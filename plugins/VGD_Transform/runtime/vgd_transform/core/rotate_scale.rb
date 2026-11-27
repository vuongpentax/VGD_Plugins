module VGD
  module Transform
    # Xoay và scale quanh tâm chọn được, theo trục thế giới (world) hoặc trục riêng của món (local). Logic thuần.
    # Mỗi món nhận danh sách bước (steps), định dạng ở core/steps.rb. Mọi điểm và độ dài tính bằng mm; góc tính bằng độ.
    module RotateScale
      SCALE_MIN = 0.001
      SCALE_MAX = 1000.0
      ANGLE_LIMIT = 3600.0 # ±3600° là nhập nhầm
      AXIS_NAMES = %w[X Y Z].freeze

      ROTATE_TOLERANCE_DEG = 1e-4 # lệch dưới 0,0001° coi là đã đúng hướng

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

      # Xoay tuyệt đối: đưa góc X, Y, Z hiện tại của mỗi món (xem Items.euler_degrees) về đúng góc đã nhập; ô nil giữ góc hiện tại.
      # Gõ 0 là quay về hướng gốc (trục riêng song song trục thế giới). Mỗi món một phép xoay quanh tâm đã chọn đưa hướng hiện tại về hướng đích.
      def absolute_rotate(items, degrees, pivot_mode)
        Items.check(items)
        raise ArgumentError, "Góc vượt giới hạn ±#{ANGLE_LIMIT.to_i}°." if degrees.compact.any? { |d| d.abs > ANGLE_LIMIT }
        raise ArgumentError, 'Hãy nhập ít nhất một góc (X, Y hoặc Z).' if degrees.all?(&:nil?)
        moves = items.map do |item|
          current = Items.euler_degrees(item[:axes])
          target = (0..2).map { |i| degrees[i].nil? ? current[i] : degrees[i] }
          axis, angle = axis_angle(matrix_mul(euler_matrix(target), transpose(columns_matrix(item[:axes]))))
          steps = angle.abs < ROTATE_TOLERANCE_DEG ? [] : [{kind: 'rotate', pivot: Items.pivot_for(items, pivot_mode, item), axis: axis, degrees: angle}]
          {index: item[:index], steps: steps}
        end
        raise NothingToDo, 'Đã đúng hướng đó, không cần xoay.' if moves.all? { |move| move[:steps].empty? }
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

      # ----- Ma trận xoay 3 x 3 (hàng, thuần Ruby) cho xoay tuyệt đối -----
      # Ma trận có ba cột là ba trục riêng của món.
      def columns_matrix(axes)
        (0..2).map { |i| (0..2).map { |k| axes[k][i] } }
      end

      def transpose(m)
        (0..2).map { |i| (0..2).map { |k| m[k][i] } }
      end

      def matrix_mul(a, b)
        (0..2).map { |i| (0..2).map { |k| (0..2).sum { |j| a[i][j] * b[j][k] } } }
      end

      # R = Rz * Ry * Rx từ ba góc (độ).
      def euler_matrix(degrees)
        a, b, g = degrees.map { |d| d * Math::PI / 180.0 }
        rx = [[1.0, 0.0, 0.0], [0.0, Math.cos(a), -Math.sin(a)], [0.0, Math.sin(a), Math.cos(a)]]
        ry = [[Math.cos(b), 0.0, Math.sin(b)], [0.0, 1.0, 0.0], [-Math.sin(b), 0.0, Math.cos(b)]]
        rz = [[Math.cos(g), -Math.sin(g), 0.0], [Math.sin(g), Math.cos(g), 0.0], [0.0, 0.0, 1.0]]
        matrix_mul(rz, matrix_mul(ry, rx))
      end

      # Trục (vector đơn vị) và góc (độ) của một phép xoay. Góc gần 180° tính trục từ đường chéo vì công thức thường mất độ chính xác.
      def axis_angle(m)
        cos = [[(m[0][0] + m[1][1] + m[2][2] - 1.0) / 2.0, 1.0].min, -1.0].max
        theta = Math.acos(cos)
        return [[0.0, 0.0, 1.0], 0.0] if theta < 1e-9
        if Math::PI - theta < 1e-4
          diag = (0..2).map { |i| Math.sqrt([(m[i][i] - cos) / (1.0 - cos), 0.0].max) }
          big = diag.index(diag.max)
          axis = diag.dup
          (0..2).each { |i| axis[i] = -axis[i] if i != big && (m[big][i] + m[i][big]) < 0.0 }
          return [axis, theta * 180.0 / Math::PI]
        end
        axis = [m[2][1] - m[1][2], m[0][2] - m[2][0], m[1][0] - m[0][1]].map { |v| v / (2.0 * Math.sin(theta)) }
        [axis, theta * 180.0 / Math::PI]
      end
    end
  end
end
