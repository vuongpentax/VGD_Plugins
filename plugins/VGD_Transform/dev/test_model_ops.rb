# Test phần gọi SketchUp (core/model_ops.rb) với SketchUp giả lập: đọc món (điểm gốc, trục riêng, tỉ lệ, hộp bao),
# áp dụng dời / xoay / scale trong group cha, đặt biến đổi đúng một lần, kiểm tra ma trận, món khóa, một thao tác hoàn tác,
# kéo trực tiếp (đặt lại trạng thái đầu, gộp bước Ctrl+Z). Biến đổi giả lập bằng ma trận 4×4 độc lập với công thức trong code.
# Chạy: ruby dev/test_model_ops.rb (từ plugins/VGD_Transform)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_transform', __dir__)

module Geom
  class Point3d
    attr_reader :x, :y, :z
    def initialize(x = 0.0, y = 0.0, z = 0.0); @x = x.to_f; @y = y.to_f; @z = z.to_f; end
  end
  class Vector3d
    attr_reader :x, :y, :z
    def initialize(x = 0.0, y = 0.0, z = 0.0); @x = x.to_f; @y = y.to_f; @z = z.to_f; end
  end
  # Ma trận 4×4 theo dòng; to_a trả theo cột như SketchUp.
  class Transformation
    IDENTITY = [[1.0, 0.0, 0.0, 0.0], [0.0, 1.0, 0.0, 0.0], [0.0, 0.0, 1.0, 0.0], [0.0, 0.0, 0.0, 1.0]].freeze
    attr_reader :m
    def initialize(m = IDENTITY); @m = m.map(&:dup); end
    def self.translation(v); new([[1.0, 0.0, 0.0, v.x], [0.0, 1.0, 0.0, v.y], [0.0, 0.0, 1.0, v.z], [0.0, 0.0, 0.0, 1.0]]); end
    def self.scaling(x, y, z); new([[x, 0.0, 0.0, 0.0], [0.0, y, 0.0, 0.0], [0.0, 0.0, z, 0.0], [0.0, 0.0, 0.0, 1.0]]); end
    def self.axes(o, x, y, z); new([[x.x, y.x, z.x, o.x], [x.y, y.y, z.y, o.y], [x.z, y.z, z.z, o.z], [0.0, 0.0, 0.0, 1.0]]); end
    # Xoay quanh trục đi qua điểm (ma trận Rodrigues, chiều dương theo quy tắc bàn tay phải)
    def self.rotation(point, axis, angle)
      len = Math.sqrt(axis.x**2 + axis.y**2 + axis.z**2)
      kx, ky, kz = axis.x / len, axis.y / len, axis.z / len
      c = Math.cos(angle); s = Math.sin(angle); t = 1 - c
      r = [[c + kx * kx * t, kx * ky * t - kz * s, kx * kz * t + ky * s, 0.0],
           [ky * kx * t + kz * s, c + ky * ky * t, ky * kz * t - kx * s, 0.0],
           [kz * kx * t - ky * s, kz * ky * t + kx * s, c + kz * kz * t, 0.0],
           [0.0, 0.0, 0.0, 1.0]]
      translation(Vector3d.new(point.x, point.y, point.z)) * new(r) * translation(Vector3d.new(-point.x, -point.y, -point.z))
    end
    def *(o)
      case o
      when Transformation then Transformation.new(Array.new(4) { |i| Array.new(4) { |j| (0..3).sum { |k| @m[i][k] * o.m[k][j] } } })
      when Point3d then v = [o.x, o.y, o.z, 1.0]; Point3d.new(*(0..2).map { |i| (0..3).sum { |k| @m[i][k] * v[k] } })
      else raise ArgumentError, 'không hỗ trợ'
      end
    end
    def to_a; (0..3).flat_map { |j| (0..3).map { |i| @m[i][j] } }; end
    def origin; Point3d.new(@m[0][3], @m[1][3], @m[2][3]); end
    def inverse
      a = @m.map(&:dup); inv = IDENTITY.map(&:dup)
      4.times do |col|
        pivot = (col...4).max_by { |r| a[r][col].abs }
        a[col], a[pivot] = a[pivot], a[col]; inv[col], inv[pivot] = inv[pivot], inv[col]
        d = a[col][col]
        4.times { |j| a[col][j] /= d; inv[col][j] /= d }
        4.times do |r|
          next if r == col
          f = a[r][col]
          4.times { |j| a[r][j] -= f * a[col][j]; inv[r][j] -= f * inv[col][j] }
        end
      end
      Transformation.new(inv)
    end
  end
