require "classy/yaml/version"
require "classy/yaml/engine"

module Classy
  module Yaml
    mattr_accessor :default_file
    @@default_file = "config/utility_classes.yml"

    mattr_accessor :extra_files
    @@extra_files = []

    autoload :Helpers, "classy/yaml/helpers"
    autoload :ComponentHelpers, "classy/yaml/component_helpers"
    autoload :InvalidKeyError, "classy/yaml/invalid_key_error"

    def self.extra_files=(value)
      @@extra_files = Array.wrap(value).reject(&:blank?).map { |file| Rails.root.join(file) }
    end

    def self.setup
      yield self
    end
  end
end
