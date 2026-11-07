# Test số đo thân (bỏ tay nắm, cắt phần nhô): logic thuần (core/measure.rb), phần duyệt hình trên model giả lập (core/measure_probe.rb),
# Geometry.dimensions có đo thân và cài đặt. SketchUp giả lập đơn giản; việc đo thật trong SketchUp chưa kiểm được. Chạy: ruby dev/test_measure.rb
require 'json'
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_measure')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def raises?(text = nil); yield; false; rescue ArgumentError => e; text ? e.message.downcase.include?(text) : true; end

module Geom
  class Vector3d
    attr_reader :x, :y, :z
    def initialize(x, y, z); @x = x.to_f; @y = y.to_f; @z = z.to_f; end
    def to_a; [x, y, z]; end
    def transform(t); t.vector(self); end
  end
  class Point3d < Vector3d
    def transform(t); t.point(self); end
  end
  class Transformation
    attr_reader :m
    def initialize(m = nil); @m = m || Array.new(4) { |i| Array.new(4) { |j| i == j ? 1.0 : 0.0 } }; end
    def self.translation(x, y, z); t = new; t.m[0][3] = x.to_f; t.m[1][3] = y.to_f; t.m[2][3] = z.to_f; t; end
    def self.rotation_z(deg)
      a = deg * Math::PI / 180
      new([[Math.cos(a), -Math.sin(a), 0, 0], [Math.sin(a), Math.cos(a), 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]].map { |r| r.map(&:to_f) })
    end
    def self.scaling(x, y, z); t = new; t.m[0][0] = x.to_f; t.m[1][1] = y.to_f; t.m[2][2] = z.to_f; t; end
    def *(o); Transformation.new(Array.new(4) { |i| Array.new(4) { |j| (0...4).sum { |k| m[i][k] * o.m[k][j] } } }); end
    def point(p); Point3d.new(*3.times.map { |i| m[i][3] + 3.times.sum { |j| m[i][j] * p.to_a[j] } }); end
    def vector(v); Vector3d.new(*3.times.map { |i| 3.times.sum { |j| m[i][j] * v.to_a[j] } }); end
    def to_a; (0...4).flat_map { |c| (0...4).map { |r| m[r][c] } }; end
  end
end
IN = 25.4
Layer = Struct.new(:name)
module Sketchup
  class Face
    attr_reader :normal, :bounds, :layer, :area_in2
    def initialize(normal, lo, hi, layer: nil)
      @normal = Geom::Vector3d.new(*normal)
      @bounds = Struct.new(:min, :max, :center).new(Geom::Point3d.new(*lo), Geom::Point3d.new(*hi), Geom::Point3d.new(*lo.zip(hi).map { |a, b| (a + b) / 2.0 }))
      @area_in2 = ->(t) { sx = Math.sqrt(t.m[0][0]**2 + t.m[1][0]**2); sy = Math.sqrt(t.m[0][1]**2 + t.m[1][1]**2); sz = Math.sqrt(t.m[2][2]**2)
        d = hi.zip(lo).map { |a, b| (a - b).abs }; (d.each_with_index.reject { |_, i| normal[i].abs > 0.5 }.map { |v, i| v * [sx, sy, sz][i] }).inject(:*) || 0.0 }
      @layer = layer
    end
    def area(t); @area_in2.call(t); end
    def valid?; true; end
  end
  class Edge
    attr_reader :layer
    def initialize(a, b, layer: nil); @a = a; @b = b; @layer = layer; end
    def start; Struct.new(:position).new(Geom::Point3d.new(*@a)); end
    def end; Struct.new(:position).new(Geom::Point3d.new(*@b)); end
    def valid?; true; end
  end
  class Group; end
end
class FakeBounds
  attr_reader :width, :height, :depth
  def initialize(w, h, d); @width = w.to_f; @height = h.to_f; @depth = d.to_f; end
  def empty?; width.zero? && height.zero? && depth.zero?; end
end
class FakeEntities
  def initialize(list); @list = list; end
  def to_enum; @list.each; end
  def to_a; @list.dup; end