end

# Hộp bao giả lập trong definition: góc 0 ở gốc, góc 7 ở (size)
class BoundingBox
  def initialize(size); @size = size; end
  def corner(i); Geom::Point3d.new(*[0, 1, 2].map { |k| (i >> k) & 1 == 1 ? @size[k] : 0.0 }); end
  def min; Geom::Point3d.new(0.0, 0.0, 0.0); end
  def max; Geom::Point3d.new(*@size); end
end

module Sketchup
  class Group
    attr_reader :transformation, :sets
    attr_accessor :name, :locked, :valid
    # shift: tịnh tiến của gốc món (inch); size: kích thước hộp bao trong definition (inch)
    def initialize(name, shift, locked: false, size: [0.0, 0.0, 0.0])
      @name = name; @transformation = Geom::Transformation.translation(Geom::Vector3d.new(*shift)); @locked = locked; @valid = true; @sets = 0
      @definition = Struct.new(:name, :bounds).new("def #{name}", BoundingBox.new(size))
    end
    def transformation=(value); @sets += 1; @transformation = value; end
    def definition; @definition; end
    def locked?; @locked; end
    def valid?; @valid; end
  end
  class ComponentInstance < Group; end
  class Edge; end
  class Model
    attr_accessor :active_path, :selection, :ops, :options
    def initialize(entities, active_path = [], length_unit: 2)
      @active_path = active_path; @selection = entities; @ops = []
      @options = {'UnitsOptions' => {'LengthUnit' => length_unit}}
    end
    def start_operation(name, _disable = false, _next = false, transparent = false); @ops << [:start, name, transparent]; true; end
    def commit_operation; @ops << [:commit]; true; end
    def abort_operation; @ops << [:abort]; true; end
  end
end

require File.join(ROOT, 'core/model_ops')
M = VGD::Transform::ModelOps
P = VGD::Transform
RS = P::RotateScale
TR = P::Translate
MM = P::Units::MM_PER_INCH
def near(a, b, tol = 0.01); a.zip(b).all? { |x, y| (x - y).abs < tol }; end
def rotated_z(group, degrees)
  group.transformation = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1), degrees * Math::PI / 180) * group.transformation
  group
end

# ----- Đọc món -----
tu = Sketchup::Group.new('Tủ A', [1000.0 / MM, 2000.0 / MM, 300.0 / MM], size: [600.0 / MM, 400.0 / MM, 800.0 / MM])
model = Sketchup::Model.new([tu, Sketchup::Edge.new])
items = M.items(model)
it = items[0]
ok('đọc món: điểm gốc, trục, tỉ lệ 1, kích thước riêng', items.size == 1 && near(it[:origin], [1000.0, 2000.0, 300.0], 1e-6) && it[:axes] == P::Items::WORLD_AXES && near(it[:scale], [1, 1, 1], 1e-9) && near(it[:size], [600.0, 400.0, 800.0]))
ok('đọc món: hộp bao thế giới', near(it[:bounds][:min], [1000.0, 2000.0, 300.0]) && near(it[:bounds][:max], [1600.0, 2400.0, 1100.0]))
ok('cạnh / mặt trong lựa chọn được đếm là bỏ qua', M.skipped_count(model, items) == 1)
ok('đơn vị file: 2 là mm, 5 là yd, đơn vị lạ là nil', M.length_unit(model) == 'mm' && M.length_unit(Sketchup::Model.new([], [], length_unit: 5)) == 'yd' && M.length_unit(Sketchup::Model.new([], [], length_unit: 9)).nil?)
turned = rotated_z(Sketchup::Group.new('Xoay', [0.0, 0.0, 0.0], size: [1000.0 / MM, 500.0 / MM, 200.0 / MM]), 90)
ti = M.items(Sketchup::Model.new([turned]))[0]
ok('món xoay 90°: trục X riêng là Y thế giới, hộp bao X thế giới 500 mm', near(ti[:axes][0], [0.0, 1.0, 0.0], 1e-9) && near(ti[:bounds][:max].zip(ti[:bounds][:min]).map { |a, b| a - b }, [500.0, 1000.0, 200.0]))
big = Sketchup::Group.new('To', [0.0, 0.0, 0.0], size: [100.0 / MM, 100.0 / MM, 100.0 / MM])
big.transformation = Geom::Transformation.scaling(2.0, 1.0, 1.0)
ok('món đã scale ×2 theo X: tỉ lệ đọc được là 2', near(M.items(Sketchup::Model.new([big]))[0][:scale], [2.0, 1.0, 1.0], 1e-9))

