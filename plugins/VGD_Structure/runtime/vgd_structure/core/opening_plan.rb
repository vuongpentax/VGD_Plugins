module VGD
  module Structure
    # Kế hoạch cửa của một tầng: lấy từ các lỗ mở đã đặt trên tường (WallPlan là nguồn duy nhất kiểm tra vị trí) rồi đổi sang tọa độ thế giới (mm).
    # Cửa đặt lên tường được chọn cùng tầng; tầng trên cùng chỉ có sàn nên không có tường, không có cửa. Logic thuần.
    module OpeningPlan
      Error = Class.new(ArgumentError)

      def self.plan(grid, types, beam_types, wall_types, opening_types, levels, level_id)
        level = Levels.find(levels, level_id) or raise Error, 'Tầng không tồn tại.'
        raise Error, "Tầng “#{level['name']}” là tầng trên cùng, chỉ có sàn nên không có cửa." unless Levels.next_of(levels, level_id)
        walls = WallPlan.plan(grid, types, beam_types, wall_types, levels, level_id, opening_types)
        items = walls[:items].flat_map do |w|
          w[:openings].map do |o|
            along = w[:start] + o[:x0]
            plan_min = w[:dir] == 'x' ? [along, w[:center] - w[:t] / 2.0] : [w[:center] - w[:t] / 2.0, along]
            plan_max = w[:dir] == 'x' ? [along + o[:w], w[:center] + w[:t] / 2.0] : [w[:center] + w[:t] / 2.0, along + o[:w]]
            {ref: o[:id], wall: w[:ref], dir: w[:dir], kind: o[:kind], type_id: o[:type_id], type_name: o[:type_name], w: o[:w], h: o[:h], sill: o[:sill], pos: o[:pos], flip: o[:flip],
             thickness: w[:t], along: along.round(2), center: w[:center], min: plan_min.map { |v| v.round(2) }, max: plan_max.map { |v| v.round(2) },
             z_bottom: (w[:z_bottom] + o[:sill]).round(2), z_top: (w[:z_bottom] + o[:z1]).round(2)}
          end
        end
        order = level['picks']['openings'].keys
        items.sort_by! { |i| order.index(i[:ref]) }
        {level: level, items: items, issues: walls[:opening_issues]}
      end
    end
  end
end
