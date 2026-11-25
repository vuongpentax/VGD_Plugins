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
      # stair_types: nếu có thì khoét lỗ cho cầu thang của tầng dưới đi lên qua sàn này (stair_holes!).
      def self.plan(grid, levels, level_id, types = nil, beam_types = nil, wall_types = nil, opening_types = OpeningTypes.default, stair_types = nil)
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
        stair_holes!(items, below_stairs(grid, types, beam_types, wall_types, stair_types, opening_types, levels, level_id, issues), issues)
        tech_holes!(items, grid, level, issues)
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

      # Hình chiếu bằng (đa giác) các cầu thang của TẦNG DƯỚI: chúng đi lên qua sàn này. Lỗi kế hoạch cầu thang thì báo và không khoét.
      def self.below_stairs(grid, types, beam_types, wall_types, stair_types, opening_types, levels, level_id, issues)
        index = levels.index { |l| l['id'] == level_id }
        return [] unless stair_types && types && beam_types && wall_types && index && index.positive?
        below = levels[index - 1]
        return [] if (below['picks']['stairs'] || {}).empty?
        StairPlace.plan(grid, types, beam_types, wall_types, stair_types, levels, below['id'], opening_types)[:items].map { |s| [s[:ref], s[:polygon]] }
      rescue StairPlace::Error, StairPlan::Error, ColumnPlan::Error, BeamPlan::Error, WallPlan::Error => e
        issues << "Sàn chưa khoét lỗ cầu thang vì kế hoạch cầu thang tầng dưới có lỗi: #{e.message}"
        []
      end

      MIN_CUT_AREA = 100.0 # mm2: phần lỗ lọt vào tấm sàn nhỏ hơn mức này coi như chỉ chạm mép, bỏ qua

      # Khoét lỗ cầu thang của tầng dưới đi lên qua sàn này: cầu thang vắt qua nhiều tấm thì khoét từng tấm phần nằm trong tấm đó (cut_holes!).
      def self.stair_holes!(items, stairs, issues)
        cut_holes!(items, stairs, :stair_holes, 'Cầu thang', issues)
      end

      # Lỗ kỹ thuật của tầng (level['slab_holes']): hình chữ nhật theo 2 giao điểm lưới + lùi mỗi cạnh, khoét từng tấm như cầu thang; lỗ không rơi vào tấm nào thì báo.
      def self.tech_holes!(items, grid, level, issues)
        nodes = Grid.intersections(grid).each_with_object({}) { |n, h| h[n[:ref]] = n }
        shapes = (level['slab_holes'] || {}).filter_map do |id, hole|
          box = nodes.key?(hole['a']) && nodes.key?(hole['b']) && Levels.slab_hole_box(nodes[hole['a']], nodes[hole['b']], hole['inset'])
          box && [id, [box[0], [box[1][0], box[0][1]], box[1], [box[0][0], box[1][1]]]]
        end
        cut_holes!(items, shapes, :tech_holes, 'Lỗ kỹ thuật', issues, warn_unused: true)
      end

      # Cắt hình `poly` theo từng tấm: phần nằm trong hộp bao của tấm thành một lỗ của tấm đó (lỗ có thể chạm mép tấm, khi đó thành chỗ khuyết ở mép).
      # Phần cắt không nằm trọn trong tấm (tấm bị khoét góc, tấm đa giác, chồng lỗ khác) thì không khoét mà CẢNH BÁO. Lỗ phủ hết một tấm thì bỏ tấm đó (cảnh báo).
      # Trừ diện tích và ghi mã vào item[key]. Hình chưa chạm tấm nào: chỉ báo khi warn_unused.
      def self.cut_holes!(items, shapes, key, label, issues, warn_unused: false)
        shapes.each do |ref, poly|
          used = false
          items.each do |item|
            piece = Geometry.clip_to_box(poly, item[:min], item[:max])
            next if piece.size < 3 || Geometry.area(piece) < MIN_CUT_AREA
            used = true
            unless Geometry.simple_ring?(piece) && fits_in?(item, piece)
              issues << "#{label} #{ref} cắt qua sàn #{item[:ref]} nhưng chưa khoét được lỗ (sàn bị khoét góc, là đa giác hoặc đã có lỗ chồng lên): hãy bỏ ô sàn đó hoặc vẽ sàn đa giác có lỗ."
              next
            end
            item[:holes] = (item[:holes] || []) + [piece]
            item[:area] = (item[:area] - Geometry.area(piece) / 1_000_000.0).round(3)
            (item[key] ||= []) << ref
          end
          issues << "#{label} #{ref} không nằm trên tấm sàn nào của tầng." if warn_unused && !used
        end
        void = items.select { |i| i[:area] <= 0.0005 }
        void.each { |i| issues << "Sàn #{i[:ref]} bị lỗ khoét trùm hết, bỏ qua." }
        items.reject! { |i| void.include?(i) }
      end

      # Hình `piece` nằm trọn trong miền của tấm (vòng ngoài, trừ lỗ có sẵn): đỉnh và trung điểm cạnh không nằm ngoài vòng, không cắt cạnh vòng,
      # không có đỉnh vòng nào chui vào trong hình, không chồng lỗ có sẵn.
      def self.fits_in?(item, piece)
        ring = Plates.ring_of(item)
        on_or_in = ->(pt) { Geometry.inside_ring?(pt, ring) || Geometry.point_on_ring?(pt, ring) }
        mids = piece.each_with_index.map { |a, k| b = piece[(k + 1) % piece.size]; [(a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0] }
        (piece + mids).all?(&on_or_in) &&
          piece.each_with_index.none? { |a, k| ring.each_with_index.any? { |c, j| Geometry.segments_cross?(a, piece[(k + 1) % piece.size], c, ring[(j + 1) % ring.size]) } } &&
          ring.none? { |v| Geometry.inside_ring?(v, piece) } &&
          (item[:holes] || []).none? { |h| Geometry.regions_overlap?(piece, [], h, []) }
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
