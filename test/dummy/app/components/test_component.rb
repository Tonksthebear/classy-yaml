class TestComponent < ApplicationComponent
  def call
    @inherited ? inherited_call : yass(@classy)
  end
end