# ----- Dời -----
M.apply(model, TR.absolute(items, [1500.0, nil, nil], 'item')[:moves], items)
ok('dời ở gốc: vị trí (1500, 2000, 300) mm', near(M.items(model)[0][:origin], [1500.0, 2000.0, 300.0]))
ok('một thao tác hoàn tác, không gộp, không abort', model.ops == [[:start, 'VGD Transform · Biến đổi món', false], [:commit]])
parent = Sketchup::Group.new('Cha', [100.0 / MM, 0.0, 0.0])
child = Sketchup::Group.new('Con', [50.0 / MM, 0.0, 0.0])
cm = Sketchup::Model.new([child], [parent])
ci = M.items(cm)
M.apply(cm, TR.offset(ci, [nil, 40.0, nil], 'world')[:moves], ci)
ok('dời món trong group cha: thế giới (150, 40, 0)', near(M.items(cm)[0][:origin], [150.0, 40.0, 0.0]))

# ----- Xoay, scale; biến đổi đặt đúng một lần -----
rm = Sketchup::Model.new([Sketchup::Group.new('R', [1000.0 / MM, 0.0, 0.0])])
ri = M.items(rm)
M.apply(rm, RS.rotate(ri, [90.0, 90.0, 90.0], 'world', 'world')[:moves], ri)
ok('xoay ba trục: biến đổi của món đặt đúng một lần (gộp các bước)', rm.selection[0].sets == 1)
rm2 = Sketchup::Model.new([Sketchup::Group.new('R2', [1000.0 / MM, 0.0, 0.0])])
r2 = M.items(rm2)
M.apply(rm2, RS.rotate(r2, [nil, nil, 90.0], 'world', 'world')[:moves], r2)
ok('xoay 90° quanh Z, tâm gốc thế giới: (0, 1000, 0) mm', near(M.items(rm2)[0][:origin], [0.0, 1000.0, 0.0]))
pm = Sketchup::Model.new([Sketchup::Group.new('A', [0.0, 0.0, 0.0], size: [1000.0 / MM, 1000.0 / MM, 0.0]), Sketchup::Group.new('B', [2000.0 / MM, 0.0, 0.0], size: [1000.0 / MM, 1000.0 / MM, 0.0])])
pi = M.items(pm)
M.apply(pm, RS.rotate(pi, [nil, nil, 180.0], 'selection', 'world')[:moves], pi)
ok('xoay 180° quanh tâm hộp bao (1500, 500): A từ (0, 0) sang (3000, 1000)', near(M.items(pm)[0][:origin], [3000.0, 1000.0, 0.0]))
sz = Sketchup::Model.new([Sketchup::Group.new('Tủ rộng', [0.0, 0.0, 0.0], size: [1000.0 / MM, 500.0 / MM, 200.0 / MM])])
M.apply(sz, RS.scale(M.items(sz), [{length: 1500.0}, nil, nil], 'world', 'world')[:moves], M.items(sz))
sb = M.items(sz)[0][:bounds]
ok('scale đến kích thước đích 1500 mm trên X: hộp bao 1500 × 500 × 200', near(sb[:max].zip(sb[:min]).map { |a, b| a - b }, [1500.0, 500.0, 200.0]))
lm = Sketchup::Model.new([rotated_z(Sketchup::Group.new('L', [0.0, 0.0, 0.0], size: [1000.0 / MM, 500.0 / MM, 200.0 / MM]), 90)])
li = M.items(lm)
M.apply(lm, RS.scale(li, [{length: 2000.0}, nil, nil], 'item', 'local')[:moves], li)
lb = M.items(lm)[0]
ok('scale local: món xoay 90°, X riêng 1000 → 2000 mm (hộp bao Y thế giới 2000), tỉ lệ X = 2', near(lb[:bounds][:max].zip(lb[:bounds][:min]).map { |a, b| a - b }, [500.0, 2000.0, 200.0]) && near(lb[:scale], [2.0, 1.0, 1.0], 1e-6))
am = Sketchup::Model.new([big])
ai = M.items(am)
M.apply(am, RS.absolute_scale(ai, [1.0, nil, nil], 'item')[:moves], ai)
ok('scale tuyệt đối: món đang ×2 theo X, đặt tỉ lệ 1 thì về đúng 1', near(M.items(am)[0][:scale], [1.0, 1.0, 1.0], 1e-6))

