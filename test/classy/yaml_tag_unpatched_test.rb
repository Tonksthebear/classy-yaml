require "test_helper"

class Classy::YamlTagUnpatchedTest < ActionView::TestCase
  setup do
    Classy::Yaml.setup do |config|
      config.default_file = "config/utility_classes.yml"
      config.extra_files = []
      config.engine_files = []
      config.override_tag_helpers = false
    end
  end

  test "tag helper override is disabled by default" do
    assert_equal false, Classy::Yaml.override_tag_helpers
  end

  test "configuration can be set to false" do
    Classy::Yaml.override_tag_helpers = false
    assert_equal false, Classy::Yaml.override_tag_helpers
  end

  test "yass helper still works when override is disabled" do
    # The yass helper should still work directly even when override is disabled
    result = yass(:single)
    assert_equal "single-class", result
  end

  test "yass helper works with arrays when override is disabled" do
    result = yass([ :single, :array ])
    assert_includes result, "single-class"
    assert_includes result, "array-class"
    assert_includes result, "array-class2"
  end
end
