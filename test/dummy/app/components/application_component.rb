class ApplicationComponent < ViewComponent::Base
  include Classy::Yaml::ComponentHelpers
  attr_reader :class_count

  def initialize(classy:, inherited: false)
    @classy = classy
    @inherited = inherited
  end

  def inherited_classes
    @inherited_classes ||= yass(@classy)
  end

  def class_count
    @class_count ||= @inherited ? inherited_classes&.split(" ")&.length : classes&.split(" ").length
  end

  def inherited_call
    inherited_classes
  end
end
