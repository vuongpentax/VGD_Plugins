ROOT_UI = ARGV[0] || File.expand_path('../runtime/vgd_bim/ui/bounds_preview.rb', __dir__)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
GL_TRIANGLES = 4
GL_QUADS = 7
module Geom
  class Point3d; attr_reader :x, :y, :z; def initialize(x, y, z); @x, @y, @z = x, y, z; end; end
end
module Sketchup
  class Color; attr_reader :r, :g, :b, :a; def initialize(r, g, b, a = 255); @r, @g, @b, @a = r, g, b, a; end; end
end
module VGD; module BIM; def self.log(m); puts "LOG #{m}"; end; end; end
require ROOT_UI

class Ent; attr_reader :name; def initialize(n); @name = n; end; def valid?; true; end; end
class Sel
  def initialize; @items = []; end
  def clear; @items.clear; end
  def add(e); @items << e; end
  def to_a; @items.dup; end
end
class Helper
  attr_accessor :paths
  def do_pick(x, y); @x = x; end
  def count; @paths.size; end
  def path_at(i); @paths[i]; end
end
class RootTransform; def to_a; [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0]; end; end
class Tools; attr_reader :popped; def initialize; @popped = 0; end; def pop_tool; @popped += 1; end; end
class Model
  attr_accessor :active_path
  def initialize; @selection = Sel.new; @active_path = []; @tools = Tools.new; end
  def selection; @selection; end
  def tools; @tools; end
  def edit_transform; RootTransform.new; end
end
class View
  attr_reader :lines, :texts, :model, :triangles, :quads, :colors
  def initialize(model, helper); @model = model; @helper = helper; @lines = []; @texts = []; @triangles = []; @quads = []; @colors = []; end
  def pick_helper; @helper; end
  def line_stipple=(v); end
  def line_width=(v); end
  def drawing_color=(v); @colors << v; end
  def draw_lines(pts); @lines << pts; end
  def draw(mode, pts); @triangles << [mode, pts] if mode == GL_TRIANGLES; end
  def draw2d(mode, pts); @quads << [mode, pts] if mode == GL_QUADS; end
  def screen_coords(pt); Geom::Point3d.new(100, 50, 0); end
  def draw_text(pt, text, opts); @texts << text; @text_points = (@text_points || []) << pt; end
  def text_points; @text_points || []; end
  def invalidate; end
end

model = Model.new
house = Ent.new('Tủ bếp')
inner = Ent.new('Ngăn')
helper = Helper.new
helper.paths = [[house, inner]]
view = View.new(model, helper)

done = 0
tool = VGD::BIM::UI::BoundsPreview.new([[1, 2, 3], [4, 5, 6]], label: 'Tủ bếp · Mới', label_point: [0, 0, 0]) { done += 1 }
tool.draw(view)
ok('vẽ khung nét đứt (một lần draw_lines)', view.lines.size == 1 && view.lines[0].size == 2)
ok('vẽ khung tên có nội dung', view.texts == ['Tủ bếp · Mới'])
ok('khung tên có nền (draw2d GL_QUADS, 4 góc)', view.quads.size == 1 && view.quads[0][1].size == 4)
ok('viền dùng màu VGD #B48963', view.colors.any? { |c| c.r == 180 && c.g == 137 && c.b == 99 })
ok('nhãn dùng nền #8E6B4C', view.colors.any? { |c| c.r == 142 && c.g == 107 && c.b == 76 })

# Click chọn: cấp gốc (depth 0) lấy đối tượng ở cấp gốc
tool.onLButtonDown(0, 10, 10, view)
ok('click chọn đối tượng cấp gốc', model.selection.to_a == [house])

# Click trong group đang mở (active_path = [house]): chỉ lấy cấp con
model.active_path = [house]
helper.paths = [[house, inner]]
tool.onLButtonDown(0, 10, 10, view)
ok('trong group đang mở: chọn đúng cấp con', model.selection.to_a == [inner])

# Click vào vùng trống: bỏ chọn
helper.paths = []
tool.onLButtonDown(0, 10, 10, view)
ok('click vùng trống: bỏ chọn', model.selection.to_a.empty?)

tool.onCancel(0, view)
ok('Esc: gọi on_done và gỡ công cụ', done == 1 && model.tools.popped == 1)
tool.finish(view)
ok('gỡ hai lần không lặp', done == 1 && model.tools.popped == 1)
tool.draw(view)
ok('sau khi gỡ: không vẽ thêm', view.lines.size == 1)

