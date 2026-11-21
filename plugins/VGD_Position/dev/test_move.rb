# Test phần gọi SketchUp (core/move.rb) với SketchUp giả lập: đọc vị trí món, dời / xoay / scale trong group cha,
# món khóa, một thao tác hoàn tác, hủy khi vị trí sau biến đổi sai. Biến đổi giả lập bằng ma trận 4×4 (độc lập với công thức trong code).
# Chạy: ruby dev/test_move.rb (từ plugins/VGD_Position)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_position', __dir__)

module Geom
  class Point3d
    attr_reader :x, :y, :z
    def initialize(x = 0.0, y = 0.0, z = 0.0); @x = x.to_f; @y = y.to_f; @z = z.to_f; end
  end
  class Vector3d
    attr_reader :x, :y, :z
    def initialize(x = 0.0, y = 0.0, z = 0.0); @x = x.to_f; @y = y.to_f; @z = z.to_f; end
  end
  # Biến đổi 4×4 (theo dòng), đủ cho tịnh tiến, xoay quanh trục đi qua điểm, scale theo trục.
  class Transformation
    IDENTITY = [[1.0, 0.0, 0.0, 0.0], [0.0, 1.0, 0.0, 0.0], [0.0, 0.0, 1.0, 0.0], [0.0, 0.0, 0.0, 1.0]].freeze
    attr_reader :m
    def initialize(m = IDENTITY); @m = m; end
    def self.translation(vector)
      new([[1.0, 0.0, 0.0, vector.x], [0.0, 1.0, 0.0, vector.y], [0.0, 0.0, 1.0, vector.z], [0.0, 0.0, 0.0, 1.0]])
    end
    def self.scaling(x, y, z); new([[x, 0.0, 0.0, 0.0], [0.0, y, 0.0, 0.0], [0.0, 0.0, z, 0.0], [0.0, 0.0, 0.0, 1.0]]); end
    # Xoay quanh trục đi qua point (ma trận Rodrigues, chiều dương theo quy tắc bàn tay phải)
    def self.rotation(point, axis, angle)
      len = Math.sqrt(axis.x**2 + axis.y**2 + axis.z**2)
      kx, ky, kz = axis.x / len, axis.y / len, axis.z / len
      c = Math.cos(angle); s = Math.sin(angle); t = 1 - c
      r = [
        [c + kx * kx * t, kx * ky * t - kz * s, kx * kz * t + ky * s, 0.0],
        [ky * kx * t + kz * s, c + ky * ky * t, ky * kz * t - kx * s, 0.0],
        [kz * kx * t - ky * s, kz * ky * t + kx * s, c + kz * kz * t, 0.0],
        [0.0, 0.0, 0.0, 1.0],
      ]
      translation(Vector3d.new(point.x, point.y, point.z)) * new(r) * translation(Vector3d.new(-point.x, -point.y, -point.z))
    end
    def *(other)
      case other
      when Transformation
        Transformation.new(Array.new(4) { |i| Array.new(4) { |j| (0..3).sum { |k| @m[i][k] * other.m[k][j] } } })
      when Point3d
        v = [other.x, other.y, other.z, 1.0]
        Point3d.new(*(0..2).map { |i| (0..3).sum { |k| @m[i][k] * v[k] } })
      when Vector3d
        v = [other.x, other.y, other.z, 0.0]
        Vector3d.new(*(0..2).map { |i| (0..3).sum { |k| @m[i][k] * v[k] } })
      else raise ArgumentError, 'không hỗ trợ'
      end
    end
    def origin; Point3d.new(@m[0][3], @m[1][3], @m[2][3]); end
    # Nghịch đảo bằng khử Gauss-Jordan (đủ cho ma trận biến đổi)
    def inverse
      a = @m.map(&:dup)
      inv = IDENTITY.map(&:dup)
      4.times do |col|
        pivot = (col...4).max_by { |r| a[r][col].abs }
        a[col], a[pivot] = a[pivot], a[col]
        inv[col], inv[pivot] = inv[pivot], inv[col]
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

