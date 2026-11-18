module VGD
  module Structure
    # Loại cột (thuộc tính dùng lại, ví dụ C30x30): tên, rộng theo X, sâu theo Y (mm). Bản đầu chỉ có cột chữ nhật (chủ dự án chốt 17/11/2026).
    module ColumnTypes
      MAX_TYPES = 50
      MAX_NAME = 20
      MIN_SIZE = 100.0
      MAX_SIZE = 3000.0
      ID_PATTERN = /\Act_[0-9a-f]{8}\z/
      DEFAULT_ID = 'ct_00000001'.freeze
      CONTROL = /[\u0000-\u001f\u007f]/

      Error = Class.new(ArgumentError)

      def self.default
        [{'id' => DEFAULT_ID, 'name' => 'C30x30', 'w' => 300.0, 'd' => 300.0}]
      end

      # Kiểm tra danh sách loại cột; trả về danh sách sạch (mới). Giao diện tự sinh id dạng ct_xxxxxxxx (8 chữ số hex).
      def self.normalize!(list)
        raise Error, 'Danh sách loại cột không hợp lệ.' unless list.is_a?(Array)
        raise Error, "Cần từ 1 đến #{MAX_TYPES} loại cột." unless list.size.between?(1, MAX_TYPES)
        out = list.each_with_index.map do |type, i|
          raise Error, "Loại cột thứ #{i + 1} không hợp lệ." unless type.is_a?(Hash)
          id = type['id']
          raise Error, "Loại cột thứ #{i + 1}: mã không hợp lệ." unless id.is_a?(String) && id.match?(ID_PATTERN)
          name = type['name'].is_a?(String) ? type['name'].strip : ''
          raise Error, "Loại cột thứ #{i + 1}: tên từ 1 đến #{MAX_NAME} ký tự, không có ký tự điều khiển." if name.empty? || name.length > MAX_NAME || name.match?(CONTROL)
          {'id' => id, 'name' => name, 'w' => size!(type['w'], name, 'rộng'), 'd' => size!(type['d'], name, 'sâu')}
        end
        names = out.map { |t| t['name'].downcase }
        dup = out.find { |t| names.count(t['name'].downcase) > 1 }
        raise Error, "Tên loại cột “#{dup['name']}” bị trùng." if dup
        raise Error, 'Mã loại cột bị trùng.' if out.map { |t| t['id'] }.uniq.size != out.size
        out
      end

      def self.size!(value, name, label)
        ok = value.is_a?(Numeric) && value.to_f.finite? && value.to_f.between?(MIN_SIZE, MAX_SIZE)
        raise Error, "Loại cột “#{name}”: #{label} phải từ #{MIN_SIZE.to_i} đến #{MAX_SIZE.to_i} mm." unless ok
        value.to_f.round(1)
      end

      def self.find(types, id)
        types.find { |t| t['id'] == id }
      end
    end
  end
end
