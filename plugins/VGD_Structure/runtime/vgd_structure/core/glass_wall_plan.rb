module VGD
  module Structure
    # Kế hoạch vách kính của tầng (H7): mỗi vách nằm trên một NHỊP lưới, gồm khung nhôm (khung bao + thanh đứng giữa) và các tấm kính. Logic thuần, đơn vị mm.
    # Dữ liệu: level['glass_walls'] = {mã => {'span', 'height', 'pane_max'}} (Levels.glass_walls!). Đáy vách ở mặt sàn kết cấu của tầng (như tường).
    # Khung bao: thanh ngang đáy và đỉnh chạy suốt nhịp, hai thanh đứng ở hai đầu; thanh đứng giữa chia đều n tấm sao cho mỗi tấm rộng không quá pane_max.
    module GlassWallPlan
      Error = Class.new(ArgumentError)
      FRAME_W = 50.0   # bề rộng nhìn thấy của thanh khung (mm)
      FRAME_D = 80.0   # bề sâu thanh khung, vuông góc mặt vách (mm)
      GLASS_T = 8.0    # bề dày tấm kính (mm)
      MIN_PANE = 100.0 # tấm kính nhỏ hơn mức này (rộng hoặc cao) thì bỏ vách

      # Trả về {level:, items: [...], issues: [...]}. Mỗi mục: ref, span, dir, a, b (hai đầu nhịp), length, height, z0, z1, count (số tấm), pane_w, pane_h,
      # frame [[s0, s1, za, zb]...] (hình chữ nhật khung trong mặt phẳng vách: s dọc nhịp từ a, z tuyệt đối), panes (cùng dạng), frame_length, frame_volume (m3), glass_area (m2), min, max (hộp bao mặt bằng).
      def self.plan(grid, levels, level_id)
        level = Levels.find(levels, level_id) or raise Error, 'Tầng không tồn tại.'
        spans = Grid.spans(grid).each_with_object({}) { |s, h| h[s[:ref]] = s }
        z0 = Levels.structure_top(level)
        issues = []
        items = (level['glass_walls'] || {}).filter_map do |ref, gw|
          span = spans[gw['span']]
          if span.nil?
            issues << "Vách kính #{ref}: nhịp #{gw['span']} không còn trên lưới, bỏ qua."
            next
          end
          item = layout(ref, span, gw['height'], gw['pane_max'], z0)
          issues << "Vách kính #{ref}: sau khi chia, tấm kính nhỏ hơn #{MIN_PANE.to_i} mm (nhịp quá ngắn hoặc vách quá thấp), bỏ qua." if item.nil?
          item
        end
        walls = (level['picks'] || {})['walls'] || {}
        items.each { |i| issues << "Vách kính #{i[:ref]} trùng nhịp #{i[:span]} đã chọn tường: hai phần tử chồng nhau." if walls.key?(i[:span]) }
        {level: level, items: items, issues: issues}
      end

      # Chia nhịp thành n tấm đều; nil nếu tấm kính nhỏ hơn MIN_PANE.
      def self.layout(ref, span, height, pane_max, z0)
        length = span[:length].to_f
        clear = length - 2 * FRAME_W
        pane_h = height - 2 * FRAME_W
        n = ((clear + FRAME_W) / (pane_max + FRAME_W)).ceil
        n = 1 if n < 1
        pane_w = (clear - (n - 1) * FRAME_W) / n
        return nil if pane_w < MIN_PANE || pane_h < MIN_PANE
        z1 = z0 + height
        panes = n.times.map { |k| s0 = FRAME_W + k * (pane_w + FRAME_W); [s0.round(2), (s0 + pane_w).round(2), (z0 + FRAME_W).round(2), (z1 - FRAME_W).round(2)] }
        mullions = (1...n).map { |k| [panes[k - 1][1], panes[k][0], panes[0][2], panes[0][3]] }
        frame = [[0.0, length, z0, (z0 + FRAME_W).round(2)], [0.0, length, (z1 - FRAME_W).round(2), z1], [0.0, FRAME_W, panes[0][2], panes[0][3]], [(length - FRAME_W).round(2), length, panes[0][2], panes[0][3]]] + mullions
        frame_length = 2 * length + (2 + n - 1) * pane_h
        a = span[:from]
        b = span[:to]
        half = FRAME_D / 2.0
        {ref: ref, span: span[:ref], dir: span[:dir], a: a, b: b, length: length.round(1), height: height, z0: z0, z1: z1.round(1), count: n, pane_w: pane_w.round(2), pane_h: pane_h.round(1), pane_max: pane_max,
         frame: frame, panes: panes, frame_length: frame_length.round(1), frame_volume: (FRAME_W * FRAME_D * frame_length / 1e9).round(5), glass_area: (n * pane_w * pane_h / 1e6).round(3),
         min: [[a[0], b[0]].min - (span[:dir] == 'y' ? half : 0), [a[1], b[1]].min - (span[:dir] == 'x' ? half : 0)].map { |v| v.round(2) },
         max: [[a[0], b[0]].max + (span[:dir] == 'y' ? half : 0), [a[1], b[1]].max + (span[:dir] == 'x' ? half : 0)].map { |v| v.round(2) }}
      end
    end
  end
end
