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
        raise Error, "Trần tầng “#{level['name']}” (mặt trên #{z_top} mm) cao hơn đáy sàn tầng trên (#{column_plan[:slab_bottom]} mm). Hãy giảm cao trần." if z_top > column_plan[:slab_bottom] + EPS
        walls = level['picks']['walls'].empty? ? {} : WallPlan.plan(grid, types, beam_types, wall_types, levels, level_id, opening_types)[:items].each_with_object({}) { |w, h| h[w[:ref]] = w }
        beams = level['picks']['beams'].empty? ? {} : BeamPlan.plan(grid, types, beam_types, levels, level_id)[:items]
        columns = column_plan[:items].each_with_object({}) { |c, h| h[c[:ref]] = c }
        cells = Grid.cells(grid).each_with_object({}) { |c, h| h[c[:ref]] = c }
        items = []
        issues = []
        cells.each do |ref, cell|
          level['picks']['ceilings'].key?(ref) or next
          shape = Plates.recess_cell(cell, Plates.edge_items(cell, walls), columns)
          if shape[:error] == :narrow
            issues << "Trần ô #{ref}: khoảng hở giữa các tường nhỏ hơn #{MIN_SIZE.to_i} mm, bỏ qua."
            next
          elsif shape[:error]
            issues << "Trần ô #{ref}: cột chiếm hết một cạnh của ô, bỏ qua."
            next
          end
          items << {ref: ref, polygon: shape[:polygon], min: shape[:min], max: shape[:max], z_bottom: z_bottom, z_top: z_top,
                    thickness: level['ceiling_thickness'], area: shape[:area]}
        end
        # Trần ĐA GIÁC tự do (P4b-3): đúng hình đã vẽ (có thể có lỗ); không lùi theo tường / cột, chồng nhau thì chỉ cảnh báo.
        free_ceilings = level['picks']['ceilings'].select { |_ref, pick| pick['free'] }.map do |ref, pick|
          Plates.free_item(ref, pick['free'], thickness: level['ceiling_thickness'], z_bottom: z_bottom, z_top: z_top)
        end
        items.concat(free_ceilings)
        unless (level['ceiling_layers'] || []).empty? # lớp cấu tạo trần, từ mặt dưới (nhìn thấy) lên
          layers = LayerList.for_plan(level['ceiling_layers'])
          items.each { |i| i[:layers] = layers }
        end
        issues.concat(Plates.overlap_issues(items, 'Trần'))
        solids = column_plan[:items].map { |c| [ColumnPlan.polygon(c), "cột #{c[:ref]}"] } + walls.values.map { |w| [Plates.ring_of(w), "tường #{w[:ref]}"] }
        free_ceilings.each do |fc|
          solids.each { |ring, name| issues << "Trần #{fc[:ref]} chồng lên #{name} (trần đa giác không lùi theo tường, cột)." if Geometry.regions_overlap?(fc[:polygon], fc[:holes], ring, []) }
        end
        # Trần chưa tính tường / cột TỰ DO (chỉ lùi theo tường và cột theo lưới): báo nếu chúng chồng lên trần.
        free_boxes = column_plan[:items].select { |c| c[:placement] == 'free' }.map { |c| ColumnPlan.box(c) + ["cột #{c[:ref]}"] }
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
