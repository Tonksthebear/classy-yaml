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

  test "can overwrite the default file classy looks for" do
    existing_default = Classy::Yaml.default_file

    Classy::Yaml.setup do |config|
      config.default_file = "config/non_default_classes.yml"
    end

    assert_empty yass(:single)
    assert_equal 'new-single-class', yass(:new_single)

    Classy::Yaml.setup do |config|
      config.default_file = existing_default
    end
  end

  test "can add extra utility files for classy to look for" do
    Classy::Yaml.setup do |config|
      config.extra_files = "config/extra_utility_classes.yml"
    end

    assert_equal "single-class", yass(:single)
    assert_equal 'extra-single-class', yass(:extra_single)
  end
end
