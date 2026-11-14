# Test số đo thân (bỏ tay nắm theo từ khóa): logic thuần (core/measure.rb), phần duyệt hình trên model giả lập (core/measure_probe.rb),
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
  attr_reader :reads # số lần duyệt danh sách (để kiểm tra mỗi định nghĩa chỉ duyệt một lần)
  def initialize(list); @list = list; @reads = 0; end
  def to_enum; @reads += 1; @list.each; end
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

# ---- Ghi chú ----
ok('ghi chú: tên không trùng, tối đa 3 tên, có dấu … khi nhiều hơn', M.note(['Tay nam 1', 'Tay nam 2', 'Tay nam 1']) == 'Bỏ 3 phần theo từ khóa hoặc tag (Tay nam 1, Tay nam 2)' && M.note(%w[a b c d]).end_with?('…)'))
ok('ghi chú: không bỏ gì thì rỗng', M.note([]) == '')

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
r = P.measure(d1, words)
ok('group tên chứa "tay nam": bị bỏ, khung bao còn lại là thân 1200 x 600 x 2000', size_mm.call(r) == [1200.0, 600.0, 2000.0] && r[:note] == 'Bỏ 1 phần theo từ khóa hoặc tag (Tay nam trái)')
d2 = cabinet.call([handle_inst.call])
ok('bản sao không tên nhưng định nghĩa tên Handle_128: vẫn bị bỏ, ghi chú dùng tên định nghĩa', size_mm.call(P.measure(d2, words)) == [1200.0, 600.0, 2000.0] && P.measure(d2, words)[:note].include?('Handle_128'))
d3 = cabinet.call([handle_inst.call(layer: Layer.new('Tay nắm'))])
ok('bản sao nằm trên tag "Tay nắm" (tên và định nghĩa không khớp): vẫn bị bỏ', (d3.entities.to_a.last.definition.define_singleton_method(:name) { 'X' }; size_mm.call(P.measure(d3, words)) == [1200.0, 600.0, 2000.0]))
tag_face = box_faces(128, 32, 15, 536, 600, 990).map { |f| Sketchup::Face.new(f.normal.to_a, f.bounds.min.to_a, f.bounds.max.to_a, layer: Layer.new('Tay nắm')) }
ok('mặt nằm trên tag "Tay nắm" (không phải group): bị bỏ', size_mm.call(P.measure(FakeDef.new('Tủ', box_faces(1200, 600, 2000) + tag_face, native), words)) == [1200.0, 600.0, 2000.0])
door_inside = FakeDef.new('Cánh', box_faces(500, 18, 700) + [handle_inst.call(name: 'Tay nắm')], FakeBounds.new(500 / IN, 50 / IN, 700 / IN))
cab_nested = FakeDef.new('Tủ', box_faces(1200, 580, 2000) + [FakeInst.new(door_inside, Geom::Transformation.translation(0, 580 / IN, 100 / IN), name: 'Cánh trái')], native)
r = P.measure(cab_nested, words)
ok('tay nắm nằm sâu trong component cánh: vẫn nhận ra và bỏ (theo vị trí đã cộng dồn biến đổi), cánh vẫn tính (y tới 598)', size_mm.call(r) == [1200.0, 598.0, 2000.0] && r[:note].include?('Tay nắm'))
rot_door = FakeDef.new('Cánh xoay', box_faces(500, 18, 700), FakeBounds.new(500 / IN, 18 / IN, 700 / IN))
rotated = FakeDef.new('Tủ', box_faces(1200, 600, 2000) + [FakeInst.new(rot_door, Geom::Transformation.translation(1250 / IN, 0, 0) * Geom::Transformation.rotation_z(90), name: 'Cánh bên'), handle_inst.call(name: 'handle')], native)
r = P.measure(rotated, words)
ok('component con xoay 90° (cánh 500 x 18 dựng ngang hông, đặt ở x = 1250): sau xoay chỉ rộng thêm tới x = 1250 (không phải 1750), tay nắm vẫn bị bỏ', size_mm.call(r) == [1250.0, 600.0, 2000.0] && r[:note].include?('handle'))
ok('không khớp từ khóa nào và không bật cắt: nil (dùng khung bao gốc, kết quả y như trước)', P.measure(FakeDef.new('Tủ', box_faces(1200, 600, 2000), FakeBounds.new(1200 / IN, 600 / IN, 2000 / IN)), words).nil?)
ok('tất cả đều bị loại: nil (giữ khung bao gốc thay vì ra 0)', P.measure(FakeDef.new('Tay nam', box_faces(10, 10, 10), FakeBounds.new(1, 1, 1)).then { |df| FakeDef.new('Tủ', [FakeInst.new(df, name: 'tay nam')], FakeBounds.new(1, 1, 1)) }, words).nil?)
ok('định nghĩa rỗng (khung bao rỗng): nil', P.measure(FakeDef.new('Rỗng', [], FakeBounds.new(0, 0, 0)), words).nil?)
r = P.measure(cabinet.call([handle_inst.call(name: 'Tay nắm')]), words)
many = FakeDef.new('Nhiều mặt', Array.new(25_000) { Sketchup::Face.new([0, 1, 0], [0, 0, 0], [1, 0, 1]) } + [handle_inst.call(name: 'tay nam')], native)
r = P.measure(many, words)
ok('món rất nhiều mặt (25.000): vẫn loại trừ được, không còn giới hạn số mặt', r && size_mm.call(r) == [25.4, 0.0, 25.4] && r[:note].include?('tay nam'))
edge_def = FakeDef.new('Có cạnh', box_faces(1200, 600, 2000) + [Sketchup::Edge.new([0, 0, 0], [0, 0, 2100 / IN]), handle_inst.call(name: 'tay nam')], native)
ok('cạnh rời (không thuộc mặt nào) vẫn được tính vào khung bao khi đo thân (cao 2100)', size_mm.call(P.measure(edge_def, words))[2] == 2100.0)

