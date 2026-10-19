module VGD
  module Reference
    class InteractionTool
      def suspend(view)
        view.invalidate
      end
      MODE_IDLE = :idle
      MODE_MOVE = :move
      MODE_RESIZE = :resize
      MODE_PAN = :pan
      MODE_CROP = :crop
      MODE_ROTATE = :rotate
      VK_ESCAPE = 27
      VK_DELETE = 46
      VK_ENTER = 13
      VK_SPACE = 32
      MK_LBUTTON = 1
      MK_RBUTTON = 2
      MK_SHIFT = 4
      RMB_DRAG_THRESHOLD = 3.0

      attr_reader :item_id

      def initialize(item_id, restore_locked: false)
        @item_id = item_id.to_s
        @restore_locked = !!restore_locked
        @mode = MODE_IDLE
        @dragging = false
        @space_down = false
        @last_point = nil
        @cropper = nil
        @resize_anchor = nil
        @resize_sign = nil
        @cursor_kind = nil
      end

      def activate
        Session.set_current_tool(self)
      end

      def deactivate(view)
        view.invalidate
        @cropper.cancel if @cropper && @mode == MODE_CROP
        @cropper = nil
        @mode = MODE_IDLE
        @dragging = false
        restore_passive_lock
        Session.tool_deactivated(self, view)
      rescue StandardError => error
        ImageLoader.log_error('Edit tool deactivation failed', error)
      end

      def draw(_view); end

      def crop_mode?
        @mode == MODE_CROP
      end

      def restore_passive_lock
        return unless @restore_locked
        item = Session.store && Session.store.find(@item_id)
        item.locked = true if item
        @restore_locked = false
      end

      def start_crop
        item = current_item
        return false unless item
        @cropper = CropController.new(item)
        center_x = item.x + item.width / 2.0
        center_y = item.y + item.height / 2.0
        item.height = item.width * item.image_height.to_f / item.image_width
        item.y = center_y - item.height / 2.0
        item.x = center_x - item.width / 2.0
        @mode = MODE_CROP
        Session.redraw
        true
      end

      def onMouseMove(flags, x, y, view)
        logical_x, logical_y = ScreenCoordinates.from_event(x, y, view)
        item = current_item
        return unless item
        update_cursor_kind(item, logical_x, logical_y)
        if @dragging && @last_point
          dx = logical_x - @last_point[0]
          dy = logical_y - @last_point[1]
          case @mode
          when MODE_MOVE
            item.move_by(dx, dy)
          when MODE_PAN
            local_dx, local_dy = item.inverse_transform_delta(dx, dy)
            item.pan_content(local_dx, local_dy)
          when MODE_RESIZE
            resize_x, resize_y = item.inverse_transform_point(logical_x, logical_y)
            resize_item(item, resize_x, resize_y)
          when MODE_CROP
            crop_x, crop_y = item.inverse_transform_point(logical_x, logical_y)
            @cropper.drag(@crop_edge, crop_x, crop_y) if @cropper && @crop_edge
          when MODE_ROTATE
            item.rotate_to(logical_x, logical_y, @rotation_start_pointer_angle, @rotation_start_angle,
                           snap: (flags.to_i & MK_SHIFT) != 0)
          end
          @last_point = [logical_x, logical_y]
          view.invalidate
        elsif @right_drag_pending && (flags.to_i & MK_RBUTTON) != 0
          dx = logical_x - @right_start_point[0]
          dy = logical_y - @right_start_point[1]
          if @right_drag_moved || Math.sqrt(dx * dx + dy * dy) >= RMB_DRAG_THRESHOLD
            item.move_by(dx, dy)
            @right_start_point = [logical_x, logical_y]
            @right_drag_moved = true
            view.invalidate
          end
        end
      rescue StandardError => error
        ImageLoader.log_error('Reference edit failed', error)
      end

      def onLButtonDown(flags, x, y, view)
        logical_x, logical_y = ScreenCoordinates.from_event(x, y, view)
        item = current_item
        return unless item && item.visible && !item.locked
        hit = HitTester.hit(item, logical_x, logical_y, crop: crop_mode?)
        return if hit == HitTester::NONE
        update_cursor_kind(item, logical_x, logical_y)
        @dragging = true
        @last_point = [logical_x, logical_y]
        if crop_mode?
          @crop_edge = hit if hit.to_s.start_with?('crop_')
        elsif hit == HitTester::ROTATE
          @mode = MODE_ROTATE
          center_x = item.x + item.width / 2.0
          center_y = item.y + item.height / 2.0
          @rotation_start_pointer_angle = Math.atan2(logical_y - center_y, logical_x - center_x) * 180.0 / Math::PI
          @rotation_start_angle = item.angle
        elsif @space_down
          @mode = MODE_PAN
        elsif hit.to_s.start_with?('resize_')
          begin_resize(item, hit)
        else
          @mode = MODE_MOVE
        end
      end

      def onLButtonUp(_flags, _x, _y, view)
        was_crop = crop_mode?
        @dragging = false
        @last_point = nil
        @resize_anchor = nil
        @resize_sign = nil
        @crop_edge = nil unless crop_mode?
        @mode = was_crop ? MODE_CROP : MODE_IDLE
        view.invalidate
      end

      def onRButtonDown(_flags, x, y, view)
        return if crop_mode?
        logical_x, logical_y = ScreenCoordinates.from_event(x, y, view)
        item = current_item
        return unless item && item.visible && !item.locked
        return if HitTester.hit(item, logical_x, logical_y) == HitTester::NONE
        @right_drag_pending = true
        @right_drag_moved = false
        @right_start_point = [logical_x, logical_y]
      end

      def onRButtonUp(_flags, _x, _y, view)
        @suppress_context_menu = !!@right_drag_moved
        @right_drag_pending = false
        @right_drag_moved = false
        @right_start_point = nil
        view.invalidate if view
      end

      def getMenu(menu, _flags, _x, _y, _view)
        return unless current_item
        return if @suppress_context_menu
        menu.add_item('Thoát chỉnh sửa ảnh tham chiếu') { Session.exit_edit }
      ensure
        @suppress_context_menu = false
      end

      def onLButtonDoubleClick(_flags, x, y, view)
        logical_x, logical_y = ScreenCoordinates.from_event(x, y, view)
        item = current_item
        return unless item && HitTester.hit(item, logical_x, logical_y) != HitTester::NONE
        item.reset_zoom
        view.invalidate
      end

      def onMouseWheel(_flags, delta, x, y, view)
        return false if crop_mode?
        logical_x, logical_y = ScreenCoordinates.from_event(x, y, view)
        item = current_item
        return false unless item && item.visible && !item.locked
        return false if HitTester.hit(item, logical_x, logical_y) == HitTester::NONE
        local_x, local_y = item.inverse_transform_point(logical_x, logical_y)
        item.zoom_at(local_x, local_y, delta.to_i >= 0 ? 0.82 : 1.22)
        view.invalidate
        true
      end

      def onKeyDown(key, _repeat, _flags, _view)
        if key.to_i == VK_SPACE
          @space_down = true
          @mode = MODE_PAN if @dragging
          return true
        end
        if key.to_i == VK_DELETE
          Session.delete_reference(@item_id)
          return true
        end
        if key.to_i == VK_ENTER && crop_mode?
          finish_crop(true)
          return true
        end
        key.to_i == VK_ESCAPE ? handle_escape : false
      end

      def onKeyUp(key, _repeat, _flags, _view)
        @space_down = false if key.to_i == VK_SPACE
      end

      def onCancel(reason, view)
        if reason.to_i == 0
          handle_escape
        elsif crop_mode?
          finish_crop(false)
        else
          reset_pointer_state
          view.invalidate if view
        end
      end

      def onMouseLeave(_view)
        @cursor_kind = nil
      end

      def onSetCursor
        return false unless @cursor_kind
        cursor_id = CursorManager.cursor(@cursor_kind)
        cursor_id ? UI.set_cursor(cursor_id) : false
      end

      private

      def current_item
        return nil unless Session.store
        item = Session.store.find(@item_id)
        item if item && item.visible
      end

      def handle_escape
        if crop_mode?
          finish_crop(false)
        else
          Session.exit_edit
        end
        true
      end

      def update_cursor_kind(item, x, y)
        hit = HitTester.hit(item, x, y, crop: crop_mode?)
        @cursor_kind = case hit
                       when HitTester::BODY, HitTester::ROTATE then :move
                       when HitTester::RESIZE_TOP_LEFT, HitTester::RESIZE_BOTTOM_RIGHT then :resize_nw_se
                       when HitTester::RESIZE_TOP_RIGHT, HitTester::RESIZE_BOTTOM_LEFT then :resize_ne_sw
                       when HitTester::CROP_LEFT, HitTester::CROP_RIGHT,
                            HitTester::CROP_TOP, HitTester::CROP_BOTTOM then :crop
                       else nil
                       end
      end

      def finish_crop(commit)
        item = current_item
        if @cropper
          commit ? @cropper.commit : @cropper.cancel
        elsif item
          item.reset_zoom
        end
        @cropper = nil
        @mode = MODE_IDLE
        reset_pointer_state
        Session.crop_finished
      end

      def reset_pointer_state
        @dragging = false
        @space_down = false
        @last_point = nil
        @crop_edge = nil
        @resize_anchor = nil
        @resize_sign = nil
        @right_drag_pending = false
        @right_drag_moved = false
        @right_start_point = nil
      end

      def begin_resize(item, handle)
        sx, sy = case handle
                 when HitTester::RESIZE_TOP_LEFT then [-1, -1]
                 when HitTester::RESIZE_TOP_RIGHT then [1, -1]
                 when HitTester::RESIZE_BOTTOM_LEFT then [-1, 1]
                 else [1, 1]
                 end
        @resize_sign = [sx, sy]
        @resize_anchor = [sx.negative? ? item.x + item.width : item.x,
                          sy.negative? ? item.y + item.height : item.y]
        @resize_aspect = item.display_aspect
        @mode = MODE_RESIZE
      end

      def resize_item(item, x, y)
        return unless @resize_anchor && @resize_sign
        sx, sy = @resize_sign
        anchor_x, anchor_y = @resize_anchor
        requested_width = (x - anchor_x) * sx
        requested_height = (y - anchor_y) * sy
        aspect = [@resize_aspect.to_f, 0.01].max
        width = [requested_width, requested_height * aspect].max
        width = [width, MIN_FRAME_SIZE].max
        height = width / aspect
        item.width = width
        item.height = height
        item.x = sx.negative? ? anchor_x - width : anchor_x
        item.y = sy.negative? ? anchor_y - height : anchor_y
      end
    end
  end
end
