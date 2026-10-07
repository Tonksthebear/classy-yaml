require "concurrent/map"
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
    autoload :Lookup, "classy/yaml/lookup"
    autoload :ResultCache, "classy/yaml/result_cache"

    # The number of yass results kept for reuse. Set to 0 to turn the result cache off.
    DEFAULT_CACHE_SIZE = 5_000

    FileEntry = Struct.new(:signature, :layer)

    # -- Caches --
    # Parsed and compiled YAML files, keyed by full path. While Rails reloads code,
    # each entry keeps the file signature that check_for_changes compares.
    @file_cache = {}
    # Configured and component paths resolved against Rails.root.
    @full_paths = {}
    @file_lock = Mutex.new
    # The engine, default and extra layers, compiled for the current generation.
    @static_layers = nil
    @results = ResultCache.new(DEFAULT_CACHE_SIZE)
    @component_files = Concurrent::Map.new
    @check_pending = false
    @merger_lock = Mutex.new

    # -- Configuration Setters with Path Resolution --
    def self.engine_files=(value)
      @@engine_files = Array.wrap(value).reject(&:blank?).map { |file| Rails.root.join(file) }
      reset_caches
    end

    def self.extra_files=(value)
      @@extra_files = Array.wrap(value).reject(&:blank?).map { |file| Rails.root.join(file) }
      reset_caches
    end

    def self.default_file=(value)
      @@default_file = value
      reset_caches
    end

    def self.override_tag_helpers=(value)
      @@override_tag_helpers = value
      apply_tag_helper_override if value
    end

    def self.cache_size
      @results.max_size
    end

    def self.cache_size=(value)
      @results.max_size = Integer(value)
    end

    # Increases on every configuration change and every YAML file change.
    def self.generation
      @results.generation
    end

    # -- Setup Method --
    def self.setup
      yield self
      # Clear all caches when configuration changes
      reset_caches(files: true)
      # Apply tag helper override if enabled
      apply_tag_helper_override if @@override_tag_helpers
    end

    # Returns the classes for yass arguments. Results are reused until a
    # configuration change or (while Rails reloads code) a YAML file change.
    def self.classes_for(args, tailwind)
      check_for_changes if @check_pending
      key = Lookup.cache_key(args, tailwind) if @results.max_size.positive?
      if key
        digest = key.hash
        cached = @results.get(key, digest)
        return cached.is_a?(String) ? cached : cached.first.dup if cached
      end

      generation = @results.generation
      result, cacheable = build_classes(args, tailwind)
      if key && cacheable
        # A frozen result is shared as 1.7.2 shared tailwind_merge's cached string;
        # any other result is returned as a new unfrozen copy each time.
        value = result.frozen? ? result : [ result.dup.freeze ].freeze
        @results.store(Lookup.freeze_key(key), value, generation, digest)
      end
      result
    end

    # Parses the YAML files and builds the merger before Puma or the test runner
    # forks, so workers share them copy-on-write and the first request pays nothing.
    def self.warm
      static_layers
      @merger_lock.synchronize { @merger ||= TailwindMerge::Merger.new } if tailwind_merge_available?
    end

    # Called at the start of each request or job (the Rails executor). While
    # Rails reloads code, the next lookup compares each YAML file it has read.
    def self.files_may_have_changed
      @check_pending = true if reloading?
    end

    # Stats every YAML file read so far (also missing ones) once. A change drops
    # that file and every cached result.
    def self.check_for_changes
      @file_lock.synchronize do
        return unless @check_pending

        @check_pending = false
        changed = @file_cache.select { |path, entry| entry.signature != file_signature(path) }
        next if changed.empty?

        changed.each_key { |path| @file_cache.delete(path) }
        invalidate_results
      end
    end

    def self.reset_caches(files: false)
      @file_lock.synchronize do
        if files
          @file_cache.clear
          @full_paths.clear
        end
        @component_files = Concurrent::Map.new
        invalidate_results
      end
    end

    # Must be called with @file_lock held.
    def self.invalidate_results
      @static_layers = nil
      @results.invalidate
    end

    def self.tailwind_merge_available?
      return @tailwind_merge_available if defined?(@tailwind_merge_available)

      @tailwind_merge_available = begin
        require "tailwind_merge"
        true
      rescue LoadError
        false
      end
    end

    # The YAML candidates next to a component's source file, computed once per class.
    def self.component_classy_files(component_class)
      @component_files.compute_if_absent(component_class) do
        source_file = Object.const_source_location(component_class.name).first
        calling_path = File.dirname(source_file)
        calling_file = File.basename(source_file).split(".").first
        component_name = component_class.name.underscore.split("/").last.split(".").first

        [ "#{calling_path}/#{component_name}.yml",
          "#{calling_path}/#{calling_file}/#{calling_file}.yml",
          "#{calling_path}/#{calling_file}/#{component_name}.yml" ].uniq.each(&:freeze).freeze
      end
    end

    # Reloaded component classes are new objects, so drop the old ones.
    def self.clear_component_files
      @component_files = Concurrent::Map.new
    end

    # Engine files (lowest priority), the default file, then extra files.
    def self.static_layers
      @static_layers || begin
        generation = @results.generation
        layers = [
          *engine_files.map { |path| cached_yaml_file(path, "engine") },
          cached_yaml_file(default_file, "default"),
          *extra_files.map { |path| cached_yaml_file(path, "extra") }
        ].compact.freeze
        @file_lock.synchronize { @static_layers = layers if generation == @results.generation }
        layers
      end
    end

    # Returns the compiled YAML of a file, or nil when it is missing or invalid.
    def self.cached_yaml_file(file_path, file_type)
      @file_lock.synchronize do
        path = @full_paths[file_path] ||= Rails.root.join(file_path).to_s.freeze
        entry = @file_cache[path] ||= load_yaml_file(path, file_path, file_type)
        entry.layer
      end
    end

    # The merger cache is mutable, so concurrent calls must use the same lock.
    def self.merge_classes(classes)
      @merger_lock.synchronize do
        @merger ||= TailwindMerge::Merger.new
        @merger.merge(classes)
      end
    end

    # Edits are picked up without a restart only while Rails reloads code.
    # With classes cached (test, production) a parsed file is never stat'ed again.
    def self.reloading?
      !Rails.application.config.cache_classes
    end

    # Turns parsed YAML into frozen lookup data: a string becomes its classes, an
    # array its flattened classes. Other values stay as they are and give no classes.
    def self.compile(value, compiled_hashes = {}.compare_by_identity)
      case value
      when Hash
        compiled_hashes[value] || begin
          compiled = compiled_hashes[value] = {}
          value.each { |key, child| compiled[key] = compile(child, compiled_hashes) }
          compiled.freeze
        end
      when String
        value.split(" ").reject(&:blank?).each(&:freeze).freeze
      when Array
        begin
          value.flatten.map(&:to_s).reject(&:blank?).each(&:freeze).freeze
        rescue ArgumentError
          # A recursive array has no classes, and a path through it is invalid.
          Lookup::INVALID
        end
      else
        value
      end
    end

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

    class << self
      private

      def build_classes(args, tailwind)
        layers = static_layers
        classy_files = args.find { |arg| arg.is_a?(Hash) && arg.key?(:classy_files) }
        if classy_files
          layers = layers.dup
          classy_files[:classy_files].each do |file_path|
            layer = cached_yaml_file(file_path, "classy")
            layers << layer if layer
          end
        end
        skip_base = args.find { |arg| arg.is_a?(Hash) && arg.key?(:skip_base) }

        keys = []
        adds = []
        Lookup.collect_list(args, Lookup::EMPTY, keys, adds)
        keys.uniq!
        classes = []
        clean = Lookup.resolve(keys, layers, skip_base && skip_base[:skip_base], classes)
        classes.uniq!
        unless adds.empty?
          classes.concat(adds)
          classes.flatten!
          classes.uniq!
        end

        result = if classes.empty?
          +""
        elsif tailwind
          merge_classes(classes)
        else
          classes.join(" ")
        end
        [ result, clean ]
      end

      def load_yaml_file(path, file_path, file_type)
        signature = file_signature(path)
        return FileEntry.new(nil, nil).freeze unless signature

        content = File.read(path, encoding: "UTF-8")
        parsed = YAML.safe_load(content, permitted_classes: [ Symbol, String, Array, Hash ], aliases: true)
        FileEntry.new(signature, parsed.is_a?(Hash) ? compile(parsed) : nil).freeze
      rescue Errno::ENOENT, Errno::ENOTDIR
        FileEntry.new(nil, nil).freeze
      rescue Psych::SyntaxError => e
        Rails.logger.error "Classy::Yaml: Failed to parse #{file_type} YAML file #{file_path}: #{e.message}"
        FileEntry.new(signature, nil).freeze
      rescue => e
        Rails.logger.error "Classy::Yaml: Error loading #{file_type} YAML file #{file_path}: #{e.message}"
        FileEntry.new(signature, nil).freeze
      end

      def file_signature(path)
        stat = File.stat(path)
        [ stat.mtime, stat.ctime, stat.size, stat.ino, stat.dev ]
      rescue Errno::ENOENT, Errno::ENOTDIR
        nil
      end
    end
  end
end
