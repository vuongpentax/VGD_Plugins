require 'json'
module VGD
  module BIM
    module UI
      class SelectionObserver < Sketchup::SelectionObserver
        def initialize(panel); @panel = panel; end
        def onSelectionBulkChange(selection); @panel.selection_changed; end
        def onSelectionAdded(selection, entity); @panel.selection_changed; end
        def onSelectionRemoved(selection, entity); @panel.selection_changed; end
        def onSelectionCleared(selection); @panel.selection_changed; end
      end
      class Dialog
        # 5 tab: Bảng khối lượng · Thông tin · Quét & xuất · Phân loại (gồm Quy tắc, Kiểm tra) · Soạn tag.
        MODES = %w[table information scan mapping rules validate_model validate_selection tags].freeze
        # Tên cũ vẫn mở được, chuyển về tab đã gộp.
        ALIASES = {'export' => 'scan', 'convert_selection' => 'information'}.freeze
        def initialize(mode)
          @mode = mode
          @records = []
          @rows = []
          @targets = []
          @generation = 0
          @scan_options = {scope: 'model', faces: nil}
          @table_rows = []
          @table_records = []
          @table_scope = []
          @table_pick = nil
          @table_options = {zoom: true, isolate: false, deep: false}
          @isolated = []
          @preview = nil
          @ready = false
          @closed = false
          @dialog = ::UI::HtmlDialog.new(dialog_title: 'VGD_BIM · Dữ liệu mô hình', preferences_key: 'VGD_BIM_Workspace', scrollable: true, resizable: true, width: 860, height: 740, style: ::UI::HtmlDialog::STYLE_DIALOG)
          @dialog.set_file(File.join(BIM::ROOT, 'html', 'index.html'))
          @dialog.add_action_callback('ready') { |_ctx| safely { @ready = true; refresh } }
          @dialog.add_action_callback('open_panel') { |_ctx, mode| safely { switch_mode(mode) } }
          @dialog.add_action_callback('export_report') { |_ctx, kind| safely { export_report(kind) } }
          @dialog.add_action_callback('save_rule') do |_ctx, payload|
            safely do
              check_model!
              rule = JSON.parse(payload)
              rules = MappingRules.read(@model)
              rules.delete_at(rule.delete('index').to_i) if rule.key?('index')
              rules.reject! { |r| r['source_type'] == rule['source_type'] && r['source_value'] == rule['source_value'] }
              MappingRules.save(rules + [rule], @model)
              refresh
              emit('message', {text: 'Đã lưu quy tắc phân loại.'})
            end
          end
          @dialog.add_action_callback('apply') { |_ctx, payload| safely { apply(JSON.parse(payload)) } }
          @dialog.add_action_callback('clear') { |_ctx| safely { clear } }
          @dialog.add_action_callback('select_entity') { |_ctx, index| safely { select_entity(index.to_i) } }
          @dialog.add_action_callback('preview_convert') { |_ctx, payload| safely { preview_convert(JSON.parse(payload)) } }
          @dialog.add_action_callback('confirm_convert') { |_ctx| safely { confirm_convert } }
          @dialog.add_action_callback('save_rules') { |_ctx, payload| safely { check_model!; MappingRules.save(JSON.parse(payload)); refresh } }
          @dialog.add_action_callback('export_rules') { |_ctx| safely { check_model!; path = ::UI.savepanel('Xuất quy tắc phân loại', '', 'VGD_Quy_tac_phan_loai.json'); if path; MappingRules.export_file(path); emit('message', {text: "Đã xuất quy tắc: #{path}"}); end } }
          @dialog.add_action_callback('import_rules') { |_ctx| safely { check_model!; path = ::UI.openpanel('Nhập quy tắc phân loại', '', 'JSON|*.json||'); if path; MappingRules.import_file(path); refresh; end } }
          @dialog.add_action_callback('save_tags') { |_ctx, payload| safely { Tags.save(JSON.parse(payload)); refresh; emit('message', {text: 'Đã lưu bộ tag trên máy này.'}) } }
          @dialog.add_action_callback('assign_tag') { |_ctx, payload| safely { assign_tag(JSON.parse(payload)) } }
          @dialog.add_action_callback('scan_options') { |_ctx, payload| safely { set_scan_options(JSON.parse(payload)) } }
          @dialog.add_action_callback('export_tags') { |_ctx, kind| safely { export_tags(kind) } }
          @dialog.add_action_callback('import_tags') { |_ctx, kind| safely { import_tags(kind) } }
          @dialog.add_action_callback('table_select') { |_ctx, payload| safely { table_select(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_edit') { |_ctx, payload| safely { table_edit(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_option') { |_ctx, payload| safely { table_option(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_preset') { |_ctx, payload| safely { table_preset(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_clear') { |_ctx| safely { table_clear } }
          @dialog.add_action_callback('table_view') { |_ctx, payload| safely { Table.save_view_state(JSON.parse(payload)) } }
          @dialog.set_on_closed { @closed = true; @ready = false; @generation += 1; cleanup_table_view; detach; ::UI.stop_timer(@selection_timer) if @selection_timer }
        end
        def show; @dialog.visible? ? @dialog.bring_to_front : @dialog.show; end
        def visible?; @dialog.visible?; end
        def closed?; @closed; end
        def close; @dialog.close; end
        def switch_mode(mode)
          mode = ALIASES.fetch(mode, mode)
          raise ArgumentError, 'Tính năng không hợp lệ.' unless MODES.include?(mode)
          @mode = mode
          refresh if @ready
        end
        def safely
          yield
        rescue StandardError => error
          BIM.log(error.message)
          text = error.message.match?(/[À-ỹ]/) ? error.message : 'Không thực hiện được thao tác. Hãy làm mới dữ liệu và thử lại.'
          text = 'Không ghi được tệp. Kiểm tra vị trí lưu và đóng tệp nếu đang mở trong Excel.' if error.is_a?(SystemCallError)
          emit('message', {error: text})
        end
        def emit(event, payload)
          json = JSON.generate(payload).gsub('<', '\\u003c').gsub("\u2028", '\\u2028').gsub("\u2029", '\\u2029')
          @dialog.execute_script("window.VGD.receive(#{JSON.generate(event)}, #{json})")
        end
        def check_model!
          raise 'Mô hình đã thay đổi. Hãy làm mới trước khi tiếp tục.' unless @model == Sketchup.active_model
        end
        def detach
          @model.selection.remove_observer(@observer) if @model && @observer
          @observer = nil
        rescue StandardError
          @observer = nil
        end
        # Gom nhiều sự kiện chọn liên tiếp thành một lần xử lý.
        # Bảng: đọc đối tượng mới chọn. Soạn tag: chỉ cập nhật số đang chọn (giữ nội dung đang soạn). Thông tin: đọc lại.
        def selection_changed
          handler = {'table' => -> { table_selection_changed },
                     'tags' => -> { emit('selection', {count: taggable_selection.size}) },
                     'information' => -> { refresh }}[@mode]
          return unless handler && @dialog.visible?
          ::UI.stop_timer(@selection_timer) if @selection_timer
          @selection_timer = ::UI.start_timer(0.05, false) { safely { handler.call if @dialog.visible? } }
        end
        def refresh
          @generation += 1
          @pending = nil
          @scan_complete = false
          @rows = []
          @validation = []
          @targets = []
          detach
          cleanup_table_view unless @mode == 'table'
          @model = Sketchup.active_model
          emit('config', {mode: @mode, version: BIM::VERSION, fields: Schema::FIELDS, categories: Schema::CATEGORIES, units: Schema::UNITS, methods: Schema::METHODS, presets: BIM.presets, locale: Locale.dictionary, scan_options: {scope: @scan_options[:scope], faces: faces?}})
          if %w[information tags table].include?(@mode)
            @observer = SelectionObserver.new(self)
            @model.selection.add_observer(@observer)
          end
          case @mode
          when 'information'
            @targets = @model.selection.to_a.select { |e| Data.supported?(e) && e.valid? }
            ancestor_locked = (@model.active_path || []).any? { |e| e.locked? }
            @records = @targets.map { |e| {entity: e, path: (@model.active_path || []) + [e], transform: @model.edit_transform * e.transformation, locked: ancestor_locked || e.locked?} }
            fields = Schema::FIELDS.each_with_object({}) do |key, h|
              values = @targets.map { |e| Data.has_data?(e) ? Data.read(e)[key] : Schema::DEFAULTS[key] }.uniq
              h[key] = values.size == 1 ? values.first : nil
            end
            objects = @records.map { |r| RawScanner.identity(r[:entity]).merge(dimensions: Geometry.dimensions(r[:entity], r[:transform]), source: Data.source(r[:entity]), status: Validator.validate([r]).first[:status], locked: r[:locked]) }
            emit('information', {count: @targets.size, fields: fields, objects: objects})
          when 'tags'
            emit('tags', tag_state)
          when 'table'
            table_scan_selection!
            table_build
          when 'rules'
            emit('rules', MappingRules.read(@model))
          else
            scan_now
          end
        end
        # Quét một mạch, không dùng bộ hẹn giờ, nên không bị ngắt khi di chuột hoặc thao tác khác.
        def scan_now
          @records = []
          selection = scope_selection?
          roots = selection ? @model.selection.to_a : @model.entities
          if selection && roots.empty?
            emit('message', {error: 'Hãy chọn group hoặc đối tượng cần quét trong SketchUp.'})
            return
          end
          transform = selection ? @model.edit_transform : Geom::Transformation.new
          path = selection ? (@model.active_path || []) : []
          begin
            Sketchup.status_text = 'VGD BIM · Đang quét mô hình…'
            Scanner.walk(roots, transform, path, [], nil, false, faces: faces?) { |r| @records << r }
          ensure
            Sketchup.status_text = ''
          end
          finish_scan
        end
        def scope_selection?
          @mode == 'validate_selection' || (%w[scan mapping].include?(@mode) && @scan_options[:scope] == 'selection')
        end
        def faces?
          return false unless %w[scan mapping].include?(@mode)
          @scan_options[:faces].nil? ? true : @scan_options[:faces]
        end
        def set_scan_options(payload)
          @scan_options[:scope] = payload['scope'] == 'selection' ? 'selection' : 'model'
          @scan_options[:faces] = payload['faces'] ? true : false
          refresh
        end
        def finish_scan
          @scan_complete = true
          if @mode.start_with?('validate')
            @validation = Validator.validate(@records)
            rows = @validation.each_with_index.map do |r, index|
              RawScanner.identity(r[:entity]).merge(index: index, status: r[:status], issues: r[:issues], path: r[:path].select { |e| Data.supported?(e) }.map { |e| e.name.to_s.empty? ? Geometry.definition(e).name : e.name }.join(' / '))
            end
            emit('validation', rows)
          else
            report = RawScanner.report(@records, @model)
            if @mode == 'mapping'
              @rows = Mapping.rows(@records) + Mapping.material_rows(report)
              emit('mapping', @rows.each_with_index.map { |r, index| r.reject { |k, _| k == :occurrences }.merge(index: index) })
            else
              # Quét & xuất: báo cáo quét kèm số liệu cho phần xuất file.
              emit('scan', report.merge(export: {objects: @records.count { |r| Data.supported?(r[:entity]) }, faces: report[:summary][:raw_faces]}))
            end
          end
        end
        def apply(payload)
          check_model!
          check_selection!
          raise 'Hãy chọn nhóm hoặc đối tượng thành phần trong SketchUp trước.' if @targets.empty?
          values = Schema.normalize(payload)
          raise 'Hãy đánh dấu ít nhất một trường cần cập nhật.' if values.empty?
          targets = writable_selection
          Data.transaction(@model) { targets.each { |e| Data.write(e, values, Data.source(e) == 'RAW' ? 'MANUAL' : Data.source(e)) } }
          refresh
          emit('message', {text: "Đã cập nhật #{targets.size} đối tượng; bỏ qua #{@targets.size - targets.size} đối tượng bị khóa."})
        end
        # Xuất / nhập bộ tag. Excel dùng file CSV (mở và lưu được bằng Excel).
        def export_tags(kind)
          list = Tags.load
          json = kind == 'json'
          path = ::UI.savepanel(json ? 'Xuất bộ tag (JSON)' : 'Xuất bộ tag (Excel / CSV)', '', json ? 'VGD_bo_tag.json' : 'VGD_bo_tag.csv')
          return unless path
          ext = json ? '.json' : '.csv'
          path += ext unless File.extname(path).downcase == ext
          File.open(path, 'wb') { |file| file.write(json ? Tags.to_json(list) : Tags.to_csv(list)) }
          emit('message', {text: "Đã xuất #{list.size} tag: #{path}"})
        end
        def import_tags(kind)
          json = kind == 'json'
          path = ::UI.openpanel(json ? 'Nhập bộ tag (JSON)' : 'Nhập bộ tag (Excel / CSV)', '', json ? 'JSON|*.json||' : 'CSV|*.csv||')
          return unless path
          text = File.read(path, encoding: 'bom|utf-8')
          incoming = json ? Tags.from_json(text) : Tags.from_csv(text)
          replace = ::UI.messagebox("Thay thế toàn bộ bộ tag hiện tại?\n\nCó: thay thế bằng bộ trong file.\nKhông: gộp vào bộ hiện tại (tag trùng tên sẽ lấy từ file).", MB_YESNO) == IDYES
          merged = replace ? incoming : Tags.merge(Tags.load, incoming)
          Tags.save(merged)
          refresh
          emit('message', {text: "Đã nhập #{incoming.size} tag. Bộ tag hiện có #{merged.size} tag."})
        end
        # Bảng đối tượng kiểu Auto Info. Mỗi dòng là một group / component trong model.
        # Phạm vi quét = đối tượng đang chọn lúc quét. Chỉ đổi khi người dùng chọn đối tượng khác bên ngoài bảng.
        def table_scan_selection!
          @model = Sketchup.active_model
          @table_scope = @model.selection.to_a.select { |e| Data.supported?(e) && e.valid? }
          @table_pick = nil
        end
        def table_selection_changed
          @model = Sketchup.active_model
          current = @model.selection.to_a.select { |e| Data.supported?(e) && e.valid? }
          if current.empty?
            # Bấm vùng trống trong SketchUp: giữ nguyên bảng, chỉ bỏ đánh dấu.
            # Nếu vừa xóa đối tượng thì đọc lại để bỏ các dòng đã xóa.
            @table_pick = nil
            @outline_field = nil
            if Array(@table_records).any? { |r| !r[:path].all?(&:valid?) }
              table_build
            else
              emit('highlight', {index: nil})
            end
          elsif @table_pick && current.size == 1 && current.first == @table_pick
            # Chọn dòng hoặc ô trong bảng: chỉ đánh dấu, không quét lại.
            highlight_selection
          else
            # Chọn đối tượng mới trong SketchUp: quét lại và làm mới bảng.
            @outline_field = nil
            table_scan_selection!
            table_build
          end
          show_outline
        end
        def table_build
          @model = Sketchup.active_model
          scope = @table_scope.select(&:valid?)
          built = Table.build(@model, scope, @table_options[:deep] ? true : false)
          @table_rows = built[:rows]
          @table_records = built[:records]
          hint = scope.empty? ? 'Chưa chọn đối tượng nào. Chọn group hoặc component trong SketchUp, bảng sẽ tự đọc.' : nil
          emit('table', {columns: Table::COLUMNS, presets: Table.presets, groups: Tags::GROUPS + [Table::UNTAGGED_GROUP],
                         statuses: Table::STATUS_LABELS, options: @table_options.merge(isolating: !@isolated.empty?),
                         rows: @table_rows, selected: selected_index, hint: hint, view: Table.view_state})
        end
        # payload: {'index' => dòng, 'field' => tên cột đã bấm (hoặc rỗng nếu bấm cả dòng)}
        def table_select(payload)
          check_model!
          index = payload.fetch('index').to_i
          record = @table_records.fetch(index) { raise 'Bảng đã cũ. Hãy làm mới bảng.' }
          raise 'Đối tượng không còn tồn tại. Hãy làm mới bảng.' unless record[:path].all?(&:valid?)
          changed = @table_pick != record[:entity]
          @table_pick = record[:entity]
          field = payload['field'].to_s
          @outline_field = field.empty? ? nil : field
          parents = record[:path][0...-1]
          @model.active_path = parents unless (@model.active_path || []) == parents
          @model.selection.clear
          @model.selection.add(record[:entity])
          if changed
            # Chỉ cô lập / zoom khi chuyển sang đối tượng khác, không làm lại khi bấm ô khác của cùng dòng.
            apply_isolation(record) if @table_options[:isolate]
            @model.active_view.zoom([record[:entity]]) if @table_options[:zoom] && record[:entity].valid?
          end
          show_outline
        end
        def apply_isolation(record)
          restore_isolation
          @isolated = Table.isolate(@model, record[:path])
        end
        def table_edit(payload)
          check_model!
          record = @table_records.fetch(payload.fetch('index').to_i) { raise 'Bảng đã cũ. Hãy làm mới bảng.' }
          entity = record[:entity]
          raise 'Đối tượng không còn tồn tại. Hãy làm mới bảng.' unless entity.valid?
          raise 'Đối tượng đang bị khóa nên không sửa được.' if record[:locked] || entity.locked?
          field = payload.fetch('field')
          value = payload.fetch('value').to_s.strip
          Data.transaction(@model, 'VGD BIM · Sửa bảng') do
            case field
            when 'name'
              entity.name = value
            when 'description', 'status'
              Data.write(entity, {field.to_sym => value}, Data.source(entity) == 'RAW' ? 'MANUAL' : Data.source(entity))
            else
              raise ArgumentError, 'Ô này không sửa được trong bảng.'
            end
          end
          table_build
          show_outline
        end
        def table_option(payload)
          check_model!
          @table_options[:zoom] = payload['zoom'] ? true : false if payload.key?('zoom')
          if payload.key?('deep')
            # Bật / tắt đọc sâu: đọc lại từ phạm vi đã quét, không đổi lựa chọn hiện tại.
            @table_options[:deep] = payload['deep'] ? true : false
            table_build
          end
          if payload.key?('isolate')
            if payload['isolate']
              @table_options[:isolate] = true
              index = selected_index
              apply_isolation(@table_records[index]) if index
            else
              @table_options[:isolate] = false
              restore_isolation
            end
          end
          emit('options', @table_options.merge(isolating: !@isolated.empty?))
        end
        def table_preset(payload)
          case payload['action']
          when 'save'
            Table.save_preset(payload['name'], payload['group'], payload['columns'])
            # Đổi cột của preset tự tạo thì cập nhật ngầm, không báo.
            emit('message', {text: "Đã lưu preset \"#{payload['name'].to_s.strip}\"."}) unless payload['silent']
          when 'delete'
            Table.delete_preset(payload['name'])
            emit('message', {text: 'Đã xóa preset.'})
          else
            raise ArgumentError, 'Thao tác preset không hợp lệ.'
          end
          emit('presets', Table.presets)
        end
        def table_clear
          check_model!
          release_preview
          @model.selection.clear
          emit('highlight', {index: nil})
        end
        def highlight_selection
          return unless @model && @model == Sketchup.active_model
          emit('highlight', {index: selected_index})
        end
        def selected_index
          return nil unless @model
          selected = @model.selection.to_a
          return nil unless selected.size == 1
          @table_records.index { |record| record[:entity] == selected.first }
        end
        # Vẽ khung nét đứt + khung tên cho các đối tượng đang được chọn (trong SketchUp hoặc trong bảng).
        # Khung tên chỉ hiện khi chọn đúng một đối tượng.
        def show_outline
          release_preview
          return unless @model && @model == Sketchup.active_model && @dialog.visible?
          selected = @model.selection.to_a
          targets = Array(@table_records).select { |r| r[:path].all?(&:valid?) && selected.include?(r[:entity]) }
          return if targets.empty?
          points = targets.flat_map { |r| Table.world_corners(r) }
          return if points.empty?
          single = targets.size == 1 ? targets.first : nil
          label = single ? outline_label(single) : nil
          box = single ? Table.bounding_box(single) : nil
          label_point = box && !box.empty? ? box.center : nil
          fills = targets.flat_map { |r| Table.face_triangles(r) }
          # Đối tượng bị xóa: khung tự tắt và bảng bỏ dòng đã xóa.
          alive = -> { targets.all? { |r| r[:path].all?(&:valid?) } }
          stale = -> { safely { table_build if @mode == 'table' && @dialog.visible? } }
          return if show_overlay(points, label, label_point, fills, alive, stale)
          @preview = UI::BoundsPreview.new(points, label: label, label_point: label_point, fills: fills, alive: alive, on_stale: stale) { @preview = nil }
          @model.tools.push_tool(@preview)
          @model.active_view.invalidate
        end
        def outline_label(record)
          index = @table_records.index { |r| r.equal?(record) }
          row = index && @table_rows[index]
          return '' unless row
          @outline_field.nil? ? summary_label(row) : field_label(row, @outline_field)
        end
        # Cả dòng (khi bấm vào dòng hoặc chọn trong SketchUp): tên · mô tả · tình trạng · phân loại.
        def summary_label(row)
          name = row[:name].to_s.strip
          name = row[:definition].to_s.strip if name.empty?
          [name, row[:description], Table::STATUS_LABELS[row[:status]], row[:tag]].map { |s| s.to_s.strip }.reject(&:empty?).join(' · ')
        end
        # Chỉ nội dung của ô vừa bấm, hiển thị giống cách bảng hiện.
        def field_label(row, key)
          case key
          when 'ordinal' then (row[:index] + 1).to_s
          when 'entity' then row[:entity_type].to_s
          when 'instance' then row[:name].to_s.strip.empty? ? row[:definition].to_s : row[:name].to_s
          when 'description' then row[:description].to_s
          when 'lenX', 'lenY', 'lenZ' then "#{num(row[key.to_sym])} mm"
          when 'lenXZ' then "#{num(row[:lenX])} x #{num(row[:lenZ])} mm"
          when 'lenXY' then "#{num(row[:lenX])} x #{num(row[:lenY])} mm"
          when 'lenXYZ' then "#{num(row[:lenX])} x #{num(row[:lenY])} x #{num(row[:lenZ])} mm"
          when 'areaXZ', 'areaXY', 'areaFace' then "#{num(row[key.to_sym])} m²"
          when 'volume' then row[:volume] ? "#{num(row[:volume])} m³" : ''
          when 'quantity' then "#{num(row[:quantity])} cái"
          when 'status' then Table::STATUS_LABELS[row[:status]].to_s
          when 'definition', 'material', 'tag', 'tag_group' then row[key.to_sym].to_s
          else ''
          end
        end
        def num(value)
          return '' if value.nil?
          value.is_a?(Float) && value == value.round ? value.round.to_s : value.to_s
        end
        # SketchUp 2023+: khung vẽ bằng lớp phủ (Overlay) nên công cụ Select của SketchUp giữ nguyên (Shift/Ctrl, kéo chọn,
        # nhấp đúp). SketchUp 2022 hoặc khi lớp phủ lỗi: dùng BoundsPreview (công cụ), có hạn chế ở click chuột.
        def overlay_available?
          defined?(UI::BoundsOverlay) && !@overlay_failed ? true : false
        end
        # Trả về true nếu đã hiện khung bằng lớp phủ, false nếu phải dùng công cụ.
        def show_overlay(points, label, label_point, fills, alive, stale)
          return false unless overlay_available?
          outline_overlay.show_shapes(points, label: label, label_point: label_point, fills: fills, alive: alive, on_stale: stale)
          @model.active_view.invalidate
          true
        rescue StandardError => error
          BIM.log("Lớp phủ lỗi, dùng công cụ vẽ khung: #{error.message}")
          @overlay_failed = true
          remove_overlay
          false
        end
        # Mỗi model một lớp phủ, đăng ký một lần rồi dùng lại cho mọi lần chọn.
        def outline_overlay
          return @overlay if @overlay && @overlay_model == @model
          remove_overlay
          overlay = UI::BoundsOverlay.new
          @model.overlays.add(overlay)
          overlay.enabled = true if overlay.respond_to?(:enabled=)
          @overlay_model = @model
          @overlay = overlay
        end
        def hide_overlay
          return unless @overlay
          @overlay.hide_shapes
          @overlay_model.active_view.invalidate
        rescue StandardError
          nil
        end
        def remove_overlay
          return unless @overlay
          overlay = @overlay
          model = @overlay_model
          @overlay = nil
          @overlay_model = nil
          model.overlays.remove(overlay) if model
        rescue StandardError
          nil
        end
        def release_preview
          hide_overlay
          return unless @preview
          tool = @preview
          @preview = nil
          tool.finish(@model.active_view)
        end
        def restore_isolation
          Table.restore(@isolated) unless @isolated.empty?
          @isolated = []
        end
        def cleanup_table_view
          release_preview
          remove_overlay
          restore_isolation
        end
        # Đối tượng có thể gán tag: group, component và mặt đang chọn.
        def taggable_selection
          @model.selection.to_a.select { |e| (Data.supported?(e) || e.is_a?(Sketchup::Face)) && e.valid? }
        end
        def tag_state
          tags = Tags.load.map do |tag|
            layer = Tags.find_layer(@model, tag['name'])
            tag.merge('in_model' => !layer.nil?, 'visible' => layer ? layer.visible? : true)
          end
          {tags: tags, groups: Tags::GROUPS, selection: taggable_selection.size}
        end
        def assign_tag(payload)
          check_model!
          entities = taggable_selection
          raise 'Hãy chọn đối tượng hoặc mặt trong SketchUp trước khi gán tag.' if entities.empty?
          name = payload.fetch('name')
          result = Tags.assign(@model, entities, name)
          text = "Đã gán tag \"#{name}\" cho #{result[:count]} đối tượng."
          text += " Bỏ qua #{result[:locked]} đối tượng bị khóa." if result[:locked] > 0
          text += ' Tag này đang tắt hiển thị nên các đối tượng gán vào sẽ bị ẩn.' if result[:hidden]
          emit('message', {text: text})
          emit('selection', {count: taggable_selection.size})
        end
        def clear
          check_model!
          check_selection!
          return unless ::UI.messagebox('Xóa dữ liệu VGD của các đối tượng đang chọn? Hình học vẫn được giữ nguyên.', MB_YESNO) == IDYES
          check_selection!
          targets = writable_selection
          Data.transaction(@model, 'VGD BIM Clear') { targets.each { |e| Data.erase(e) } }
          refresh
        end
        def check_selection!
          current = @model.selection.to_a.select { |e| Data.supported?(e) && e.valid? }
          raise 'Lựa chọn đã thay đổi. Hãy làm mới trước khi áp dụng.' unless current.size == @targets.size && (current - @targets).empty?
        end
        # Đối tượng ghi được: còn tồn tại, không bị khóa, và không nằm trong group cha bị khóa.
        # Chỉ xét đường dẫn đang mở, không quét toàn bộ model.
        def writable_selection
          return [] if (@model.active_path || []).any?(&:locked?)
          @targets.select { |e| e.valid? && !e.locked? }
        end
        def preview_convert(payload)
          check_model!
          row = @mode == 'mapping' ? @rows.fetch(payload.fetch('index').to_i) : nil
          records = row ? row[:occurrences] : @records
          unless row && row[:kind] == 'material'
            entities = records.map { |r| r[:entity] }.uniq
            records = Scanner.scan_model(@model).select { |r| entities.include?(r[:entity]) }
          end
          values = Schema.normalize(payload.fetch('data'))
          rule = if row && (payload['save_rule'] || row[:kind] == 'material')
                   { 'source_type' => row[:source_type], 'source_value' => row[:source_value], 'data' => values }
                 end
          plan = Converter.preview(records, values)
          @pending = {records: records, values: values, rule: rule, token: @generation, plan: plan}
          emit('preview', {objects: plan[:entities].size, occurrences: plan[:occurrences], skipped: plan[:skipped], data: values, rule: !!rule, material: row && row[:kind] == 'material', shared: records.any? { |r| r[:path].size > 1 }})
        end
        def confirm_convert
          check_model!
          pending = @pending
          raise 'Bản xem trước đã hết hiệu lực. Hãy xem trước lại.' unless pending && pending[:token] == @generation
          @pending = nil
          # Re-scan at confirmation so deleted, reparented, or newly locked objects are skipped.
          current = Scanner.scan_model(@model)
          wanted = pending[:plan][:entities]
          records = current.select { |r| wanted.include?(r[:entity]) }
          # A shared nested entity is protected if ANY parent occurrence is locked.
          blocked = records.select { |r| r[:locked] }.map { |r| r[:entity] }
          records.reject! { |r| blocked.include?(r[:entity]) }
          result = Converter.convert(records, pending[:values], pending[:rule], @model)
          refresh
          emit('message', {text: "Đã chuyển đổi #{result[:entities].size} đối tượng.#{pending[:rule] ? ' Đã lưu quy tắc phân loại.' : ''}"})
        end
        def select_entity(index)
          check_model!
          record = @validation.fetch(index)
          raise 'Đối tượng không còn tồn tại. Hãy chạy kiểm tra lại.' unless record[:path].all?(&:valid?)
          @model.active_path = record[:path][0...-1]
          @model.selection.clear
          @model.selection.add(record[:entity])
          bounds = Geom::BoundingBox.new
          local = Geometry.definition(record[:entity]).bounds
          8.times { |i| bounds.add(local.corner(i).transform(record[:transform])) } unless local.empty?
          @model.active_view.zoom(bounds) unless bounds.empty?
        end
        def export_report(kind)
          check_model!
          raise 'Hãy đợi quét xong trước khi xuất báo cáo.' unless @mode == 'scan' && @scan_complete
          name = ReportExporter::NAMES.fetch(kind) { raise ArgumentError, 'Loại báo cáo không hợp lệ.' }
          path = ::UI.savepanel('Xuất báo cáo để mở trong Excel', '', "VGD_#{name}.csv")
          return unless path
          path += '.csv' unless File.extname(path).downcase == '.csv'
          count = ReportExporter.write(path, kind, @records, @model)
          emit('message', {text: "Đã xuất #{count} dòng. Mở bằng Excel: #{path}"})
        end
      end
    end
  end
end
