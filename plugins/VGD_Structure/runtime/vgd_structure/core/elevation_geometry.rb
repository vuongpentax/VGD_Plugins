module VGD
  module Structure
    # Hình học MẶT ĐỨNG 2D (logic thuần, không đụng SketchUp): chiếu các MẶT 3D lên mặt phẳng đứng nhìn từ một phía của model, KHÔNG cắt.
    # Các mặt được sắp từ xa đến gần rồi tô theo thứ tự đó, nên mặt phía trước che mặt phía sau (không che nét riêng từng cạnh). Mọi tọa độ mm.
    #   Hệ tọa độ mặt đứng: s = ngang (đứng trước mặt đứng nhìn vào: trái -> phải), z = cao độ, d = khoảng cách từ người xem vào model (lớn = xa).
    #   Hướng nhìn theo trục model: 'south' đứng ở -Y nhìn về +Y, 'north' đứng ở +Y, 'west' đứng ở -X, 'east' đứng ở +X.
    #   Giả định: hướng Bắc của model là +Y (mặc định của SketchUp); nếu model xoay khác thì nhãn Bắc / Nam / Đông / Tây không đúng hướng thật.
    #   mặt: {'outer' => [[x, y, z]...], 'loops' => [[[x, y, z]...]...] (lỗ), src: nguồn}.
    module ElevationGeometry
      EPS = 1e-6
      # Với mỗi hướng: trục (0 = x, 1 = y) và dấu của s (ngang) và của d (chiều sâu).
      VIEWS = {
        'south' => {s: [0, 1], d: [1, 1]},
        'north' => {s: [0, -1], d: [1, -1]},
        'west' => {s: [1, -1], d: [0, 1]},
        'east' => {s: [1, 1], d: [0, -1]}
      }.freeze

      def self.view!(name)
        VIEWS.fetch(name.to_s) { raise ArgumentError, 'Hướng mặt đứng không hợp lệ.' }
      end

      # [s, z, d] của điểm 3D (mm).
      def self.local(view, p)
        [view[:s][1] * p[view[:s][0]], p[2], view[:d][1] * p[view[:d][0]]]
      end

      # faces: [{'outer' => ..., 'loops' => ..., src: ...}]. Trả về {polys: [{pts: [[s, z]...], holes: [[[s, z]...]...], depth: d, src:}] từ XA ĐẾN GẦN, bounds: {s0, s1, z0, z1} hoặc nil}.
      # Mặt có diện tích 0 (nhìn thẳng cạnh) bị bỏ.
      def self.project(view, faces)
        polys = faces.filter_map do |face|
          pts = face['outer'].map { |p| local(view, p) }
          next if area(pts.map { |s, z, _| [s, z] }) < EPS
          {
            pts: pts.map { |s, z, _| [s.round(1), z.round(1)] },
            holes: (face['loops'] || []).map { |ring| ring.map { |p| local(view, p).then { |s, z, _| [s.round(1), z.round(1)] } } },
            depth: (pts.sum { |_, _, d| d } / pts.size).round(1),
            src: face[:src]
          }
        end
        polys.sort_by! { |poly| -poly[:depth] }
        {polys: polys, bounds: bounds(polys)}
      end

      # Diện tích có dấu theo công thức đa giác (mm²); chỉ dùng để bỏ mặt suy biến.
      def self.area(ring)
        ring.each_with_index.sum { |(s0, z0), i| s1, z1 = ring[(i + 1) % ring.size]; s0 * z1 - s1 * z0 }.abs / 2.0
      end

      def self.bounds(polys)
        return nil if polys.empty?
        ss = polys.flat_map { |poly| poly[:pts].map(&:first) }
        zs = polys.flat_map { |poly| poly[:pts].map(&:last) }
        {s0: ss.min, s1: ss.max, z0: zs.min, z1: zs.max}
      end
    end
  end
end
