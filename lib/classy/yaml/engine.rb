require "rails"

module Classy
  module Yaml
    class Engine < Rails::Railtie
      # Each request or job starts with one check of the YAML files while Rails
      # reloads code, instead of a check on every lookup.
      initializer "classy_yaml.file_check" do |app|
        app.executor.to_run { Classy::Yaml.files_may_have_changed }
      end

      config.to_prepare do
        Classy::Yaml.clear_component_files
        ApplicationController.helper(Classy::Yaml::Helpers)
      end

      # With classes cached, parse the YAML before workers fork.
      config.after_initialize do |app|
        Classy::Yaml.warm if app.config.cache_classes
      end
    end
  end
end
