# Test trừ cửa khỏi tường của phòng: ghép cửa với phòng (core/room_openings.rb), dữ liệu lưu trong phòng và số đo (core/rooms.rb),
# đọc cửa theo tag trong model giả lập (core/opening_probe.rb). Chạy: ruby dev/test_room_openings.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end

MM = 1 / 25.4
module Geom
  class Point3d
    attr_reader :x, :y, :z
    def initialize(x, y, z); @x = x; @y = y; @z = z; end
    def transform(t); t * self; end
  end
  class Transformation # chỉ dời và (tùy chọn) xoay 90 độ quanh Z
    attr_reader :dx, :dy, :dz, :turn
    def initialize(dx = 0, dy = 0, dz = 0, turn = false); @dx = dx; @dy = dy; @dz = dz; @turn = turn; end
    def *(other)
      if other.is_a?(Transformation)
        raise 'test chỉ ghép phép dời' if other.turn && @turn
        Transformation.new(@dx + other.dx, @dy + other.dy, @dz + other.dz, @turn || other.turn)
      else
        x, y = @turn ? [-other.y, other.x] : [other.x, other.y]
        Point3d.new(x + @dx, y + @dy, other.z + @dz)
      end
    end
    def to_a
      @turn ? [0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, @dx, @dy, @dz, 1] : [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, @dx, @dy, @dz, 1]
    end
  end
  class BoundingBox
    def initialize(min, max); @min = min; @max = max; end
    def empty?; false; end
    def corner(i); Point3d.new(i & 1 == 0 ? @min[0] : @max[0], i & 2 == 0 ? @min[1] : @max[1], i & 4 == 0 ? @min[2] : @max[2]); end
    def width; @max[0] - @min[0]; end
    def height; @max[1] - @min[1]; end
    def depth; @max[2] - @min[2]; end
  end
end
module Sketchup
  class Group; end
  class ComponentInstance; end
end
Layer = Struct.new(:name)
class FakeDef
  attr_reader :entities, :bounds
  def initialize(entities, size_mm = [0, 0, 0]); @entities = entities; @bounds = Geom::BoundingBox.new([0, 0, 0], size_mm.map { |v| v * MM }); end
  def get_attribute(*); nil; end
end
class FakeInstance < Sketchup::ComponentInstance
  attr_reader :definition, :transformation, :layer, :attrs
  def initialize(definition, at_mm, layer: 'Untagged', turn: false, attrs: {})
    super(); @definition = definition; @transformation = Geom::Transformation.new(*at_mm.map { |v| v * MM }, turn); @layer = Layer.new(layer); @attrs = attrs
  end
  def get_attribute(dict, key, default = nil); @attrs.dig(dict, key) || default; end
end
FakeModel = Struct.new(:entities, :layers)

ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
require File.join(ROOT, 'core/levels')
require File.join(ROOT, 'core/rooms')
require File.join(ROOT, 'core/geometry')
require File.join(ROOT, 'core/opening_probe')
RO = VGD::BIM::RoomOpenings
RM = VGD::BIM::Rooms
OP = VGD::BIM::OpeningProbe

room = ->(id, x0, y0, x1, y1, elevation: 0, height: 3000) { {'id' => id, 'name' => id, 'number' => '', 'level' => '', 'height' => height, 'elevation' => elevation, 'boundary' => [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]} }
a = room.call('rm_aaaaaaaa', 0, 0, 4000, 3000)
b = room.call('rm_bbbbbbbb', 4200, 0, 8000, 3000) # tường 200 giữa hai phòng: x 4000..4200
door = ->(x, y, w: 900, h: 2100, z0: 0, exact: false) { {x: x, y: y, z0: z0, z1: z0 + h, width: w, height: h, exact: exact} }

