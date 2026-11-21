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

      # specs: [X, Y, Z]. Mỗi ô là một trong ba loại:
      #   nil: giữ nguyên (hệ số 1); số: hệ số tương đối; {length: mm}: đặt kích thước của món theo trục đó thành đúng số mm này.
      # Với {length}, hệ số của từng món = kích thước đích / kích thước hiện tại của món theo trục đó (món[:extent]).
      # Scale theo trục thế giới quanh tâm chọn được; scale theo trục giữ nguyên hộp bao, nên kích thước sau scale đúng bằng đích.
      def scale(items, specs, pivot_mode)
        Translate.check_items(items)
        moves = items.map do |item|
          factors = AXES_INDEX.map { |i| factor_for(specs[i], item, i) }
          check_factors(factors)
          {index: item[:index], steps: [{kind: 'scale', pivot: pivot_for(items, pivot_mode, item), factors: factors}]}
        end
        raise ArgumentError, 'Hệ số bằng 1 ở mọi trục, không đổi kích thước.' if moves.all? { |m| m[:steps][0][:factors].all? { |f| (f - 1.0).abs < 1e-9 } }
        {moves: moves}
      end

      def factor_for(spec, item, axis)
        return 1.0 if spec.nil?
        return Float(spec) unless spec.is_a?(Hash)
        extent = item[:extent][axis]
        raise ArgumentError, "Không đo được kích thước của #{item[:name]} theo trục #{%w[X Y Z][axis]}." unless extent.positive?
        spec[:length] / extent
      end

      def check_factors(factors)
        raise ArgumentError, 'Hệ số phải nằm trong khoảng 0,001 đến 1000.' unless factors.all? { |f| f >= SCALE_MIN && f <= SCALE_MAX }
      end
    end
  end
end