# ----- Khóa và kiểm tra sau khi áp dụng -----
km = Sketchup::Model.new([Sketchup::Group.new('Khóa', [0.0, 0.0, 0.0], locked: true)])
ki = M.items(km)
ki[0][:locked] = false # giả như lúc đọc chưa khóa, tới lúc áp dụng mới khóa
ok('món bị khóa lúc áp dụng: báo lỗi, hủy thao tác, không đổi model', error_of { M.apply(km, TR.offset(ki, [10.0, nil, nil], 'world')[:moves], ki) }.to_s.include?('đang bị khóa') && km.selection[0].sets.zero? && km.ops.map(&:first) == [:start, :abort])
ok('món trong group cha bị khóa: coi là khóa', M.items(Sketchup::Model.new([Sketchup::Group.new('Con', [0.0, 0.0, 0.0])], [Sketchup::Group.new('Cha', [0.0, 0.0, 0.0], locked: true)]))[0][:locked])
class StubbornGroup < Sketchup::Group
  def transformation=(_value); end # không cho đổi
end
sm = Sketchup::Model.new([StubbornGroup.new('Cứng đầu', [0.0, 0.0, 0.0])])
si = M.items(sm)
ok('SketchUp không đổi được vị trí: hủy cả thao tác, báo lỗi', error_of { M.apply(sm, TR.offset(si, [100.0, nil, nil], 'world')[:moves], si) }.to_s.include?('không khớp') && sm.ops.map(&:first) == [:start, :abort])
# Xoay quanh chính điểm gốc: điểm gốc không đổi, chỉ ma trận mới bắt được việc SketchUp bỏ phần xoay
class NoRotateGroup < Sketchup::Group
  def transformation=(value); super(Geom::Transformation.translation(Geom::Vector3d.new(*value.to_a[12, 3]))); end
end
nm = Sketchup::Model.new([NoRotateGroup.new('Không xoay', [100.0 / MM, 0.0, 0.0])])
ni = M.items(nm)
ok('SketchUp bỏ mất phần xoay (điểm gốc vẫn đúng): kiểm tra ma trận bắt được, hủy thao tác', error_of { M.apply(nm, RS.rotate(ni, [nil, nil, 45.0], 'item', 'world')[:moves], ni) }.to_s.include?('không khớp') && nm.ops.map(&:first) == [:start, :abort])