end
class FakeDef
  attr_reader :entities, :name, :bounds
  def initialize(name, list, bounds); @name = name; @entities = FakeEntities.new(list); @bounds = bounds; @attrs = {}; end
  def get_attribute(d, k, df = nil); @attrs.dig(d, k) || df; end
  def set_attribute(d, k, v); (@attrs[d] ||= {})[k] = v; end
  def delete_attribute(d, k); @attrs[d]&.delete(k); end
end
class FakeInst
  attr_reader :definition, :transformation, :layer
  attr_accessor :name
  def initialize(definition, transformation = Geom::Transformation.new, name: '', layer: nil); @definition = definition; @transformation = transformation; @name = name; @layer = layer; end
  def valid?; true; end
end
module VGD; module BIM; def self.log(_m); end
  module Data; def self.supported?(e); e.is_a?(FakeInst); end; end
end; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
%w[storage settings measure front geometry].each { |f| require File.join(ROOT, "core/#{f}") }
module VGD::BIM::Geometry; def self.definition(e); e.is_a?(FakeInst) ? e.definition : e.entities.parent; end; end
require File.join(ROOT, 'core/measure_probe')
M = VGD::BIM::Measure
P = VGD::BIM::MeasureProbe
S = VGD::BIM::Settings
F = VGD::BIM::Front

# ---- Từ khóa ----
ok('chuẩn hóa: bỏ dấu, hoa thường, đ -> d, gộp khoảng trắng', M.normalize('  Tay   NẮM Đẹp ') == 'tay nam dep')
ok('danh sách từ khóa: tách theo dấu phẩy, chấm phẩy, xuống dòng; bỏ trùng và rỗng', M.parse_words("tay nắm, Tay Nam;handle\n knob,,") == ['tay nam', 'handle', 'knob'])
ok('từ khóa: trống thì không có từ nào', M.parse_words('') == [] && M.parse_words(nil) == [])
ok('từ khóa: quá 12 từ, từ quá dài hoặc cả chuỗi quá dài bị từ chối', raises?('tối đa') { M.parse_words((1..13).map { |i| "w#{i}" }.join(',')) } && raises?('tối đa') { M.parse_words('a' * 41) } && raises?('tối đa') { M.parse_words('a, ' * 100) })
words = M.parse_words('tay nắm, handle')
ok('khớp không phân biệt hoa thường và dấu, theo tên chứa từ khóa', M.match(words, 'TAY NAM 128') == 'tay nam' && M.match(words, '', 'Handle_01') == 'handle' && M.match(words, 'Cánh tủ', 'Tủ bếp').nil? && M.match([], 'tay nắm').nil?)

# ---- Cắt phần nhô theo hình học (thuần) ----
def face(n, c, a, lo, hi); {n: n, c: c, a: a, lo: lo, hi: hi}; end
# Thân 1200 x 600 x 2000: mặt trước (y = 600) rất lớn, mặt sau (y = 0); tay nắm nhô thêm 32 mm ở giữa mặt trước
body = [face([0, 1, 0], [600, 600, 1000], 2_400_000, [0, 600, 0], [1200, 600, 2000]), face([0, -1, 0], [600, 0, 1000], 2_400_000, [0, 0, 0], [1200, 0, 2000]),
        face([1, 0, 0], [1200, 300, 1000], 1_200_000, [1200, 0, 0], [1200, 600, 2000]), face([-1, 0, 0], [0, 300, 1000], 1_200_000, [0, 0, 0], [0, 600, 2000]),
        face([0, 0, 1], [600, 300, 2000], 720_000, [0, 0, 2000], [1200, 600, 2000]), face([0, 0, -1], [600, 300, 0], 720_000, [0, 0, 0], [1200, 600, 0])]
