module VGD
  module Structure
    # Hình học MẶT CẮT 2D từ hình thật (logic thuần, không đụng SketchUp): cắt các MẶT 3D bằng mặt phẳng đứng đi qua đoạn a-b trên mặt bằng, nối các đoạn cắt thành
    # đường viền (phần bị cắt), và chiếu các CẠNH nằm phía sau mặt cắt (trong tầm nhìn) lên mặt cắt. Mọi tọa độ mm.
    #   Hệ tọa độ mặt cắt: s = khoảng cách dọc đường cắt tính từ a, z = cao độ; t = khoảng cách vuông góc (dương về phía pháp tuyến trái của a->b).
    #   Hướng nhìn: dir = 1 nhìn về phía t > 0 (pháp tuyến trái), dir = -1 nhìn về phía t < 0. Phần "phía sau" là dir * t trong [0, depth].
    #   mặt: {'outer' => [[x, y, z]...], 'loops' => [[[x, y, z]...]...] (lỗ)}; cạnh: [[x, y, z], [x, y, z]].
    module SectionGeometry
      EPS = 1e-6
      JOIN_TOL = 0.5 # mm: hai đầu đoạn cách nhau không quá mức này thì nối làm một điểm

      Plane = Struct.new(:a, :ux, :uy, :nx, :ny, :length, :dir, :depth)

      # a, b: hai đầu đường cắt trên mặt bằng; dir: 1 | -1; depth: tầm nhìn (mm) phía sau mặt cắt.
      def self.plane(a, b, dir, depth)
        len = Math.hypot(b[0] - a[0], b[1] - a[1])
        raise ArgumentError, 'Đường cắt quá ngắn.' if len < 1.0
        ux = (b[0] - a[0]) / len
        uy = (b[1] - a[1]) / len
        Plane.new(a, ux, uy, -uy, ux, len, dir == -1 ? -1 : 1, depth.to_f)
      end

      # [s, t, z] của điểm 3D.
      def self.local(plane, p)
        dx = p[0] - plane.a[0]
        dy = p[1] - plane.a[1]
        [dx * plane.ux + dy * plane.uy, dx * plane.nx + dy * plane.ny, p[2]]
      end

      # Phần mặt phẳng t = 0 nằm trong các mặt: danh sách đoạn [[s0, z0], [s1, z1]].
      def self.cut_faces(plane, faces)
        faces.flat_map { |face| cut_face(plane, face) }
      end

      def self.cut_face(plane, face)
        loops = [face['outer']] + (face['loops'] || [])
        points = []
        loops.each do |ring|
          pts = ring.map { |p| local(plane, p) }
          pts.each_with_index do |p, i|
            q = pts[(i + 1) % pts.size]
            next unless (p[1] >= 0) != (q[1] >= 0) # nửa mở: đỉnh nằm đúng trên mặt phẳng tính về phía t >= 0, không đếm hai lần
            k = (0 - p[1]) / (q[1] - p[1])
            points << [p[0] + (q[0] - p[0]) * k, p[2] + (q[2] - p[2]) * k]
          end
        end
        return [] if points.size < 2
        # các giao điểm nằm trên một đường thẳng (mặt cắt mặt phẳng của mặt): sắp theo s rồi z, ghép từng cặp (chẵn - lẻ) thành đoạn nằm TRONG mặt
        points.sort_by! { |s, z| [s, z] }
        points.each_slice(2).filter_map { |a, b| b && (a[0] - b[0]).abs + (a[1] - b[1]).abs > EPS ? [a, b] : nil }
      end

      # Nối các đoạn thành đường viền: trả về [{pts: [[s, z]...], closed: true | false}]. Hai đầu cách nhau không quá JOIN_TOL được coi là một điểm.
      def self.loops(segments)
        cell = ->(p) { [(p[0] / JOIN_TOL).floor, (p[1] / JOIN_TOL).floor] }
        grid = Hash.new { |h, k| h[k] = [] }
        segments.each_with_index { |(a, b), i| grid[cell.call(a)] << [i, 0]; grid[cell.call(b)] << [i, 1] }
        near = lambda do |tip, used|
          cx, cy = cell.call(tip)
          (-1..1).each do |dx|
            (-1..1).each do |dy|
              grid[[cx + dx, cy + dy]].each do |i, e|
                next if used[i]
                q = segments[i][e]
                return [i, e] if Math.hypot(q[0] - tip[0], q[1] - tip[1]) <= JOIN_TOL
              end
            end
          end
          nil
        end
        used = {}
        out = []
        segments.each_with_index do |seg, i|
          next if used[i]
          used[i] = true
          chain = [seg[0], seg[1]]
          [true, false].each do |forward| # kéo dài ở hai đầu
            loop do
              tip = forward ? chain.last : chain.first
              nxt = near.call(tip, used)
              break unless nxt
              used[nxt[0]] = true
              other = segments[nxt[0]][1 - nxt[1]]
              forward ? chain << other : chain.unshift(other)
            end
          end
          closed = chain.size > 2 && Math.hypot(chain.first[0] - chain.last[0], chain.first[1] - chain.last[1]) <= JOIN_TOL
          chain.pop if closed
          out << {pts: chain.map { |x, z| [x.round(1), z.round(1)] }, closed: closed}
        end
        out
      end

      # Cạnh nằm phía sau mặt cắt (trong tầm nhìn): cắt cạnh theo khoảng 0 <= dir * t <= depth rồi chiếu lên (s, z). Trả về [[[s0, z0], [s1, z1]]...].
      def self.beyond(plane, edges)
        edges.filter_map do |p, q|
          a = local(plane, p)
          b = local(plane, q)
          ta = a[1] * plane.dir
          tb = b[1] * plane.dir
          if (tb - ta).abs < EPS # cạnh song song với mặt cắt
            next unless ta >= 0 && ta <= plane.depth
            k0 = 0.0
            k1 = 1.0
          else
            k0, k1 = [(0 - ta) / (tb - ta), (plane.depth - ta) / (tb - ta)].minmax
            k0 = [k0, 0.0].max
            k1 = [k1, 1.0].min
            next if k0 >= k1
          end
          a2 = [a[0] + (b[0] - a[0]) * k0, a[2] + (b[2] - a[2]) * k0]
          b2 = [a[0] + (b[0] - a[0]) * k1, a[2] + (b[2] - a[2]) * k1]
          next if (a2[0] - b2[0]).abs + (a2[1] - b2[1]).abs < EPS
          [[a2[0].round(1), a2[1].round(1)], [b2[0].round(1), b2[1].round(1)]]
        end
      end
    end
  end
end
