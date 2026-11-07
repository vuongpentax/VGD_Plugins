require 'json'
require_relative 'storage'
require_relative 'images'

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
        {key: 'volume', label: 'Thể tích m³', kind: 'sum'},
        {key: 'tag', label: 'Phân loại thẻ', kind: 'text', editable: 'tag'},
        {key: 'tag_group', label: 'Nhóm hạng mục', kind: 'text'},
        {key: 'material', label: 'Vật liệu', kind: 'text', editable: 'material'},
        {key: 'status', label: 'Tình trạng', kind: 'status', editable: 'status'},
        {key: 'quantity', label: 'Số lượng', kind: 'sum'}
      ].freeze
      COLUMN_KEYS = COLUMNS.map { |column| column[:key] }.freeze

      STATUS_LABELS = {'new' => 'Mới', 'existing' => 'Hiện hữu', 'reuse' => 'Dùng lại', 'temporary' => 'Tạm thời', 'removed' => 'Loại bỏ'}.freeze

      # Preset có sẵn. Preset do người dùng lưu nằm trong custom_presets.
      BUILT_IN_PRESETS = [
        {'name' => 'Tất cả', 'group' => '', 'columns' => %w[ordinal image entity definition instance description material tag status quantity]},
        {'name' => 'Phần thô', 'group' => 'Phần thô', 'columns' => %w[ordinal entity instance lenX lenY lenZ areaFace volume tag material quantity]},
        {'name' => 'Hoàn thiện', 'group' => 'Hoàn thiện', 'columns' => %w[ordinal entity instance description lenX lenY lenZ areaXZ areaXY areaFace tag material status quantity]},
        {'name' => 'Đồ rời', 'group' => 'Đồ rời', 'columns' => %w[ordinal entity definition instance description lenX lenY lenZ tag material status quantity]}
      ].freeze

      def self.presets
        BUILT_IN_PRESETS.map { |preset| preset.merge('builtin' => true) } + custom_presets.map { |preset| preset.merge('builtin' => false) }
      end

      def self.custom_presets
        raw = Storage.read('table_presets', SECTION, PRESET_KEY)
        return [] unless raw.is_a?(Array)
        raw.map { |item| sanitize_preset(item) rescue nil }.compact
      rescue ArgumentError => error
        BIM.log("Table presets invalid: #{error.message}")
        []
      end

      def self.sanitize_preset(item)
        raise ArgumentError, 'Preset không hợp lệ.' unless item.is_a?(Hash)
        name = item['name'].to_s.strip.gsub(/\s+/, ' ')
        raise ArgumentError, 'Tên preset không được để trống.' if name.empty?
        raise ArgumentError, 'Tên preset quá dài (tối đa 40 ký tự).' if name.length > 40
        group = item['group'].to_s
        raise ArgumentError, "Nhóm hạng mục không hợp lệ: #{group}" unless group.empty? || Tags::GROUPS.include?(group)
        # Giữ đúng thứ tự cột người dùng đã sắp xếp; bỏ cột lạ và cột trùng.
        columns = Array(item['columns']).map(&:to_s).uniq.select { |key| COLUMN_KEYS.include?(key) }
        raise ArgumentError, 'Preset phải có ít nhất một cột.' if columns.empty?
        {'name' => name, 'group' => group, 'columns' => columns}
      end

      def self.save_preset(name, group, columns)
        preset = sanitize_preset('name' => name, 'group' => group, 'columns' => columns)
        raise ArgumentError, 'Tên này trùng với preset có sẵn. Hãy đặt tên khác.' if BUILT_IN_PRESETS.any? { |p| p['name'] == preset['name'] }
        list = custom_presets.reject { |p| p['name'] == preset['name'] } + [preset]
        Storage.write('table_presets', list)
        preset
      end

      def self.delete_preset(name)
        list = custom_presets.reject { |p| p['name'] == name.to_s.strip }
        Storage.write('table_presets', list)
      end

      # Trạng thái bảng (preset đang dùng, cột, thứ tự, độ rộng, ...) để mở lại vẫn giữ như lần trước.
      VIEW_KEYS = %w[preset group order visible widths density showTotals onlyTop].freeze
      def self.view_state
        raw = Storage.read('table_view')
        raw.is_a?(Hash) ? raw.select { |k, _| VIEW_KEYS.include?(k) } : {}
      end

      def self.save_view_state(state)
        raise ArgumentError, 'Trạng thái bảng không hợp lệ.' unless state.is_a?(Hash)
        clean = state.select { |k, _| VIEW_KEYS.include?(k) }
        %w[order visible].each { |k| clean[k] = Array(clean[k]).map(&:to_s).select { |key| COLUMN_KEYS.include?(key) } if clean.key?(k) }
        clean['widths'] = (clean['widths'].is_a?(Hash) ? clean['widths'] : {}).select { |k, v| COLUMN_KEYS.include?(k) && v.is_a?(Numeric) } if clean.key?('widths')
        Storage.write('table_view', clean)
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
      def self.build(model, entities, deep = false)
        records = []
        path = model.active_path || []
        transform = model.edit_transform
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
        groups = tag_groups
        index_of = {}
        records.each_with_index { |record, i| index_of[path_key(record[:path])] = i }
        image_folder = model.respond_to?(:guid) ? Images.dir(model) : nil # một lần cho cả bảng
        rows = records.each_with_index.map { |record, i| row_for(record, i, groups).merge(image_state(model, record[:entity], image_folder)) }
        # Đối tượng cha đang có trong bảng: dùng để tránh cộng trùng khi tính tổng.
        records.each_with_index do |record, i|
          rows[i][:parents] = (1...record[:path].size).map { |n| index_of[path_key(record[:path][0...n])] }.compact
          rows[i][:parent] = parent_label(record)
        end
        {rows: rows, records: records}
      end

      # Mã bền (persistent_id) và tình trạng ảnh của đối tượng. Ảnh nằm ngoài file SketchUp (xem Images).
      def self.image_state(model, entity, folder = nil)
        pid = entity.respond_to?(:persistent_id) ? entity.persistent_id : nil
        return {pid: nil, has_image: false, image_stamp: 0} unless pid.is_a?(Integer) && pid > 0 && model.respond_to?(:guid)
        info = Images.info(model, pid, folder || Images.dir(model))
        {pid: pid, has_image: info[:has], image_stamp: info[:stamp]}
      end

      # Tên của đối tượng cha trực tiếp (để nhóm theo cha); cấp gốc của model thì để trống.
      def self.parent_label(record)
        parent = record[:path][-2]
        return '' unless parent
        name = parent.name.to_s
        name.empty? ? Geometry.definition(parent).name.to_s : name
      end

      def self.row_for(record, index, groups)
        entity = record[:entity]
        transform = record[:transform]
        dims = Geometry.dimensions(entity, transform)
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
          volume: solid_volume(entity, transform),
          tag: tag,
          tag_group: groups.fetch(Tags.key(tag), UNTAGGED_GROUP),
          material: entity.material ? entity.material.display_name.to_s : '',
          status: status,
          locked: record[:locked] ? true : false,
          quantity: 1,
          parents: []
        }
      end

      # Chỉ tính cho group. Giả định Group#volume là thể tích hình học gốc, nhân thêm hệ số phóng to của vị trí.
      # Âm nghĩa là khối không kín, khi đó để trống.
      def self.solid_volume(entity, transform)
        return nil unless entity.is_a?(Sketchup::Group)
        raw = entity.volume
        return nil if raw.nil? || raw <= 0
        scale = transform.xaxis.length * transform.yaxis.length * transform.zaxis.length
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
