module VGD
  module Structure
    # Kế hoạch dầm của một tầng (đặc tả: SPEC mục 4 và 5). Logic thuần.
    # - Dầm treo dưới sàn tầng kế trên: đỉnh dầm = đáy sàn (cùng cao độ đỉnh cột), xuống `h`. Tầng trên cùng chỉ có sàn nên không có dầm.
    # - Dọc nhịp, hai đầu dầm dừng ở MẶT CỘT (cột được chọn ở giao điểm đó cùng tầng); chỗ không có cột thì dầm theo phương X chạy tới trục,
    #   dầm theo phương Y dừng ở mặt dầm X nếu có dầm X được chọn chạm giao điểm đó, nếu không thì tới trục.
    # - Vị trí theo phương vuông góc: auto (dầm trên trục biên đầu "min", biên cuối "max": mặt ngoài tiếp giáp trục biên; nhịp giữa "center"),
    #   center (tâm trên trục), min (cạnh nhỏ tại trục), max (cạnh lớn tại trục).
    module BeamPlan
      EPS = 1e-6
      MIN_LENGTH = 100.0

      Error = Class.new(ArgumentError)

      def self.plan(grid, types, beam_types, levels, level_id)
        level = Levels.find(levels, level_id) or raise Error, 'Tầng không tồn tại.'
        above = Levels.next_of(levels, level_id)
        raise Error, "Tầng “#{level['name']}” là tầng trên cùng, chỉ có sàn nên không có dầm." unless above
        column_plan = ColumnPlan.plan(grid, types, levels, level_id)
        z_top = column_plan[:z1]
        default_type = BeamTypes.find(beam_types, level['beam_type']) || beam_types.first
        spans = Grid.spans(grid).each_with_object({}) { |sp, h| h[sp[:ref]] = sp }
        columns = column_plan[:items].each_with_object({}) { |c, h| h[c[:ref]] = c }
        picks = level['picks']['beams']
        # Lượt 1: kích thước và vị trí vuông góc của từng dầm.
        beams = spans.each_with_object([]) do |(ref, span), out|
          pick = picks[ref] or next
          type = pick['type'] ? BeamTypes.find(beam_types, pick['type']) : default_type
          mode = mode(pick['p'], span[:side])
          axis = span[:dir] == 'x' ? span[:from][1] : span[:from][0]
          center = case mode
                   when 'min' then axis + type['w'] / 2.0
                   when 'max' then axis - type['w'] / 2.0
                   else axis
                   end
          bottom = (z_top - type['h']).round(1)
          raise Error, "Dầm #{type['name']} cao #{type['h'].round} mm không lọt dưới chiều cao tầng “#{level['name']}” (#{column_plan[:height]} mm)." if bottom <= level['elevation'] + EPS
          out << {ref: ref, span: span, type: type, mode: mode, center: center.round(2), w: type['w'], h: type['h'], z_top: z_top, z_bottom: bottom}
        end
        x_beams_at = Hash.new { |h, k| h[k] = [] } # nút -> các dầm X chạm nút
        beams.select { |b| b[:span][:dir] == 'x' }.each { |b| [b[:span][:from_ref], b[:span][:to_ref]].each { |n| x_beams_at[n] << b } }
        items = []
        issues = []
        beams.each do |b|
          span = b[:span]
          dir = span[:dir]
          a = dir == 'x' ? span[:from][0] : span[:from][1]
          z = dir == 'x' ? span[:to][0] : span[:to][1]
          start = end_of(span[:from_ref], dir, true, a, columns, x_beams_at)
          finish = end_of(span[:to_ref], dir, false, z, columns, x_beams_at)
          length = (finish - start).round(2)
          if length < MIN_LENGTH
            issues << "Dầm #{ref_label(span)}: khoảng hở giữa hai đầu chỉ #{length} mm, bỏ qua."
            next
          end
          min, max = dir == 'x' ? [[start, b[:center] - b[:w] / 2.0], [finish, b[:center] + b[:w] / 2.0]] : [[b[:center] - b[:w] / 2.0, start], [b[:center] + b[:w] / 2.0, finish]]
          items << {ref: b[:ref], dir: dir, type_id: b[:type]['id'], type_name: b[:type]['name'], w: b[:w], h: b[:h], length: length, start: start.round(2), finish: finish.round(2), center: b[:center],
                    min: min.map { |v| v.round(2) }, max: max.map { |v| v.round(2) }, mode: b[:mode], placement: span[:placement], z_top: b[:z_top], z_bottom: b[:z_bottom]}
        end
        x0, y0, x1, y1 = Grid.bounds(grid)
        items.each do |i|
          issues << "Dầm #{label(i)} nhô ra ngoài khung lưới (tâm đặt trên trục biên)." if i[:min][0] < x0 - EPS || i[:max][0] > x1 + EPS || i[:min][1] < y0 - EPS || i[:max][1] > y1 + EPS
        end
        overlaps(items.map { |i| [i[:min], i[:max], i] }).each { |a, c| issues << "Dầm #{label(a)} và #{label(c)} chồng lên nhau." }
        column_boxes = column_plan[:items].map { |c| [[c[:center][0] - c[:w] / 2.0, c[:center][1] - c[:d] / 2.0], [c[:center][0] + c[:w] / 2.0, c[:center][1] + c[:d] / 2.0], c] }
        beam_boxes = items.map { |i| [i[:min], i[:max], i] }
        beam_boxes.each do |bb|
          column_boxes.each do |cb|
            issues << "Dầm #{label(bb[2])} chồng lên cột #{cb[2][:ref]}." if rects_overlap?(bb, cb)
          end
        end
        {level: level, next_level: above, z_top: z_top, items: items, issues: issues, columns_height: column_plan[:height]}
      end

      def self.mode(chosen, side)
        return chosen if chosen && chosen != 'auto'
        side || 'center'
      end

      # Tọa độ đầu dầm dọc phương dầm: mặt cột nếu có cột ở nút; nếu không: dầm X tới trục; dầm Y dừng ở mặt dầm X chạm nút (nếu có), không thì tới trục.
      def self.end_of(node, dir, is_start, axis_coord, columns, x_beams_at)
        col = columns[node]
        if col
          center = dir == 'x' ? col[:center][0] : col[:center][1]
          half = (dir == 'x' ? col[:w] : col[:d]) / 2.0
          return is_start ? center + half : center - half
        end
        return axis_coord if dir == 'x' || x_beams_at[node].empty?
        faces = x_beams_at[node].map { |xb| is_start ? xb[:center] + xb[:w] / 2.0 : xb[:center] - xb[:w] / 2.0 }
        is_start ? faces.max : faces.min
      end

      def self.ref_label(span)
        span[:ref]
      end

      def self.label(item)
        item[:ref]
      end

      def self.rects_overlap?(a, b)
        a[0][0] < b[1][0] - EPS && b[0][0] < a[1][0] - EPS && a[0][1] < b[1][1] - EPS && b[0][1] < a[1][1] - EPS
      end

      def self.overlaps(boxes)
        sorted = boxes.sort_by { |b| b[0][0] }
        pairs = []
        sorted.each_with_index do |a, ai|
          (ai + 1...sorted.size).each do |bi|
            b = sorted[bi]
            break if b[0][0] >= a[1][0] - EPS
            pairs << [a[2], b[2]] if rects_overlap?(a, b)
          end
        end
        pairs
      end
    end
  end
end