# 1. Ghép cửa với phòng
r = RO.match([door.call(2000, -100)], [a, b])
ok 'cửa ở tường ngoài phòng A: chỉ trừ cho A', r[:rooms].keys == ['rm_aaaaaaaa'] && r[:rooms]['rm_aaaaaaaa']['count'] == 1 && r[:unmatched].zero?
ok 'diện tích cửa 0,9 x 2,1 = 1,89 m2', r[:rooms]['rm_aaaaaaaa']['area'] == 1.89
r = RO.match([door.call(4100, 1500)], [a, b])
ok 'cửa trong tường chung: trừ cho cả hai phòng', r[:rooms].keys.sort == %w[rm_aaaaaaaa rm_bbbbbbbb] && r[:rooms].values.all? { |e| e['count'] == 1 }
r = RO.match([door.call(2000, 1500)], [a, b])
ok 'món giữa phòng (xa tường): không trừ, đếm là không thuộc phòng', r[:rooms].empty? && r[:unmatched] == 1
r = RO.match([door.call(2000, -600)], [a])
ok 'cửa xa tường hơn 400 mm: không trừ', r[:rooms].empty?
r = RO.match([door.call(2000, -100, z0: 3200)], [a])
ok 'cửa ở tầng trên (ngoài khoảng cao phòng): không trừ', r[:rooms].empty?
r = RO.match([door.call(2000, -100, h: 3500)], [a])
ok 'cửa cao hơn trần: chỉ trừ phần trong phòng (0,9 x 3,0)', r[:rooms]['rm_aaaaaaaa']['area'] == 2.7
r = RO.match([door.call(2000, -100, exact: true), door.call(3000, -100)], [a])
ok 'đếm số cửa ước tính theo khung bao', r[:rooms]['rm_aaaaaaaa']['count'] == 2 && r[:rooms]['rm_aaaaaaaa']['estimated'] == 1
holed = a.merge('holes' => [[[1800, 1300], [2200, 1300], [2200, 1700], [1800, 1700]]])
ok 'cửa sát lỗ (vách hộp kỹ thuật) cũng được trừ', RO.match([door.call(2000, 1250)], [holed])[:rooms].size == 1

# 2. Dữ liệu lưu trong phòng và số đo
clean = RM.sanitize!([a.merge('openings' => {'count' => 2, 'area' => 3.78, 'estimated' => 1, 'tags' => ['A. DOOR']})])
ok 'lưu số cửa trong phòng', clean[0]['openings'] == {'count' => 2, 'area' => 3.78, 'estimated' => 1, 'tags' => ['A. DOOR']}
m = RM.metrics(clean[0])
ok 'tường đã trừ cửa: 14 x 3 - 3,78 = 38,22 m2', m[:wall_gross] == 42.0 && m[:wall_area] == 38.22 && m[:openings_area] == 3.78 && m[:openings_count] == 2
m = RM.metrics(RM.sanitize!([a])[0])
ok 'chưa trừ cửa: tường như cũ, không có số cửa', m[:wall_area] == 42.0 && m[:openings_count].nil? && !RM.sanitize!([a])[0].key?('openings')
ok 'cửa lớn hơn tường: tường không âm', RM.metrics(RM.sanitize!([a.merge('openings' => {'count' => 1, 'area' => 99.0})])[0])[:wall_area] == 0.0
bad = ->(o) { error_of { RM.sanitize!([a.merge('openings' => o)]) }.to_s.include?('cửa đã trừ') }
ok 'dữ liệu cửa sai bị từ chối', bad.call('x') && bad.call({'count' => -1, 'area' => 1}) && bad.call({'count' => 1, 'area' => -1}) && bad.call({'count' => 1, 'area' => 1, 'estimated' => 2}) && bad.call({'count' => 1.5, 'area' => 1}) && bad.call({'count' => 1, 'area' => 1, 'tags' => [1]})

# 3. Danh sách tag cửa
ok 'tag cửa: bỏ trống / trùng', RO.tags!([' A. DOOR ', 'A. DOOR', '', 'A. WINDOW']) == ['A. DOOR', 'A. WINDOW']
ok 'tag cửa: rỗng bị từ chối', error_of { RO.tags!([]) }.to_s.include?('ít nhất một tag')
ok 'tag cửa: không phải danh sách bị từ chối', error_of { RO.tags!('A') }.to_s.include?('không hợp lệ')
ok 'tag cửa: Untagged bị từ chối', error_of { RO.tags!(['Untagged']) }.to_s.include?('Untagged')
ok 'tag cửa: quá nhiều bị từ chối', error_of { RO.tags!((1..60).map { |i| "T#{i}" }) }.to_s.include?('Tối đa')

