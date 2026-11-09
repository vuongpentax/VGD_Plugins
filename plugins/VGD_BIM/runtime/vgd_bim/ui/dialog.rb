require 'json'
require_relative 'image_actions'
require_relative 'front_actions'
require_relative 'tag_auto'
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
          @dialog.add_action_callback('table_export') { |_ctx, payload| safely { table_export(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_replace') { |_ctx, payload| safely { table_replace(JSON.parse(payload)) } }
          @dialog.add_action_callback('open_url') { |_ctx, url| safely { open_url(url) } }
          @dialog.add_action_callback('table_preset') { |_ctx, payload| safely { table_preset(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_clear') { |_ctx| safely { table_clear } }
          @dialog.add_action_callback('rename_preview') { |_ctx, payload| safely { rename_preview(JSON.parse(payload)) } }
          @dialog.add_action_callback('rename_apply') { |_ctx, payload| safely { rename_apply(JSON.parse(payload)) } }
          @dialog.add_action_callback('table_view') { |_ctx, payload| safely { Table.save_view_state(JSON.parse(payload)) } }
          register_image_callbacks
          register_front_callbacks
          register_tag_auto_callbacks
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
                         table: {columns: Table::COLUMNS, presets: Table.presets, view: Table.view_state}, fields: Schema::FIELDS, categories: Schema::CATEGORIES, units: Schema::UNITS, methods: Schema::METHODS, presets: BIM.presets, locale: Locale.ui_dictionary(language), vi_en: (language == 'en' ? Locale.vi_en_names : nil), scan_options: {scope: @scan_options[:scope], faces: faces?}})
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
          @table_context = {path: (@model.active_path || []).dup, transform: @model.edit_transform}
          @table_picks = nil
          @picked_entities = []
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
          Images.ensure_model_id(@model) # mã model cố định trong file, để ảnh còn sau khi tắt mở lại (trước mọi thao tác khác)
          scope = @table_scope.select(&:valid?)
          built = Table.build(@model, scope, @table_options[:deep] ? true : false, projected: @table_options[:projected], measure: MeasureProbe.context, context: scan_context)
          @table_rows = built[:rows]
          @table_records = built[:records]
          hint = if scope.empty?
                   'Chưa chọn đối tượng nào. Chọn group hoặc component trong SketchUp, bảng sẽ tự đọc.'
                 elsif built[:hidden].to_i.positive?
                   "Đã ẩn #{built[:hidden]} đối tượng thuộc tag loại trừ."
                 end
          emit('table', {columns: Table::COLUMNS, presets: Table.presets, groups: Tags::GROUPS + [Table::UNTAGGED_GROUP],
                         statuses: Table::STATUS_LABELS, options: @table_options.merge(isolating: !@isolated.empty?),
                         rows: @table_rows, selected: selected_indexes, hint: hint, view: Table.view_state, choices: table_choices})
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
                       'owner' => 'hãng', 'url' => 'link', 'size' => 'cỡ', 'price' => 'đơn giá'}.freeze
        def table_edit(payload)
          check_model!
          field = payload.fetch('field')
          raise ArgumentError, 'Ô này không sửa được trong bảng.' unless EDIT_LABELS.key?(field)
          value = payload.fetch('value').to_s.strip
          indexes = payload.key?('indexes') ? table_indexes(payload) : table_indexes('indexes' => [payload.fetch('index')])
          records = indexes.map { |index| @table_records.fetch(index) { raise 'Bảng đã cũ. Hãy làm mới bảng.' } }
          raise 'Đối tượng không còn tồn tại. Hãy làm mới bảng.' unless records.all? { |record| record[:path].all?(&:valid?) }
          editable = records.reject { |record| record[:locked] || record[:entity].locked? }
          raise 'Đối tượng đang bị khóa nên không sửa được.' if editable.empty?
          material = field == 'material' && !value.empty? ? find_material(value) : nil
          Data.transaction(@model, 'VGD_BIM · Sửa bảng') do
            layer = field == 'tag' ? (value.empty? ? untagged_layer : Tags.layer_for(@model, value)) : nil
            editable.each { |record| apply_edit(record[:entity], field, value, material, layer) }
          end
          table_build
          show_outline
          text = "Đã sửa #{EDIT_LABELS[field]} cho #{editable.size} đối tượng."
          text += " Bỏ qua #{records.size - editable.size} đối tượng bị khóa." if records.size > editable.size
          emit('message', {text: text})
        end
        def apply_edit(entity, field, value, material, layer)
          case field
          when 'name' then entity.name = value
          when 'tag' then entity.layer = layer
          when 'material' then entity.material = material
          when 'url', 'size', 'price' then Table::Extras.write(entity, field, value) # dữ liệu riêng của bảng, không thuộc schema VGD
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
          {tags: tags.sort_by { |name| name.downcase }, materials: materials.sort_by { |name| name.downcase }, model_tags: model_tags}
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
          report = TableReport.build(payload, model_name, ->(pid) { table_image(pid) })
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
        def table_image(pid)
          return nil unless known_pid?(pid)
          file = Images.path(@model, pid)
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
        def table_settings; Preset.settings(Table.view_state['settings']); end
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
          {tags: tags, groups: Tags::GROUPS, selection: taggable_selection.size, rules: TagRules.load, catalog: TagCatalog.summary}
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
