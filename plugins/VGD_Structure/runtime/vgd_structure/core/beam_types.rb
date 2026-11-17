module VGD
  module Structure
    # Loại dầm (thuộc tính dùng lại, ví dụ D20x40): tên, bề rộng, chiều cao dầm (mm). Dầm treo dưới sàn: chiều cao tính từ đáy sàn xuống.
    module BeamTypes
      MAX_TYPES = 50
      MAX_NAME = 20
      WIDTH = (100.0..1500.0)
      HEIGHT = (100.0..2000.0)
      ID_PATTERN = /\Abt_[0-9a-f]{8}\z/
      DEFAULT_ID = 'bt_00000001'.freeze
      CONTROL = /[\u0000-\u001f\u007f]/

      Error = Class.new(ArgumentError)

      def self.default
        [{'id' => DEFAULT_ID, 'name' => 'D20x40', 'w' => 200.0, 'h' => 400.0}]
      end

      def self.normalize!(list)
        raise Error, 'Danh sách loại dầm không hợp lệ.' unless list.is_a?(Array)
        raise Error, "Cần từ 1 đến #{MAX_TYPES} loại dầm." unless list.size.between?(1, MAX_TYPES)
        out = list.each_with_index.map do |type, i|
          raise Error, "Loại dầm thứ #{i + 1} không hợp lệ." unless type.is_a?(Hash)
          id = type['id']
          raise Error, "Loại dầm thứ #{i + 1}: mã không hợp lệ." unless id.is_a?(String) && id.match?(ID_PATTERN)
          name = type['name'].is_a?(String) ? type['name'].strip : ''
          raise Error, "Loại dầm thứ #{i + 1}: tên từ 1 đến #{MAX_NAME} ký tự, không có ký tự điều khiển." if name.empty? || name.length > MAX_NAME || name.match?(CONTROL)
          {'id' => id, 'name' => name, 'w' => size!(type['w'], name, 'rộng', WIDTH), 'h' => size!(type['h'], name, 'cao', HEIGHT)}
        end
        names = out.map { |t| t['name'].downcase }
        dup = out.find { |t| names.count(t['name'].downcase) > 1 }
        raise Error, "Tên loại dầm “#{dup['name']}” bị trùng." if dup
        raise Error, 'Mã loại dầm bị trùng.' if out.map { |t| t['id'] }.uniq.size != out.size
        out
      end

      def self.size!(value, name, label, range)
        ok = value.is_a?(Numeric) && value.to_f.finite? && range.cover?(value.to_f)
        raise Error, "Loại dầm “#{name}”: #{label} phải từ #{range.min.to_i} đến #{range.max.to_i} mm." unless ok
        value.to_f.round(1)
      end

      def self.find(types, id)
        types.find { |t| t['id'] == id }
      end
    end
  end
end
