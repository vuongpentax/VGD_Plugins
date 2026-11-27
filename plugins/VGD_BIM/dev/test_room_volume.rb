# Test dựng khối phòng dạng KHUNG DÂY (runtime/vgd_bim/core/room_volume.rb, nhập từ VGD_Room vào BIM) với SketchUp giả lập đơn giản: kiểm tra dữ liệu sai, khung dây đúng (viền sàn, viền trần, cạnh đứng,
# cao độ, chiều cao, không có mặt nào), tag / tên, dữ liệu cầu nối (VGD ID, nguồn), dựng lại giữ ID và thay khối cũ, một thao tác, hủy khi lỗi. Chạy: ruby dev/test_builder.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end

module Geom
  class Point3d
    attr_reader :x, :y, :z
    def initialize(x, y, z); @x = x; @y = y; @z = z; end
  end
end
module Sketchup
  class Group
    attr_reader :entities, :attrs
    attr_accessor :name, :layer, :material
    attr_writer :locked
    def initialize(model); @model = model; @entities = FakeEntities.new; @attrs = {}; @erased = false; @locked = false; end
    def get_attribute(dict, key, default = nil); @attrs.dig(dict, key).nil? ? default : @attrs[dict][key]; end
    def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; end
    def locked?; @locked; end
    def erase!; @erased = true; @model.entities.items.delete(self); true; end
    def valid?; !@erased; end
  end
  class Edge
    attr_reader :start_point, :end_point
    def initialize(a, b); @start_point = a; @end_point = b; end
  end
  class Face
    attr_reader :points, :pushed, :erased
    def initialize(points, entities = nil); @points = points; @flipped = false; @pushed = nil; @entities = entities; @erased = false; end
    def erase!; @erased = true; @entities.items.delete(self) if @entities; true; end
    def normal; Struct.new(:z).new(@flipped ? -@natural : @natural); end
    def natural=(value); @natural = value; end
    def reverse!; @flipped = !@flipped; end
    def pushpull(distance); @pushed = distance; end
  end
end
class FakeEntities
  attr_reader :items
  def initialize(model = nil); @items = []; @model = model; end
  def add_group; g = Sketchup::Group.new(@model); @items << g; g; end
  def add_face(points)
    face = Sketchup::Face.new(points, self)
    area = points.each_with_index.sum { |p, i| q = points[(i + 1) % points.size]; p.x * q.y - q.x * p.y }
    face.natural = area >= 0 ? 1 : -1 # chiều đi ngược kim đồng hồ: pháp tuyến hướng lên
    @items << face; face
  end
  def to_a; @items.dup; end
  def grep(klass); @items.grep(klass); end
  # Giả lập SketchUp: auto_faces = true thì cạnh khép kín (vòng phẳng) sinh mặt; kills_edges = true thì xóa mặt kéo theo xóa cạnh
  attr_accessor :auto_faces, :kills_edges
  def add_edges(points)
    edges = points.each_cons(2).map { |a, b| e = Sketchup::Edge.new(a, b); @items << e; e }
    @items << Sketchup::Face.new(points, self) if @auto_faces && points.first.equal?(points.last)
    edges
  end
  def add_line(a, b); e = Sketchup::Edge.new(a, b); @items << e; e; end
  def erase_entities(list)
    Array(list).each do |item|
      @items.delete(item)
      @items.reject! { |other| other.is_a?(Sketchup::Edge) } if @kills_edges && item.is_a?(Sketchup::Face)
    end
  end
end
class FakeTag
  attr_reader :name
  attr_accessor :color
  def initialize(name); @name = name; end
end
class FakeLayers
  def initialize; @names = {}; end
  def add(name); @names[name] ||= FakeTag.new(name); end
  def to_a; @names.values; end
  attr_reader :names
end
class FakeMaterial; attr_accessor :color, :alpha; attr_reader :name; def initialize(name); @name = name; end; end
class FakeMaterials; def initialize; @items = {}; end; def [](name); @items[name]; end; def add(name); @items[name] = FakeMaterial.new(name); end; attr_reader :items; end
class FakeModel
  attr_reader :entities, :layers, :materials, :ops
  def initialize; @entities = FakeEntities.new(self); @layers = FakeLayers.new; @materials = FakeMaterials.new; @ops = []; end
  def start_operation(name, disable_ui = false); @ops << [:start, name]; true; end
  def commit_operation; @ops << [:commit]; true; end
  def abort_operation; @ops << [:abort]; true; end
