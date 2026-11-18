module VGD
  module Structure
    # Cầu nối với SketchUp cho cửa sổ (cột mốc P6): theo dõi phần tử đang chọn trong SketchUp, và công cụ chọn điểm trong khung nhìn SketchUp.
    # Phần này chỉ kiểm được đầy đủ trong SketchUp thật (observer, InputPoint, select_tool).

    # Báo cho cửa sổ khi người dùng đổi vùng chọn trong SketchUp (cửa sổ gom các sự kiện dồn dập thành một lần gửi).
    class SelectionWatcher < (defined?(Sketchup::SelectionObserver) ? Sketchup::SelectionObserver : Object)
      def initialize(panel)
        @panel = panel
      end

      def onSelectionBulkChange(_selection); @panel.model_selection_changed; end
      def onSelectionCleared(_selection); @panel.model_selection_changed; end
      def onSelectionAdded(_selection, _entity); @panel.model_selection_changed; end
      def onSelectionRemoved(_selection, _entity); @panel.model_selection_changed; end
    end

    # Theo dõi Hoàn tác / Làm lại trong SketchUp: nếu dữ liệu plugin lưu trong model đổi thì cửa sổ nạp lại dữ liệu (cột mốc vẽ trực tiếp trong SketchUp).
    class ModelWatcher < (defined?(Sketchup::ModelObserver) ? Sketchup::ModelObserver : Object)
      def initialize(panel)
        @panel = panel
      end

      def onTransactionUndo(_model); @panel.model_history_changed; end
      def onTransactionRedo(_model); @panel.model_history_changed; end
      def onTransactionCommit(_model); @panel.model_committed; end
    end

    # Công cụ SketchUp: bấm một điểm trong khung nhìn (có bắt điểm của SketchUp: đầu mút, giữa, giao, trên cạnh...). Mỗi lần bấm gửi tọa độ (mm, theo trục X Y của model)
    # cho cửa sổ để dùng như một lần bấm trên mặt bằng; công cụ giữ nguyên để bấm tiếp (chuỗi dầm, tường), Esc hoặc đổi công cụ khác thì kết thúc.
    class PickTool
      MOVE_INTERVAL = 0.06 # giây: gửi vị trí con trỏ cho cửa sổ (để hiện xem trước) không dày hơn mức này
      VK_BACK = 8
      VK_RETURN = 13
      GHOST_COLOR = [47, 123, 255].freeze # xanh như xem trước trên mặt bằng

      def initialize(panel)
        @panel = panel
        @input = Sketchup::InputPoint.new
        @last_move = 0.0
      end

      def activate
        Sketchup.status_text = 'VGD Structure: bấm điểm (bắt điểm của SketchUp). Enter khép / kết thúc, Backspace bỏ điểm cuối, gõ số + Enter ở ô giá trị, Esc hủy.'
        Sketchup.vcb_label = 'Giá trị (mm)' if Sketchup.respond_to?(:vcb_label=)
      end

      def deactivate(view)
        view.invalidate
        @panel.pick_ended(self)
      end

      def resume(view)
        view.invalidate
      end

      def onMouseMove(_flags, x, y, view)
        @input.pick(view, x, y)
        view.tooltip = @input.tooltip
        view.invalidate
        now = Time.now.to_f
        return if now - @last_move < MOVE_INTERVAL
        @last_move = now
        @panel.pick_move(point_mm) if @input.valid?
      end

      def onLButtonDown(_flags, x, y, view)
        @input.pick(view, x, y)
        @panel.pick_point(point_mm) if @input.valid?
        view.invalidate
      end

      # Esc (lý do 0): chuyển cho cửa sổ quyết định (hủy chuỗi đang vẽ, hoặc kết thúc nếu không còn gì). Lý do khác (chọn lại công cụ, hoàn tác): bỏ qua.
      def onCancel(reason, _view)
        @panel.pick_key('Escape') if reason.to_i.zero?
      end

      def onKeyDown(key, _repeat, _flags, view)
        name = {VK_RETURN => 'Enter', VK_BACK => 'Backspace'}[key]
        return false unless name
        @panel.pick_key(name)
        view.invalidate
        true
      end

      # Ô giá trị của SketchUp (VCB): gõ số + Enter đi như ô nhập số trên mặt bằng.
      def onUserText(text, view)
        @panel.pick_text(text.to_s)
        view.invalidate
      end

      # Vẽ bắt điểm và xem trước do cửa sổ gửi (đường, chấm, đa giác ở cao độ tầng); phần tử khác bỏ qua.
      def draw(view)
        @input.draw(view) if @input.valid?
        ghost = @panel.ghost_items
        return if ghost.empty?
        z = @panel.ghost_z.mm
        view.drawing_color = Sketchup::Color.new(*GHOST_COLOR)
        view.line_width = 2
        ghost.each do |g|
          pts = Array(g['pts']).map { |x, y| Geom::Point3d.new(x.mm, y.mm, z) }
          next if pts.empty?
          case g['t']
          when 'line' then view.draw_polyline(pts) if pts.size >= 2
          when 'poly' then view.draw_polyline(pts + [pts.first]) if pts.size >= 2
          when 'dot' then view.draw_points(pts, 8, 2, view.drawing_color) if view.respond_to?(:draw_points)
          end
        end
      end

      def point_mm
        p = @input.position
        [ModelSync.to_mm(p.x).round(1), ModelSync.to_mm(p.y).round(1)]
      end
    end
  end
end
