require "test_helper"

begin
  require "rails_icons"
rescue LoadError
  # rails_icons not available in this appraisal
end

return unless defined?(RailsIcons)

class Classy::YamlIconHelperTest < ActionView::TestCase
  helper RailsIcons::Helpers::IconHelper

  setup do
    Classy::Yaml.setup do |config|
      config.default_file = "config/utility_classes.yml"
      config.extra_files = []
      config.engine_files = []
      config.override_tag_helpers = true
    end
  end

  teardown do
    Classy::Yaml.setup do |config|
      config.override_tag_helpers = false
    end
  end

  test "icon helper override is applied when rails_icons is present" do
    assert RailsIcons::Helpers::IconHelper.ancestors.include?(Classy::Yaml::IconHelper)
  end

  test "icon helper converts symbol class to yass result" do
    result = icon("star", variant: :solid, class: :single)
    assert_includes result, 'class="single-class"'
  end

  test "icon helper converts hash class to yass result" do
    result = icon("star", variant: :solid, class: { nested_no_base: :nested })
    assert_includes result, 'class="nested-no-base-class"'
  end

  test "icon helper converts array class to yass result" do
    result = icon("star", variant: :solid, class: [ :single, :array ])
    assert_includes result, "single-class"
    assert_includes result, "array-class"
    assert_includes result, "array-class2"
  end

  test "icon helper passes string class through unchanged" do
    result = icon("star", variant: :solid, class: "existing-class")
    assert_includes result, 'class="existing-class"'
  end

  test "icon helper preserves other arguments" do
    result = icon("star", variant: :solid, class: :single, data: { controller: "test" })
    assert_includes result, 'class="single-class"'
    assert_includes result, 'data-controller="test"'
  end
end