end

module VGD; module BIM; VERSION = '1.1.1-beta.13'; end; end # như runtime/vgd_bim.rb (không nạp SketchUp thật)
require File.expand_path('../runtime/vgd_bim/core/room_volume', __dir__)
B = VGD::BIM::RoomVolume

ID = '8a42f1c0-1111-4222-8333-444455556666'.freeze
ROOM = {'id' => 'rm_aaaaaaaa', 'name' => 'Phòng khách', 'number' => 'P01', 'elevation' => 100.0, 'height' => 2800.0,
        'boundary' => [[0.0, 0.0], [4000.0, 0.0], [4000.0, 3000.0], [0.0, 3000.0]]}.freeze

# ---- Dữ liệu sai ----
m = FakeModel.new
bad = ->(over) { error_of { B.build(m, ROOM.merge(over), ID) } }
ok('không phải bảng băm: từ chối', error_of { B.build(m, 'x', ID) }.to_s.include?('không hợp lệ'))
ok('mã phòng sai: từ chối', bad.call('id' => 'zz').to_s.include?('mã phòng'))
ok('viền ít hơn 3 điểm / không phải số: từ chối', bad.call('boundary' => [[0, 0], [1, 1]]).to_s.include?('viền') && bad.call('boundary' => [[0, 0], [1, 'a'], [2, 3]]).to_s.include?('viền') && bad.call('boundary' => 'x').to_s.include?('viền') && bad.call('boundary' => [[0, 0], [Float::NAN, 1], [2, 3]]).to_s.include?('viền'))
ok('quá nhiều điểm: từ chối', bad.call('boundary' => Array.new(B::MAX_POINTS + 1) { |i| [i * 10.0, (i * i % 97) * 10.0] }).to_s.include?('viền'))
ok('chiều cao sai (0, âm, quá lớn, chữ): từ chối', [0, -1, 100_001, '2800', nil].all? { |h| bad.call('height' => h).to_s.include?('chiều cao') })
ok('cao độ sai: từ chối', ['0', nil, Float::INFINITY].all? { |e| bad.call('elevation' => e).to_s.include?('cao độ') })
ok('VGD ID sai dạng: từ chối', error_of { B.build(m, ROOM, 'abc') }.to_s.include?('VGD ID') && error_of { B.build(m, ROOM, nil) }.to_s.include?('VGD ID'))
ok('dữ liệu sai không mở thao tác, không thêm hình', m.ops.empty? && m.entities.items.empty?)