# 4. Đọc cửa theo tag trong model giả lập
door_def = FakeDef.new([], [900, 50, 2100])
window_def = FakeDef.new([], [1200, 40, 1200])
inner_door = FakeInstance.new(door_def, [100, 0, 0], layer: 'A. DOOR')
cabinet_def = FakeDef.new([FakeInstance.new(FakeDef.new([], [500, 500, 800]), [0, 0, 0], layer: 'F. CABINET')], [500, 500, 800])
wing_def = FakeDef.new([inner_door], [2000, 200, 2800]) # group chứa một cửa bên trong
struct_attrs = {'VGD_BIM_SOURCE' => {'plugin' => 'vgd_structure', 'kind' => 'door'}, 'VGD_STRUCT' => {'dims' => JSON.generate('w' => 800, 'h' => 2000)}}
entities = [
  FakeInstance.new(door_def, [1550, -100, 0], layer: 'A. DOOR'),                  # cửa ở tường dưới của A
  FakeInstance.new(window_def, [5000, 2975, 900], layer: 'A. WINDOW'),            # cửa sổ ở tường trên của B
  FakeInstance.new(window_def, [5000, 2975, 900], layer: 'A. WINDOW'),            # bản sao trùng chỗ: vẫn là hai cửa
  FakeInstance.new(cabinet_def, [1000, 1000, 0], layer: 'Untagged'),              # tủ: không phải cửa
  FakeInstance.new(wing_def, [4000, 600, 0]),                                     # cửa nằm trong group
  FakeInstance.new(FakeDef.new([], [100, 1000, 2400]), [4050, 1500, 0], layer: 'A. DOOR', attrs: struct_attrs) # cửa của VGD Structure trong tường chung
]
model = FakeModel.new(entities, [Layer.new('A. DOOR'), Layer.new('A. WINDOW')])
scan = OP.collect(model, ['A. DOOR', 'A. WINDOW'])
ok 'tìm được 5 cửa theo tag (kể cả trong group), không lấy tủ', scan[:openings].size == 5 && !scan[:truncated]
first = scan[:openings].first
ok 'cửa đo theo khung bao: rộng 900, cao 2100, tâm (2000, -75)', first[:width].round == 900 && first[:height].round == 2100 && first[:x].round == 2000 && first[:y].round == -75 && !first[:exact]
struct = scan[:openings].last
ok 'cửa VGD Structure dùng số đo lỗ chính xác 800 x 2000', struct[:width] == 800.0 && struct[:height] == 2000.0 && struct[:exact]
nested = scan[:openings][3]
ok 'cửa trong group: vị trí cộng cả biến đổi của group', nested[:x].round == 4550 && nested[:y].round == 625
ok 'chỉ tag cửa sổ: 2 cửa sổ', OP.collect(model, ['A. WINDOW'])[:openings].size == 2
turned = OP.collect(FakeModel.new([FakeInstance.new(door_def, [2000, 0, 0], layer: 'A. DOOR', turn: true)], []), ['A. DOOR'])[:openings][0]
ok 'cửa xoay 90 độ: rộng vẫn là chiều ngang lớn hơn (900)', turned[:width].round == 900
plan = RO.match(scan[:openings], [a, b])
ok 'ghép vào phòng: A có cửa đi + cửa Structure, B có 2 cửa sổ + cửa trong group + cửa Structure', plan[:rooms]['rm_aaaaaaaa']['count'] == 2 && plan[:rooms]['rm_bbbbbbbb']['count'] == 4
ok 'diện tích của B: 2 x 1,44 + 1,89 + 1,6 = 6,37 m2', plan[:rooms]['rm_bbbbbbbb']['area'] == 6.37

# 5. Duyệt có giới hạn, định nghĩa không chứa cửa không duyệt lại
many = Array.new(OP::MAX_VISITS + 1) { FakeInstance.new(door_def, [0, 0, 0], layer: 'X') }
ok 'quá nhiều đối tượng: dừng và báo', OP.collect(FakeModel.new(many, []), ['A. DOOR'])[:truncated]
counter = Class.new(FakeDef) { attr_reader :reads; def entities; @reads = (@reads || 0) + 1; super; end }.new([FakeInstance.new(FakeDef.new([], [10, 10, 10]), [0, 0, 0])], [100, 100, 100])
OP.collect(FakeModel.new(Array.new(5) { FakeInstance.new(counter, [0, 0, 0]) }, []), ['A. DOOR'])
ok 'định nghĩa không có cửa chỉ duyệt một lần cho mọi bản sao', counter.reads == 1

puts($fails.zero? ? 'ALL PASS' : "#{$fails} FAIL")
exit($fails.zero? ? 0 : 1)