handle = face([0, 1, 0], [600, 632, 1000], 1_920, [536, 632, 990], [664, 632, 1005])
bar_sides = [face([1, 0, 0], [664, 616, 997], 480, [664, 600, 990], [664, 632, 1005]), face([-1, 0, 0], [536, 616, 997], 480, [536, 600, 990], [536, 632, 1005])]
r = M.body_extents(body + [handle] + bar_sides)
ok('tay nắm nhô 32 mm khỏi mặt trước: cắt đúng 32 mm ở +Y, thân 600 mm', r[:hi][1] == 600.0 && r[:trimmed][1][1].round(6) == 32.0 && r[:trimmed][1][0] == 0.0)
ok('các trục khác giữ nguyên (X 1200, Z 2000)', r[:lo][0] == 0.0 && r[:hi][0] == 1200.0 && r[:lo][2] == 0.0 && r[:hi][2] == 2000.0)
long_handle = face([0, 1, 0], [600, 800, 1000], 1_920, [536, 800, 990], [664, 800, 1005])
r = M.body_extents(body + [long_handle])
ok('phần nhô 200 mm (quá mức cho phép 10% = 60 mm): không cắt, tránh cắt nhầm phần thân thật', r[:hi][1] == 800.0 && r[:trimmed][1] == [0.0, 0.0])
cornice = face([0, 1, 0], [600, 620, 1900], 96_000, [0, 620, 1820], [1200, 620, 1980]) # phào nhô 20 mm, mặt trước 96.000 mm² (4% của lớp lớn nhất)
ok('phào chạy suốt chiều rộng (diện tích đủ lớn, đúng ngưỡng 4%): giữ lại, không coi là tay nắm', M.body_extents(body + [cornice])[:hi][1] == 620.0)
legs = [face([0, 0, 1], [600, 300, 720], 800_000, [0, 0, 720], [1200, 600, 738])] + [[0, 0], [1160, 0], [0, 560], [1160, 560]].map { |x, y| face([0, 0, -1], [x + 20, y + 20, 0], 1_600, [x, y, 0], [x + 40, y + 40, 0]) }
ok('bàn có chân: chiều cao Z không bị cắt (chỉ cắt trục X, Y), chân vẫn tính vào chiều cao 738 mm', (rr = M.body_extents(legs))[:hi][2] == 738.0 && rr[:lo][2] == 0.0 && rr[:trimmed][2] == [0.0, 0.0])
two = [handle, face([0, 1, 0], [600, 620, 1000], 900, [570, 620, 995], [630, 620, 1005])]
ok('nhiều lớp nhô nhỏ liên tiếp (620 và 632) đều bị cắt nếu trong mức cho phép', M.body_extents(body + two)[:hi][1] == 600.0)
curved = [face([0.6, 0.8, 0], [100, 100, 100], 5000, [0, 0, 0], [200, 200, 200])]
ok('không có mặt vuông góc trục (khối cong): giữ nguyên, không cắt', (c = M.body_extents(curved))[:trimmed] == Array.new(3) { [0.0, 0.0] } && c[:hi] == [200.0, 200.0, 200.0])
ok('không có mặt nào: nil', M.body_extents([]).nil?)
ok('ghi chú: loại theo từ khóa (tên không trùng, tối đa 3) + cắt nhô theo trục (làm tròn mm, bỏ dưới 0,5 mm)', M.note(['Tay nam 1', 'Tay nam 2', 'Tay nam 1'], [[0.0, 31.6], [0.2, 0.0], [0.0, 0.0]]) == 'Bỏ 3 phần theo từ khóa (Tay nam 1, Tay nam 2); cắt nhô +X 32 mm')
ok('ghi chú: không có gì thì rỗng, nhiều hơn 3 tên thì có dấu …', M.note([], Array.new(3) { [0.0, 0.0] }) == '' && M.note(%w[a b c d], Array.new(3) { [0.0, 0.0] }).end_with?('…)'))