# Người dùng chọn công cụ khác khi khung đang bật: SketchUp gỡ khung (deactivate) nên lần gỡ sau không được pop công cụ của người dùng
switched_done = 0
switched = VGD::BIM::UI::BoundsPreview.new([[1, 2, 3], [4, 5, 6]]) { switched_done += 1 }
popped_before = model.tools.popped
switched.deactivate(view)
switched.finish(view)
ok('đổi sang công cụ khác: không pop nhầm công cụ của người dùng, báo on_done một lần', model.tools.popped == popped_before && switched_done == 1)
switched.draw(view)
ok('đổi sang công cụ khác: khung không vẽ nữa', view.lines.size == 1)

plain = VGD::BIM::UI::BoundsPreview.new([[1, 2, 3], [4, 5, 6]]) { }
v2 = View.new(model, helper)
plain.draw(v2)
ok('không có nhãn: không gọi draw_text', v2.texts.empty?)
ok('không có mặt tô: không gọi draw tam giác', v2.triangles.empty?)

# Tô nhẹ mặt: có danh sách tam giác thì vẽ GL_TRIANGLES, màu VGD có alpha
tris = [[0, 0, 0], [1, 0, 0], [0, 1, 0]]
filled = VGD::BIM::UI::BoundsPreview.new([[1, 2, 3], [4, 5, 6]], fills: tris) { }
v3 = View.new(model, helper)
filled.draw(v3)
ok('tô mặt: vẽ GL_TRIANGLES đúng số điểm', v3.triangles.size == 1 && v3.triangles[0][1] == tris)
ok('tô mặt: màu VGD có độ trong suốt', v3.colors.any? { |c| c.r == 180 && c.a < 255 })

# Mũi tên mặt trước: tô đặc màu sáng + viền nâu đậm, vẽ sau khung; không có mũi tên thì không vẽ thêm gì
arrow_fills = [[0, 0, 5], [1, 0, 5], [0, 1, 5], [2, 0, 5], [3, 0, 5], [2, 1, 5], [4, 0, 5], [5, 0, 5], [4, 1, 5]]
arrow_lines = [[0, 0, 5], [1, 0, 5], [1, 0, 5], [1, 1, 5]]
arrowed = VGD::BIM::UI::BoundsPreview.new([[1, 2, 3], [4, 5, 6]], arrows: [arrow_fills, arrow_lines]) { }
v6 = View.new(model, helper)
arrowed.draw(v6)
ok('mũi tên: tô bằng GL_TRIANGLES đúng điểm', v6.triangles.size == 1 && v6.triangles[0][1] == arrow_fills)
ok('mũi tên: viền vẽ sau đường viền khung, đúng điểm', v6.lines.size == 2 && v6.lines[1] == arrow_lines)
ok('mũi tên: màu tô sáng (255, 244, 224) rồi viền nâu đậm (142, 107, 76)', v6.colors.any? { |c| [c.r, c.g, c.b] == [255, 244, 224] } && v6.colors.last.then { |c| [c.r, c.g, c.b] == [142, 107, 76] })
v7 = View.new(model, helper)
VGD::BIM::UI::BoundsPreview.new([[1, 2, 3], [4, 5, 6]]) { }.draw(v7)
ok('không có mũi tên: chỉ vẽ đường viền khung, không tô thêm', v7.lines.size == 1 && v7.triangles.empty?)

# Chữ phải nằm trong khung tên (tọa độ màn hình), không bị đẩy lên góc trái màn hình.
lab = VGD::BIM::UI::BoundsPreview.new([[1, 2, 3], [4, 5, 6]], label: 'Tủ', label_point: Geom::Point3d.new(5000, 9000, 0)) { }
v4 = View.new(model, helper)
lab.draw(v4)
tp = v4.text_points.first
ok('chữ khung tên đặt theo tọa độ màn hình, nằm trong ô nền', tp && (tp.x - 100).abs < 40 && (tp.y - 50).abs < 15)

# Đối tượng bị xóa: không vẽ nữa, tự gỡ khung và báo cho bảng
stale_called = 0
gone = false
m5 = Model.new
s5 = VGD::BIM::UI::BoundsPreview.new([[1, 2, 3], [4, 5, 6]], alive: -> { !gone }, on_stale: -> { stale_called += 1 }) { }
v5 = View.new(m5, helper)
s5.draw(v5)
gone = true
s5.draw(v5)
ok('đối tượng bị xóa: khung tự tắt, bảng được báo', v5.lines.size == 1 && stale_called == 1 && m5.tools.popped == 1)
s5.draw(v5)
ok('sau khi xóa: không vẽ lại', v5.lines.size == 1 && stale_called == 1)

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
