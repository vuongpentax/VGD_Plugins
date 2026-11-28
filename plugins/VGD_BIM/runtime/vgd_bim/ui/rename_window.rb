require 'json'
module VGD
  module BIM
    module UI
      # Mở file khác hoặc tạo file mới: cửa sổ Đổi tên gắn lại vào vùng chọn của file đang mở.
      class RenameAppObserver < Sketchup::AppObserver
        def initialize(window); @window = window; end
        def onNewModel(_model); @window.model_changed; end
        def onOpenModel(_model); @window.model_changed; end
        def onActivateModel(_model); @window.model_changed; end
      end

      # Cửa sổ Đổi tên độc lập (html/rename.html), dùng được cả khi đã đóng Bảng khối lượng. Danh sách là các group / component đang chọn
      # trong SketchUp, tự cập nhật khi chọn lại. Mỗi lần Áp dụng là một bước hoàn tác; bật "Ẩn" thì món vừa đổi tên được ẩn đi (Edit > Unhide để hiện lại).
      # Chỉ đổi tên đối tượng (instance), không đổi tên định nghĩa dùng chung. Logic kiểm tra và mẫu tên: core/rename_list.rb.
      class RenameWindow
        def initialize
          @items = {}
          @ready = false
          @closed = false
          @dialog = ::UI::HtmlDialog.new(dialog_title: 'VGD BIM · Đổi tên', preferences_key: 'VGD_BIM_Rename', scrollable: false, resizable: true,
                                         width: 640, height: 640, min_width: 420, min_height: 380, style: ::UI::HtmlDialog::STYLE_DIALOG)
          @dialog.set_file(File.join(BIM::ROOT, 'html', 'rename.html'))
          @dialog.add_action_callback('ready') { |_ctx| safely { ready } }
          @dialog.add_action_callback('rename_apply') { |_ctx, payload| safely { apply(JSON.parse(payload)) } }
          @dialog.add_action_callback('rename_templates') { |_ctx, payload| safely { save_templates(JSON.parse(payload)) } }
          @dialog.set_on_closed { closed }
        end

        def show; @dialog.visible? ? @dialog.bring_to_front : @dialog.show; end
        def close; @dialog.close; end
        def closed?; @closed; end

        # Gom nhiều sự kiện chọn liên tiếp thành một lần đọc.
        def selection_changed
          return unless @ready
          ::UI.stop_timer(@timer) if @timer
          @timer = ::UI.start_timer(0.05, false) { safely { push_items if @ready } }
        end

        def model_changed
          return unless @ready
          safely do
            attach
            push_items
          end
        end

        private

        def ready
          @ready = true
          emit('config', {version: BIM::VERSION, language: Settings.read['language'], templates: RenameList.templates})
          attach
          unless @app_observer
            @app_observer = RenameAppObserver.new(self)
            Sketchup.add_observer(@app_observer)
          end
          push_items
        end

        def closed
          @closed = true
          @ready = false
          ::UI.stop_timer(@timer) if @timer
          detach
          Sketchup.remove_observer(@app_observer) if @app_observer
          @app_observer = nil
        rescue StandardError
          @app_observer = nil
        end

        def attach
          detach
          @model = Sketchup.active_model
          return unless @model
          @observer = SelectionObserver.new(self)
          @model.selection.add_observer(@observer)
        end

        def detach
          @model.selection.remove_observer(@observer) if @model && @observer
          @observer = nil
        rescue StandardError
          @observer = nil
        end

        def ancestor_locked?
          (@model.active_path || []).any?(&:locked?)
        end

        def push_items
          @model = Sketchup.active_model unless @model
          picked = @model ? @model.selection.to_a.select { |entity| Data.supported?(entity) && entity.valid? } : []
          shown = picked.first(RenameList::MAX_ITEMS)
          locked = @model ? ancestor_locked? : false
          @items = shown.to_h { |entity| [entity.entityID, entity] }
          emit('items', {total: picked.size, items: shown.map do |entity|
            {id: entity.entityID, name: entity.name.to_s, definition: entity.definition.name.to_s, def_id: entity.definition.entityID, locked: locked || entity.locked?}
          end})
        end

        def apply(payload)
          raise 'Đã mở file SketchUp khác. Hãy chọn lại các món cần đổi tên.' unless @model && @model.equal?(Sketchup.active_model)
          changes = RenameList.changes!(payload, @items)
          targets = changes.map { |id, name| [@items.fetch(id), name] }
          raise 'Có món không còn trong model. Hãy chọn lại các món cần đổi tên.' unless targets.all? { |entity, _| entity.valid? }
          raise 'Có món bị khóa, không đổi tên được. Hãy mở khóa hoặc bỏ chọn món đó.' if ancestor_locked? || targets.any? { |entity, _| entity.locked? }
          hide = payload['hide'] == true
          Data.transaction(@model, 'VGD_BIM · Đổi tên') do
            targets.each do |entity, name|
              entity.name = name
              entity.hidden = true if hide
            end
          end
          @model.selection.remove(targets.map(&:first)) if hide # món đã ẩn không còn nằm trong vùng chọn, danh sách chỉ còn món chưa đặt tên
          push_items
          BIM.names_changed
          text = "Đã đổi tên #{targets.size} món"
          text += hide ? ' và ẩn đi (Edit > Unhide để hiện lại).' : '.'
          emit('applied', {count: targets.size, hidden: hide ? targets.size : 0, text: "#{text} Bấm Ctrl+Z để hoàn tác."})
        end

        def save_templates(payload)
          emit('templates', RenameList.save_templates(payload))
        end

        def safely
          yield
        rescue StandardError => error
          BIM.log(error.message)
          text = error.message.match?(/[À-ỹ]/) ? error.message : 'Không thực hiện được thao tác. Hãy chọn lại các món và thử lại.'
          text = 'Không lưu được mẫu tên trên máy này.' if error.is_a?(SystemCallError)
          emit('message', {error: text})
        end

        def emit(event, payload)
          return if @closed
          json = JSON.generate(payload).gsub('<', '\\u003c').gsub("\u2028", '\\u2028').gsub("\u2029", '\\u2029')
          @dialog.execute_script("window.VGD.receive(#{JSON.generate(event)}, #{json})")
        end
      end
    end
  end
end