# ---- Duyệt hình trong định nghĩa (model giả lập) ----
def box_faces(w, d, h, ox = 0, oy = 0, oz = 0)   # 6 mặt của khối w x d x h (mm) tại gốc (ox, oy, oz), đổi ra inch
  i = ->(v) { v / IN }
  [Sketchup::Face.new([0, 1, 0], [i.(ox), i.(oy + d), i.(oz)], [i.(ox + w), i.(oy + d), i.(oz + h)]), Sketchup::Face.new([0, -1, 0], [i.(ox), i.(oy), i.(oz)], [i.(ox + w), i.(oy), i.(oz + h)]),
   Sketchup::Face.new([1, 0, 0], [i.(ox + w), i.(oy), i.(oz)], [i.(ox + w), i.(oy + d), i.(oz + h)]), Sketchup::Face.new([-1, 0, 0], [i.(ox), i.(oy), i.(oz)], [i.(ox), i.(oy + d), i.(oz + h)]),
   Sketchup::Face.new([0, 0, 1], [i.(ox), i.(oy), i.(oz + h)], [i.(ox + w), i.(oy + d), i.(oz + h)]), Sketchup::Face.new([0, 0, -1], [i.(ox), i.(oy), i.(oz)], [i.(ox + w), i.(oy + d), i.(oz)])]
end
handle_def = FakeDef.new('Handle_128', box_faces(128, 32, 15), FakeBounds.new(128 / IN, 32 / IN, 15 / IN))
handle_inst = ->(name: '', layer: nil) { FakeInst.new(handle_def, Geom::Transformation.translation(536 / IN, 600 / IN, 990 / IN), name: name, layer: layer) }
native = FakeBounds.new(1200 / IN, 632 / IN, 2000 / IN) # khung bao gốc của định nghĩa gồm cả tay nắm
cabinet = ->(extra) { FakeDef.new('Tủ', box_faces(1200, 600, 2000) + extra, native) }
size_mm = ->(r) { r[:size].map { |v| (v * IN).round(3) } }

