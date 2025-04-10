require_relative "lib/classy/yaml/version"

Gem::Specification.new do |spec|
  spec.name        = "classy-yaml"
  spec.version     = Classy::Yaml::VERSION
  spec.authors     = [ "Tonksthebear" ]
  spec.email       = [ "" ]
  spec.homepage    = "https://github.com/Tonksthebear/classy-yaml"
  spec.summary     = "Rails helper to allow yaml configuration of utility css classes"
  spec.description = "Rails helper to allow yaml configuration of utility css classes"
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Tonksthebear/classy-yaml"
  spec.metadata["changelog_uri"] = "https://github.com/Tonksthebear/classy-yaml/releases"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "activesupport", ">= 6"
  spec.add_dependency "actionpack", ">= 6"
  spec.add_dependency "railties", ">= 6"

  spec.add_development_dependency "view_component", ">= 2.4"
  spec.add_development_dependency "capybara", ">= 3.36"
  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "rubocop-rails-omakase"
end
