module VGD
  module Structure
    # Kế hoạch sàn của một tầng (đặc tả: SPEC mục 5). Logic thuần.
    # - Mặt trên sàn KẾT CẤU = cao độ tầng `Ei` (cốt hoàn thiện) trừ lớp cán nền `screed` (mặc định 50 mm); dày `slab_thickness` xuống dưới.
    # - Sàn nằm LỌT LÒNG giữa các dầm: mỗi ô lùi tới MẶT các dầm theo cạnh ô và khoét góc theo cột của tầng dưới (đỉnh dầm bằng đỉnh sàn), nên khối sàn
    #   và khối dầm, cột không chồng nhau (khối lượng bóc tách đúng). Dầm, cột tự do (không theo lưới) nằm trong ô chỉ được CẢNH BÁO, sàn chưa lùi theo chúng.
    # - Tầng thấp nhất không có tầng dưới nên sàn phủ trọn ô. Tầng trên cùng (đỉnh nhà, mái) cũng có sàn.
    module SlabPlan
      Error = Class.new(ArgumentError)

      # types, beam_types, wall_types: nếu có thì lùi sàn theo cột, dầm, tường của tầng dưới; không có thì sàn phủ trọn ô (tường cần thêm opening_types cho kế hoạch tường).
      def self.plan(grid, levels, level_id, types = nil, beam_types = nil, wall_types = nil, opening_types = OpeningTypes.default)
        level = Levels.find(levels, level_id) or raise Error, 'Tầng không tồn tại.'
        cells = Grid.cells(grid).each_with_object({}) { |c, h| h[c[:ref]] = c }
        z_top = Levels.structure_top(level)
        thickness = level['slab_thickness']
        z_bottom = (z_top - thickness).round(1)
        issues = []
        columns, beams, walls = below_items(grid, types, beam_types, wall_types, opening_types, levels, level_id, issues)
        beams_by_ref = beams.reject { |b| b[:placement] == 'free' }.each_with_object({}) { |b, h| h[b[:ref]] = b }
        walls_by_ref = walls.reject { |w| w[:placement] == 'free' }.each_with_object({}) { |w, h| h[w[:ref]] = w }
        columns_by_ref = columns.reject { |c| c[:placement] == 'free' }.each_with_object({}) { |c, h| h[c[:ref]] = c }
        items = []
        cells.each do |ref, cell|
          next unless level['picks']['slabs'].key?(ref)
          shape = Plates.recess_cell(cell, Plates.recess_edges(cell, beams_by_ref, walls_by_ref), columns_by_ref)
          if shape[:error]
            issues << "Sàn ô #{ref}: #{shape[:error] == :narrow ? 'khoảng hở giữa các dầm nhỏ hơn ' + Plates::MIN_SIZE.to_i.to_s + ' mm' : 'cột chiếm hết một cạnh của ô'}, bỏ qua."
            next
          end
          items << {ref: ref, polygon: shape[:polygon], min: shape[:min], max: shape[:max], width: cell[:width], depth: cell[:depth], thickness: thickness, z_top: z_top, z_bottom: z_bottom, area: shape[:area]}
        end
        order = cells.keys
        items.sort_by! { |i| order.index(i[:ref]) }
        # Sàn ĐA GIÁC tự do (P4b-3): đúng hình đã vẽ, có thể có lỗ; trộn được với sàn theo ô, chồng nhau thì chỉ cảnh báo.
        level['picks']['slabs'].each do |ref, pick|
          free = pick['free'] or next
          items << Plates.free_item(ref, free, thickness: thickness, z_top: z_top, z_bottom: z_bottom)
        end
        unless (level['floor_layers'] || []).empty? # sàn kết cấu rồi các lớp hoàn thiện xếp LÊN trên (danh sách của tầng đi từ trên xuống nên đảo lại)
          layers = [{fn: 'structure', t: thickness, material: '', color: WallTypes::DEFAULT_COLORS['structure']}] + LayerList.for_plan(level['floor_layers']).reverse
          items.each { |i| i[:layers] = layers }
        end
        issues.concat(Plates.overlap_issues(items, 'Sàn'))
        issues.concat(free_overlaps(items, columns, beams, walls))
        {level: level, z_top: z_top, thickness: thickness, items: items, issues: issues.uniq}
      end

      # Cột, dầm, tường của TẦNG DƯỚI (đỡ sàn này). Lỗi kế hoạch tầng dưới thì báo cảnh báo và không lùi.
      def self.below_items(grid, types, beam_types, wall_types, opening_types, levels, level_id, issues)
        index = levels.index { |l| l['id'] == level_id }
        return [[], [], []] unless types && beam_types && index && index.positive?
        below = levels[index - 1]
        columns = ColumnPlan.plan(grid, types, levels, below['id'])[:items]
        beams = below['picks']['beams'].empty? ? [] : BeamPlan.plan(grid, types, beam_types, levels, below['id'])[:items]
        walls = below['picks']['walls'].empty? || wall_types.nil? ? [] : WallPlan.plan(grid, types, beam_types, wall_types, levels, below['id'], opening_types)[:items]
        [columns, beams, walls]
      rescue ColumnPlan::Error, BeamPlan::Error, WallPlan::Error => e
        issues << "Sàn chưa lùi theo cột, dầm, tường tầng dưới vì kế hoạch tầng dưới có lỗi: #{e.message}"
        [[], [], []]
      end

      # Cột, dầm, tường TỰ DO của tầng dưới nằm trong tấm sàn: sàn chưa lùi theo chúng nên chỉ báo.
      def self.free_overlaps(items, columns, beams, walls)
        solids = columns.select { |c| c[:placement] == 'free' }.map { |c| [ColumnPlan.polygon(c), "cột #{c[:ref]}"] } + beams.select { |b| b[:placement] == 'free' }.map { |b| [Plates.ring_of(b), "dầm #{b[:ref]}"] } + walls.select { |w| w[:placement] == 'free' }.map { |w| [Plates.ring_of(w), "tường #{w[:ref]}"] }
        return [] if solids.empty?
        items.flat_map do |i|
          solids.select { |ring, _| Geometry.regions_overlap?(Plates.ring_of(i), i[:holes] || [], ring, []) }.map { |_, name| "Sàn #{i[:ref]} chồng lên #{name} tầng dưới (sàn chưa lùi theo phần tử tự do)." }
        end
      end
    end
  end
end
