module VGD
  module Structure
    # Loại cửa (thuộc tính dùng lại): cửa đi (door) hoặc cửa sổ (window) với rộng, cao, cao ngưỡng (mm, từ mặt sàn tới đáy lỗ). Bản đầu: lỗ mở chữ nhật,
    # khung và cánh đơn giản theo tham số (chủ dự án chốt 17/11/2026).
    module OpeningTypes
      MAX_TYPES = 50
      MAX_NAME = 20
      KINDS = %w[door window].freeze
      WIDTH = (300.0..5000.0)
      HEIGHT = (300.0..4000.0)
      SILL = (0.0..3000.0)
      ID_PATTERN = /\Aot_[0-9a-f]{8}\z/
      CONTROL = /[\u0000-\u001f\u007f]/

      Error = Class.new(ArgumentError)

      def self.default
        [{'id' => 'ot_00000001', 'name' => 'D900x2100', 'kind' => 'door', 'w' => 900.0, 'h' => 2100.0, 'sill' => 0.0},
         {'id' => 'ot_00000002', 'name' => 'W1200x1200', 'kind' => 'window', 'w' => 1200.0, 'h' => 1200.0, 'sill' => 900.0}]
      end

      def self.normalize!(list)
        raise Error, 'Danh sách loại cửa không hợp lệ.' unless list.is_a?(Array)
        raise Error, "Cần từ 1 đến #{MAX_TYPES} loại cửa." unless list.size.between?(1, MAX_TYPES)
        out = list.each_with_index.map do |type, i|
          raise Error, "Loại cửa thứ #{i + 1} không hợp lệ." unless type.is_a?(Hash)
          id = type['id']
          raise Error, "Loại cửa thứ #{i + 1}: mã không hợp lệ." unless id.is_a?(String) && id.match?(ID_PATTERN)
          name = type['name'].is_a?(String) ? type['name'].strip : ''
          raise Error, "Loại cửa thứ #{i + 1}: tên từ 1 đến #{MAX_NAME} ký tự, không có ký tự điều khiển." if name.empty? || name.length > MAX_NAME || name.match?(CONTROL)
          raise Error, "Loại cửa “#{name}”: kiểu phải là cửa đi (door) hoặc cửa sổ (window)." unless KINDS.include?(type['kind'])
          {'id' => id, 'name' => name, 'kind' => type['kind'], 'w' => size!(type['w'], name, 'rộng', WIDTH), 'h' => size!(type['h'], name, 'cao', HEIGHT), 'sill' => size!(type['sill'], name, 'cao ngưỡng', SILL)}
        end
        names = out.map { |t| t['name'].downcase }
        dup = out.find { |t| names.count(t['name'].downcase) > 1 }
        raise Error, "Tên loại cửa “#{dup['name']}” bị trùng." if dup
        raise Error, 'Mã loại cửa bị trùng.' if out.map { |t| t['id'] }.uniq.size != out.size
        out
      end

      def self.size!(value, name, label, range)
        ok = value.is_a?(Numeric) && value.to_f.finite? && range.cover?(value.to_f)
        raise Error, "Loại cửa “#{name}”: #{label} phải từ #{range.min.to_i} đến #{range.max.to_i} mm." unless ok
        value.to_f.round(1)
      end

      def self.find(types, id)
        types.find { |t| t['id'] == id }
      end
    end
  end
end
