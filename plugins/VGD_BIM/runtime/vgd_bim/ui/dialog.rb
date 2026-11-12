require 'json'
require_relative 'image_actions'
require_relative 'front_actions'
require_relative 'tag_auto'
require_relative 'tag_sample'
require_relative 'tag_manager'
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
        include ImageActions
        include FrontActions
        include TagAuto
        include TagManager
        # 5 tab: Bảng khối lượng · Thông tin · Quét & xuất · Phân loại (gồm Quy tắc, Kiểm tra) · Soạn tag. Ảnh nằm trong cột Ảnh của bảng.
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
          @table_picks = nil      # đối tượng bảng đã chọn và SketchUp đang chọn theo
          @picked_entities = []   # mọi đối tượng đã chọn trong bảng (có thể nhiều hơn SketchUp chọn khi khác cấp lồng)
          @table_options = {zoom: true, isolate: false, deep: false, projected: false, label: true}
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
          @dialog.add_action_callback('validation_assign_ids') { |_ctx| safely { validation_assign_ids } }
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
          @dialog.add_action_callback('table_commit_calc') { |_ctx, payload| safely { table_commit_calc(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_option') { |_ctx, payload| safely { table_option(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_export') { |_ctx, payload| safely { table_export(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_replace') { |_ctx, payload| safely { table_replace(JSON.parse(payload)) } }
          @dialog.add_action_callback('open_url') { |_ctx, url| safely { open_url(url) } }
          @dialog.add_action_callback('table_preset') { |_ctx, payload| safely { table_preset(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_clear') { |_ctx| safely { table_clear } }
          @dialog.add_action_callback('rename_preview') { |_ctx, payload| safely { rename_preview(JSON.parse(payload)) } }
          @dialog.add_action_callback('rename_apply') { |_ctx, payload| safely { rename_apply(JSON.parse(payload)) } }
          @dialog.add_action_callback('material_library_save') { |_ctx, payload| safely { material_library_save(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_room_build') { |_ctx, payload| safely { table_room_build(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_rooms') { |_ctx, payload| safely { table_rooms(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_room_from_selection') { |_ctx, payload| safely { table_room_from_selection(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_assign_rooms_auto') { |_ctx, payload| safely { table_assign_rooms_auto(JSON.parse(payload)) } }
          @dialog.add_action_callback('snapshot_list') { |_ctx| safely { snapshot_list } }
          @dialog.add_action_callback('snapshot_save') { |_ctx, payload| safely { snapshot_save(JSON.parse(payload)) } }
          @dialog.add_action_callback('snapshot_delete') { |_ctx, payload| safely { snapshot_delete(JSON.parse(payload)) } }
          @dialog.add_action_callback('snapshot_compare') { |_ctx, payload| safely { snapshot_compare(JSON.parse(payload)) } }
          @dialog.add_action_callback('check_rules_save') { |_ctx, payload| safely { check_rules_save(JSON.parse(payload)) } }
          @dialog.add_action_callback('check_rules_run') { |_ctx| safely { check_rules_run } }
          @dialog.add_action_callback('table_levels') { |_ctx, payload| safely { table_levels(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_assign_levels_auto') { |_ctx, payload| safely { table_assign_levels_auto(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_assign_codes') { |_ctx, payload| safely { table_assign_codes(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_assign_ids') { |_ctx, payload| safely { table_assign_ids(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_fix_duplicate_ids') { |_ctx| safely { table_fix_duplicate_ids } }
          @dialog.add_action_callback('table_custom_column') { |_ctx, payload| safely { table_custom_column(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_view') { |_ctx, payload| safely { Table.save_view_state(JSON.parse(payload), @model) } }
          @dialog.add_action_callback('table_order') { |_ctx, payload| safely { table_order(JSON.parse(payload)) } }
          register_image_callbacks
          register_front_callbacks
          register_tag_auto_callbacks
          register_tag_manager_callbacks
          @dialog.set_on_closed { @closed = true; @capture[:cancel] = true if @capture; @ready = false; @generation += 1; cleanup_table_view; detach; ::UI.stop_timer(@selection_timer) if @selection_timer }
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
          return if @capture # đang chụp ảnh: chọn / bỏ chọn tạm thời là của việc chụp, không phải của người dùng
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
          language = Settings.read['language']
          emit('config', {mode: @mode, version: BIM::VERSION, language: language, app: settings_payload, preset_info: {defaults: Preset::DEFAULT_SETTINGS, choices: Preset.choices},
                         table: {columns: Table.columns, presets: Table.presets, view: Table.view_state(@model)}, fields: Schema::FIELDS, categories: Schema::CATEGORIES, units: Schema::UNITS, methods: Schema::METHODS, presets: BIM.presets, locale: Locale.ui_dictionary(language), vi_en: (language == 'en' ? Locale.vi_en_names : nil), scan_options: {scope: @scan_options[:scope], faces: faces?}})
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
        def emit_validation
          @validation = Validator.validate(@records)
          rows = @validation.each_with_index.map do |r, index|
            RawScanner.identity(r[:entity]).merge(index: index, status: r[:status], issues: r[:issues], path: r[:path].select { |e| Data.supported?(e) }.map { |e| e.name.to_s.empty? ? Geometry.definition(e).name : e.name }.join(' / '))
          end
          emit('validation', rows)
        end
        # Tab Kiểm tra: gán VGD ID cho mọi món đang liệt kê mà chưa có ID (bỏ qua món khóa), một bước hoàn tác, rồi hiện lại kết quả.
        def validation_assign_ids
          check_model!
          raise 'Hãy chạy kiểm tra trước.' if @validation.nil? || @validation.empty?
          raise 'Đối tượng không còn tồn tại. Hãy chạy kiểm tra lại.' unless @validation.all? { |record| record[:path].all?(&:valid?) }
          items = @validation.each_with_index.map { |record, index| {index: index, guid: VgdId.read(record[:entity]), locked: record[:locked] || record[:entity].locked? ? true : false} }
          plan = VgdId.assign_plan(items)
          note = plan[:locked].empty? ? '' : " Bỏ qua #{plan[:locked].size} món bị khóa."
          return emit('message', {text: "Mọi món đều đã có VGD ID.#{note}"}) if plan[:assign].empty?
          Data.transaction(@model, 'VGD_BIM · Gán VGD ID') { plan[:assign].each { |index| VgdId.assign(@validation.fetch(index)[:entity]) } }
          emit_validation
          emit('message', {text: "Đã gán VGD ID cho #{plan[:assign].size} món.#{note}"})
        end
        def finish_scan
          @scan_complete = true
          if @mode.start_with?('validate')
            emit_validation
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
          @table_context = {path: (@model.active_path || []).dup, transform: context_transform}
          @table_picks = nil
          @picked_entities = []
        end
        # Biến đổi (cục bộ -> thế giới) của ngữ cảnh đang mở, tính bằng cách nhân biến đổi của các group / component trong active_path,
        # không tin riêng Model#edit_transform: chọn món con bằng tay trong group vừa nhấp đúp mở thì khung từng lệch xa món, giống như
        # thiếu biến đổi của group cha. Hai cách trùng nhau thì không đổi gì; khác nhau thì dùng tích của path và báo một lần để biết.
        def context_transform
          path = @model.active_path || []
          reported = @model.edit_transform
          return reported if path.empty?
          composed = path.inject(Geom::Transformation.new) { |total, entity| total * entity.transformation }
          unless same_transform?(composed, reported)
            key = [path.map(&:object_id), composed.to_a, reported.to_a]
            unless @context_mismatch == key
              @context_mismatch = key
              BIM.log("edit_transform khác tích biến đổi của group đang mở: edit_transform dịch #{translation_text(reported)}, tích dịch #{translation_text(composed)} (đang dùng tích)")
              emit('message', {text: 'Lưu ý: SketchUp báo vị trí group đang mở khác với vị trí tính từ các group cha. VGD_BIM dùng vị trí tính từ các group cha.'})
            end
          end
          composed
        end
        def same_transform?(first, second)
          a = first.to_a
          b = second.to_a
          a.size == b.size && a.zip(b).all? { |x, y| (x - y).abs < 1e-6 }
        end
        # Ghi một dòng chẩn đoán (cửa sổ Ruby Console) về khung vừa vẽ; không bao giờ làm hỏng việc vẽ.
        def log_outline(targets)
          BIM.log("Khung đánh dấu: #{targets.size} đối tượng, nằm sâu #{targets.first[:path].size} cấp, hộp thế giới của đối tượng đầu #{box_text(Table.bounding_box(targets.first))}")
        rescue StandardError
          nil
        end
        def box_text(box)
          box.empty? ? 'rỗng' : "#{box.min.to_a.map { |value| value.round(1) }}..#{box.max.to_a.map { |value| value.round(1) }}"
        end
        def translation_text(transform)
          transform.to_a[12, 3].map { |value| value.round(2) }.inspect
        end
        def table_selection_changed
          @model = Sketchup.active_model
          current = @model.selection.to_a.select { |e| Data.supported?(e) && e.valid? }
          if current.empty?
            # Bấm vùng trống trong SketchUp: giữ nguyên bảng, chỉ bỏ đánh dấu.
            # Nếu vừa xóa đối tượng thì đọc lại để bỏ các dòng đã xóa.
            @table_picks = nil
            @picked_entities = []
            @outline_field = nil
            if Array(@table_records).any? { |r| !r[:path].all?(&:valid?) }
              table_build
            else
              emit('highlight', {indexes: []})
            end
          elsif same_entities?(current, @table_picks)
            # Chọn dòng hoặc ô trong bảng (SketchUp chọn theo): bảng đã đánh dấu dòng rồi, chỉ cần vẽ lại khung.
            nil
          else
            # Chọn đối tượng mới trong SketchUp: quét lại và làm mới bảng.
            @outline_field = nil
            table_scan_selection!
            table_build
          end
          show_outline
        end
        # Ngữ cảnh lúc quét (xem Table.build); không còn dùng được (group đã bị xóa) thì để Table.build dùng ngữ cảnh đang mở.
        def scan_context
          context = @table_context
          context && context[:path].all?(&:valid?) ? context : nil
        end
        def table_build
          @model = Sketchup.active_model
          ModelSettings.pin(@model, Table.view_state) # file chưa có cài đặt riêng thì ghi lại cài đặt chung đang dùng, để mở file khác không làm đổi theo
          Images.ensure_model_id(@model) # mã model cố định trong file, để ảnh còn sau khi tắt mở lại (trước mọi thao tác khác)
          scope = @table_scope.select(&:valid?)
          built = Table.build(@model, scope, @table_options[:deep] ? true : false, projected: @table_options[:projected], measure: MeasureProbe.context(ModelSettings.effective(@model)), context: scan_context)
          @table_rows = built[:rows]
          @table_records = built[:records]
          hint = if scope.empty?
                   'Chưa chọn đối tượng nào. Chọn group hoặc component trong SketchUp, bảng sẽ tự đọc.'
                 elsif built[:hidden].to_i.positive?
                   "Đã ẩn #{built[:hidden]} đối tượng thuộc tag loại trừ."
                 end
          emit('table', {check_rules: CheckRules.read(@model), material_library: MaterialLibrary.read, sketchup_materials: (@model.respond_to?(:materials) ? @model.materials.to_a.map { |m| m.display_name.to_s }.sort_by(&:downcase) : []), bridge: {room_volume: !Bridge.provider_for('room_volume').nil?}, rooms: rooms_view, levels: Levels.read(@model), columns: Table.columns, presets: Table.presets, groups: Tags::GROUPS + [Table::UNTAGGED_GROUP],
                         statuses: Table::STATUS_LABELS, options: @table_options.merge(isolating: !@isolated.empty?),
                         rows: @table_rows, selected: selected_indexes, hint: hint, view: Table.view_state(@model), choices: table_choices,
                         row_order: RowOrder.read(@model)})
        end
        # Thứ tự dòng người dùng kéo tay: chỉ ghi danh sách mã món vào model (RowOrder), không đổi gì trên đối tượng; bảng đã tự xếp lại ở giao diện.
        def table_order(payload)
          check_model!
          RowOrder.apply(@model, payload)
        end
        # payload: {'indexes' => [các dòng đã chọn trong bảng], 'field' => tên cột đã bấm (chỉ dùng khi chọn đúng một dòng)}
        # Chọn nhiều dòng kiểu Excel (Shift / Ctrl) ở giao diện; SketchUp chọn theo các đối tượng đó để các tab khác dùng luôn.
        # SketchUp chỉ chọn được các đối tượng cùng một cấp lồng; khác cấp thì chỉ chọn dòng cuối (đổi tên vẫn áp cho mọi dòng đã chọn).
        def table_select(payload)
          check_model!
          records = table_indexes(payload).map { |index| @table_records.fetch(index) { raise 'Bảng đã cũ. Hãy làm mới bảng.' } }
          raise 'Đối tượng không còn tồn tại. Hãy làm mới bảng.' unless records.all? { |record| record[:path].all?(&:valid?) }
          entities = records.map { |record| record[:entity] }
          changed = @picked_entities != entities
          @picked_entities = entities
          field = payload['field'].to_s
          @outline_field = field.empty? || records.size > 1 ? nil : field
          mirrored = same_parents?(records) ? records : [records.last]
          @table_picks = mirrored.map { |record| record[:entity] }
          parents = mirrored.first[:path][0...-1]
          @model.active_path = parents unless (@model.active_path || []) == parents
          @model.selection.clear
          @model.selection.add(*@table_picks)
          if changed
            # Chỉ cô lập / zoom khi chọn đối tượng khác, không làm lại khi bấm ô khác của cùng dòng.
            # Cô lập chỉ có khi chọn đúng một dòng.
            if records.size == 1 then apply_isolation(records.first) if @table_options[:isolate] else restore_isolation end
            zoom_to_bounds(Geometry.world_bounds(mirrored)) if @table_options[:zoom]
          end
          emit('message', {text: 'Các dòng nằm ở cấp lồng khác nhau nên SketchUp chỉ chọn dòng cuối. Đổi tên vẫn áp dụng cho mọi dòng đã chọn trong bảng.'}) if mirrored.size < records.size
          show_outline
        end
        def table_indexes(payload)
          list = payload['indexes']
          raise 'Hãy chọn ít nhất một dòng trong bảng.' unless list.is_a?(Array) && !list.empty?
          list.map { |value| Integer(value.to_s, 10) }.uniq
        rescue ArgumentError
          raise 'Chỉ số dòng không hợp lệ.'
        end
        def same_parents?(records)
          parents = records.first[:path][0...-1]
          records.all? { |record| record[:path][0...-1] == parents }
        end
        def same_entities?(current, picks)
          !picks.nil? && current.size == picks.size && (current - picks).empty?
        end
        def apply_isolation(record)
          restore_isolation
          @isolated = Table.isolate(@model, record[:path])
        end
        # Sửa ô bằng nhấp đúp. payload: {'indexes' => [các dòng], 'field' => name|description|status|tag|material, 'value' => giá trị}.
        # Áp cho mọi dòng gửi lên, bỏ qua đối tượng khóa; cả đợt là một bước hoàn tác. ('index' => một dòng vẫn được nhận.)
        EDIT_LABELS = {'name' => 'tên', 'description' => 'mô tả', 'status' => 'tình trạng', 'tag' => 'tag', 'material' => 'vật liệu',
                       'owner' => 'hãng', 'url' => 'link', 'size' => 'cỡ', 'price' => 'đơn giá', 'calc_method' => 'cách tính', 'code' => 'mã đối tượng', 'level' => 'tầng', 'room' => 'phòng'}.freeze
        def table_edit(payload)
          check_model!
          field = payload.fetch('field')
          custom = CustomColumns.find(field)
          raise ArgumentError, 'Ô này không sửa được trong bảng.' unless EDIT_LABELS.key?(field) || (custom && custom['kind'] == 'text')
          value = payload.fetch('value').to_s.strip
          raise 'Phòng này không còn trong danh sách. Hãy mở lại Quản lý phòng.' if field == 'room' && !value.empty? && Rooms.read(@model).none? { |room| room['id'] == value }
          raise 'Tầng này không còn trong danh sách. Hãy mở lại Quản lý tầng.' if field == 'level' && !value.empty? && Levels.read(@model).none? { |level| level['id'] == value }
          indexes = payload.key?('indexes') ? table_indexes(payload) : table_indexes('indexes' => [payload.fetch('index')])
          records = indexes.map { |index| @table_records.fetch(index) { raise 'Bảng đã cũ. Hãy làm mới bảng.' } }
          raise 'Đối tượng không còn tồn tại. Hãy làm mới bảng.' unless records.all? { |record| record[:path].all?(&:valid?) }
          return table_calc_method(indexes, value) if field == 'calc_method'
          editable = records.reject { |record| record[:locked] || record[:entity].locked? }
          raise 'Đối tượng đang bị khóa nên không sửa được.' if editable.empty?
          material = field == 'material' && !value.empty? ? find_material(value) : nil
          Data.transaction(@model, 'VGD_BIM · Sửa bảng') do
            layer = field == 'tag' ? (value.empty? ? untagged_layer : Tags.layer_for(@model, value)) : nil
            editable.each { |record| apply_edit(record[:entity], field, value, material, layer) }
          end
          table_build
          show_outline
          text = "Đã sửa #{custom ? custom['label'] : EDIT_LABELS[field]} cho #{editable.size} đối tượng."
          text += " Bỏ qua #{records.size - editable.size} đối tượng bị khóa." if records.size > editable.size
          emit('message', {text: text})
        end
        # Gán VGD ID (mã định danh ổn định, xem core/vgd_id.rb) cho các dòng đã chọn: chỉ món chưa có ID, bỏ qua món khóa, một bước hoàn tác.
        def table_assign_ids(payload)
          check_model!
          records = table_indexes(payload).map { |index| [index, @table_records.fetch(index) { raise 'Bảng đã cũ. Hãy làm mới bảng.' }] }
          raise 'Đối tượng không còn tồn tại. Hãy làm mới bảng.' unless records.all? { |_index, record| record[:path].all?(&:valid?) }
          items = records.map { |index, record| {index: index, guid: @table_rows.fetch(index)[:vgd_id].to_s, locked: record[:locked] || record[:entity].locked? ? true : false} }
          plan = VgdId.assign_plan(items)
          raise 'Đối tượng đang bị khóa nên không gán được VGD ID.' if plan[:assign].empty? && plan[:keep].empty?
          note = plan[:locked].empty? ? '' : " Bỏ qua #{plan[:locked].size} món bị khóa."
          if plan[:assign].empty?
            return emit('message', {text: "Các món đã chọn đều đã có VGD ID.#{note}"})
          end
          Data.transaction(@model, 'VGD_BIM · Gán VGD ID') { plan[:assign].each { |index| VgdId.assign(@table_records.fetch(index)[:entity]) } }
          table_build
          have = plan[:keep].empty? ? '' : " #{plan[:keep].size} món đã có ID từ trước."
          emit('message', {text: "Đã gán VGD ID cho #{plan[:assign].size} món.#{have}#{note}"})
        end
        # Phòng kèm số đo (diện tích, chu vi, thể tích, tường, trần) để giao diện hiện; tính lại mỗi lần dựng bảng.
        def rooms_view
          provider = Bridge.provider_for('room_volume')
          Rooms.read(@model).map { |room| room.merge('metrics' => Rooms.metrics(room), 'has_volume' => provider ? !Bridge.call('room_volume', 'find', @model, room['id']).nil? : false) }
        end
        # Lưu thư viện vật liệu (trên máy, dùng cho mọi model). payload: {'items' => [...]}. Không đụng gì trong model.
        def material_library_save(payload)
          raise ArgumentError, 'Dữ liệu vật liệu không hợp lệ.' unless payload.is_a?(Hash)
          items = MaterialLibrary.sanitize!(payload['items'])
          MaterialLibrary.write(items)
          table_build
          emit('message', {text: "Đã lưu #{items.size} vật liệu."})
        end
        # Dựng (hoặc dựng lại) khối 3D của phòng bằng plugin VGD_Room qua cầu nối. VGD_BIM không tự dựng hình. payload: {'id' => mã phòng}.
        # VGD ID của khối do BIM cấp (dựng lại thì plugin giữ ID cũ). Plugin tự mở một thao tác (một bước hoàn tác).
        def table_room_build(payload)
          check_model!
          raise ArgumentError, 'Dữ liệu phòng không hợp lệ.' unless payload.is_a?(Hash) && payload['id'].is_a?(String)
          room = Rooms.read(@model).find { |item| item['id'] == payload['id'] }
          raise 'Phòng này không còn trong danh sách. Hãy mở lại Quản lý phòng.' unless room
          raise 'Chưa cài plugin VGD Room để dựng khối phòng. Hãy cài qua VGD Center rồi khởi động lại SketchUp.' unless Bridge.provider_for('room_volume')
          existed = !Bridge.call('room_volume', 'find', @model, room['id']).nil?
          Bridge.call('room_volume', 'build', @model, room, VgdId.generate)
          table_build
          emit('message', {text: "Đã #{existed ? 'dựng lại' : 'dựng'} khối phòng #{room['name']} (thể tích #{Rooms.metrics(room)[:volume]} m³)."})
        end
        # Lưu danh sách phòng. payload: {'rooms' => [...]}. Chỉ ghi vào model (không đụng đối tượng, không dựng hình; khối phòng do VGD_Room dựng).
        def table_rooms(payload)
          check_model!
          raise ArgumentError, 'Dữ liệu phòng không hợp lệ.' unless payload.is_a?(Hash)
          list = Rooms.sanitize!(payload['rooms'])
          Rooms.write(@model, list)
          table_build
          emit('message', {text: "Đã lưu #{list.size} phòng."})
        end
        # Tạo phòng từ mặt sàn đang chọn trong SketchUp: chỉ ĐỌC viền (vòng ngoài của mặt nằm ngang), lưu dữ liệu phòng. Không dựng hình.
        # payload: {'name'?, 'number'?, 'level'? (id tầng), 'height'? (mm)}; thiếu thì tên "Phòng N", chiều cao theo tầng hoặc 3000.
        def table_room_from_selection(payload)
          check_model!
          raise ArgumentError, 'Dữ liệu phòng không hợp lệ.' unless payload.is_a?(Hash)
          face = @model.selection.to_a.find { |entity| entity.is_a?(Sketchup::Face) }
          raise 'Hãy chọn một mặt sàn (Face) trong SketchUp rồi bấm lại.' unless face
          context = context_transform
          points = face.outer_loop.vertices.map { |vertex| p = context * vertex.position; [p.x.to_f * Geometry::INCH_MM, p.y.to_f * Geometry::INCH_MM, p.z.to_f * Geometry::INCH_MM] }
          shape = Rooms.boundary_from_points(points)
          rooms = Rooms.read(@model)
          level = payload['level'].to_s
          level_data = Levels.read(@model).find { |l| l['id'] == level }
          name = payload['name'].to_s.strip
          name = "Phòng #{rooms.size + 1}" if name.empty?
          height = payload['height'].is_a?(Numeric) ? payload['height'] : (level_data ? level_data['height'] : 3000)
          created = {'name' => name, 'number' => payload['number'].to_s, 'level' => level_data ? level : '', 'height' => height, 'elevation' => shape[:elevation], 'boundary' => shape[:boundary]}
          Rooms.write(@model, rooms + [created])
          table_build
          area = Rooms.metrics(Rooms.sanitize!([created]).first)[:area]
          emit('message', {text: "Đã tạo phòng #{name} từ mặt đang chọn (diện tích #{area} m²). Hình khối phòng do plugin VGD_Room dựng."})
        end
        # Gán món vào phòng theo vị trí (tâm đáy món trong viền và trong khoảng cao của phòng). Nhãn, không dời hình. Một bước hoàn tác.
        def table_assign_rooms_auto(payload)
          check_model!
          rooms = Rooms.read(@model)
          raise 'Chưa có phòng nào. Hãy tạo phòng trong Quản lý phòng trước.' if rooms.empty?
          records = table_indexes(payload).map { |index| [index, @table_records.fetch(index) { raise 'Bảng đã cũ. Hãy làm mới bảng.' }] }
          raise 'Đối tượng không còn tồn tại. Hãy làm mới bảng.' unless records.all? { |_index, record| record[:path].all?(&:valid?) }
          items = records.map { |index, record| row = @table_rows.fetch(index); {index: index, x: row[:base_x], y: row[:base_y], z: row[:base_z], locked: record[:locked] || record[:entity].locked? ? true : false} }
          plan = Rooms.plan_auto(items, rooms)
          raise 'Không gán được phòng nào (món bị khóa hoặc nằm ngoài mọi phòng).' if plan[:assign].empty?
          Data.transaction(@model, 'VGD_BIM · Gán phòng theo vị trí') { plan[:assign].each { |index, id| Rooms.assign(@table_records.fetch(index)[:entity], id) } }
          table_build
          notes = ''
          notes += " #{plan[:none].size} món nằm ngoài mọi phòng hoặc không đo được vị trí." unless plan[:none].empty?
          notes += " Bỏ qua #{plan[:locked].size} món bị khóa." unless plan[:locked].empty?
          emit('message', {text: "Đã gán phòng cho #{plan[:assign].size} món theo vị trí.#{notes}"})
        end
        # Mốc phiên bản của bảng (core/snapshots.rb): danh sách đọc theo yêu cầu (không đọc mỗi lần dựng bảng vì có thể lớn).
        def snapshot_list
          check_model!
          emit('snapshots', Snapshots.summary(Snapshots.read(@model)))
        end
        # Chụp mốc từ các dòng hiện có của bảng. payload: {'name' => tên}. Chỉ ghi dictionary của model, không đụng đối tượng.
        def snapshot_save(payload)
          check_model!
          raise ArgumentError, 'Dữ liệu mốc không hợp lệ.' unless payload.is_a?(Hash)
          raise 'Bảng chưa có dữ liệu. Hãy làm mới bảng.' if @table_rows.nil?
          list = Snapshots.add(Snapshots.read(@model), Snapshots.capture(payload['name'], @table_rows))
          Snapshots.write(@model, list)
          emit('snapshots', Snapshots.summary(list))
          emit('message', {text: "Đã chụp mốc #{list.last['name']} (#{list.last['items'].size} món)."})
        end
        def snapshot_delete(payload)
          check_model!
          raise ArgumentError, 'Dữ liệu mốc không hợp lệ.' unless payload.is_a?(Hash)
          list = Snapshots.read(@model)
          kept = list.reject { |snap| snap['id'] == payload['id'] }
          raise 'Không tìm thấy mốc này.' if kept.size == list.size
          Snapshots.write(@model, kept)
          emit('snapshots', Snapshots.summary(kept))
          emit('message', {text: 'Đã xóa mốc.'})
        end
        # So mốc với bảng hiện tại (chỉ đọc), gửi kết quả cho giao diện. payload: {'id' => mã mốc}.
        def snapshot_compare(payload)
          check_model!
          raise ArgumentError, 'Dữ liệu mốc không hợp lệ.' unless payload.is_a?(Hash)
          raise 'Bảng chưa có dữ liệu. Hãy làm mới bảng.' if @table_rows.nil?
          snap = Snapshots.read(@model).find { |item| item['id'] == payload['id'] }
          raise 'Không tìm thấy mốc này.' unless snap
          emit('snapshot_diff', Snapshots.compare(snap, @table_rows).merge('name' => snap['name'], 'created' => snap['created']))
        end
        # Lưu luật kiểm tra tự đặt (lưu trong model, chỉ ghi dictionary của model, không đụng đối tượng). payload: {'rules' => [...]}.
        def check_rules_save(payload)
          check_model!
          raise ArgumentError, 'Dữ liệu luật không hợp lệ.' unless payload.is_a?(Hash)
          list = CheckRules.sanitize!(payload['rules'], Table.column_keys)
          CheckRules.write(@model, list)
          table_build
          emit('message', {text: "Đã lưu #{list.size} luật kiểm tra."})
        end
        # Chạy các luật đã lưu trên các dòng đang có của bảng (chỉ đọc), gửi kết quả cho giao diện.
        def check_rules_run
          check_model!
          rules = CheckRules.read(@model)
          raise 'Chưa có luật nào. Hãy thêm luật kiểm tra trước.' if rules.empty?
          raise 'Bảng chưa có dữ liệu. Hãy làm mới bảng.' if @table_rows.nil?
          outcome = CheckRules.evaluate(rules, @table_rows)
          emit('check_results', outcome.merge(rows: @table_rows.size, rules: rules.size))
        end
        # Lưu danh sách tầng của công trình (Quản lý tầng). payload: {'levels' => [{id?, name, elevation, height}]}. Chỉ ghi vào model (không đụng đối tượng).
        def table_levels(payload)
          check_model!
          raise ArgumentError, 'Dữ liệu tầng không hợp lệ.' unless payload.is_a?(Hash)
          list = Levels.sanitize!(payload['levels'])
          Levels.write(@model, list)
          table_build
          emit('message', {text: "Đã lưu #{list.size} tầng."})
        end
        # Gán tầng cho các dòng đã chọn theo cao độ đáy món (gợi ý, nhãn): món khóa bỏ qua, món thấp hơn mọi tầng không gán. Một bước hoàn tác.
        def table_assign_levels_auto(payload)
          check_model!
          levels = Levels.read(@model)
          raise 'Chưa có tầng nào. Hãy thêm tầng trong Quản lý tầng trước.' if levels.empty?
          records = table_indexes(payload).map { |index| [index, @table_records.fetch(index) { raise 'Bảng đã cũ. Hãy làm mới bảng.' }] }
          raise 'Đối tượng không còn tồn tại. Hãy làm mới bảng.' unless records.all? { |_index, record| record[:path].all?(&:valid?) }
          items = records.map { |index, record| {index: index, z: @table_rows.fetch(index)[:base_z], locked: record[:locked] || record[:entity].locked? ? true : false} }
          plan = Levels.plan_auto(items, levels)
          raise 'Không gán được tầng nào (món bị khóa hoặc thấp hơn mọi tầng).' if plan[:assign].empty?
          Data.transaction(@model, 'VGD_BIM · Gán tầng theo cao độ') { plan[:assign].each { |index, id| Levels.assign(@table_records.fetch(index)[:entity], id) } }
          table_build
          notes = ''
          notes += " #{plan[:none].size} món thấp hơn mọi tầng hoặc không đo được cao độ." unless plan[:none].empty?
          notes += " Bỏ qua #{plan[:locked].size} món bị khóa." unless plan[:locked].empty?
          emit('message', {text: "Đã gán tầng cho #{plan[:assign].size} món theo cao độ.#{notes}"})
        end
        # Đặt Mã đối tượng hàng loạt (tiền tố + số, theo thứ tự các dòng gửi lên): chỉ món chưa có mã (trừ khi ghi đè), bỏ qua món khóa, không trùng mã món khác, một bước hoàn tác.
        def table_assign_codes(payload)
          check_model!
          raise ArgumentError, 'Dữ liệu không hợp lệ.' unless payload.is_a?(Hash)
          indexes = table_indexes(payload)
          records = indexes.map { |index| [index, @table_records.fetch(index) { raise 'Bảng đã cũ. Hãy làm mới bảng.' }] }
          raise 'Đối tượng không còn tồn tại. Hãy làm mới bảng.' unless records.all? { |_index, record| record[:path].all?(&:valid?) }
          items = records.map { |index, record| {index: index, code: @table_rows.fetch(index)[:code].to_s, locked: record[:locked] || record[:entity].locked? ? true : false} }
          others = @table_rows.reject { |row| indexes.include?(row[:index]) }.map { |row| row[:code].to_s }
          plan = ObjectCode.plan(items, prefix: payload['prefix'], start: payload['start'], pad: payload['pad'], overwrite: payload['overwrite'] == true, others: others)
          note = plan[:locked].empty? ? '' : " Bỏ qua #{plan[:locked].size} món bị khóa."
          raise "Không có món nào để đặt mã (món đã có mã hoặc bị khóa).#{note}" if plan[:assign].empty?
          Data.transaction(@model, 'VGD_BIM · Đặt mã đối tượng') do
            plan[:assign].each do |index, code|
              entity = @table_records.fetch(index)[:entity]
              Data.write(entity, {code: code}, Data.source(entity) == 'RAW' ? 'MANUAL' : Data.source(entity))
            end
          end
          table_build
          kept = plan[:kept].empty? ? '' : " #{plan[:kept].size} món đã có mã giữ nguyên."
          emit('message', {text: "Đã đặt mã cho #{plan[:assign].size} món.#{kept}#{note}"})
        end
        # Sửa VGD ID trùng (do copy món): trong các món của bảng dùng chung một ID, món có mã bền nhỏ nhất giữ ID, các món khác nhận ID mới. Một bước hoàn tác.
        def table_fix_duplicate_ids
          check_model!
          items = @table_rows.map { |row| record = @table_records.fetch(row[:index]); {index: row[:index], pid: row[:pid], guid: row[:vgd_id].to_s, locked: record[:locked] || record[:entity].locked? ? true : false} }
          raise 'Có đối tượng không còn tồn tại. Hãy làm mới bảng.' unless @table_records.all? { |record| record[:path].all?(&:valid?) }
          plan = VgdId.fix_plan(items)
          note = plan[:locked].empty? ? '' : " #{plan[:locked].size} món bị khóa nên chưa đổi được."
          return emit('message', {text: "Không có VGD ID trùng trong bảng.#{note}"}) if plan[:renew].empty? && plan[:locked].empty?
          return emit('message', {text: "Không đổi được ID nào.#{note}"}) if plan[:renew].empty?
          Data.transaction(@model, 'VGD_BIM · Sửa VGD ID trùng') { plan[:renew].each { |index| VgdId.renew(@table_records.fetch(index)[:entity]) } }
          table_build
          emit('message', {text: "Đã cấp VGD ID mới cho #{plan[:renew].size} món bị trùng (món cũ nhất giữ ID).#{note}"})
        end
        # Thêm / xóa cột thêm tay (nút + ở ngăn Chọn cột). Chỉ đổi danh sách cột trên máy, không đụng gì trong model;
        # xóa cột không xóa dữ liệu đã nhập trong món. Đổi tên cột dùng tiêu đề cột của preset (nhấp đúp tiêu đề). payload: {'action' => 'add' | 'remove', ...}.
        def table_custom_column(payload)
          check_model!
          raise ArgumentError, 'Dữ liệu cột không hợp lệ.' unless payload.is_a?(Hash)
          text = case payload['action']
                 when 'add' then "Đã thêm cột #{CustomColumns.add(payload['column'])['label']}."
                 when 'remove' then (CustomColumns.remove(payload['key']); 'Đã xóa cột. Dữ liệu đã nhập trong các món vẫn còn.')
                 else raise ArgumentError, 'Dữ liệu cột không hợp lệ.'
                 end
          table_build
          emit('message', {text: text})
        end
        # Đổi cách tính theo TAG của các dòng đã chọn (lưu trên máy, mọi món cùng tag đổi theo); không ghi vào món nên cả món bị khóa cũng đổi được.
        # Giá trị rỗng: bỏ cách tính riêng của tag (về theo từ khóa / nhóm tag).
        def table_calc_method(indexes, value)
          tags = indexes.map { |index| @table_rows.fetch(index)[:tag].to_s }.reject(&:empty?).uniq
          raise 'Món chưa có tag nên không đặt cách tính theo tag được. Hãy gắn tag trước, hoặc dùng Ghi cách tính vào món.' if tags.empty?
          tags.each { |tag| Quantity.set_override(tag, value) }
          table_build
          text = value.empty? ? "Đã bỏ cách tính riêng của #{tags.size} tag, tính theo từ khóa / nhóm tag." : "Đã đặt cách tính #{Quantity::LABELS.fetch(value)} cho #{tags.size} tag: #{tags.first(3).join(', ')}#{tags.size > 3 ? '…' : ''}."
          emit('message', {text: text})
        end
        # Ghi cách tính suy ra từ tag vào chính các món (nút "Ghi cách tính vào món"): chỉ điền các mục dữ liệu chuẩn còn trống (hạng mục, cách tính, đơn vị),
        # không ghi đè gì người dùng đã nhập; bỏ qua món bị khóa; cả đợt là một bước hoàn tác. payload: {'indexes' => [các dòng]}.
        def table_commit_calc(payload)
          check_model!
          indexes = table_indexes(payload)
          records = indexes.map { |index| [index, @table_records.fetch(index) { raise 'Bảng đã cũ. Hãy làm mới bảng.' }] }
          raise 'Đối tượng không còn tồn tại. Hãy làm mới bảng.' unless records.all? { |_index, record| record[:path].all?(&:valid?) }
          editable = records.reject { |_index, record| record[:locked] || record[:entity].locked? }
          raise 'Đối tượng đang bị khóa nên không ghi được.' if editable.empty?
          written = 0
          Data.transaction(@model, 'VGD_BIM · Ghi cách tính vào món') do
            editable.each do |index, record|
              row = @table_rows.fetch(index)
              entity = record[:entity]
              has_data = Data.has_data?(entity)
              values = Quantity.commit_values(Data.read(entity), has_data, {category: row[:calc_category], method: row[:calc_method]})
              next if values.empty?
              Data.write(entity, values, has_data ? Data.source(entity) : 'MAPPED')
              written += 1
            end
          end
          table_build
          full = editable.size - written
          skipped = records.size - editable.size
          text = written.zero? ? 'Các món đã đủ dữ liệu chuẩn, không có gì để ghi.' : "Đã ghi cách tính vào #{written} món."
          text += " #{full} món đã đủ dữ liệu." if written.positive? && full.positive?
          text += " Bỏ qua #{skipped} món bị khóa." if skipped.positive?
          emit('message', {text: text})
        end
        def apply_edit(entity, field, value, material, layer)
          case field
          when 'name' then entity.name = value
          when 'tag' then entity.layer = layer
          when 'material' then entity.material = material
          when 'url', 'size', 'price' then Table::Extras.write(entity, field, value) # dữ liệu riêng của bảng, không thuộc schema VGD
          when 'room' then Rooms.assign(entity, value) # nhãn phòng, không đổi hình học
          when 'level' then Levels.assign(entity, value) # nhãn tầng, không đổi hình học
          when CustomColumns::KEY_PATTERN then CustomColumns.write(entity, field, value) # cột tự nhập do người dùng thêm
          when 'owner' then Data.write(entity, {manufacturer: value}, Data.source(entity) == 'RAW' ? 'MANUAL' : Data.source(entity))
          else Data.write(entity, {field.to_sym => value}, Data.source(entity) == 'RAW' ? 'MANUAL' : Data.source(entity))
          end
        end
        def find_material(name)
          @model.materials.to_a.find { |material| material.display_name.to_s == name } || raise('Vật liệu này không có trong model.')
        end
        def untagged_layer
          @model.layers.to_a.find { |layer| %w[Untagged Layer0].include?(layer.name.to_s) } || @model.layers[0]
        end
        # Danh sách để chọn khi nhấp đúp ô Tag / Vật liệu: tag của model và bộ tag của người dùng, vật liệu của model.
        def table_choices
          untagged = ->(name) { %w[Untagged Layer0].include?(name) }
          tags = @model.layers.to_a.map { |layer| layer.name.to_s }.reject(&untagged) | Tags.load.map { |tag| tag['name'].to_s }
          materials = @model.materials.to_a.map { |material| material.display_name.to_s }
          model_tags = @model.layers.to_a.map { |layer| layer.name.to_s }.reject(&untagged).sort_by { |name| name.downcase } # chỉ tag có trong model (bảng Loại trừ tag)
          {tags: tags.sort_by { |name| name.downcase }, materials: materials.sort_by { |name| name.downcase }, model_tags: model_tags,
           levels: Levels.read(@model).map { |level| {value: level['id'], label: level['name']} },
           rooms: Rooms.read(@model).map { |room| {value: room['id'], label: room['number'].empty? ? room['name'] : "#{room['number']} · #{room['name']}"} }}
        end
        # Cột chữ cho phép thay hàng loạt, và cách đọc giá trị hiện tại của dòng.
        REPLACE_FIELDS = {'name' => :name, 'description' => :description, 'owner' => :owner, 'size' => :size}.freeze
        MAX_FIND = 200
        # Thay chữ trong Tên / Mô tả / Hãng / Cỡ của các dòng gửi lên (không có 'indexes' thì mọi dòng trong bảng).
        # Không phân biệt hoa thường; chuỗi thay được hiểu nguyên văn. Bỏ qua đối tượng khóa. Cả đợt là một bước hoàn tác.
        def table_replace(payload)
          check_model!
          find = payload['find'].to_s
          replacement = payload['replace'].to_s
          raise 'Hãy nhập chữ cần tìm.' if find.empty?
          raise "Chữ cần tìm hoặc chữ thay thế quá dài (tối đa #{MAX_FIND} ký tự)." if find.length > MAX_FIND || replacement.length > MAX_FIND
          fields = Array(payload['fields']).map(&:to_s)
          raise 'Hãy chọn cột cần thay: chỉ có Tên, Mô tả, Xuất xứ, Quy cách.' if fields.empty? || !(fields - REPLACE_FIELDS.keys).empty?
          indexes = payload['indexes'].is_a?(Array) ? table_indexes(payload) : @table_rows.map { |row| row[:index] }
          records = indexes.map { |index| [index, @table_records.fetch(index) { raise 'Bảng đã cũ. Hãy làm mới bảng.' }] }
          raise 'Có đối tượng không còn tồn tại. Hãy làm mới bảng.' unless records.all? { |_, record| record[:path].all?(&:valid?) }
          pattern = Regexp.new(Regexp.escape(find), Regexp::IGNORECASE)
          changes = []
          locked = 0
          records.each do |index, record|
            if record[:locked] || record[:entity].locked?
              locked += 1
              next
            end
            fields.each do |field|
              old = @table_rows[index][REPLACE_FIELDS.fetch(field)].to_s
              changed = old.gsub(pattern) { replacement }
              changes << [record[:entity], field, changed] if changed != old
            end
          end
          raise 'Không có ô nào chứa chữ cần tìm.' if changes.empty?
          Data.transaction(@model, 'VGD_BIM · Thay thế') { changes.each { |entity, field, value| apply_edit(entity, field, value, nil, nil) } }
          table_build
          show_outline
          text = "Đã thay chữ trong #{changes.size} ô của #{changes.map(&:first).uniq.size} đối tượng."
          text += " Bỏ qua #{locked} đối tượng bị khóa." if locked > 0
          emit('message', {text: text})
        end
        # Mở link của cột Link bằng trình duyệt. Chỉ http / https, không mở gì khác.
        def open_url(url)
          text = url.to_s.strip
          raise 'Link không hợp lệ.' unless text.length <= Table::Extras::MAX_URL && text.match?(Table::Extras::URL_PATTERN)
          ::UI.openURL(text)
        end
        def table_option(payload)
          check_model!
          @table_options[:zoom] = payload['zoom'] ? true : false if payload.key?('zoom')
          if payload.key?('projected')
            # Diện tích chiếu tính thêm từ pháp tuyến từng mặt nên chỉ tính khi bật; đọc lại bảng để có số liệu.
            @table_options[:projected] = payload['projected'] ? true : false
            table_build
          end
          if payload.key?('deep')
            # Bật / tắt đọc sâu: đọc lại từ phạm vi đã quét, không đổi lựa chọn hiện tại.
            @table_options[:deep] = payload['deep'] ? true : false
            table_build
          end
          if payload.key?('isolate')
            if payload['isolate']
              @table_options[:isolate] = true
              chosen = selected_indexes
              apply_isolation(@table_records[chosen.first]) if chosen.size == 1
            else
              @table_options[:isolate] = false
              restore_isolation
            end
          end
          if payload.key?('label')
            # Bảng tên (khung tên) vẽ trên model khi chọn một món: bật / tắt, vẽ lại ngay.
            @table_options[:label] = payload['label'] ? true : false
            show_outline
          end
          emit('options', @table_options.merge(isolating: !@isolated.empty?))
        end
        def table_preset(payload)
          case payload['action']
          when 'save'
            Table.save_preset(payload['name'], payload['group'], payload['columns'], payload['headers'], payload['settings'])
            # Đổi cột của preset tự tạo thì cập nhật ngầm, không báo.
            emit('message', {text: "Đã lưu preset \"#{payload['name'].to_s.strip}\"."}) unless payload['silent']
          when 'delete'
            Table.delete_preset(payload['name'])
            emit('message', {text: 'Đã xóa preset.'})
          when 'import' then preset_import
          when 'export' then preset_export
          else
            raise ArgumentError, 'Thao tác preset không hợp lệ.'
          end
          emit('presets', Table.presets)
        end
        MAX_PRESET_FILE = 1024 * 1024 # file preset lớn hơn 1 MB là bất thường, không đọc
        # Nhập preset từ file JSON (định dạng riêng hoặc của plugin tham khảo). Trùng tên preset đã lưu thì ghi đè.
        def preset_import
          path = ::UI.openpanel('Nhập preset', '', 'JSON|*.json||')
          return unless path
          raise 'File preset quá lớn.' if File.size(path) > MAX_PRESET_FILE
          obj = begin
            JSON.parse(File.read(path, encoding: 'bom|utf-8'))
          rescue JSON::ParserError
            raise 'File không phải JSON hợp lệ.'
          end
          imported = Table.import_presets(obj)
          emit('presets', Table.presets)
          emit('message', {text: "Đã nhập #{imported.size} preset."})
        end
        # Xuất bảng đang hiện, đúng như trên màn hình: payload['format'] là 'xlsx' (file Excel có ảnh) hoặc 'pdf' (trang báo cáo mở bằng
        # trình duyệt để In > Lưu PDF). Cấu trúc payload xem TableReport.
        def table_export(payload)
          raise 'Dữ liệu bảng không hợp lệ.' unless payload.is_a?(Hash)
          format = payload['format']
          raise 'Định dạng xuất không hợp lệ.' unless %w[xlsx pdf].include?(format)
          report = TableReport.build(payload, model_name, ->(pid, kind = :full) { table_image(pid, kind) })
          count = report[:rows].count { |row| row[:kind] == 'row' }
          if format == 'pdf'
            ::UI.openURL(TableReport.file_url(TableReport.write_html(report)))
            return emit('message', {text: "Đã tạo trang báo cáo #{count} dòng và mở trong trình duyệt. Khi cần in, bấm nút In / Lưu PDF trên trang rồi chọn Lưu thành PDF."})
          end
          path = ::UI.savepanel('Xuất bảng khối lượng ra Excel', '', 'VGD_Bang_khoi_luong.xlsx')
          return unless path
          path += '.xlsx' unless File.extname(path).downcase == '.xlsx'
          Xlsx.write(path, report)
          emit('message', {text: "Đã xuất #{count} dòng#{report[:images].empty? ? '' : " và #{report[:images].size} ảnh"} ra Excel: #{path}"})
        end
        def model_name
          title = @model.title.to_s.strip
          title.empty? ? 'Chưa đặt tên' : title
        end
        # Ảnh đầy đủ (đúng cỡ đã chụp theo preset) của một đối tượng trong bảng; nil nếu mã không thuộc bảng hoặc chưa có ảnh.
        def table_image(pid, kind = :full)
          return nil unless known_pid?(pid)
          file = Images.path(@model, pid, kind)
          File.file?(file) ? File.binread(file) : nil
        end
        def preset_export
          data = Table.export_presets
          path = ::UI.savepanel('Xuất preset', '', 'VGD_BIM_presets.json')
          return unless path
          File.write(path, JSON.pretty_generate(data), encoding: 'UTF-8')
          emit('message', {text: "Đã xuất #{data['presets'].size} preset: #{path}"})
        end
        # Đổi tên hàng loạt cho mọi dòng đang có trong bảng (các đối tượng đã chọn). Chỉ đổi tên của đối tượng (instance),
        # không đổi tên định nghĩa dùng chung, và không sửa hình học hay dữ liệu hạng mục.
        def rename_items
          @table_rows.map do |row|
            record = @table_records.fetch(row[:index])
            box = Table.bounding_box(record)
            corner = box.empty? ? nil : box.min
            {index: row[:index], name: row[:name], definition: row[:definition], tag: row[:tag], tag_group: row[:tag_group],
             locked: record[:locked] || record[:entity].locked? ? true : false,
             position: corner ? [corner.x, corner.y, corner.z].map { |value| value.to_f * Geometry::INCH_MM } : [0.0, 0.0, 0.0]}
          end
        end
        def rename_plan(payload)
          check_model!
          options = Rename.normalize(payload)
          raise 'Bảng chưa có dòng nào. Hãy chọn group hoặc component trong SketchUp.' if @table_records.empty?
          raise 'Có đối tượng không còn tồn tại. Hãy làm mới bảng.' unless @table_records.all? { |record| record[:path].all?(&:valid?) }
          items = rename_items
          unless Array(payload['indexes']).empty?
            scope = table_indexes(payload)
            raise 'Bảng đã cũ. Hãy làm mới bảng.' unless scope.all? { |index| items.any? { |item| item[:index] == index } }
            items = items.select { |item| scope.include?(item[:index]) }
          end
          Rename.plan(items, options)
        end
        def rename_preview(payload)
          emit('rename_preview', rename_plan(payload))
        end
        def rename_apply(payload)
          plan = rename_plan(payload)
          changes = plan[:rows].select { |row| row[:status] == 'ok' }
          raise 'Không có đối tượng nào cần đổi tên.' if changes.empty?
          Data.transaction(@model, 'VGD_BIM · Đổi tên hàng loạt') do
            changes.each { |row| @table_records.fetch(row[:index])[:entity].name = row[:new] }
          end
          table_build
          show_outline
          text = "Đã đổi tên #{changes.size} đối tượng."
          text += " Bỏ qua #{plan[:counts][:locked]} đối tượng bị khóa." if plan[:counts][:locked] > 0
          text += " Có #{plan[:counts][:duplicate]} dòng trùng tên." if plan[:counts][:duplicate] > 0
          emit('message', {text: text})
        end
        def table_clear
          check_model!
          release_preview
          @model.selection.clear
          @table_picks = nil
          @picked_entities = []
          emit('highlight', {indexes: []})
        end
        # Các dòng đang được đánh dấu: dòng đã chọn trong bảng (khi SketchUp còn chọn theo), hoặc các dòng ứng với đối tượng
        # SketchUp đang chọn. Chọn hết mọi dòng từ SketchUp thì không đánh dấu dòng nào (cả bảng đều là vùng chọn).
        def selected_indexes
          return [] unless @model
          selected = @model.selection.to_a
          if same_entities?(selected, @table_picks)
            return @table_records.each_index.select { |i| @picked_entities.include?(@table_records[i][:entity]) }
          end
          indexes = selected.map { |entity| @table_records.index { |record| record[:entity] == entity } }.compact
          indexes.size == @table_records.size && indexes.size > 1 ? [] : indexes
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
          arrows = front_arrows(targets) # mũi tên chỉ mặt trước trên mặt trên của các đối tượng đã có mặt trước
          single = targets.size == 1 ? targets.first : nil
          label = single && @table_options[:label] ? outline_label(single) : nil # công tắc Bảng tên trên model
          box = single ? Table.bounding_box(single) : nil
          label_point = box && !box.empty? ? box.center : nil
          fills = targets.flat_map { |r| Table.box_triangles(r) }
          log_outline(targets)
          # Đối tượng bị xóa: khung tự tắt và bảng bỏ dòng đã xóa.
          alive = -> { targets.all? { |r| r[:path].all?(&:valid?) } }
          stale = -> { safely { table_build if @mode == 'table' && @dialog.visible? } }
          return if show_overlay(points, label, label_point, fills, alive, stale, arrows)
          @preview = UI::BoundsPreview.new(points, label: label, label_point: label_point, fills: fills, arrows: arrows, alive: alive, on_stale: stale) { @preview = nil }
          @model.tools.push_tool(@preview)
          @model.active_view.invalidate
        end
        # Mũi tên mặt trước của các đối tượng đã có mặt trước: [tam giác tô, đường viền] theo tọa độ thế giới.
        def front_arrows(records)
          shapes = records.map { |record| FrontProbe.arrow_shapes(record, Front.read(Geometry.definition(record[:entity]))[:dir]) }
          [shapes.flat_map(&:first), shapes.flat_map(&:last)]
        rescue StandardError => error
          BIM.log("Front arrow failed: #{error.message}")
          [[], []]
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
          when 'lenX', 'lenY', 'lenZ' then "#{length_num(row[key.to_sym])} #{length_unit}"
          when 'lenXZ' then "#{length_num(row[:lenX])} x #{length_num(row[:lenZ])} #{length_unit}"
          when 'lenXY' then "#{length_num(row[:lenX])} x #{length_num(row[:lenY])} #{length_unit}"
          when 'lenXYZ' then "#{length_num(row[:lenX])} x #{length_num(row[:lenY])} x #{length_num(row[:lenZ])} #{length_unit}"
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
        # Kích thước trong nhãn khung đánh dấu theo đơn vị và số lẻ của preset đang dùng, như bảng hiện (số liệu gốc luôn là mm).
        LENGTH_FACTORS = {'mm' => 1.0, 'cm' => 0.1, 'm' => 0.001, 'in' => 1 / 25.4, 'ft' => 1 / 304.8}.freeze
        def table_settings; Preset.settings(Table.view_state(@model)['settings']); end
        def length_unit; table_settings['length_unit']; end
        def length_num(mm)
          return '' if mm.nil?
          num((mm * LENGTH_FACTORS.fetch(length_unit)).round(table_settings['length_digits']))
        end
        # SketchUp 2023+: khung vẽ bằng lớp phủ (Overlay) nên công cụ Select của SketchUp giữ nguyên (Shift/Ctrl, kéo chọn,
        # nhấp đúp). SketchUp 2022 hoặc khi lớp phủ lỗi: dùng BoundsPreview (công cụ), có hạn chế ở click chuột.
        def overlay_available?
          defined?(UI::BoundsOverlay) && !@overlay_failed ? true : false
        end
        # Trả về true nếu đã hiện khung bằng lớp phủ, false nếu phải dùng công cụ.
        def show_overlay(points, label, label_point, fills, alive, stale, arrows = [[], []])
          return false unless overlay_available?
          outline_overlay.show_shapes(points, label: label, label_point: label_point, fills: fills, arrows: arrows, alive: alive, on_stale: stale)
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
          {tags: tags, groups: Tags::GROUPS, selection: taggable_selection.size, rules: TagRules.load, catalog: TagCatalog.summary, folder_rules: FolderRules.load, tree: tag_tree_state}
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
          Settings.touch_recent(name)
          emit('tag_tree', tag_tree_state)
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
        # Thu phóng tới một hộp bao theo tọa độ thế giới bằng cách đặt camera (xem ViewFit). Không dùng View#zoom: nó không nhận hộp bao
        # và với đối tượng nằm sâu trong group thì tính theo tọa độ cục bộ nên camera nhảy về gần gốc của group cha.
        def zoom_to_bounds(bounds)
          return if bounds.empty?
          view = @model.active_view
          camera = view.camera
          aspect = view.vpheight.to_f.positive? ? view.vpwidth.to_f / view.vpheight : 1.0
          fit = ViewFit.camera(bounds.min.to_a, bounds.max.to_a, direction: camera.direction.to_a, up: camera.up.to_a, perspective: camera.perspective?,
                                                                 fov: camera.fov, fov_is_height: camera.fov_is_height?, aspect: aspect)
          camera.set(Geom::Point3d.new(*fit[:eye]), Geom::Point3d.new(*fit[:target]), Geom::Vector3d.new(*fit[:up]))
          camera.height = fit[:height] if fit[:height]
          view.camera = camera
          view.invalidate
        end
        def select_entity(index)
          check_model!
          record = @validation.fetch(index)
          raise 'Đối tượng không còn tồn tại. Hãy chạy kiểm tra lại.' unless record[:path].all?(&:valid?)
          @model.active_path = record[:path][0...-1]
          @model.selection.clear
          @model.selection.add(record[:entity])
          zoom_to_bounds(Geometry.world_bounds([record]))
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
