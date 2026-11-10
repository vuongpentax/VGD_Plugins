module VGD
  module BIM
    module UI
      # Phần của cửa sổ BIM lo cho tab nhỏ "Trong model" của Soạn tag: hiện cây thư mục tag / tag của model đang mở, bật tắt hiển thị
      # (mắt) từng tag hoặc thư mục, cô lập một tag / thư mục (ẩn mọi thứ khác, bấm lại để khôi phục). Logic cây nằm ở TagTree.
      # Chỉ đổi hiển thị (Layer#visible=, LayerFolder#visible=), mỗi lệnh là MỘT bước hoàn tác. Thư mục tag cần SketchUp 2021 trở lên.
      # Trộn vào UI::Dialog (dùng @model, emit, check_model!...).
      module TagManager
        UNTAGGED_NAMES = %w[Untagged Layer0].freeze

        def register_tag_manager_callbacks
          @dialog.add_action_callback('tm_refresh') { |_ctx, _payload| safely { tm_refresh } }
          @dialog.add_action_callback('tm_visible') { |_ctx, payload| safely { tm_visible(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_isolate') { |_ctx, payload| safely { tm_isolate(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_color') { |_ctx, payload| safely { tm_color(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_line_style') { |_ctx, payload| safely { tm_line_style(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_sample') { |_ctx, _payload| safely { tm_sample } }
          @dialog.add_action_callback('tm_delete_preview') { |_ctx, payload| safely { tm_delete_preview(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_delete') { |_ctx, payload| safely { tm_delete(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_pin') { |_ctx, payload| safely { tm_pin(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_move') { |_ctx, payload| safely { tm_move(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_color_by_tag') { |_ctx, payload| safely { tm_color_by_tag(JSON.parse(payload)) } }
        end

        # Dữ liệu gửi cho giao diện: {supported:, folders: [...], layers: [...], isolated: {kind, id, name} hoặc nil}
        def tag_tree_state
          layers, folders = tag_tree_read
          tree = {supported: folders_supported?,
                  folders: folders.map { |item| item.slice(:id, :name, :visible, :parent_id) },
                  layers: layers.map { |item| item.slice(:id, :name, :visible, :folder_id, :color, :line_style) },
                  styles_supported: line_styles_supported?, line_styles: line_style_names, color_by_tag: color_by_tag?,
                  pinned: Settings.read['pinned_tags'], recent: Settings.read['recent_tags'],
                  isolated: nil}
          tree[:isolated] = {kind: @isolation[:kind], id: @isolation[:id], name: @isolation[:name]} if isolation_active?
          tree
        end

        def tm_refresh
          check_model!
          emit('tag_tree', tag_tree_state)
        end

        # payload: {'kind' => 'tag' | 'folder', 'id' => persistent_id, 'visible' => true / false}
        def tm_visible(payload)
          check_model!
          kind = payload['kind'].to_s
          id = tm_id(payload)
          visible = payload['visible']
          raise 'Giá trị hiển thị không hợp lệ.' unless visible == true || visible == false
          layers, folders = tag_tree_read
          item = (kind == 'folder' ? folders : layers).find { |entry| entry[:id] == id }
          raise 'Không tìm thấy tag hoặc thư mục này. Hãy làm mới danh sách.' unless item
          Data.transaction(@model, visible ? 'VGD BIM · Hiện tag' : 'VGD BIM · Ẩn tag') { item[:object].visible = visible }
          emit('tag_tree', tag_tree_state)
        end

        # payload: {'id' => persistent_id của tag, 'color' => '#rrggbb'}
        def tm_color(payload)
          check_model!
          id = tm_id(payload)
          rgb = TagTree.parse_color(payload['color'])
          layer = tag_tree_read.first.find { |entry| entry[:id] == id }&.fetch(:object) or raise 'Không tìm thấy tag này. Hãy làm mới danh sách.'
          Data.transaction(@model, 'VGD BIM · Đổi màu tag') { layer.color = Sketchup::Color.new(*rgb) }
          emit('tag_tree', tag_tree_state)
        end

        # payload: {'id' => persistent_id của tag, 'style' => tên kiểu nét có trong model (model.line_styles)}
        def tm_line_style(payload)
          check_model!
          raise 'Phiên bản SketchUp này chưa có kiểu nét cho tag (cần SketchUp 2021 trở lên).' unless line_styles_supported?
          id = tm_id(payload)
          style = @model.line_styles.to_a.find { |entry| entry.name.to_s == payload['style'].to_s } or raise 'Kiểu nét không có trong model.'
          layer = tag_tree_read.first.find { |entry| entry[:id] == id }&.fetch(:object) or raise 'Không tìm thấy tag này. Hãy làm mới danh sách.'
          Data.transaction(@model, 'VGD BIM · Đổi kiểu nét tag') { layer.line_style = style }
          emit('tag_tree', tag_tree_state)
        end

        # Công cụ lấy mẫu: bấm vào đối tượng trong view để lấy tag, kết quả gửi cho giao diện (sự kiện tag_sample) để chọn sẵn trong ô Gán tag.
        def tm_sample
          check_model!
          release_preview if respond_to?(:release_preview, true) # khung đánh dấu của bảng không được che hay chiếm chuột của công cụ lấy mẫu
          @sample_tool = TagSampleTool.new(->(name) { safely { tm_sampled(name) } }, -> { @sample_tool = nil })
          @model.select_tool(@sample_tool)
          emit('message', {text: 'Bấm vào một đối tượng trong view để lấy tag của nó (Esc để hủy).'})
        end

        def tm_sampled(name)
          emit('tag_sample', {name: name.to_s})
        end

        # Xóa tag có gán lại, bước 1: đếm số đối tượng (kể cả bên trong group / component) đang dùng tag, để giao diện hỏi lại trước khi xóa.
        # payload: {'id' => persistent_id của tag}
        def tm_delete_preview(payload)
          check_model!
          layer = tm_deletable_layer(payload)
          emit('tag_delete_preview', {id: layer[:id], name: layer[:name], count: tm_count_users(layer[:object])})
        end

        # Xóa tag có gán lại, bước 2. payload: {'id' => tag cần xóa, 'to_id' => tag nhận các đối tượng (nil = Untagged)}. Một bước hoàn tác.
        # Không bao giờ xóa đối tượng: chỉ đổi tag của chúng rồi bỏ tag.
        def tm_delete(payload)
          check_model!
          layer = tm_deletable_layer(payload)
          raw = payload['to_id']
          raise 'Mã tag nhận không hợp lệ.' unless raw.nil? || raw.is_a?(Integer)
          layers, = tag_tree_read
          target = raw.nil? ? nil : (layers.find { |entry| entry[:id] == raw } or raise 'Không tìm thấy tag nhận. Hãy làm mới danh sách.')
          raise 'Tag nhận phải khác tag cần xóa.' if target && target[:id] == layer[:id]
          untagged = target.nil? || UNTAGGED_NAMES.include?(target[:name])
          moved = 0
          Data.transaction(@model, 'VGD BIM · Xóa tag') do
            # Đưa các đối tượng sang tag nhận; về Untagged thì SketchUp tự làm khi gỡ tag nên không cần duyệt cả model.
            moved = tm_reassign(layer[:object], target[:object]) unless untagged
            @model.active_layer = untagged_layer if @model.active_layer == layer[:object] # SketchUp không cho gỡ tag đang hiện hành
            @model.layers.remove(layer[:object])
          end
          tm_forget_tag(layer[:name])
          emit('tag_tree', tag_tree_state)
          text = "Đã xóa tag \"#{layer[:name]}\"."
          text += " Đã chuyển #{moved} đối tượng sang tag \"#{target[:name]}\"." if !untagged && moved.positive?
          text += ' Các đối tượng đang dùng tag này đã về Untagged.' if untagged
          emit('message', {text: text})
        end

        # payload: {'name' => tên tag, 'pinned' => true / false}: ghim tag lên hàng chip phía trên danh sách (lưu trên máy, dùng cho mọi model).
        def tm_pin(payload)
          raise 'Giá trị không hợp lệ.' unless payload['pinned'] == true || payload['pinned'] == false
          Settings.set_pinned(payload['name'], payload['pinned'])
          emit('tag_tree', tag_tree_state)
        end

        # Kéo thả: đưa một tag vào thư mục (folder_id) hoặc ra gốc (folder_id nil). payload: {'id' => persistent_id của tag, 'folder_id' => persistent_id hoặc nil}
        def tm_move(payload)
          check_model!
          raise 'Phiên bản SketchUp này chưa có thư mục tag (cần SketchUp 2021 trở lên).' unless folders_supported?
          id = tm_id(payload)
          raw = payload['folder_id']
          raise 'Mã thư mục không hợp lệ.' unless raw.nil? || raw.is_a?(Integer)
          layers, folders = tag_tree_read
          item = layers.find { |entry| entry[:id] == id } or raise 'Không tìm thấy tag này. Hãy làm mới danh sách.'
          raise 'Tag Untagged không xếp vào thư mục được.' if UNTAGGED_NAMES.include?(item[:name])
          target = raw.nil? ? nil : (folders.find { |entry| entry[:id] == raw } or raise 'Không tìm thấy thư mục này. Hãy làm mới danh sách.')
          return emit('message', {text: 'Tag đã nằm sẵn ở đó.'}) if item[:folder_id] == raw
          Data.transaction(@model, 'VGD BIM · Chuyển tag vào thư mục') { item[:object].folder = target && target[:object] }
          emit('tag_tree', tag_tree_state)
          emit('message', {text: "Đã chuyển tag \"#{item[:name]}\" #{target ? "vào thư mục \"#{target[:name]}\"" : 'ra ngoài thư mục'}."})
        end

        # payload: {'enabled' => true / false}: bật / tắt chế độ tô màu theo tag của SketchUp (không nằm trong lịch sử hoàn tác của SketchUp).
        def tm_color_by_tag(payload)
          check_model!
          enabled = payload['enabled']
          raise 'Giá trị không hợp lệ.' unless enabled == true || enabled == false
          @model.rendering_options['DisplayColorByLayer'] = enabled
          emit('tag_tree', tag_tree_state)
        end

        # Cô lập: chưa cô lập thì ghi lại hiển thị hiện tại rồi ẩn mọi thứ ngoài mục được chọn; bấm lại đúng mục đó thì khôi phục;
        # bấm mục khác khi đang cô lập thì chuyển sang mục mới (vẫn nhớ hiển thị gốc từ trước lúc cô lập).
        # payload: {'kind' => 'tag' | 'folder', 'id' => persistent_id}, hoặc {'restore' => true} để chỉ khôi phục.
        def tm_isolate(payload)
          check_model!
          layers, folders = tag_tree_read
          if payload['restore'] == true || (isolation_active? && @isolation[:kind] == payload['kind'].to_s && @isolation[:id] == tm_id(payload))
            raise 'Chưa cô lập gì để khôi phục.' unless isolation_active?
            tm_restore_isolation(layers, folders)
            return
          end
          kind = payload['kind'].to_s
          id = tm_id(payload)
          name = (kind == 'folder' ? folders : layers).find { |entry| entry[:id] == id }&.fetch(:name) or raise 'Không tìm thấy tag hoặc thư mục này. Hãy làm mới danh sách.'
          plan = TagTree.isolate_plan(layers, folders, kind, id)
          saved = isolation_active? ? @isolation[:saved] : TagTree.snapshot(layers, folders)
          changes = TagTree.changes(layers, folders, plan)
          Data.transaction(@model, 'VGD BIM · Cô lập tag') { tm_apply(layers, folders, plan, changes) }
          @isolation = {model: @model, kind: kind, id: id, name: name, saved: saved}
          emit('tag_tree', tag_tree_state)
          hidden = plan[:layers].count { |_layer_id, visible| !visible }
          emit('message', {text: "Đã cô lập #{kind == 'folder' ? 'thư mục' : 'tag'} \"#{name}\" (ẩn #{hidden} tag khác). Bấm lại để khôi phục hiển thị."})
        end

        private

        # Tag xóa được: có trong model, không phải Untagged.
        def tm_deletable_layer(payload)
          id = tm_id(payload)
          layers, = tag_tree_read
          layer = layers.find { |entry| entry[:id] == id } or raise 'Không tìm thấy tag này. Hãy làm mới danh sách.'
          raise 'Tag Untagged không xóa được.' if UNTAGGED_NAMES.include?(layer[:name])
          layer
        end

        # Duyệt mọi đối tượng của model (cả trong các định nghĩa group / component) rồi gọi khối với từng đối tượng có thuộc tính layer.
        def tm_each_drawing_element
          lists = [@model.entities] + @model.definitions.to_a.map(&:entities)
          lists.each do |entities|
            entities.each { |entity| yield entity if entity.respond_to?(:layer) }
          end
        end

        # Số đối tượng (kể cả mặt, cạnh và đối tượng trong group / component) đang dùng tag. Model rất lớn thì có thể mất vài giây.
        def tm_count_users(layer)
          count = 0
          tm_each_drawing_element { |entity| count += 1 if entity.layer == layer }
          count
        end

        def tm_reassign(from, to)
          moved = 0
          tm_each_drawing_element do |entity|
            next unless entity.layer == from
            entity.layer = to
            moved += 1
          end
          moved
        end

        # Tag đã xóa thì bỏ khỏi danh sách ghim và gần đây.
        def tm_forget_tag(name)
          Settings.set_pinned(name, false)
          recent = Settings.read['recent_tags'].reject { |item| Measure.normalize(item) == Measure.normalize(name) }
          Settings.update('recent_tags' => recent)
        end

        def tm_id(payload)
          id = payload['id']
          raise 'Mã tag hoặc thư mục không hợp lệ.' unless id.is_a?(Integer)
          id
        end

        def line_styles_supported?
          @model.respond_to?(:line_styles)
        end

        def line_style_names
          line_styles_supported? ? @model.line_styles.to_a.map { |style| style.name.to_s } : []
        end

        def color_by_tag?
          @model.rendering_options['DisplayColorByLayer'] == true
        rescue StandardError
          false
        end

        def folders_supported?
          @model.layers.respond_to?(:folders)
        end

        def isolation_active?
          !@isolation.nil? && @isolation[:model].equal?(@model)
        end

        # Đọc toàn bộ tag và thư mục của model: [layers, folders], mỗi phần tử kèm :object (không gửi cho giao diện).
        def tag_tree_read
          folders = []
          if folders_supported?
            walk = lambda do |list, parent_id|
              list.each do |folder|
                folders << {id: folder.persistent_id, name: folder.name.to_s, visible: folder.visible?, parent_id: parent_id, object: folder}
                walk.call(folder.folders.to_a, folder.persistent_id)
              end
            end
            walk.call(@model.layers.folders.to_a, nil)
          end
          layers = @model.layers.to_a.map do |layer|
            parent = layer.respond_to?(:folder) ? layer.folder : nil
            style = line_styles_supported? && layer.line_style ? layer.line_style.name.to_s : ''
            {id: layer.persistent_id, name: layer.name.to_s, visible: layer.visible?, folder_id: parent ? parent.persistent_id : nil,
             color: TagTree.hex_color(layer.color.to_a), line_style: style, object: layer}
          end
          [layers, folders]
        end

        def tm_apply(layers, folders, plan, changes)
          # Thư mục trước tag khi hiện, tag trước thư mục khi ẩn không quan trọng với SketchUp, nhưng giữ thứ tự cố định cho dễ đoán.
          folders.each { |item| item[:object].visible = plan[:folders][item[:id]] if changes[:folders].include?(item[:id]) }
          layers.each { |item| item[:object].visible = plan[:layers][item[:id]] if changes[:layers].include?(item[:id]) }
        end

        def tm_restore_isolation(layers, folders)
          saved = @isolation[:saved]
          changes = TagTree.changes(layers, folders, saved)
          Data.transaction(@model, 'VGD BIM · Khôi phục hiển thị tag') { tm_apply(layers, folders, saved, changes) }
          @isolation = nil
          emit('tag_tree', tag_tree_state)
          emit('message', {text: 'Đã khôi phục hiển thị tag như trước khi cô lập.'})
        end
      end
    end
  end
end
