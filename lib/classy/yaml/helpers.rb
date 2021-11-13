module Classy
  module Yaml
    module Helpers
      def yass(*args)
        classy_yamls = []
        classy_yamls << YAML.load_file(Rails.root.join("config/utility_classes.yml")) if File.exists?(Rails.root.join("config/utility_classes.yml"))

        classy_files_hash = args.find { |arg| arg.is_a?(Hash) && arg.keys.include?(:classy_files) }
        if classy_files_hash.present?
          classy_files_hash[:classy_files].each do |file|
            if File.exists?(file) && YAML.load_file(file)
              file = YAML.load_file(file)
              classy_yamls << file if file
            end
          end
        end

        return if classy_yamls.blank?

        keys, classes = flatten_args(values: args)
        classes += fetch_classes(keys, classy_yamls: classy_yamls)

        return classes.flatten.join(" ")
      end

      private

      def flatten_args(root: [], values: [], keys: [], added_classes: [])
        values.each do|value|
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

      def fetch_classes(keys, classy_yamls: [])
        classes = []

        keys.map do |key|
          base_classes = nil
          fetched_classes = nil

          classy_yamls.reverse_each do |classy_yaml|
            begin
              base_classes ||= if classy_yaml.send(:dig, *key).is_a?(Hash)
                                 classy_yaml.send(:dig, *(key + ['base'])).try(:split, " ")
                               else
                                 classy_yaml.send(:dig, *(key[0...-1] + ['base'])).try(:split, " ")
                               end
            rescue
              raise Classy::Yaml::InvalidKeyError.new(data: key)
            end

            begin
              fetched_classes ||= unless classy_yaml.send(:dig, *key).is_a?(Hash)
                                    classy_yaml.send(:dig, *key).try(:split, " ")
                                  end

              base_classes = nil if base_classes.blank?
              fetched_classes = nil if fetched_classes.blank?
            rescue
              raise Classy::Yaml::InvalidKeyError.new(data: key)
            end
          end

          classes << base_classes
          classes << fetched_classes
        end

        classes.reject!(&:blank?)
        return classes.flatten.uniq
      end

    end
  end
end
