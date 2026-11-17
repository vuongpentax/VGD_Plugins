module VGD
  module Structure
    # Kế hoạch cột của một tầng: vị trí, kích thước, cao độ từng cột và các cảnh báo. Logic thuần (đặc tả: SPEC mục 4 và 5).
    #
    # Vị trí theo từng phương: auto (theo quy ước: trục biên đầu "min", trục biên cuối "max", trục giữa "center"),
    # center (tâm trên trục), min (cạnh nhỏ của cột nằm trên trục, cột lùi về phía tăng), max (cạnh lớn nằm trên trục, cột lùi về phía giảm).
    # Quy ước: cột biên tiếp giáp trục biên, cột giữa ở giữa, cột góc tiếp giáp cả hai trục biên, nên cột lọt trong khung lưới.
    module ColumnPlan
      MAX_COLUMNS = 5000
      EPS = 1e-6

      Error = Class.new(ArgumentError)

      # grid, types, levels đã chuẩn hóa. Trả về {level:, next_level:, height:, z0:, z1:, items: [...], issues: [...]}.
      def self.plan(grid, types, levels, level_id)
        level = Levels.find(levels, level_id) or raise Error, 'Tầng không tồn tại.'
        above = Levels.next_of(levels, level_id)
        raise Error, "Tầng “#{level['name']}” là tầng trên cùng, chỉ có sàn nên không có cột." unless above
        z0 = level['elevation']
        z1 = (above['elevation'] - above['slab_thickness']).round(1)
        height = (z1 - z0).round(1)
        raise Error, "Chiều cao cột tầng “#{level['name']}” chỉ #{height} mm (từ mặt sàn đến đáy sàn tầng “#{above['name']}”), cần ít nhất #{Levels::MIN_COLUMN_HEIGHT.to_i} mm." if height < Levels::MIN_COLUMN_HEIGHT
        default_type = ColumnTypes.find(types, level['column_type']) || types.first
        points = Grid.intersections(grid).each_with_object({}) { |i, h| h[i[:ref]] = i }
        x_last = grid['x_axes'].last['name']
        y_last = grid['y_axes'].last['name']
        x_first = grid['x_axes'].first['name']
        y_first = grid['y_axes'].first['name']
        items = []
        issues = []
        points.each do |ref, point| # theo thứ tự giao điểm của lưới
          pick = level['picks']['columns'][ref] or next
          type = pick['type'] ? ColumnTypes.find(types, pick['type']) : default_type
          modes = {'x' => mode(pick['x'], point[:xn] == x_first, point[:xn] == x_last), 'y' => mode(pick['y'], point[:yn] == y_first, point[:yn] == y_last)}
          cx = center(point[:x], type['w'], modes['x'])
          cy = center(point[:y], type['d'], modes['y'])
          items << {ref: ref, type_id: type['id'], type_name: type['name'], w: type['w'], d: type['d'], center: [cx.round(2), cy.round(2)], modes: modes,
                    placement: point[:placement], z0: z0, z1: z1, height: height}
        end
        # Cột TỰ DO (không theo lưới): đặt đúng tọa độ, xoay 0 hoặc 90 độ (xoay 90 thì đổi chỗ rộng và sâu).
        level['picks']['columns'].each do |ref, pick|
          free = pick['free'] or next
          type = pick['type'] ? ColumnTypes.find(types, pick['type']) : default_type
          w, d = free['rot'] == 90 ? [type['d'], type['w']] : [type['w'], type['d']]
          items << {ref: ref, type_id: type['id'], type_name: type['name'], w: w, d: d, center: [free['x'], free['y']], modes: {'x' => 'free', 'y' => 'free'}, placement: 'free', z0: z0, z1: z1, height: height}
        end
        raise Error, "Quá nhiều cột (#{items.size}); tối đa #{MAX_COLUMNS} mỗi lần dựng." if items.size > MAX_COLUMNS
        x0, y0, x1, y1 = Grid.bounds(grid)
        items.each do |item|
          next if item[:placement] == 'free' # cột tự do được phép nằm ngoài khung lưới
          min_x = item[:center][0] - item[:w] / 2.0
          max_x = item[:center][0] + item[:w] / 2.0
          min_y = item[:center][1] - item[:d] / 2.0
          max_y = item[:center][1] + item[:d] / 2.0
          issues << "Cột #{item[:ref]} nhô ra ngoài khung lưới (tâm đặt trên trục biên)." if min_x < x0 - EPS || max_x > x1 + EPS || min_y < y0 - EPS || max_y > y1 + EPS
        end
        overlaps(items).each { |a, b| issues << "Cột #{a[:ref]} và #{b[:ref]} chồng lên nhau." }
        {level: level, next_level: above, z0: z0, z1: z1, height: height, items: items, issues: issues}
      end

      def self.mode(chosen, first, last)
        return chosen if chosen && chosen != 'auto'
        return 'min' if first
        return 'max' if last
        'center'
      end

      def self.center(axis, size, mode)
        case mode
        when 'min' then axis + size / 2.0
        when 'max' then axis - size / 2.0
        else axis
        end
      end

      # Các cặp cột chồng nhau (quét theo cạnh trái, không so mọi cặp).
      def self.overlaps(items)
        boxes = items.map { |i| [i[:center][0] - i[:w] / 2.0, i[:center][0] + i[:w] / 2.0, i[:center][1] - i[:d] / 2.0, i[:center][1] + i[:d] / 2.0, i] }.sort_by(&:first)
        pairs = []
        boxes.each_with_index do |a, ai|
          (ai + 1...boxes.size).each do |bi|
            b = boxes[bi]
            break if b[0] >= a[1] - EPS
            pairs << [a[4], b[4]] if b[2] < a[3] - EPS && a[2] < b[3] - EPS
          end
        end
        pairs
      end
    end
  end
end