module Sketchup
  class Group
    attr_accessor :transformation, :name, :locked, :valid
    # shift: tịnh tiến của gốc món (inch, như SketchUp)
    def initialize(name, shift, locked: false)
      @name = name; @transformation = Geom::Transformation.translation(Geom::Vector3d.new(*shift)); @locked = locked; @valid = true
      @definition = Struct.new(:name).new("def #{name}")
    end
    def definition; @definition; end
    def locked?; @locked; end
    def valid?; @valid; end
  end
  class ComponentInstance < Group; end
  class Model
    attr_accessor :active_path, :selection, :ops, :options
    def initialize(entities, active_path = [], length_unit: 2)
      @active_path = active_path; @selection = Struct.new(:items) { def to_a; items; end }.new(entities); @ops = []
      @options = {'UnitsOptions' => {'LengthUnit' => length_unit}}
    end
    def start_operation(name, _disable = false); @ops << [:start, name]; true; end
    def commit_operation; @ops << [:commit]; true; end
    def abort_operation; @ops << [:abort]; true; end
  end
end

require File.join(ROOT, 'core/move')
M = VGD::Position::Move
P = VGD::Position
T = P::Transform
MM = P::MM_PER_INCH
def near(a, b, tol = 0.01); a.zip(b).all? { |x, y| (x - y).abs < tol }; end

# Món ở gốc model: tâm (1000, 2000, 300) mm
root_item = Sketchup::Group.new('Tủ A', [1000.0 / MM, 2000.0 / MM, 300.0 / MM])
model = Sketchup::Model.new([root_item])
items = M.items(model)
ok('đọc vị trí món ở gốc model: đúng mm', items.size == 1 && near(items[0][:origin], [1000.0, 2000.0, 300.0], 1e-6))
ok('tên món đọc được, không khóa', items[0][:name] == 'Tủ A' && items[0][:locked] == false)
ok('đơn vị của file đọc được từ model (2 = mm, 4 = m)', M.length_unit(model) == 'mm' && M.length_unit(Sketchup::Model.new([], [], length_unit: 4)) == 'm')

# Dời món ở gốc: +500 mm trên X
M.apply(model, [{index: 0, steps: [{kind: 'translate', delta: [500.0, 0.0, 0.0]}]}], items)
ok('dời ở gốc: vị trí sau dời đúng (1500, 2000, 300) mm', near(M.items(model)[0][:origin], [1500.0, 2000.0, 300.0]))
ok('dời trong một thao tác hoàn tác: start rồi commit, không abort', model.ops.map(&:first) == [:start, :commit] && model.ops[0][1] == 'VGD Position · Biến đổi món')

# Dời trong group cha đang mở: cha ở +100 mm X, con ở +50 mm trong cha → thế giới 150 mm. Dời con +40 mm theo Y.
parent = Sketchup::Group.new('Cha', [100.0 / MM, 0.0, 0.0])
child = Sketchup::Group.new('Con', [50.0 / MM, 0.0, 0.0])
ctx_model = Sketchup::Model.new([child], [parent])
ctx_items = M.items(ctx_model)
ok('món trong group cha: vị trí thế giới = 100 + 50 = 150 mm', near(ctx_items[0][:origin], [150.0, 0.0, 0.0]))
M.apply(ctx_model, [{index: 0, steps: [{kind: 'translate', delta: [0.0, 40.0, 0.0]}]}], ctx_items)
ok('dời món trong group cha: thế giới đi đúng 40 mm theo Y, X giữ nguyên 150', near(M.items(ctx_model)[0][:origin], [150.0, 40.0, 0.0]))

# Nhiều món trong một đợt: mọi món cùng độ dời, một thao tác hoàn tác
pair = [Sketchup::Group.new('Tủ A', [0.0, 0.0, 0.0]), Sketchup::Group.new('Tủ B', [500.0 / MM, 0.0, 0.0])]
pm = Sketchup::Model.new(pair)
pi = M.items(pm)
M.apply(pm, [{index: 0, steps: [{kind: 'translate', delta: [100.0, 0.0, 0.0]}]}, {index: 1, steps: [{kind: 'translate', delta: [100.0, 0.0, 0.0]}]}], pi)
before_x = pi.map { |i| i[:origin][0] }
after_x = M.items(pm).map { |i| i[:origin][0] }
ok('nhiều món: mỗi món dời đúng 100 mm theo X trong một thao tác', after_x.zip(before_x).all? { |a, b| (a - b - 100.0).abs < 0.01 } && pm.ops.map(&:first) == [:start, :commit])

