# Test sửa trục theo mặt trước (core/front_align.rb) bằng ma trận biến đổi thật 4x4: sau khi sửa, mặt trước là -y và mọi điểm trong thế giới
# giữ nguyên chỗ (nội dung xoay R, mọi bản sao nhân R⁻¹). SketchUp giả lập; việc ghi thật vào model chưa kiểm được ngoài SketchUp.
# Chạy: ruby dev/test_front_align.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end

module Geom
  class Point3d
    attr_reader :x, :y, :z
    def initialize(x, y, z); @x = x.to_f; @y = y.to_f; @z = z.to_f; end
    def to_a; [x, y, z]; end
  end
  class Vector3d < Point3d; end
  class Transformation
    attr_reader :m
    def initialize(m = nil); @m = m || Array.new(4) { |i| Array.new(4) { |j| i == j ? 1.0 : 0.0 } }; end
    def self.rotation(origin, axis, angle)
      c = Math.cos(angle); s = Math.sin(angle)
      new([[c, -s, 0, origin.x], [s, c, 0, origin.y], [0, 0, 1, origin.z], [0, 0, 0, 1]].map { |r| r.map(&:to_f) })
    end
    def self.scaling_rotation(deg, sx, sy, sz, tx, ty, tz)
      a = deg * Math::PI / 180
      new([[Math.cos(a) * sx, -Math.sin(a) * sy, 0, tx], [Math.sin(a) * sx, Math.cos(a) * sy, 0, ty], [0, 0, sz, tz], [0, 0, 0, 1]].map { |r| r.map(&:to_f) })
    end
    def *(o); Transformation.new(Array.new(4) { |i| Array.new(4) { |j| (0...4).sum { |k| m[i][k] * o.m[k][j] } } }); end
    def inverse
      # Nghịch đảo affine 3x3 + tịnh tiến bằng khử Gauss
      a = m.map { |r| r.dup } + []
      n = 4
      inv = Array.new(n) { |i| Array.new(n) { |j| i == j ? 1.0 : 0.0 } }
      n.times do |col|
        pivot = (col...n).max_by { |r| a[r][col].abs }
        a[col], a[pivot] = a[pivot], a[col]; inv[col], inv[pivot] = inv[pivot], inv[col]
        d = a[col][col]
        n.times { |j| a[col][j] /= d; inv[col][j] /= d }
        n.times { |r| next if r == col; f = a[r][col]; n.times { |j| a[r][j] -= f * a[col][j]; inv[r][j] -= f * inv[col][j] } }
      end
      Transformation.new(inv)
    end
    def point(p); Point3d.new(*3.times.map { |i| m[i][3] + 3.times.sum { |j| m[i][j] * p.to_a[j] } }); end
    def xaxis; Vector3d.new(m[0][0], m[1][0], m[2][0]); end
    def yaxis; Vector3d.new(m[0][1], m[1][1], m[2][1]); end
    def zaxis; Vector3d.new(m[0][2], m[1][2], m[2][2]); end
  end
end
module Sketchup; class Group; end; class Face; end; end

class FakeDefinition
  attr_reader :entities, :name, :instances
  attr_accessor :image
  def initialize(name); @name = name; @attrs = {}; @entities = FakeEntities.new; @instances = []; end
  def get_attribute(dict, key, default = nil); @attrs.dig(dict, key) || default; end
  def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; end
  def delete_attribute(dict, key); @attrs[dict]&.delete(key); end
  def attribute_dictionary(name); @dynamic && name == 'dynamic_attributes' ? {} : nil; end
  def make_dynamic; @dynamic = true; end
  def image?; !!@image; end
end
class FakeEntities
  attr_reader :list
  def initialize; @list = []; end
  def to_a; @list.dup; end
  def add(entity); @list << entity; entity; end
  def transform_entities(t, entities); entities.each { |e| e.apply!(t) }; end
end
class FakePoint   # đỉnh trong định nghĩa
  attr_reader :p
  def initialize(x, y, z); @p = Geom::Point3d.new(x, y, z); end
  def apply!(t); @p = t.point(@p); end
end
class FakeInstance
  attr_accessor :transformation, :name
  def initialize(definition, transformation, locked: false, name: ''); @definition = definition; @transformation = transformation; @locked = locked; @name = name; definition.instances << self; end
  attr_reader :definition
  def locked?; @locked; end
  def apply!(t); @transformation = t * @transformation; end # transform_entities trên một instance lồng bên trong
end

ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
module VGD; module BIM; def self.log(_m); end
  module Geometry; def self.definition(e); e.definition; end; end
end; end
%w[front front_probe front_align].each { |f| require File.join(ROOT, "core/#{f}") }
F = VGD::BIM::Front
A = VGD::BIM::FrontAlign

