module Classy
  module Yaml
    module TagHelper
      include Classy::Yaml::Helpers

      def tag_options(options, escape = true)
        if options
          class_key = options.key?(:class) ? :class : "class"
          options = options.dup
          val = options[class_key]
          if val.is_a?(Symbol) || val.is_a?(Hash) || val.is_a?(Array)
            options[class_key] = yass(val)
          end
        end
        super(options, escape)
      end
    end
  end
end