# ---- Loại trừ theo tag (bảng tick) ----
ok('parse_tags: bỏ khoảng trắng, rỗng, trùng; nhận danh sách rỗng', M.parse_tags(['  Đá bếp ', '', 'Đá bếp', 'Tay nắm']) == ['Đá bếp', 'Tay nắm'] && M.parse_tags([]) == [])
ok('parse_tags: không phải mảng chữ, quá 300 tag hoặc tên quá 100 ký tự bị từ chối', raises?('không hợp lệ') { M.parse_tags('Đá bếp') } && raises?('không hợp lệ') { M.parse_tags([1]) } && raises?('tối đa') { M.parse_tags((1..301).map { |i| "t#{i}" }) } && raises?('tối đa') { M.parse_tags(['a' * 101]) })
tags = %w[da\ bep tay\ nam]
ok('tag_excluded?: so đúng toàn bộ tên (đã chuẩn hóa: hoa thường, bỏ dấu), không khớp một phần', M.tag_excluded?(tags, 'Đá bếp') && M.tag_excluded?(tags, 'TAY NẮM') && !M.tag_excluded?(tags, 'Tay nắm 2') && !M.tag_excluded?(tags, 'Đá') && !M.tag_excluded?(tags, '') && !M.tag_excluded?([], 'Đá bếp'))
counter = FakeDef.new('Đá', box_faces(1200, 600, 30, 0, 0, 2000), FakeBounds.new(1200 / IN, 600 / IN, 2030 / IN))
cab_with_counter = FakeDef.new('Tủ bếp', box_faces(1200, 600, 2000) + [FakeInst.new(counter, Geom::Transformation.translation(0, 0, 0), name: 'Mặt đá', layer: Layer.new('Đá bếp'))], FakeBounds.new(1200 / IN, 600 / IN, 2030 / IN))
r = P.measure(cab_with_counter, [], ['da bep'])
ok('nhóm nằm trên tag được tick (tên và định nghĩa không chứa từ khóa): bị bỏ, tủ cao 2000 thay vì 2030', size_mm.call(r) == [1200.0, 600.0, 2000.0] && r[:note] == 'Bỏ 1 phần theo từ khóa hoặc tag (Mặt đá)')
ok('tag khác không được tick: giữ nguyên (nil, số đo như cũ)', P.measure(cab_with_counter, [], ['tay nam']).nil?)
ok('tag chỉ trùng một phần với tên tag của nhóm ("Đá" so với "Đá bếp"): không bị bỏ', P.measure(cab_with_counter, [], ['da']).nil?)
face_tag = Layer.new('Đá bếp')
faces_on_tag = box_faces(1200, 600, 30, 0, 0, 2000).map { |f| Sketchup::Face.new(f.normal.to_a, f.bounds.min.to_a, f.bounds.max.to_a, layer: face_tag) }
r = P.measure(FakeDef.new('Tủ', box_faces(1200, 600, 2000) + faces_on_tag, FakeBounds.new(1200 / IN, 600 / IN, 2030 / IN)), [], ['da bep'])
ok('mặt nằm trên tag được tick: bị bỏ', size_mm.call(r) == [1200.0, 600.0, 2000.0])
edge_on_tag = Sketchup::Edge.new([0, 0, 0], [0, 0, 2500 / IN], layer: Layer.new('Đá bếp'))
ok('cạnh nằm trên tag được tick: không kéo khung bao (cao vẫn 2000)', size_mm.call(P.measure(FakeDef.new('Tủ', box_faces(1200, 600, 2000) + [edge_on_tag, handle_inst.call(name: 'tay nam')], native), words, ['da bep']))[2] == 2000.0)
both = FakeDef.new('Tủ', box_faces(1200, 600, 2000) + [handle_inst.call(name: 'Tay nam'), FakeInst.new(counter, name: 'Mặt đá', layer: Layer.new('Đá bếp'))], FakeBounds.new(1200 / IN, 632 / IN, 2030 / IN))
r = P.measure(both, words, ['da bep'])
ok('từ khóa tên và tag dùng cùng lúc: cả hai đều bị bỏ, ghi chú đủ hai phần', size_mm.call(r) == [1200.0, 600.0, 2000.0] && r[:note].start_with?('Bỏ 2 phần theo từ khóa hoặc tag (') && r[:note].include?('Mặt đá') && r[:note].include?('Tay nam'))
ctx_tags = P::Context.new([], ['Đá bếp'])
ok('Context chỉ có tag (không có từ khóa): hoạt động, tên tag được chuẩn hóa', ctx_tags.active? && ctx_tags.tags == ['da bep'] && size_mm.call(ctx_tags.extent(cab_with_counter)) == [1200.0, 600.0, 2000.0])

