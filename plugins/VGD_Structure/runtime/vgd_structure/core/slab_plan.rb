module VGD
  module Structure
    # Kế hoạch sàn của một tầng (đặc tả: SPEC mục 5). Logic thuần. Sàn phủ trọn ô (từ trục tới trục, kể cả phía trên cột và dầm của tầng dưới),
    # mặt trên tại cao độ sàn của tầng (`Ei`), dày `slab_thickness` xuống dưới. Cột và dầm tầng dưới dừng ở đáy sàn nên không chồng khối.
    # Tầng trên cùng (đỉnh nhà, mái) cũng có sàn.
    module SlabPlan
      Error = Class.new(ArgumentError)

      def self.plan(grid, levels, level_id)
        level = Levels.find(levels, level_id) or raise Error, 'Tầng không tồn tại.'
        cells = Grid.cells(grid).each_with_object({}) { |c, h| h[c[:ref]] = c }
        z_top = level['elevation']
        thickness = level['slab_thickness']
        items = level['picks']['slabs'].keys.reject { |ref| level['picks']['slabs'][ref]['free'] }.map do |ref|
          cell = cells.fetch(ref)
          {ref: ref, min: cell[:min], max: cell[:max], width: cell[:width], depth: cell[:depth], thickness: thickness, z_top: z_top, z_bottom: (z_top - thickness).round(1),
           area: (cell[:width] * cell[:depth] / 1_000_000.0).round(3)}
        end
        # theo thứ tự ô của lưới
        order = cells.keys
        items.sort_by! { |i| order.index(i[:ref]) }
        # Sàn ĐA GIÁC tự do (P4b-3): đúng hình đã vẽ, có thể có lỗ; trộn được với sàn theo ô, chồng nhau thì chỉ cảnh báo.
        level['picks']['slabs'].each do |ref, pick|
          free = pick['free'] or next
          items << Plates.free_item(ref, free, thickness: thickness, z_top: z_top, z_bottom: (z_top - thickness).round(1))
        end
        {level: level, z_top: z_top, thickness: thickness, items: items, issues: Plates.overlap_issues(items, 'Sàn')}
      end
    end
  end
end
