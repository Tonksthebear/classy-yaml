require "test_helper"
include Classy::Yaml::Helpers

class Classy::YamlTest < ActiveSupport::TestCase
  setup do
    Classy::Yaml.setup do |config|
      config.default_file = "config/utility_classes.yml"
      config.extra_files = []
      config.engine_files = []
      config.override_tag_helpers = false
    end
  end

  teardown do
    # Reset configuration to default state after each test
    Classy::Yaml.setup do |config|
      config.override_tag_helpers = false
    end
  end

  test "can fetch single utility class" do
    assert_equal "single-class", yass(:single)
  end

  test "can fetch nested utility classes" do
    assert_equal "nested-no-base-class", yass(nested_no_base: :nested)
  end

  test "can fetch multiple nested utility classes" do
    assert_equal "nested-no-base-class nested2-class", yass(nested_no_base: [ :nested, :nested2 ])
  end

  test "includes base if found to nested" do
    assert_equal "nested-base-class nested-class", yass(nested_base: :nested)
  end

  test "can fetch multiple at same time" do
    assert_equal "single-class nested-no-base-class", yass(:single, nested_no_base: :nested)
  end

  test "can call non-existent class" do
    yass(:non_existent)
    assert true
  end

  test "can call non-existent nested class" do
    yass(non_existent: :nested)
    assert true
  end

  test "can call existent base with non-existent nested class" do
    yass(nested_base: :non_existent)
    assert true
  end

  test "Log warning error when calling nested on non-nested" do
    original_logger = Rails.logger

    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    yass(single: :non_existent)

    Rails.logger = original_logger

    # More flexible assertion that accounts for different Rails logging formats
    assert_match /WARN.*yass called with invalid keys/, log_output.string, "Should log a warning about invalid keys"
    assert_match /single.*non_existent/, log_output.string, "Should mention the invalid keys in the log"
  end

  test "can overwrite the default file classy looks for" do
    existing_default = Classy::Yaml.default_file

    Classy::Yaml.setup do |config|
      config.default_file = "config/non_default_classes.yml"
    end

    assert_empty yass(:single)
    assert_equal "new-single-class", yass(:new_single)

    Classy::Yaml.setup do |config|
      config.default_file = existing_default
    end
  end

  test "can add extra utility files for classy to look for" do
    Classy::Yaml.setup do |config|
      config.extra_files = "config/extra_utility_classes.yml"
    end

    assert_equal "single-class", yass(:single)
    assert_equal "extra-single-class", yass(:extra_single)
  end

  test "can add engine utility files that are overridden by default and extra classes" do
    Classy::Yaml.setup do |config|
      config.engine_files = "config/engine_utility_classes.yml"
      config.extra_files = "config/extra_utility_classes.yml"
    end

    assert_equal "engine-no-override-class", yass(:engine_no_override)
    assert_equal "default-overridden-class", yass(:engine_default_override)
    assert_equal "extra-overidden-class", yass(:engine_extra_override)
  end

  test "allow skipping of base" do
    assert_equal "nested-class", yass(nested_base: :nested, skip_base: true)
  end

  test "can fetch array of classes" do
    assert_equal "array-class array-class2", yass(:array)
  end

  test "can fetch array of classes with overrides" do
    assert_equal "array-override-this array-override-this2", yass(:array_override)

    Classy::Yaml.setup do |config|
      config.extra_files = "config/extra_utility_classes.yml"
    end

    assert_equal "array-override-class array-override-class2", yass(:array_override)
  end

  test "caching behavior in development environment" do
    # Force development environment, which reloads code
    original_env = Rails.env
    original_cache_classes = Rails.application.config.cache_classes
    Rails.env = ActiveSupport::StringInquirer.new("development")
    Rails.application.config.cache_classes = false

    # First call should load from disk
    first_result = yass(:single)

    # Modify the YAML file
    original_content = File.read(Rails.root.join("config/utility_classes.yml"))
    File.write(Rails.root.join("config/utility_classes.yml"), "single: \"modified-class\"")

    # The changed file should replace the cached YAML.
    second_result = yass(:single)

    # Restore original content
    File.write(Rails.root.join("config/utility_classes.yml"), original_content)

    # Restore original environment
    Rails.env = original_env
    Rails.application.config.cache_classes = original_cache_classes

    assert_equal "single-class", first_result
    assert_equal "modified-class", second_result
  end

  test "caching behavior in production environment" do
    # Force production environment
    original_env = Rails.env
    Rails.env = ActiveSupport::StringInquirer.new("production")

    # First call should load from disk and cache
    first_result = yass(:single)

    # Modify the YAML file
    original_content = File.read(Rails.root.join("config/utility_classes.yml"))
    File.write(Rails.root.join("config/utility_classes.yml"), "single: \"modified-class\"")

    # Second call should use cached value
    second_result = yass(:single)

    # Restore original content
    File.write(Rails.root.join("config/utility_classes.yml"), original_content)

    # Restore original environment
    Rails.env = original_env

    assert_equal "single-class", first_result
    assert_equal "single-class", second_result
  end

  test "caching is cleared when configuration changes" do
    # Force production environment
    original_env = Rails.env
    Rails.env = ActiveSupport::StringInquirer.new("production")

    # First call should load from disk and cache
    first_result = yass(:single)

    # Change configuration
    Classy::Yaml.setup do |config|
      config.default_file = "config/non_default_classes.yml"
    end

    second_result = yass(:new_single)


    # Restore original configuration
    Classy::Yaml.setup do |config|
      config.default_file = "config/utility_classes.yml"
    end

    # Restore original environment
    Rails.env = original_env

    assert_equal "single-class", first_result
    assert_equal "new-single-class", second_result
  end

  test "override_tag_helpers configuration option" do
    # Reset to default configuration first
    Classy::Yaml.setup do |config|
      config.override_tag_helpers = false
    end

    # Test that the configuration option exists and defaults to false
    assert_equal false, Classy::Yaml.override_tag_helpers

    # Test that we can set it to true
    Classy::Yaml.override_tag_helpers = true
    assert_equal true, Classy::Yaml.override_tag_helpers

    # Test that we can set it back to false
    Classy::Yaml.override_tag_helpers = false
    assert_equal false, Classy::Yaml.override_tag_helpers
  end


  test "tag helper override can be toggled on and off" do
    # Test that we can set it to true
    Classy::Yaml.override_tag_helpers = true
    assert_equal true, Classy::Yaml.override_tag_helpers

    # Test that we can set it back to false
    Classy::Yaml.override_tag_helpers = false
    assert_equal false, Classy::Yaml.override_tag_helpers
  end

  test "tailwind_merge is enabled when tailwind_merge gem is available" do
    helper = Classy::Yaml::Helpers

    helper.instance_variable_set(:@tailwind_merge_available, true)
    result = helper.yass(:single, :array, add: "px-1 p-2")
    assert_includes result, "single-class"
    assert_includes result, "array-class"
    assert_includes result, "array-class2"
    assert_not_includes result, "px-1"
    assert_includes result, "p-2"

    helper.instance_variable_set(:@tailwind_merge_available, false)
    result = helper.yass(:single, :array, add: "px-1 p-2")
    assert_includes result, "single-class"
    assert_includes result, "array-class"
    assert_includes result, "array-class2"
    assert_includes result, "px-1"
    assert_includes result, "p-2"
  end

  test "add classes have highest priority over yaml classes" do
    # Test without TailwindMerge - add classes should appear last in the string
    result = yass(:single, add: "override-class")
    assert_equal "single-class override-class", result

    # Test with multiple yaml classes and add classes - add should come last
    result = yass(:single, :array, add: "additional-class extra-class")
    assert_equal "single-class array-class array-class2 additional-class extra-class", result
  end

  test "add classes appear after yaml classes in output order" do
    # Verify the order is: [yaml classes] then [add classes]
    result = yass(:array, add: "first-add second-add")

    # Split result and check that yaml classes come before add classes
    classes = result.split(" ")
    yaml_end_index = classes.rindex("array-class2")
    add_start_index = classes.index("first-add")

    assert yaml_end_index < add_start_index, "Add classes should come after yaml classes"
  end

  test "arguments can be frozen and reused without losing added classes" do
    choices = [ :nested, :nested2 ].freeze
    options = { nested_no_base: choices, add: "extra-class" }.freeze
    arguments = [ options ].freeze

    2.times do
      assert_equal "nested-no-base-class nested2-class extra-class", yass(arguments)
    end
    assert_equal [ :nested, :nested2 ], choices
    assert_equal "extra-class", options[:add]
  end

  test "control options do not become YAML lookup keys" do
    keys, additions = flatten_args(values: [
      { nested_base: :nested, skip_base: true, classy_files: [ "config/classes.yml" ], add: "px-2" }
    ])

    assert_equal [ [ "nested_base", "nested" ], [ "nested_base" ] ], keys
    assert_equal [ "px-2" ], additions
  end

  test "deep paths keep the full parent path" do
    keys, = flatten_args(values: [ { button: { size: :small } } ])
    yamls = [ {
      "button" => { "base" => "button-base", "size" => { "base" => "size-base", "small" => "small-class" } },
      "size" => "unrelated-class"
    } ]

    assert_equal [ [ "button", "size", "small" ], [ "button", "size" ], [ "button" ] ], keys
    assert_equal [ "size-base", "small-class", "button-base" ], fetch_classes(keys, classy_yamls: yamls)
  end

  test "added classes work without any YAML files" do
    Classy::Yaml.default_file = "config/does-not-exist.yml"
    assert_equal "extra-class", yass(add: "extra-class")
  end

  test "base and specific classes fall back independently" do
    lower = { "button" => { "base" => "lower-base", "small" => "lower-small" } }
    upper = { "button" => { "small" => "upper-small" } }
    assert_equal [ "lower-base", "upper-small" ], fetch_classes([ [ "button", "small" ] ], classy_yamls: [ lower, upper ])

    upper = { "button" => { "base" => "upper-base", "small" => "" } }
    assert_equal [ "upper-base", "lower-small" ], fetch_classes([ [ "button", "small" ] ], classy_yamls: [ lower, upper ])
  end

  test "lookup stops when the highest priority file supplies all requested classes" do
    lower = Object.new
    def lower.dig(*)
      raise "The lower priority file must not be read"
    end
    upper = { "button" => { "base" => "upper-base", "small" => "upper-small" } }
    log_output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = Logger.new(log_output)

    assert_equal [ "upper-base", "upper-small" ], fetch_classes([ [ "button", "small" ] ], classy_yamls: [ lower, upper ])
    assert_equal [ "upper-small" ], fetch_classes([ [ "button", "small" ] ], classy_yamls: [ lower, upper ], skip_base: true)
    assert_empty log_output.string
  ensure
    Rails.logger = original_logger
  end
end
