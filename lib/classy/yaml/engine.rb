module Classy
  module Yaml
    class Engine < ::Rails::Engine
      paths["lib/classy/yaml"]
      config.to_prepare do
        ApplicationController.helper(Classy::Yaml::Helpers)
      end

      Gem.loaded_specs['classy-yaml'].dependencies.each do |d|
        require d.name if Rails.env.test?
      end
    end
  end
end
