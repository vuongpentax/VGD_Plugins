module VGD
  module Reference
    # Sketchup::View has invalidate, but has no valid? method. Keep the fake
    # deliberately limited to the real methods this redraw path needs.
    class RedrawFixtureView
      attr_reader :invalidations

      def initialize
        @invalidations = 0
      end

      def invalidate
        @invalidations += 1
      end
    end

    previous_model = Session.instance_variable_get(:@model)
    begin
      view = RedrawFixtureView.new
      Session.instance_variable_set(:@model, Struct.new(:active_view).new(view))
      Session.redraw
      raise 'Redraw failed with the real View API shape.' unless view.invalidations == 1
      puts 'PASS: redraw uses View#invalidate without an unsupported View#valid? call.'
    ensure
      Session.instance_variable_set(:@model, previous_model)
    end
  end
end
