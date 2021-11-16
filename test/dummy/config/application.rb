require_relative "boot"

# require "rails/all"
# require "active_model/railtie" 
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
# require "active_job/railtie"
# require "action_cable/engine"
require "sprockets/railtie"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)
require "classy/yaml"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
  end
end
