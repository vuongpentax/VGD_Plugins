module VGD
  module Transform
    # Xoay và scale quanh tâm chọn được, theo trục thế giới (world) hoặc trục riêng của món (local). Logic thuần.
    # Mỗi món nhận danh sách bước (steps), định dạng ở core/steps.rb. Mọi điểm và độ dài tính bằng mm; góc tính bằng độ.
    module RotateScale
      SCALE_MIN = 0.001
      SCALE_MAX = 1000.0
      ANGLE_LIMIT = 3600.0 # ±3600° là nhập nhầm
      AXIS_NAMES = %w[X Y Z].freeze

      module_function

      # degrees: [độ quanh X, Y, Z] (nil hoặc 0 thì bỏ). Áp dụng theo thứ tự X, rồi Y, rồi Z.
      # Hệ local: trục lấy theo hướng của món lúc bắt đầu (trước khi xoay).
      def rotate(items, degrees, pivot_mode, coord)
        Items.check(items)
        raise ArgumentError, "Góc vượt giới hạn ±#{ANGLE_LIMIT.to_i}°." if degrees.compact.any? { |d| d.abs > ANGLE_LIMIT }
        raise ArgumentError, 'Hãy nhập ít nhất một góc (X, Y hoặc Z).' if degrees.all?(&:nil?)
        raise NothingToDo, 'Góc bằng 0, không cần xoay.' if degrees.all? { |d| d.nil? || d.zero? }
        moves = items.map do |item|
          pivot = Items.pivot_for(items, pivot_mode, item)
          axes = Items.frame(item, coord)
          steps = (0..2).filter_map do |i|
            next if degrees[i].nil? || degrees[i].zero?
            {kind: 'rotate', pivot: pivot, axis: axes[i], degrees: degrees[i]}
          end
          {index: item[:index], steps: steps}
        end
        {moves: moves}
      end

      # Scale tương đối. specs: [X, Y, Z], mỗi ô là nil (giữ), số (hệ số) hoặc {length: mm} (kích thước đích theo trục đó).
      # Kích thước hiện tại: hệ world đo hộp bao thế giới; hệ local đo kích thước theo trục riêng của món.
      def scale(items, specs, pivot_mode, coord)
        Items.check(items)
        build_scale(items, pivot_mode, coord) do |item|
          (0..2).map { |i| factor_for(specs[i], item, i, coord) }
        end
      end

      # Scale tuyệt đối (local, như 3ds Max Absolute:Local): đặt tỉ lệ của món so với definition thành đúng số đã nhập.
      # targets: [sx, sy, sz] hoặc nil (giữ). Hệ số thực hiện = tỉ lệ đích / tỉ lệ hiện tại.
      def absolute_scale(items, targets, pivot_mode)
        Items.check(items)
        raise ArgumentError, 'Hãy nhập ít nhất một tỉ lệ (X, Y hoặc Z).' if targets.all?(&:nil?)
        build_scale(items, pivot_mode, 'local') do |item|
          (0..2).map do |i|
            next 1.0 if targets[i].nil?
            raise ArgumentError, "Không đo được tỉ lệ của #{item[:name]} theo trục #{AXIS_NAMES[i]}." unless item[:scale][i].positive?
            targets[i] / item[:scale][i]
          end
        end
      end

      def build_scale(items, pivot_mode, coord)
        moves = items.map do |item|
          factors = yield(item)
          check_factors(factors)
          step = {kind: 'scale', pivot: Items.pivot_for(items, pivot_mode, item), factors: factors, axes: Items.frame(item, coord)}
          {index: item[:index], steps: [step]}
        end
        raise NothingToDo, 'Hệ số bằng 1 ở mọi trục, không đổi kích thước.' if moves.all? { |m| m[:steps][0][:factors].all? { |f| (f - 1.0).abs < 1e-9 } }
        {moves: moves}
      end

      def factor_for(spec, item, axis, coord)
        return 1.0 if spec.nil?
        return Float(spec) unless spec.is_a?(Hash)
        current = coord == 'local' ? item[:size][axis] : item[:bounds][:max][axis] - item[:bounds][:min][axis]
        raise ArgumentError, "Không đo được kích thước của #{item[:name]} theo trục #{AXIS_NAMES[axis]}." unless current.positive?
        spec[:length] / current
      end

      def check_factors(factors)
        raise ArgumentError, 'Hệ số phải nằm trong khoảng 0,001 đến 1000.' unless factors.all? { |f| f >= SCALE_MIN && f <= SCALE_MAX }
      end
    end
  end
end
