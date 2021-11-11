require_relative "lib/classy/yaml/version"

Gem::Specification.new do |spec|
  spec.name        = "classy-yaml"
  spec.version     = Classy::Yaml::VERSION
  spec.authors     = [""]
  spec.email       = [""]
  spec.homepage    = "TODO"
  spec.summary     = "TODO: Summary of Classy::Yaml."
  spec.description = "TODO: Description of Classy::Yaml."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 6.1.4", ">= 6.1.4.1"
end
