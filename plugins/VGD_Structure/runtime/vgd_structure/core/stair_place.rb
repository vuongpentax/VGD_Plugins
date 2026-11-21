module VGD
  module Structure
    # Đặt cầu thang lên một tầng và KIỂM TRA KHÔNG ĐÂM VÀO cột, dầm, tường của chính tầng đó (logic thuần).
    # Cầu thang thuộc tầng dưới (picks.stairs của tầng), đi từ mặt sàn kết cấu tầng này lên mặt sàn kết cấu tầng kế trên. Khối cầu thang (các bậc đặc)
    # không được cắt qua cột, dầm, tường nằm cùng vùng cao độ. Sàn tầng trên được khoét theo cầu thang ở bước sau (không tính là đâm vào).
    # Lan can chưa tính va chạm (sẽ kiểm ở bước dựng).
    module StairPlace
      Error = Class.new(ArgumentError)
      TOL_Z = 0.5 # mm: chạm nhau đúng mặt không phải va chạm

      # Trả về {level:, items: [...], issues: [...]}. Mỗi mục: ref, type, type_name, a, b, plan (StairPlan), polygon (chân cầu thang), min, max, z0, z1, placement, conflicts.
      def self.plan(grid, types, beam_types, wall_types, stair_types, levels, level_id, opening_types = OpeningTypes.default)
        level = Levels.find(levels, level_id) or raise Error, 'Tầng không tồn tại.'
        picks = level['picks']['stairs'] || {}
        return {level: level, items: [], issues: []} if picks.empty?
        above = Levels.next_of(levels, level_id)
        raise Error, "Tầng “#{level['name']}” là tầng trên cùng, không có cầu thang đi lên." unless above
        z0 = Levels.structure_top(level)
        z1 = Levels.structure_top(above)
        obstacles = obstacles_of(grid, types, beam_types, wall_types, levels, level_id, opening_types)
        items = []
        issues = []
        picks.each do |ref, pick|
          type = StairTypes.find(stair_types, pick['type'])
          raise Error, "Cầu thang #{ref}: loại không tồn tại." unless type
          begin
            plan = StairPlan.plan(pick['free']['a'], pick['free']['b'], type, z0, z1, [], shape: pick['shape'] || 'straight', mid: pick['free']['c'])
          rescue StairPlan::Error => e
            issues << "Cầu thang #{ref}: #{e.message}"
            next
          end
          hits = conflicts(plan, z0, obstacles)
          issues << "Cầu thang #{ref} đâm vào #{hits.join(', ')}: dời cầu thang hoặc dầm, tường." unless hits.empty?
          items << {ref: ref, type: type['id'], type_name: type['name'], a: pick['free']['a'], b: pick['free']['b'], plan: plan, polygon: plan[:footprint],
                    min: bounds(plan[:footprint]).first, max: bounds(plan[:footprint]).last, z0: z0, z1: z1, placement: 'free', conflicts: hits}
        end
        {level: level, items: items, issues: issues}
      end

      # Cột, dầm, tường của tầng (vùng cao độ + hình chiếu). Dầm, tường tự do và xiên dùng đa giác; cột dùng ColumnPlan.polygon.
      def self.obstacles_of(grid, types, beam_types, wall_types, levels, level_id, opening_types)
        level = Levels.find(levels, level_id)
        cols = ColumnPlan.plan(grid, types, levels, level_id)[:items].map { |c| {name: "cột #{c[:ref]}", ring: ColumnPlan.polygon(c), z0: c[:z0], z1: c[:z1]} }
        beams = level['picks']['beams'].empty? ? [] : BeamPlan.plan(grid, types, beam_types, levels, level_id)[:items]
        beams = beams.map { |b| {name: "dầm #{b[:ref]}", ring: ring_of(b), z0: b[:z_bottom], z1: b[:z_top]} }
        walls = level['picks']['walls'].empty? ? [] : WallPlan.plan(grid, types, beam_types, wall_types, levels, level_id, opening_types)[:items]
        walls = walls.map { |w| {name: "tường #{w[:ref]}", ring: ring_of(w), z0: w[:z_bottom], z1: w[:z_top]} }
        cols + beams + walls
      end

      # Tên các vật cản mà một bậc đâm vào (cùng vùng cao độ và cùng vùng mặt bằng).
      def self.conflicts(plan, z0, obstacles)
        steps = plan[:steps]
        obstacles.filter_map do |ob|
          hit = steps.any? do |step|
            zs_overlap = ob[:z0] < step[:z1] - TOL_Z && ob[:z1] > z0 + TOL_Z
            zs_overlap && Geometry.regions_overlap?(step[:poly], [], ob[:ring], [])
          end
          ob[:name] if hit
        end
      end

      def self.ring_of(item)
        item[:poly] || item[:polygon] || Plates.ring_of(item)
      end

      def self.bounds(points)
        xs = points.map(&:first)
        ys = points.map(&:last)
        [[xs.min, ys.min], [xs.max, ys.max]]
      end
    end
  end
end
