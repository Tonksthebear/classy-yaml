class TestComponent < ViewComponent::Base
  include Classy::Yaml::ComponentHelpers

  def initialize(classy:)
    @classy = classy
  end

  def call
    yass(@classy)
  end
end
