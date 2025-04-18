module Classy
  module Yaml
    module ComponentHelpers
      def yass(*args)
        calling_path = Object.const_source_location(self.class.name).first.split("/")[0...-1].join("/")
        calling_file = Object.const_source_location(self.class.name).first.split("/").last.split(".").first
        component_name = self.class.name.underscore.split("/").last.split(".").first

        classy_files = [ "#{calling_path}/#{component_name}.yml",
                        "#{calling_path}/#{calling_file}/#{calling_file}.yml",
                        "#{calling_path}/#{calling_file}/#{component_name}.yml" ]

        if args.first.is_a?(Hash)
          args.first.merge!({ classy_files: classy_files.uniq })
        else
          args << { classy_files: classy_files.uniq }
        end

        helpers.yass(*args)
      end
    end
  end
end
