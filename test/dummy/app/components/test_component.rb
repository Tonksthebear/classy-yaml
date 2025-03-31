class TestComponent < ApplicationComponent
  def before_render
    @classes = @inherited ? inherited_call : yass(@classy)
    @class_count = @classes.split(" ").length
  end

  def classes
    @classes ||= @inherited ? inherited_classes : yass(@classy)
  end

  def call
    @inherited ? inherited_call : classes
  end

  class NestedComponent < TestComponent
    def classes
      @classes ||= @inherited ? inherited_classes : yass(@classy)
    end

    def call
      @inherited ? inherited_call : classes
    end
  end
end