# Xoay 90° quanh Z, tâm gốc thế giới: món ở (1000, 0, 0) → (0, 1000, 0) mm
rm = Sketchup::Model.new([Sketchup::Group.new('Xoay', [1000.0 / MM, 0.0, 0.0])])
ri = M.items(rm)
M.apply(rm, T.rotate(ri, [nil, nil, 90.0], 'world')[:moves], ri)
ok('xoay 90° quanh Z, tâm gốc thế giới: vị trí (0, 1000, 0) mm', near(M.items(rm)[0][:origin], [0.0, 1000.0, 0.0]))
ok('xoay: một thao tác hoàn tác, không abort', rm.ops.map(&:first) == [:start, :commit])

# Xoay hai món 180° quanh tâm cả lựa chọn (500, 0, 0): đổi chỗ nhau
sm = Sketchup::Model.new([Sketchup::Group.new('A', [0.0, 0.0, 0.0]), Sketchup::Group.new('B', [1000.0 / MM, 0.0, 0.0])])
si = M.items(sm)
M.apply(sm, T.rotate(si, [nil, nil, 180.0], 'selection')[:moves], si)
ok('xoay 180° quanh tâm cả lựa chọn: hai món đổi chỗ', near(M.items(sm)[0][:origin], [1000.0, 0.0, 0.0]) && near(M.items(sm)[1][:origin], [0.0, 0.0, 0.0]))

# Scale ×2 đều quanh gốc thế giới: (1000, 2000, 300) → (2000, 4000, 600) mm
scm = Sketchup::Model.new([Sketchup::Group.new('Tủ', [1000.0 / MM, 2000.0 / MM, 300.0 / MM])])
sci = M.items(scm)
M.apply(scm, T.scale(sci, [2.0, 2.0, 2.0], 'world')[:moves], sci)
ok('scale ×2 đều: vị trí (2000, 4000, 600) mm', near(M.items(scm)[0][:origin], [2000.0, 4000.0, 600.0]))

# Scale không đều trong group cha: cha ở +100 mm X, con +50 mm trong cha → thế giới (150, 0, 0); scale [2, 1, 0.5] quanh gốc thế giới → (300, 0, 0)
nested_parent = Sketchup::Group.new('Cha2', [100.0 / MM, 0.0, 0.0])
nested_child = Sketchup::Group.new('Con2', [50.0 / MM, 0.0, 0.0])
nm = Sketchup::Model.new([nested_child], [nested_parent])
ni = M.items(nm)
M.apply(nm, T.scale(ni, [2.0, 1.0, 0.5], 'world')[:moves], ni)
ok('scale không đều trong group cha: (150, 0, 0) → (300, 0, 0) mm', near(M.items(nm)[0][:origin], [300.0, 0.0, 0.0]))

# Món bị khóa: không dời, báo lỗi, không đổi model
locked_item = Sketchup::Group.new('Khóa', [0.0, 0.0, 0.0], locked: true)
lm = Sketchup::Model.new([locked_item])
li = M.items(lm)
ok('món bị khóa: báo lỗi khi cố dời, không đổi vị trí', error_of { M.apply(lm, [{index: 0, steps: [{kind: 'translate', delta: [10.0, 0.0, 0.0]}]}], li) }.to_s.include?('đang bị khóa') && near(M.items(lm)[0][:origin], [0.0, 0.0, 0.0]) && lm.ops.map(&:first) == [:start, :abort])

# Group cha bị khóa: mọi món bên trong coi là khóa
locked_parent = Sketchup::Group.new('Cha khóa', [0.0, 0.0, 0.0], locked: true)
kid = Sketchup::Group.new('Con', [0.0, 0.0, 0.0])
ok('món trong group cha bị khóa: tất cả coi là khóa', M.items(Sketchup::Model.new([kid], [locked_parent]))[0][:locked] == true)

# Kiểm tra sau biến đổi: nếu SketchUp không đặt đúng vị trí thì hủy cả thao tác
class StubbornGroup < Sketchup::Group
  def transformation=(_value); end # không cho đổi: mô phỏng lỗi
end
stubborn = StubbornGroup.new('Cứng đầu', [0.0, 0.0, 0.0])
sm2 = Sketchup::Model.new([stubborn])
si2 = M.items(sm2)
ok('sau biến đổi vị trí không khớp: hủy cả thao tác, báo lỗi', error_of { M.apply(sm2, [{index: 0, steps: [{kind: 'translate', delta: [100.0, 0.0, 0.0]}]}], si2) }.to_s.include?('không khớp') && sm2.ops.map(&:first) == [:start, :abort])

puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
