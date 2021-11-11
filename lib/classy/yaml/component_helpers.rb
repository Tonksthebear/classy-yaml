module Classy
  module Yaml
    module ComponentHelpers
      def yass(*args)
        component_name = caller.first.split("/").last.split(".").first
        calling_path = caller.first.split("/")[0...-1].join("/")
        classy_file = calling_path + "/" + component_name + ".yml"

        helpers.yass(args, classy_files: [classy_file] )
      end
    end
  end
end
