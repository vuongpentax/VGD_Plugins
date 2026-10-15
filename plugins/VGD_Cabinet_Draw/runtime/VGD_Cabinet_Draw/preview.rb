module VGD_Cabinet_Draw
  class Preview
    COLORS = {
      body: Sketchup::Color.new(75, 185, 198, 55),
      front: Sketchup::Color.new(217, 145, 91, 80),
      target: Sketchup::Color.new(88, 190, 145, 80),
      cutter: Sketchup::Color.new(220, 95, 112, 95)
    }.freeze

    def initialize
      @polygons = []
      @lines = []
    end

    def add_polygon(points, kind = :body)
      @polygons << [points.map { |p| p.is_a?(Geom::Point3d) ? p : Geom::Point3d.new(p) }, kind]
    end

    def add_line(a, b, kind = :body)
      @lines << [[a, b].map { |p| p.is_a?(Geom::Point3d) ? p : Geom::Point3d.new(p) }, kind]
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
      view.drawing_color = Sketchup::Color.new(30, 85, 103, 220)
      view.line_width = 1
      visible.each { |_, points, _| view.draw2d(GL_LINE_LOOP, points) }
      @lines.each do |points, kind|
        next if points.any? { |point| (point - eye).dot(direction) <= 0 }
        view.drawing_color = kind == :cutter ? COLORS[:cutter] : Sketchup::Color.new(30, 85, 103, 210)
        view.draw2d(GL_LINES, points.map { |p| view.screen_coords(p) })
      end
    ensure
      view.line_width = 1
      view.line_stipple = ''
    end
  end
end
