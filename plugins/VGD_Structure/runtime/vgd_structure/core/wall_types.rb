module VGD
  module Structure
    # Loại tường (thuộc tính dùng lại, ví dụ T200, T100): tên và bề dày (mm). Bản đầu tường đặc, chưa có lớp cấu tạo và chưa khoét cửa.
    module WallTypes
      MAX_TYPES = 50
      MAX_NAME = 20
      THICKNESS = (50.0..1000.0)
      ID_PATTERN = /\Awt_[0-9a-f]{8}\z/
      DEFAULT_ID = 'wt_00000001'.freeze
      CONTROL = /[\u0000-\u001f\u007f]/

      Error = Class.new(ArgumentError)

      def self.default
        [{'id' => DEFAULT_ID, 'name' => 'T200', 't' => 200.0}]
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
          t = type['t']
          raise Error, "Loại tường “#{name}”: bề dày phải từ #{THICKNESS.min.to_i} đến #{THICKNESS.max.to_i} mm." unless t.is_a?(Numeric) && t.to_f.finite? && THICKNESS.cover?(t.to_f)
          {'id' => id, 'name' => name, 't' => t.to_f.round(1)}
        end
        names = out.map { |t| t['name'].downcase }
        dup = out.find { |t| names.count(t['name'].downcase) > 1 }
        raise Error, "Tên loại tường “#{dup['name']}” bị trùng." if dup
        raise Error, 'Mã loại tường bị trùng.' if out.map { |t| t['id'] }.uniq.size != out.size
        out
      end

      def self.find(types, id)
        types.find { |t| t['id'] == id }
      end
    end
  end
end