# ----- Khóa / mở khóa như Lock của SketchUp -----
la = Sketchup::Group.new('A', [0.0, 0.0, 0.0]); lb = Sketchup::Group.new('B', [0.0, 0.0, 0.0], locked: true)
lkm = Sketchup::Model.new([la, lb, Sketchup::Edge.new])
ok('trạng thái khóa: lẫn lộn / khóa hết / không khóa / chưa chọn', M.lock_state(lkm) == 'mixed' && M.lock_state(Sketchup::Model.new([lb])) == 'all' &&
   M.lock_state(Sketchup::Model.new([la])) == 'none' && M.lock_state(Sketchup::Model.new([Sketchup::Edge.new])).nil?)
ok('khóa: mọi group / component đang chọn bị khóa, một bước hoàn tác tên Khóa', M.set_locked(lkm, true) == 2 && la.locked? && lb.locked? && lkm.ops == [[:start, 'VGD Transform · Khóa', false], [:commit]])
lkm.ops.clear
ok('mở khóa: mọi món mở khóa, bước hoàn tác tên Mở khóa', M.set_locked(lkm, false) == 2 && !la.locked? && !lb.locked? && lkm.ops[0][1] == 'VGD Transform · Mở khóa')
ok('khóa khi chưa chọn group / component: báo lỗi, không mở thao tác', error_of { M.set_locked(Sketchup::Model.new([Sketchup::Edge.new]), true) }.to_s.include?('Chưa chọn'))
ok('món vừa khóa thì không biến đổi được', (M.set_locked(lkm, true) && error_of { M.apply(lkm, TR.offset(M.items(lkm).map { |i| i.merge(locked: false) }, [5.0, nil, nil], 'world')[:moves], M.items(lkm)) }.to_s.include?('đang bị khóa')))

# ----- Kéo trực tiếp: mỗi lần tính từ trạng thái đầu, gộp thành một bước Ctrl+Z -----
lv = Sketchup::Model.new([Sketchup::Group.new('Kéo', [0.0, 0.0, 0.0])])
lvi = M.items(lv)
originals = lvi.to_h { |i| [i[:entity], i[:entity].transformation] }
M.apply(lv, TR.offset(lvi, [100.0, nil, nil], 'world')[:moves], lvi, transparent: false, restore: originals)
M.apply(lv, TR.offset(lvi, [150.0, nil, nil], 'world')[:moves], lvi, transparent: true, restore: originals)
ok('kéo trực tiếp: lần sau tính từ trạng thái đầu (150, không phải 250)', near(M.items(lv)[0][:origin], [150.0, 0.0, 0.0]))
ok('kéo trực tiếp: lần đầu là bước mới, các lần sau gộp vào (transparent)', lv.ops.select { |o| o[0] == :start }.map { |o| o[2] } == [false, true])
sets_before = lv.selection.first.sets
M.apply(lv, TR.offset(lvi, [120.0, nil, nil], 'world')[:moves], lvi, transparent: true, restore: originals)
ok('kéo trực tiếp: mỗi nhịp ghi biến đổi của món đúng một lần (không ghi lại vị trí đầu rồi mới ghi vị trí mới)', lv.selection.first.sets - sets_before == 1)
ok('kéo trực tiếp: vẫn tính từ trạng thái đầu (120)', near(M.items(lv)[0][:origin], [120.0, 0.0, 0.0]))
M.restore(lv, originals)
ok('kéo về 0: món trở lại vị trí đầu, gộp vào cùng bước Ctrl+Z', near(M.items(lv)[0][:origin], [0.0, 0.0, 0.0]) && lv.ops[-2][2] == true)

# Món có trong bản đầu nhưng không còn trong danh sách bước thì về vị trí đầu (như khi đặt lại trước rồi áp dụng)
pm = Sketchup::Model.new([Sketchup::Group.new('A', [0.0, 0.0, 0.0]), Sketchup::Group.new('B', [10.0, 0.0, 0.0])])
pi = M.items(pm)
po = pi.to_h { |i| [i[:entity], i[:entity].transformation] }
both = TR.offset(pi, [50.0, nil, nil], 'world')[:moves]
M.apply(pm, both, pi, restore: po)
M.apply(pm, [both.first], pi, transparent: true, restore: po)
ok('kéo trực tiếp: món không còn trong danh sách bước trở về vị trí đầu', near(M.items(pm)[1][:origin], pi[1][:origin]) && near(M.items(pm)[0][:origin], [50.0, 0.0, 0.0]))

