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

      def self.plan(grid, types, beam_types, wall_types, levels, level_id)
        level = Levels.find(levels, level_id) or raise Error, 'Tầng không tồn tại.'
        above = Levels.next_of(levels, level_id)
        raise Error, "Tầng “#{level['name']}” là tầng trên cùng, chỉ có sàn nên không có tường." unless above
        column_plan = ColumnPlan.plan(grid, types, levels, level_id)
        beams = level['picks']['beams'].empty? ? {} : BeamPlan.plan(grid, types, beam_types, levels, level_id)[:items].each_with_object({}) { |b, h| h[b[:ref]] = b }
        z0 = level['elevation']
        z_slab = column_plan[:z1]
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
          out << {ref: ref, span: span, type: type, mode: mode, center: center.round(2), w: type['t'], under_beam: beams.key?(ref), z_top: beams.key?(ref) ? beams[ref][:z_bottom] : z_slab}
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
                    center: w[:center], min: min.map { |v| v.round(2) }, max: max.map { |v| v.round(2) }, mode: w[:mode], placement: span[:placement], z_bottom: z0, z_top: w[:z_top], under_beam: w[:under_beam]}
        end
        x0, y0, x1, y1 = Grid.bounds(grid)
        items.each do |i|
          issues << "Tường #{i[:ref]} nhô ra ngoài khung lưới (tâm đặt trên trục biên)." if i[:min][0] < x0 - EPS || i[:max][0] > x1 + EPS || i[:min][1] < y0 - EPS || i[:max][1] > y1 + EPS
        end
        boxes = items.map { |i| [i[:min], i[:max], i] }
        BeamPlan.overlaps(boxes).each { |a, c| issues << "Tường #{a[:ref]} và #{c[:ref]} chồng lên nhau." }
        column_plan[:items].each do |c|
          cb = [[c[:center][0] - c[:w] / 2.0, c[:center][1] - c[:d] / 2.0], [c[:center][0] + c[:w] / 2.0, c[:center][1] + c[:d] / 2.0]]
          boxes.each { |wb| issues << "Tường #{wb[2][:ref]} chồng lên cột #{c[:ref]}." if BeamPlan.rects_overlap?(wb, cb) }
        end
        {level: level, next_level: above, z0: z0, z_slab: z_slab, items: items, issues: issues}
      end
    end
  end
end
