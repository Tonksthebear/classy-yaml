require "test_helper"
require "view_component/test_case"

class Classy::YamlComponentTest < ViewComponent::TestCase
  test "can fetch single utility class" do
    component = TestComponent.new classy: :single
    render_inline component
    assert_text "single-class"
    assert_equal component.class_count, 1
  end

  test "can fetch nested utility classes" do
    component = TestComponent.new classy: { nested_no_base: :nested }
    render_inline component
    assert_text "nested-no-base-class"
    assert_equal component.class_count, 1
  end

  test "can fetch multiple nested utility classes" do
    component = TestComponent.new classy: { nested_no_base: [ :nested, :nested2 ] }
    render_inline component
    assert_text "nested-no-base-class nested2-class"
    assert_equal component.class_count, 2
  end

  test "includes base if found to nested" do
    component = TestComponent.new classy: { nested_base: :nested }
    render_inline component
    assert_text "nested-base-class nested-class"
    assert_equal component.class_count, 2
  end

  test "can fetch multiple at same time" do
    component = TestComponent.new classy: [ :single, nested_no_base: :nested ]
    render_inline component
    assert_text "single-class nested-no-base-class"
    assert_equal component.class_count, 2
  end

  test "can override single utility class" do
    component = TestComponent.new classy: :overrideable
    render_inline component
    assert_text "component-class"
    assert_equal component.class_count, 1
  end

  test "can override non-base but keep inherited base" do
    component = TestComponent.new classy: { overrideable_nested: :nested }
    render_inline component
    assert_text "overrideable-base-class"
    assert_text "component-nested-class"
    assert_equal component.class_count, 2
  end

  test "can override nested utility classes" do
    component = TestComponent.new classy: { overrideable_base_nested: :nested }
    render_inline component
    assert_text "component-base-nested-base-class"
    assert_text "component-base-nested-class"
    assert_equal component.class_count, 2
  end

  test "can override multiple nested utility classes" do
    component = TestComponent.new classy: { overrideable_base_nested: [ :nested, :nested2 ] }
    render_inline component
    assert_text "component-base-nested-base-class"
    assert_text "component-base-nested-class"
    assert_text "component-base-nested2-class"
    assert_equal component.class_count, 3
  end

  test "can override with original base" do
    component = TestComponent.new classy: { overrideable_no_base_nested: :nested }
    render_inline component
    assert_text "overrideable-no-base-class"
    assert_text "component-no-base-nested-class"
    assert_equal component.class_count, 2
  end

  test "can find definitions through inherited function call" do
    component = TestComponent.new classy: :inherited, inherited: true
    render_inline component
    assert_text "inherited"
    assert_equal component.class_count, 1
  end

  test "can find parent component utility classes" do
    component = TestComponent::NestedComponent.new classy: :inherited
    render_inline component
    assert_text "inherited"
    assert_equal component.class_count, 1
  end

  test "can find nested component utility classes" do
    component = TestComponent::NestedComponent.new classy: :nested
    render_inline component
    assert_text "nested"
    assert_equal component.class_count, 1
  end

  test "can find nested component utility classes through inherited function call" do
    component = TestComponent::NestedComponent.new classy: :nested_inherited, inherited: true
    render_inline component
    assert_text "nested-inherited"
    assert_equal component.class_count, 1
  end

  test "can skip base" do
    component = TestComponent.new classy: { overrideable_base_nested: :nested, skip_base: true }
    render_inline component
    assert_text "component-base-nested-class"
    assert_equal component.class_count, 1
  end
end
