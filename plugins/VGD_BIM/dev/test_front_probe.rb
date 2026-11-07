# Test phần đo của Mặt trước (core/front_probe.rb) trên model giả lập: mặt trong khung cục bộ, tia ra bốn phía, trục thế giới, camera, mũi tên.
# Đây là mô phỏng đơn giản của API SketchUp (Geom, Face, raytest); việc đo thật trong SketchUp chưa kiểm được. Chạy: ruby dev/test_front_probe.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end

module Geom
  class Vector3d
    attr_reader :x, :y, :z
    def initialize(x, y, z); @x = x.to_f; @y = y.to_f; @z = z.to_f; end
    def to_a; [x, y, z]; end
    def length; Math.sqrt(x * x + y * y + z * z); end
    def transform(t); t.vector(self); end
  end
  class Point3d < Vector3d
    def transform(t); t.point(self); end
    def distance(p); Vector3d.new(x - p.x, y - p.y, z - p.z).length; end
  end
  class Transformation
    attr_reader :m
    def initialize(m = nil); @m = m || [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]].map { |r| r.map(&:to_f) }; end
    def self.rotation_z(deg, scale: [1, 1, 1], origin: [0, 0, 0])
      a = deg * Math::PI / 180
      new([[Math.cos(a) * scale[0], -Math.sin(a) * scale[1], 0, origin[0]], [Math.sin(a) * scale[0], Math.cos(a) * scale[1], 0, origin[1]], [0, 0, scale[2], origin[2]], [0, 0, 0, 1]].map { |r| r.map(&:to_f) })
    end
    def point(p); Point3d.new(*3.times.map { |i| m[i][3] + 3.times.sum { |j| m[i][j] * p.to_a[j] } }); end
    def vector(v); Vector3d.new(*3.times.map { |i| 3.times.sum { |j| m[i][j] * v.to_a[j] } }); end
    def *(other)
      return point(other) if other.is_a?(Point3d)
      new_m = 4.times.map { |i| 4.times.map { |j| 4.times.sum { |k| m[i][k] * other.m[k][j] } } }
      self.class.new(new_m)
    end
    def xaxis; Vector3d.new(m[0][0], m[1][0], m[2][0]); end
    def yaxis; Vector3d.new(m[0][1], m[1][1], m[2][1]); end
    def zaxis; Vector3d.new(m[0][2], m[1][2], m[2][2]); end
  end
end
module Sketchup
  class Face
    attr_reader :normal, :bounds, :area_in2
    def initialize(normal, center, area_in2 = 10.0)
      @normal = Geom::Vector3d.new(*normal); @bounds = Struct.new(:center).new(Geom::Point3d.new(*center)); @area_in2 = area_in2
    end
    def valid?; true; end
    def area(_t); area_in2; end
  end
  class Group; attr_reader :entities, :transformation; def initialize(entities, t = Geom::Transformation.new); @entities = entities; @transformation = t; end; def valid?; true; end; def locked?; false; end; end
  class ComponentInstance; end
  class SelectionObserver; end
end
class FakeBox
  attr_reader :min, :width, :height, :depth
  def initialize(w, h, d); @min = Geom::Point3d.new(0, 0, 0); @width = w.to_f; @height = h.to_f; @depth = d.to_f; end
  def empty?; width.zero? && height.zero? && depth.zero?; end
  def center; Geom::Point3d.new(width / 2, height / 2, depth / 2); end
end
class FakeDef
  attr_reader :entities, :bounds
  def initialize(faces, box); @entities = faces; @bounds = box; end
  def attribute_dictionary(name); @dyn && name == 'dynamic_attributes' ? {} : nil; end
  def make_dynamic; @dyn = true; end
end
class FakeInstance
  attr_reader :definition
  def initialize(definition); @definition = definition; end
  def attribute_dictionary(_n); nil; end
end
module VGD; module BIM; def self.log(_m); end
  module Data; def self.supported?(e); e.is_a?(Sketchup::Group) || e.is_a?(FakeInstance); end; end
  module Geometry; INCH_MM = 25.4; def self.definition(e); e.definition; end; end
end; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
require File.join(ROOT, 'core/front')
require File.join(ROOT, 'core/front_probe')
# Scanner thật: chỉ duyệt group / component và mặt (Data.supported? ở trên chấp nhận FakeInstance)
require File.join(ROOT, 'core/scanner')
class FakeInstance; def transformation; Geom::Transformation.new; end; def locked?; false; end; def valid?; true; end; def respond_to_missing?(*) = true; end
P = VGD::BIM::FrontProbe
F = VGD::BIM::Front
IN = 25.4

# Tủ 1200 x 600 x 2000 mm (đổi ra inch): +y có 8 mặt nhỏ sát mặt trước, -y một tấm phẳng lớn
w, d, h = 1200 / IN, 600 / IN, 2000 / IN
faces = (1..8).map { |i| Sketchup::Face.new([0, 1, 0], [i * w / 9, d - 0.1, h / 2]) } + [Sketchup::Face.new([0, -1, 0], [w / 2, 0.1, h / 2], 200.0)]
faces << Sketchup::Face.new([0, 0, 1], [w / 2, d / 2, h - 0.1]) # mặt trên, không tính là mặt hướng ngang
cabinet_def = FakeDef.new(faces, FakeBox.new(w, d, h))
cabinet = FakeInstance.new(cabinet_def)

class RayModel
  attr_reader :rays
  def initialize(&hit); @hit = hit; @rays = []; end
  # Như SketchUp thật: trả về [điểm chạm, đường dẫn] hoặc nil
  def raytest(ray, ignore_hidden); @rays << [ray, ignore_hidden]; point = @hit.call(ray[0], ray[1]); point && [point, []]; end
end
free_model = RayModel.new { |_p, _v| nil }
record = {entity: cabinet, transform: Geom::Transformation.new, locked: false}
r = P.measure(free_model, record)
ok('đo mặt trong khung cục bộ: +y nhiều chi tiết, -y một tấm', r[:detail]['+y'] == 8 && r[:detail]['-y'] == 1 && r[:dir] == '+y')
ok('tia: 4 hướng x 3 tia, bỏ qua vật ẩn, tia không chạm gì thì thoáng tối đa', free_model.rays.size == 12 && free_model.rays.all? { |ray, ignore| ignore == true } && r[:free].values.all? { |v| v == F::FREE_MAX })

# Tường ở phía -y thế giới cách mặt sau 20 mm: tia hướng -y trúng tường
wall_model = RayModel.new { |start, vec| vec.y < -0.5 ? Geom::Point3d.new(start.x, start.y - 15 / IN, start.z) : nil }
r = P.measure(wall_model, record)
ok('tường sát phía -y: khoảng thoáng -y nhỏ (≈15 mm), +y thoáng tối đa', (r[:free]['-y'] - 15.0).abs < 0.5 && r[:free]['+y'] == F::FREE_MAX)
ok('tường + hình học cùng chỉ +y: tin cậy cao', r[:dir] == '+y' && r[:confidence] == 'high')
ok('điểm bắt đầu tia nằm ngoài khung bao (không trúng chính món)', wall_model.rays.select { |ray, _| ray[1].y < -0.5 }.all? { |ray, _| ray[0].y < 0 })

# Món xoay 90° quanh Z (đặt ở gốc): +y cục bộ thành -x thế giới; tường ở phía +x thế giới (sau lưng món)
rotated = {entity: cabinet, transform: Geom::Transformation.rotation_z(90), locked: false}
wall_x = RayModel.new { |start, vec| vec.x > 0.5 ? Geom::Point3d.new(start.x + 10 / IN, start.y, start.z) : nil }
r = P.measure(wall_x, rotated)
ok('món xoay 90°: tia bắn theo hướng thế giới của từng mặt cục bộ (-y cục bộ nhìn ra +x thế giới là mặt sát tường)', (r[:free]['-y'] - 10.0).abs < 0.5 && r[:free]['+y'] == F::FREE_MAX && r[:dir] == '+y')

