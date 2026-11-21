require 'json'

module VGD
  module Position
    # Cửa sổ VGD Position (UI::HtmlDialog). Logic dời nằm ở core/position.rb và core/move.rb; file này chỉ nối giao diện với chúng.
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
        @dialog = ::UI::HtmlDialog.new(dialog_title: 'VGD Position', preferences_key: 'VGD_Position_Panel', scrollable: true, resizable: true,
                                       width: 440, height: 560, style: ::UI::HtmlDialog::STYLE_DIALOG)
        @dialog.set_file(File.join(VGD::Position::ROOT, ROOT_HTML))
        @dialog.add_action_callback('ready') { |_ctx| safely { refresh } }
        @dialog.add_action_callback('refresh') { |_ctx| safely { refresh } }
        @dialog.add_action_callback('preview') { |_ctx, payload| safely { preview(JSON.parse(payload)) } }
        @dialog.add_action_callback('apply') { |_ctx, payload| safely { apply(JSON.parse(payload)) } }
        @dialog.set_on_closed { @closed = true; detach }
        attach
      end

      def show; @dialog.visible? ? @dialog.bring_to_front : @dialog.show; end
      def closed?; @closed; end
      def close; @dialog.close; end
      # Không có thao tác nào kéo dài (dời là một lệnh ngắn), nên luôn rảnh khi tải lại code.
      def busy_reason; nil; end

      def selection_changed
        return if @closed
        safely { refresh }
      end

      def refresh
        items = Move.items(Sketchup.active_model).map { |item| public_item(item) }
        emit('items', {items: items, count: items.size, can_absolute: items.size == 1})
      end

      def preview(payload)
        items, plan = plan_for(payload)
        moves = plan[:moves].map do |move|
          item = items.find { |i| i[:index] == move[:index] }
          {index: move[:index], name: item[:name], delta: move[:delta].map { |v| v.round(1) }, target: item[:origin].zip(move[:delta]).map { |a, d| (a + d).round(1) }}
        end
        emit('preview', {moves: moves, skipped: plan[:skipped]})
      end

      def apply(payload)
        items, plan = plan_for(payload)
        count = Move.apply(Sketchup.active_model, plan[:moves], items)
        emit('done', {moved: count, skipped: plan[:skipped]})
        refresh
      end

      private

      def plan_for(payload)
        items = Move.items(Sketchup.active_model)
        values = payload['values'].is_a?(Hash) ? payload['values'] : {}
        plan = Position.plan(items, payload['mode'].to_s, values)
        [items, plan]
      end

      def public_item(item)
        {index: item[:index], name: item[:name], origin: item[:origin].map { |v| v.round(1) }, locked: item[:locked]}
      end

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
        VGD::Position.log(error.message)
        text = error.message.match?(/[À-ỹ]/) ? error.message : 'Không thực hiện được thao tác. Hãy chọn lại món và thử lại.'
        emit('message', {error: text})
      end
    end
  end
end
