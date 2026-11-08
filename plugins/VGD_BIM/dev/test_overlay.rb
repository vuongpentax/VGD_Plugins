# Khung đánh dấu bằng lớp phủ (Sketchup::Overlay, SketchUp 2023+): vẽ như công cụ cũ nhưng không chiếm công cụ đang dùng,
# nên chọn Shift/Ctrl, kéo chọn và nhấp đúp vào group vẫn là của SketchUp.
# Sketchup::Overlay dưới đây mô phỏng đúng phần API thật được dùng: new(id, name), overlay_id, name.
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
  class Overlay
    attr_reader :overlay_id, :name
    def initialize(id, name); @overlay_id = id; @name = name; end
  end
end
module VGD; module BIM; def self.log(m); puts "LOG #{m}"; end; end; end
require ROOT_UI

class FakeTransform
  attr_reader :array, :inverted
  def initialize(array, inverted = false); @array = array; @inverted = inverted; end
  def to_a; @array; end
  def inverse; FakeTransform.new(@array, !@inverted); end
end
class FakePoint
  attr_reader :tag
  def initialize(tag); @tag = tag; end
  def transform(transformation); FakePoint.new(transformation.inverted ? "#{@tag}→cục bộ" : "#{@tag}→thế giới"); end
end
IDENTITY = [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0].freeze
MOVED = [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 5000.0, 0, 0, 1.0].freeze

class FakeEditModel
  attr_accessor :edit_transform
  def initialize(transform); @edit_transform = transform; end
end
class View
  attr_reader :lines, :texts, :triangles, :quads, :screen_points
  attr_accessor :model
  def initialize(model = nil); @model = model || FakeEditModel.new(FakeTransform.new(IDENTITY)); @lines = []; @texts = []; @triangles = []; @quads = []; @screen_points = []; end
  def line_stipple=(v); end
  def line_width=(v); end
  def drawing_color=(v); end
  def draw_lines(pts); @lines << pts; end
  def draw(mode, pts); @triangles << pts if mode == GL_TRIANGLES; end
  def draw2d(mode, pts); @quads << pts if mode == GL_QUADS; end
  def screen_coords(pt); @screen_points << pt; Geom::Point3d.new(100, 50, 0); end
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

# Mũi tên mặt trước: vẽ tô đặc + viền, và đổi sang tọa độ cục bộ khi đang mở sửa một group
ar = FakePoint.new('t1')
arrow_overlay = VGD::BIM::UI::BoundsOverlay.new
arrow_overlay.show_shapes([FakePoint.new('a')], arrows: [[ar, FakePoint.new('t2'), FakePoint.new('t3')], [ar, FakePoint.new('l2')]])
av = View.new
arrow_overlay.draw(av)
ok('lớp phủ có mũi tên: vẽ thêm một lượt tam giác và một lượt đường viền', av.triangles.size == 1 && av.triangles[0].size == 3 && av.lines.size == 2 && av.lines[1].size == 2)
arrow_overlay.show_shapes([FakePoint.new('a')], arrows: [[ar, FakePoint.new('t2'), FakePoint.new('t3')], [ar, FakePoint.new('l2')]])
av2 = View.new(FakeEditModel.new(FakeTransform.new(MOVED)))
arrow_overlay.draw(av2)
ok('đang mở sửa group: điểm mũi tên được đổi sang tọa độ cục bộ như khung', av2.triangles[0].all? { |pt| pt.tag.end_with?('→cục bộ') } && av2.lines[1].all? { |pt| pt.tag.end_with?('→cục bộ') })
arrow_overlay.show_shapes([FakePoint.new('a')])
av3 = View.new
arrow_overlay.draw(av3)
ok('show_shapes sau đó không kèm mũi tên: mũi tên cũ bị xóa', av3.triangles.empty? && av3.lines.size == 1)

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

# Đang mở sửa group / component: SketchUp hiểu điểm vẽ theo tọa độ cục bộ của ngữ cảnh đang mở (tính từ ảnh chụp lỗi
# khi dùng tọa độ thế giới: khung lệch đúng bằng vị trí của ngữ cảnh). Điểm thế giới phải đổi bằng edit_transform.inverse.
ctx = VGD::BIM::UI::BoundsOverlay.new
ctx.show_shapes([FakePoint.new('a'), FakePoint.new('b')], label: 'Door_01', label_point: FakePoint.new('c'), fills: [FakePoint.new('f1'), FakePoint.new('f2'), FakePoint.new('f3')])
root_view = View.new(FakeEditModel.new(FakeTransform.new(IDENTITY)))
ctx.draw(root_view)
ok('không mở ngữ cảnh nào (ma trận đơn vị): giữ nguyên điểm thế giới', root_view.lines[0].map(&:tag) == %w[a b] && root_view.screen_points.map(&:tag) == %w[c])

