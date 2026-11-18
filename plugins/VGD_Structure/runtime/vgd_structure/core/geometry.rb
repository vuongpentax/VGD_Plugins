module VGD
  module Structure
    # Hình học mặt bằng dùng chung cho phần tử TỰ DO xiên (P4b-2): đa giác 4 đỉnh của dải (dầm, tường) và của cột xoay, hộp bao, kiểm tra chồng nhau.
    # Logic thuần, đơn vị mm.
    module Geometry
      EPS = 1e-6

      # Dải bề rộng `width` quanh đoạn a-b: 4 đỉnh (a phải, b phải, b trái, a trái) theo chiều ngược kim đồng hồ khi nhìn từ trên xuống.
      def self.strip(a, b, width)
        len = Math.hypot(b[0] - a[0], b[1] - a[1])
        ux = (b[0] - a[0]) / len
        uy = (b[1] - a[1]) / len
        h = width / 2.0
        [[a[0] + uy * h, a[1] - ux * h], [b[0] + uy * h, b[1] - ux * h], [b[0] - uy * h, b[1] + ux * h], [a[0] - uy * h, a[1] + ux * h]]
      end

      # Hình chữ nhật rộng w, sâu d quanh tâm, xoay `deg` độ ngược chiều kim đồng hồ.
      def self.rotated_rect(center, w, d, deg)
        r = deg * Math::PI / 180.0
        c = Math.cos(r)
        s = Math.sin(r)
        [[-w / 2.0, -d / 2.0], [w / 2.0, -d / 2.0], [w / 2.0, d / 2.0], [-w / 2.0, d / 2.0]].map { |x, y| [center[0] + x * c - y * s, center[1] + x * s + y * c] }
      end

      def self.bounds(poly)
        xs = poly.map(&:first)
        ys = poly.map(&:last)
        [[xs.min, ys.min], [xs.max, ys.max]]
      end

      def self.round_poly(poly, digits = 2)
        poly.map { |p| p.map { |v| v.round(digits) } }
      end

      # Hai đa giác lồi chồng nhau (phần chung có diện tích > 0, chạm cạnh không tính): định lý trục phân cách.
      def self.overlap?(p, q)
        [p, q].each do |poly|
          poly.each_with_index do |a, i|
            b = poly[(i + 1) % poly.size]
            nx = b[1] - a[1]
            ny = a[0] - b[0]
            len = Math.hypot(nx, ny)
            next if len < EPS
            pr = p.map { |v| (v[0] * nx + v[1] * ny) / len }
            qr = q.map { |v| (v[0] * nx + v[1] * ny) / len }
            return false if pr.max <= qr.min + EPS || qr.max <= pr.min + EPS
          end
        end
        true
      end

      # Hướng (độ, ngược chiều kim đồng hồ từ +X) của đoạn a -> b.
      def self.angle(a, b)
        Math.atan2(b[1] - a[1], b[0] - a[0]) * 180.0 / Math::PI
      end
    end
  end
end
