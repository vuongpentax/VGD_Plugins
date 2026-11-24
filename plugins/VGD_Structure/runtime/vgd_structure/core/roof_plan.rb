module VGD
  module Structure
    # Kế hoạch mái của một tầng có khai báo `roof` (Levels.roof!). Logic thuần.
    # Đường mép (chân) mái là khung lưới (trục biên); mái chìa ra ngoài `overhang` mỗi phía. Đáy mái tại đường mép ở cao độ z_b = cao độ tầng + base,
    # mặt mái dốc lên theo khoảng cách d tới đường mép (d âm ở phần chìa): mặt trên z = z_b + tv + d * tan(dốc), tv = dày / cos(dốc) là bề dày theo phương đứng.
    # Mỗi mặt mái là một tấm: đa giác MẶT TRÊN 3D (4 đỉnh, mm) đùn xuống tv theo phương đứng (nên thể tích = diện tích nghiêng x dày).
    # Mái hai dốc: hai tấm gặp nhau ở nóc, không chồng nhau trên mặt bằng. Mái bốn dốc (hip): cùng một độ dốc cho bốn phía, bốn tấm nam, đông, bắc, tây (hình thang hoặc tam giác);
    # nóc là đoạn nằm giữa khung theo phương dài, dài (dài - rộng), hoặc một điểm nếu khung vuông. Chưa làm: tường thu hồi, mái theo đường bao bất kỳ.
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
        parts = case roof['shape']
                when 'flat' then [[rect_corners(x0 - o, y0 - o, x1 + o, y1 + o), ->(_x, _y) { 0.0 }]]
                when 'shed' then [[rect_corners(x0 - o, y0 - o, x1 + o, y1 + o), rise_of(roof['dir'], x0, y0, x1, y1)]]
                when 'hip' then hip(x0, y0, x1, y1, o)
                else gable(roof['dir'], x0, y0, x1, y1, o)
                end
        items = parts.each_with_index.map do |(corners, rise), i|
          top = corners.map { |x, y| [x.round(2), y.round(2), (zb + tv + rise.call(x, y) * tan).round(2)] }
          poly = top.map { |x, y, _| [x, y] }
          plan_area = polygon_area(poly) / 1_000_000.0
          {ref: parts.size == 1 ? 'roof' : "roof_#{i + 1}", top: top, poly: poly, tv: tv, thickness: roof['thickness'], slope: slope,
           shape: roof['shape'], area: (plan_area / Math.cos(slope * Math::PI / 180)).round(3), plan_area: plan_area.round(3)}
        end
        issues = []
        ridge = items.map { |i| i[:top].map(&:last).max }.max
        issues << "Nóc mái cao #{(ridge - zb).round} mm so với chân mái: kiểm tra lại độ dốc." if ridge - zb > 15_000
        {level: level, z_base: zb, ridge: ridge, items: items, issues: issues}
      end

      def self.rect_corners(ax, ay, bx, by)
        [[ax, ay], [bx, ay], [bx, by], [ax, by]]
      end

      # Diện tích đa giác phẳng (shoelace), mm².
      def self.polygon_area(poly)
        poly.each_with_index.sum { |(x, y), i| nx, ny = poly[(i + 1) % poly.size]; x * ny - nx * y }.abs / 2.0
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
          [[rect_corners(x0 - o, y0 - o, x1 + o, ym), ->(_x, y) { y - y0 }], [rect_corners(x0 - o, ym, x1 + o, y1 + o), ->(_x, y) { y1 - y }]]
        else
          xm = (x0 + x1) / 2.0
          [[rect_corners(x0 - o, y0 - o, xm, y1 + o), ->(x, _y) { x - x0 }], [rect_corners(xm, y0 - o, x1 + o, y1 + o), ->(x, _y) { x1 - x }]]
        end
      end

      # Mái bốn dốc: độ cao = dốc x khoảng cách tới mép khung GẦN NHẤT (nên bốn mặt dốc đều nhau). Hai đầu nóc A, B cách mép m = nửa cạnh ngắn; các đường
      # chéo 45° từ góc khung qua góc chìa tới A, B. Bốn tấm theo thứ tự nam, đông, bắc, tây, đỉnh ngược chiều kim đồng hồ (nhìn từ trên); khung vuông thì A = B
      # và các tấm hình thang thành tam giác (đỉnh trùng bị bỏ).
      def self.hip(x0, y0, x1, y1, o)
        rise = ->(x, y) { [x - x0, x1 - x, y - y0, y1 - y].min }
        m = [x1 - x0, y1 - y0].min / 2.0
        ox0, oy0, ox1, oy1 = x0 - o, y0 - o, x1 + o, y1 + o
        a, b = if (x1 - x0) >= (y1 - y0)
                 [[x0 + m, (y0 + y1) / 2.0], [x1 - m, (y0 + y1) / 2.0]]
               else
                 [[(x0 + x1) / 2.0, y0 + m], [(x0 + x1) / 2.0, y1 - m]]
               end
        sw, se, ne, nw = [ox0, oy0], [ox1, oy0], [ox1, oy1], [ox0, oy1]
        sides = if (x1 - x0) >= (y1 - y0)
                  [[sw, se, b, a], [se, ne, b], [ne, nw, a, b], [nw, sw, a]]
                else
                  [[sw, se, a], [se, ne, b, a], [ne, nw, b], [nw, sw, a, b]]
                end
        sides.map { |corners| [dedupe(corners), rise] }
      end

      # Bỏ đỉnh trùng liên tiếp (khung vuông: hai đầu nóc trùng nhau).
      def self.dedupe(points)
        points.each_with_index.reject { |p, i| (p[0] - points[i - 1][0]).abs < 0.01 && (p[1] - points[i - 1][1]).abs < 0.01 }.map(&:first)
      end
    end
  end
end