# ---- Dựng khối ----
group = B.build(m, ROOM, ID)
edges = group.entities.items
floor_z = 100.0 / 25.4
top_z = (100.0 + 2800.0) / 25.4
ok('dựng một Group chỉ có cạnh (12 cạnh), không có mặt nào: mặt cắt của SketchUp không bị tô kín', group.is_a?(Sketchup::Group) && edges.size == 12 && edges.all? { |e| e.is_a?(Sketchup::Edge) } && group.entities.grep(Sketchup::Face).empty?)
floor_ring = edges.select { |e| [e.start_point.z, e.end_point.z].all? { |z| (z - floor_z).abs < 1e-9 } }
top_ring = edges.select { |e| [e.start_point.z, e.end_point.z].all? { |z| (z - top_z).abs < 1e-9 } }
verticals = edges - floor_ring - top_ring
ok('viền sàn ở cao độ sàn, viền trần ở cao độ sàn + chiều cao (mm đổi sang inch), đúng viền', floor_ring.size == 4 && top_ring.size == 4 && floor_ring.flat_map { |e| [e.start_point.x, e.end_point.x] }.max.then { |x| (x - 4000.0 / 25.4).abs < 1e-9 } && floor_ring.flat_map { |e| [e.start_point.y, e.end_point.y] }.max.then { |y| (y - 3000.0 / 25.4).abs < 1e-9 })
ok('bốn cạnh đứng nối đúng từng góc sàn lên trần', verticals.size == 4 && verticals.all? { |e| (e.start_point.x - e.end_point.x).abs < 1e-9 && (e.start_point.y - e.end_point.y).abs < 1e-9 && (e.start_point.z - floor_z).abs < 1e-9 && (e.end_point.z - top_z).abs < 1e-9 })
cw = ROOM.merge('boundary' => ROOM['boundary'].reverse)
cw_group = B.build(FakeModel.new, cw, ID)
ok('viền đi theo chiều kim đồng hồ: vẫn đủ 12 cạnh (chiều viền không còn ảnh hưởng)', cw_group.entities.items.size == 12 && cw_group.entities.grep(Sketchup::Face).empty?)
ok('tên khối, tag VGD_ROOMS, không có vật liệu (khung dây chỉ có cạnh)', group.name == 'Phòng · P01 · Phòng khách' && group.layer.name == 'VGD_ROOMS' && group.material.nil? && m.materials.items.empty?)
ok('tag VGD_ROOMS mới tạo có màu xanh nhạt', group.layer.color == B::TAG_COLOR)
mine = FakeModel.new
mine.layers.add('VGD_ROOMS').color = [1, 2, 3]
ok('tag VGD_ROOMS đã có: giữ nguyên màu của người dùng', B.build(mine, ROOM, ID).layer.color == [1, 2, 3])
ok('dữ liệu cầu nối: VGD ID, plugin, phiên bản, loại phòng, mã phòng BIM', group.get_attribute('VGD_BIM_ID', 'guid') == ID && group.get_attribute('VGD_BIM_SOURCE', 'plugin') == 'vgd_bim' && group.get_attribute('VGD_BIM_SOURCE', 'kind') == 'room' && group.get_attribute('VGD_BIM_SOURCE', 'ref') == 'rm_aaaaaaaa' && !group.get_attribute('VGD_BIM_SOURCE', 'plugin_version').to_s.empty? && !group.attrs.key?('VGD_BIM'))
ok('một thao tác có commit', m.ops == [[:start, 'VGD_BIM · Dựng khối phòng'], [:commit]])
ok('find: tìm khối theo mã phòng; phòng khác thì nil', B.find(m, 'rm_aaaaaaaa').equal?(group) && B.find(m, 'rm_bbbbbbbb').nil? && B.find(Object.new, 'rm_aaaaaaaa').nil?)
nested_host = Sketchup::Group.new(m); m.entities.items << nested_host
nested_vol = Sketchup::Group.new(m); nested_vol.set_attribute('VGD_BIM_SOURCE', 'kind', 'room'); nested_vol.set_attribute('VGD_BIM_SOURCE', 'ref', 'rm_cccccccc'); nested_host.entities.items << nested_vol
ok('find: khối nằm trong group khác vẫn tìm thấy (không dựng trùng)', B.find(m, 'rm_cccccccc').equal?(nested_vol))
m.entities.items.delete(nested_host) # dọn: các kiểm tra sau đếm khối trong model

# ---- Dựng lại ----
m.ops.clear
newer = B.build(m, ROOM.merge('height' => 3000.0, 'name' => 'Khách lớn'), '11111111-2222-4333-8444-555555555555')
ok('dựng lại: khối cũ bị thay bằng khối mới (chỉ còn một), giữ VGD ID cũ, cập nhật tên', m.entities.items.grep(Sketchup::Group).size == 1 && !group.valid? && newer.get_attribute('VGD_BIM_ID', 'guid') == ID && newer.name == 'Phòng · P01 · Khách lớn' && newer.entities.items.map { |e| [e.start_point.z, e.end_point.z] }.flatten.max.then { |z| (z - (100.0 + 3000.0) / 25.4).abs < 1e-9 })
ok('dựng lại cũng chỉ một thao tác', m.ops == [[:start, 'VGD_BIM · Dựng khối phòng'], [:commit]])
newer.locked = true
m.ops.clear
ok('khối cũ đang bị khóa: từ chối, hủy thao tác, khối cũ còn nguyên', error_of { B.build(m, ROOM, ID) }.to_s.include?('khóa') && m.ops.last == [:abort] && newer.valid? && m.entities.items.grep(Sketchup::Group).size == 1)
newer.locked = false
failing = FakeModel.new
failing.entities.define_singleton_method(:add_group) { raise 'SketchUp lỗi' }
ok('lỗi giữa chừng: hủy thao tác và báo lỗi', error_of { B.build(failing, ROOM, ID) } == 'SketchUp lỗi' && failing.ops.last == [:abort])
other = B.build(m, ROOM.merge('id' => 'rm_cccccccc', 'name' => 'Bếp', 'number' => ''), '99999999-aaaa-4bbb-8ccc-dddddddddddd')
ok('phòng khác: khối riêng, tên không có mã khi mã rỗng, không đụng khối phòng khác', other.name == 'Phòng · Bếp' && m.entities.items.grep(Sketchup::Group).size == 2 && B.find(m, 'rm_aaaaaaaa').equal?(newer))

