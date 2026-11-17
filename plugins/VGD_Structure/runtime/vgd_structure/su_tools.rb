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

    # Công cụ SketchUp: bấm một điểm trong khung nhìn (có bắt điểm của SketchUp: đầu mút, giữa, giao, trên cạnh...). Mỗi lần bấm gửi tọa độ (mm, theo trục X Y của model)
    # cho cửa sổ để dùng như một lần bấm trên mặt bằng; công cụ giữ nguyên để bấm tiếp (chuỗi dầm, tường), Esc hoặc đổi công cụ khác thì kết thúc.
    class PickTool
      MOVE_INTERVAL = 0.06 # giây: gửi vị trí con trỏ cho cửa sổ (để hiện xem trước) không dày hơn mức này

      def initialize(panel)
        @panel = panel
        @input = Sketchup::InputPoint.new
        @last_move = 0.0
      end

      def activate
        Sketchup.status_text = 'VGD Structure: bấm điểm (bắt điểm của SketchUp), Esc để kết thúc.'
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

      def onCancel(_reason, _view)
        Sketchup.active_model.select_tool(nil)
      end

      def draw(view)
        @input.draw(view) if @input.valid?
      end

      def point_mm
        p = @input.position
        [ModelSync.to_mm(p.x).round(1), ModelSync.to_mm(p.y).round(1)]
      end
    end
  end
end