# ----- Kéo trực tiếp trong MỘT thao tác mở suốt lần kéo (không mở / đóng thao tác mỗi nhịp) -----
lm = Sketchup::Model.new([Sketchup::Group.new('Live', [0.0, 0.0, 0.0])])
li = M.items(lm)
lo = li.to_h { |i| [i[:entity], i[:entity].transformation] }
M.begin_live(lm)
M.apply_live(lm, TR.offset(li, [100.0, nil, nil], 'world')[:moves], li, lo)
M.apply_live(lm, TR.offset(li, [150.0, nil, nil], 'world')[:moves], li, lo)
ok('kéo trực tiếp: chỉ một thao tác được mở, các nhịp không mở / đóng thêm', lm.ops == [[:start, 'VGD Transform · Biến đổi món', false]])
ok('kéo trực tiếp: mỗi nhịp tính từ trạng thái đầu (150, không phải 250)', near(M.items(lm)[0][:origin], [150.0, 0.0, 0.0]))
ok('kéo trực tiếp: mỗi nhịp ghi biến đổi một lần', lm.selection.first.sets == 2)
M.restore_entities(lo)
ok('kéo về 0: món trở lại vị trí đầu, không mở thao tác mới', near(M.items(lm)[0][:origin], [0.0, 0.0, 0.0]) && lm.ops.size == 1)
M.finish_live(lm, true)
ok('thả nút có thay đổi: đóng thao tác một lần (một bước Ctrl+Z)', lm.ops.last == [:commit] && lm.ops.size == 2)
am = Sketchup::Model.new([Sketchup::Group.new('Live', [0.0, 0.0, 0.0])])
M.begin_live(am)
M.finish_live(am, false)
ok('thả nút khi không còn thay đổi: hủy thao tác, không để lại bước Ctrl+Z trống', am.ops.last == [:abort])
bad = Sketchup::Model.new([Sketchup::Group.new('Khóa', [0.0, 0.0, 0.0], locked: true)])
bi = M.items(bad)
M.begin_live(bad)
ok('kéo trực tiếp món bị khóa giữa chừng: nhịp cuối (check: true) báo lỗi, thao tác bị hủy', error_of { M.apply_live(bad, TR.offset(bi.map { |i| i.merge(locked: false) }, [5.0, nil, nil], 'world')[:moves], bi, {}, check: true) }.to_s.include?('đang bị khóa'))

# ----- Mỗi nhịp kéo gọi ít API SketchUp: đọc ngữ cảnh một lần cho cả đợt, kiểm tra lại ma trận chỉ ở lần cuối -----
class CountingModel < Sketchup::Model
  attr_accessor :path_reads
  def active_path; @path_reads = (@path_reads || 0) + 1; super; end
end
cm = CountingModel.new(Array.new(5) { |i| Sketchup::Group.new("G#{i}", [i.to_f, 0.0, 0.0]) })
ci = M.items(cm)
co = ci.to_h { |i| [i[:entity], i[:entity].transformation] }
M.begin_live(cm)
cm.path_reads = 0
M.apply_live(cm, TR.offset(ci, [10.0, nil, nil], 'world')[:moves], ci, co)
ok('mỗi nhịp kéo đọc active_path không quá 2 lần dù có 5 món (không đọc lại cho từng món)', cm.path_reads <= 2)
ok('nhịp kéo vẫn đặt đúng vị trí cho cả 5 món', ci.all? { |i| near(M.items(cm).find { |x| x[:entity] == i[:entity] }[:origin], [i[:origin][0] + 10.0, 0.0, 0.0]) })
rm_live = Sketchup::Model.new([NoRotateGroup.new('Không xoay', [100.0 / MM, 0.0, 0.0])])
rli = M.items(rm_live)
rlo = rli.to_h { |i| [i[:entity], i[:entity].transformation] }
M.begin_live(rm_live)
rot = RS.rotate(rli, [nil, nil, 45.0], 'item', 'world')[:moves]
ok('nhịp kéo thường không kiểm lại ma trận (đỡ tốn thời gian)', error_of { M.apply_live(rm_live, rot, rli, rlo) }.nil?)
ok('nhịp cuối (check: true) kiểm lại ma trận và bắt được lỗi', error_of { M.apply_live(rm_live, rot, rli, rlo, check: true) }.to_s.include?('không khớp'))

