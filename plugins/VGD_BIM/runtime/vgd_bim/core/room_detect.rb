require_relative 'rooms'

module VGD
  module BIM
    # Dò vùng phòng từ tường (đặc tả docs/vgd_bim/ROOM_FROM_WALLS.md, mục 3). Thuật toán THUẦN Ruby, không gọi SketchUp: nhận các đoạn thẳng
    # (giao tuyến của mặt tường với mặt phẳng nằm ngang ở độ cao cắt, mm, XY thế giới) và trả về các vùng kín giữa tường.
    # Các bước: tách đoạn tại mọi điểm giao / chạm -> bỏ đầu hở (đoạn cụt) -> duyệt các mặt của đồ thị phẳng, bỏ mặt bao ngoài ->
    # vùng của một cụm tường nằm trong mặt của cụm khác là LỖ (cột đứng một mình) -> bỏ vùng quá nhỏ và vùng hẹp (ruột tường).
    # Vùng không kín (có chỗ hở tường) không thành vùng: phần hở được báo (open_ends), phòng liền với bên ngoài không được tạo.
    module RoomDetect
      TOLERANCE = 1.0          # mm: hai điểm gần hơn coi là một; đoạn ngắn hơn bị bỏ
      MIN_WIDTH = 350.0        # mm: vùng hẹp hơn (bề rộng nhỏ nhất của bao lồi) là ruột tường chứ không phải phòng (ngưỡng D3, chỉnh được)
      MIN_AREA = 200_000.0     # mm2 (0,2 m2): vùng nhỏ hơn bị bỏ
      MAX_SEGMENTS = 2500      # nhiều hơn thì từ chối (model quá lớn, tính chậm): hãy chọn ít tường hơn
      PARALLEL = 1.0e-9        # sin góc coi là song song

      # segments: [[x1, y1, x2, y2], ...] (mm). Trả về
      # {regions: [{boundary:, holes:, area:, width:, center:}], dropped: [{reason:, area:, width:, center:}], open_ends:, segments:}
      # area: mm2 (đã trừ lỗ), width: mm, center: [x, y]. Vùng sắp từ trái sang phải rồi từ dưới lên.
      def self.detect(segments, min_width: MIN_WIDTH)
        raise ArgumentError, 'Danh sách đoạn tường không hợp lệ.' unless segments.is_a?(Array) && segments.all? { |s| s.is_a?(Array) && s.size == 4 && s.all? { |v| v.is_a?(Numeric) && v.finite? } }
        raise ArgumentError, 'Bề rộng tối thiểu phải là số lớn hơn 0.' unless min_width.is_a?(Numeric) && min_width.positive?
        clean = segments.map { |s| s.map(&:to_f) }.reject { |s| Math.hypot(s[2] - s[0], s[3] - s[1]) < TOLERANCE }
        raise ArgumentError, "Có quá nhiều đoạn tường (#{clean.size}, tối đa #{MAX_SEGMENTS}). Hãy chọn ít tường hơn." if clean.size > MAX_SEGMENTS
        return {regions: [], dropped: [], open_ends: 0, segments: clean.size} if clean.empty?
        points, edges = build_graph(clean)
        edges, open_ends = prune_dangling(edges)
        cycles = trace_faces(points, edges)
        regions, dropped = classify(points, cycles, min_width)
        {regions: regions, dropped: dropped, open_ends: open_ends, segments: clean.size}
      end

      # ---- Đồ thị phẳng ----

      # Tách các đoạn tại mọi giao điểm, chạm chữ T và đoạn chồng nhau; gộp điểm gần nhau. Trả về [điểm, cạnh] (cạnh = [i, j] với i < j, không trùng).
      def self.build_graph(segments)
        cuts = Array.new(segments.size) { [] }
        segments.each_with_index do |a, i|
          ((i + 1)...segments.size).each do |j|
            b = segments[j]
            intersections(a, b).each do |x, y|
              cuts[i] << param(a, x, y)
              cuts[j] << param(b, x, y)
            end
          end
        end
        registry = PointRegistry.new
        edge_set = {}
        segments.each_with_index do |s, i|
          ts = ([0.0, 1.0] + cuts[i]).map { |t| t.clamp(0.0, 1.0) }.sort
          ids = ts.map { |t| registry.id(s[0] + (s[2] - s[0]) * t, s[1] + (s[3] - s[1]) * t) }.chunk_while { |u, v| u == v }.map(&:first)
          ids.each_cons(2) { |u, v| edge_set[[u, v].minmax] = true unless u == v }
        end
        [registry.points, edge_set.keys]
      end

      # Điểm trong khoảng cách TOLERANCE được gộp về một mã.
      class PointRegistry
        attr_reader :points
        def initialize; @points = []; @grid = {}; end

        def id(x, y)
          cx = (x / TOLERANCE).floor
          cy = (y / TOLERANCE).floor
          (-1..1).each do |dx|
            (-1..1).each do |dy|
              (@grid[[cx + dx, cy + dy]] || []).each { |i| return i if Math.hypot(@points[i][0] - x, @points[i][1] - y) <= TOLERANCE }
            end
          end
          @points << [x, y]
          (@grid[[cx, cy]] ||= []) << (@points.size - 1)
          @points.size - 1
        end
      end

      # Tham số t (0..1) của điểm (x, y) dọc đoạn s.
      def self.param(s, x, y)
        dx = s[2] - s[0]
        dy = s[3] - s[1]
        ((x - s[0]) * dx + (y - s[1]) * dy) / (dx * dx + dy * dy)
      end

      # Điểm chung của hai đoạn: giao điểm, chạm đầu đoạn (kể cả sát trong TOLERANCE), và hai đầu mút của đoạn chồng nhau.
      def self.intersections(a, b)
        rx = a[2] - a[0]
        ry = a[3] - a[1]
        sx = b[2] - b[0]
        sy = b[3] - b[1]
        len_a = Math.hypot(rx, ry)
        len_b = Math.hypot(sx, sy)
        denom = rx * sy - ry * sx
        qx = b[0] - a[0]
        qy = b[1] - a[1]
        if denom.abs / (len_a * len_b) > PARALLEL
          t = (qx * sy - qy * sx) / denom
          u = (qx * ry - qy * rx) / denom
          slack_t = TOLERANCE / len_a
          slack_u = TOLERANCE / len_b
          return [] unless t >= -slack_t && t <= 1 + slack_t && u >= -slack_u && u <= 1 + slack_u
          return [[a[0] + rx * t.clamp(0.0, 1.0), a[1] + ry * t.clamp(0.0, 1.0)]]
        end
        # song song: chỉ xét khi cùng một đường thẳng; thêm đầu mút của đoạn này nằm trên đoạn kia
        return [] if (qx * ry - qy * rx).abs / len_a > TOLERANCE
        found = []
        [[b[0], b[1]], [b[2], b[3]]].each { |x, y| found << [x, y] if on_segment?(a, x, y) }
        [[a[0], a[1]], [a[2], a[3]]].each { |x, y| found << [x, y] if on_segment?(b, x, y) }
        found
      end

      def self.on_segment?(s, x, y)
        t = param(s, x, y)
        return false if t < 0.0 || t > 1.0
        Math.hypot(s[0] + (s[2] - s[0]) * t - x, s[1] + (s[3] - s[1]) * t - y) <= TOLERANCE
      end

      # Bỏ liên tiếp các cạnh cụt (đỉnh bậc 1): đầu tường hở không khép kín được. Trả về [cạnh còn lại, số đầu cụt].
      def self.prune_dangling(edges)
        adjacency = Hash.new { |h, k| h[k] = [] }
        edges.each { |u, v| adjacency[u] << v; adjacency[v] << u }
        queue = adjacency.select { |_v, list| list.size == 1 }.keys
        open_ends = queue.size
        until queue.empty?
          v = queue.pop
          next unless adjacency.key?(v) && adjacency[v].size == 1
          u = adjacency[v].first
          adjacency.delete(v)
          adjacency[u].delete(v)
          queue << u if adjacency[u].size == 1
          adjacency.delete(u) if adjacency[u].empty?
        end
        [adjacency.flat_map { |u, list| list.map { |v| [u, v].minmax } }.uniq, open_ends]
      end

      # Duyệt mọi mặt (chu trình) của đồ thị phẳng: mỗi cạnh có hướng được đi đúng một lần, mặt nằm bên trái. Trả về
      # [{ring: [mã điểm], area: diện tích có dấu, component: mã cụm liên thông}]; diện tích dương là mặt trong, âm là bao ngoài của cụm.
      def self.trace_faces(points, edges)
        neighbors = Hash.new { |h, k| h[k] = [] }
        edges.each { |u, v| neighbors[u] << v; neighbors[v] << u }
        neighbors.each { |v, list| list.sort_by! { |w| Math.atan2(points[w][1] - points[v][1], points[w][0] - points[v][0]) } }
        component = component_ids(neighbors)
        visited = {}
        cycles = []
        neighbors.each do |u, list|
          list.each do |v|
            next if visited[[u, v]]
            ring = []
            a = u
            b = v
            until visited[[a, b]]
              visited[[a, b]] = true
              ring << a
              around = neighbors[b]
              c = around[(around.index(a) - 1) % around.size] # rẽ trái nhất: giữ mặt bên trái
              a = b
              b = c
            end
            cycles << {ring: ring, area: signed_area(ring.map { |i| points[i] }), component: component[u]}
          end
        end
        cycles
      end

      def self.component_ids(neighbors)
        ids = {}
        next_id = 0
        neighbors.each_key do |start|
          next if ids.key?(start)
          stack = [start]
          ids[start] = next_id
          until stack.empty?
            v = stack.pop
            neighbors[v].each { |w| (ids[w] = next_id; stack << w) unless ids.key?(w) }
          end
          next_id += 1
        end
        ids
      end

      def self.signed_area(ring)
        sum = 0.0
        ring.each_with_index { |p, i| q = ring[(i + 1) % ring.size]; sum += p[0] * q[1] - q[0] * p[1] }
        sum / 2.0
      end

      # ---- Phân loại vùng ----

      def self.classify(points, cycles, min_width)
        inner = cycles.select { |c| c[:area] > 0 }
        outer = cycles.select { |c| c[:area] < 0 }
        holes_of = Hash.new { |h, k| h[k] = [] }
        outer.each do |cycle|
          probe = points[cycle[:ring].first]
          host = inner.select { |face| face[:component] != cycle[:component] && inside_ring?(face[:ring].map { |i| points[i] }, probe) }.min_by { |face| face[:area] }
          holes_of[host.object_id] << cycle[:ring].reverse.map { |i| points[i] } if host
        end
        regions = []
        dropped = []
        inner.each do |face|
          boundary = simplify(face[:ring].map { |i| points[i] })
          holes = holes_of[face.object_id].map { |ring| simplify(ring) }.select { |ring| ring.size >= 3 }
          area = signed_area(boundary) - holes.sum { |ring| signed_area(ring).abs }
          width = region_width(boundary, holes, area)
          center = centroid(boundary)
          info = {boundary: boundary, holes: holes, area: area, width: width, center: center, sig: signature(center, area)}
          kind, reason = reject_reason(info, min_width)
          kind ? dropped << info.merge(kind: kind, reason: reason) : regions << info
        end
        order = ->(item) { [item[:boundary].map(&:first).min.round(-1), item[:boundary].map(&:last).min.round(-1)] }
        [regions.sort_by(&order), dropped.sort_by(&order)]
      end

      # Dấu nhận dạng một vùng giữa hai lần dò (xem trước rồi tạo): tâm làm tròn 10 mm và diện tích làm tròn cm2.
      def self.signature(center, area)
        "#{center[0].round(-1).to_i}:#{center[1].round(-1).to_i}:#{(area / 10_000.0).round}"
      end

      # Trả về [loại, lời giải thích] nếu vùng không dùng được làm phòng, nil nếu dùng được. Loại: :small, :thin, :invalid.
      def self.reject_reason(info, min_width)
        return [:invalid, 'viền không hợp lệ (ít hơn 3 điểm)'] if info[:boundary].size < 3
        return [:small, "diện tích quá nhỏ (#{(info[:area] / 1.0e6).round(2)} m²)"] if info[:area] < MIN_AREA
        return [:thin, "bề rộng #{info[:width].round} mm nhỏ hơn ngưỡng #{min_width.round} mm (coi là ruột tường)"] if info[:width] < min_width
        return [:invalid, "viền nhiều hơn #{Rooms::MAX_POINTS} điểm (tường cong nhiều đoạn)"] if info[:boundary].size > Rooms::MAX_POINTS
        Rooms.holes!(info[:holes], Rooms.boundary!(info[:boundary], 'vùng dò'), 'vùng dò')
        nil
      rescue ArgumentError => error
        [:invalid, error.message.sub(/\AGiá trị (viền|lỗ) của vùng dò không hợp lệ: /, 'viền hoặc lỗ không hợp lệ: ')]
      end

      # Bỏ điểm trùng và điểm thẳng hàng thừa (cách đường nối hai điểm kề dưới TOLERANCE).
      def self.simplify(ring)
        pts = ring.dup
        changed = true
        while changed && pts.size > 2
          changed = false
          pts.each_index do |i|
            a = pts[i - 1]
            b = pts[i]
            c = pts[(i + 1) % pts.size]
            span = Math.hypot(c[0] - a[0], c[1] - a[1])
            dist = span < TOLERANCE ? Math.hypot(b[0] - a[0], b[1] - a[1]) : ((c[0] - a[0]) * (a[1] - b[1]) - (a[0] - b[0]) * (c[1] - a[1])).abs / span
            next unless dist <= TOLERANCE * 0.5
            pts.delete_at(i)
            changed = true
            break
          end
        end
        pts
      end

      def self.centroid(ring)
        area = signed_area(ring)
        return [ring.sum { |p| p[0] } / ring.size, ring.sum { |p| p[1] } / ring.size] if area.abs < 1.0e-6
        cx = 0.0
        cy = 0.0
        ring.each_with_index { |p, i| q = ring[(i + 1) % ring.size]; w = p[0] * q[1] - q[0] * p[1]; cx += (p[0] + q[0]) * w; cy += (p[1] + q[1]) * w }
        [cx / (6 * area), cy / (6 * area)]
      end

      def self.inside_ring?(ring, point)
        x, y = point
        inside = false
        ring.each_index do |i|
          a = ring[i]
          b = ring[(i + 1) % ring.size]
          next unless (a[1] > y) != (b[1] > y)
          inside = !inside if x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]
        end
        inside
      end

      # Bao lồi (monotone chain).
      def self.hull(ring)
        pts = ring.uniq.sort
        return pts if pts.size < 3
        cross = ->(o, a, b) { (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]) }
        lower = pts.each_with_object([]) { |p, h| h.pop while h.size >= 2 && cross.call(h[-2], h[-1], p) <= 0; h << p }
        upper = pts.reverse.each_with_object([]) { |p, h| h.pop while h.size >= 2 && cross.call(h[-2], h[-1], p) <= 0; h << p }
        lower[0...-1] + upper[0...-1]
      end

      # Bề rộng của một vùng: bao lồi của viền ngoài; vùng có lỗ (vành giữa hai lớp tường lồng nhau) lấy thêm độ dày trung bình
      # 2 x diện tích / tổng chu vi, nhỏ hơn thì dùng giá trị đó (vành tường dày 200 quanh phòng 4 x 4 m ra khoảng 200 chứ không phải 4000).
      def self.region_width(boundary, holes, area)
        width = min_width_of(hull(boundary))
        return width if holes.empty?
        perimeter = [boundary, *holes].sum { |ring| ring.each_index.sum { |i| Math.hypot(ring[(i + 1) % ring.size][0] - ring[i][0], ring[(i + 1) % ring.size][1] - ring[i][1]) } }
        [width, 2.0 * area / perimeter].min
      end

      # Bề rộng nhỏ nhất của một bao lồi: nhỏ nhất, theo từng cạnh, của khoảng cách xa nhất từ các đỉnh tới đường thẳng chứa cạnh.
      def self.min_width_of(hull_points)
        return 0.0 if hull_points.size < 3
        hull_points.each_index.map do |i|
          a = hull_points[i]
          b = hull_points[(i + 1) % hull_points.size]
          len = Math.hypot(b[0] - a[0], b[1] - a[1])
          next Float::INFINITY if len < TOLERANCE
          hull_points.map { |p| ((b[0] - a[0]) * (a[1] - p[1]) - (a[0] - p[0]) * (b[1] - a[1])).abs / len }.max
        end.min
      end
    end
  end
end
