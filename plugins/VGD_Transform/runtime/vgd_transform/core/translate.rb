module VGD
  module Transform
    # Dời món tuyệt đối (tới tọa độ, theo hệ thế giới) và tương đối (theo độ dời, hệ World hoặc Local). Logic thuần.
    module Translate
      TOLERANCE_MM = 0.05 # lệch dưới 0,05 mm coi là đã đúng vị trí

      module_function

      # Tuyệt đối (thế giới), theo tâm biến đổi như 3ds Max:
      #   item: điểm gốc của từng món tới đúng tọa độ (nhiều món thì thẳng hàng trên trục đã nhập);
      #   selection / world: tâm hộp bao của cả lựa chọn tới đúng tọa độ, cả nhóm dời cùng độ lệch.
      # values_mm: [x, y, z] mm hoặc nil (giữ nguyên trục đó). Trả về {moves: [{index:, steps:}]}.
      def absolute(items, values_mm, pivot_mode)
        Items.check(items)
        raise ArgumentError, 'Hãy nhập ít nhất một tọa độ (X, Y hoặc Z).' if values_mm.all?(&:nil?)
        anchor = pivot_mode == 'item' ? nil : Items.selection_center(items)
        moves = items.map do |item|
          from = anchor || item[:origin]
          delta = values_mm.each_with_index.map { |value, i| value.nil? ? 0.0 : value - from[i] }
          {index: item[:index], steps: [{kind: 'translate', delta: delta}]}
        end
        raise NothingToDo, 'Đã ở đúng tọa độ đó, không cần dời.' if moves.all? { |m| near_zero?(m[:steps][0][:delta]) }
        {moves: moves}
      end

      # Dời tương đối: [dX, dY, dZ] mm (ô trống là 0) theo trục thế giới (world) hoặc trục riêng của từng món (local).
      def offset(items, deltas_mm, coord)
        Items.check(items)
        raise ArgumentError, 'Hãy nhập ít nhất một độ dời (ΔX, ΔY hoặc ΔZ).' if deltas_mm.all?(&:nil?)
        local = deltas_mm.map { |value| value || 0.0 }
        raise NothingToDo, 'Độ dời bằng 0, không cần dời.' if near_zero?(local)
        moves = items.map do |item|
          axes = Items.frame(item, coord)
          delta = (0..2).map { |k| (0..2).sum { |i| axes[i][k] * local[i] } }
          {index: item[:index], steps: [{kind: 'translate', delta: delta}]}
        end
        {moves: moves}
      end

      def near_zero?(vector)
        vector.all? { |d| d.abs < TOLERANCE_MM }
      end
    end
  end
end
