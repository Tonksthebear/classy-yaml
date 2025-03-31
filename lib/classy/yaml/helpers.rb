module Classy
  module Yaml
    module Helpers
      # Fetches utility classes from YAML files based on the provided keys.
      # The method follows a priority order:
      # 1. Extra files (highest priority)
      # 2. Default YAML
      # 3. ViewComponent YAMLs (lowest priority)
      #
      # @param args [Array] Array of keys to look up in the YAML files
      # @return [String] Space-separated list of CSS classes
      def yass(*args)
        # Start with ViewComponent YAMLs (lowest priority)
        classy_yamls = Classy::Yaml.cached_engine_yamls.dup

        # Add default YAML (next priority)
        default_yaml = Classy::Yaml.cached_default_yaml
        classy_yamls << default_yaml if default_yaml

        # Add extra files (highest priority)
        Classy::Yaml.extra_files.each do |file_path|
          load_yaml_file(file_path, classy_yamls, "extra")
        end

        # Add classy_files (highest priority)
        classy_files_hash = args.find { |arg| arg.is_a?(Hash) && arg.keys.include?(:classy_files) } || { classy_files: [] }
        classy_files_hash[:classy_files].each do |file_path|
          load_yaml_file(file_path, classy_yamls, "classy")
        end

        return "" if classy_yamls.blank?

        skip_base_hash = args.find { |arg| arg.is_a?(Hash) && arg.keys.include?(:skip_base) } || {}
        keys, classes = flatten_args(values: args)
        classes += fetch_classes(keys, classy_yamls: classy_yamls, skip_base: skip_base_hash[:skip_base])

        classes.flatten.uniq.join(" ")
      end

      private

      # Loads a YAML file and adds its contents to the classy_yamls array
      # @param file_path [String, Pathname] Path to the YAML file
      # @param classy_yamls [Array] Array to add the parsed YAML to
      # @param file_type [String] Type of file being loaded (for error messages)
      def load_yaml_file(file_path, classy_yamls, file_type)
        begin
          path_obj = file_path.is_a?(Pathname) ? file_path : Rails.root.join(file_path)
          if File.exist?(path_obj)
            content = File.read(path_obj, encoding: 'UTF-8')
            parsed_yaml = YAML.safe_load(content, permitted_classes: [Symbol, String, Array, Hash], aliases: true)
            classy_yamls << parsed_yaml if parsed_yaml && parsed_yaml.is_a?(Hash)
          end
        rescue Psych::SyntaxError => e
          Rails.logger.error "Classy::Yaml (yass helper): Failed to parse #{file_type} YAML file #{file_path}: #{e.message}"
        rescue => e
          Rails.logger.error "Classy::Yaml (yass helper): Error loading #{file_type} YAML file #{file_path}: #{e.message}"
        end
      end

      # Flattens the arguments into keys and classes
      # @param root [Array] Current root path in the argument tree
      # @param values [Array] Values to process
      # @param keys [Array] Array to store found keys
      # @param added_classes [Array] Array to store found classes
      # @return [Array] Tuple of [keys, added_classes]
      def flatten_args(root: [], values: [], keys: [], added_classes: [])
        values.each do |value|
          if value.is_a?(Hash)
            if value.has_key? :add
              added_classes << value[:add]
              value.except! :add
            end

            value.keys.each do |key|
              values << (root + [key.to_s])
              flatten_args(root: root + [key.to_s], values: [value[key]], keys: keys, added_classes: added_classes)
            end
          else
            if value.is_a?(Array)
              flatten_args(root: root, values: value, keys: keys, added_classes: added_classes)
            else
              keys << (root + [value.to_s])
            end
          end
        end

        return keys, added_classes
      end

      # Fetches classes from the YAML files based on the provided keys
      # @param keys [Array] Array of keys to look up
      # @param classy_yamls [Array] Array of YAML files to search in
      # @param skip_base [Boolean] Whether to skip base classes
      # @return [Array] Array of found classes
      def fetch_classes(keys, classy_yamls: [], skip_base: false)
        classes = []

        keys.map do |key|
          base_classes = nil
          fetched_classes = nil

          classy_yamls.reverse_each do |classy_yaml|
            # Base Class Lookup
            unless skip_base == true
              begin
                value_at_key = classy_yaml.send(:dig, *key)
                base_value = if value_at_key.is_a?(Hash)
                               classy_yaml.send(:dig, *(key + ['base']))
                             elsif key.length > 1
                               classy_yaml.send(:dig, *(key[0...-1] + ['base']))
                             else
                               nil
                             end
                normalized_base = normalize_original(base_value)
                base_classes ||= normalized_base
              rescue
                Rails.logger.warn(Classy::Yaml::InvalidKeyError.new(data: key))
              end
            end

            # Specific Key Class Lookup
            begin
              value = classy_yaml.send(:dig, *key)
              unless value.is_a?(Hash)
                normalized_fetched = normalize_original(value)
                fetched_classes ||= normalized_fetched
              end
            rescue
              Rails.logger.warn(Classy::Yaml::InvalidKeyError.new(data: key))
            end

            base_classes = nil if base_classes.blank?
            fetched_classes = nil if fetched_classes.blank?
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
