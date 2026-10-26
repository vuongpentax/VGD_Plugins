module VGD_DC_Exporter
  # Xử lý thuộc tính Dynamic Component (dictionary 'dynamic_attributes') dưới dạng dữ liệu thuần:
  # không đụng SketchUp nên kiểm thử được bằng Ruby thường.
  #
  # Quy ước DC chuẩn: mỗi tham số 'x' có thể đi kèm các khóa 'x_formula', 'x_label', 'x_units',
  # 'x_access', 'x_formlabel', 'x_options', 'x_description'. Khóa không có hậu tố (và không bắt đầu bằng '_')
  # là giá trị của tham số. Khóa bắt đầu bằng '_' (ví dụ '_name', '_hasbehaviors') là thông tin của đối tượng.
  module Params
    extend self

    META_SUFFIXES = %w[_formula _label _units _access _formlabel _options _description].freeze

    # Đơn vị được coi là độ dài. DC lưu độ dài theo inch nội bộ của SketchUp; chỉ đổi sang mm khi đơn vị là độ dài.
    LENGTH_UNITS = /MILLIM|CENTIM|METER|INCH|FEET|LENGTH|\A(MM|CM|M|IN|FT)\z/i

    # Tách một dictionary DC thành tham số và thông tin khác.
    # Trả về { 'parameters' => { tên => { 'value' => ..., 'formula' => ..., ... } }, 'other' => { khóa => giá trị } }.
    def split(values)
      parameters = {}
      other = {}
      values.each do |key, value|
        suffix = META_SUFFIXES.find { |item| key.end_with?(item) }
        if suffix
          base = key[0...-suffix.length]
          (parameters[base] ||= {})[suffix[1..-1]] = value
        elsif key.start_with?('_')
          other[key] = value
        else
          (parameters[key] ||= {})['value'] = value
        end
      end
      { 'parameters' => parameters, 'other' => other }
    end

    # Ghép tham số của định nghĩa (mặc định, công thức, nhãn, đơn vị) với giá trị riêng của instance.
    # Giá trị hiệu lực = giá trị của instance nếu có, không thì giá trị mặc định của định nghĩa.
    def combine(definition_split, instance_split)
      definitions = definition_split['parameters']
      instances = instance_split['parameters']
      (definitions.keys | instances.keys).sort.each_with_object({}) do |name, out|
        defined = definitions.fetch(name, {})
        given = instances.fetch(name, {})
        meta = defined.reject { |key, _| key == 'value' }
        meta = given.reject { |key, _| key == 'value' }.merge(meta)
        out[name] = {
          'value' => given.key?('value') ? given['value'] : defined['value'],
          'instance_value' => given['value'],
          'definition_value' => defined['value'],
          'formula' => meta['formula'],
          'label' => meta['label'], 'formlabel' => meta['formlabel'],
          'units' => meta['units'], 'access' => meta['access'],
          'options' => meta['options'], 'description' => meta['description']
        }.merge(length_fields(meta['units'], given.key?('value') ? given['value'] : defined['value']))
      end
    end

    # Đổi sang mm chỉ khi đơn vị là độ dài và giá trị là số. Trường hợp khác không thêm gì.
    def length_fields(units, value)
      return {} unless value.is_a?(Numeric) && units.to_s =~ LENGTH_UNITS
      { 'value_mm' => value.to_f * 25.4 }
    end

    # Danh sách công thức (để đọc nhanh): [{ 'parameter' => tên, 'formula' => công thức }].
    def formulas(parameters)
      parameters.each_with_object([]) do |(name, item), out|
        out << { 'parameter' => name, 'formula' => item['formula'] } if item['formula']
      end
    end
  end
end
