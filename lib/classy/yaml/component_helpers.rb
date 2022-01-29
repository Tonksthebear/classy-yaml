module Classy
  module Yaml
    module ComponentHelpers
      def yass(*args)
        calling_path = self.class.source_location.split("/")[0...-1].join("/")
        calling_file = self.class.source_location.split("/").last.split(".").first
        component_name = self.class.name.underscore.split("/").last.split(".").first

        classy_file = if Dir.exist?("#{calling_path}/#{calling_file}")
                        "#{calling_path}/#{calling_file}/#{component_name}.yml"
                      else
                        "#{calling_path}/#{component_name}.yml"
                      end
        helpers.yass(args, classy_files: [classy_file] )
      end
    end
  end
end
