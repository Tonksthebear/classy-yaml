class TestComponent < ApplicationComponent
  def call
    @inherited ? inherited_call : yass(@classy)
  end

  class NestedComponent < TestComponent
    def call
      @inherited ? inherited_call : yass(@classy)
    end
  end
end
