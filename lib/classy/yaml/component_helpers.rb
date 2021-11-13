module Classy
  module Yaml
    module ComponentHelpers
      def yass(*args)
        component_name = caller.first.split("/").last.split(".").first
        calling_path = caller.first.split("/")[0...-1].join("/")
        classy_file = if Dir.exists?("#{calling_path}/#{component_name}")
                        "#{calling_path}/#{component_name}/#{component_name}.yml"
                      else
                        "#{calling_path}/#{component_name}.yml"
                      end
        helpers.yass(args, classy_files: [classy_file] )
      end
    end
  end
end
