require "classy/yaml/version"
require "classy/yaml/engine"

module Classy
  module Yaml
    # -- Configuration Accessors --
    mattr_accessor :default_file
    @@default_file = "config/utility_classes.yml"

    mattr_accessor :engine_files
    @@engine_files = []

    mattr_accessor :extra_files
    @@extra_files = []

    mattr_accessor :override_tag_helpers
    @@override_tag_helpers = false

    # -- Autoloads --
    autoload :Helpers, "classy/yaml/helpers"
    autoload :ComponentHelpers, "classy/yaml/component_helpers"
    autoload :InvalidKeyError, "classy/yaml/invalid_key_error"

    # -- Class Instance Variables for Caching --
    @cached_engine_yamls = nil
    @cached_default_yaml = nil
    @load_lock = Mutex.new # Prevent race conditions during lazy loading
    @file_cache = {}
    @file_lock = Mutex.new
    @merger_lock = Mutex.new

    # -- Configuration Setters with Path Resolution --
    def self.engine_files=(value)
      @@engine_files = Array.wrap(value).reject(&:blank?).map { |file| Rails.root.join(file) }
      @cached_engine_yamls = nil # Clear cache on reassignment
    end

    def self.extra_files=(value)
      @@extra_files = Array.wrap(value).reject(&:blank?).map { |file| Rails.root.join(file) }
      # Parsed files use the shared file cache.
    end

    def self.default_file=(value)
      @@default_file = value
      @cached_default_yaml = nil # Clear cache on reassignment
    end

    def self.override_tag_helpers=(value)
      @@override_tag_helpers = value
      apply_tag_helper_override if value
    end

    # -- Cached Data Accessors (Lazy Loading) --
    def self.cached_engine_yamls
      # Check file metadata only while Rails reloads code
      return load_engine_yamls if reloading?

      # Classes are cached: parse once
      return @cached_engine_yamls if @cached_engine_yamls

      @load_lock.synchronize do
        # Double-check idiom to ensure loading happens only once
        return @cached_engine_yamls if @cached_engine_yamls
        @cached_engine_yamls = load_engine_yamls
      end
    end

    def self.cached_default_yaml
      # Check file metadata only while Rails reloads code
      return load_default_yaml if reloading?

      # Classes are cached: parse once
      return @cached_default_yaml if @cached_default_yaml

      @load_lock.synchronize do
        return @cached_default_yaml if @cached_default_yaml
        @cached_default_yaml = load_default_yaml
      end
    end

    # -- Setup Method --
    def self.setup
      yield self
      # Clear all caches when configuration changes
      @cached_engine_yamls = nil
      @cached_default_yaml = nil
      @file_lock.synchronize { @file_cache.clear }
      # Apply tag helper override if enabled
      apply_tag_helper_override if @@override_tag_helpers
    end

    private

    def self.apply_tag_helper_override
      require "classy/yaml/tag_helper"

      ActiveSupport.on_load(:action_view) do
        ActionView::Helpers::TagHelper::TagBuilder.prepend(Classy::Yaml::TagHelper)
      end

      apply_icon_helper_override
    end

    def self.apply_icon_helper_override
      return unless defined?(RailsIcons::Helpers::IconHelper)

      require "classy/yaml/icon_helper"

      RailsIcons::Helpers::IconHelper.prepend(Classy::Yaml::IconHelper)
    end

    def self.load_engine_yamls
      engine_files.map { |path| cached_yaml_file(path, "engine") }.compact
    end

    def self.load_default_yaml
      cached_yaml_file(default_file, "default")
    end

    # Edits are picked up without a restart only while Rails reloads code.
    # With classes cached (test, production) a parsed file is never stat'ed again.
    def self.reloading?
      !Rails.application.config.cache_classes
    end

    # Check metadata on each access while reloading so edits do not require a restart.
    def self.cached_yaml_file(file_path, file_type)
      @file_lock.synchronize do
        begin
          path = Rails.root.join(file_path).to_s
          cached = @file_cache[path]
          return cached[:yaml] if cached && !reloading?

          stat = File.stat(path)
          signature = [ stat.mtime, stat.ctime, stat.size, stat.ino, stat.dev ]
          return cached[:yaml] if cached && cached[:signature] == signature

          content = File.read(path, encoding: "UTF-8")
          parsed = YAML.safe_load(content, permitted_classes: [ Symbol, String, Array, Hash ], aliases: true)
          yaml = parsed.is_a?(Hash) ? parsed : nil
          @file_cache[path] = { signature: signature, yaml: yaml }
          yaml
        rescue Errno::ENOENT, Errno::ENOTDIR
          # A missing file stays missing until the next restart when classes are cached.
          reloading? ? @file_cache.delete(path) : @file_cache[path] = { signature: nil, yaml: nil }
          nil
        rescue Psych::SyntaxError => e
          @file_cache.delete(path)
          Rails.logger.error "Classy::Yaml: Failed to parse #{file_type} YAML file #{file_path}: #{e.message}"
          nil
        rescue => e
          @file_cache.delete(path)
          Rails.logger.error "Classy::Yaml: Error loading #{file_type} YAML file #{file_path}: #{e.message}"
          nil
        end
      end
    end

    # The merger cache is mutable, so concurrent calls must use the same lock.
    def self.merge_classes(classes)
      @merger_lock.synchronize do
        @merger ||= TailwindMerge::Merger.new
        @merger.merge(classes)
      end
    end
  end
end
