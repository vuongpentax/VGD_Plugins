module VGD
  module Structure
    # Kế hoạch trần của một tầng (đặc tả: SPEC mục 5). Logic thuần. Trần là tấm mỏng trong ô, mặt dưới ở `Ei + ceiling_height`, dày `ceiling_thickness` lên trên.
    # - Cạnh ô có tường được chọn cùng tầng thì trần lùi tới MẶT TƯỜNG phía trong ô; cạnh không có tường thì tới trục.
    # - Góc ô có cột được chọn thì trần có KHOÉT GÓC theo mặt cột (đa giác chữ L / chữ U...), nên không chồng cột.
    # - Tầng trên cùng chỉ có sàn nên không có trần. Mặt trên trần phải thấp hơn đáy sàn tầng trên; chạm đáy dầm được cảnh báo.
    module CeilingPlan
      EPS = 1e-6
      MIN_SIZE = 100.0

      Error = Class.new(ArgumentError)

      def self.plan(grid, types, beam_types, wall_types, levels, level_id, opening_types = OpeningTypes.default)
        level = Levels.find(levels, level_id) or raise Error, 'Tầng không tồn tại.'
        above = Levels.next_of(levels, level_id)
        raise Error, "Tầng “#{level['name']}” là tầng trên cùng, chỉ có sàn nên không có trần." unless above
        column_plan = ColumnPlan.plan(grid, types, levels, level_id)
        z_bottom = (level['elevation'] + level['ceiling_height']).round(1)
        z_top = (z_bottom + level['ceiling_thickness']).round(1)
        raise Error, "Trần tầng “#{level['name']}” (mặt trên #{z_top} mm) cao hơn đáy sàn tầng trên (#{column_plan[:z1]} mm). Hãy giảm cao trần." if z_top > column_plan[:z1] + EPS
        walls = level['picks']['walls'].empty? ? {} : WallPlan.plan(grid, types, beam_types, wall_types, levels, level_id, opening_types)[:items].each_with_object({}) { |w, h| h[w[:ref]] = w }
        beams = level['picks']['beams'].empty? ? {} : BeamPlan.plan(grid, types, beam_types, levels, level_id)[:items]
        columns = column_plan[:items].each_with_object({}) { |c, h| h[c[:ref]] = c }
        cells = Grid.cells(grid).each_with_object({}) { |c, h| h[c[:ref]] = c }
        items = []
        issues = []
        cells.each do |ref, cell|
          level['picks']['ceilings'].key?(ref) or next
          x0, y0 = cell[:min]
          x1, y1 = cell[:max]
          wall = ->(span_ref) { walls[span_ref] }
          bottom = wall.call("x:#{cell[:ya]}:#{cell[:xa]}-#{cell[:xb]}")
          top = wall.call("x:#{cell[:yb]}:#{cell[:xa]}-#{cell[:xb]}")
          left = wall.call("y:#{cell[:xa]}:#{cell[:ya]}-#{cell[:yb]}")
          right = wall.call("y:#{cell[:xb]}:#{cell[:ya]}-#{cell[:yb]}")
          rx0 = left ? [x0, left[:max][0]].max : x0
          rx1 = right ? [x1, right[:min][0]].min : x1
          ry0 = bottom ? [y0, bottom[:max][1]].max : y0
          ry1 = top ? [y1, top[:min][1]].min : y1
          if rx1 - rx0 < MIN_SIZE || ry1 - ry0 < MIN_SIZE
            issues << "Trần ô #{ref}: khoảng hở giữa các tường nhỏ hơn #{MIN_SIZE.to_i} mm, bỏ qua."
            next
          end
          notch = lambda do |node, cx, cy|
            col = columns[node] or return nil
            cmin = [col[:center][0] - col[:w] / 2.0, col[:center][1] - col[:d] / 2.0]
            cmax = [col[:center][0] + col[:w] / 2.0, col[:center][1] + col[:d] / 2.0]
            return nil unless cmin[0] < cx + EPS && cx - EPS < cmax[0] && cmin[1] < cy + EPS && cy - EPS < cmax[1] # cột phải chứa góc của hình chữ nhật trần
            [cmax[0] - cx, cmax[1] - cy, cmin[0] - cx, cmin[1] - cy]
          end
          n_bl = notch.call("#{cell[:xa]}-#{cell[:ya]}", rx0, ry0)
          n_br = notch.call("#{cell[:xb]}-#{cell[:ya]}", rx1, ry0)
          n_tr = notch.call("#{cell[:xb]}-#{cell[:yb]}", rx1, ry1)
          n_tl = notch.call("#{cell[:xa]}-#{cell[:yb]}", rx0, ry1)
          sizes = {
            bl: n_bl && [[n_bl[0], 0].max, [n_bl[1], 0].max], br: n_br && [[-n_br[2], 0].max, [n_br[1], 0].max],
            tr: n_tr && [[-n_tr[2], 0].max, [-n_tr[3], 0].max], tl: n_tl && [[n_tl[0], 0].max, [-n_tl[3], 0].max]
          }
          sizes.each { |k, v| sizes[k] = nil if v && (v[0] <= EPS || v[1] <= EPS) }
          w = rx1 - rx0
          h = ry1 - ry0
          widths = ->(a, b) { (sizes[a]&.first || 0) + (sizes[b]&.first || 0) }
          heights = ->(a, b) { (sizes[a]&.last || 0) + (sizes[b]&.last || 0) }
          if widths.call(:bl, :br) >= w - EPS || widths.call(:tl, :tr) >= w - EPS || heights.call(:bl, :tl) >= h - EPS || heights.call(:br, :tr) >= h - EPS
            issues << "Trần ô #{ref}: cột chiếm hết một cạnh của ô, bỏ qua."
            next
          end
          polygon = polygon_for(rx0, ry0, rx1, ry1, sizes)
          area = ((rx1 - rx0) * (ry1 - ry0) - sizes.values.compact.sum { |v| v[0] * v[1] }) / 1_000_000.0
          items << {ref: ref, polygon: polygon.map { |p| p.map { |v| v.round(2) } }, min: [rx0.round(2), ry0.round(2)], max: [rx1.round(2), ry1.round(2)], z_bottom: z_bottom, z_top: z_top,
                    thickness: level['ceiling_thickness'], area: area.round(3)}
        end
        # Trần chưa tính tường / cột TỰ DO (chỉ lùi theo tường và cột theo lưới): báo nếu chúng chồng lên trần.
        free_boxes = column_plan[:items].select { |c| c[:placement] == 'free' }.map { |c| [[c[:center][0] - c[:w] / 2.0, c[:center][1] - c[:d] / 2.0], [c[:center][0] + c[:w] / 2.0, c[:center][1] + c[:d] / 2.0], "cột #{c[:ref]}"] }
        free_boxes += walls.values.select { |w| w[:placement] == 'free' }.map { |w| [w[:min], w[:max], "tường #{w[:ref]}"] }
        items.each do |i|
          free_boxes.each { |fb| issues << "Trần ô #{i[:ref]} chồng lên #{fb[2]} (trần chưa lùi theo phần tử tự do)." if i[:min][0] < fb[1][0] - EPS && fb[0][0] < i[:max][0] - EPS && i[:min][1] < fb[1][1] - EPS && fb[0][1] < i[:max][1] - EPS }
        end
        beams.each do |b|
          issues << "Trần cao #{z_top.round} mm chạm dầm #{b[:ref]} (đáy dầm #{b[:z_bottom].round} mm)." if b[:z_bottom] < z_top - EPS && items.any? { |i| overlap?(i, b) }
        end
        {level: level, z_bottom: z_bottom, z_top: z_top, items: items, issues: issues.uniq}
      end

      def self.overlap?(item, beam)
        item[:min][0] < beam[:max][0] - EPS && beam[:min][0] < item[:max][0] - EPS && item[:min][1] < beam[:max][1] - EPS && beam[:min][1] < item[:max][1] - EPS
      end

      # Đa giác ngược chiều kim đồng hồ của hình chữ nhật có khoét góc (sizes: bl, br, tr, tl => [rộng, sâu] hoặc nil).
      def self.polygon_for(x0, y0, x1, y1, sizes)
        pts = []
        (nx, ny = sizes[:bl]) ? pts.push([x0, y0 + ny], [x0 + nx, y0 + ny], [x0 + nx, y0]) : pts.push([x0, y0])
        (nx, ny = sizes[:br]) ? pts.push([x1 - nx, y0], [x1 - nx, y0 + ny], [x1, y0 + ny]) : pts.push([x1, y0])
        (nx, ny = sizes[:tr]) ? pts.push([x1, y1 - ny], [x1 - nx, y1 - ny], [x1 - nx, y1]) : pts.push([x1, y1])
        (nx, ny = sizes[:tl]) ? pts.push([x0 + nx, y1], [x0 + nx, y1 - ny], [x0, y1 - ny]) : pts.push([x0, y1])
        pts
      end
    end
  end
end