# ----- Góc hiện tại của món (cho ô Xoay tuyệt đối) đọc từ ma trận thế giới -----
em = Sketchup::Model.new([rotated_z(Sketchup::Group.new('Quay 90', [0.0, 0.0, 0.0]), 90.0), Sketchup::Group.new('Thẳng', [1.0, 0.0, 0.0])])
ei = M.items(em)
ok('đọc món: món xoay 90° quanh Z có góc (0, 0, 90), món chưa xoay có góc (0, 0, 0)', near(ei[0][:euler], [0.0, 0.0, 90.0], 1e-6) && near(ei[1][:euler], [0.0, 0.0, 0.0], 1e-6))

am_rot = Sketchup::Model.new([rotated_z(Sketchup::Group.new('Quay 90', [3.0, 4.0, 0.0]), 90.0)])
ai_rot = M.items(am_rot)
M.apply(am_rot, RS.absolute_rotate(ai_rot, [0.0, 0.0, 0.0], 'item')[:moves], ai_rot)
after_rot = M.items(am_rot)[0]
ok('xoay tuyệt đối 0 trong SketchUp giả lập: món về hướng gốc (góc 0, 0, 0), điểm gốc đứng yên, qua được kiểm tra ma trận', near(after_rot[:euler], [0.0, 0.0, 0.0], 1e-6) && near(after_rot[:origin], ai_rot[0][:origin], 0.01))

# ----- Panel: luồng kéo trực tiếp (gộp giá trị theo nhịp hẹn giờ, một thao tác mở suốt, thả / đóng cửa sổ) với HtmlDialog và hẹn giờ giả lập -----
require 'json'
module Sketchup
  class SelectionObserver; end
  class ModelObserver; end
  def self.active_model; $panel_model; end
end
module UI
  class HtmlDialog
    STYLE_DIALOG = 1
    attr_reader :callbacks, :scripts
    def initialize(*); @callbacks = {}; @scripts = []; end
    def set_file(*); end
    def add_action_callback(name, &block); @callbacks[name] = block; end
    def set_on_closed(&block); @on_closed = block; end
    def execute_script(script); @scripts << script; end
    def visible?; false; end
    def show; end
    def bring_to_front; end
    def close; @on_closed&.call; end
  end
  @timers = {}
  @next_timer = 0
  def self.start_timer(_seconds, _repeat = false, &block); @next_timer += 1; @timers[@next_timer] = block; @next_timer; end
  def self.stop_timer(id); @timers.delete(id); end
  def self.timers; @timers; end
  def self.run_timers; list = @timers.values; @timers.clear; list.each(&:call); end
end
module VGD::Transform
  ROOT = ::ROOT unless const_defined?(:ROOT, false)
  def self.log(*); end
end
require File.join(ROOT, 'core/live_queue')
require File.join(ROOT, 'ui/panel')

def panel_model(shift)
  model = Sketchup::Model.new([Sketchup::Group.new('P', [shift, 0.0, 0.0])])
  def model.add_observer(*); end
  def model.remove_observer(*); end
  def model.active_view; @view ||= Struct.new(:count) { def invalidate; self.count = (count || 0) + 1; end }.new(0); end
  model.selection.define_singleton_method(:add_observer) { |*| }
  model.selection.define_singleton_method(:remove_observer) { |*| }
  model
