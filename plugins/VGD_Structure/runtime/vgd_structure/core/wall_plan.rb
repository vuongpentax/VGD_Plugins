module VGD
  module Structure
    # Kế hoạch tường của một tầng (đặc tả: SPEC mục 4 và 5). Logic thuần. Bản đầu: tường đặc, chưa khoét cửa, chưa nối L / T.
    # - Tường dọc nhịp, hai đầu dừng ở MẶT CỘT (cột được chọn ở nút đó); nút không có cột: tường X tới trục, tường Y dừng ở mặt tường X chạm nút.
    # - Cao từ mặt sàn tầng này (`Ei`) lên ĐÁY DẦM của nhịp đó nếu nhịp có dầm được chọn cùng tầng, không thì lên đáy sàn tầng trên.
    # - Vị trí ngang: tường trên trục biên có mặt ngoài tiếp giáp trục biên (dày vào trong), tường nhịp giữa tâm trên trục.
    module WallPlan
      EPS = 1e-6
      MIN_LENGTH = 100.0
      MIN_HEIGHT = 100.0

      Error = Class.new(ArgumentError)

      MIN_OPENING_GAP = 50.0 # khoảng hở tối thiểu giữa hai cửa liền nhau trên một tường

      def self.plan(grid, types, beam_types, wall_types, levels, level_id, opening_types = OpeningTypes.default)
        level = Levels.find(levels, level_id) or raise Error, 'Tầng không tồn tại.'
        above = Levels.next_of(levels, level_id)
        raise Error, "Tầng “#{level['name']}” là tầng trên cùng, chỉ có sàn nên không có tường." unless above
        column_plan = ColumnPlan.plan(grid, types, levels, level_id)
        beams = level['picks']['beams'].empty? ? {} : BeamPlan.plan(grid, types, beam_types, levels, level_id)[:items].each_with_object({}) { |b, h| h[b[:ref]] = b }
        z0 = column_plan[:z0]               # tường đặt trên sàn kết cấu
        z_slab = column_plan[:slab_bottom]  # không có dầm thì tường lên đáy sàn tầng trên
        default_type = WallTypes.find(wall_types, level['wall_type']) || wall_types.first
        spans = Grid.spans(grid).each_with_object({}) { |sp, h| h[sp[:ref]] = sp }
        columns = column_plan[:items].each_with_object({}) { |c, h| h[c[:ref]] = c }
        walls = spans.each_with_object([]) do |(ref, span), out|
          pick = level['picks']['walls'][ref] or next
          type = pick['type'] ? WallTypes.find(wall_types, pick['type']) : default_type
          mode = BeamPlan.mode(pick['p'], span[:side])
          axis = span[:dir] == 'x' ? span[:from][1] : span[:from][0]
          center = case mode
                   when 'min' then axis + type['t'] / 2.0
                   when 'max' then axis - type['t'] / 2.0
                   else axis
                   end
          out << {ref: ref, span: span, type: type, mode: mode, center: center.round(2), w: type['t'], join: pick['join'] != false, under_beam: beams.key?(ref), z_top: beams.key?(ref) ? beams[ref][:z_bottom] : z_slab}
        end
        x_walls_at = Hash.new { |h, k| h[k] = [] }
        walls.select { |w| w[:span][:dir] == 'x' }.each { |w| [w[:span][:from_ref], w[:span][:to_ref]].each { |n| x_walls_at[n] << w } }
        items = []
        issues = []
        walls.each do |w|
          span = w[:span]
          dir = span[:dir]
          a = dir == 'x' ? span[:from][0] : span[:from][1]
          z = dir == 'x' ? span[:to][0] : span[:to][1]
          start = BeamPlan.end_of(span[:from_ref], dir, true, a, columns, x_walls_at)
          finish = BeamPlan.end_of(span[:to_ref], dir, false, z, columns, x_walls_at)
          length = (finish - start).round(2)
          height = (w[:z_top] - z0).round(1)
          if length < MIN_LENGTH
            issues << "Tường #{w[:ref]}: khoảng hở giữa hai đầu chỉ #{length} mm, bỏ qua."
            next
          end
          if height < MIN_HEIGHT
            issues << "Tường #{w[:ref]}: chiều cao chỉ #{height} mm (dầm quá thấp), bỏ qua."
            next
          end
          min, max = dir == 'x' ? [[start, w[:center] - w[:w] / 2.0], [finish, w[:center] + w[:w] / 2.0]] : [[w[:center] - w[:w] / 2.0, start], [w[:center] + w[:w] / 2.0, finish]]
          items << {ref: w[:ref], dir: dir, type_id: w[:type]['id'], type_name: w[:type]['name'], t: w[:w], length: length, height: height, start: start.round(2), finish: finish.round(2),
                    center: w[:center], min: min.map { |v| v.round(2) }, max: max.map { |v| v.round(2) }, mode: w[:mode], placement: span[:placement], z_bottom: z0, z_top: w[:z_top], under_beam: w[:under_beam], join: w[:join]}
        end
        # Tường TỰ DO (ngang hoặc dọc): đầu mút đúng tọa độ nhập; cao tới đáy dầm nào nằm trên tường (cùng tim, chồng lên) hoặc tới đáy sàn tầng trên.
        beam_items = level['picks']['beams'].empty? ? [] : BeamPlan.plan(grid, types, beam_types, levels, level_id)[:items]
        level['picks']['walls'].each do |ref, pick|
          free = pick['free'] or next
          type = pick['type'] ? WallTypes.find(wall_types, pick['type']) : default_type
          item = BeamPlan.free_item(ref, free, type['t'], type, z_slab, z0, :t)
          cover = beam_items.select { |b| BeamPlan.covers?(b, item) }
          z_top = cover.empty? ? z_slab : cover.map { |b| b[:z_bottom] }.min
          height = (z_top - z0).round(1)
          if item[:length] < MIN_LENGTH
            issues << "Tường #{ref}: dài chỉ #{item[:length]} mm, bỏ qua."
            next
          end
          if height < MIN_HEIGHT
            issues << "Tường #{ref}: chiều cao chỉ #{height} mm (dầm quá thấp), bỏ qua."
            next
          end
          items << item.merge(height: height, z_top: z_top, under_beam: !cover.empty?, join: pick['join'] != false)
        end
        items.each do |item| # lớp cấu tạo của loại (nil nếu tường đặc đơn giản)
          layers = WallTypes.layers_for(WallTypes.find(wall_types, item[:type_id]))
          item[:layers] = layers if layers
        end
        WallJoins.apply(items, column_plan[:items])
        opening_issues = place_openings(level, items, opening_types)
        x0, y0, x1, y1 = Grid.bounds(grid)
        items.each do |i|
          next if i[:placement] == 'free'
          issues << "Tường #{i[:ref]} nhô ra ngoài khung lưới (tâm đặt trên trục biên)." if i[:min][0] < x0 - EPS || i[:max][0] > x1 + EPS || i[:min][1] < y0 - EPS || i[:max][1] > y1 + EPS
        end
        boxes = items.map { |i| [i[:min], i[:max], i] }
        BeamPlan.overlaps(boxes).each { |a, c| issues << "Tường #{a[:ref]} và #{c[:ref]} chồng lên nhau." }
        column_plan[:items].each do |c|
          cb = ColumnPlan.box(c) + [c]
          boxes.each { |wb| issues << "Tường #{wb[2][:ref]} chồng lên cột #{c[:ref]}." if BeamPlan.rects_overlap?(wb, cb) }
        end
        {level: level, next_level: above, z0: z0, z_slab: z_slab, items: items, issues: issues, opening_issues: opening_issues}
      end

      # Đặt cửa lên tường: mỗi cửa nằm trọn trong chiều dài và chiều cao tường, không chồng cửa khác; cửa sai thì bỏ và báo. Tính theo hệ trục của tường:
      # x từ đầu tường (mặt cột hoặc trục ở đầu đó), z từ mặt sàn tầng. Gán item[:openings] (cửa hợp lệ, sắp theo vị trí) và item[:openings_area] (m²).
      def self.place_openings(level, items, opening_types)
        issues = []
        by_wall = items.each_with_object({}) { |i, h| h[i[:ref]] = i }
        level['picks']['openings'].each { |id, e| issues << "Cửa #{id}: tường #{e['wall']} chưa được chọn hoặc bị bỏ qua, nên cửa không được dựng." unless by_wall.key?(e['wall']) }
        items.each do |item|
          list = level['picks']['openings'].select { |_id, e| e['wall'] == item[:ref] }.map { |id, e| [id, e, OpeningTypes.find(opening_types, e['type'])] }.sort_by { |_id, e, _t| [e['pos'], e['type'].to_s] }
          valid = []
          list.each do |id, e, type|
            unless type
              issues << "Cửa #{id} trên tường #{item[:ref]}: loại cửa không tồn tại, bỏ qua."
              next
            end
            shift = item[:join_shift] || 0.0 # đầu tường đã dịch do nối góc: vị trí cửa tính từ đầu tường cũ
            x0 = e['pos'] - type['w'] / 2.0 - shift
            x1 = e['pos'] + type['w'] / 2.0 - shift
            z0 = type['sill'] + level['screed'] # cao ngưỡng tính từ cốt sàn HOÀN THIỆN; tường tính từ sàn kết cấu thấp hơn `screed`
            z1 = z0 + type['h']
            label = "Cửa #{type['name']} (#{id}) trên tường #{item[:ref]}"
            if x0 < -EPS || x1 > item[:length] + EPS
              issues << "#{label}: vượt ra ngoài chiều dài tường (#{item[:length]} mm), bỏ qua."
            elsif z1 > item[:height] + EPS
              issues << "#{label}: cao #{z1.round} mm (tính cả cao ngưỡng) hơn tường (#{item[:height]} mm), bỏ qua."
            elsif valid.last && x0 < valid.last[:x1] + MIN_OPENING_GAP - EPS
              issues << "#{label}: chồng hoặc sát cửa #{valid.last[:id]} (cần cách nhau ít nhất #{MIN_OPENING_GAP.to_i} mm), bỏ qua."
            else
              valid << {id: id, kind: type['kind'], type_id: type['id'], type_name: type['name'], w: type['w'], h: type['h'], sill: type['sill'], pos: e['pos'], flip: e['flip'], x0: x0.round(2), x1: x1.round(2), z0: z0, z1: z1.round(2)}
            end
          end
          item[:openings] = valid
          item[:openings_area] = valid.sum { |o| o[:w] * o[:h] / 1_000_000.0 }.round(4)
        end
        issues
      end
    end
  end
end