# ---- Phòng có lỗ (cột, hộp kỹ thuật) ----
COL = [[1000.0, 1000.0], [1400.0, 1000.0], [1400.0, 1400.0], [1000.0, 1400.0]].freeze
COL2 = [[2500.0, 1500.0], [2900.0, 1500.0], [2900.0, 1900.0], [2500.0, 1900.0]].freeze
hm = FakeModel.new
hole_bad = ->(holes) { error_of { B.build(hm, ROOM.merge('holes' => holes), ID) } }
ok('lỗ không phải mảng / lỗ ít hơn 3 điểm / điểm không phải số: từ chối', %w[x].all? { |v| hole_bad.call(v).to_s.include?('lỗ') } && hole_bad.call([[[0, 0], [1, 1]]]).to_s.include?('lỗ') && hole_bad.call([[[0, 0], [1, 'a'], [2, 3]]]).to_s.include?('lỗ') && hole_bad.call(['abc']).to_s.include?('lỗ'))
ok("quá #{B::MAX_HOLES} lỗ hoặc lỗ quá nhiều điểm: từ chối", hole_bad.call(Array.new(B::MAX_HOLES + 1) { COL }).to_s.include?('lỗ') && hole_bad.call([Array.new(B::MAX_POINTS + 1) { |i| [i * 10.0, (i * i % 97) * 10.0] }]).to_s.include?('lỗ'))
ok('lỗ sai không mở thao tác, không thêm hình', hm.ops.empty? && hm.entities.items.empty?)
ok('lỗ rỗng hoặc không có: vẫn dựng như phòng thường (12 cạnh)', B.build(FakeModel.new, ROOM.merge('holes' => []), ID).entities.items.size == 12 && B.build(FakeModel.new, ROOM.merge('holes' => nil), ID).entities.items.size == 12)
holed = B.build(hm, ROOM.merge('holes' => [COL, COL2]), ID)
ok('phòng có hai lỗ: khung dây của viền ngoài (12 cạnh) cộng mỗi lỗ 12 cạnh = 36 cạnh, không có mặt', holed.entities.items.size == 36 && holed.entities.grep(Sketchup::Face).empty?)
hole_pts = holed.entities.items.flat_map { |e| [e.start_point, e.end_point] }
ok('viền các lỗ nằm đúng chỗ (có điểm ở góc lỗ thứ nhất và thứ hai)', hole_pts.any? { |p| (p.x - 1000.0 / 25.4).abs < 1e-9 && (p.y - 1000.0 / 25.4).abs < 1e-9 } && hole_pts.any? { |p| (p.x - 2900.0 / 25.4).abs < 1e-9 && (p.y - 1900.0 / 25.4).abs < 1e-9 })
# SketchUp tự sinh mặt từ cạnh khép kín: mặt bị xóa, cạnh còn nguyên
auto = FakeModel.new
auto.entities.define_singleton_method(:add_group) { g = super(); g.entities.auto_faces = true; g }
auto_group = B.build(auto, ROOM, ID)
ok('SketchUp tự sinh mặt từ cạnh khép kín: mặt bị xóa, 12 cạnh còn nguyên', auto_group.entities.grep(Sketchup::Face).empty? && auto_group.entities.grep(Sketchup::Edge).size == 12)
lost = FakeModel.new
lost.entities.define_singleton_method(:add_group) { g = super(); g.entities.auto_faces = true; g.entities.kills_edges = true; g }
ok('xóa mặt kéo theo mất cạnh: báo lỗi rõ, hủy thao tác (không để lại khối hỏng)', error_of { B.build(lost, ROOM, ID) }.to_s.include?('khung dây') && lost.ops.last == [:abort])
ok('phòng có lỗ vẫn một thao tác có commit', hm.ops == [[:start, 'VGD_BIM · Dựng khối phòng'], [:commit]])