edit_view = View.new(FakeEditModel.new(FakeTransform.new(MOVED)))
ctx.draw(edit_view)
ok('đang mở sửa group / component: đường viền đổi sang tọa độ cục bộ', edit_view.lines[0].map(&:tag) == ['a→cục bộ', 'b→cục bộ'])
ok('đang mở sửa group / component: tô mặt đổi sang tọa độ cục bộ', edit_view.triangles[0].map(&:tag) == ['f1→cục bộ', 'f2→cục bộ', 'f3→cục bộ'])
ok('đang mở sửa group / component: điểm đặt khung tên đổi sang tọa độ cục bộ', edit_view.screen_points.map(&:tag) == ['c→cục bộ'])

# Đổi sang ngữ cảnh khác (hoặc thoát ra gốc) thì tính lại từ điểm thế giới gốc, không dồn lỗi
ctx.draw(root_view)
ok('thoát ra gốc: quay lại điểm thế giới', root_view.lines.last.map(&:tag) == %w[a b])

# Tự đo kiểu tọa độ SketchUp đang dùng khi vẽ: chiếu thử một điểm bằng camera rồi so với View#screen_coords.
# Có phiên bản / loại vẽ hiểu điểm theo tọa độ cục bộ của group đang mở, có nơi lại hiểu theo tọa độ thế giới (khung lệch đúng bằng vị trí group).
require File.expand_path('../runtime/vgd_bim/core/view_fit', __dir__)
class NumPoint
  attr_reader :x, :y, :z
  def initialize(x, y, z); @x, @y, @z = x.to_f, y.to_f, z.to_f; end
  def to_a; [x, y, z]; end
  def transform(shift); NumPoint.new(x + shift.dx, y + shift.dy, z + shift.dz); end
end
class ShiftTransform
  attr_reader :dx, :dy, :dz
  def initialize(dx, dy, dz); @dx, @dy, @dz = dx.to_f, dy.to_f, dz.to_f; end
  def to_a; [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, dx, dy, dz, 1.0]; end
  def inverse; ShiftTransform.new(-dx, -dy, -dz); end
end
class NumCamera
  def eye; NumPoint.new(0, -300, 0); end
  def direction; NumPoint.new(0, 1, 0); end
  def up; NumPoint.new(0, 0, 1); end
  def perspective?; true; end
  def fov; 60.0; end
  def fov_is_height?; false; end
  def height; 0.0; end
end
# interpret: :world = điểm vẽ được hiểu là tọa độ thế giới; :local = hiểu là tọa độ cục bộ của group đang mở (thế giới = ngữ cảnh * điểm)
class SpaceView < View
  attr_reader :camera, :probes
  def initialize(model, interpret); super(model); @interpret = interpret; @camera = NumCamera.new; @shift = model.edit_transform; @probes = 0; end
  def vpwidth; 1000; end
  def vpheight; 600; end
  def screen_coords(pt)
    @probes += 1
    world = @interpret == :local ? pt.transform(@shift) : pt
    xy = VGD::BIM::ViewFit.project(world.to_a, eye: camera.eye.to_a, direction: camera.direction.to_a, up: camera.up.to_a, perspective: true, fov: 60.0, fov_is_height: false, width: 1000.0, height: 600.0)
    Geom::Point3d.new(xy[0], xy[1], 0)
  end
end
shift = ShiftTransform.new(5000, 0, 0) # group đang mở nằm cách gốc 5000 theo X
world_points = [NumPoint.new(5010, 100, 20), NumPoint.new(5030, 100, 20)]
space_overlay = ->(interpret) do
  o = VGD::BIM::UI::BoundsOverlay.new
  o.show_shapes(world_points, fills: [], label: nil)
  v = SpaceView.new(FakeEditModel.new(shift), interpret)
  o.draw(v)
  v.lines[0].map(&:x)
