# Test phần đọc tường của việc dò phòng (core/room_detect_probe.rb) với model giả lập: cắt mặt đứng ở độ cao cắt, lỗ cửa, group lồng nhau,
# bỏ qua mặt nằm ngang / đối tượng ẩn, chân tường làm mốc, rồi nối với RoomDetect.detect. Chạy: ruby dev/test_room_detect_probe.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end

module Sketchup
  class Face; end
  class Group; end
  class ComponentInstance; end
end

MM = 1 / 25.4 # SketchUp đo bằng inch
Pt = Struct.new(:x, :y, :z)
class Shift # biến đổi chỉ gồm phép dời (inch)
  attr_reader :dx, :dy, :dz
  def initialize(dx = 0, dy = 0, dz = 0); @dx = dx; @dy = dy; @dz = dz; end
  def *(other)
    other.is_a?(Shift) ? Shift.new(@dx + other.dx, @dy + other.dy, @dz + other.dz) : Pt.new(other.x + @dx, other.y + @dy, other.z + @dz)
  end
end
Vert = Struct.new(:position)
Loop_ = Struct.new(:vertices)
class FakeFace < Sketchup::Face
  attr_reader :outer_loop, :loops
  attr_accessor :hidden, :layer
  def initialize(rings_mm) # vòng đầu là vòng ngoài; điểm [x, y, z] mm
    super()
    @loops = rings_mm.map { |ring| Loop_.new(ring.map { |x, y, z| Vert.new(Pt.new(x * MM, y * MM, z * MM)) }) }
    @outer_loop = @loops.first
    @hidden = false
  end
  def hidden?; @hidden; end
end
class FakeGroup < Sketchup::Group
  attr_reader :entities, :transformation
  attr_accessor :hidden
  def initialize(entities, shift = Shift.new); super(); @entities = entities; @transformation = shift; @hidden = false; end
  def hidden?; @hidden; end
end
class FakeDefinition; attr_reader :entities; def initialize(e); @entities = e; end; end
class FakeInstance < Sketchup::ComponentInstance
  attr_reader :definition, :transformation
  def initialize(entities, shift = Shift.new); super(); @definition = FakeDefinition.new(entities); @transformation = shift; end
end

ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
require File.join(ROOT, 'core/levels')
require File.join(ROOT, 'core/rooms')
require File.join(ROOT, 'core/room_detect')
require File.join(ROOT, 'core/room_detect_probe')
P = VGD::BIM::RoomDetectProbe

# Tường đứng cao `h` mm dọc từ (x0, y0) tới (x1, y1), chân ở z0.
def wall(x0, y0, x1, y1, h: 2800, z0: 0, holes: [])
  outer = [[x0, y0, z0], [x1, y1, z0], [x1, y1, z0 + h], [x0, y0, z0 + h]]
  FakeFace.new([outer] + holes)
end

# Phòng 4 x 3 m bằng bốn mặt tường
def room_walls(x0 = 0, y0 = 0, x1 = 4000, y1 = 3000, **opts)
  [wall(x0, y0, x1, y0, **opts), wall(x1, y0, x1, y1, **opts), wall(x1, y1, x0, y1, **opts), wall(x0, y1, x0, y0, **opts)]
end

ctx = Shift.new

# 1. Bốn mặt tường -> bốn đoạn ở độ cao cắt
r = P.read(room_walls, ctx, 2400)
ok 'bốn tường: bốn đoạn', r[:segments].size == 4 && r[:walls] == 4 && r[:faces] == 4
ok 'chân tường 0, đỉnh 2800', r[:floor].round(3) == 0.0 && r[:top].round(3) == 2800.0
ok 'đoạn đúng tọa độ mm', r[:segments].any? { |sg| [sg[0, 2], sg[2, 2]].sort.flatten.map { |v| v.round(3) } == [0.0, 0.0, 4000.0, 0.0] }
res = RD = VGD::BIM::RoomDetect.detect(r[:segments])
ok 'nối với RoomDetect: một phòng 12 m2', res[:regions].size == 1 && (res[:regions][0][:area] / 1e6).round(2) == 12.0

# 2. Cao độ cắt tính từ chân tường (tường đặt ở z = 3000)
r = P.read(room_walls(z0: 3000), ctx, 2400)
ok 'tường đặt cao 3000: vẫn cắt được, chân tường 3000', r[:segments].size == 4 && r[:floor].round(3) == 3000.0

# 3. Cắt cao hơn tường: không ra đoạn, vẫn báo chiều cao tường
r = P.read(room_walls(h: 2000), ctx, 2400)
ok 'cắt cao hơn tường: không có đoạn', r[:segments].empty? && r[:walls] == 0 && r[:faces] == 4 && r[:top].round(3) == 2000.0

