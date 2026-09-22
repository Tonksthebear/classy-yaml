module Classy
  module Yaml
    module ComponentHelpers
      def yass(*args)
        source_file = Object.const_source_location(self.class.name).first
        calling_path = File.dirname(source_file)
        calling_file = File.basename(source_file).split(".").first
        component_name = self.class.name.underscore.split("/").last.split(".").first

        classy_files = [ "#{calling_path}/#{component_name}.yml",
                        "#{calling_path}/#{calling_file}/#{calling_file}.yml",
                        "#{calling_path}/#{calling_file}/#{component_name}.yml" ]

        if args.first.is_a?(Hash)
          args[0] = args.first.merge(classy_files: classy_files.uniq)
        else
          args << { classy_files: classy_files.uniq }
        end

        helpers.yass(*args)
      end
    end
  end
end
