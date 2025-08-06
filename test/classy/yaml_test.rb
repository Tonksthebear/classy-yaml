require "test_helper"
include Classy::Yaml::Helpers

class Classy::YamlTest < ActiveSupport::TestCase
  setup do
    Classy::Yaml.setup do |config|
      config.default_file = "config/utility_classes.yml"
      config.extra_files = []
      config.engine_files = []
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

    assert_match /WARN.*yass called with invalid keys: \{:data=>\[\"single\", \"non_existent\"\]\}/, log_output.string
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
    # Force development environment
    original_env = Rails.env
    Rails.env = ActiveSupport::StringInquirer.new("development")

    # First call should load from disk
    first_result = yass(:single)

    # Modify the YAML file
    original_content = File.read(Rails.root.join("config/utility_classes.yml"))
    File.write(Rails.root.join("config/utility_classes.yml"), "single: \"modified-class\"")

    # Second call should load from disk again (no caching)
    second_result = yass(:single)

    # Restore original content
    File.write(Rails.root.join("config/utility_classes.yml"), original_content)

    # Restore original environment
    Rails.env = original_env

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

  test "tag helper override is applied when enabled" do
    # Enable tag helper override
    Classy::Yaml.setup do |config|
      config.override_tag_helpers = true
    end

    # Test that the override method exists in ActionView::Helpers::TagHelper::TagBuilder
    assert ActionView::Helpers::TagHelper::TagBuilder.method_defined?(:classy_yaml_original_tag_options)
  end

  test "tag helper automatically converts symbol class to yass result" do
    # Enable tag helper override
    Classy::Yaml.setup do |config|
      config.override_tag_helpers = true
    end

    # Create a test helper instance using the test app's view context
    helper = ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil)
    helper.extend(Classy::Yaml::Helpers)

    # Test that a symbol class gets converted to yass result
    result = helper.tag.div(class: :single)
    assert_includes result, "single-class"
    assert_includes result, 'class="single-class"'
  end

  test "tag helper automatically converts hash class to yass result" do
    # Enable tag helper override
    Classy::Yaml.setup do |config|
      config.override_tag_helpers = true
    end

    # Create a test helper instance using the test app's view context
    helper = ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil)
    helper.extend(Classy::Yaml::Helpers)

    # Test that a hash class gets converted to yass result
    result = helper.tag.div(class: { nested_no_base: :nested })
    assert_includes result, "nested-no-base-class"
    assert_includes result, 'class="nested-no-base-class"'
  end

  test "tag helper processes nested hash classes correctly" do
    # Enable tag helper override
    Classy::Yaml.setup do |config|
      config.override_tag_helpers = true
    end

    # Create a test helper instance using the test app's view context
    helper = ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil)
    helper.extend(Classy::Yaml::Helpers)

    # Test that nested hash classes work correctly
    result = helper.tag.div(class: { nested_base: :nested })
    assert_includes result, "nested-base-class"
    assert_includes result, "nested-class"
    assert_includes result, 'class="nested-base-class nested-class"'
  end

  test "tag helper does not convert string class values" do
    # Enable tag helper override
    Classy::Yaml.setup do |config|
      config.override_tag_helpers = true
    end

    # Create a test helper instance using the test app's view context
    helper = ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil)
    helper.extend(Classy::Yaml::Helpers)

    # Test that string class values are left unchanged
    result = helper.tag.div(class: "existing-class")
    assert_includes result, 'class="existing-class"'
    assert_not_includes result, "single-class"
  end

  test "tag helper does not convert array class values" do
    # Enable tag helper override
    Classy::Yaml.setup do |config|
      config.override_tag_helpers = true
    end

    # Create a test helper instance using the test app's view context
    helper = ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil)
    helper.extend(Classy::Yaml::Helpers)

    # Test that array class values are left unchanged
    result = helper.tag.div(class: [ "class1", "class2" ])
    assert_includes result, 'class="class1 class2"'
    assert_not_includes result, "single-class"
  end

  test "tag helper works with multiple options" do
    # Enable tag helper override
    Classy::Yaml.setup do |config|
      config.override_tag_helpers = true
    end

    # Create a test helper instance using the test app's view context
    helper = ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil)
    helper.extend(Classy::Yaml::Helpers)

    # Test that other options are preserved
    result = helper.tag.div(class: :single, id: "test-id", data: { test: "value" })
    assert_includes result, 'class="single-class"'
    assert_includes result, 'id="test-id"'
    assert_includes result, 'data-test="value"'
  end

  test "tag helper override is disabled by default" do
    # Reset to default configuration and clear any existing override
    Classy::Yaml.setup do |config|
      config.override_tag_helpers = false
    end

    # Clear the override by removing the method
    if ActionView::Helpers::TagHelper::TagBuilder.method_defined?(:classy_yaml_original_tag_options)
      ActionView::Helpers::TagHelper::TagBuilder.class_eval do
        alias_method :tag_options, :classy_yaml_original_tag_options
        remove_method :classy_yaml_original_tag_options
      end
    end

    # Create a test helper instance using the test app's view context
    helper = ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil)
    helper.extend(Classy::Yaml::Helpers)

    # Test that symbol class values are not converted when disabled
    result = helper.tag.div(class: :single)
    # Should contain the symbol as-is, not the yass result
    assert_includes result, 'class="single"'
    assert_not_includes result, "single-class"
  end

  test "tag helper override can be toggled on and off" do
    # Create a test helper instance using the test app's view context
    helper = ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil)
    helper.extend(Classy::Yaml::Helpers)

    # Test with override disabled
    Classy::Yaml.setup do |config|
      config.override_tag_helpers = false
    end

    # Clear the override by removing the method
    if ActionView::Helpers::TagHelper::TagBuilder.method_defined?(:classy_yaml_original_tag_options)
      ActionView::Helpers::TagHelper::TagBuilder.class_eval do
        alias_method :tag_options, :classy_yaml_original_tag_options
        remove_method :classy_yaml_original_tag_options
      end
    end

    result_disabled = helper.tag.div(class: :single)
    assert_includes result_disabled, 'class="single"'
    assert_not_includes result_disabled, "single-class"

    # Test with override enabled
    Classy::Yaml.setup do |config|
      config.override_tag_helpers = true
    end

    result_enabled = helper.tag.div(class: :single)
    assert_includes result_enabled, 'class="single-class"'
    assert_not_includes result_enabled, 'class="single"'
  end
end
