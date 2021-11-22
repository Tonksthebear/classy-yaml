require "rails"

module Classy
  module Yaml
    class Engine < Rails::Railtie
      config.to_prepare do
        ApplicationController.helper(Classy::Yaml::Helpers)
      end
    end
  end
end
