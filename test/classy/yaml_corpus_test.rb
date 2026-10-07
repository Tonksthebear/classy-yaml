require "test_helper"
require "json"
require_relative "../support/yass_corpus"

class Classy::YamlCorpusTest < ActiveSupport::TestCase
  setup do
    @original = YassCorpus::CONFIGS.values.first.keys.to_h { |key| [ key, Classy::Yaml.public_send(key) ] }
    @golden = JSON.parse(File.read(YassCorpus::GOLDEN_PATH))
  end

  teardown do
    Classy::Yaml.setup do |config|
      @original.each { |key, value| config.public_send("#{key}=", value) }
    end
  end

  test "yass output is byte-identical to the 1.7.2 golden corpus" do
    assert_matches_golden YassCorpus.record
  end

  test "yass output without the result cache is byte-identical to the 1.7.2 golden corpus" do
    original_size = Classy::Yaml.cache_size
    Classy::Yaml.cache_size = 0
    assert_matches_golden YassCorpus.record
  ensure
    Classy::Yaml.cache_size = original_size
  end

  private

  def assert_matches_golden(actual)
    assert_equal "1.7.2", @golden["version"]
    assert_equal @golden["args"], actual["args"], "The corpus generator changed; the golden file no longer matches it"
    @golden["results"].each do |run, expected|
      expected.each_with_index do |result, index|
        assert_equal result, actual["results"][run][index], "#{run} yass(*#{@golden["args"][index]})"
      end
    end
  end
end
