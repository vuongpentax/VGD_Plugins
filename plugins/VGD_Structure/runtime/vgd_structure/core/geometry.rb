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

      # ---- Vòng đa giác tùy ý (sàn, trần đa giác, P4b-3) ----
      RING_TOL = 0.05 # mm: điểm gần nhau hơn mức này coi là trùng

      def self.area2(ring) # diện tích có dấu x 2 (dương: ngược chiều kim đồng hồ)
        ring.each_with_index.sum { |p, i| q = ring[(i + 1) % ring.size]; p[0] * q[1] - q[0] * p[1] }
      end

      def self.area(ring)
        area2(ring).abs / 2.0
      end

      # Bỏ điểm trùng liên tiếp và điểm đóng vòng lặp lại điểm đầu.
      def self.clean_ring(points)
        out = []
        points.each { |p| out << p if out.empty? || Math.hypot(p[0] - out.last[0], p[1] - out.last[1]) > RING_TOL }
        out.pop while out.size > 1 && Math.hypot(out.last[0] - out.first[0], out.last[1] - out.first[1]) <= RING_TOL
        out
      end

      def self.orient(a, b, c)
        (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
      end

      # Hai đoạn chạm nhau (kể cả chạm đầu mút hoặc chồng cùng đường).
      def self.segments_touch?(a, b, c, d)
        d1 = orient(a, b, c)
        d2 = orient(a, b, d)
        d3 = orient(c, d, a)
        d4 = orient(c, d, b)
        return true if ((d1 > EPS && d2 < -EPS) || (d1 < -EPS && d2 > EPS)) && ((d3 > EPS && d4 < -EPS) || (d3 < -EPS && d4 > EPS))
        on = ->(p, q, r) { orient(p, q, r).abs <= EPS * [1, Math.hypot(q[0] - p[0], q[1] - p[1])].max * 1000 && r[0].between?([p[0], q[0]].min - RING_TOL, [p[0], q[0]].max + RING_TOL) && r[1].between?([p[1], q[1]].min - RING_TOL, [p[1], q[1]].max + RING_TOL) }
        on.call(a, b, c) || on.call(a, b, d) || on.call(c, d, a) || on.call(c, d, b)
      end

      # Hai đoạn CẮT nhau thật (không tính chạm đầu mút / chung đầu).
      def self.segments_cross?(a, b, c, d)
        d1 = orient(a, b, c)
        d2 = orient(a, b, d)
        d3 = orient(c, d, a)
        d4 = orient(c, d, b)
        ((d1 > EPS && d2 < -EPS) || (d1 < -EPS && d2 > EPS)) && ((d3 > EPS && d4 < -EPS) || (d3 < -EPS && d4 > EPS))
      end

      # Vòng đơn: không tự cắt, không có hai cạnh không kề nhau chạm nhau.
      def self.simple_ring?(ring)
        n = ring.size
        return false if n < 3 || area(ring) < 1.0
        n.times do |i|
          (i + 1...n).each do |j|
            next if j == i || (j + 1) % n == i || (i + 1) % n == j # cạnh kề nhau
            return false if segments_touch?(ring[i], ring[(i + 1) % n], ring[j], ring[(j + 1) % n])
          end
        end
        true
      end

      def self.point_on_ring?(pt, ring)
        ring.each_with_index.any? do |a, i|
          b = ring[(i + 1) % ring.size]
          l2 = ((b[0] - a[0])**2 + (b[1] - a[1])**2).to_f
          t = l2.zero? ? 0 : [[((pt[0] - a[0]) * (b[0] - a[0]) + (pt[1] - a[1]) * (b[1] - a[1])) / l2, 0].max, 1].min
          Math.hypot(pt[0] - (a[0] + (b[0] - a[0]) * t), pt[1] - (a[1] + (b[1] - a[1]) * t)) <= RING_TOL
        end
      end

      # Điểm nằm TRONG vòng (không tính điểm trên cạnh).
      def self.inside_ring?(pt, ring)
        return false if point_on_ring?(pt, ring)
        inside = false
        ring.each_with_index do |a, i|
          b = ring[(i + 1) % ring.size]
          inside = !inside if (a[1] > pt[1]) != (b[1] > pt[1]) && pt[0] < (b[0] - a[0]) * (pt[1] - a[1]) / (b[1] - a[1]).to_f + a[0]
        end
        inside
      end

      # Điểm nằm trong MIỀN (vòng ngoài trừ các lỗ).
      def self.inside_region?(pt, ring, holes)
        inside_ring?(pt, ring) && holes.none? { |h| inside_ring?(pt, h) || point_on_ring?(pt, h) }
      end

      # Hai miền (vòng ngoài + lỗ) chồng nhau: có đỉnh hoặc trung điểm cạnh của vòng này nằm trong miền kia, hoặc hai vòng ngoài cắt nhau.
      # Gần đúng: hai miền trùng khít nhau hoàn toàn (mọi đỉnh nằm trên cạnh) không được phát hiện.
      def self.regions_overlap?(ring_a, holes_a, ring_b, holes_b)
        samples = ->(r) { r + r.each_with_index.map { |a, i| b = r[(i + 1) % r.size]; [(a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0] } }
        return true if samples.call(ring_a).any? { |v| inside_region?(v, ring_b, holes_b) } || samples.call(ring_b).any? { |v| inside_region?(v, ring_a, holes_a) }
        ring_a.each_with_index.any? { |a, i| ring_b.each_with_index.any? { |c, j| segments_cross?(a, ring_a[(i + 1) % ring_a.size], c, ring_b[(j + 1) % ring_b.size]) } }
      end
    end
  end
end