end
ok('SketchUp hiểu điểm vẽ theo tọa độ thế giới (như lớp phủ trong ảnh lỗi): giữ nguyên điểm thế giới, không đổi sang cục bộ', space_overlay.call(:world) == [5010.0, 5030.0])
ok('SketchUp hiểu điểm vẽ theo tọa độ cục bộ của group đang mở: đổi sang cục bộ (trừ vị trí group)', space_overlay.call(:local) == [10.0, 30.0])
lazy = VGD::BIM::UI::BoundsOverlay.new
lazy.show_shapes(world_points, fills: [])
cache_view = SpaceView.new(FakeEditModel.new(shift), :world)
lazy.draw(cache_view); lazy.draw(cache_view)
ok('đã đo xong thì dùng lại cho các lần vẽ sau (không gọi screen_coords lại để đo)', cache_view.probes == 2)
undecidable = VGD::BIM::UI::BoundsOverlay.new
undecidable.show_shapes([NumPoint.new(0, -900, 0), NumPoint.new(10, -900, 0)], fills: []) # điểm nằm sau camera: không đo được
behind_view = SpaceView.new(FakeEditModel.new(shift), :world)
undecidable.draw(behind_view)
ok('không đo được (điểm sau camera): dùng cách cũ là tọa độ cục bộ, không báo lỗi', behind_view.lines[0].map(&:x) == [-5000.0, -4990.0])

# Khung tên: hộp ôm đúng chiều rộng chữ (đo bằng View#text_bounds), tên quá dài thì rút gọn bằng "…" để chữ không tràn hộp
class MeasuringView < View
  def text_bounds(_point, text, _options); Struct.new(:width, :height).new(text.length * 11.0, 16.0); end
end
class BrokenMeasureView < View
  def text_bounds(*); raise 'không đo được'; end
end
module Overlay; end
LIMIT = VGD::BIM::UI::OutlineDrawing::MAX_LABEL_WIDTH
PAD = VGD::BIM::UI::OutlineDrawing::PADDING
quad_width = ->(view) { xs = view.quads[0].map(&:x); xs.max - xs.min }
label_overlay = lambda do |text|
  o = VGD::BIM::UI::BoundsOverlay.new
  o.show_shapes([FakePoint.new('a')], label: text, label_point: FakePoint.new('c'))
  o
end
mv = MeasuringView.new
label_overlay.call('Tủ bếp · Mới').draw(mv)
ok('hộp chữ rộng đúng chiều rộng chữ đo được cộng lề', (quad_width.call(mv) - (12 * 11.0 + 2 * PAD)).abs < 1e-6 && mv.texts == ['Tủ bếp · Mới'])
long_text = 'Tủ bếp dưới bên trái của căn hộ số mười hai tầng ba khu A phần cánh cửa đôi'
mv2 = MeasuringView.new
label_overlay.call(long_text).draw(mv2)
shown = mv2.texts.first
ok('tên quá dài: rút gọn bằng "…", vẫn là phần đầu của tên', shown.end_with?('…') && long_text.start_with?(shown.chomp('…')) && shown.length < long_text.length)
ok('tên quá dài: chữ vừa trong hộp, hộp không vượt giới hạn', shown.length * 11.0 <= LIMIT && quad_width.call(mv2) <= LIMIT + 2 * PAD + 1e-6)
ok('tên quá dài: rút gọn gần hết mức cho phép (không cắt quá tay)', (shown.length + 2) * 11.0 > LIMIT)
fb = View.new
label_overlay.call(long_text).draw(fb)
ok('không có View#text_bounds: vẫn rút gọn tên dài, hộp không vượt giới hạn', fb.texts.first.end_with?('…') && quad_width.call(fb) <= LIMIT + 2 * PAD + 1e-6)
fb2 = View.new
label_overlay.call('Cửa').draw(fb2)
ok('không có View#text_bounds: tên ngắn giữ nguyên', fb2.texts == ['Cửa'])
bv = BrokenMeasureView.new
label_overlay.call(long_text).draw(bv)
ok('đo chữ lỗi: không báo lỗi, dùng ước lượng', bv.texts.first.end_with?('…') && quad_width.call(bv) <= LIMIT + 2 * PAD + 1e-6)
wide = label_overlay.call('Cửa')
mv3 = MeasuringView.new
wide.draw(mv3)
wide.draw(mv3)
ok('vẽ lại nhiều lần: kết quả như nhau', mv3.quads[0].map(&:x) == mv3.quads[1].map(&:x))

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
