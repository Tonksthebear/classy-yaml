require "test_helper"

class Classy::YamlTagPatchTest < ActionView::TestCase
  setup do
    Classy::Yaml.setup do |config|
      config.default_file = "config/utility_classes.yml"
      config.extra_files = []
      config.engine_files = []
      config.override_tag_helpers = true
    end
  end

  teardown do
    # Reset configuration to default state
    Classy::Yaml.setup do |config|
      config.override_tag_helpers = false
    end
  end

  test "tag helper converts string array class values" do
    # Test that string array class values are processed by yass
    result = tag.div(class: [ "single", "array" ])
    assert_includes result, "single-class"
    assert_includes result, "array-class"
    assert_includes result, "array-class2"
    assert_includes result, 'class="single-class array-class array-class2"'
  end

  test "tag helper works with multiple options" do
    result = tag.div(class: :single, id: "test-id", data: { test: "value" })
    assert_includes result, 'class="single-class"'
    assert_includes result, 'id="test-id"'
    assert_includes result, 'data-test="value"'
  end

  test "tag helper override is applied when enabled" do
    # Test that the override method exists in ActionView::Helpers::TagHelper::TagBuilder
    assert ActionView::Helpers::TagHelper::TagBuilder.ancestors.include?(Classy::Yaml::TagHelper)
  end

  test "tag helper automatically converts symbol class to yass result" do
    # Test that a symbol class gets converted to yass result
    result = tag.div(class: :single)
    assert_includes result, "single-class"
    assert_includes result, 'class="single-class"'
  end

  test "tag helper automatically converts hash class to yass result" do
    # Test that a hash class gets converted to yass result
    result = tag.div(class: { nested_no_base: :nested })
    assert_includes result, "nested-no-base-class"
    assert_includes result, 'class="nested-no-base-class"'
  end

  test "tag helper automatically converts array class to yass result" do
    # Test that an array class gets converted to yass result
    result = tag.div(class: [ :single, :array ])
    assert_includes result, "single-class"
    assert_includes result, "array-class"
    assert_includes result, "array-class2"
    assert_includes result, 'class="single-class array-class array-class2"'
  end

  test "tag helper converts mixed string and symbol arrays" do
    # Test that mixed arrays get converted to yass result
    result = tag.div(class: [ "single", :array ])
    assert_includes result, "single-class"
    assert_includes result, "array-class"
    assert_includes result, "array-class2"
    assert_includes result, 'class="single-class array-class array-class2"'
  end

  test "tag helper processes nested hash classes correctly" do
    # Test that nested hash classes work correctly
    result = tag.div(class: { nested_base: :nested })
    assert_includes result, "nested-base-class"
    assert_includes result, "nested-class"
    assert_includes result, 'class="nested-base-class nested-class"'
  end

  test "tag helper does not convert string class values" do
    # Test that string class values are left unchanged
    result = tag.div(class: "existing-class")
    assert_includes result, 'class="existing-class"'
    assert_not_includes result, "single-class"
  end

  test "form and url helpers work with override" do
    # Test text_field_tag with symbol class
    text_result = text_field_tag(:name, "value", class: :single)
    assert_includes text_result, "single-class", "Failed to override text_field_tag with symbol class"
    assert_includes text_result, 'class="single-class"', "Failed to override text_field_tag with symbol class"

    # Test text_field_tag with array classes
    text_array_result = text_field_tag(:name, "value", class: [ :single, :array ])
    assert_includes text_array_result, "single-class", "Failed to override text_field_tag with array classes"
    assert_includes text_array_result, "array-class", "Failed to override text_field_tag with array classes"
    assert_includes text_array_result, "array-class2", "Failed to override text_field_tag with array classes"
    assert_includes text_array_result, 'class="single-class array-class array-class2"', "Failed to override text_field_tag with array classes"

    # Test select_tag with symbol class
    select_result = select_tag(:name, "<option value='1'>Option 1</option>", class: :single)
    assert_includes select_result, "single-class", "Failed to override select_tag with symbol class"
    assert_includes select_result, 'class="single-class"', "Failed to override select_tag with symbol class"

    # Test password_field_tag with symbol class
    password_result = password_field_tag(:password, nil, class: :single)
    assert_includes password_result, "single-class", "Failed to override password_field_tag with symbol class"
    assert_includes password_result, 'class="single-class"', "Failed to override password_field_tag with symbol class"

    # Test button_tag with symbol class
    button_result = button_tag("Click me", class: :single)
    assert_includes button_result, "single-class", "Failed to override button_tag with symbol class"
    assert_includes button_result, 'class="single-class"', "Failed to override button_tag with symbol class"

    # Test button_tag with array classes
    button_array_result = button_tag("Click me", class: [ :single, :array ])
    assert_includes button_array_result, "single-class", "Failed to override button_tag with array classes"
    assert_includes button_array_result, "array-class", "Failed to override button_tag with array classes"
    assert_includes button_array_result, "array-class2", "Failed to override button_tag with array classes"
    assert_includes button_array_result, 'class="single-class array-class array-class2"', "Failed to override button_tag with array classes"

    # Test link_to with symbol class
    link_result = link_to("Click here", "/path", class: :single)
    assert_includes link_result, "single-class", "Failed to override link_to with symbol class"
    assert_includes link_result, 'class="single-class"', "Failed to override link_to with symbol class"
  end

  test "multiple helpers work together with override" do
    # Test multiple helpers in sequence
    text_result = text_field_tag(:name, "value", class: :single)
    select_result = select_tag(:category, "<option>Test</option>", class: { nested_no_base: :nested })
    button_result = button_tag("Submit", class: :single)

    # Verify all results have processed classes
    assert_includes text_result, 'class="single-class"'
    assert_includes select_result, 'class="nested-no-base-class"'
    assert_includes button_result, 'class="single-class"'
  end
end
