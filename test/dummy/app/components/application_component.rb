class ApplicationComponent < ViewComponent::Base
  include Classy::Yaml::ComponentHelpers
  def initialize(classy:, inherited: false)
    @classy = classy
    @inherited = inherited
  end

  def inherited_call
    yass(@classy)
  end
end