# ---- Hệ nhiều cấp: tag nằm sâu trong group cha, món rất nhiều mặt ----
t = ->(x, y, z) { Geom::Transformation.translation(x / IN, y / IN, z / IN) }
def_box = ->(name, w, d, h) { FakeDef.new(name, box_faces(w, d, h), FakeBounds.new(w / IN, d / IN, h / IN)) }
tagged = ->(definition, tag, transform, name) { FakeInst.new(definition, transform, name: name, layer: Layer.new(tag)) }
door_sys = FakeDef.new('Cánh', box_faces(500, 18, 700) + [tagged.call(def_box.call('Tay', 128, 32, 15), 'Tay nắm', t.call(100, 18, 300), 'Tay nắm 1')], FakeBounds.new(500 / IN, 50 / IN, 700 / IN))
body_sys = FakeDef.new('Thùng', box_faces(1200, 560, 720) + [tagged.call(door_sys, 'Cánh', t.call(0, 560, 0), 'Cánh trái')], FakeBounds.new(1200 / IN, 610 / IN, 720 / IN))
device = tagged.call(def_box.call('Thiết bị', 100, 300, 50), 'Thiết bị', t.call(0, 400, 0), 'Cảm biến')
sink_sys = FakeDef.new('Chậu', box_faces(600, 450, 150) + Array.new(25_000) { Sketchup::Face.new([0, 1, 0], [0, 0, 0], [1, 0, 1]) } + [device], FakeBounds.new(600 / IN, 700 / IN, 150 / IN))
inner_sys = FakeDef.new('Hệ lavabo', [tagged.call(body_sys, 'Thùng tủ', t.call(0, 0, 0), 'Thùng tủ'), tagged.call(def_box.call('LED', 1000, 10, 10), 'LED', t.call(100, 0, 2090), 'Dải LED'),
                                     tagged.call(def_box.call('Gương', 800, 5, 1000), 'Gương', t.call(200, 0, 1000), 'Gương'), tagged.call(sink_sys, 'Lavabo', t.call(300, 50, 700), 'Chậu lavabo')],
                        FakeBounds.new(1200 / IN, 750 / IN, 2100 / IN))
