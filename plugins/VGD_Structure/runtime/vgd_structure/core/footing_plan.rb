module VGD
  module Structure
    # Kế hoạch đế móng đơn của một tầng (tầng móng có `footing`): mỗi cột của tầng (theo ColumnPlan, cả cột tự do / xoay) có một đế
    # hình hộp ngay dưới chân cột: đỉnh đế = chân cột (z0 của cột), dày `h` xuống dưới, tâm trùng tâm cột, dài `l` theo trục x riêng của cột,
    # rộng `w` theo trục y riêng (cột xoay 90 độ thì đổi chỗ, cột xoay góc khác thì đế xoay cùng góc). Logic thuần.
    # Mục kế hoạch có cùng trường hình học với cột (center, w, d, rot, poly) để dùng lại ColumnPlan.box / overlaps và Placement.
    module FootingPlan
      Error = Class.new(ArgumentError)

      def self.plan(grid, types, levels, level_id)
        level = Levels.find(levels, level_id) or raise Error, 'Tầng không tồn tại.'
        footing = level['footing'] or raise Error, "Tầng “#{level['name']}” chưa khai báo móng."
        columns = ColumnPlan.plan(grid, types, levels, level_id)
        h = footing['h']
        z_top = columns[:z0]
        items = columns[:items].map do |col|
          rot = col[:rot]
          swapped = !rot && col[:placement] == 'free' && ((level['picks']['columns'][col[:ref]]['free']['rot'] || 0) % 180) == 90
          w, d = swapped ? [footing['w'], footing['l']] : [footing['l'], footing['w']]
          item = {ref: col[:ref], center: col[:center], w: w, d: d, h: h, z0: (z_top - h).round(1), z1: z_top, column_w: col[:w], column_d: col[:d], placement: col[:placement]}
          item.merge!(rot: rot, poly: Geometry.round_poly(Geometry.rotated_rect(col[:center], w, d, rot))) if rot
          item
        end
        issues = []
        items.each do |item|
          small = item[:w] < item[:column_w] || item[:d] < item[:column_d]
          issues << "Móng #{item[:ref]} nhỏ hơn tiết diện cột (#{item[:column_w].round}x#{item[:column_d].round} mm)." if small
        end
        ColumnPlan.overlaps(items).each { |a, b| issues << "Móng #{a[:ref]} và #{b[:ref]} chồng lên nhau: nên gộp thành móng chung hoặc giảm kích thước." }
        {level: level, z_top: z_top, h: h, items: items, issues: issues}
      end
    end
  end
end
