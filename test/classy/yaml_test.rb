require "test_helper"
include Classy::Yaml::Helpers

class Classy::YamlTest < ActiveSupport::TestCase
  test "can fetch single utility class" do
    assert_equal "single-class", yass(:single)
  end

  test "can fetch nested utility classes" do
    assert_equal "nested-no-base-class", yass(nested_no_base: :nested)
  end

  test "can fetch multiple nested utility classes" do
    assert_equal "nested-no-base-class nested2-class", yass(nested_no_base: [:nested, :nested2])
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

  test "raise error when calling nested on non-nested" do
    assert_raises(Classy::Yaml::InvalidKeyError) do
      yass(single: :non_existent)
    end
  end
end