d1 = cabinet.call([handle_inst.call(name: 'Tay nam trái')])
r = P.measure(d1, words, false)
ok('group tên chứa "tay nam": bị bỏ, khung bao còn lại là thân 1200 x 600 x 2000', size_mm.call(r) == [1200.0, 600.0, 2000.0] && r[:note] == 'Bỏ 1 phần theo từ khóa (Tay nam trái)')
d2 = cabinet.call([handle_inst.call])
ok('bản sao không tên nhưng định nghĩa tên Handle_128: vẫn bị bỏ, ghi chú dùng tên định nghĩa', size_mm.call(P.measure(d2, words, false)) == [1200.0, 600.0, 2000.0] && P.measure(d2, words, false)[:note].include?('Handle_128'))
d3 = cabinet.call([handle_inst.call(layer: Layer.new('Tay nắm'))])
ok('bản sao nằm trên tag "Tay nắm" (tên và định nghĩa không khớp): vẫn bị bỏ', (d3.entities.to_a.last.definition.define_singleton_method(:name) { 'X' }; size_mm.call(P.measure(d3, words, false)) == [1200.0, 600.0, 2000.0]))
tag_face = box_faces(128, 32, 15, 536, 600, 990).map { |f| Sketchup::Face.new(f.normal.to_a, f.bounds.min.to_a, f.bounds.max.to_a, layer: Layer.new('Tay nắm')) }
ok('mặt nằm trên tag "Tay nắm" (không phải group): bị bỏ', size_mm.call(P.measure(FakeDef.new('Tủ', box_faces(1200, 600, 2000) + tag_face, native), words, false)) == [1200.0, 600.0, 2000.0])
door_inside = FakeDef.new('Cánh', box_faces(500, 18, 700) + [handle_inst.call(name: 'Tay nắm')], FakeBounds.new(500 / IN, 50 / IN, 700 / IN))
cab_nested = FakeDef.new('Tủ', box_faces(1200, 580, 2000) + [FakeInst.new(door_inside, Geom::Transformation.translation(0, 580 / IN, 100 / IN), name: 'Cánh trái')], native)
r = P.measure(cab_nested, words, false)
ok('tay nắm nằm sâu trong component cánh: vẫn nhận ra và bỏ (theo vị trí đã cộng dồn biến đổi), cánh vẫn tính (y tới 598)', size_mm.call(r) == [1200.0, 598.0, 2000.0] && r[:note].include?('Tay nắm'))
rot_door = FakeDef.new('Cánh xoay', box_faces(500, 18, 700), FakeBounds.new(500 / IN, 18 / IN, 700 / IN))
rotated = FakeDef.new('Tủ', box_faces(1200, 600, 2000) + [FakeInst.new(rot_door, Geom::Transformation.translation(1250 / IN, 0, 0) * Geom::Transformation.rotation_z(90), name: 'Cánh bên'), handle_inst.call(name: 'handle')], native)
r = P.measure(rotated, words, false)
ok('component con xoay 90° (cánh 500 x 18 dựng ngang hông, đặt ở x = 1250): sau xoay chỉ rộng thêm tới x = 1250 (không phải 1750), tay nắm vẫn bị bỏ', size_mm.call(r) == [1250.0, 600.0, 2000.0] && r[:note].include?('handle'))
ok('không khớp từ khóa nào và không bật cắt: nil (dùng khung bao gốc, kết quả y như trước)', P.measure(FakeDef.new('Tủ', box_faces(1200, 600, 2000), FakeBounds.new(1200 / IN, 600 / IN, 2000 / IN)), words, false).nil?)
ok('tất cả đều bị loại: nil (giữ khung bao gốc thay vì ra 0)', P.measure(FakeDef.new('Tay nam', box_faces(10, 10, 10), FakeBounds.new(1, 1, 1)).then { |df| FakeDef.new('Tủ', [FakeInst.new(df, name: 'tay nam')], FakeBounds.new(1, 1, 1)) }, words, false).nil?)
ok('định nghĩa rỗng (khung bao rỗng): nil', P.measure(FakeDef.new('Rỗng', [], FakeBounds.new(0, 0, 0)), words, true).nil?)
# Cắt tự động trên hình thật (tay nắm dính vào cánh, không tách riêng)
merged = FakeDef.new('Tủ dính', box_faces(1200, 600, 2000) + box_faces(128, 32, 15, 536, 600, 990), native)
r = P.measure(merged, [], true)
ok('bật cắt, tay nắm dính liền thân (không tên, không tag): cắt 32 mm ở +Y, thân 600 mm, ghi chú nói rõ', size_mm.call(r) == [1200.0, 600.0, 2000.0] && r[:note] == 'cắt nhô +Y 32 mm')
ok('bật cắt nhưng không có gì nhô: nil', P.measure(FakeDef.new('Tủ', box_faces(1200, 600, 2000), FakeBounds.new(1200 / IN, 600 / IN, 2000 / IN)), [], true).nil?)
r = P.measure(cabinet.call([handle_inst.call(name: 'Tay nắm')]), words, true)
ok('bật cả hai: tay nắm có tên bỏ trước, không còn gì để cắt thêm, ghi chú chỉ nói phần bỏ theo từ khóa', size_mm.call(r) == [1200.0, 600.0, 2000.0] && r[:note] == 'Bỏ 1 phần theo từ khóa (Tay nắm)')
many = FakeDef.new('Nhiều mặt', Array.new(P::MAX_FACES + 1) { Sketchup::Face.new([0, 1, 0], [0, 0, 0], [1, 0, 1]) } + [handle_inst.call(name: 'tay nam')], native)
ok("quá #{P::MAX_FACES} mặt: không đo thân (giữ khung bao gốc) để bảng không chậm", P.measure(many, words, false).nil?)
edge_def = FakeDef.new('Có cạnh', box_faces(1200, 600, 2000) + [Sketchup::Edge.new([0, 0, 0], [0, 0, 2100 / IN]), handle_inst.call(name: 'tay nam')], native)
ok('cạnh rời (không thuộc mặt nào) vẫn được tính vào khung bao khi đo thân (cao 2100)', size_mm.call(P.measure(edge_def, words, false))[2] == 2100.0)

