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

    # -- Configuration Setters with Path Resolution --
    def self.engine_files=(value)
      @@engine_files = Array.wrap(value).reject(&:blank?).map { |file| Rails.root.join(file) }
      @cached_engine_yamls = nil # Clear cache on reassignment
    end

    def self.extra_files=(value)
      @@extra_files = Array.wrap(value).reject(&:blank?).map { |file| Rails.root.join(file) }
      # Note: extra_files are not cached globally by default
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
      # Bypass cache in development and test environments
      return load_engine_yamls if Rails.env.development? || Rails.env.test?

      # Use cache in other environments
      return @cached_engine_yamls if @cached_engine_yamls

      @load_lock.synchronize do
        # Double-check idiom to ensure loading happens only once
        return @cached_engine_yamls if @cached_engine_yamls
        @cached_engine_yamls = load_engine_yamls
      end
    end

    def self.cached_default_yaml
      # Bypass cache in development and test environments
      return load_default_yaml if Rails.env.development? || Rails.env.test?

      # Use cache in other environments
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
      # Apply tag helper override if enabled
      apply_tag_helper_override if @@override_tag_helpers
    end

    private

    def self.apply_tag_helper_override
      return unless defined?(ActionView::Helpers::TagHelper)

      # Override the TagBuilder class which is what the tag method returns
      ActionView::Helpers::TagHelper::TagBuilder.class_eval do
        unless method_defined?(:classy_yaml_original_tag_options)
          alias_method :classy_yaml_original_tag_options, :tag_options

          def tag_options(options, escape = true)
            if options
              class_key = options.key?(:class) ? :class : "class"
              options = options.dup
              val = options[class_key]
              if val.is_a?(Symbol) || val.is_a?(Hash)
                options[:class] = yass(val)
              end
            end
            classy_yaml_original_tag_options(options, escape)
          end
        end
      end
    end

    def self.load_engine_yamls
      yamls = []
      self.engine_files.each do |file_path|
        begin
          if File.exist?(file_path)
            content = File.read(file_path, encoding: "UTF-8")
            parsed_yaml = YAML.safe_load(content, permitted_classes: [ Symbol, String, Array, Hash ], aliases: true)
            yamls << parsed_yaml if parsed_yaml && parsed_yaml.is_a?(Hash)
          end
        rescue Psych::SyntaxError => e
          Rails.logger.error "Classy::Yaml: Failed to parse engine YAML file #{file_path}: #{e.message}"
        rescue => e
          Rails.logger.error "Classy::Yaml: Error loading engine YAML file #{file_path}: #{e.message}"
        end
      end
      yamls
    end

    def self.load_default_yaml
      default_path = Rails.root.join(self.default_file)
      begin
        if File.exist?(default_path)
          content = File.read(default_path, encoding: "UTF-8")
          parsed_yaml = YAML.safe_load(content, permitted_classes: [ Symbol, String, Array, Hash ], aliases: true)
          return parsed_yaml if parsed_yaml && parsed_yaml.is_a?(Hash)
        end
      rescue Psych::SyntaxError => e
        Rails.logger.error "Classy::Yaml: Failed to parse default YAML file #{default_path}: #{e.message}"
      rescue => e
        Rails.logger.error "Classy::Yaml: Error loading default YAML file #{default_path}: #{e.message}"
      end
      nil # Return nil if file doesn't exist or fails to load/parse
    end
  end
end
