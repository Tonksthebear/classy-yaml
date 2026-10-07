module Classy
  module Yaml
    module ComponentHelpers
      def yass(*args)
        classy_files = Classy::Yaml.component_classy_files(self.class)

        if args.first.is_a?(Hash)
          args[0] = args.first.merge(classy_files: classy_files)
        else
          args << { classy_files: classy_files }
        end

        helpers.yass(*args)
      end
    end
  end
end
