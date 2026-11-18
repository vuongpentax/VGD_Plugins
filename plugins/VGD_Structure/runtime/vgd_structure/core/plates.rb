module VGD
  module Structure
    # Phần dùng chung của sàn và trần ĐA GIÁC tự do (P4b-3): mục kế hoạch từ dữ liệu `free`, kiểm tra chồng nhau. Logic thuần.
    module Plates
      MIN_SIZE = 100.0
      MAX_COMPARE = 400 # số mục tối đa để so chồng từng cặp (vượt thì bỏ qua so cặp, không lỗi)

      # Hình tấm trong một Ô lưới sau khi LÙI theo vật cản và KHOÉT GÓC theo cột (dùng chung cho trần lùi theo tường và sàn lọt lòng giữa dầm):
      # edges = {bottom:, top:, left:, right:} là mục (có :min, :max) đứng ở bốn cạnh ô hoặc nil; columns = {mã nút => mục cột}.
      # Trả về {polygon:, min:, max:, area:} (polygon ngược chiều kim đồng hồ, mm) hoặc {error: :narrow | :columns}.
      def self.recess_cell(cell, edges, columns)
        eps = 1e-6
        x0, y0 = cell[:min]
        x1, y1 = cell[:max]
        rx0 = edges[:left] ? [x0, edges[:left][:max][0]].max : x0
        rx1 = edges[:right] ? [x1, edges[:right][:min][0]].min : x1
        ry0 = edges[:bottom] ? [y0, edges[:bottom][:max][1]].max : y0
        ry1 = edges[:top] ? [y1, edges[:top][:min][1]].min : y1
        return {error: :narrow} if rx1 - rx0 < MIN_SIZE || ry1 - ry0 < MIN_SIZE
        notch = lambda do |node, cx, cy|
          col = columns[node] or return nil
          cmin, cmax = ColumnPlan.box(col)
          return nil unless cmin[0] < cx + eps && cx - eps < cmax[0] && cmin[1] < cy + eps && cy - eps < cmax[1] # cột phải chứa góc của hình chữ nhật
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
        sizes.each { |k, v| sizes[k] = nil if v && (v[0] <= eps || v[1] <= eps) }
        w = rx1 - rx0
        h = ry1 - ry0
        widths = ->(a, b) { (sizes[a]&.first || 0) + (sizes[b]&.first || 0) }
        heights = ->(a, b) { (sizes[a]&.last || 0) + (sizes[b]&.last || 0) }
        return {error: :columns} if widths.call(:bl, :br) >= w - eps || widths.call(:tl, :tr) >= w - eps || heights.call(:bl, :tl) >= h - eps || heights.call(:br, :tr) >= h - eps
        polygon = CeilingPlan.polygon_for(rx0, ry0, rx1, ry1, sizes)
        area = (w * h - sizes.values.compact.sum { |v| v[0] * v[1] }) / 1_000_000.0
        {polygon: polygon.map { |p| p.map { |v| v.round(2) } }, min: [rx0.round(2), ry0.round(2)], max: [rx1.round(2), ry1.round(2)], area: area.round(3)}
      end

      # Mục ở bốn cạnh của ô theo mã nhịp (tường hoặc dầm): bottom / top là nhịp theo X, left / right là nhịp theo Y.
      def self.edge_items(cell, by_ref)
        {bottom: by_ref["x:#{cell[:ya]}:#{cell[:xa]}-#{cell[:xb]}"], top: by_ref["x:#{cell[:yb]}:#{cell[:xa]}-#{cell[:xb]}"],
         left: by_ref["y:#{cell[:xa]}:#{cell[:ya]}-#{cell[:yb]}"], right: by_ref["y:#{cell[:xb]}:#{cell[:ya]}-#{cell[:yb]}"]}
      end

      # free: {'poly' => vòng ngoài, 'holes' => [vòng lỗ]} đã chuẩn hóa. Trả về mục kế hoạch có polygon, holes, min, max, area (m2, đã trừ lỗ), placement 'free'.
      def self.free_item(ref, free, extra)
        poly = free['poly']
        holes = free['holes'] || []
        min, max = Geometry.bounds(poly)
        area = (Geometry.area(poly) - holes.sum { |h| Geometry.area(h) }) / 1_000_000.0
        {ref: ref, polygon: poly, holes: holes, min: min, max: max, area: area.round(3), placement: 'free'}.merge(extra)
      end

      def self.ring_of(item)
        item[:polygon] || [[item[:min][0], item[:min][1]], [item[:max][0], item[:min][1]], [item[:max][0], item[:max][1]], [item[:min][0], item[:max][1]]]
      end

      # Cảnh báo cặp chồng nhau mà ít nhất một bên là đa giác tự do.
      def self.overlap_issues(items, label)
        return [] if items.size > MAX_COMPARE
        issues = []
        items.each_with_index do |a, i|
          items[(i + 1)..].each do |b|
            next unless a[:placement] == 'free' || b[:placement] == 'free'
            next unless a[:min][0] < b[:max][0] && b[:min][0] < a[:max][0] && a[:min][1] < b[:max][1] && b[:min][1] < a[:max][1]
            issues << "#{label} #{a[:ref]} và #{b[:ref]} chồng lên nhau." if Geometry.regions_overlap?(ring_of(a), a[:holes] || [], ring_of(b), b[:holes] || [])
          end
        end
        issues
      end
    end
  end
end
