module VGD
  module Reference
    module QuickMovePrototype
      ENABLED = false
      MK_RBUTTON = 2

      module_function

      def on_mouse_move(flags, x, y, view)
        unless ENABLED && Session.store && (flags.to_i & MK_RBUTTON) != 0
          @last_point = nil
          return
        end
        logical_x, logical_y = ScreenCoordinates.from_event(x, y, view)
        item = Session.store.hit_test_order.find do |candidate|
          logical_x >= candidate.x && logical_x <= candidate.x + candidate.width &&
            logical_y >= candidate.y && logical_y <= candidate.y + candidate.height
        end
        return unless item
        previous = @last_point
        @last_point = [logical_x, logical_y]
        return unless previous
        item.move_by(logical_x - previous[0], logical_y - previous[1])
        view.invalidate
      rescue StandardError => error
        ImageLoader.log_error('RMB quick-move prototype failed', error)
      end
    end
  end
end
