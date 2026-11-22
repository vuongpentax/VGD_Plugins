module VGD
  module Structure
    # Kế hoạch mái của một tầng có khai báo `roof` (Levels.roof!). Logic thuần.
    # Đường mép (chân) mái là khung lưới (trục biên); mái chìa ra ngoài `overhang` mỗi phía. Đáy mái tại đường mép ở cao độ z_b = cao độ tầng + base,
    # mặt mái dốc lên theo khoảng cách d tới đường mép (d âm ở phần chìa): mặt trên z = z_b + tv + d * tan(dốc), tv = dày / cos(dốc) là bề dày theo phương đứng.
    # Mỗi mặt mái là một tấm: đa giác MẶT TRÊN 3D (4 đỉnh, mm) đùn xuống tv theo phương đứng (nên thể tích = diện tích nghiêng x dày).
    # Mái hai dốc: hai tấm gặp nhau ở nóc, không chồng nhau trên mặt bằng. Chưa làm: mái bốn dốc (hip), tường thu hồi, mái theo đường bao bất kỳ.
    module RoofPlan
      Error = Class.new(ArgumentError)

      def self.plan(grid, levels, level_id)
        level = Levels.find(levels, level_id) or raise Error, 'Tầng không tồn tại.'
        roof = level['roof'] or raise Error, "Tầng “#{level['name']}” chưa khai báo mái."
        x0, y0, x1, y1 = Grid.bounds(grid)
        o = roof['overhang']
        slope = roof['shape'] == 'flat' ? 0.0 : roof['slope']
        tan = Math.tan(slope * Math::PI / 180)
        tv = (roof['thickness'] / Math.cos(slope * Math::PI / 180)).round(2)
        zb = (level['elevation'] + roof['base']).round(1)
        rects = case roof['shape']
                when 'flat' then [[[x0 - o, y0 - o, x1 + o, y1 + o], ->(_x, _y) { 0.0 }]]
                when 'shed' then [[[x0 - o, y0 - o, x1 + o, y1 + o], rise_of(roof['dir'], x0, y0, x1, y1)]]
                else gable(roof['dir'], x0, y0, x1, y1, o)
                end
        items = rects.each_with_index.map do |((ax, ay, bx, by), rise), i|
          top = [[ax, ay], [bx, ay], [bx, by], [ax, by]].map { |x, y| [x.round(2), y.round(2), (zb + tv + rise.call(x, y) * tan).round(2)] }
          plan_area = (bx - ax) * (by - ay) / 1_000_000.0
          {ref: rects.size == 1 ? 'roof' : "roof_#{i + 1}", top: top, poly: top.map { |x, y, _| [x, y] }, tv: tv, thickness: roof['thickness'], slope: slope,
           shape: roof['shape'], area: (plan_area / Math.cos(slope * Math::PI / 180)).round(3), plan_area: plan_area.round(3)}
        end
        issues = []
        ridge = items.map { |i| i[:top].map(&:last).max }.max
        issues << "Nóc mái cao #{(ridge - zb).round} mm so với chân mái: kiểm tra lại độ dốc." if ridge - zb > 15_000
        {level: level, z_base: zb, ridge: ridge, items: items, issues: issues}
      end

      # Mái một dốc: khoảng cách tới đường mép phía THẤP (dốc lên theo `dir`).
      def self.rise_of(dir, x0, y0, x1, y1)
        case dir
        when 'x+' then ->(x, _y) { x - x0 }
        when 'x-' then ->(x, _y) { x1 - x }
        when 'y+' then ->(_x, y) { y - y0 }
        else ->(_x, y) { y1 - y }
        end
      end

      # Mái hai dốc: nóc ở giữa khung, song song phương `dir`; mỗi tấm dốc lên từ đường mép của nó tới nóc.
      def self.gable(dir, x0, y0, x1, y1, o)
        if dir == 'x'
          ym = (y0 + y1) / 2.0
          [[[x0 - o, y0 - o, x1 + o, ym], ->(_x, y) { y - y0 }], [[x0 - o, ym, x1 + o, y1 + o], ->(_x, y) { y1 - y }]]
        else
          xm = (x0 + x1) / 2.0
          [[[x0 - o, y0 - o, xm, y1 + o], ->(x, _y) { x - x0 }], [[xm, y0 - o, x1 + o, y1 + o], ->(x, _y) { x1 - x }]]
        end
      end
    end
  end
end
