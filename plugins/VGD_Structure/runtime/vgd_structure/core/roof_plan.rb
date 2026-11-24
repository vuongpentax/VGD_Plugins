module VGD
  module Structure
    # Kế hoạch mái của một tầng có khai báo `roof` (Levels.roof!). Logic thuần.
    # Đường mép (chân) mái là khung lưới (trục biên); mái chìa ra ngoài `overhang` mỗi phía. Đáy mái tại đường mép ở cao độ z_b = cao độ tầng + base,
    # mặt mái dốc lên theo khoảng cách d tới đường mép (d âm ở phần chìa): mặt trên z = z_b + tv + d * tan(dốc), tv = dày / cos(dốc) là bề dày theo phương đứng.
    # Mỗi mặt mái là một tấm: đa giác MẶT TRÊN 3D (4 đỉnh, mm) đùn xuống tv theo phương đứng (nên thể tích = diện tích nghiêng x dày).
    # Mái hai dốc: hai tấm gặp nhau ở nóc, không chồng nhau trên mặt bằng. Mái bốn dốc (hip): cùng một độ dốc cho bốn phía, bốn tấm nam, đông, bắc, tây (hình thang hoặc tam giác);
    # nóc là đoạn nằm giữa khung theo phương dài, dài (dài - rộng), hoặc một điểm nếu khung vuông.
    # Tường thu hồi (`roof['gable_wall']`): giao của mặt phẳng đứng ở mỗi cạnh biên khung với ĐÁY mái; chỉ cạnh nào đáy mái đổi độ cao dọc cạnh mới có tường (đầu hồi mái hai dốc, hai cạnh
    # song song hướng dốc của mái một dốc), nên không mã hóa riêng "tam giác" hay "hình thang". Tường đứng trên mặt sàn kết cấu của tầng, mặt ngoài trùng trục biên.
    # Mái theo đường bao (`outline`): đa giác LỒI nối các giao điểm lưới, cùng một độ dốc cho mọi cạnh, mỗi cạnh một tấm; không có tường thu hồi. Chưa làm: đa giác lõm, dốc riêng từng cạnh.
    module RoofPlan
      Error = Class.new(ArgumentError)

      def self.plan(grid, levels, level_id, wall_types = nil)
        level = Levels.find(levels, level_id) or raise Error, 'Tầng không tồn tại.'
        roof = level['roof'] or raise Error, "Tầng “#{level['name']}” chưa khai báo mái."
        x0, y0, x1, y1 = Grid.bounds(grid)
        o = roof['overhang']
        slope = roof['shape'] == 'flat' ? 0.0 : roof['slope']
        tan = Math.tan(slope * Math::PI / 180)
        tv = (roof['thickness'] / Math.cos(slope * Math::PI / 180)).round(2)
        zb = (level['elevation'] + roof['base']).round(1)
        parts = case roof['shape']
                when 'flat' then [[rect_corners(x0 - o, y0 - o, x1 + o, y1 + o), ->(_x, _y) { 0.0 }]]
                when 'shed' then [[rect_corners(x0 - o, y0 - o, x1 + o, y1 + o), rise_of(roof['dir'], x0, y0, x1, y1)]]
                when 'hip' then hip(x0, y0, x1, y1, o)
                when 'outline' then outline(grid, roof['points'], o, level['name'])
                else gable(roof['dir'], x0, y0, x1, y1, o)
                end
        items = parts.each_with_index.map do |(corners, rise), i|
          top = corners.map { |x, y| [x.round(2), y.round(2), (zb + tv + rise.call(x, y) * tan).round(2)] }
          poly = top.map { |x, y, _| [x, y] }
          plan_area = polygon_area(poly) / 1_000_000.0
          {ref: parts.size == 1 ? 'roof' : "roof_#{i + 1}", top: top, poly: poly, tv: tv, thickness: roof['thickness'], slope: slope,
           shape: roof['shape'], area: (plan_area / Math.cos(slope * Math::PI / 180)).round(3), plan_area: plan_area.round(3)}
        end
        issues = []
        ridge = items.map { |i| i[:top].map(&:last).max }.max
        issues << "Nóc mái cao #{(ridge - zb).round} mm so với chân mái: kiểm tra lại độ dốc." if ridge - zb > 15_000
        gables = roof['gable_wall'] ? gable_walls(level, roof, items, [x0, y0, x1, y1], tv, wall_types || WallTypes.default) : []
        {level: level, z_base: zb, ridge: ridge, items: items, gables: gables, issues: issues}
      end

      GABLE_EDGES = {'south' => [[0, 1], 1.0, [0.0, 1.0]], 'east' => [[1, 2], 1.0, [-1.0, 0.0]], 'north' => [[2, 3], 1.0, [0.0, -1.0]], 'west' => [[3, 0], 1.0, [1.0, 0.0]]}.freeze
      EDGE_FLAT_MM = 1.0   # đáy mái lệch dưới 1 mm dọc cạnh coi là phẳng (cạnh mái hiên, đầu cao, đầu thấp: không có tường thu hồi)

      # Tường thu hồi theo từng cạnh biên khung (nam, đông, bắc, tây, đi ngược chiều kim đồng hồ): biên dạng đỉnh = đáy mái dọc cạnh.
      def self.gable_walls(level, roof, items, bounds, tv, wall_types)
        type = wall_types.find { |t| t['id'] == roof['gable_wall']['type'] } or raise Error, "Tầng “#{level['name']}”: loại tường của tường thu hồi không tồn tại."
        x0, y0, x1, y1 = bounds
        corners = [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]
        floor = Levels.structure_top(level)
        GABLE_EDGES.filter_map do |edge, (ends, _, inward)|
          a, b = corners[ends[0]], corners[ends[1]]
          length = Math.hypot(b[0] - a[0], b[1] - a[1])
          profile = edge_profile(items, a, b, length, tv)
          next if profile.size < 2
          zs = profile.map(&:last)
          next if zs.max - zs.min < EDGE_FLAT_MM || zs.max <= floor + EDGE_FLAT_MM
          heights = profile.map { |_, z| [z - floor, 0.0].max }
          area = profile.each_cons(2).each_with_index.sum { |((s0, _), (s1, _)), i| (s1 - s0) * (heights[i] + heights[i + 1]) / 2.0 }
          {ref: "gable_#{edge}", edge: edge, a: a.map { |v| v.round(2) }, b: b.map { |v| v.round(2) }, inward: inward, t: type['t'], type_id: type['id'], type_name: type['name'],
           profile: profile, floor: floor, length: length.round(2), height: (area / length).round(1), area: (area / 1_000_000.0).round(4)}
        end
      end

      # Đáy mái dọc đoạn a -> b: [[s mm tính từ a, cao độ đáy]] tăng dần theo s. Cắt đoạn qua từng tấm (đa giác lồi) rồi nội suy theo mặt phẳng của tấm.
      def self.edge_profile(items, a, b, length, tv)
        points = {}
        items.each do |item|
          clip = clip_segment(a, b, item[:poly]) or next
          plane = plane_of(item[:top])
          clip.each do |t|
            x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            points[(t * length).round(1)] = (plane.call(x, y) - tv).round(1)
          end
        end
        list = points.sort.map { |s, z| [s, z] }
        list.reject.with_index { |(s, z), i| i.positive? && i < list.size - 1 && collinear?(list[i - 1], [s, z], list[i + 1]) }
      end

      def self.collinear?(p, q, r)
        ((q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])).abs < 0.05 * (r[0] - p[0]).abs
      end

      # Mặt phẳng z = f(x, y) qua ba đỉnh đầu của một tấm mái (đỉnh liên tiếp đầu tiên không thẳng hàng).
      def self.plane_of(top)
        p0, p1, p2 = top[0], top[1], top[2]
        ux, uy, uz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
        vx, vy, vz = p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2]
        det = ux * vy - uy * vx
        ca = (uz * vy - uy * vz) / det
        cb = (ux * vz - uz * vx) / det
        ->(x, y) { p0[2] + ca * (x - p0[0]) + cb * (y - p0[1]) }
      end

      # Phần đoạn a -> b nằm trong đa giác LỒI ngược chiều kim đồng hồ (Cyrus - Beck): [t0, t1] trong [0, 1] hoặc nil.
      def self.clip_segment(a, b, poly)
        t0, t1 = 0.0, 1.0
        dx, dy = b[0] - a[0], b[1] - a[1]
        poly.each_with_index do |p, i|
          q = poly[(i + 1) % poly.size]
          ex, ey = q[0] - p[0], q[1] - p[1]
          len = Math.hypot(ex, ey)
          nx, ny = -ey / len, ex / len
          num = nx * (a[0] - p[0]) + ny * (a[1] - p[1])
          den = nx * dx + ny * dy
          if den.abs < 1e-9
            return nil if num < -0.01
          else
            t = -num / den
            den.positive? ? t0 = [t0, t].max : t1 = [t1, t].min
          end
        end
        t1 > t0 + 1e-9 ? [t0, t1] : nil
      end

      def self.rect_corners(ax, ay, bx, by)
        [[ax, ay], [bx, ay], [bx, by], [ax, by]]
      end

      # Diện tích đa giác phẳng (shoelace), mm².
      def self.polygon_area(poly)
        poly.each_with_index.sum { |(x, y), i| nx, ny = poly[(i + 1) % poly.size]; x * ny - nx * y }.abs / 2.0
      end

      # Mái một dốc: khoảng cách tới đường mép phía THẤP (dốc lên theo `dir`).
      def self.rise_of(dir, x0, y0, x1, y1)
        case dir
        when 'x+' then ->(x, _y) { x - x0 }
        when 'x-' then ->(x, _y) { x1 - x }
        when 'y+' then ->(_x, y) { y - y0 }
        else ->(_x, y) { y1 - y }
        end
      end

      # Mái hai dốc: nóc ở giữa khung, song song phương `dir`; mỗi tấm dốc lên từ đường mép của nó tới nóc.
      def self.gable(dir, x0, y0, x1, y1, o)
        if dir == 'x'
          ym = (y0 + y1) / 2.0
          [[rect_corners(x0 - o, y0 - o, x1 + o, ym), ->(_x, y) { y - y0 }], [rect_corners(x0 - o, ym, x1 + o, y1 + o), ->(_x, y) { y1 - y }]]
        else
          xm = (x0 + x1) / 2.0
          [[rect_corners(x0 - o, y0 - o, xm, y1 + o), ->(x, _y) { x - x0 }], [rect_corners(xm, y0 - o, x1 + o, y1 + o), ->(x, _y) { x1 - x }]]
        end
      end

      # Mái bốn dốc: độ cao = dốc x khoảng cách tới mép khung GẦN NHẤT (nên bốn mặt dốc đều nhau). Hai đầu nóc A, B cách mép m = nửa cạnh ngắn; các đường
      # chéo 45° từ góc khung qua góc chìa tới A, B. Bốn tấm theo thứ tự nam, đông, bắc, tây, đỉnh ngược chiều kim đồng hồ (nhìn từ trên); khung vuông thì A = B
      # và các tấm hình thang thành tam giác (đỉnh trùng bị bỏ).
      def self.hip(x0, y0, x1, y1, o)
        rise = ->(x, y) { [x - x0, x1 - x, y - y0, y1 - y].min }
        m = [x1 - x0, y1 - y0].min / 2.0
        ox0, oy0, ox1, oy1 = x0 - o, y0 - o, x1 + o, y1 + o
        a, b = if (x1 - x0) >= (y1 - y0)
                 [[x0 + m, (y0 + y1) / 2.0], [x1 - m, (y0 + y1) / 2.0]]
               else
                 [[(x0 + x1) / 2.0, y0 + m], [(x0 + x1) / 2.0, y1 - m]]
               end
        sw, se, ne, nw = [ox0, oy0], [ox1, oy0], [ox1, oy1], [ox0, oy1]
        sides = if (x1 - x0) >= (y1 - y0)
                  [[sw, se, b, a], [se, ne, b], [ne, nw, a, b], [nw, sw, a]]
                else
                  [[sw, se, a], [se, ne, b, a], [ne, nw, b], [nw, sw, a, b]]
                end
        sides.map { |corners| [dedupe(corners), rise] }
      end

      # Mái theo đường bao: độ cao tại điểm bất kỳ = dốc x khoảng cách CÓ DẤU tới đường chứa cạnh GẦN NHẤT (phần chìa ra ngoài có khoảng cách âm, như mái bốn dốc).
      # Mỗi cạnh một tấm = vùng đa giác (đã chìa ra o) mà cạnh đó gần nhất; vùng này lồi nên cắt từng nửa mặt phẳng "khoảng cách tới cạnh i <= tới cạnh j".
      # Khung chữ nhật cho kết quả như mái bốn dốc. Trả về [[đỉnh tấm, hàm độ cao]] theo thứ tự các cạnh.
      def self.outline(grid, refs, o, level_name)
        ring = outline_ring(grid, refs, level_name)
        lines = ring.each_index.map do |i|
          a, b = ring[i], ring[(i + 1) % ring.size]
          len = Math.hypot(b[0] - a[0], b[1] - a[1])
          nx, ny = -(b[1] - a[1]) / len, (b[0] - a[0]) / len # pháp tuyến hướng vào trong (đa giác ngược chiều kim đồng hồ)
          [nx, ny, nx * a[0] + ny * a[1]]
        end
        around = lines.each_index.map do |i|
          n1, n2 = lines[i - 1], lines[i]
          det = n1[0] * n2[1] - n1[1] * n2[0]
          c1, c2 = n1[2] - o, n2[2] - o
          [(c1 * n2[1] - c2 * n1[1]) / det, (n1[0] * c2 - n2[0] * c1) / det] # giao của hai đường cạnh đã dời ra ngoài o
        end
        lines.each_with_index.filter_map do |(nx, ny, c), i|
          face = lines.each_with_index.reduce(around) do |poly, ((mx, my, d), j)|
            j == i ? poly : clip_half(poly, mx - nx, my - ny, c - d) # khoảng cách tới cạnh j - tới cạnh i >= 0
          end
          face = drop_collinear(dedupe(face))
          next if face.size < 3 || polygon_area(face) < 1.0
          [face, ->(x, y) { nx * x + ny * y - c }]
        end
      end

      # Đỉnh đường bao (tọa độ thế giới, ngược chiều kim đồng hồ, không có đỉnh thẳng hàng). Báo lỗi nếu mã không còn trên lưới hoặc đa giác không lồi.
      def self.outline_ring(grid, refs, level_name)
        who = "Tầng “#{level_name}”: mái theo đường bao"
        known = Grid.intersections(grid).to_h { |i| [i[:ref], [i[:x], i[:y]]] }
        ring = refs.map { |r| known[r] or raise Error, "#{who}: đỉnh #{r} không còn trên lưới." }
        ring.reverse! if signed_area(ring).negative?
        raise Error, "#{who}: các đỉnh phải tạo thành một đa giác lồi có diện tích (không tự cắt)." if signed_area(ring) < 1.0
        n = ring.size
        keep = ring.each_index.reject do |i|
          a, b, c = ring[i - 1], ring[i], ring[(i + 1) % n]
          cross = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0])
          dot = (b[0] - a[0]) * (c[0] - b[0]) + (b[1] - a[1]) * (c[1] - b[1])
          next false unless cross.abs < 1e-9 * Math.hypot(b[0] - a[0], b[1] - a[1]) * Math.hypot(c[0] - b[0], c[1] - b[1])
          raise Error, "#{who}: đường bao gấp ngược lại tại đỉnh #{refs[i]}." if dot.negative?
          true # đỉnh nằm thẳng hàng trên cạnh: bỏ
        end
        ring = keep.map { |i| ring[i] }
        raise Error, "#{who}: cần ít nhất ba đỉnh không thẳng hàng." if ring.size < 3
        n = ring.size
        turns = ring.each_index.map do |i|
          a, b, c = ring[i - 1], ring[i], ring[(i + 1) % n]
          Math.atan2((b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]), (b[0] - a[0]) * (c[0] - b[0]) + (b[1] - a[1]) * (c[1] - b[1]))
        end
        raise Error, "#{who}: chỉ nhận đa giác lồi (không lõm, không tự cắt). Hãy chọn lại đỉnh." unless turns.all?(&:positive?) && (turns.sum - 2 * Math::PI).abs < 1e-6
        ring
      end

      def self.signed_area(poly)
        poly.each_with_index.sum { |(x, y), i| nx, ny = poly[(i + 1) % poly.size]; x * ny - nx * y } / 2.0
      end

      # Phần đa giác lồi nằm ở phía a.x + b.y + c >= 0 (Sutherland - Hodgman, một nửa mặt phẳng).
      def self.clip_half(poly, a, b, c)
        poly.each_with_index.flat_map do |p, i|
          q = poly[(i + 1) % poly.size]
          fp, fq = a * p[0] + b * p[1] + c, a * q[0] + b * q[1] + c
          out = fp >= -1e-6 ? [p] : []
          out << [p[0] + (q[0] - p[0]) * fp / (fp - fq), p[1] + (q[1] - p[1]) * fp / (fp - fq)] if (fp > 1e-6 && fq < -1e-6) || (fp < -1e-6 && fq > 1e-6)
          out
        end
      end

      # Bỏ đỉnh nằm trên đoạn nối hai đỉnh kề (cách đường thẳng chưa tới 0,01 mm): mặt phẳng của tấm xác định từ ba đỉnh đầu nên không được thẳng hàng.
      def self.drop_collinear(points)
        n = points.size
        points.each_index.reject do |i|
          a, b, c = points[i - 1], points[i], points[(i + 1) % n]
          len = Math.hypot(c[0] - a[0], c[1] - a[1])
          len < 0.01 || ((c[0] - a[0]) * (b[1] - a[1]) - (c[1] - a[1]) * (b[0] - a[0])).abs / len < 0.01
        end.map { |i| points[i] }
      end

      # Bỏ đỉnh trùng liên tiếp (khung vuông: hai đầu nóc trùng nhau).
      def self.dedupe(points)
        points.each_with_index.reject { |p, i| (p[0] - points[i - 1][0]).abs < 0.01 && (p[1] - points[i - 1][1]).abs < 0.01 }.map(&:first)
      end
    end
  end
end
