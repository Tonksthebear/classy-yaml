require_relative "lib/classy/yaml/version"

Gem::Specification.new do |spec|
  spec.name        = "classy-yaml"
  spec.version     = Classy::Yaml::VERSION
  spec.authors     = ["Tonksthebear"]
  spec.email       = [""]
  spec.homepage    = "https://github.com/Tonksthebear/classy-yaml"
  spec.summary     = "Rails helper to allow yaml configuration of utility css classes"
  spec.description = "Rails helper to allow yaml configuration of utility css classes"
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Tonksthebear/classy-yaml"
  spec.metadata["changelog_uri"] = "https://github.com/Tonksthebear/classy-yaml/releases"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 6.1.4", ">= 6.1.4.1"
end
