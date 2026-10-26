require 'json'
require 'time'

module VGD_DC_Exporter
  VERSION = '1.0.1'.freeze unless const_defined?(:VERSION)

  # Đọc đối tượng SketchUp thành dữ liệu JSON. Chỉ đọc: không sửa thuộc tính, không đổi mô hình.
  # Định nghĩa dùng chung chỉ xuất một lần (theo persistent_id); mỗi instance giữ tham số và vị trí riêng.
  class Walker
    DC_DICTIONARY = 'dynamic_attributes'.freeze
    VGD_DICTIONARY = 'VGD_Cabinet_Draw'.freeze
    MAX_OTHER_ENTITIES = 500 # giới hạn số mặt/cạnh có thuộc tính được liệt kê riêng, tránh file quá lớn

    attr_reader :warnings

    def initialize
      @definitions = {}
      @warnings = []
      @other_truncated = 0
    end

    def build(model, selected)
      roots = selected.map { |entity| instance_record(entity) }
      {
        'schema' => 'vgd.dc_snapshot', 'schema_version' => 2,
        'exporter_version' => VGD_DC_Exporter::VERSION,
        'exported_at' => Time.now.iso8601,
        'sketchup_version' => Sketchup.version,
        'model_title' => text(model.title),
        'units' => units(model),
        'conventions' => {
          'hierarchy' => 'roots -> definition_ref -> definitions[id].children. Shared definitions appear once in definitions.',
          'parameters' => 'dc_parameters: value = giá trị hiệu lực (instance nếu có, không thì mặc định); instance_value và definition_value giữ riêng.',
          'formulas' => 'Công thức DC lưu sẵn, không được tính lại. Thứ tự và phụ thuộc giữa các công thức xem trong dc_formulas.',
          'lengths' => 'Giá trị độ dài DC lưu theo inch nội bộ SketchUp. value_mm là giá trị đã đổi sang mm (chỉ khi đơn vị là độ dài).',
          'transforms' => 'transformation_to_parent: 16 số theo cột (SketchUp Transformation#to_a), phần tịnh tiến tính bằng inch. origin_parent_mm là mm.',
          'bounds' => 'bounds_parent_mm: hộp bao theo trục của khung cha (không xoay theo cạnh tủ).',
          'scope' => 'Thuộc tính của instance, định nghĩa và các đối tượng con (kể cả đang ẩn/khóa). Không có lưới hình học, không có ảnh.'
        },
        'summary' => {
          'selected' => roots.length, 'definitions' => @definitions.length,
          'other_entities_truncated' => @other_truncated
        },
        'roots' => roots,
        'definitions' => @definitions,
        'warnings' => @warnings.uniq
      }
    end

    private

    def text(value)
      value.to_s.encode('UTF-8', invalid: :replace, undef: :replace)
    end

    def units(model)
      options = model.options['UnitsOptions']
      %w[LengthUnit LengthPrecision AreaUnit VolumeUnit].each_with_object({}) do |key, out|
        out[key] = options[key]
      end
    rescue StandardError
      @warnings << 'Không đọc được UnitsOptions của model.'
      {}
    end

    # Giá trị thuộc tính sang JSON. Số/chuỗi giữ nguyên; kiểu lạ được ghi dạng chuỗi và báo cáo.
    def attr_value(raw)
      case raw
      when nil, true, false, Integer then raw
      when Float
        return raw if raw.finite?
        @warnings << 'Có số không hữu hạn trong thuộc tính.'
        raw.to_s
      when String then text(raw)
      when Array then raw.map { |item| attr_value(item) }
      when Hash then raw.each_with_object({}) { |(key, item), out| out[text(key)] = attr_value(item) }
      when Time then raw.iso8601
      else
        @warnings << "Kiểu #{raw.class} được ghi dạng chuỗi."
        text(raw)
      end
    end

    # Các dictionary của đối tượng (trừ dictionary DC, xử lý riêng). Khóa '*_json' được đọc thành dữ liệu.
    def dictionaries(entity)
      collection = entity.attribute_dictionaries
      return {} unless collection
      collection.each_with_object({}) do |dictionary, out|
        next if dictionary.name == DC_DICTIONARY
        out[text(dictionary.name)] = { 'values' => dictionary_values(dictionary) }
      end
    end

    def dictionary_values(dictionary)
      out = {}
      dictionary.each_pair do |raw_key, raw|
        key = text(raw_key)
        if key.end_with?('_json') && raw.is_a?(String)
          begin
            out[key.chomp('_json')] = JSON.parse(raw)
          rescue JSON::ParserError
            out[key] = text(raw)
            @warnings << "Không đọc được JSON trong thuộc tính #{key}."
          end
        else
          out[key] = attr_value(raw)
        end
      end
      out
    end

    # Thuộc tính DC của một đối tượng (dictionary 'dynamic_attributes') dưới dạng hash thường.
    def dc_values(entity)
      dictionary = entity.attribute_dictionary(DC_DICTIONARY)
      return {} unless dictionary
      out = {}
      dictionary.each_pair { |key, raw| out[text(key)] = attr_value(raw) }
      out
    end

    def id(entity)
      entity.persistent_id.to_s
    end

    def container?(entity)
      entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
    end

    def mm_point(point)
      point.to_a.map { |coordinate| coordinate.to_f * 25.4 }
    end

    def bounds_mm(box)
      return nil if box.empty?
      { 'min' => mm_point(box.min), 'max' => mm_point(box.max),
        'size_mm' => [box.width, box.height, box.depth].map { |n| n.to_f * 25.4 } }
    end

    def definition_record(definition)
      key = "definition_#{id(definition)}"
      return key if @definitions.key?(key)
      record = { 'id' => key }
      @definitions[key] = record # đăng ký trước khi đi xuống: định nghĩa lặp lại không gây vòng lặp
      record.merge!(
        'persistent_id' => id(definition), 'name' => text(definition.name),
        'description' => text(definition.description),
        'local_bounds_mm' => bounds_mm(definition.bounds),
        'dc_definition' => Params.split(dc_values(definition)),
        'attribute_dictionaries' => dictionaries(definition),
        'children' => [], 'entity_counts' => Hash.new(0), 'other_entities_with_attributes' => []
      )
      definition.entities.each do |child|
        record['entity_counts'][child.typename] += 1
        if container?(child)
          record['children'] << instance_record(child)
        else
          add_other_entity(record, child)
        end
      end
      record['entity_counts'] = record['entity_counts'].to_h
      key
    end

    def add_other_entity(record, child)
      attributes = dictionaries(child)
      return if attributes.empty?
      if record['other_entities_with_attributes'].length >= MAX_OTHER_ENTITIES
        @other_truncated += 1
        return
      end
      record['other_entities_with_attributes'] << {
        'type' => child.typename, 'persistent_id' => id(child), 'attribute_dictionaries' => attributes
      }
    end

    def instance_record(entity)
      definition = entity.definition
      transform = entity.transformation
      definition_ref = definition_record(definition)
      definition_split = @definitions[definition_ref]['dc_definition']
      instance_split = Params.split(dc_values(entity))
      parameters = Params.combine(definition_split, instance_split)
      {
        'type' => entity.typename, 'persistent_id' => id(entity),
        'instance_name' => text(entity.name), 'definition_ref' => definition_ref,
        'tag' => text(entity.layer.name), 'material_name' => material_name(entity),
        'hidden' => flag(entity, :hidden?), 'locked' => flag(entity, :locked?),
        'transformation_to_parent' => transform.to_a.map(&:to_f),
        'origin_parent_mm' => mm_point(transform.origin),
        'axis_scale' => [transform.xaxis.length, transform.yaxis.length, transform.zaxis.length].map(&:to_f),
        'mirrored' => transform.xaxis.cross(transform.yaxis).dot(transform.zaxis) < 0,
        'bounds_parent_mm' => bounds_mm(entity.bounds),
        'dc_parameters' => parameters,
        'dc_formulas' => Params.formulas(parameters),
        'dc_instance_other' => instance_split['other'],
        'attribute_dictionaries' => dictionaries(entity)
      }
    end

    def material_name(entity)
      material = entity.material
      material ? text(material.name) : nil
    end

    # Cờ ẩn/khóa: có trên SketchUp 2014 trở lên; không có thì coi là không ẩn/không khóa.
    def flag(entity, method)
      return false unless entity.respond_to?(method)
      entity.public_send(method) ? true : false
    end
  end
end
