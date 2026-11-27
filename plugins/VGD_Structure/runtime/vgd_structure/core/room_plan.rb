module VGD
  module Structure
    # Phòng của tầng (H8): nhóm ô lưới liền nhau do người dùng chọn (level['rooms'], Levels.rooms!). Logic thuần.
    # Phòng cho tên + diện tích hiện trên mặt bằng và thống kê, và lớp hoàn thiện sàn / trần RIÊNG của phòng (thay lớp chung của tầng cho các ô của phòng).
    # Vì phòng là tập ô nên đường biên phòng luôn trùng cạnh ô: sàn, trần chia theo ô đã đúng biên phòng, không cần cắt thêm.
    module RoomPlan
      # {mã ô => [mã phòng, phòng]} của tầng.
      def self.by_cell(level)
        (level['rooms'] || {}).each_with_object({}) { |(id, room), h| room['cells'].each { |c| h[c] = [id, room] } }
      end

      # Trả về {level:, items: [...], issues: [...]}. Mỗi mục: ref, name, cells, rects ([[min, max]] từng ô), label (tâm ô lớn nhất, để đặt nhãn), area_grid (m2, theo ô lưới),
      # floor_area (m2, tổng diện tích sàn kết cấu của các ô có sàn, nil nếu phòng chưa có sàn nào), floor_layers, ceiling_layers.
      # slab_items: mục của SlabPlan.plan (nếu có) để tính floor_area và cảnh báo ô chưa chọn sàn.
      def self.plan(grid, levels, level_id, slab_items = nil)
        level = Levels.find(levels, level_id) or raise ArgumentError, 'Tầng không tồn tại.'
        cells = Grid.cells(grid).each_with_object({}) { |c, h| h[c[:ref]] = c }
        slabs = (slab_items || []).each_with_object({}) { |i, h| h[i[:ref]] = i }
        issues = []
        items = (level['rooms'] || {}).map do |id, room|
          list = room['cells'].filter_map { |c| cells[c] }
          rects = list.map { |c| [c[:min], c[:max]] }
          area = list.sum { |c| (c[:max][0] - c[:min][0]) * (c[:max][1] - c[:min][1]) } / 1_000_000.0
          big = list.max_by { |c| (c[:max][0] - c[:min][0]) * (c[:max][1] - c[:min][1]) }
          floor = slab_items ? room['cells'].filter_map { |c| slabs[c] } : []
          if room['floor_layers']
            missing = room['cells'].reject { |c| level['picks']['slabs'].key?(c) }
            issues << "Phòng #{room['name']}: có lớp hoàn thiện sàn riêng nhưng ô #{missing.join(', ')} chưa chọn sàn." unless missing.empty?
          end
          if room['ceiling_layers']
            missing = room['cells'].reject { |c| level['picks']['ceilings'].key?(c) }
            issues << "Phòng #{room['name']}: có lớp cấu tạo trần riêng nhưng ô #{missing.join(', ')} chưa chọn trần." unless missing.empty?
          end
          {ref: id, name: room['name'], cells: room['cells'], rects: rects, label: [(big[:min][0] + big[:max][0]) / 2.0, (big[:min][1] + big[:max][1]) / 2.0].map { |v| v.round(1) },
           area_grid: area.round(3), floor_area: floor.empty? ? nil : floor.sum { |i| i[:area] }.round(3), floor_layers: room['floor_layers'], ceiling_layers: room['ceiling_layers']}
        end
        {level: level, items: items, issues: issues}
      end
    end
  end
end