# ---- Dựng nhiều phòng một lần (một bước hoàn tác) ----
ID2 = '22222222-3333-4444-8555-666666666666'.freeze
ID3 = '33333333-4444-4555-8666-777777777777'.freeze
R2 = ROOM.merge('id' => 'rm_bbbbbbbb', 'name' => 'Phòng ngủ', 'number' => 'P02')
R3 = ROOM.merge('id' => 'rm_cccccccc', 'name' => 'Bếp', 'number' => '', 'holes' => [COL])
bm = FakeModel.new
many = B.build_many(bm, [[ROOM, ID], [R2, ID2], [R3, ID3]])
ok('dựng ba phòng: ba khối, đúng thứ tự, mỗi khối có VGD ID riêng', many.size == 3 && many.map(&:name) == ['Phòng · P01 · Phòng khách', 'Phòng · P02 · Phòng ngủ', 'Phòng · Bếp'] && many.map { |g| g.get_attribute('VGD_BIM_ID', 'guid') } == [ID, ID2, ID3])
ok('cả đợt chỉ MỘT thao tác (một bước hoàn tác)', bm.ops == [[:start, 'VGD_BIM · Dựng khối nhiều phòng'], [:commit]])
ok('phòng có lỗ trong đợt: khung dây có thêm viền lỗ (24 cạnh)', many[2].entities.items.size == 24)
bm.ops.clear
again = B.build_many(bm, [[ROOM.merge('height' => 2500.0), '44444444-5555-4666-8777-888888888888'], [R2, ID2]])
ok('dựng lại cả đợt: khối cũ bị thay (còn đúng 3 khối), giữ VGD ID cũ, một thao tác', bm.entities.items.grep(Sketchup::Group).size == 3 && again[0].get_attribute('VGD_BIM_ID', 'guid') == ID && again[0].entities.items.map { |e| [e.start_point.z, e.end_point.z] }.flatten.max.then { |z| (z - (100.0 + 2500.0) / 25.4).abs < 1e-9 } && bm.ops.size == 2)
sm = FakeModel.new
bad_items = [[[ROOM, ID], [ROOM.merge('id' => 'rm_zz'), ID2]], [[ROOM, ID], [R2, 'abc']], [[ROOM, ID], [ROOM, ID2]], [], 'x', [[ROOM]], Array.new(B::MAX_BATCH + 1) { [ROOM, ID] }]
errors = bad_items.map { |items| error_of { B.build_many(sm, items) } }
ok('đợt sai (phòng sai dữ liệu, VGD ID sai, trùng mã, rỗng, sai kiểu, quá nhiều): từ chối', errors.all? { |e| e.to_s.include?('không hợp lệ') || e.to_s.include?('mã phòng') || e.to_s.include?('VGD ID') || e.to_s.include?('trùng') })
ok('đợt sai không mở thao tác, không thêm hình (kiểm tra hết trước khi đụng model)', sm.ops.empty? && sm.entities.items.empty?)
lm = FakeModel.new
first = B.build(lm, ROOM, ID)
second = B.build(lm, R2, ID2)
second.locked = true
lm.ops.clear
ok('một khối cũ bị khóa trong đợt: từ chối, hủy cả thao tác', error_of { B.build_many(lm, [[ROOM, ID], [R2, ID2]]) }.to_s.include?('khóa') && lm.ops.last == [:abort])
fm = FakeModel.new
calls = 0
fm.entities.define_singleton_method(:add_group) { calls += 1; raise 'SketchUp lỗi' if calls == 2; super() }
ok('lỗi ở phòng thứ hai: hủy cả đợt', error_of { B.build_many(fm, [[ROOM, ID], [R2, ID2]]) } == 'SketchUp lỗi' && fm.ops.last == [:abort])

puts($fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
