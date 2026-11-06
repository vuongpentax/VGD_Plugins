# Chọn đối tượng theo khung hoặc nét quét trên màn hình. Ruby thuần (không gọi SketchUp API) nên test được ngoài SketchUp.
# Mỗi đối tượng là bao lồi (hull) của các điểm màn hình [x, y] của hộp bao của nó; hull thật sát hình hơn hộp chữ nhật bao
# (tấm xiên nhìn nghiêng không bị chọn nhầm ở góc trống của hộp bao).
module VGD_Cabinet_Draw
  module ScreenPick
    extend self

    # Khung [x0, y0, x1, y1] chuẩn hóa (x0 <= x1, y0 <= y1) từ hai góc kéo bất kỳ.
    def rect(x0, y0, x1, y1)
      [[x0, x1].min, [y0, y1].min, [x0, x1].max, [y0, y1].max]
    end

    # Bao lồi (ngược chiều kim đồng hồ) của danh sách điểm [x, y]; bỏ điểm trùng. Một điểm → [điểm], hai điểm → đoạn.
    def hull(points)
      pts = points.map { |x, y| [x.to_f, y.to_f] }.uniq.sort
      return pts if pts.length <= 2
      cross = ->(o, a, b) { (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]) }
      lower = pts.each_with_object([]) do |p, out|
        out.pop while out.length >= 2 && cross.call(out[-2], out[-1], p) <= 0
        out << p
      end
      upper = pts.reverse.each_with_object([]) do |p, out|
        out.pop while out.length >= 2 && cross.call(out[-2], out[-1], p) <= 0
        out << p
      end
      lower[0...-1] + upper[0...-1]
    end

    # Mọi điểm nằm trong khung (khung kéo từ trái sang phải: chỉ chọn đối tượng nằm TRỌN trong khung).
    def inside_rect?(points, box)
      points.all? { |x, y| x >= box[0] && x <= box[2] && y >= box[1] && y <= box[3] }
    end

    # Hull chạm hoặc nằm trong khung (khung kéo từ phải sang trái: chọn mọi đối tượng CHẠM khung).
    def hull_touches_rect?(hull, box)
      convex_overlap?(hull, [[box[0], box[1]], [box[2], box[1]], [box[2], box[3]], [box[0], box[3]]])
    end

    # Hull chạm điểm point trong dung sai margin (px): click chọn một đối tượng.
    def hull_touches_point?(hull, point, margin = 0.0)
      convex_overlap?(hull, [point], margin)
    end

    # Nét quét (danh sách điểm màn hình) có đi qua hull không (dung sai margin px). Nét một điểm vẫn tính.
    def touched_by_path?(hull, path, margin = 0.0)
      return false if path.empty?
      return hull_touches_point?(hull, path.first, margin) if path.length == 1
      path.each_cons(2).any? { |a, b| convex_overlap?(hull, [a, b], margin) }
    end

    # Hai đa giác lồi (điểm, đoạn hoặc đa giác) có chạm nhau không, cách nhau không quá margin: định lý trục phân cách.
    def convex_overlap?(a, b, margin = 0.0)
      return false if a.empty? || b.empty?
      axes = edge_normals(a) + edge_normals(b) + [[1.0, 0.0], [0.0, 1.0]]
      axes.none? do |ax, ay|
        pa = a.map { |x, y| x * ax + y * ay }
        pb = b.map { |x, y| x * ax + y * ay }
        pa.max + margin < pb.min || pb.max + margin < pa.min
      end
    end

    # Pháp tuyến đơn vị của các cạnh (đoạn thẳng: một cạnh). Điểm: không có cạnh.
    def edge_normals(poly)
      return [] if poly.length < 2
      edges = poly.length == 2 ? [[poly[0], poly[1]]] : poly.each_index.map { |i| [poly[i], poly[(i + 1) % poly.length]] }
      edges.filter_map do |p, q|
        dx = q[0] - p[0]
        dy = q[1] - p[1]
        len = Math.sqrt(dx * dx + dy * dy)
        len < 1e-12 ? nil : [-dy / len, dx / len]
      end
    end
  end
end
