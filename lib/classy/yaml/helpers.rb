module Classy
  module Yaml
    module Helpers
      # Fetches utility classes from YAML files based on the provided keys.
      # The method follows a priority order:
      # 1. Component files (highest priority)
      # 2. Extra files
      # 3. Default YAML
      # 4. Engine files (lowest priority)
      #
      # @param args [Array] Array of keys to look up in the YAML files
      # @return [String] Space-separated list of CSS classes
      def yass(*args)
        # Start with engine YAMLs (lowest priority)
        classy_yamls = Classy::Yaml.cached_engine_yamls.dup

        # Add default YAML (next priority)
        default_yaml = Classy::Yaml.cached_default_yaml
        classy_yamls << default_yaml if default_yaml

        # Add extra files (highest priority)
        Classy::Yaml.extra_files.each do |file_path|
          load_yaml_file(file_path, classy_yamls, "extra")
        end

        # Add classy_files (highest priority)
        classy_files_hash = args.find { |arg| arg.is_a?(Hash) && arg.key?(:classy_files) } || { classy_files: [] }
        classy_files_hash[:classy_files].each do |file_path|
          load_yaml_file(file_path, classy_yamls, "classy")
        end

        skip_base_hash = args.find { |arg| arg.is_a?(Hash) && arg.key?(:skip_base) } || {}
        keys, add_classes = flatten_args(values: args)
        classes = fetch_classes(keys.uniq, classy_yamls: classy_yamls, skip_base: skip_base_hash[:skip_base])
        classes += add_classes

        # Use tailwind_merge if available, otherwise fall back to simple join
        merge_classes(classes.flatten.uniq)
      end

      private

      # Merges CSS classes using tailwind_merge if available, otherwise uses simple join
      # @param classes [Array] Array of CSS class strings
      # @return [String] Merged CSS classes
      def merge_classes(classes)
        return "" if classes.blank?

        if tailwind_merge_available?
          # Use tailwind_merge for intelligent class merging
          Classy::Yaml.merge_classes(classes)
        else
          # Fall back to simple space-joined classes
          classes.join(" ")
        end
      end

      # Checks if tailwind_merge gem is available
      # @return [Boolean] True if tailwind_merge is available
      def tailwind_merge_available?
        return @tailwind_merge_available if defined?(@tailwind_merge_available)
        @tailwind_merge_available = begin
          require "tailwind_merge"
          true
        rescue LoadError
          false
        end
      end

      # Loads a YAML file and adds its contents to the classy_yamls array
      # @param file_path [String, Pathname] Path to the YAML file
      # @param classy_yamls [Array] Array to add the parsed YAML to
      # @param file_type [String] Type of file being loaded (for error messages)
      def load_yaml_file(file_path, classy_yamls, file_type)
        parsed_yaml = Classy::Yaml.cached_yaml_file(file_path, file_type)
        classy_yamls << parsed_yaml if parsed_yaml
      end

      # Flattens the arguments into keys and classes
      # @param root [Array] Current root path in the argument tree
      # @param values [Array] Values to process
      # @param keys [Array] Array to store found keys
      # @param added_classes [Array] Array to store found classes
      # @return [Array] Tuple of [keys, added_classes]
      def flatten_args(root: [], values: [], keys: [], added_classes: [])
        parent_keys = []
        values.each do |value|
          case value
          when Hash
            added_classes << value[:add] if value.key?(:add)
            value.each do |key, child|
              next if key == :add
              next if root.empty? && [ :skip_base, :classy_files ].include?(key)

              path = root + [ key.to_s ]
              parent_keys << path
              flatten_args(root: path, values: [ child ], keys: keys, added_classes: added_classes)
            end
          when Array
            flatten_args(root: root, values: value, keys: keys, added_classes: added_classes)
          else
            keys << (root + [ value.to_s ])
          end
        end
        keys.concat(parent_keys)
        [ keys, added_classes ]
      end

      # Fetches classes from the YAML files based on the provided keys
      # @param keys [Array] Array of keys to look up
      # @param classy_yamls [Array] Array of YAML files to search in
      # @param skip_base [Boolean] Whether to skip base classes
      # @return [Array] Array of found classes
      def fetch_classes(keys, classy_yamls: [], skip_base: false)
        classes = []

        keys.each do |key|
          base_classes = nil
          fetched_classes = nil

          classy_yamls.reverse_each do |classy_yaml|
            begin
              value = classy_yaml.dig(*key)
              unless skip_base == true || base_classes
                base_value = if value.is_a?(Hash)
                  value["base"]
                elsif key.length > 1
                  classy_yaml.dig(*(key[0...-1] + [ "base" ]))
                end
                base_classes = normalize_original(base_value).presence
              end

              unless fetched_classes || value.is_a?(Hash)
                fetched_classes = normalize_original(value).presence
              end
            rescue StandardError
              Rails.logger.warn(Classy::Yaml::InvalidKeyError.new(data: key))
            end

            break if fetched_classes && (skip_base == true || base_classes)
          end

          classes << base_classes unless base_classes.blank?
          classes << fetched_classes unless fetched_classes.blank?
        end

        classes.flatten.uniq
      end

      # Normalizes a value into an array of classes
      # @param value [String, Array, nil] Value to normalize
      # @return [Array, nil] Array of classes or nil if value is invalid
      def normalize_original(value)
        case value
        when String
          value.split(" ").reject(&:blank?)
        when Array
          value.flatten.map(&:to_s).reject(&:blank?)
        else
          nil
        end
      end
    end
  end
end
