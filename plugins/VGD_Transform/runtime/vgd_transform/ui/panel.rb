require 'json'

module VGD
  module Transform
    # Cửa sổ VGD Transform (UI::HtmlDialog). Logic nằm ở core/; file này chỉ nối giao diện với chúng.
    # Gửi trạng thái (đơn vị, số món, giá trị hiện tại cho ô Tuyệt đối) mỗi khi lựa chọn hoặc model thay đổi, giống 3ds Max.
    class Panel
      ROOT_HTML = 'html/index.html'.freeze
      SUMMARY_LIMIT = 500 # chọn nhiều hơn số này thì không đọc giá trị hiện tại (tránh chậm khi model thay đổi liên tục)
      ORIGIN_TOLERANCE_MM = 0.001
      SCALE_TOLERANCE = 1e-6

      class SelectionObserver < Sketchup::SelectionObserver
        def initialize(panel); @panel = panel; end
        def onSelectionBulkChange(_selection); @panel.changed; end
        def onSelectionAdded(_selection, _entity); @panel.changed; end
        def onSelectionRemoved(_selection, _entity); @panel.changed; end
        def onSelectionCleared(_selection); @panel.changed; end
      end

      # Model thay đổi (kể cả Ctrl+Z, công cụ Move của SketchUp): cập nhật ô Tuyệt đối.
      class ModelObserver < Sketchup::ModelObserver
        def initialize(panel); @panel = panel; end
        def onTransactionCommit(_model); @panel.changed; end
        def onTransactionUndo(_model); @panel.changed; end
        def onTransactionRedo(_model); @panel.changed; end
      end

      def initialize
        @closed = false
        @live = nil
        @ready = false
        @tool = nil
        # Cửa sổ gọn cỡ Transform Type-In của 3ds Max (320 × 250), để đặt cạnh màn hình. Khóa lưu cỡ mới: không giữ cỡ to của bản cũ.
        @dialog = ::UI::HtmlDialog.new(dialog_title: 'VGD Transform', preferences_key: 'VGD_Transform_Compact', scrollable: true, resizable: true,
                                       width: 320, height: 250, min_width: 300, min_height: 220, style: ::UI::HtmlDialog::STYLE_DIALOG)
        @dialog.set_file(File.join(VGD::Transform::ROOT, ROOT_HTML))
        @dialog.add_action_callback('ready') { |_ctx| safely { @ready = true; emit('tool', {tool: @tool}) if @tool; refresh } }
        @dialog.add_action_callback('refresh') { |_ctx| safely { refresh } }
        @dialog.add_action_callback('apply') { |_ctx, payload| safely { apply(JSON.parse(payload)) } }
        @dialog.add_action_callback('lock') { |_ctx| safely { toggle_lock } }
        @dialog.add_action_callback('live_start') { |_ctx| safely { live_start } }
        @dialog.add_action_callback('live') { |_ctx, payload| safely { live(JSON.parse(payload)) } }
        @dialog.add_action_callback('live_end') { |_ctx| safely { live_end } }
        @dialog.set_on_closed { @closed = true; @live = nil; detach }
        attach
      end

      def show; @dialog.visible? ? @dialog.bring_to_front : @dialog.show; end
      def closed?; @closed; end
      def close; @dialog.close; end

      # Chọn công cụ (move / rotate / scale). Cửa sổ chưa nạp xong thì nhớ lại, gửi khi giao diện báo sẵn sàng.
      def select_tool(tool)
        @tool = tool
        emit('tool', {tool: tool}) if @ready
      end

      # Đang kéo trực tiếp thì không tải lại code (đang giữ trạng thái ban đầu của các món).
      def busy_reason
        'đang kéo để biến đổi món' if @live
      end

      # Lựa chọn hoặc model đổi. Trong lúc kéo trực tiếp thì bỏ qua (chính plugin đang đổi model).
      def changed
        return if @closed || @live
        safely { refresh }
      end

      def refresh
        model = Sketchup.active_model
        known = ModelOps.length_unit(model)
        unit = known || Units::DEFAULT_UNIT
        state = {unit: unit, unit_known: !known.nil?, count: 0, skipped: 0, origin: nil, center: nil, scale: nil, lock: ModelOps.lock_state(model)}
        if model.selection.size > SUMMARY_LIMIT
          state[:count] = model.selection.size
        else
          items = ModelOps.items(model)
          state.merge!(summary(items, unit))
          state[:skipped] = ModelOps.skipped_count(model, items)
        end
        emit('state', state)
      end

      def apply(payload)
        model = Sketchup.active_model
        items = ModelOps.items(model)
        plan = Plan.build(items, payload, unit_of(model))
        count = ModelOps.apply(model, plan[:moves], items)
        emit('done', {moved: count, skipped: ModelOps.skipped_count(model, items), tool: payload['tool']})
        refresh
      end

      # Nút khóa, như Lock / Unlock của SketchUp: lựa chọn đã khóa hết thì mở khóa, còn lại (chưa khóa hoặc lẫn lộn) thì khóa hết.
      def toggle_lock
        model = Sketchup.active_model
        lock = ModelOps.lock_state(model) != 'all'
        count = ModelOps.set_locked(model, lock)
        emit('message', {text: "Đã #{lock ? 'khóa' : 'mở khóa'} #{count} món."})
        refresh
      end

      # Kéo trực tiếp (như spinner của 3ds Max): nhớ biến đổi ban đầu, mỗi lần cập nhật tính lại từ đó, gộp thành một bước Ctrl+Z.
      def live_start
        items = ModelOps.items(Sketchup.active_model)
        @live = {items: items, originals: items.to_h { |item| [item[:entity], item[:entity].transformation] }, applied: false}
      end

      def live(payload)
        return unless @live
        model = Sketchup.active_model
        begin
          plan = Plan.build(@live[:items], payload, unit_of(model))
          ModelOps.apply(model, plan[:moves], @live[:items], transparent: @live[:applied], restore: @live[:originals])
          @live[:applied] = true
        rescue NothingToDo
          # Giá trị kéo về 0 (hoặc hệ số 1): đưa món về như lúc bắt đầu kéo.
          ModelOps.restore(model, @live[:originals]) if @live[:applied]
        rescue StandardError
          @live = nil
          raise
        end
      end

      def live_end
        @live = nil
        refresh
      end

      private

      def unit_of(model)
        ModelOps.length_unit(model) || Units::DEFAULT_UNIT
      end

      # Giá trị hiện tại, theo đơn vị của file: điểm gốc chung (nil ở trục mà các món khác nhau), tâm lựa chọn, tỉ lệ chung.
      def summary(items, unit)
        return {count: 0} if items.empty?
        per_unit = Units::MM_PER_UNIT.fetch(unit)
        to_unit = ->(list) { list.map { |v| v.nil? ? nil : (v / per_unit).round(6) } }
        {count: items.size,
         origin: to_unit.call(Items.common(items, ORIGIN_TOLERANCE_MM) { |item| item[:origin] }),
         center: to_unit.call(Items.selection_center(items)),
         scale: Items.common(items, SCALE_TOLERANCE) { |item| item[:scale] }.map { |v| v&.round(6) }}
      end

      def attach
        @model = Sketchup.active_model
        @selection_observer = SelectionObserver.new(self)
        @model_observer = ModelObserver.new(self)
        @model.selection.add_observer(@selection_observer)
        @model.add_observer(@model_observer)
      end

      def detach
        if @model
          @model.selection.remove_observer(@selection_observer) if @selection_observer
          @model.remove_observer(@model_observer) if @model_observer
        end
      rescue StandardError
        nil
      ensure
        @selection_observer = nil
        @model_observer = nil
      end

      def emit(event, payload)
        json = JSON.generate(payload).gsub('<', '\\u003c').gsub("\u2028", '\\u2028').gsub("\u2029", '\\u2029')
        @dialog.execute_script("window.VGD.receive(#{JSON.generate(event)}, #{json})")
      end

      # Lỗi có chữ tiếng Việt thì hiện nguyên văn; "không có gì để làm" hiện như thông báo thường, không tô đỏ.
      def safely
        yield
      rescue NothingToDo => error
        emit('message', {text: error.message})
      rescue StandardError => error
        VGD::Transform.log(error.message)
        text = error.message.match?(/[À-ỹ]/) ? error.message : 'Không thực hiện được thao tác. Hãy chọn lại món và thử lại.'
        emit('message', {error: text})
      end
    end
  end
end
