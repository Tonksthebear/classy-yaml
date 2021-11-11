module Classy
  module Yaml
    class Engine < ::Rails::Engine
      paths["lib/classy/yaml"]
      config.to_prepare do
        ApplicationController.helper(Classy::Yaml::Helpers)
      end
    end
  end
end
