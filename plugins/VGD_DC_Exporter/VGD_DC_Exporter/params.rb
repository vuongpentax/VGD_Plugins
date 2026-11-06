module VGD_DC_Exporter
  # Xử lý thuộc tính Dynamic Component (dictionary 'dynamic_attributes') dưới dạng dữ liệu thuần:
  # không đụng SketchUp nên kiểm thử được bằng Ruby thường.
  #
  # Quy ước DC chuẩn: tham số 'x' có giá trị ở khóa 'x' và thông tin mô tả ở các khóa '_x_formula', '_x_label',
  # '_x_units', '_x_access', '_x_formlabel', '_x_options', '_x_description' (có gạch dưới ở đầu).
  # Khóa không bắt đầu bằng '_' là giá trị tham số. Khóa '_name', '_description', '_hasbehaviors'... không gắn
  # với tham số nào thì là thông tin của đối tượng.
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
        if suffix && key.start_with?('_') && key.length > suffix.length + 1
          base = key[1...-suffix.length]
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
          'options' => options(meta['options']), 'description' => meta['description']
        }.merge(length_fields(meta['units'], given.key?('value') ? given['value'] : defined['value']))
      end
    end

    # Đổi sang mm chỉ khi đơn vị là độ dài và giá trị là số. Trường hợp khác không thêm gì.
    def length_fields(units, value)
      return {} unless value.is_a?(Numeric) && units.to_s =~ LENGTH_UNITS
      { 'value_mm' => value.to_f * 25.4 }
    end

    # Tùy chọn DC: chuỗi mã hóa kiểu '&Nhãn=giá trị&Nhãn2=giá trị2' (%uXXXX và %XX là mã ký tự) thành danh sách.
    def options(raw)
      return [] unless raw.is_a?(String) && !raw.empty?
      raw.sub(/\A&/, '').split('&').each_with_object([]) do |pair, out|
        label, value = pair.split('=', 2)
        next if label.nil? || value.nil?
        out << { 'label' => decode(label), 'value' => decode(value) }
      end
    end

    def decode(text)
      text.tr('+', ' ').gsub(/%u([0-9A-Fa-f]{4})/) { [Regexp.last_match(1).hex].pack('U') }
          .gsub(/%([0-9A-Fa-f]{2})/) { [Regexp.last_match(1).hex].pack('U') }
    end

    # Danh sách công thức (để đọc nhanh): [{ 'parameter' => tên, 'formula' => công thức }].
    def formulas(parameters)
      parameters.each_with_object([]) do |(name, item), out|
        out << { 'parameter' => name, 'formula' => item['formula'] } if item['formula']
      end
    end
  end
end