# 4. Lỗ cửa cao 2100: cắt ở 2400 vẫn liền, cắt ở 1000 bị hở
door = [[1000, 0, 0], [1900, 0, 0], [1900, 0, 2100], [1000, 0, 2100]]
faces = [wall(0, 0, 4000, 0, holes: [door])] + room_walls(0, 0, 4000, 3000)[1..]
r = P.read(faces, ctx, 2400)
ok 'cửa thấp hơn mặt cắt: tường liền một đoạn', r[:segments].count { |s| s[1].abs < 1e-6 && s[3].abs < 1e-6 } == 1
ok 'cửa thấp hơn mặt cắt: phòng khép kín', VGD::BIM::RoomDetect.detect(r[:segments])[:regions].size == 1
r = P.read(faces, ctx, 1000)
south = r[:segments].select { |s| s[1].abs < 1e-6 && s[3].abs < 1e-6 }.map { |s| s.values_at(0, 2).sort.map(&:round) }.sort
ok 'cắt ngang cửa: tường tách hai đoạn, chừa khe', south == [[0, 1000], [1900, 4000]]
ok 'cắt ngang cửa: không còn phòng kín', VGD::BIM::RoomDetect.detect(r[:segments])[:regions].empty?

# 5. Mặt nằm ngang và mặt nghiêng nhiều bị bỏ
floor = FakeFace.new([[[0, 0, 0], [4000, 0, 0], [4000, 3000, 0], [0, 3000, 0]]])
slab = FakeFace.new([[[0, 0, 2400], [4000, 0, 2400], [4000, 3000, 2400], [0, 3000, 2400]]])
r = P.read(room_walls + [floor, slab], ctx, 2400)
ok 'mặt nằm ngang không tính', r[:segments].size == 4 && r[:faces] == 4

# 6. Group và component lồng nhau, có dời chỗ
inner = FakeGroup.new(room_walls(0, 0, 4000, 3000), Shift.new(1000 * MM, 500 * MM, 0))
outer = FakeInstance.new([inner], Shift.new(0, 0, 200 * MM))
r = P.read([outer], ctx, 2400)
ok 'lồng group trong component: bốn đoạn đã dời', r[:segments].size == 4 && r[:segments].flatten.min.round == 500 && r[:floor].round(3) == 200.0
ok 'đoạn đã dời: góc dưới trái ở (1000, 500)', r[:segments].map { |s| s[0, 2].map(&:round) }.include?([1000, 500])
r = P.read(room_walls, Shift.new(2000 * MM, 0, 0), 2400)
ok 'ngữ cảnh group đang mở được cộng vào', r[:segments].any? { |sg| [sg[0, 2], sg[2, 2]].sort.flatten.map(&:round) == [2000, 0, 6000, 0] }

# 7. Đối tượng ẩn / tag ẩn bị bỏ
hidden = FakeGroup.new(room_walls); hidden.hidden = true
ok 'group ẩn bị bỏ', P.read([hidden], ctx, 2400)[:segments].empty?
hidden_face = wall(0, 0, 4000, 0); hidden_face.hidden = true
ok 'mặt ẩn bị bỏ', P.read([hidden_face], ctx, 2400)[:faces] == 0
Layer = Struct.new(:visible?)
off = wall(0, 0, 4000, 0); off.layer = Layer.new(false)
ok 'tag đang tắt bị bỏ', P.read([off], ctx, 2400)[:faces] == 0

# 8. Chọn rỗng, độ cao sai, quá nhiều mặt
r = P.read([], ctx, 2400)
ok 'chọn rỗng: không đoạn', r[:segments].empty? && r[:floor].nil? && r[:faces] == 0
ok 'độ cao cắt 0 bị từ chối', error_of { P.read(room_walls, ctx, 0) }.to_s.include?('lớn hơn 0')
ok 'độ cao cắt không phải số bị từ chối', error_of { P.read(room_walls, ctx, 'x') }.to_s.include?('lớn hơn 0')
ok 'quá nhiều mặt: dừng và báo', P.read(Array.new(P::MAX_FACES + 5) { wall(0, 0, 100, 0) }, ctx, 2400)[:truncated] == true

# 9. Tường lõm (chữ L) cắt đúng, mặt nghiêng nhẹ (< 3 độ) coi như đứng
l_shape = FakeFace.new([[[0, 0, 0], [4000, 0, 0], [4000, 0, 1000], [2000, 0, 1000], [2000, 0, 2800], [0, 0, 2800]]])
r = P.read([l_shape], ctx, 2400)
ok 'mặt lõm: chỉ phần cao hơn 1000 bên trái còn ở độ cao 2400', r[:segments].size == 1 && r[:segments][0].values_at(0, 2).sort.map(&:round) == [0, 2000]
lean = FakeFace.new([[[0, 0, 0], [4000, 0, 0], [4000, 30, 2800], [0, 30, 2800]]])
ok 'mặt nghiêng nhẹ vẫn là tường', P.read([lean], ctx, 1400)[:segments].size == 1

puts($fails.zero? ? 'ALL PASS' : "#{$fails} FAIL")
exit($fails.zero? ? 0 : 1)
