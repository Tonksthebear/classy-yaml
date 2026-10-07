# Writes test/support/yass_golden.json from the yass output of the checked-out version.
ENV["RAILS_ENV"] = "test"
require_relative "../dummy/config/environment"
require_relative "yass_corpus"
require "json"

Classy::Yaml.setup { |config| config.override_tag_helpers = false }
golden = { "version" => Classy::Yaml::VERSION, "seed" => YassCorpus::SEED }.merge(YassCorpus.record)
File.write(YassCorpus::GOLDEN_PATH, JSON.generate(golden).gsub("],[", "],\n[") + "\n")
puts "#{golden["args"].size} calls from #{Classy::Yaml::VERSION} written to #{YassCorpus::GOLDEN_PATH}"
