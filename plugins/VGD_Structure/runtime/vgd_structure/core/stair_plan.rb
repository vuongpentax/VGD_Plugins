module VGD
  module Structure
    # Kế hoạch cầu thang THẲNG MỘT VẾ (logic thuần, không đụng SketchUp). Đầu dưới a, đầu trên b trên mặt bằng (mm), cao độ z0 (mặt sàn kết cấu tầng dưới)
    # đến z1 (mặt sàn kết cấu tầng trên).
    #   Số bậc N = ceil(cao tầng / cao bậc tối đa); cao bậc = cao tầng / N; bản bậc = chiều dài / N (không nhỏ hơn bản bậc tối thiểu).
    #   Mỗi bậc là một khối đặc từ đáy đến mặt bậc (phần thô, chưa có bản bậc riêng). Lan can chạy dọc hai cạnh (left: phía trái a -> b, right: phía phải),
    #   tay vịn cao `rail` tính từ mép bậc, cột đứng cách nhau POST_SPACING.
    #   Hệ tọa độ: s = dọc theo a -> b, t = vuông góc (dương về phía trái), z = cao độ tuyệt đối.
    module StairPlan
      Error = Class.new(ArgumentError)
      MIN_RUN = 600.0          # chiều dài vế tối thiểu (mm)
      MIN_RISE = 120.0         # chiều cao cần lên tối thiểu (mm): dưới mức này không phải cầu thang
      POST_SPACING = 1000.0    # khoảng cách cột lan can dọc cạnh (mm)
      SIDES = {'left' => 1, 'right' => -1}.freeze

      def self.plan(a, b, type, z0, z1, sides = %w[left right])
        raise Error, 'Điểm đầu và điểm cuối cầu thang không hợp lệ.' unless point?(a) && point?(b)
        raise Error, 'Cao độ cầu thang không hợp lệ.' unless [z0, z1].all? { |v| v.is_a?(Numeric) && v.to_f.finite? }
        run = Math.hypot(b[0] - a[0], b[1] - a[1])
        raise Error, "Vế cầu thang quá ngắn (ít nhất #{MIN_RUN.to_i} mm)." if run < MIN_RUN
        rise = z1.to_f - z0.to_f
        raise Error, "Cầu thang phải lên cao ít nhất #{MIN_RISE.to_i} mm." if rise < MIN_RISE
        count = [(rise / type["riser"]).ceil, 1].max
        riser = rise / count
        tread = run / count
        raise Error, "Bản bậc #{tread.round(0)} mm nhỏ hơn mức tối thiểu #{type['tread'].to_i} mm: kéo dài vế hoặc giảm số bậc." if tread < type['tread']
        width = type['width']
        ux, uy = (b[0] - a[0]) / run, (b[1] - a[1]) / run
        nx, ny = -uy, ux
        at = ->(s, t) { [(a[0] + ux * s + nx * t).round(1), (a[1] + uy * s + ny * t).round(1)] }
        steps = (0...count).map do |i|
          s0, s1 = i * tread, (i + 1) * tread
          top = (z0.to_f + (i + 1) * riser).round(1)
          {poly: [at.call(s0, -width / 2), at.call(s1, -width / 2), at.call(s1, width / 2), at.call(s0, width / 2)], z0: z0.to_f.round(1), z1: top}
        end
        surface = ->(s) { z0.to_f + ([(s / tread).floor, count - 1].min + 1) * riser } # mặt bậc tại vị trí s dọc vế
        rails = []
        sides.each do |side|
          sign = SIDES.fetch(side) { raise Error, "Phía lan can “#{side}” không hợp lệ." }
          t = sign * width / 2
          rail = type['rail']
          rails << {side: side, kind: 'handrail', from: at.call(0, t) + [(surface.call(0) + rail).round(1)], to: at.call(run, t) + [(surface.call(run) + rail).round(1)]}
          posts = (0..(run / POST_SPACING).floor).map { |k| k * POST_SPACING }
          posts << run unless posts.last >= run - 1e-6
          posts.each do |s|
            base = surface.call(s).round(1)
            rails << {side: side, kind: 'post', from: at.call(s, t) + [base], to: at.call(s, t) + [(base + rail).round(1)]}
          end
        end
        {run: run.round(1), rise: rise.round(1), count: count, riser: riser.round(2), tread: tread.round(1), width: width,
         footprint: [at.call(0, -width / 2), at.call(run, -width / 2), at.call(run, width / 2), at.call(0, width / 2)], steps: steps, rails: rails}
      end

      def self.point?(p)
        p.is_a?(Array) && p.size == 2 && p.all? { |v| v.is_a?(Numeric) && v.to_f.finite? }
      end
    end
  end
end