outer_sys = FakeDef.new('Món to', [FakeInst.new(inner_sys, t.call(0, 0, 0), name: 'Hệ lavabo')], FakeBounds.new(1200 / IN, 750 / IN, 2100 / IN))
sys_tags = %w[tay\ nam led thiet\ bi]
r = P.measure(outer_sys, [], sys_tags)
ok('gộp cả hệ thành một món to (3 cấp, tay nắm trong cánh, LED, thiết bị trong chậu 25.000 mặt): bảng chỉ đo phần còn lại 1200 x 578 x 2000', r && size_mm.call(r) == [1200.0, 578.0, 2000.0])
ok('ghi chú nêu đủ 3 phần bị loại, kể cả phần nằm sâu', r && r[:note].start_with?('Bỏ 3 phần') && %w[Tay Dải Cảm].all? { |name| r[:note].include?(name) })
ok('không tick tag nào: nil (số đo gốc như cũ)', P.measure(outer_sys, [], []).nil?)
ok('chỉ tick "tay nam": LED và thiết bị vẫn tính (cao 2100, sâu 750)', size_mm.call(P.measure(outer_sys, [], ['tay nam'])) == [1200.0, 750.0, 2100.0])
shared_door = FakeDef.new('Cánh dùng chung', box_faces(500, 18, 700) + [handle_inst.call(name: 'tay nam')], FakeBounds.new(500 / IN, 50 / IN, 700 / IN))
rack = FakeDef.new('Kệ', Array.new(200) { |i| FakeInst.new(shared_door, t.call(0, 0, i * 10)) }, native)
rack2 = FakeDef.new('Kệ 2', [FakeInst.new(shared_door, t.call(0, 100, 0))], native)
shared_ctx = P::Context.new(words)
r = shared_ctx.extent(rack); shared_ctx.extent(rack2)
ok('200 bản sao của cùng một component (và một định nghĩa khác dùng chung): định nghĩa đó chỉ duyệt một lần, kết quả vẫn đúng', shared_door.entities.reads == 1 && r && size_mm.call(r)[2] == 700.0 + 199 * 10 && r[:note].start_with?('Bỏ 200 phần'))

# ---- Context: cache và cài đặt ----
ctx = P::Context.new(words)
calls = 0
P.singleton_class.send(:alias_method, :orig_measure, :measure)
P.define_singleton_method(:measure) { |*a| calls += 1; orig_measure(*a) }
ctx.extent(d1); ctx.extent(d1); ctx.extent(d2)
P.singleton_class.send(:alias_method, :measure, :orig_measure)
ok('Context: mỗi định nghĩa chỉ đo một lần dù hỏi nhiều lần', calls == 2)
ok('Context không có từ khóa: không hoạt động, trả nil', P::Context.new([]).extent(d1).nil? && !P::Context.new([]).active?)
S.update('exclude_words' => 'tay nắm, handle')
c = P.context
ok('P.context đọc từ cài đặt chung (từ khóa đã chuẩn hóa)', c.words == ['tay nam', 'handle'] && c.active?)
File.write(File.join(ENV['VGD_BIM_DATA_DIR'], 'settings.json'), JSON.generate('exclude_words' => 'a' * 500))
ok('file cài đặt sửa tay có từ khóa hỏng: dùng danh sách mặc định (không lỗi)', P.context.words == M.parse_words(S::DEFAULTS['exclude_words']))