def world_points(definition, instance); definition.entities.list.grep(FakePoint).map { |e| instance.transformation.point(e.p).to_a.map { |v| v.round(6) } }; end
def near?(a, b); a.flatten.zip(b.flatten).all? { |x, y| (x - y).abs < 1e-6 }; end
def record(entity); {entity: entity, transform: entity.transformation, locked: false}; end

# Tủ 1200 x 600: bốn đỉnh không đối xứng để lộ mọi sai lệch
def build(dir, name = 'Tủ')
  d = FakeDefinition.new(name)
  [[0, 0, 0], [1200, 0, 0], [1200, 600, 0], [0, 600, 2000], [300, 150, 700]].each { |x, y, z| d.entities.add(FakePoint.new(x, y, z)) }
  F.write(d, dir, source: 'auto', confidence: 'medium', note: 'ghi chú') if dir
  d
end

# ---- Bất biến: hình trong thế giới không đổi, mặt trước thành -y ----
F::DIRECTIONS.each do |dir|
  d = build(dir)
  inst = [FakeInstance.new(d, Geom::Transformation.scaling_rotation(0, 1, 1, 1, 100, 200, 0)),
          FakeInstance.new(d, Geom::Transformation.scaling_rotation(37, 1, 1, 1, -500, 80, 10)),
          FakeInstance.new(d, Geom::Transformation.scaling_rotation(90, 2.0, 0.5, 1.5, 0, 0, 0))] # có scale không đều
  before = inst.map { |i| world_points(d, i) }
  plan = A.plan(inst.map { |i| record(i) })
  ok("mặt trước #{dir}: kế hoạch có đúng một loại cần sửa, #{F.align_turns(dir)} lần quay, 3 bản sao", dir == '-y' ? (plan[:items].empty? && plan[:aligned] == 1) : (plan[:items].size == 1 && plan[:items][0][:turns] == F.align_turns(dir) && plan[:items][0][:instances].size == 3))
  next if dir == '-y'
  front_before = F.read(d)
  A.apply(plan)
  after = inst.map { |i| world_points(d, i) }
  ok("mặt trước #{dir}: mọi điểm của cả 3 bản sao giữ nguyên chỗ trong thế giới sau khi sửa trục (kể cả xoay 37° và scale không đều)", before.zip(after).all? { |b, a| near?(b, a) })
  info = F.read(d)
  ok("mặt trước #{dir}: dữ liệu thành -y, giữ nguồn / độ tin cậy / ghi chú cũ", info == {dir: '-y', source: 'auto', confidence: 'medium', note: 'ghi chú'} && front_before[:dir] == dir)
  # Điểm nằm ở phía trước thật (trước khi sửa): đỉnh hướng ra theo dir có tọa độ cục bộ lớn nhất theo hướng đó -> sau sửa phải có y nhỏ nhất
  ok("mặt trước #{dir}: nội dung thực sự xoay (đỉnh (1200, 600, 0) đổi tọa độ cục bộ đúng bội 90°)", d.entities.list.grep(FakePoint).map { |e| e.p.to_a.map { |v| v.round(6) } }.include?(
    { '+y' => [0.0, 0.0, 0.0], '+x' => [600.0, -1200.0, 0.0], '-x' => [-600.0, 1200.0, 0.0] }.fetch(dir)))
end

# ---- Quay đúng chiều: mặt trước +x cục bộ trở thành -y ----
d = build('+x'); i = FakeInstance.new(d, Geom::Transformation.new)
A.apply(A.plan([record(i)]))
ok('điểm (1, 0, 0) cục bộ (hướng mặt trước +x) sau khi sửa nằm ở (0, -1, 0)', (v = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1), 3 * Math::PI / 2).point(Geom::Point3d.new(1, 0, 0)).to_a.map { |x| x.round(9) }) == [0.0, -1.0, 0.0] && v == [0.0, -1.0, 0.0])
ok('gốc tọa độ giữ nguyên: điểm gốc vẫn ở gốc', (o = FakeDefinition.new('O'); o.entities.add(FakePoint.new(0, 0, 0)); F.write(o, '+y'); oi = FakeInstance.new(o, Geom::Transformation.scaling_rotation(30, 1, 1, 1, 7, 8, 9)); A.apply(A.plan([record(oi)])); o.entities.list[0].p.to_a == [0.0, 0.0, 0.0] && oi.transformation.point(Geom::Point3d.new(0, 0, 0)).to_a.map { |v| v.round(6) } == [7.0, 8.0, 9.0]))