# Trục thế giới, lật gương, đứng thẳng
axes = P.axes_of(Geom::Transformation.rotation_z(90, scale: [2, 2, 2]))
ok('trục chuẩn hóa dù món bị phóng to', axes.all? { |a| (Math.sqrt(a.sum { |v| v * v }) - 1).abs < 1e-9 } && axes[2] == [0.0, 0.0, 1.0])
ok('nhận ra lật gương', P.mirrored?(P.axes_of(Geom::Transformation.rotation_z(0, scale: [-1, 1, 1]))) && !P.mirrored?(axes))
tipped = Geom::Transformation.new([[1, 0, 0, 0], [0, 0, -1, 0], [0, 1, 0, 0], [0, 0, 0, 1]].map { |row| row.map(&:to_f) }) # lật 90° quanh X
r = P.measure(free_model, {entity: cabinet, transform: tipped, locked: false})
ok('món nằm nghiêng (Z không hướng lên): không chọn, ghi lý do', r[:dir].nil? && r[:notes].any? { |n| n.include?('không đứng thẳng') })
dyn_def = FakeDef.new(faces, FakeBox.new(w, d, h)); dyn_def.make_dynamic
r = P.measure(free_model, {entity: FakeInstance.new(dyn_def), transform: Geom::Transformation.new, locked: false})
ok('component động: tin cậy thấp, ghi chú', r[:confidence] == 'low' && r[:notes].any? { |n| n.include?('component động') })
ok('món rỗng (khung bao rỗng): không đo', P.measure(free_model, {entity: FakeInstance.new(FakeDef.new([], FakeBox.new(0, 0, 0))), transform: Geom::Transformation.new, locked: false}).nil?)
many = FakeDef.new(Array.new(P::MAX_FACES + 50) { Sketchup::Face.new([0, 1, 0], [w / 2, d - 0.1, h / 2]) }, FakeBox.new(w, d, h))
r = P.measure(free_model, {entity: FakeInstance.new(many), transform: Geom::Transformation.new, locked: false})
ok("quá #{P::MAX_FACES} mặt: dừng đọc, đếm đúng số mặt đã đọc, ghi chú lấy mẫu", r[:detail]['+y'] == P::MAX_FACES && r[:notes].any? { |n| n.include?('lấy mẫu') })
ok('model không có raytest: vẫn đo hình học, không lỗi', P.measure(Object.new, record)[:dir] == '+y')

# Camera: đứng ở phía +y thế giới nhìn vào món đặt thẳng -> mặt trước +y; món xoay 90° thì +x cục bộ
view = Struct.new(:camera).new(Struct.new(:eye).new(Geom::Point3d.new(w / 2, d + 30.0, 60.0)))
ok('camera ở phía +y thế giới: món đặt thẳng lấy +y', P.camera_direction(view, record) == '+y')
view = Struct.new(:camera).new(Struct.new(:eye).new(Geom::Point3d.new(w / 2, -30.0, 60.0)))
ok('camera ở phía -y thế giới: món đặt thẳng lấy -y', P.camera_direction(view, record) == '-y')
view = Struct.new(:camera).new(Struct.new(:eye).new(Geom::Point3d.new(-d / 2 - 30.0, w / 2, 60.0)))
ok('món xoay 90° quanh Z: camera ở phía -x thế giới là +y cục bộ', P.camera_direction(view, rotated) == '+y')
above = Struct.new(:camera).new(Struct.new(:eye).new(Geom::Point3d.new(w / 2, d / 2, 500.0)))
ok('camera ngay trên đỉnh món (không có hướng ngang): nil', P.camera_direction(above, record).nil?)

# Mũi tên
pts = P.arrow_points(record, '+y')
ok('mũi tên: 6 điểm (thân + hai cánh), bắt đầu ở mặt +y và hướng ra +y', pts.size == 6 && (pts[0].y - d).abs < 1e-6 && pts[1].y > pts[0].y && (pts[1].x - pts[0].x).abs < 1e-6)
ok('mũi tên dài tối thiểu 300 mm', (pts[1].y - pts[0].y) * IN >= 299.0)
pr = P.arrow_points(rotated, '+y')
ok('món xoay 90°: mũi tên +y cục bộ chỉ ra -x thế giới', pr[1].x < pr[0].x && (pr[1].y - pr[0].y).abs < 1e-6)
ok('hướng không hợp lệ hoặc món rỗng: không có mũi tên', P.arrow_points(record, nil).empty? && P.arrow_points({entity: FakeInstance.new(FakeDef.new([], FakeBox.new(0, 0, 0))), transform: Geom::Transformation.new}, '+y').empty?)

puts $fails.zero? ? 'Done' : "#{$fails} lỗi"
exit($fails.zero? ? 0 : 1)
