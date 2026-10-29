module VGD_Cabinet_Draw
  # Bảng màu trạng thái dùng chung cho mọi công cụ:
  #   body = xem trước (cyan), front = mặt trước / mặt đang xử lý (cam nhạt),
  #   override = đối tượng đang có cấu hình riêng (xanh lá), target = đích đang chọn (xanh lá lục),
  #   cutter = dao cắt (hồng đỏ).
  class Preview
    # Màu nhạt kiểu X-ray: nhìn xuyên được, không che hình tủ phía sau. hover luôn là màu vàng nét đứt.
    COLORS = {
      body: Sketchup::Color.new(180, 137, 99, 55),      # đồng VGD #B48963
      front: Sketchup::Color.new(204, 122, 72, 60),
      override: Sketchup::Color.new(80, 114, 71, 60),   # success #507247
      target: Sketchup::Color.new(70, 140, 120, 60),
      cutter: Sketchup::Color.new(167, 61, 54, 75),     # danger #A73D36
      door: Sketchup::Color.new(96, 128, 168, 55),
      glass: Sketchup::Color.new(140, 190, 208, 45),
      drawer: Sketchup::Color.new(138, 108, 168, 60),
      hover: Sketchup::Color.new(220, 175, 90, 95)
    }.freeze
    # Nét hướng dẫn và khung chữ dùng đồng đậm #8E6B4C: thấy rõ trên nền trắng lẫn vân gỗ.
    GUIDE = Sketchup::Color.new(142, 107, 76, 255)
    EDGE = Sketchup::Color.new(41, 43, 45, 150)         # nét than #292B2D của bộ icon
    EDGE_HOVER = Sketchup::Color.new(180, 137, 99, 235)

    # Chữ nét (stroke font) vẽ trong không gian 3D để chữ nằm song song mặt tủ và xoay theo góc nhìn.
    # Lưới 2 x 4 đơn vị (rộng x cao); mỗi ký tự là danh sách các đường gấp khúc.
    GLYPHS = {
      '0' => [[[0, 0], [2, 0], [2, 4], [0, 4], [0, 0]]],
      '1' => [[[1, 0], [1, 4], [0, 3]]],
      '2' => [[[0, 4], [2, 4], [2, 2], [0, 2], [0, 0], [2, 0]]],
      '3' => [[[0, 4], [2, 4], [2, 0], [0, 0]], [[0, 2], [2, 2]]],
      '4' => [[[0, 4], [0, 2], [2, 2]], [[2, 4], [2, 0]]],
      '5' => [[[2, 4], [0, 4], [0, 2], [2, 2], [2, 0], [0, 0]]],
      '6' => [[[2, 4], [0, 4], [0, 0], [2, 0], [2, 2], [0, 2]]],
      '7' => [[[0, 4], [2, 4], [2, 0]]],
      '8' => [[[0, 0], [2, 0], [2, 4], [0, 4], [0, 0]], [[0, 2], [2, 2]]],
      '9' => [[[2, 2], [0, 2], [0, 4], [2, 4], [2, 0], [0, 0]]],
      '.' => [[[0.4, 0], [0.8, 0], [0.8, 0.4], [0.4, 0.4], [0.4, 0]]],
      'x' => [[[0, 1], [2, 3]], [[0, 3], [2, 1]]],
      '×' => [[[0, 1], [2, 3]], [[0, 3], [2, 1]]],
      '-' => [[[0, 2], [2, 2]]],
      'm' => [[[0, 0], [0, 2.4], [0.7, 2.8], [1, 2.4], [1, 0]], [[1, 2.4], [1.7, 2.8], [2, 2.4], [2, 0]]],
      ' ' => []
    }.freeze
    GLYPH_WIDTH = { '.' => 1.2, ' ' => 1.2, '1' => 2.0, '-' => 2.0 }.freeze
    GLYPH_GAP = 1.0

    def initialize
      @polygons = []
      @lines = []
      @labels = []
      @texts = []
    end

    # Hộp chữ có khung nằm trong mặt phẳng (xaxis, zaxis) quanh center (điểm thế giới).
    # pixels: chiều cao chữ mong muốn trên màn hình; max_height: chiều cao tối đa (đơn vị SketchUp) để chữ vừa chỗ chứa.
    def add_text_box(center, text, xaxis, zaxis, pixels: 14, max_height: nil, height: nil)
      @texts << { center: center.is_a?(Geom::Point3d) ? center : Geom::Point3d.new(center), text: text.to_s,
                  x: xaxis.normalize, z: zaxis.normalize, pixels: pixels, max_height: max_height, height: height }
    end

    def text_count
      @texts.length
    end

    def text_boxes
      @texts
    end

    # Các đường nét của chuỗi, tính trong hệ (u, v) đơn vị lưới, gốc ở giữa chuỗi. Trả về [đường nét, chiều rộng].
    def self.layout_text(text)
      cursor = 0.0
      strokes = []
      text.to_s.each_char do |ch|
        glyph = GLYPHS[ch] || GLYPHS[ch.downcase] || []
        glyph.each { |line| strokes << line.map { |u, v| [cursor + u, v] } }
        cursor += (GLYPH_WIDTH[ch] || 2.0) + GLYPH_GAP
      end
      width = [cursor - GLYPH_GAP, 0.0].max
      [strokes.map { |line| line.map { |u, v| [u - width / 2.0, v - 2.0] } }, width]
    end

    def add_polygon(points, kind = :body)
      @polygons << [points.map { |p| p.is_a?(Geom::Point3d) ? p : Geom::Point3d.new(p) }, kind]
    end

    def add_line(a, b, kind = :body)
      @lines << [[a, b].map { |p| p.is_a?(Geom::Point3d) ? p : Geom::Point3d.new(p) }, kind]
    end

    # Khối lăng trụ: đáy và đỉnh là hai đa giác cùng số điểm (đã ở hệ thế giới).
    def add_prism(bottom, top, kind = :body)
      add_polygon(bottom, kind)
      add_polygon(top, kind)
      bottom.each_index do |i|
        j = (i + 1) % bottom.length
        add_polygon([bottom[i], bottom[j], top[j], top[i]], kind)
      end
    end

    # Lăng trụ đẩy theo trục Y: polygon [[x, z]...], mặt đầu ở y, mặt cuối ở y - depth (hướng ra phía trước tủ).
    def add_prism_y(polygon, y, depth, transform, kind = :body)
      front = polygon.map { |x, z| Geom::Point3d.new(x, y, z).transform(transform) }
      back = polygon.map { |x, z| Geom::Point3d.new(x, y - depth, z).transform(transform) }
      add_prism(front, back, kind)
    end

    # Nhãn chữ gắn vào một điểm thế giới (vẽ ở tọa độ màn hình).
    def add_label(point, text)
      @labels << [point.is_a?(Geom::Point3d) ? point : Geom::Point3d.new(point), text]
    end

    def polygon_count
      @polygons.length
    end

    def empty?
      @polygons.empty? && @lines.empty?
    end

    def draw(view)
      eye = view.camera.eye
      direction = view.camera.direction
      visible = @polygons.filter_map do |points, kind|
        next if points.any? { |point| (point - eye).dot(direction) <= 0 }
        screen = points.map { |point| p = view.screen_coords(point); Geom::Point3d.new(p.x, p.y, 0) }
        area = screen.each_index.sum { |i| a = screen[i]; b = screen[(i + 1) % screen.length]; a.x * b.y - b.x * a.y }
        next if area.abs < 0.01
        screen.reverse! if area < 0
        [points.sum { |p| p.distance(eye) } / points.length, screen, kind]
      end.sort_by { |entry| -entry[0] }
      visible.each do |_, points, kind|
        view.drawing_color = COLORS.fetch(kind, COLORS[:body])
        triangles = Geom.tesselate(points)
        view.draw2d(GL_TRIANGLES, triangles) unless triangles.empty?
      end
      view.line_width = 1
      view.line_stipple = ''
      view.drawing_color = EDGE
      visible.each { |_, points, kind| view.draw2d(GL_LINE_LOOP, points) unless kind == :hover }
      view.line_stipple = '-'
      view.drawing_color = EDGE_HOVER
      visible.each { |_, points, kind| view.draw2d(GL_LINE_LOOP, points) if kind == :hover }
      view.line_stipple = ''
      @lines.each do |points, kind|
        next if points.any? { |point| (point - eye).dot(direction) <= 0 }
        screen = points.map { |p| view.screen_coords(p) }
        if kind == :guide
          view.line_width = 2
          view.line_stipple = '-'
          view.drawing_color = GUIDE
        else
          view.line_width = 1
          view.line_stipple = ''
          view.drawing_color = kind == :cutter ? COLORS[:cutter] : EDGE
        end
        view.draw2d(GL_LINES, screen)
      end
      view.line_stipple = ''
      draw_texts(view, eye)
      @labels.each do |point, text|
        next if (point - eye).dot(direction) <= 0
        spot = view.screen_coords(point)
        Theme.draw_text(view, [spot.x + 6, spot.y - 16], text, color: Theme.color(:accent_strong), size: 10, bold: true)
      end
    ensure
      view.line_width = 1
      view.line_stipple = ''
    end

    # Hộp chữ kích thước theo chế độ sáng/tối của dialog.
    def text_background; Theme.color(:surface, 225); end
    def text_ink; Theme.color(:text); end
    def text_frame; Theme.color(:accent); end

    # Vẽ các hộp chữ: nền trắng + khung cam + chữ nét, tất cả nằm trong mặt phẳng của mặt tủ (không xoay theo màn hình).
    def draw_texts(view, eye)
      @texts.each do |entry|
        center = entry[:center]
        normal = entry[:x].cross(entry[:z])
        next if (eye - center).dot(normal) <= 0 # nhìn từ phía sau mặt tủ: không vẽ
        strokes, width = self.class.layout_text(entry[:text])
        next if strokes.empty?
        size = entry[:height]
        if size.nil?
          size = view.respond_to?(:pixels_to_model) ? view.pixels_to_model(entry[:pixels], center) : 25.mm
          size = [size, entry[:max_height]].min if entry[:max_height]
        end
        unit = size / 4.0
        point = lambda { |u, v| center.offset(entry[:x], u * unit).offset(entry[:z], v * unit) }
        pad = 1.2
        half = width / 2.0 + pad
        frame = [[-half, -2.0 - pad], [half, -2.0 - pad], [half, 2.0 + pad], [-half, 2.0 + pad]].map { |u, v| view.screen_coords(point.call(u, v)) }
        flat = frame.map { |p| Geom::Point3d.new(p.x, p.y, 0) }
        view.drawing_color = text_background
        view.draw2d(GL_QUADS, flat)
        view.line_width = 1
        view.line_stipple = ''
        view.drawing_color = text_frame
        view.draw2d(GL_LINE_LOOP, flat)
        view.line_width = 1
        view.drawing_color = text_ink
        strokes.each do |line|
          pts = line.map { |u, v| p = view.screen_coords(point.call(u, v)); Geom::Point3d.new(p.x, p.y, 0) }
          view.draw2d(GL_LINE_STRIP, pts)
        end
      end
    end
  end
end