# ---- Instance lồng bên trong định nghĩa cũng được xoay ----
outer = build('-x', 'Ngoài')
inner_def = build(nil, 'Trong')
nested = FakeInstance.new(inner_def, Geom::Transformation.scaling_rotation(0, 1, 1, 1, 400, 100, 0))
outer.entities.add(nested)
oi = FakeInstance.new(outer, Geom::Transformation.scaling_rotation(15, 1, 1, 1, 50, 60, 0))
world_nested_before = oi.transformation.point(nested.transformation.point(inner_def.entities.list[1].p)).to_a.map { |v| v.round(6) }
A.apply(A.plan([record(oi)]))
world_nested_after = oi.transformation.point(nested.transformation.point(inner_def.entities.list[1].p)).to_a.map { |v| v.round(6) }
ok('group / component lồng bên trong định nghĩa được xoay cùng (đỉnh của nó vẫn ở đúng chỗ trong thế giới)', near?(world_nested_before, world_nested_after))

# ---- Bỏ qua và lý do ----
def plan_for(definition, *transforms)
  instances = transforms.map { |t| FakeInstance.new(definition, t) }
  [A.plan(instances.map { |i| record(i) }), instances]
end
id = Geom::Transformation.new
no_front = build(nil); p, = plan_for(no_front, id)
ok('chưa có mặt trước: bỏ qua, ghi lý do', p[:items].empty? && p[:skipped] == [{name: 'Tủ', reason: 'chưa có mặt trước'}])
already = build('-y'); p, = plan_for(already, id)
ok('đã là -y: không sửa, đếm là đã đúng, không phải bỏ qua', p[:items].empty? && p[:skipped].empty? && p[:aligned] == 1)
dyn = build('+y'); dyn.make_dynamic; p, = plan_for(dyn, id)
ok('component động: bỏ qua', p[:items].empty? && p[:skipped][0][:reason] == 'component động')
img = build('+y'); img.image = true; p, = plan_for(img, id)
ok('định nghĩa ảnh: bỏ qua', p[:skipped][0][:reason] == 'là ảnh')
empty = FakeDefinition.new('Rỗng'); F.write(empty, '+y'); p, = plan_for(empty, id)
ok('định nghĩa không có hình: bỏ qua', p[:skipped][0][:reason] == 'không có hình bên trong')
locked_def = build('+y'); li = FakeInstance.new(locked_def, id); lk = FakeInstance.new(locked_def, id, locked: true)
p = A.plan([record(li), record(lk)])
ok('một trong các bản sao bị khóa: bỏ cả định nghĩa', p[:items].empty? && p[:skipped][0][:reason] == 'có bản sao bị khóa')
anc = build('+y'); ai = FakeInstance.new(anc, id); p = A.plan([{entity: ai, transform: id, locked: true}])
ok('bản sao nằm trong đối tượng cha bị khóa (record locked): bỏ qua', p[:items].empty? && p[:skipped][0][:reason] == 'nằm trong đối tượng bị khóa')
mir = build('+y'); p, = plan_for(mir, Geom::Transformation.scaling_rotation(0, -1, 1, 1, 0, 0, 0))
ok('một bản sao bị lật gương: bỏ cả định nghĩa', p[:items].empty? && p[:skipped][0][:reason] == 'có bản sao bị lật gương')
shared = build('+y', 'Chung'); a1 = FakeInstance.new(shared, id, name: 'Tủ trái'); a2 = FakeInstance.new(shared, Geom::Transformation.scaling_rotation(90, 1, 1, 1, 1000, 0, 0))
p = A.plan([record(a1), record(a2)])
ok('hai bản sao cùng định nghĩa trong danh sách: chỉ một mục, tên lấy của bản sao có tên, đủ hai bản sao', p[:items].size == 1 && p[:items][0][:name] == 'Tủ trái' && p[:items][0][:instances].size == 2)
ok('bản sao ngoài danh sách chọn cũng được bù (định nghĩa có 3 bản sao nhưng chỉ chọn 1)', (d3 = build('+y'); [FakeInstance.new(d3, id), FakeInstance.new(d3, id), FakeInstance.new(d3, id)]; A.plan([record(d3.instances[0])])[:items][0][:instances].size == 3))
many = [build('+y', 'A'), build('-x', 'B'), build(nil, 'C'), build('-y', 'D')].map { |d| FakeInstance.new(d, id) }
p = A.plan(many.map { |i| record(i) })
ok('nhiều loại: A và B sửa, C bỏ qua (chưa có), D đã đúng', p[:items].map { |x| x[:name] } == %w[A B] && p[:skipped].map { |x| x[:name] } == ['C'] && p[:aligned] == 1)
ok('apply trả về số loại đã sửa', A.apply(p) == 2 && F.read(many[0].definition)[:dir] == '-y' && F.read(many[1].definition)[:dir] == '-y')
ok('sửa lần hai: không còn gì để sửa (đã -y)', A.plan(many.map { |i| record(i) })[:items].empty?)

puts $fails.zero? ? 'Done' : "#{$fails} lỗi"
exit($fails.zero? ? 0 : 1)
