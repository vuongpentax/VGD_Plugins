module VGD
  module Transform
    # Xoay và scale theo trục thế giới, quanh tâm chọn được. Logic thuần (không gọi SketchUp).
    # Mỗi món nhận danh sách bước (steps), định dạng ở core/steps.rb. Mọi điểm và độ dài tính bằng mm; góc tính bằng độ.
    module RotateScale
      SCALE_MIN = 0.001
      SCALE_MAX = 1000.0
      ANGLE_LIMIT = 3600.0 # ±3600° là nhập nhầm
      AXES_INDEX = [0, 1, 2].freeze

      module_function

      # Tâm xoay / scale của một món.
      # item: điểm gốc của món; selection: tâm hộp bao các điểm gốc của cả lựa chọn; world: gốc tọa độ thế giới.
      def pivot_for(items, mode, item)
        case mode
        when 'item' then item[:origin]
        when 'selection' then selection_center(items)
        when 'world' then [0.0, 0.0, 0.0]
        else raise ArgumentError, 'Tâm xoay không hợp lệ.'
        end
      end

      def selection_center(items)
        origins = items.map { |item| item[:origin] }
        AXES_INDEX.map { |i| (origins.map { |o| o[i] }.min + origins.map { |o| o[i] }.max) / 2.0 }
      end

      # degrees: [độ quanh X, độ quanh Y, độ quanh Z] (nil hoặc 0 thì bỏ). Áp dụng theo thứ tự X, rồi Y, rồi Z.
      def rotate(items, degrees, pivot_mode)
        Translate.check_items(items)
        raise ArgumentError, 'Hãy nhập ít nhất một góc (X, Y hoặc Z).' if degrees.all? { |d| d.nil? || d.zero? }
        raise ArgumentError, "Góc vượt giới hạn ±#{ANGLE_LIMIT.to_i}°." if degrees.compact.any? { |d| d.abs > ANGLE_LIMIT }
        moves = items.map do |item|
          pivot = pivot_for(items, pivot_mode, item)
          steps = AXES_INDEX.filter_map do |i|
            next if degrees[i].nil? || degrees[i].zero?
            axis = Array.new(3, 0.0).tap { |v| v[i] = 1.0 }
            {kind: 'rotate', pivot: pivot, axis: axis, degrees: degrees[i]}
          end
          {index: item[:index], steps: steps}
        end
        {moves: moves}
      end

      # factors: [fX, fY, fZ], mỗi hệ số > 0 (1 = giữ nguyên trục đó). Scale theo trục thế giới.
      def scale(items, factors, pivot_mode)
        Translate.check_items(items)
        raise ArgumentError, 'Hệ số phải nằm trong khoảng 0,001 đến 1000.' unless factors.all? { |f| f >= SCALE_MIN && f <= SCALE_MAX }
        raise ArgumentError, 'Hệ số bằng 1 ở mọi trục, không đổi kích thước.' if factors.all? { |f| (f - 1.0).abs < 1e-9 }
        moves = items.map do |item|
          {index: item[:index], steps: [{kind: 'scale', pivot: pivot_for(items, pivot_mode, item), factors: factors}]}
        end
        {moves: moves}
      end
    end
  end
end
