module VGD
  module Reference
    module ScreenCoordinates
      module_function

      def scale(view = nil)
        return 1.0 if Sketchup.version.to_i >= 25
        factor = if view && UI.respond_to?(:scale_factor)
                   begin
                     UI.scale_factor(view)
                   rescue ArgumentError
                     UI.scale_factor
                   end
                 else
                   UI.scale_factor
                 end
        factor = factor.to_f
        factor.positive? ? factor : 1.0
      rescue StandardError
        1.0
      end

      def from_event(x, y, view = nil)
        divisor = Sketchup.version.to_i >= 25 ? 1.0 : scale(view)
        [x.to_f / divisor, y.to_f / divisor]
      end

      def to_draw_space(x, y, view = nil)
        multiplier = Sketchup.version.to_i >= 25 ? 1.0 : scale(view)
        [x.to_f * multiplier, y.to_f * multiplier]
      end

      def viewport_size(view)
        [view.vpwidth.to_f / scale_for_viewport(view), view.vpheight.to_f / scale_for_viewport(view)]
      end

      def scale_for_viewport(view)
        Sketchup.version.to_i >= 25 ? 1.0 : scale(view)
      end
    end
  end
end