# ---- Context: cache và cài đặt ----
ctx = P::Context.new(words, false)
calls = 0
P.singleton_class.send(:alias_method, :orig_measure, :measure)
P.define_singleton_method(:measure) { |*a| calls += 1; orig_measure(*a) }
ctx.extent(d1); ctx.extent(d1); ctx.extent(d2)
P.singleton_class.send(:alias_method, :measure, :orig_measure)
ok('Context: mỗi định nghĩa chỉ đo một lần dù hỏi nhiều lần', calls == 2)
ok('Context không có từ khóa và không bật cắt: không hoạt động, trả nil', P::Context.new([], false).extent(d1).nil? && !P::Context.new([], false).active?)
S.update('exclude_words' => 'tay nắm, handle', 'trim_protrusions' => true)
c = P.context
ok('P.context đọc từ cài đặt chung (từ khóa đã chuẩn hóa, bật cắt)', c.words == ['tay nam', 'handle'] && c.trim == true && c.active?)
File.write(File.join(ENV['VGD_BIM_DATA_DIR'], 'settings.json'), JSON.generate('exclude_words' => 'a' * 500, 'trim_protrusions' => true))
ok('file cài đặt sửa tay có từ khóa hỏng: dùng danh sách mặc định (không lỗi)', P.context.words == M.parse_words(S::DEFAULTS['exclude_words']))

# ---- Cài đặt ----
FileUtils.rm_f(File.join(ENV['VGD_BIM_DATA_DIR'], 'settings.json')) if defined?(FileUtils)
S.update('exclude_words' => '  Tay nắm , handle ')
ok('cài đặt: lưu nguyên chữ người dùng gõ (bỏ khoảng trắng hai đầu)', S.read['exclude_words'] == 'Tay nắm , handle')
S.update('exclude_words' => '')
ok('cài đặt: danh sách trống được giữ (tắt loại trừ), không quay về mặc định', S.read['exclude_words'] == '')
ok('cài đặt: từ khóa sai bị từ chối, không ghi nửa chừng', raises?('tối đa') { S.update('exclude_words' => 'a' * 300, 'trim_protrusions' => true) } && S.read['trim_protrusions'] == false)
ok('cài đặt: bật cắt chỉ nhận đúng / sai', raises?('bật hoặc tắt') { S.update('trim_protrusions' => 'yes') } && (S.update('trim_protrusions' => true); S.read['trim_protrusions'] == true))

# ---- Geometry.dimensions có đo thân ----
dd = cabinet.call([handle_inst.call(name: 'tay nam')])
inst = FakeInst.new(dd, Geom::Transformation.scaling(1, 1, 1))
dims = VGD::BIM::Geometry.dimensions(inst, Geom::Transformation.new, measure: P::Context.new(words, false)).transform_values { |v| v.round(3) }
ok('Geometry.dimensions có đo thân: Rộng 1200, Sâu 600 (không tính tay nắm), Cao 2000', dims == {width: 1200.0, depth: 600.0, height: 2000.0})
raw = VGD::BIM::Geometry.dimensions(inst, Geom::Transformation.new).transform_values { |v| v.round(3) }
ok('không truyền measure: giữ khung bao gốc (Sâu 632 gồm tay nắm), như trước', raw == {width: 1200.0, depth: 632.0, height: 2000.0})
scaled = VGD::BIM::Geometry.dimensions(inst, Geom::Transformation.scaling(2, 3, 0.5), measure: P::Context.new(words, false)).transform_values { |v| v.round(3) }
ok('số đo thân vẫn nhân phóng to (scale 2 x 3 x 0,5): 2400 x 1800 x 1000', scaled == {width: 2400.0, depth: 1800.0, height: 1000.0})
F.write(dd, '+x')
swapped = VGD::BIM::Geometry.dimensions(inst, Geom::Transformation.new, measure: P::Context.new(words, false)).transform_values { |v| v.round(3) }
ok('kết hợp mặt trước theo trục X: Rộng và Sâu của thân đổi chỗ (600 x 1200)', swapped == {width: 600.0, depth: 1200.0, height: 2000.0})

puts $fails.zero? ? 'Done' : "#{$fails} lỗi"
exit($fails.zero? ? 0 : 1)
