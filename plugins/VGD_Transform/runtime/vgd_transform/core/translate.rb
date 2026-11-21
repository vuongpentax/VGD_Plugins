module VGD
  module Transform
    # Dời món tuyệt đối (tới tọa độ) và tương đối (theo độ dời). Logic thuần (không gọi SketchUp).
    # Đọc ô nhập: core/units.rb. Xoay và scale: core/rotate_scale.rb. Ghép công cụ với ô nhập: core/plan.rb. Phần gọi SketchUp: core/move.rb.
    module Translate
      TOLERANCE_MM = 0.05         # lệch dưới 0,05 mm coi là đã đúng vị trí

      module_function

      # Tuyệt đối (thế giới): điểm gốc của món đầu tiên trong lựa chọn tới đúng [X, Y, Z] mm; trục nil thì giữ nguyên.
      # Cả nhóm dời cùng độ lệch đó, nên món khác giữ nguyên khoảng cách với món đầu tiên.
      # values_mm: [x, y, z] mm hoặc nil. Trả về {moves: [{index:, steps:}]}.
      def absolute(items, values_mm)
        check_items(items)
        raise ArgumentError, 'Hãy nhập ít nhất một tọa độ (X, Y hoặc Z).' if values_mm.all?(&:nil?)
        anchor = items.first[:origin]
        delta = values_mm.each_with_index.map { |value, i| value.nil? ? 0.0 : value - anchor[i] }
        raise ArgumentError, 'Món đầu tiên đã ở vị trí đó, không cần dời.' if near_zero?(delta)
        translation(items, delta)
      end

      # Dời tương đối (thế giới): mỗi món dời cùng độ dời [dX, dY, dZ] mm; ô trống là 0.
      def offset(items, deltas_mm)
        check_items(items)
        raise ArgumentError, 'Hãy nhập ít nhất một độ dời (ΔX, ΔY hoặc ΔZ).' if deltas_mm.all?(&:nil?)
        delta = deltas_mm.map { |value| value || 0.0 }
        raise ArgumentError, 'Độ dời bằng 0, không cần dời.' if near_zero?(delta)
        translation(items, delta)
      end

      # Món nào khóa hoặc không đo được vị trí thì không biến đổi gì cả, để cả nhóm không lệch nhau.
      def check_items(items)
        raise ArgumentError, 'Chưa chọn món nào.' if items.empty?
        items.each do |item|
          raise ArgumentError, "#{item[:name]} đang khóa. Bỏ khóa hoặc bỏ chọn món đó rồi thử lại." if item[:locked]
          raise ArgumentError, "Không đo được vị trí của #{item[:name]}." if item[:origin].nil?
        end
      end

      def translation(items, delta)
        {moves: items.map { |item| {index: item[:index], steps: [{kind: 'translate', delta: delta}]} }}
      end

      def near_zero?(vector)
        vector.all? { |d| d.abs < TOLERANCE_MM }
      end
    end
  end
end
