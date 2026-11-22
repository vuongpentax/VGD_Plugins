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
          @dialog.add_action_callback('tm_excel_open') { |_ctx, _payload| safely { tm_excel_open } }
          @dialog.add_action_callback('tm_excel_apply') { |_ctx, payload| safely { tm_excel_apply(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_pin') { |_ctx, payload| safely { tm_pin(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_move') { |_ctx, payload| safely { tm_move(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_color_by_tag') { |_ctx, payload| safely { tm_color_by_tag(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_scene_visibility') { |_ctx, payload| safely { tm_scene_visibility(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_all_visible') { |_ctx, payload| safely { tm_all_visible(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_create') { |_ctx, payload| safely { tm_create(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_rename') { |_ctx, payload| safely { tm_rename(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_explode') { |_ctx, payload| safely { tm_explode(JSON.parse(payload)) } }
          @dialog.add_action_callback('tm_hide_words') { |_ctx, payload| safely { tm_hide_words(JSON.parse(payload)) } }
        end

        # Dữ liệu gửi cho giao diện: {supported:, folders: [...], layers: [...], isolated: {kind, id, name} hoặc nil}
        def tag_tree_state
          layers, folders = tag_tree_read
          tree = {supported: folders_supported?,
                  folders: folders.map { |item| item.slice(:id, :name, :visible, :parent_id) },
                  layers: layers.map { |item| item.slice(:id, :name, :visible, :folder_id, :color, :line_style, :default) },
                  scenes: scene_list, hide_words: Settings.read['tag_hide_words'],
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

        # Scene của model: tên, có lưu hiển thị tag không (Properties to save: Visible Tags) và mã các tag đang ẩn trong scene.
        def scene_list
          return [] unless @model.respond_to?(:pages)
          @model.pages.to_a.map do |page|
            saves = page.respond_to?(:use_hidden_layers?) ? page.use_hidden_layers? : true
            folders = page.respond_to?(:layer_folders) ? page.layer_folders.to_a.map(&:persistent_id) : []
            {name: page.name.to_s, saves_tags: saves ? true : false, hidden: page.layers.to_a.map(&:persistent_id), hidden_folders: folders}
          end
        end

        # Hiện hoặc ẩn một tag hoặc thư mục ở mọi scene (chuột phải vào dòng), trừ các scene loại trừ (giữ nguyên ở scene đó).
        # payload: {'kind' => 'tag' (mặc định) | 'folder', 'id' => persistent_id, 'visible' => true / false, 'exclude' => [tên scene]}.
        # Thư mục cần Page#layer_folders (SketchUp 2021 trở lên).
        # Scene không lưu hiển thị tag thì bỏ qua (không tự bật thuộc tính đó, vì nó đổi cách scene giữ mọi tag khác).
        # Hiển thị hiện tại của model cũng đổi theo, trừ khi scene đang chọn nằm trong danh sách loại trừ. Một bước hoàn tác.
        def tm_scene_visibility(payload)
          check_model!
          id = tm_id(payload)
          visible = payload['visible']
          raise 'Giá trị hiển thị không hợp lệ.' unless visible == true || visible == false
          exclude = payload['exclude'] || []
          raise 'Danh sách scene loại trừ không hợp lệ.' unless exclude.is_a?(Array) && exclude.all? { |name| name.is_a?(String) }
          folder = payload['kind'] == 'folder'
          raise 'Loại mục không hợp lệ.' unless folder || [nil, 'tag'].include?(payload['kind'])
          layers, folders = tag_tree_read
          item = (folder ? folders : layers).find { |entry| entry[:id] == id }
          raise "Không tìm thấy #{folder ? 'thư mục' : 'tag'} này. Hãy làm mới danh sách." unless item
          raise 'Tag Untagged luôn hiện, không ẩn được.' if item[:default]
          pages = @model.respond_to?(:pages) ? @model.pages.to_a : []
          raise 'Phiên bản SketchUp này chưa ẩn / hiện thư mục theo scene được (cần SketchUp 2021 trở lên).' if folder && pages.any? { |page| !page.respond_to?(:layer_folders) }
          names = pages.map { |page| page.name.to_s }
          unknown = exclude - names
          raise "Không có scene: #{unknown.join(', ')}. Hãy làm mới danh sách." unless unknown.empty?
          applied = []
          unsaved = []
          Data.transaction(@model, "VGD BIM · #{visible ? 'Hiện' : 'Ẩn'} #{folder ? 'thư mục' : 'tag'} ở mọi scene") do
            pages.each do |page|
              next if exclude.include?(page.name.to_s)
              if page.respond_to?(:use_hidden_layers?) && !page.use_hidden_layers?
                unsaved << page.name.to_s
                next
              end
              page.set_visibility(item[:object], visible)
              applied << page.name.to_s
            end
            current = pages.empty? ? nil : @model.pages.selected_page
            item[:object].visible = visible unless current && exclude.include?(current.name.to_s)
          end
          text = "Đã #{visible ? 'hiện' : 'ẩn'} #{folder ? 'thư mục' : 'tag'} #{item[:name]} ở #{applied.size} scene."
          text += " Giữ nguyên #{exclude.size} scene loại trừ." unless exclude.empty?
          text += " Bỏ qua #{unsaved.size} scene không lưu hiển thị tag (#{unsaved.first(3).join(', ')}#{unsaved.size > 3 ? '...' : ''})." unless unsaved.empty?
          emit('message', {text: text})
          emit('tag_tree', tag_tree_state)
        end

        # Bật / tắt tất cả tag hoặc tất cả thư mục. payload: {'kind' => 'tag' | 'folder', 'visible' => true / false}. Untagged luôn hiện. Một bước hoàn tác.
        def tm_all_visible(payload)
          check_model!
          folder = tm_kind(payload) == 'folder'
          visible = payload['visible']
          raise 'Giá trị hiển thị không hợp lệ.' unless visible == true || visible == false
          raise 'Phiên bản SketchUp này chưa có thư mục tag (cần SketchUp 2021 trở lên).' if folder && !folders_supported?
          layers, folders = tag_tree_read
          items = (folder ? folders : layers).reject { |item| item[:default] || item[:visible] == visible }
          noun = folder ? 'thư mục' : 'tag'
          return emit('message', {text: "Mọi #{noun} đã #{visible ? 'hiện' : 'ẩn'} sẵn."}) if items.empty?
          Data.transaction(@model, "VGD BIM · #{visible ? 'Bật' : 'Tắt'} tất cả #{noun}") { items.each { |item| item[:object].visible = visible } }
          emit('tag_tree', tag_tree_state)
          emit('message', {text: "Đã #{visible ? 'bật' : 'tắt'} #{items.size} #{noun}."})
        end

        # Tạo tag hoặc thư mục, ở gốc hoặc trong một thư mục. payload: {'kind' => 'tag' | 'folder', 'name' => tên, 'folder_id' => persistent_id hoặc nil}.
        # Tên tag không được trùng tag khác (không phân biệt hoa thường); tên thư mục không trùng thư mục cùng cấp. Một bước hoàn tác.
        def tm_create(payload)
          check_model!
          folder = tm_kind(payload) == 'folder'
          name = tm_clean_name(payload['name'], folder)
          raw = payload['folder_id']
          raise 'Mã thư mục không hợp lệ.' unless raw.nil? || raw.is_a?(Integer)
          raise 'Phiên bản SketchUp này chưa có thư mục tag (cần SketchUp 2021 trở lên).' if (folder || raw) && !folders_supported?
          layers, folders = tag_tree_read
          parent = raw.nil? ? nil : (folders.find { |entry| entry[:id] == raw } or raise 'Không tìm thấy thư mục này. Hãy làm mới danh sách.')
          if folder
            raise "Đã có thư mục \"#{name}\" ở đây." if folders.any? { |entry| entry[:parent_id] == raw && Tags.key(entry[:name]) == Tags.key(name) }
          elsif (same = layers.find { |entry| Tags.key(entry[:name]) == Tags.key(name) })
            raise "Đã có tag \"#{same[:name]}\" trong model."
          end
          Data.transaction(@model, "VGD BIM · Tạo #{folder ? 'thư mục' : 'tag'}") do
            if folder
              (parent ? parent[:object] : @model.layers).add_folder(name)
            else
              layer = @model.layers.add(name)
              layer.folder = parent[:object] if parent
            end
          end
          emit('tag_tree', tag_tree_state)
          where = parent ? " trong thư mục \"#{parent[:name]}\"" : ''
          emit('message', {text: "Đã tạo #{folder ? 'thư mục' : 'tag'} \"#{name}\"#{where}."})
        end

        # Đổi tên tag hoặc thư mục (nhấp đúp vào tên). payload: {'kind' => 'tag' | 'folder', 'id' => persistent_id, 'name' => tên mới}.
        # Untagged không đổi tên được; tên tag không trùng tag khác. Ghim / gần đây theo tên mới. Một bước hoàn tác.
        def tm_rename(payload)
          check_model!
          folder = tm_kind(payload) == 'folder'
          id = tm_id(payload)
          name = tm_clean_name(payload['name'], folder)
          layers, folders = tag_tree_read
          item = (folder ? folders : layers).find { |entry| entry[:id] == id }
          raise "Không tìm thấy #{folder ? 'thư mục' : 'tag'} này. Hãy làm mới danh sách." unless item
          raise 'Tag Untagged không đổi tên được.' if item[:default]
          return emit('message', {text: 'Tên không đổi.'}) if item[:name] == name
          if folder
            raise "Đã có thư mục \"#{name}\" ở đây." if folders.any? { |entry| entry[:id] != id && entry[:parent_id] == item[:parent_id] && Tags.key(entry[:name]) == Tags.key(name) }
          elsif (same = layers.find { |entry| entry[:id] != id && Tags.key(entry[:name]) == Tags.key(name) })
            raise "Đã có tag \"#{same[:name]}\" trong model."
          end
          Data.transaction(@model, "VGD BIM · Đổi tên #{folder ? 'thư mục' : 'tag'}") { item[:object].name = name }
          tm_rename_saved(item[:name], name) unless folder
          emit('tag_tree', tag_tree_state)
          emit('message', {text: "Đã đổi tên #{folder ? 'thư mục' : 'tag'} \"#{item[:name]}\" thành \"#{name}\"."})
        end

        # Rã thư mục: đưa mọi tag và thư mục con ra thư mục cha (hoặc ra gốc) rồi bỏ thư mục. Không đổi tag hay đối tượng nào khác.
        # payload: {'id' => persistent_id của thư mục}. Một bước hoàn tác.
        def tm_explode(payload)
          check_model!
          raise 'Phiên bản SketchUp này chưa có thư mục tag (cần SketchUp 2021 trở lên).' unless folders_supported?
          id = tm_id(payload)
          layers, folders = tag_tree_read
          item = folders.find { |entry| entry[:id] == id } or raise 'Không tìm thấy thư mục này. Hãy làm mới danh sách.'
          parent = folders.find { |entry| entry[:id] == item[:parent_id] }
          container = parent ? parent[:object] : @model.layers
          kids = folders.select { |entry| entry[:parent_id] == id }
          tags = layers.select { |entry| entry[:folder_id] == id }
          Data.transaction(@model, 'VGD BIM · Rã thư mục') do
            tags.each { |entry| entry[:object].folder = parent && parent[:object] }
            kids.each { |entry| container.add_folder(entry[:object]) } # add_folder nhận thư mục có sẵn thì chuyển nó sang chỗ mới
            container.remove_folder(item[:object])
          end
          emit('tag_tree', tag_tree_state)
          where = parent ? "thư mục \"#{parent[:name]}\"" : 'ngoài cùng'
          emit('message', {text: "Đã rã thư mục \"#{item[:name]}\": #{tags.size} tag và #{kids.size} thư mục con chuyển ra #{where}."})
        end

        # Danh sách loại trừ: tag và thư mục có tên chứa một từ trong danh sách không hiện ở cây (chỉ ẩn khỏi danh sách, không đổi model).
        # Lưu trên máy, dùng cho mọi model. payload: {'words' => 'từ 1, từ 2'} (rỗng = bỏ loại trừ).
        def tm_hide_words(payload)
          raise 'Danh sách loại trừ không hợp lệ.' unless payload['words'].is_a?(String)
          Settings.update('tag_hide_words' => payload['words'])
          emit('tag_tree', tag_tree_state)
          emit('message', {text: payload['words'].strip.empty? ? 'Đã bỏ danh sách loại trừ.' : 'Đã lưu danh sách loại trừ.'})
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

        # Nhập tag từ Excel, bước 1: chọn file .xlsx, đọc và gửi bản xem trước cho giao diện (chưa đổi gì trong model).
        def tm_excel_open
          check_model!
          path = ::UI.openpanel('Nhập tag từ Excel (.xlsx)', '', 'Excel|*.xlsx||')
          return unless path
          raise 'Hãy chọn file Excel đuôi .xlsx.' unless File.extname(path).downcase == '.xlsx'
          raise 'File Excel quá lớn (tối đa 5 MB).' if File.size(path) > XlsxReader::MAX_FILE_BYTES
          parsed = TagExcel.parse(XlsxReader.read(File.binread(path)))
          layers, = tag_tree_read
          present = layers.map { |layer| Tags.key(layer[:name]) }
          rows = parsed[:tags].map { |tag| tag.merge('exists' => present.include?(Tags.key(tag['name']))) }
          emit('tag_excel', {file: File.basename(path), rows: rows, warnings: parsed[:warnings].first(10), more_warnings: [parsed[:warnings].size - 10, 0].max,
                             styles_supported: line_styles_supported?, folders_supported: folders_supported?})
        end

        # Nhập tag từ Excel, bước 2. payload: {'rows' => [{'name','color','style','folder'}] (các dòng đã tick), 'overwrite' => true / false}.
        # Tag mới thì tạo kèm màu, kiểu nét, thư mục; tag đã có chỉ bị đổi khi bật ghi đè, còn không thì bỏ qua. Một bước hoàn tác.
        def tm_excel_apply(payload)
          check_model!
          rows = TagExcel.sanitize(payload['rows'])
          raise 'Chưa chọn tag nào để nhập.' if rows.empty?
          overwrite = payload['overwrite'] == true
          style_names = line_styles_supported? ? @model.line_styles.to_a.map { |style| style.name.to_s } : []
          counts = {created: 0, updated: 0, skipped: 0, folders: 0}
          unknown_styles = []
          Data.transaction(@model, 'VGD BIM · Nhập tag từ Excel') do
            folders = {}
            @model.layers.folders.each { |folder| folders[Tags.key(folder.name)] ||= folder } if folders_supported?
            rows.each do |row|
              layer = Tags.find_layer(@model, row['name'])
              if layer && !overwrite
                counts[:skipped] += 1
                next
              end
              fresh = layer.nil?
              layer ||= @model.layers.add(row['name'])
              layer.color = Sketchup::Color.new(*TagTree.parse_color(row['color'])) if row['color']
              unless row['style'].empty?
                style_name = TagExcel.match_style(row['style'], style_names)
                if style_name then layer.line_style = @model.line_styles.to_a.find { |style| style.name.to_s == style_name } else unknown_styles << row['style'] end
              end
              if !row['folder'].empty? && folders_supported?
                key = Tags.key(row['folder'])
                unless folders[key]
                  folders[key] = @model.layers.add_folder(row['folder'])
                  counts[:folders] += 1
                end
                layer.folder = folders[key]
              end
              fresh ? counts[:created] += 1 : counts[:updated] += 1
            end
          end
          emit('tag_tree', tag_tree_state)
          emit('tag_excel', {cleared: true})
          text = "Đã nhập #{counts[:created] + counts[:updated]} tag từ Excel (#{counts[:created]} mới tạo, #{counts[:updated]} cập nhật)."
          text += " Bỏ qua #{counts[:skipped]} tag đã có trong model." if counts[:skipped].positive?
          text += " Đã tạo #{counts[:folders]} thư mục tag." if counts[:folders].positive?
          text += " Kiểu nét không nhận ra, đã bỏ qua: #{unknown_styles.uniq.first(5).join(', ')}." unless unknown_styles.empty?
          emit('message', {text: text})
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
          Data.transaction(@model, 'VGD BIM · Tô màu theo tag') { @model.rendering_options['DisplayColorByLayer'] = enabled }
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

        def tm_kind(payload)
          kind = payload['kind'].to_s
          raise 'Loại mục không hợp lệ.' unless %w[tag folder].include?(kind)
          kind
        end

        # Tên tag / thư mục người dùng gõ: bỏ khoảng trắng thừa, không rỗng, không quá dài, không dùng tên của tag mặc định.
        def tm_clean_name(raw, folder)
          raise 'Tên không hợp lệ.' unless raw.is_a?(String)
          name = raw.strip.gsub(/\s+/, ' ')
          noun = folder ? 'thư mục' : 'tag'
          raise "Hãy nhập tên #{noun}." if name.empty?
          raise "Tên #{noun} quá dài (tối đa #{Tags::MAX_NAME} ký tự)." if name.length > Tags::MAX_NAME
          raise "Tên \"#{name}\" là tên tag mặc định của SketchUp, hãy chọn tên khác." if UNTAGGED_NAMES.any? { |item| Tags.key(item) == Tags.key(name) }
          name
        end

        # Tag đổi tên: ghim và gần đây theo tên mới.
        def tm_rename_saved(old_name, new_name)
          key = Measure.normalize(old_name)
          data = Settings.read
          pinned = data['pinned_tags'].map { |item| Measure.normalize(item) == key ? new_name : item }
          recent = data['recent_tags'].map { |item| Measure.normalize(item) == key ? new_name : item }
          Settings.update('pinned_tags' => pinned, 'recent_tags' => recent) unless pinned == data['pinned_tags'] && recent == data['recent_tags']
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
             color: TagTree.hex_color(layer.color.to_a), line_style: style, default: UNTAGGED_NAMES.include?(layer.name.to_s), object: layer}
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
