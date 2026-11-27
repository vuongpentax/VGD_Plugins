module VGD
  module Structure
    # Kế hoạch đế móng của một tầng (tầng móng có `footing`): mỗi cột của tầng (theo ColumnPlan, cả cột tự do / xoay) có một đế
    # hình hộp ngay dưới chân cột: đỉnh đế = chân cột (z0 của cột), dày `h` xuống dưới, tâm trùng tâm cột, dài `l` theo trục x riêng của cột,
    # rộng `w` theo trục y riêng (cột xoay 90 độ thì đổi chỗ, cột xoay góc khác thì đế xoay cùng góc). Logic thuần.
    # Mục kế hoạch có cùng trường hình học với cột (center, w, d, rot, poly) để dùng lại ColumnPlan.box / overlaps và Placement.
    # H4: kích thước theo loại móng gán cho cột (`types` / `assign`), giật cấp (`step`: bậc trên là mục riêng mã '<cột>:b2' đặt trên bậc dưới,
    # hai khối chồng theo phương đứng, không trùng thể tích), móng băng (`strip`) dưới tường thẳng trục của tầng (mã '<tường>:s<n>').
    # `kind` của mục: 'pad' (đế / bậc dưới), 'step' (bậc trên), 'strip' (đoạn móng băng).
    module FootingPlan
      Error = Class.new(ArgumentError)
      MIN_STRIP = 50.0 # đoạn móng băng ngắn hơn (sau khi trừ đế cột) thì bỏ
      EPS = 1e-6

      def self.plan(grid, types, levels, level_id, beam_types = BeamTypes.default, wall_types = WallTypes.default, opening_types = OpeningTypes.default)
        level = Levels.find(levels, level_id) or raise Error, 'Tầng không tồn tại.'
        footing = level['footing']
        free = level['free_footings'] || {}
        raise Error, "Tầng “#{level['name']}” chưa khai báo móng." if footing.nil? && free.empty?
        columns = ColumnPlan.plan(grid, types, levels, level_id)
        z_top = columns[:z0]
        named = ((footing || {})['types'] || []).each_with_object({}) { |t, h| h[t['name']] = t }
        assign = (footing || {})['assign'] || {}
        issues = []
        refs = columns[:items].map { |c| c[:ref] }
        assign.each { |ref, name| issues << "Móng loại “#{name}” gán cho cột #{ref} nhưng cột này không còn: bỏ qua." unless refs.include?(ref) }
        pads = []
        steps = []
        (footing ? columns[:items] : []).each do |col|
          spec = named[assign[col[:ref]]] || footing
          step = spec['step']
          step_h = step ? step['h'] : 0.0
          pad = block(level, col, col[:ref], spec['l'], spec['w'], spec['h'], z_top - step_h, 'pad')
          pad[:type_name] = spec['name'] if spec['name']
          pads << pad
          steps << block(level, col, "#{col[:ref]}:b2", step['l'], step['w'], step['h'], z_top, 'step') if step
          top = step ? steps.last : pad
          issues << "Móng #{col[:ref]} #{step ? '(bậc trên) ' : ''}nhỏ hơn tiết diện cột (#{col[:w].round}x#{col[:d].round} mm)." if top[:w] < top[:column_w] || top[:d] < top[:column_d]
        end
        free_pads, free_strips = free_items(free, z_top)
        ColumnPlan.overlaps(pads + free_pads).each { |a, b| issues << "Móng #{a[:ref]} và #{b[:ref]} chồng lên nhau: nên gộp thành móng chung hoặc giảm kích thước." }
        strips = []
        if footing && footing['strip']
          walls = WallPlan.plan(grid, types, beam_types, wall_types, levels, level_id, opening_types)[:items]
          issues << "Móng băng: tầng “#{level['name']}” chưa có tường nào nên chưa có đế băng." if walls.empty?
          strips = strip_items(walls, pads, footing['strip'], z_top, issues)
        end
        h = footing ? footing['h'] + (footing['step'] ? footing['step']['h'] : 0.0) : 0.0
        h = ([h] + (free_pads + free_strips).map { |i| i[:h] }).max
        {level: level, z_top: z_top, h: h, items: pads + steps + strips + free_pads + free_strips, issues: issues}
      end

      # Móng vẽ tự do (level['free_footings']): đỉnh móng = chân cột của tầng (z_top). Móng đơn quanh tâm (x, y), xoay 90 độ đổi chỗ dài / rộng, góc khác thì đế xoay theo.
      # Móng băng theo đường tim a-b: ngang / dọc như đoạn băng dưới tường, xiên thì xoay quanh tâm đoạn. Trả về [móng đơn, móng băng].
      def self.free_items(free, z_top)
        pads = []
        strips = []
        free.each do |id, f|
          if f['kind'] == 'pad'
            rot = f['rot'].to_f
            rot90 = (rot % 180) == 90
            bw, bd = rot90 ? [f['w'], f['l']] : [f['l'], f['w']]
            item = {ref: id, kind: 'pad', free: true, center: [f['x'], f['y']], w: bw, d: bd, h: f['h'], z0: (z_top - f['h']).round(1), z1: z_top.round(1), placement: 'free'}
            item.merge!(rot: rot, poly: Geometry.round_poly(Geometry.rotated_rect(item[:center], bw, bd, rot))) if rot != 0 && !rot90
            pads << item
          else
            a, b = f['a'], f['b']
            length = Math.hypot(b[0] - a[0], b[1] - a[1])
            center = [((a[0] + b[0]) / 2.0).round(2), ((a[1] + b[1]) / 2.0).round(2)]
            along = a[1] == b[1] ? 'x' : a[0] == b[0] ? 'y' : 'o'
            bw, bd = along == 'y' ? [f['w'], length.round(2)] : [length.round(2), f['w']]
            item = {ref: id, kind: 'strip', free: true, along: along, center: center, w: bw, d: bd, h: f['h'], width: f['w'], length: length.round(2), z0: (z_top - f['h']).round(1), z1: z_top.round(1), placement: 'free', a: a, b: b}
            if along == 'o'
              rot = Geometry.angle(a, b).round(4)
              item.merge!(rot: rot, poly: Geometry.round_poly(Geometry.rotated_rect(center, bw, bd, rot)))
            end
            strips << item
          end
        end
        [pads, strips]
      end

      # Một khối đế dưới cột `col`: dài l theo trục x riêng của cột, rộng w theo trục y riêng, đỉnh tại z1, dày h.
      def self.block(level, col, ref, l, w, h, z1, kind)
        rot = col[:rot]
        swapped = !rot && col[:placement] == 'free' && ((level['picks']['columns'][col[:ref]]['free']['rot'] || 0) % 180) == 90
        bw, bd = swapped ? [w, l] : [l, w]
        item = {ref: ref, kind: kind, column: col[:ref], center: col[:center], w: bw, d: bd, h: h, z0: (z1 - h).round(1), z1: z1.round(1), column_w: col[:w], column_d: col[:d], placement: col[:placement]}
        item.merge!(rot: rot, poly: Geometry.round_poly(Geometry.rotated_rect(col[:center], bw, bd, rot))) if rot
        item
      end

      # Móng băng dưới tường ngang / dọc: dải rộng `w` theo trục tường, dài bằng tường cộng (w - dày tường) / 2 mỗi đầu (để băng hai tường gặp góc khép kín),
      # rồi TRỪ phần nằm trong hộp bao của đế cột và của đoạn băng đã lập trước (tường X trước, Y sau) nên không có hai khối chồng thể tích.
      # Trừ theo cả bề ngang dải (đơn giản, an toàn): đế hẹp hơn dải thì để hở một ít bên cạnh đế. Tường xiên chưa hỗ trợ (cảnh báo).
      def self.strip_items(walls, pads, strip, z_top, issues)
        sw = strip['w']
        obstacles = pads.map { |p| ColumnPlan.box(p) }
        out = []
        xs, others = walls.partition { |w| w[:dir] == 'x' }
        (xs + others).each do |wall|
          if wall[:dir] == 'o'
            issues << "Móng băng: tường xiên #{wall[:ref]} chưa hỗ trợ, bỏ qua."
            next
          end
          issues << "Móng băng hẹp hơn tường #{wall[:ref]} (dày #{wall[:t].round} mm)." if sw < wall[:t]
          along = wall[:dir] == 'x' ? 0 : 1
          across = 1 - along
          ext = [(sw - wall[:t]) / 2.0, 0.0].max
          mid = (wall[:min][across] + wall[:max][across]) / 2.0
          lo_c, hi_c = mid - sw / 2.0, mid + sw / 2.0
          intervals = [[wall[:min][along] - ext, wall[:max][along] + ext]]
          obstacles.each do |(min, max)|
            next unless min[across] < hi_c - EPS && lo_c < max[across] - EPS
            intervals = intervals.flat_map { |a, b| [[a, [b, min[along]].min], [[a, max[along]].max, b]].select { |x, y| y - x > EPS } }
          end
          intervals.select { |a, b| b - a >= MIN_STRIP }.each_with_index do |(a, b), k|
            min = along.zero? ? [a, lo_c] : [lo_c, a]
            max = along.zero? ? [b, hi_c] : [hi_c, b]
            obstacles << [min, max]
            out << {ref: "#{wall[:ref]}:s#{k + 1}", kind: 'strip', wall: wall[:ref], along: wall[:dir], center: [((min[0] + max[0]) / 2.0).round(2), ((min[1] + max[1]) / 2.0).round(2)],
                    w: (max[0] - min[0]).round(2), d: (max[1] - min[1]).round(2), h: strip['h'], width: sw, length: (b - a).round(2),
                    z0: (z_top - strip['h']).round(1), z1: z_top.round(1), placement: wall[:placement]}
          end
        end
        out
      end
    end
  end
end
