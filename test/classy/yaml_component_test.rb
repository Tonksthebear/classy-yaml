require "test_helper"
require "view_component/test_case"

class Classy::YamlComponentTest < ViewComponent::TestCase
  test "can fetch single utility class" do
    render_inline(TestComponent.new classy: :single)
    assert_text "single-class"
  end

  test "can fetch nested utility classes" do
    render_inline(TestComponent.new classy: {nested_no_base: :nested})
    assert_text "nested-no-base-class"
  end

  test "can fetch multiple nested utility classes" do
    render_inline(TestComponent.new(classy: {nested_no_base: [:nested, :nested2]}))
    assert_text "nested-no-base-class nested2-class"
  end

  test "includes base if found to nested" do
    render_inline(TestComponent.new classy: {nested_base: :nested})
    assert_text "nested-base-class nested-class"
  end

  test "can fetch multiple at same time" do
    render_inline(TestComponent.new classy: [:single, nested_no_base: :nested])
    assert_text "single-class nested-no-base-class"
  end

  test "can override single utility class" do
    render_inline(TestComponent.new classy: :overrideable)
    assert_text "component-class"
  end

  test "can override nested utility classes" do
    render_inline(TestComponent.new classy: {overrideable_nested: :nested})
    assert_text "component-nested-base-class"
    assert_text "component-nested-class"
  end

  test "can override multiple nested utility classes" do
    render_inline(TestComponent.new(classy: {overrideable_nested: [:nested, :nested2]}))
    assert_text "component-nested-base-class"
    assert_text "component-nested-class"
    assert_text "component-nested2-class"
  end

  test "can override with original base" do
    render_inline(TestComponent.new(classy: {overrideable_no_base_nested: :nested}))
    assert_text "overrideable-no-base-class"
    assert_text "component-no-base-nested-class"
  end
end
