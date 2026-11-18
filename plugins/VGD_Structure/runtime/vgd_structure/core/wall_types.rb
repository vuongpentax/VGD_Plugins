module VGD
  module Structure
    # Loại tường (thuộc tính dùng lại, ví dụ T200, T100): tên và các LỚP cấu tạo (như Compound Structure của Revit): mỗi lớp có chức năng, bề dày (mm),
    # tên vật liệu và màu. Bề dày tường `t` là TỔNG bề dày các lớp (luôn tính lại, không tin giá trị gửi lên khi có `layers`). Lớp đầu nằm ở phía -Y
    # (tường X) hoặc -X (tường Y) của khung định nghĩa; tường xiên thì xoay theo. Dữ liệu cũ chưa có `layers` được coi là MỘT lớp kết cấu.
    module WallTypes
      MAX_TYPES = 50
      MAX_NAME = 20
      THICKNESS = (50.0..1000.0)
      ID_PATTERN = /\Awt_[0-9a-f]{8}\z/
      DEFAULT_ID = 'wt_00000001'.freeze
      CONTROL = /[\u0000-\u001f\u007f]/
      MAX_LAYERS = 5
      LAYER_T = (1.0..1000.0)
      MAX_MATERIAL = 24
      COLOR = /\A#[0-9a-f]{6}\z/
      # Chức năng của lớp (nhãn hiển thị) và màu mặc định khi lớp chưa chọn màu.
      FUNCTIONS = {'structure' => 'Kết cấu', 'substrate' => 'Lớp nền', 'insulation' => 'Cách nhiệt', 'finish' => 'Hoàn thiện'}.freeze
      DEFAULT_COLORS = {'structure' => '#b8b0a2', 'substrate' => '#d6cfc0', 'insulation' => '#e6d96b', 'finish' => '#f1eee6'}.freeze

      Error = Class.new(ArgumentError)

      def self.default
        [{'id' => DEFAULT_ID, 'name' => 'T200', 't' => 200.0, 'layers' => [{'fn' => 'structure', 't' => 200.0, 'material' => ''}]}]
      end

      def self.normalize!(list)
        raise Error, 'Danh sách loại tường không hợp lệ.' unless list.is_a?(Array)
        raise Error, "Cần từ 1 đến #{MAX_TYPES} loại tường." unless list.size.between?(1, MAX_TYPES)
        out = list.each_with_index.map do |type, i|
          raise Error, "Loại tường thứ #{i + 1} không hợp lệ." unless type.is_a?(Hash)
          id = type['id']
          raise Error, "Loại tường thứ #{i + 1}: mã không hợp lệ." unless id.is_a?(String) && id.match?(ID_PATTERN)
          name = type['name'].is_a?(String) ? type['name'].strip : ''
          raise Error, "Loại tường thứ #{i + 1}: tên từ 1 đến #{MAX_NAME} ký tự, không có ký tự điều khiển." if name.empty? || name.length > MAX_NAME || name.match?(CONTROL)
          layers = layers!(type, name)
          t = layers.sum { |l| l['t'] }.round(1)
          raise Error, "Loại tường “#{name}”: tổng bề dày phải từ #{THICKNESS.min.to_i} đến #{THICKNESS.max.to_i} mm." unless THICKNESS.cover?(t)
          {'id' => id, 'name' => name, 't' => t, 'layers' => layers}
        end
        names = out.map { |t| t['name'].downcase }
        dup = out.find { |t| names.count(t['name'].downcase) > 1 }
        raise Error, "Tên loại tường “#{dup['name']}” bị trùng." if dup
        raise Error, 'Mã loại tường bị trùng.' if out.map { |t| t['id'] }.uniq.size != out.size
        out
      end

      # Các lớp của loại: chưa có `layers` (dữ liệu cũ) thì một lớp kết cấu dày `t`.
      def self.layers!(type, name)
        raw = type['layers']
        if raw.nil?
          t = type['t']
          raise Error, "Loại tường “#{name}”: bề dày phải từ #{THICKNESS.min.to_i} đến #{THICKNESS.max.to_i} mm." unless t.is_a?(Numeric) && t.to_f.finite? && THICKNESS.cover?(t.to_f)
          return [{'fn' => 'structure', 't' => t.to_f.round(1), 'material' => ''}]
        end
        raise Error, "Loại tường “#{name}”: cần từ 1 đến #{MAX_LAYERS} lớp." unless raw.is_a?(Array) && raw.size.between?(1, MAX_LAYERS)
        layers = raw.each_with_index.map do |l, i|
          at = "Loại tường “#{name}”, lớp #{i + 1}"
          raise Error, "#{at}: dữ liệu không hợp lệ." unless l.is_a?(Hash)
          raise Error, "#{at}: chức năng không hợp lệ." unless FUNCTIONS.key?(l['fn'])
          t = l['t']
          raise Error, "#{at}: bề dày phải từ #{LAYER_T.min.to_i} đến #{LAYER_T.max.to_i} mm." unless t.is_a?(Numeric) && t.to_f.finite? && LAYER_T.cover?(t.to_f)
          material = l['material'].nil? ? '' : l['material']
          raise Error, "#{at}: tên vật liệu tối đa #{MAX_MATERIAL} ký tự, không có ký tự điều khiển." unless material.is_a?(String) && material.strip.length <= MAX_MATERIAL && !material.match?(CONTROL)
          layer = {'fn' => l['fn'], 't' => t.to_f.round(1), 'material' => material.strip}
          if l['color']
            raise Error, "#{at}: màu phải có dạng #rrggbb." unless l['color'].is_a?(String) && l['color'].downcase.match?(COLOR)
            layer['color'] = l['color'].downcase
          end
          layer
        end
        raise Error, "Loại tường “#{name}”: cần ít nhất một lớp kết cấu." unless layers.any? { |l| l['fn'] == 'structure' }
        layers
      end

      # Lớp để lập kế hoạch dựng: nil nếu tường đặc đơn giản (một lớp kết cấu không vật liệu, không màu: dựng như tường đặc, vân tay không đổi).
      def self.layers_for(type)
        layers = type && type['layers']
        return nil if layers.nil? || (layers.size == 1 && layers[0]['material'].to_s.empty? && layers[0]['color'].nil? && layers[0]['fn'] == 'structure')
        layers.map { |l| {fn: l['fn'], t: l['t'], material: l['material'].to_s, color: l['color'] || DEFAULT_COLORS[l['fn']]} }
      end

      def self.find(types, id)
        types.find { |t| t['id'] == id }
      end
    end
  end
end
