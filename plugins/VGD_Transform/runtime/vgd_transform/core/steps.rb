module VGD
  module Transform
    # Bước biến đổi và điểm sau khi áp dụng các bước. Logic thuần (không gọi SketchUp).
    # Bước (mọi điểm, vector theo hệ thế giới, mm; góc bằng độ):
    #   translate {delta}; rotate {pivot, axis (vector đơn vị), degrees};
    #   scale {pivot, factors, axes (3 vector đơn vị vuông góc; mặc định trục thế giới)}.
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
        when 'scale' then scale_point(point, step[:pivot], step[:factors], step[:axes] || Items::WORLD_AXES)
        else raise ArgumentError, 'Bước biến đổi không hợp lệ.'
        end
      end

      # Xoay điểm quanh trục đi qua pivot (công thức Rodrigues).
      def rotate_point(point, pivot, axis, degrees)
        v = sub(point, pivot)
        k = axis
        theta = degrees * Math::PI / 180.0
        cos = Math.cos(theta)
        sin = Math.sin(theta)
        kv = dot(k, v)
        cross = [k[1] * v[2] - k[2] * v[1], k[2] * v[0] - k[0] * v[2], k[0] * v[1] - k[1] * v[0]]
        rotated = (0..2).map { |i| v[i] * cos + cross[i] * sin + k[i] * kv * (1 - cos) }
        add(pivot, rotated)
      end

      # Scale quanh pivot theo ba trục vuông góc: thành phần của điểm trên trục thứ i nhân hệ số thứ i.
      def scale_point(point, pivot, factors, axes)
        v = sub(point, pivot)
        scaled = axes.each_with_index.reduce([0.0, 0.0, 0.0]) { |sum, (a, i)| add(sum, mul(a, dot(v, a) * factors[i])) }
        add(pivot, scaled)
      end

      def dot(a, b)
        a.zip(b).sum { |x, y| x * y }
      end

      def add(a, b)
        a.zip(b).map { |x, y| x + y }
      end

      def sub(a, b)
        a.zip(b).map { |x, y| x - y }
      end

      def mul(a, k)
        a.map { |x| x * k }
      end
    end
  end
end
