module VGD
  module Structure
    # Kế hoạch cầu thang (logic thuần, không đụng SketchUp). Đi từ cao độ z0 (mặt sàn kết cấu tầng dưới) đến z1 (mặt sàn kết cấu tầng trên).
    #   Dạng 'straight': một vế thẳng từ a đến b.
    #   Dạng 'L' / 'U': vế 1 từ a đến c (đầu chiếu nghỉ), chiếu nghỉ vuông (cạnh = bề rộng vế), vế 2 rẽ về phía điểm b (chữ L: vuông góc, dài theo
    #   khoảng cách tới b; chữ U: song song, đi ngược lại, dài bằng vế 1). Chỉ b chọn phía rẽ.
    #   Số bậc N = ceil(cao tầng / cao bậc tối đa), cao bậc = cao tầng / N. Vế 1 và vế 2 chia N bậc (vế 1 nhận phần làm tròn lên).
    #   Mỗi bậc và chiếu nghỉ là khối đặc từ đáy (z0) đến mặt của nó. Lan can tạm chưa làm (không có chi tiết lan can).
    #   Hệ tọa độ phần tử: s = dọc theo vế 1 (từ a), t = vuông góc (dương về phía trái của a -> c).
    module StairPlan
      Error = Class.new(ArgumentError)
      MIN_RUN = 600.0          # chiều dài mỗi vế tối thiểu (mm)
      MIN_RISE = 120.0         # cao cần lên tối thiểu (mm)
      POST_SPACING = 1000.0    # khoảng cách cột lan can (mm), dùng khi có lan can
      SIDES = {'left' => 1, 'right' => -1}.freeze
      SHAPES = %w[straight L U].freeze

      # shape: 'straight' | 'L' | 'U'. mid: đầu chiếu nghỉ (chỉ dùng cho L, U). sides: lan can (mặc định cả hai bên, dạng thẳng).
      def self.plan(a, b, type, z0, z1, sides = %w[left right], shape: 'straight', mid: nil)
        raise Error, 'Điểm đầu và điểm cuối cầu thang không hợp lệ.' unless point?(a) && point?(b)
        raise Error, 'Cao độ cầu thang không hợp lệ.' unless [z0, z1].all? { |v| v.is_a?(Numeric) && v.to_f.finite? }
        raise Error, 'Dạng cầu thang không hợp lệ.' unless SHAPES.include?(shape)
        rise = z1.to_f - z0.to_f
        raise Error, "Cầu thang phải lên cao ít nhất #{MIN_RISE.to_i} mm." if rise < MIN_RISE
        count = [(rise / type['riser']).ceil, 1].max
        riser = rise / count
        return straight(a, b, type, z0.to_f, count, riser, sides) if shape == 'straight'
        turn(a, mid, b, shape, type, z0.to_f, count, riser)
      end

      def self.straight(a, b, type, z0, count, riser, sides)
        run = Math.hypot(b[0] - a[0], b[1] - a[1])
        raise Error, "Vế cầu thang quá ngắn (ít nhất #{MIN_RUN.to_i} mm)." if run < MIN_RUN
        tread = run / count
        raise Error, "Bản bậc #{tread.round(0)} mm nhỏ hơn mức tối thiểu #{type['tread'].to_i} mm: kéo dài vế hoặc giảm số bậc." if tread < type['tread']
        width = type['width']
        at = frame(a, b)
        steps = (0...count).map do |i|
          s0, s1 = i * tread, (i + 1) * tread
          {poly: [at.call(s0, -width / 2), at.call(s1, -width / 2), at.call(s1, width / 2), at.call(s0, width / 2)], z0: z0.round(1), z1: (z0 + (i + 1) * riser).round(1)}
        end
        surface = ->(s) { z0 + ([(s / tread).floor, count - 1].min + 1) * riser }
        rails = rails_for(at, sides, width, type['rail'], run, surface)
        {shape: 'straight', run: run.round(1), run2: nil, rise: (count * riser).round(1), count: count, riser: riser.round(2), tread: tread.round(1), width: width,
         footprint: [at.call(0, -width / 2), at.call(run, -width / 2), at.call(run, width / 2), at.call(0, width / 2)], steps: steps, rails: rails}
      end

      # Lan can (tạm chưa dùng từ giao diện): tay vịn nối hai đầu, cột đứng cách POST_SPACING.
      def self.rails_for(at, sides, width, rail, run, surface)
        rails = []
        sides.each do |side|
          sign = SIDES.fetch(side) { raise Error, "Phía lan can “#{side}” không hợp lệ." }
          t = sign * width / 2
          rails << {side: side, kind: 'handrail', from: at.call(0, t) + [(surface.call(0) + rail).round(1)], to: at.call(run, t) + [(surface.call(run) + rail).round(1)]}
          posts = (0..(run / POST_SPACING).floor).map { |k| k * POST_SPACING }
          posts << run unless posts.last >= run - 1e-6
          posts.each do |s|
            base = surface.call(s).round(1)
            rails << {side: side, kind: 'post', from: at.call(s, t) + [base], to: at.call(s, t) + [(base + rail).round(1)]}
          end
        end
        rails
      end

      # Chữ L / U: vế 1 (a -> mid), chiếu nghỉ, vế 2 rẽ về phía b.
      def self.turn(a, mid, b, shape, type, z0, count, riser)
        raise Error, 'Thiếu đầu chiếu nghỉ của cầu thang chữ ' + shape + '.' unless point?(mid)
        run1 = Math.hypot(mid[0] - a[0], mid[1] - a[1])
        raise Error, "Vế 1 quá ngắn (ít nhất #{MIN_RUN.to_i} mm)." if run1 < MIN_RUN
        width = type['width']
        half = width / 2
        at = frame(a, mid)
        t_side = (b[0] - a[0]) * at.normal[0] + (b[1] - a[1]) * at.normal[1]  # khoảng cách có dấu của b về phía trái vế 1
        raise Error, 'Chọn điểm cuối về phía rẽ (không thẳng hàng với vế 1).' if t_side.abs < half + MIN_RUN
        sign = t_side > 0 ? 1 : -1
        n1 = (count + 1) / 2
        n2 = count - n1
        raise Error, 'Cầu thang chữ L / U cần ít nhất 2 bậc (tăng cao tầng hoặc đổi loại).' if n2 < 1
        run2 = shape == 'L' ? t_side.abs - half : run1
        raise Error, "Vế 2 quá ngắn (ít nhất #{MIN_RUN.to_i} mm)." if run2 < MIN_RUN
        d1 = run1 / n1
        d2 = run2 / n2
        min_tread = [d1, d2].min
        raise Error, "Bản bậc #{min_tread.round(0)} mm nhỏ hơn mức tối thiểu #{type['tread'].to_i} mm: kéo dài vế hoặc giảm số bậc." if min_tread < type['tread']
        z_land = z0 + n1 * riser
        pt = ->(s, t) { at.call(s, sign * t) }
        steps = []
        n1.times do |i|
          steps << {poly: [pt.call(i * d1, -half), pt.call((i + 1) * d1, -half), pt.call((i + 1) * d1, half), pt.call(i * d1, half)], z0: z0.round(1), z1: (z0 + (i + 1) * riser).round(1)}
        end
        landing_top = z_land.round(1)
        if shape == 'L'
          steps << {poly: [pt.call(run1, -half), pt.call(run1 + width, -half), pt.call(run1 + width, half), pt.call(run1, half)], z0: z0.round(1), z1: landing_top, landing: true}
          n2.times do |j|
            steps << {poly: [pt.call(run1, half + j * d2), pt.call(run1 + width, half + j * d2), pt.call(run1 + width, half + (j + 1) * d2), pt.call(run1, half + (j + 1) * d2)],
                      z0: z0.round(1), z1: (z_land + (j + 1) * riser).round(1)}
          end
          footprint = [pt.call(0, -half), pt.call(run1 + width, -half), pt.call(run1 + width, half + run2), pt.call(run1, half + run2), pt.call(run1, half), pt.call(0, half)]
        else
          steps << {poly: [pt.call(run1, -half), pt.call(run1 + width, -half), pt.call(run1 + width, 3 * half), pt.call(run1, 3 * half)], z0: z0.round(1), z1: landing_top, landing: true}
          n2.times do |j|
            steps << {poly: [pt.call(run1 - (j + 1) * d2, half), pt.call(run1 - j * d2, half), pt.call(run1 - j * d2, 3 * half), pt.call(run1 - (j + 1) * d2, 3 * half)],
                      z0: z0.round(1), z1: (z_land + (j + 1) * riser).round(1)}
          end
          footprint = [pt.call(0, -half), pt.call(run1 + width, -half), pt.call(run1 + width, 3 * half), pt.call(0, 3 * half)]
        end
        {shape: shape, run: run1.round(1), run2: run2.round(1), rise: (count * riser).round(1), count: count, riser: riser.round(2), tread: min_tread.round(1), width: width,
         footprint: footprint.map { |x, y| [x.round(1), y.round(1)] }, steps: steps, rails: []}
      end

      # Hệ tọa độ dọc theo a -> u (u là điểm định hướng): at.call(s, t) cho điểm trên mặt bằng; at.normal là pháp tuyến trái.
      def self.frame(a, u_point)
        run = Math.hypot(u_point[0] - a[0], u_point[1] - a[1])
        ux, uy = (u_point[0] - a[0]) / run, (u_point[1] - a[1]) / run
        nx, ny = -uy, ux
        f = ->(s, t) { [(a[0] + ux * s + nx * t).round(1), (a[1] + uy * s + ny * t).round(1)] }
        f.define_singleton_method(:normal) { [nx, ny] }
        f
      end

      def self.point?(p)
        p.is_a?(Array) && p.size == 2 && p.all? { |v| v.is_a?(Numeric) && v.to_f.finite? }
      end
    end
  end
end
