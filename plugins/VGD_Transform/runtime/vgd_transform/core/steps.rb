module VGD
  module Transform
    # Bước biến đổi và điểm sau khi áp dụng các bước. Logic thuần (không gọi SketchUp).
    # Bước: translate {delta}, rotate {pivot, axis, degrees}, scale {pivot, factors}. Mọi điểm tính bằng mm; góc tính bằng độ.
    module Steps
      module_function

      # Điểm sau khi áp dụng các bước theo thứ tự. Dùng để kiểm tra lại sau khi biến đổi trong SketchUp.
      def apply_steps(steps, point)
        steps.reduce(point) { |p, step| apply_step(step, p) }
      end

      def apply_step(step, point)
        case step[:kind]
        when 'translate' then point.zip(step[:delta]).map { |a, d| a + d }
        when 'rotate' then rotate_point(point, step[:pivot], step[:axis], step[:degrees])
        when 'scale' then scale_point(point, step[:pivot], step[:factors])
        else raise ArgumentError, 'Bước biến đổi không hợp lệ.'
        end
      end

      # Xoay điểm quanh trục đi qua pivot (công thức Rodrigues).
      def rotate_point(point, pivot, axis, degrees)
        v = point.zip(pivot).map { |a, b| a - b }
        k = axis
        theta = degrees * Math::PI / 180.0
        cos = Math.cos(theta)
        sin = Math.sin(theta)
        kv = dot(k, v)
        cross = [k[1] * v[2] - k[2] * v[1], k[2] * v[0] - k[0] * v[2], k[0] * v[1] - k[1] * v[0]]
        rotated = (0..2).map { |i| v[i] * cos + cross[i] * sin + k[i] * kv * (1 - cos) }
        pivot.zip(rotated).map { |p, r| p + r }
      end

      def scale_point(point, pivot, factors)
        pivot.each_index.map { |i| pivot[i] + (point[i] - pivot[i]) * factors[i] }
      end

      def dot(a, b)
        a.zip(b).sum { |x, y| x * y }
      end
    end
  end
end