# ---- Cài đặt ----
FileUtils.rm_f(File.join(ENV['VGD_BIM_DATA_DIR'], 'settings.json')) if defined?(FileUtils)
S.update('exclude_words' => '  Tay nắm , handle ')
ok('cài đặt: lưu nguyên chữ người dùng gõ (bỏ khoảng trắng hai đầu)', S.read['exclude_words'] == 'Tay nắm , handle')
S.update('exclude_words' => '')
ok('cài đặt: danh sách trống được giữ (tắt loại trừ), không quay về mặc định', S.read['exclude_words'] == '')
ok('cài đặt: từ khóa sai bị từ chối, không ghi nửa chừng', (before = S.read['exclude_words']; raises?('tối đa') { S.update('exclude_words' => 'a' * 300) } && S.read['exclude_words'] == before))
ok('cài đặt cũ có trường trim_protrusions (bản beta.25): bị bỏ qua, không lỗi', (S.update('trim_protrusions' => true); !S.read.key?('trim_protrusions')))

S.update('exclude_tags' => ['Đá bếp', 'Tay nắm'])
ok('cài đặt: lưu danh sách tag loại trừ', S.read['exclude_tags'] == ['Đá bếp', 'Tay nắm'])
ok('cài đặt: danh sách tag sai kiểu bị từ chối, không đổi cái cũ', raises?('không hợp lệ') { S.update('exclude_tags' => 'Đá bếp') } && S.read['exclude_tags'] == ['Đá bếp', 'Tay nắm'])
S.update('exclude_tags' => [])
ok('cài đặt: danh sách tag trống được giữ', S.read['exclude_tags'] == [])
S.update('exclude_tags' => ['Đá bếp'], 'exclude_words' => '')
c = P.context
ok('P.context đọc cả từ khóa (trống) và tag từ cài đặt', c.words == [] && c.tags == ['da bep'] && c.active?)
File.write(File.join(ENV['VGD_BIM_DATA_DIR'], 'settings.json'), JSON.generate('exclude_tags' => 'hỏng', 'exclude_words' => 'tay nắm'))
ok('file cài đặt sửa tay có tag hỏng: bỏ qua danh sách tag (không lỗi), từ khóa vẫn dùng', P.context.tags == [] && P.context.words == ['tay nam'])
# ---- Geometry.dimensions có đo thân ----
dd = cabinet.call([handle_inst.call(name: 'tay nam')])
inst = FakeInst.new(dd, Geom::Transformation.scaling(1, 1, 1))
dims = VGD::BIM::Geometry.dimensions(inst, Geom::Transformation.new, measure: P::Context.new(words)).transform_values { |v| v.round(3) }
ok('Geometry.dimensions có đo thân: Rộng 1200, Sâu 600 (không tính tay nắm), Cao 2000', dims == {width: 1200.0, depth: 600.0, height: 2000.0})
raw = VGD::BIM::Geometry.dimensions(inst, Geom::Transformation.new).transform_values { |v| v.round(3) }
ok('không truyền measure: giữ khung bao gốc (Sâu 632 gồm tay nắm), như trước', raw == {width: 1200.0, depth: 632.0, height: 2000.0})
scaled = VGD::BIM::Geometry.dimensions(inst, Geom::Transformation.scaling(2, 3, 0.5), measure: P::Context.new(words)).transform_values { |v| v.round(3) }
ok('số đo thân vẫn nhân phóng to (scale 2 x 3 x 0,5): 2400 x 1800 x 1000', scaled == {width: 2400.0, depth: 1800.0, height: 1000.0})
F.write(dd, '+x')
swapped = VGD::BIM::Geometry.dimensions(inst, Geom::Transformation.new, measure: P::Context.new(words)).transform_values { |v| v.round(3) }
ok('kết hợp mặt trước theo trục X: Rộng và Sâu của thân đổi chỗ (600 x 1200)', swapped == {width: 600.0, depth: 1200.0, height: 2000.0})

puts $fails.zero? ? 'Done' : "#{$fails} lỗi"
exit($fails.zero? ? 0 : 1)
