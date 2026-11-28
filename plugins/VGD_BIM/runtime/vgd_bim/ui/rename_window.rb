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

      # Cửa sổ Đổi tên độc lập (html/rename.html), dùng được cả khi đã đóng Bảng khối lượng. Danh sách là các group / component người dùng
      # chọn trong SketchUp (bật "Chọn sâu" thì thêm mọi group / component lồng bên trong), tự cập nhật khi người dùng chọn lại. Bấm dòng trong
      # cửa sổ thì chọn món đó trong SketchUp mà danh sách giữ nguyên (lựa chọn do chính cửa sổ đặt được bỏ qua, `@own_pick`).
      # Mỗi lần Áp dụng là một bước hoàn tác; bật "Ẩn" thì món vừa đổi tên được ẩn đi (Edit > Unhide để hiện lại) và rời danh sách.
      # Chỉ đổi tên đối tượng (instance), không đổi tên định nghĩa. Logic kiểm tra và mẫu tên: core/rename_list.rb.
      class RenameWindow
        def initialize
          @records = []
          @items = {}
          @roots = []
          @root_path = []
          @deep = false
          @ready = false
          @closed = false
          @dialog = ::UI::HtmlDialog.new(dialog_title: 'VGD BIM · Đổi tên', preferences_key: 'VGD_BIM_Rename', scrollable: false, resizable: true,
                                         width: 640, height: 640, min_width: 420, min_height: 380, style: ::UI::HtmlDialog::STYLE_DIALOG)
          @dialog.set_file(File.join(BIM::ROOT, 'html', 'rename.html'))
          @dialog.add_action_callback('ready') { |_ctx| safely { ready } }
          @dialog.add_action_callback('rename_apply') { |_ctx, payload| safely { apply(JSON.parse(payload)) } }
          @dialog.add_action_callback('rename_templates') { |_ctx, payload| safely { save_templates(JSON.parse(payload)) } }
          @dialog.add_action_callback('rename_deep') { |_ctx, payload| safely { set_deep(JSON.parse(payload)) } }
          @dialog.add_action_callback('rename_pick') { |_ctx, payload| safely { pick(JSON.parse(payload)) } }
          @dialog.set_on_closed { closed }
        end

        def show; @dialog.visible? ? @dialog.bring_to_front : @dialog.show; end
        def close; @dialog.close; end
        def closed?; @closed; end
        def visible?; @dialog.visible?; end

        # Gom nhiều sự kiện chọn liên tiếp thành một lần đọc.
        def selection_changed
          return unless @ready
          ::UI.stop_timer(@timer) if @timer
          @timer = ::UI.start_timer(0.05, false) { safely { follow_selection if @ready } }
        end

        def model_changed
          return unless @ready
          safely do
            attach
            @own_pick = nil
            follow_selection
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
          follow_selection
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

        # Người dùng chọn trong SketchUp: lấy làm gốc của danh sách. Lựa chọn do cửa sổ vừa đặt (bấm dòng, ẩn sau khi đổi tên) thì bỏ qua.
        def follow_selection
          @model ||= Sketchup.active_model
          current = @model ? @model.selection.to_a : []
          return if @own_pick && current.size == @own_pick.size && (current - @own_pick).empty?
          @own_pick = nil
          @roots = current.select { |entity| Data.supported?(entity) && entity.valid? }
          @root_path = @model ? (@model.active_path || []) : []
          rebuild
        end

        def set_deep(value)
          @deep = value == true
          rebuild
        end

        # Danh sách từ các món gốc: không sâu thì đúng các món đã chọn, sâu thì thêm mọi group / component bên trong (bỏ món đang ẩn,
        # mỗi định nghĩa không duyệt vào chính nó, món trong định nghĩa dùng chung chỉ một dòng). Lấy tối đa MAX_ITEMS + 1 dòng để biết còn nữa.
        def rebuild
          locked = @root_path.any?(&:locked?)
          records = []
          seen = {}
          if @deep
            collect(@roots, @root_path, locked, [], records, seen, true)
          else
            @roots.each do |entity|
              break if records.size > RenameList::MAX_ITEMS
              records << {entity: entity, path: @root_path + [entity], locked: locked || entity.locked?, shared: false}
            end
          end
          @more = records.size > RenameList::MAX_ITEMS
          @records = records.first(RenameList::MAX_ITEMS)
          push_items
        end

        def collect(entities, path, locked, definitions, out, seen, root)
          entities.each do |entity|
            return if out.size > RenameList::MAX_ITEMS
            next unless Data.supported?(entity) && entity.valid?
            next if !root && entity.hidden?
            current = path + [entity]
            current_locked = locked || entity.locked?
            unless seen[entity.entityID]
              seen[entity.entityID] = true
              out << {entity: entity, path: current, locked: current_locked, shared: definitions.any? { |definition| definition.instances.size > 1 }}
            end
            definition = entity.definition
            next if definitions.include?(definition)
            collect(definition.entities, current, current_locked, definitions + [definition], out, seen, false)
          end
        end

        def push_items
          @items = @records.to_h { |record| [record[:entity].entityID, record] }
          emit('items', {total: @records.size, more: @more ? true : false, deep: @deep, items: @records.map do |record|
            entity = record[:entity]
            {id: entity.entityID, name: entity.name.to_s, definition: entity.definition.name.to_s, def_id: entity.definition.entityID,
             level: record[:path].size - @root_path.size - 1, locked: record[:locked] || entity.locked?, shared: record[:shared]}
          end})
        end

        # Bấm dòng trong cửa sổ: chọn các món đó trong SketchUp (mở group cha nếu món nằm bên trong). Món ở các cấp lồng khác nhau thì
        # SketchUp chỉ chọn được món cuối. Danh sách giữ nguyên.
        def pick(payload)
          return unless @model && @model.equal?(Sketchup.active_model)
          ids = payload.is_a?(Hash) ? payload['ids'] : nil
          raise ArgumentError, 'Dữ liệu chọn món không hợp lệ.' unless ids.is_a?(Array) && ids.size <= RenameList::MAX_ITEMS && ids.all? { |id| id.is_a?(Integer) }
          records = ids.map { |id| @items[id] }.compact
          return if records.empty?
          raise 'Có món không còn trong model. Hãy chọn lại các món cần đổi tên.' unless records.all? { |record| record[:path].all?(&:valid?) }
          parents = records.first[:path][0...-1]
          mirrored = records.all? { |record| record[:path][0...-1] == parents } ? records : [records.last]
          parents = mirrored.first[:path][0...-1]
          @model.active_path = parents unless (@model.active_path || []) == parents
          @own_pick = mirrored.map { |record| record[:entity] }
          @model.selection.clear
          @model.selection.add(*@own_pick)
          emit('message', {text: 'Các món nằm ở cấp lồng khác nhau nên SketchUp chỉ chọn món cuối.'}) if mirrored.size < records.size
        end

        def apply(payload)
          raise 'Đã mở file SketchUp khác. Hãy chọn lại các món cần đổi tên.' unless @model && @model.equal?(Sketchup.active_model)
          changes = RenameList.changes!(payload, @items)
          targets = changes.map { |id, name| [@items.fetch(id), name] }
          raise 'Có món không còn trong model. Hãy chọn lại các món cần đổi tên.' unless targets.all? { |record, _| record[:path].all?(&:valid?) }
          raise 'Có món bị khóa, không đổi tên được. Hãy mở khóa hoặc bỏ chọn món đó.' if targets.any? { |record, _| record[:locked] || record[:entity].locked? }
          hide = payload['hide'] == true
          entities = targets.map { |record, _| record[:entity] }
          Data.transaction(@model, 'VGD_BIM · Đổi tên') do
            targets.each do |record, name|
              record[:entity].name = name
              record[:entity].hidden = true if hide
            end
          end
          if hide # món đã ẩn rời danh sách và vùng chọn; danh sách chỉ còn món chưa đặt tên
            @records.reject! { |record| entities.include?(record[:entity]) }
            @roots -= entities
            @own_pick = @model.selection.to_a - entities
            @model.selection.remove(entities)
          end
          push_items
          BIM.model_edited
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
