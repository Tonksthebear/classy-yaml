require "test_helper"
require "json"

# The Classy conformance suite: the contract between this gem and Classy for PHP (php/).
# test/conformance/classy/calls.json lists yass calls over fixture YAML layers, and class_names merges.
# This test runs them with the gem and checks that expected.json holds the gem's output.
# CLASSY_CONFORMANCE_WRITE=1 rewrites expected.json. The PHP side (test/conformance/classy/run.php)
# compares its own output with expected.json.
class Classy::ConformanceTest < ActiveSupport::TestCase
  DIR = Pathname.new(File.expand_path("../conformance/classy", __dir__))
  SPEC = JSON.parse(File.read(DIR.join("calls.json")))
  EXPECTED = DIR.join("expected.json")

  # Counts the InvalidKeyError warnings that Classy logs during one yass call.
  class WarningCounter < ::Logger
    attr_reader :warnings

    def initialize
      super(nil)
      @warnings = 0
    end

    def warn(message = nil, &block)
      @warnings += 1 if message.is_a?(Classy::Yaml::InvalidKeyError)
      super
    end
  end

  test "calls.json holds 164 calls" do
    counts = SPEC["suites"].transform_values { |suite| suite["calls"].size }
    assert_equal({ "fixture" => 43, "components" => 103 }, counts)
    assert_equal 18, SPEC["class_names"]["calls"].size
  end

  test "expected.json is the gem's output" do
    actual = ruby_results
    if ENV["CLASSY_CONFORMANCE_WRITE"]
      File.write(EXPECTED, JSON.pretty_generate(actual) + "\n")
      return pass
    end

    expected = EXPECTED.exist? ? JSON.parse(File.read(EXPECTED)) : {}
    differences = compare(expected, actual)
    assert differences.empty?, <<~MESSAGE
      #{differences.size} calls differ from expected.json:
      #{differences.join("\n")}

      If the gem's new output is correct, run CLASSY_CONFORMANCE_WRITE=1 bin/test #{__FILE__} and commit expected.json.
    MESSAGE
  end

  private

  def ruby_results
    results = { "suites" => {}, "class_names" => {} }
    SPEC["suites"].each do |name, suite|
      with_suite(suite) do
        results["suites"][name] = suite["calls"].to_h do |call|
          classes, warnings = yass_with_warnings(resolve(call["args"]))
          [ call["name"], { "classes" => classes, "warnings" => warnings } ]
        end
        results["class_names"] = class_names_results if SPEC["class_names"]["suite"] == name
      end
    end
    results
  end

  def class_names_results
    override = SPEC["class_names"]["override_tag_helpers"]
    SPEC["class_names"]["calls"].to_h do |call|
      parts = call["parts"].map do |part|
        if part.is_a?(Hash) && part.key?("yass")
          helper.yass(*resolve(part["yass"]))
        elsif part.is_a?(Hash) && part.key?("hash")
          part["hash"]
        else
          part
        end
      end
      [ call["name"], merged_class_names(parts, override) ]
    end
  end

  # A component's class_names merge: with Classy's tag helper override on, a Hash argument is a yass
  # lookup. Then Rails' token_list, unescaped, and one tailwind-merge pass with Classy's merger.
  # The override is a suite setting here; the global Classy::Yaml.override_tag_helpers stays off.
  def merged_class_names(parts, override)
    parts = parts.map { |part| process_user_class(part) } if override
    Classy::Yaml.merge_classes(CGI.unescape_html(helper.token_list(*parts)))
  end

  def process_user_class(value)
    case value
    when Array then value.map { |item| process_user_class(item) }
    # Classy deletes :add from the hash it resolves; resolve a copy so the spec is left as it was.
    when Hash then helper.yass(value.deep_dup)
    else value
    end
  end

  def helper
    @helper ||= Object.new.extend(ActionView::Helpers::TagHelper, Classy::Yaml::Helpers)
  end

  def yass_with_warnings(args)
    logger = WarningCounter.new
    original = Rails.logger
    Rails.logger = logger
    [ helper.yass(*args), logger.warnings ]
  ensure
    Rails.logger = original
  end

  # JSON keys become Symbols, as Ruby callers write them; classy_files paths are relative to DIR.
  def resolve(value)
    case value
    when Hash
      value.to_h do |key, child|
        key = key.to_sym
        [ key, key == :classy_files ? child.map { |file| DIR.join(file).to_s } : resolve(child) ]
      end
    when Array then value.map { |child| resolve(child) }
    else value
    end
  end

  def with_suite(suite)
    saved = [ Classy::Yaml.engine_files, Classy::Yaml.default_file, Classy::Yaml.extra_files ]
    Classy::Yaml.setup do |config|
      config.engine_files = suite["engine_files"].map { |file| DIR.join(file).to_s }
      config.default_file = DIR.join(suite["default_file"]).to_s
      config.extra_files = suite["extra_files"].map { |file| DIR.join(file).to_s }
    end
    yield
  ensure
    Classy::Yaml.setup do |config|
      config.engine_files = saved[0]
      config.default_file = saved[1]
      config.extra_files = saved[2]
    end
  end

  def compare(expected, actual)
    differences = []
    (expected.fetch("suites", {}).keys | actual.fetch("suites", {}).keys).each do |suite|
      differences.concat(compare_calls("[#{suite}]", expected.dig("suites", suite) || {}, actual.dig("suites", suite) || {}))
    end
    differences.concat(compare_calls("[class_names]", expected.fetch("class_names", {}), actual.fetch("class_names", {})))
  end

  def compare_calls(label, expected, actual)
    (expected.keys | actual.keys).filter_map do |name|
      next if expected[name] == actual[name]

      "#{label} #{name}\n  expected.json: #{expected[name].inspect}\n  gem:           #{actual[name].inspect}"
    end
  end
end
