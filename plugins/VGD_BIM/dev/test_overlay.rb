# Khung đánh dấu bằng lớp phủ (Sketchup::Overlay, SketchUp 2023+): vẽ như công cụ cũ nhưng không chiếm công cụ đang dùng,
# nên chọn Shift/Ctrl, kéo chọn và nhấp đúp vào group vẫn là của SketchUp.
# Sketchup::Overlay dưới đây mô phỏng đúng phần API thật được dùng: new(id, name), overlay_id, name.
ROOT_UI = ARGV[0] || File.expand_path('../runtime/vgd_bim_lite/ui/bounds_preview.rb', __dir__)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
GL_TRIANGLES = 4
GL_QUADS = 7
module Geom
  class Point3d; attr_reader :x, :y, :z; def initialize(x, y, z); @x, @y, @z = x, y, z; end; end
end
module Sketchup
  class Color; attr_reader :r, :g, :b, :a; def initialize(r, g, b, a = 255); @r, @g, @b, @a = r, g, b, a; end; end
  class Overlay
    attr_reader :overlay_id, :name
    def initialize(id, name); @overlay_id = id; @name = name; end
  end
end
module VGD; module BIM; def self.log(m); puts "LOG #{m}"; end; end; end
require ROOT_UI

class View
  attr_reader :lines, :texts, :triangles, :quads
  def initialize; @lines = []; @texts = []; @triangles = []; @quads = []; end
  def line_stipple=(v); end
  def line_width=(v); end
  def drawing_color=(v); end
  def draw_lines(pts); @lines << pts; end
  def draw(mode, pts); @triangles << pts if mode == GL_TRIANGLES; end
  def draw2d(mode, pts); @quads << pts if mode == GL_QUADS; end
  def screen_coords(pt); Geom::Point3d.new(100, 50, 0); end
  def draw_text(pt, text, opts); @texts << text; end
end

ok('có lớp phủ khi SketchUp có Sketchup::Overlay', defined?(VGD::BIM::UI::BoundsOverlay) && VGD::BIM::UI::BoundsOverlay < Sketchup::Overlay)
overlay = VGD::BIM::UI::BoundsOverlay.new
ok('đăng ký id và tên riêng của VGD_BIM', overlay.overlay_id == 'vgd.bim.outline' && overlay.name.include?('VGD_BIM'))

view = View.new
overlay.draw(view)
ok('chưa có nội dung: không vẽ gì', view.lines.empty? && view.texts.empty?)

alive = true
stale = 0
overlay.show_shapes([[0, 0, 0], [1, 1, 1]], label: 'Tủ bếp · Mới', label_point: [0, 0, 0], fills: [[0, 0, 0], [1, 0, 0], [0, 1, 0]], alive: -> { alive }, on_stale: -> { stale += 1 })
overlay.draw(view)
ok('có nội dung: vẽ khung nét đứt, tô mặt và khung tên', view.lines.size == 1 && view.triangles.size == 1 && view.quads.size == 1 && view.texts == ['Tủ bếp · Mới'])

overlay.hide_shapes
view2 = View.new
overlay.draw(view2)
ok('sau khi ẩn: không vẽ nữa', view2.lines.empty? && view2.texts.empty?)

overlay.show_shapes([[0, 0, 0], [1, 1, 1]], label: 'A', label_point: [0, 0, 0], alive: -> { alive }, on_stale: -> { stale += 1 })
alive = false
view3 = View.new
overlay.draw(view3)
ok('đối tượng bị xóa: không vẽ, báo bảng đọc lại một lần', view3.lines.empty? && stale == 1)
overlay.draw(view3)
ok('đã báo rồi thì không báo lặp', stale == 1)

# Không có phương thức của công cụ: lớp phủ không nhận chuột, nên không chặn chọn đối tượng của SketchUp
ok('lớp phủ không có xử lý chuột', %i[onLButtonDown onLButtonUp onMouseMove onCancel].none? { |m| overlay.respond_to?(m) })

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
