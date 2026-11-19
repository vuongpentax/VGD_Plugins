module VGD
  module Structure
    # Loại cầu thang (thuộc tính dùng lại, theo mẫu loại dầm): bề rộng vế, cao bậc tối đa, bản bậc tối thiểu, cao lan can (mm).
    module StairTypes
      MAX_TYPES = 20
      MAX_NAME = 20
      WIDTH = (600.0..2000.0)
      RISER = (120.0..200.0)     # cao bậc tối đa: số bậc tự tính theo cao tầng, mỗi bậc không cao hơn mức này
      TREAD = (200.0..400.0)     # bản bậc tối thiểu
      RAIL = (800.0..1200.0)     # cao lan can đo từ mép bậc
      ID_PATTERN = /\Asj_[0-9a-f]{8}\z/
      DEFAULT_ID = 'sj_00000001'.freeze
      CONTROL = /[\u0000-\u001f\u007f]/

      Error = Class.new(ArgumentError)

      def self.default
        [{'id' => DEFAULT_ID, 'name' => 'Cầu thang 1000', 'width' => 1000.0, 'riser' => 175.0, 'tread' => 260.0, 'rail' => 900.0}]
      end

      def self.normalize!(list)
        raise Error, 'Danh sách loại cầu thang không hợp lệ.' unless list.is_a?(Array)
        raise Error, "Cần từ 1 đến #{MAX_TYPES} loại cầu thang." unless list.size.between?(1, MAX_TYPES)
        out = list.each_with_index.map do |type, i|
          raise Error, "Loại cầu thang thứ #{i + 1} không hợp lệ." unless type.is_a?(Hash)
          id = type['id']
          raise Error, "Loại cầu thang thứ #{i + 1}: mã không hợp lệ." unless id.is_a?(String) && id.match?(ID_PATTERN)
          name = type['name'].is_a?(String) ? type['name'].strip : ''
          raise Error, "Loại cầu thang thứ #{i + 1}: tên từ 1 đến #{MAX_NAME} ký tự, không có ký tự điều khiển." if name.empty? || name.length > MAX_NAME || name.match?(CONTROL)
          {'id' => id, 'name' => name, 'width' => number!(type['width'], name, 'bề rộng vế', WIDTH), 'riser' => number!(type['riser'], name, 'cao bậc tối đa', RISER),
           'tread' => number!(type['tread'], name, 'bản bậc tối thiểu', TREAD), 'rail' => number!(type['rail'], name, 'cao lan can', RAIL)}
        end
        names = out.map { |t| t['name'].downcase }
        dup = out.find { |t| names.count(t['name'].downcase) > 1 }
        raise Error, "Tên loại cầu thang “#{dup['name']}” bị trùng." if dup
        raise Error, 'Mã loại cầu thang bị trùng.' if out.map { |t| t['id'] }.uniq.size != out.size
        out
      end

      def self.find(list, id)
        list.find { |t| t['id'] == id }
      end

      def self.number!(value, name, label, range)
        ok = value.is_a?(Numeric) && value.to_f.finite? && range.cover?(value.to_f)
        raise Error, "Loại cầu thang “#{name}”: #{label} phải từ #{range.min.to_i} đến #{range.max.to_i} mm." unless ok
        value.to_f.round(1)
      end
    end
  end
end
