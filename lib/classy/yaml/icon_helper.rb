module Classy
  module Yaml
    module IconHelper
      include Classy::Yaml::Helpers

      def icon(name, **arguments)
        val = arguments[:class]
        if val.is_a?(Symbol) || val.is_a?(Hash) || val.is_a?(Array)
          arguments[:class] = yass(val)
        end
        super(name, **arguments)
      end
    end
  end
end