end
def live_payload(x); {'tool' => 'move_off', 'values' => {'x' => x.to_s}, 'pivot' => 'item', 'coord' => 'world'}; end
def panel_call(dialog, name, payload = nil); dialog.callbacks[name].call(nil, payload && JSON.generate(payload)); end

def panel_with_clock(model)
  $panel_model = model
  $clock = 10.0
  panel = VGD::Transform::Panel.new
  panel.define_singleton_method(:live_now) { $clock }
  [panel, panel.instance_variable_get(:@dialog)]
end

panel, dlg = panel_with_clock(panel_model(0.0))
panel_call(dlg, 'live_start')
ok('panel: bắt đầu kéo mở đúng một thao tác', $panel_model.ops == [[:start, 'VGD Transform · Biến đổi món', false]] && !panel.busy_reason.nil?)
panel_call(dlg, 'live', live_payload(100))
ok('panel: giá trị đầu tiên áp dụng NGAY (không chờ nhịp hẹn giờ)', near(M.items($panel_model)[0][:origin], [100.0, 0.0, 0.0]) && UI.timers.empty?)
$clock += 0.002
panel_call(dlg, 'live', live_payload(110))
$clock += 0.002
panel_call(dlg, 'live', live_payload(120))
ok('panel: giá trị đến dồn trong một nhịp chỉ hẹn giờ một lần và chưa đụng model', UI.timers.size == 1 && near(M.items($panel_model)[0][:origin], [100.0, 0.0, 0.0]))
$clock += 0.02
UI.run_timers
ok('panel: đến nhịp chỉ áp dụng giá trị mới nhất (120), không mở thao tác thêm', near(M.items($panel_model)[0][:origin], [120.0, 0.0, 0.0]) && $panel_model.ops.size == 1)
$clock += 0.5
panel_call(dlg, 'live', live_payload(200))
panel_call(dlg, 'live_end')
ok('panel: thả nút áp dụng giá trị cuối (200) rồi đóng một lần, hẹn giờ còn lại bị hủy', near(M.items($panel_model)[0][:origin], [200.0, 0.0, 0.0]) && $panel_model.ops.last == [:commit] && $panel_model.ops.size == 2 && UI.timers.empty? && panel.busy_reason.nil?)
ok('panel: kéo xong báo số nhịp và thời gian trung bình để biết chỗ nào chậm', dlg.scripts.any? { |script| script.include?('nhịp') && script.include?('ms') })

panel, dlg = panel_with_clock(panel_model(0.0))
panel_call(dlg, 'live_start')
panel_call(dlg, 'live', live_payload(0))
panel_call(dlg, 'live_end')
ok('panel: kéo về 0 rồi thả: hủy thao tác, không để lại bước Ctrl+Z trống', $panel_model.ops.last == [:abort] && near(M.items($panel_model)[0][:origin], [0.0, 0.0, 0.0]))

panel, dlg = panel_with_clock(panel_model(0.0))
panel_call(dlg, 'live_start')
panel_call(dlg, 'live', live_payload(50))
dlg.close
ok('panel: đóng cửa sổ giữa lúc kéo: hủy thao tác đang mở', $panel_model.ops.last == [:abort] && panel.busy_reason.nil?)

# Ctrl+Z / Ctrl+Y trong cửa sổ: giao cho SketchUp (phím tắt không tới SketchUp khi tiêu điểm đang ở cửa sổ này)
$undo_calls = []
module Sketchup
  def self.undo; $undo_calls << :undo; end
  def self.send_action(action); $undo_calls << action; true; end
end
panel, dlg = panel_with_clock(panel_model(0.0))
panel_call(dlg, 'undo')
panel_call(dlg, 'redo')
ok('panel: lệnh undo / redo từ cửa sổ gọi Hoàn tác / Làm lại của SketchUp', $undo_calls == [:undo, 'editRedo:'])
$undo_calls.clear
panel_call(dlg, 'live_start')
panel_call(dlg, 'undo')
ok('panel: đang kéo thì bỏ qua Ctrl+Z (thao tác còn mở)', $undo_calls.empty?)
panel_call(dlg, 'live_end')

puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
