require 'json'

module VGD
  module Transform
    # Cửa sổ VGD Transform (UI::HtmlDialog). Logic nằm ở core/; file này chỉ nối giao diện với chúng.
    # Luôn tính lại từ lựa chọn hiện tại khi xem trước và khi áp dụng (không dùng danh sách cũ của cửa sổ).
    class Panel
      ROOT_HTML = 'html/index.html'.freeze

      class SelectionObserver < Sketchup::SelectionObserver
        def initialize(panel); @panel = panel; end
        def onSelectionBulkChange(_selection); @panel.selection_changed; end
        def onSelectionAdded(_selection, _entity); @panel.selection_changed; end
        def onSelectionRemoved(_selection, _entity); @panel.selection_changed; end
        def onSelectionCleared(_selection); @panel.selection_changed; end
      end

      def initialize
        @closed = false
        @dialog = ::UI::HtmlDialog.new(dialog_title: 'VGD Transform', preferences_key: 'VGD_Transform_Panel', scrollable: true, resizable: true,
                                       width: 440, height: 600, style: ::UI::HtmlDialog::STYLE_DIALOG)
        @dialog.set_file(File.join(VGD::Transform::ROOT, ROOT_HTML))
        @dialog.add_action_callback('ready') { |_ctx| safely { refresh } }
        @dialog.add_action_callback('refresh') { |_ctx| safely { refresh } }
        @dialog.add_action_callback('apply') { |_ctx, payload| safely { apply(JSON.parse(payload)) } }
        @dialog.set_on_closed { @closed = true; detach }
        attach
      end

      def show; @dialog.visible? ? @dialog.bring_to_front : @dialog.show; end
      def closed?; @closed; end
      def close; @dialog.close; end
      # Không có thao tác nào kéo dài (biến đổi là một lệnh ngắn), nên luôn rảnh khi tải lại code.
      def busy_reason; nil; end

      def selection_changed
        return if @closed
        safely { refresh }
      end

      def refresh
        emit('unit', {unit: Move.length_unit(Sketchup.active_model)})
      end

      def apply(payload)
        model = Sketchup.active_model
        unit = Move.length_unit(model)
        items = Move.items(model)
        plan = Plan.build(items, payload, unit)
        count = Move.apply(model, plan[:moves], items)
        emit('done', {moved: count})
        refresh
      end

      private

      def attach
        @model = Sketchup.active_model
        @observer = SelectionObserver.new(self)
        @model.selection.add_observer(@observer)
      end

      def detach
        @model.selection.remove_observer(@observer) if @model && @observer
        @observer = nil
      rescue StandardError
        @observer = nil
      end

      def emit(event, payload)
        json = JSON.generate(payload).gsub('<', '\\u003c').gsub("\u2028", '\\u2028').gsub("\u2029", '\\u2029')
        @dialog.execute_script("window.VGD.receive(#{JSON.generate(event)}, #{json})")
      end

      def safely
        yield
      rescue StandardError => error
        VGD::Transform.log(error.message)
        text = error.message.match?(/[À-ỹ]/) ? error.message : 'Không thực hiện được thao tác. Hãy chọn lại món và thử lại.'
        emit('message', {error: text})
      end
    end
  end
end
