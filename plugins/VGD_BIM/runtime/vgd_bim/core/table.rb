require 'json'
require_relative 'storage'
require_relative 'images'
require_relative 'preset'
require_relative 'front'
require_relative 'measure'

module VGD
  module BIM
    # Bảng đối tượng kiểu Auto Info: mỗi group / component là một dòng.
    # Đơn vị: chiều dài mm; diện tích m²; thể tích m³; số lượng cái.
    # Diện tích (X*Z), (X*Y) là theo khung bao quanh đối tượng (bounding box).
    module Table
      SECTION = 'VGD_BIM'.freeze
      PRESET_KEY = 'table_presets'.freeze
      UNTAGGED_GROUP = 'Chưa phân loại'.freeze
      MM3_PER_IN3 = 25.4**3

      # Thứ tự cột theo Auto Info. kind: text | number | sum | status.
      # editable: name / description / status (sửa trực tiếp trong bảng).
      COLUMNS = [
        {key: 'ordinal', label: '#', kind: 'text'},
        {key: 'image', label: 'Ảnh', kind: 'image'},
        {key: 'image_location', label: 'Ảnh vị trí', kind: 'image_location'},
        {key: 'entity', label: 'Loại', kind: 'text'},
        {key: 'definition', label: 'Họ', kind: 'text'},
        {key: 'instance', label: 'Tên', kind: 'text', editable: 'name'},
        {key: 'description', label: 'Mô tả', kind: 'text', editable: 'description'},
        {key: 'lenX', label: 'Rộng (X) mm', kind: 'number'},
        {key: 'lenY', label: 'Dài (Y) mm', kind: 'number'},
        {key: 'lenZ', label: 'Cao (Z) mm', kind: 'number'},
        {key: 'lenXZ', label: '(X) x (Z) mm', kind: 'text'},
        {key: 'lenXY', label: '(X) x (Y) mm', kind: 'text'},
        {key: 'lenXYZ', label: '(X) x (Y) x (Z) mm', kind: 'text'},
        {key: 'areaXZ', label: 'Diện tích (X*Z) m²', kind: 'sum'},
        {key: 'areaXY', label: 'Diện tích (X*Y) m²', kind: 'sum'},
        {key: 'areaFace', label: 'Diện tích mặt m²', kind: 'sum'},
        {key: 'areaProjected', label: 'Diện tích chiếu bằng m²', kind: 'sum'},
        {key: 'volume', label: 'Thể tích m³', kind: 'sum'},
        {key: 'ifc', label: 'Loại IFC', kind: 'text'},
        {key: 'tag', label: 'Phân loại thẻ', kind: 'text', editable: 'tag'},
        {key: 'tag_group', label: 'Nhóm hạng mục', kind: 'text'},
        {key: 'material', label: 'Vật liệu', kind: 'text', editable: 'material'},
        {key: 'status', label: 'Tình trạng', kind: 'status', editable: 'status'},
        {key: 'owner', label: 'Xuất xứ', kind: 'text', editable: 'owner'},
        {key: 'url', label: 'Liên kết', kind: 'text', editable: 'url'},
        {key: 'size', label: 'Quy cách', kind: 'text', editable: 'size'},
        {key: 'price', label: 'Đơn giá', kind: 'number', editable: 'price'},
        {key: 'quantity', label: 'Số lượng', kind: 'sum'},
        {key: 'total', label: 'Thành tiền', kind: 'sum'},
        {key: 'front', label: 'Mặt trước', kind: 'text'},
        {key: 'front_state', label: 'Độ tin cậy mặt trước', kind: 'text'},
        {key: 'measure_note', label: 'Ghi chú số đo', kind: 'text'}
      ].freeze
      COLUMN_KEYS = COLUMNS.map { |column| column[:key] }.freeze

      STATUS_LABELS = {'new' => 'Mới', 'existing' => 'Hiện hữu', 'reuse' => 'Dùng lại', 'temporary' => 'Tạm thời', 'removed' => 'Loại bỏ'}.freeze

      # Preset có sẵn (xem Preset::BUILT_IN). Preset do người dùng lưu nằm trong custom_presets.
      BUILT_IN_PRESETS = Preset::BUILT_IN
      BUILT_IN_NAMES = BUILT_IN_PRESETS.map { |preset| preset['name'] }.freeze

      def self.presets
        BUILT_IN_PRESETS.map { |preset| preset.merge('builtin' => true) } + custom_presets.map { |preset| preset.merge('builtin' => false) }
      end

      # Preset đã lưu. Preset cũ chỉ có cột thì được bổ sung tiêu đề rỗng và thiết lập mặc định.
      # Preset trùng tên preset có sẵn bị ẩn để không hiện hai preset cùng tên.
      def self.custom_presets
        raw = Storage.read('table_presets', SECTION, PRESET_KEY)
        return [] unless raw.is_a?(Array)
        raw.map { |item| sanitize_preset(item) rescue nil }.compact.reject { |preset| BUILT_IN_NAMES.include?(preset['name']) }
      rescue ArgumentError => error
        BIM.log("Table presets invalid: #{error.message}")
        []
      end

      # Preset đã lưu / nhập từ bản cũ có thể dùng 5 nhóm cũ: đổi sang nhóm mới tương ứng trước khi kiểm tra.
      def self.sanitize_preset(item)
        item = item.merge('group' => Tags.migrate_group(item['group'])) if item.is_a?(Hash) && item.key?('group')
        Preset.sanitize(item, COLUMN_KEYS, Tags::GROUPS)
      end

      def self.save_preset(name, group, columns, headers = nil, settings = nil)
        preset = sanitize_preset('name' => name, 'group' => group, 'columns' => columns, 'headers' => headers, 'settings' => settings || {})
        raise ArgumentError, 'Tên này trùng với preset có sẵn. Hãy đặt tên khác.' if BUILT_IN_NAMES.include?(preset['name'])
        list = custom_presets.reject { |p| p['name'] == preset['name'] } + [preset]
        raise ArgumentError, "Quá nhiều preset (tối đa #{Preset::MAX_PRESETS})." if list.size > Preset::MAX_PRESETS
        Storage.write('table_presets', list)
        preset
      end

      def self.delete_preset(name)
        list = custom_presets.reject { |p| p['name'] == name.to_s.strip }
        Storage.write('table_presets', list)
      end

      # Nhập preset từ file JSON (định dạng riêng hoặc của plugin tham khảo). Trùng tên preset đã lưu thì ghi đè.
      def self.import_presets(obj)
        obj = obj.merge('presets' => obj['presets'].map { |item| item.is_a?(Hash) && item.key?('group') ? item.merge('group' => Tags.migrate_group(item['group'])) : item }) if obj.is_a?(Hash) && obj['presets'].is_a?(Array)
        incoming = Preset.import(obj, COLUMN_KEYS, Tags::GROUPS, BUILT_IN_NAMES)
        kept = custom_presets.reject { |p| incoming.any? { |i| i['name'] == p['name'] } }
        raise ArgumentError, "Quá nhiều preset (tối đa #{Preset::MAX_PRESETS})." if kept.size + incoming.size > Preset::MAX_PRESETS
        Storage.write('table_presets', kept + incoming)
        incoming
      end

      def self.export_presets
        list = custom_presets
        raise ArgumentError, 'Chưa có preset tự tạo để xuất. Bấm + trong bảng preset để lưu một preset.' if list.empty?
        Preset.export(list)
      end

      # Trạng thái bảng (preset đang dùng, cột, thứ tự, độ rộng, ...) để mở lại vẫn giữ như lần trước.
      VIEW_KEYS = %w[preset group order visible widths density showTotals onlyTop headers settings rowHeight].freeze
      ROW_HEIGHT_MIN = 28 # độ cao hàng (điểm ảnh) khi người dùng Ctrl + lăn chuột; 0 = theo mật độ hàng
      ROW_HEIGHT_MAX = 640
      def self.view_state
        raw = Storage.read('table_view')
        return {} unless raw.is_a?(Hash)
        state = raw.select { |k, _| VIEW_KEYS.include?(k) }
        state['group'] = Tags.migrate_group(state['group']) if state['group'].is_a?(String) # trạng thái cũ dùng nhóm cũ
        state['rowHeight'] = row_height(state['rowHeight']) if state.key?('rowHeight') # file sửa tay: giá trị lạ bị bỏ
        state.delete('rowHeight') if state['rowHeight'].nil?
        state['headers'] = Preset.headers(state['headers'], COLUMN_KEYS) if state.key?('headers')
        state['settings'] = Preset.settings(state['settings']) if state.key?('settings')
        state
      end

      def self.save_view_state(state)
        raise ArgumentError, 'Trạng thái bảng không hợp lệ.' unless state.is_a?(Hash)
        clean = state.select { |k, _| VIEW_KEYS.include?(k) }
        %w[order visible].each { |k| clean[k] = Array(clean[k]).map(&:to_s).select { |key| COLUMN_KEYS.include?(key) } if clean.key?(k) }
        clean['widths'] = (clean['widths'].is_a?(Hash) ? clean['widths'] : {}).select { |k, v| COLUMN_KEYS.include?(k) && v.is_a?(Numeric) } if clean.key?('widths')
        clean['rowHeight'] = row_height(clean['rowHeight']) if clean.key?('rowHeight')
        clean.delete('rowHeight') if clean['rowHeight'].nil?
        clean['headers'] = Preset.headers(clean['headers'], COLUMN_KEYS) if clean.key?('headers')
        clean['settings'] = Preset.settings(clean['settings']) if clean.key?('settings')
        Storage.write('table_view', clean)
      end

      # 0 (theo mật độ hàng) hoặc số điểm ảnh làm tròn, kẹp trong giới hạn; không phải số thì nil (bỏ).
      def self.row_height(value)
        return nil unless value.is_a?(Numeric) && value.finite?
        return 0 if value <= 0
        value.round.clamp(ROW_HEIGHT_MIN, ROW_HEIGHT_MAX)
      end

      def self.tag_groups
        Tags.load.each_with_object({}) { |tag, map| map[Tags.key(tag['name'])] = tag['group'] }
      end

      def self.path_key(path)
        path.map(&:entityID).join('/')
      end

      # Dựng dòng của bảng cho các đối tượng đã chọn.
      # deep = false (mặc định): chỉ đọc đúng các đối tượng đang chọn.
      # deep = true: đọc thêm mọi group / component lồng bên trong.
      # Chỉ group / component, không đọc mặt riêng lẻ, không đọc cả model.
      # context: {path:, transform:} là ngữ cảnh (group đang mở) lúc quét đối tượng. Bấm một dòng con làm SketchUp mở sâu vào group cha,
      # nhưng phạm vi quét vẫn là đối tượng ở cấp lúc quét, nên dựng lại bảng phải dùng ngữ cảnh lúc quét; không truyền thì dùng ngữ cảnh đang mở.
      def self.build(model, entities, deep = false, projected: false, measure: nil, context: nil)
        records = []
        path = context ? context[:path] : (model.active_path || [])
        transform = context ? context[:transform] : model.edit_transform
        if deep
          Scanner.walk(entities, transform, path, [], nil, false, faces: false) do |record|
            records << record if Data.supported?(record[:entity]) && record[:entity].valid?
          end
        else
          context_locked = path.any? { |e| e.respond_to?(:locked?) && e.locked? }
          entities.each do |entity|
            next unless Data.supported?(entity) && entity.valid?
            records << {entity: entity, path: path + [entity], transform: transform * entity.transformation,
                        locked: context_locked || entity.locked?}
          end
        end
        records, hidden = drop_excluded_tags(records, path.size, measure ? measure.tags : [])
        groups = tag_groups
        index_of = {}
        records.each_with_index { |record, i| index_of[path_key(record[:path])] = i }
        image_folder = model.respond_to?(:guid) ? Images.dir(model) : nil # một lần cho cả bảng
        rows = records.each_with_index.map { |record, i| row_for(record, i, groups, projected: projected, measure: measure).merge(image_state(model, record[:entity], image_folder)) }
        # Đối tượng cha đang có trong bảng: dùng để tránh cộng trùng khi tính tổng.
        records.each_with_index do |record, i|
          rows[i][:parents] = (1...record[:path].size).map { |n| index_of[path_key(record[:path][0...n])] }.compact
          rows[i][:parent] = parent_label(record)
        end
        {rows: rows, records: records, hidden: hidden}
      end

      # Bỏ dòng gắn tag loại trừ (tên tag đã chuẩn hóa) và mọi món nằm trong nó. Chỉ xét các đối tượng được đọc (từ path[skip..]),
      # không xét group đang mở sửa. Trả về [các dòng còn lại, số dòng bị ẩn].
      def self.drop_excluded_tags(records, skip, tags)
        return [records, 0] if tags.empty?
        kept = records.reject do |record|
          record[:path][skip..].any? { |entity| Measure.tag_excluded?(tags, entity.layer ? entity.layer.name.to_s : '') }
        end
        [kept, records.size - kept.size]
      end

      # Mã bền (persistent_id) và tình trạng ảnh của đối tượng. Ảnh nằm ngoài file SketchUp (xem Images).
      def self.image_state(model, entity, folder = nil)
        pid = entity.respond_to?(:persistent_id) ? entity.persistent_id : nil
        none = {pid: nil, has_image: false, image_stamp: 0, image_url: nil, has_location: false, location_stamp: 0, location_url: nil}
        return none unless pid.is_a?(Integer) && pid > 0 && model.respond_to?(:guid)
        folder ||= Images.dir(model)
        info = Images.info(model, pid, folder)
        place = Images.info(model, pid, folder, :location)
        # image_url / location_url: giao diện hiện ảnh gốc trực tiếp từ file (không chuyển qua Ruby); chưa có ảnh thì nil.
        {pid: pid, has_image: info[:has], image_stamp: info[:stamp], image_url: info[:has] ? Images.file_url(model, pid, info[:stamp], folder) : nil,
         has_location: place[:has], location_stamp: place[:stamp], location_url: place[:has] ? Images.file_url(model, pid, place[:stamp], folder, :location) : nil}
      end

      # Tên của đối tượng cha trực tiếp (để nhóm theo cha); cấp gốc của model thì để trống.
      def self.parent_label(record)
        parent = record[:path][-2]
        return '' unless parent
        name = parent.name.to_s
        name.empty? ? Geometry.definition(parent).name.to_s : name
      end

      def self.row_for(record, index, groups, projected: false, measure: nil)
        entity = record[:entity]
        transform = record[:transform]
        dims = Geometry.dimensions(entity, transform, measure: measure)
        body = measure && measure.extent(Geometry.definition(entity))
        width = dims[:width].round(1)
        depth = dims[:depth].round(1)
        height = dims[:height].round(1)
        data = Data.read(entity)
        layer_name = entity.layer ? entity.layer.name.to_s : ''
        tag = %w[Untagged Layer0].include?(layer_name) ? '' : layer_name
        status = data[:status].to_s
        status = 'new' if status.empty?
        faces = Geometry.definition(entity).entities.grep(Sketchup::Face)
        {
          index: index,
          entity_type: entity.is_a?(Sketchup::Group) ? 'Nhóm' : 'Thành phần',
          definition: Geometry.definition(entity).name.to_s,
          name: entity.name.to_s,
          description: data[:description].to_s,
          lenX: width, lenY: depth, lenZ: height,
          areaXZ: (width * height / 1_000_000.0).round(3),
          areaXY: (width * depth / 1_000_000.0).round(3),
          areaFace: faces.sum { |face| Geometry.face_area(face, transform) }.round(3),
          areaProjected: projected ? projected_area(entity, faces, transform) : nil,
          volume: solid_volume(entity, transform),
          tag: tag,
          tag_group: groups.fetch(Tags.key(tag), UNTAGGED_GROUP),
          material: entity.material ? entity.material.display_name.to_s : '',
          status: status,
          locked: record[:locked] ? true : false,
          quantity: 1,
          parents: []
        }.merge(extra_columns(entity, data)).merge(measure_note: body ? body[:note].to_s : '')
      end

      # Xuất xứ (trường manufacturer của dữ liệu VGD), Liên kết / Quy cách / Đơn giá (dictionary riêng của bảng), Loại IFC, Thành tiền.
      def self.extra_columns(entity, data)
        extras = Extras.read(entity)
        {owner: data[:manufacturer].to_s, url: extras[:url], size: extras[:size], price: extras[:price],
         total: extras[:price], ifc: ifc_class(entity)}.merge(front_columns(entity))
      end

      # Mặt trước (lưu ở định nghĩa): hướng cục bộ, nhãn trạng thái, ghi chú lý do.
      def self.front_columns(entity)
        info = Front.read(Geometry.definition(entity))
        {front: Front.label(info[:dir]), front_state: Front.state_label(info), front_note: info[:note].to_s, front_conf: info[:confidence].to_s}
      end

      # Phân loại IFC có sẵn trong định nghĩa (dictionary AppliedSchemaTypes: tên bảng phân loại => lớp); lấy mục đầu tiên có giá trị.
      def self.ifc_class(entity)
        definition = Geometry.definition(entity)
        return '' unless definition.respond_to?(:attribute_dictionary)
        dictionary = definition.attribute_dictionary('AppliedSchemaTypes')
        return '' unless dictionary
        found = ''
        dictionary.each_pair { |_schema, value| found = value.to_s if found.empty? && !value.to_s.strip.empty? }
        found
      rescue StandardError
        ''
      end

      # Diện tích chiếu xuống mặt phẳng ngang (m²). Khối kín có mặt trên và mặt dưới cùng chiếu xuống nên chia đôi.
      def self.projected_area(entity, faces, transform)
        total = faces.sum { |face| Geometry.projected_area(face, transform) }
        total /= 2.0 if entity.respond_to?(:manifold?) && entity.manifold?
        total.round(3)
      end

      # Dữ liệu riêng của bảng (không thuộc schema VGD dùng chung): Link, Cỡ, Đơn giá.
      module Extras
        DICTIONARY = 'VGD_BIM_TABLE'.freeze
        FIELDS = %w[url size price].freeze
        URL_PATTERN = %r{\Ahttps?://[^\s\u0000-\u001f]+\z}i
        MAX_URL = 500
        MAX_SIZE = 100
        PRICE_PATTERN = /\A\d{1,12}(?:[.,]\d{1,4})?\z/

        def self.read(entity)
          return {url: '', size: '', price: nil} unless entity.respond_to?(:get_attribute)
          price = entity.get_attribute(DICTIONARY, 'price')
          {url: entity.get_attribute(DICTIONARY, 'url', '').to_s, size: entity.get_attribute(DICTIONARY, 'size', '').to_s,
           price: price.is_a?(Numeric) ? price.to_f : nil}
        end

        # Giá trị rỗng nghĩa là xóa. Link chỉ nhận http / https (giao diện mở link bằng trình duyệt).
        def self.write(entity, field, value)
          raise ArgumentError, 'Ô này không sửa được trong bảng.' unless FIELDS.include?(field)
          raise ArgumentError, 'Đối tượng đang bị khóa.' if entity.locked?
          clean = send("clean_#{field}", value.to_s)
          clean.nil? ? entity.delete_attribute(DICTIONARY, field) : entity.set_attribute(DICTIONARY, field, clean)
        end

        def self.clean_url(text)
          text = text.strip
          return nil if text.empty?
          raise ArgumentError, "Link phải bắt đầu bằng http:// hoặc https://, không có khoảng trắng, tối đa #{MAX_URL} ký tự." unless text.length <= MAX_URL && text.match?(URL_PATTERN)
          text
        end

        def self.clean_size(text)
          text = text.gsub(/[\u0000-\u001f\u007f]/, '').strip
          return nil if text.empty?
          raise ArgumentError, "Cỡ tối đa #{MAX_SIZE} ký tự." if text.length > MAX_SIZE
          text
        end

        def self.clean_price(text)
          text = text.strip
          return nil if text.empty?
          raise ArgumentError, 'Đơn giá phải là số không âm, ví dụ 1250000 hoặc 12,5 (không dùng dấu chấm ngăn cách hàng nghìn).' unless text.match?(PRICE_PATTERN)
          text.tr(',', '.').to_f
        end
      end

      # Chỉ tính cho group. Giả định Group#volume là thể tích hình học gốc, nhân thêm hệ số phóng to của vị trí.
      # Âm nghĩa là khối không kín, khi đó để trống.
      def self.solid_volume(entity, transform)
        return nil unless entity.is_a?(Sketchup::Group)
        raw = entity.volume
        return nil if raw.nil? || raw <= 0
        scale = Geometry.scales(transform).inject(:*)
        (raw * scale * MM3_PER_IN3 / 1.0e9).round(4)
      rescue StandardError
        nil
      end

      # 8 góc của khung bao quanh đối tượng, theo tọa độ thế giới (rỗng nếu đối tượng không có hình).
      def self.box_corners(record)
        box = Geometry.definition(record[:entity]).bounds
        return [] if box.empty?
        (0..7).map { |i| box.corner(i).transform(record[:transform]) }
      end

      # 12 cạnh của khung bao quanh đối tượng, theo tọa độ thế giới.
      def self.world_corners(record)
        corners = box_corners(record)
        points = []
        corners.each_index do |i|
          [1, 2, 4].each do |bit|
            next if i & bit != 0
            points << corners[i] << corners[i | bit]
          end
        end
        points
      end

      # 6 mặt của khung bao (mỗi mặt là 4 góc theo vòng), dùng để tô nhẹ.
      BOX_FACES = [[0, 2, 6, 4], [1, 3, 7, 5], [0, 1, 5, 4], [2, 3, 7, 6], [0, 1, 3, 2], [4, 5, 7, 6]].freeze

      # 12 tam giác tô nhẹ khung bao. Chỉ dùng 8 góc của hộp, không duyệt mặt của đối tượng nên nhẹ dù chọn rất nhiều đối tượng.
      def self.box_triangles(record)
        corners = box_corners(record)
        return [] if corners.empty?
        BOX_FACES.flat_map { |a, b, c, d| [corners[a], corners[b], corners[c], corners[a], corners[c], corners[d]] }
      end

      def self.bounding_box(record)
        bounds = Geom::BoundingBox.new
        box = Geometry.definition(record[:entity]).bounds
        return bounds if box.empty?
        (0..7).each { |i| bounds.add(box.corner(i).transform(record[:transform])) }
        bounds
      end

      # Cô lập: ẩn mọi thứ cùng cấp với đối tượng và các cấp cha. Trả về danh sách đã ẩn để khôi phục.
      # Thành phần dùng chung nhiều nơi bị từ chối, vì ẩn sẽ ảnh hưởng mọi bản sao.
      def self.isolate(model, path)
        levels = path.each_with_index.map do |node, level|
          container = level.zero? ? model.entities : Geometry.definition(path[level - 1]).entities
          [node, container]
        end
        path[0...-1].each do |parent|
          raise ArgumentError, 'Đối tượng nằm trong thành phần dùng chung nhiều nơi nên không cô lập được.' if Geometry.definition(parent).count_instances > 1
        end
        hidden = []
        levels.each do |node, container|
          container.each do |entity|
            next if entity == node || entity.hidden?
            entity.hidden = true
            hidden << entity
          end
        end
        hidden
      end

      def self.restore(entities)
        entities.each { |entity| entity.hidden = false if entity.valid? }
      end
    end
  end
end
