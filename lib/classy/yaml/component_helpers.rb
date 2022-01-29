module Classy
  module Yaml
    module ComponentHelpers
      def yass(*args)
        component_name = self.class.source_location.split("/").last.split(".").first
        calling_path = self.class.source_location.split("/")[0...-1].join("/")
        classy_file = if Dir.exist?("#{calling_path}/#{component_name}")
                        "#{calling_path}/#{component_name}/#{component_name}.yml"
                      else
                        "#{calling_path}/#{component_name}.yml"
                      end
        helpers.yass(args, classy_files: [classy_file] )
      end
    end
  end
end
