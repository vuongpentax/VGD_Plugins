module VGD
  module Structure
    # Nối góc tường (cột mốc 9): đầu tường chạm tường khác thì khít góc, không hở, không chồng khối (khối lượng khỏi tính đôi). Logic thuần, đơn vị mm.
    #  - Góc L (hai đầu tường gặp nhau): một tường CHẠY SUỐT tới mặt ngoài của tường kia, tường kia DỪNG Ở MẶT tường chạy suốt. Tường chạy suốt: tường ngang (dir 'x')
    #    nếu chỉ một trong hai là tường ngang, không thì tường dài hơn (bằng nhau thì theo thứ tự mục).
    #  - Góc T (đầu tường chạm thân tường khác): đầu tường dừng ở mặt gần của tường kia.
    #  - Đầu tường đã chạm mặt cột thì giữ nguyên. Tường tắt nối (`join: false`) không bị đổi và không làm đối tác của tường khác.
    #  - Đầu cắt vuông góc với trục (tường xiên chưa cắt vát theo phân giác).
    # Mục tường đổi: start / finish / length / min / max (tường xiên: a, b, poly); `join_shift` là mức đầu tường dịch dọc theo tường (mm), để cửa đặt theo đầu tường cũ
    # vẫn đứng đúng chỗ thật; `joined` liệt kê các đầu đã nối (:start, :finish).
    module WallJoins
      PARALLEL = 0.1  # |sin| của góc giữa hai tường nhỏ hơn mức này thì coi là song song, không nối
      TOUCH = 1.0     # mm: sai số khi coi hai điểm chạm nhau

      def self.apply(items, columns = [])
        geos = items.select { |i| i[:join] != false }.map { |i| geo(i) }
        boxes = columns.map { |c| ColumnPlan.box(c) }
        ends = geos.flat_map { |g| %i[p q].map { |w| [g, w] } }.reject do |g, w|
          e = g[w]
          boxes.any? { |(x0, y0), (x1, y1)| e[0] >= x0 - TOUCH && e[0] <= x1 + TOUCH && e[1] >= y0 - TOUCH && e[1] <= y1 + TOUCH } # đã chạm mặt cột: giữ nguyên
        end
        moves = {}
        grouped = {}
        clusters(ends).each do |cl|
          cl.each { |g, w| grouped[[g, w]] = true }
          if cl.size == 2
            (g, w), (o, ow) = cl
            next if cross(g[:u], o[:u]).abs < PARALLEL # hai tường nối tiếp thẳng hàng: không đổi
            run, rw, butt, bw = runner_first?(g, o) ? [g, w, o, ow] : [o, ow, g, w]
            ends2 = corner(run, rw, butt, bw) or next
            moves[[run, rw]] = ends2[0]
            moves[[butt, bw]] = ends2[1]
          else # ba đầu trở lên gặp nhau: cặp thẳng hàng là tường chạy qua, các đầu còn lại dừng ở mặt của nó
            pair = cl.combination(2).find { |a, b| a[0] != b[0] && cross(a[0][:u], b[0][:u]).abs < PARALLEL } or next
            through = pair[0][0]
            cl.each do |g, w|
              next if pair.any? { |pg, _| pg.equal?(g) } || cross(g[:u], through[:u]).abs < PARALLEL
              moves[[g, w]] = face_hit(g, w, through)
            end
          end
        end
        ends.each do |g, w| # đầu chạm thân tường khác (góc T)
          next if grouped[[g, w]]
          o = body_partner(g, w, geos) or next
          moves[[g, w]] = face_hit(g, w, o)
        end
        moves.group_by { |(g, _), _| g }.each { |g, list| reshape(g, list.to_h { |(_, w), pt| [w, pt] }) }
        items
      end

      # Nhóm các đầu tường của các tường KHÁC NHAU nằm sát nhau (cách nhau không quá tổng nửa bề dày + sai số).
      def self.clusters(ends)
        parent = (0...ends.size).to_a
        find = ->(i) { parent[i] == i ? i : (parent[i] = find.call(parent[i])) }
        ends.each_with_index do |(g, w), i|
          ends.each_with_index do |(o, ow), j|
            next if j <= i || o.equal?(g)
            parent[find.call(i)] = find.call(j) if dist(g[w], o[ow]) <= g[:h] + o[:h] + TOUCH
          end
        end
        ends.each_index.group_by { |i| find.call(i) }.values.map { |ids| ids.map { |i| ends[i] } }.select { |cl| cl.size >= 2 && cl.map(&:first).uniq.size == cl.size }
      end

      def self.geo(item)
        p, q = case item[:dir]
               when 'x' then [[item[:start], item[:center]], [item[:finish], item[:center]]]
               when 'y' then [[item[:center], item[:start]], [item[:center], item[:finish]]]
               else [item[:a], item[:b]]
               end
        len = Math.hypot(q[0] - p[0], q[1] - p[1])
        {item: item, p: p, q: q, u: [(q[0] - p[0]) / len, (q[1] - p[1]) / len], h: item[:t] / 2.0, len: len}
      end

      def self.cross(a, b)
        a[0] * b[1] - a[1] * b[0]
      end

      def self.dist(a, b)
        Math.hypot(a[0] - b[0], a[1] - b[1])
      end

      # Tường mà thân của nó bị đầu (g, w) chạm vào (góc T): gần nhất, không song song, đầu nằm giữa hai đầu của tường đó.
      def self.body_partner(g, w, geos)
        e = g[w]
        best = nil
        geos.each do |o|
          next if o.equal?(g) || cross(g[:u], o[:u]).abs < PARALLEL
          along = (e[0] - o[:p][0]) * o[:u][0] + (e[1] - o[:p][1]) * o[:u][1]
          off = ((e[0] - o[:p][0]) * -o[:u][1] + (e[1] - o[:p][1]) * o[:u][0]).abs
          best = [off, o] if along > TOUCH && along < o[:len] - TOUCH && off <= o[:h] + TOUCH && (!best || off < best[0])
        end
        best && best[1]
      end

      def self.runner_first?(a, b)
        ax = a[:item][:dir] == 'x'
        bx = b[:item][:dir] == 'x'
        return ax if ax != bx
        return a[:len] > b[:len] if (a[:len] - b[:len]).abs > TOUCH
        a[:item][:ref].to_s <= b[:item][:ref].to_s
      end

      # Giao điểm của hai đường thẳng (điểm + hướng); nil nếu song song.
      def self.meet(p1, d1, p2, d2)
        den = cross(d1, d2)
        return nil if den.abs < 1e-9
        t = cross([p2[0] - p1[0], p2[1] - p1[1]], d2) / den
        [p1[0] + d1[0] * t, p1[1] + d1[1] * t]
      end

      # Điểm đầu tường g (đầu w) sau khi dừng ở mặt gần của tường o: giao của trục g với đường mặt của o phía thân g.
      def self.face_hit(g, w, o)
        far = g[w == :p ? :q : :p]
        side = cross(o[:u], [far[0] - o[:p][0], far[1] - o[:p][1]]) >= 0 ? 1.0 : -1.0
        face = [o[:p][0] + -o[:u][1] * o[:h] * side, o[:p][1] + o[:u][0] * o[:h] * side]
        meet(g[:p], g[:u], face, o[:u])
      end

      # Góc L: [đầu mới của tường chạy suốt, đầu mới của tường dừng ở mặt]; nil nếu hai trục không cắt nhau.
      def self.corner(run, rw, butt, bw)
        c = meet(run[:p], run[:u], butt[:p], butt[:u]) or return nil
        d_run = rw == :p ? [-run[:u][0], -run[:u][1]] : run[:u]   # hướng ra khỏi thân tường
        d_butt = bw == :p ? [-butt[:u][0], -butt[:u][1]] : butt[:u]
        perp = ->(u, away) { n = [-u[1], u[0]]; (n[0] * away[0] + n[1] * away[1]) <= 0 ? n : [-n[0], -n[1]] } # pháp tuyến quay ra xa hướng `away`
        n_run = perp.call(run[:u], [-d_butt[0], -d_butt[1]])    # mặt ngoài của tường chạy suốt: phía không có thân tường dừng
        n_butt = perp.call(butt[:u], [-d_run[0], -d_run[1]])
        outer = meet([c[0] + n_run[0] * run[:h], c[1] + n_run[1] * run[:h]], run[:u], [c[0] + n_butt[0] * butt[:h], c[1] + n_butt[1] * butt[:h]], butt[:u]) or return nil
        e = (outer[0] - c[0]) * d_run[0] + (outer[1] - c[1]) * d_run[1]
        run_end = [c[0] + d_run[0] * e, c[1] + d_run[1] * e]
        face = [c[0] - n_run[0] * run[:h], c[1] - n_run[1] * run[:h]]
        butt_end = meet(butt[:p], butt[:u], face, run[:u]) or return nil
        [run_end, butt_end]
      end

      # Ghi đầu mới vào mục kế hoạch (cập nhật cả hình, hộp bao, đa giác).
      def self.reshape(g, ends)
        item = g[:item]
        np = ends[:p] || g[:p]
        nq = ends[:q] || g[:q]
        shift = ((np[0] - g[:p][0]) * g[:u][0] + (np[1] - g[:p][1]) * g[:u][1]).round(2)
        case item[:dir]
        when 'x'
          item[:start] = np[0].round(2)
          item[:finish] = nq[0].round(2)
          item[:min] = [item[:start], item[:min][1]]
          item[:max] = [item[:finish], item[:max][1]]
        when 'y'
          item[:start] = np[1].round(2)
          item[:finish] = nq[1].round(2)
          item[:min] = [item[:min][0], item[:start]]
          item[:max] = [item[:max][0], item[:finish]]
        else
          item[:a] = np.map { |v| v.round(2) }
          item[:b] = nq.map { |v| v.round(2) }
          item[:poly] = Geometry.round_poly(Geometry.strip(item[:a], item[:b], item[:t]))
          item[:min], item[:max] = Geometry.bounds(item[:poly])
          item[:finish] = Math.hypot(item[:b][0] - item[:a][0], item[:b][1] - item[:a][1]).round(2)
        end
        item[:length] = item[:dir] == 'o' ? item[:finish] : (item[:finish] - item[:start]).round(2)
        item[:join_shift] = shift
        item[:joined] = ends.keys.map { |w| w == :p ? :start : :finish }
      end
    end
  end
end
