# Test phần gọi SketchUp (core/move.rb) với SketchUp giả lập: đọc vị trí món, dời món trong group cha, kiểm tra sau khi dời,
# món khóa, một thao tác hoàn tác, hủy khi vị trí sau dời sai. Chạy: ruby dev/test_move.rb (từ plugins/VGD_Position)
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
  # Biến đổi chỉ gồm tịnh tiến (đủ để kiểm tra độ dời trong group cha; phép xoay do SketchUp xử lý)
  class Transformation
    attr_reader :shift
    def initialize(shift = [0.0, 0.0, 0.0]); @shift = shift.map(&:to_f); end
    def self.translation(vector); new([vector.x, vector.y, vector.z]); end
    def inverse; Transformation.new(@shift.map(&:-@)); end
    def origin; Point3d.new(*@shift); end
    def *(other)
      case other
      when Transformation then Transformation.new(@shift.zip(other.shift).map { |a, b| a + b })
      when Vector3d then other # vector không chịu tịnh tiến
      when Point3d then Point3d.new(other.x + @shift[0], other.y + @shift[1], other.z + @shift[2])
      else raise ArgumentError, 'không hỗ trợ'
      end
    end
  end
end

module Sketchup
  class Group
    attr_accessor :transformation, :name, :locked, :valid
    def initialize(name, shift, locked: false)
      @name = name; @transformation = Geom::Transformation.new(shift); @locked = locked; @valid = true
      @definition = Struct.new(:name).new("def #{name}")
    end
    def definition; @definition; end
    def locked?; @locked; end
    def valid?; @valid; end
  end
  class ComponentInstance < Group; end
  class Model
    attr_accessor :active_path, :selection, :ops
    def initialize(entities, active_path = [])
      @active_path = active_path; @selection = Struct.new(:items) { def to_a; items; end }.new(entities); @ops = []
    end
    def start_operation(name, _disable = false); @ops << [:start, name]; true; end
    def commit_operation; @ops << [:commit]; true; end
    def abort_operation; @ops << [:abort]; true; end
  end
end

require File.join(ROOT, 'core/move')
M = VGD::Position::Move
P = VGD::Position
MM = P::MM_PER_INCH

# Món ở gốc model: tâm (1000, 2000, 300) mm
root_item = Sketchup::Group.new('Tủ A', [1000.0 / MM, 2000.0 / MM, 300.0 / MM])
model = Sketchup::Model.new([root_item])
items = M.items(model)
ok('đọc vị trí món ở gốc model: đúng mm', items.size == 1 && items[0][:origin].zip([1000.0, 2000.0, 300.0]).all? { |a, b| (a - b).abs < 1e-6 })
ok('tên món đọc được, không khóa', items[0][:name] == 'Tủ A' && items[0][:locked] == false)

# Dời món ở gốc: +500 mm trên X
moved = M.apply(model, [{index: 0, delta: [500.0, 0.0, 0.0]}], items)
after = M.items(model)[0][:origin]
ok('dời món ở gốc: vị trí sau dời đúng (1500, 2000, 300)', (after[0] - 1500.0).abs < 0.01 && (after[1] - 2000.0).abs < 0.01 && (after[2] - 300.0).abs < 0.01 && moved == 1)
ok('dời trong một thao tác hoàn tác: start rồi commit, không abort', model.ops.map(&:first) == [:start, :commit] && model.ops[0][1] == 'VGD Position · Dời món')

# Món nằm trong group cha đang mở, group cha ở (100, 0, 0) mm: độ dời tính trong hệ thế giới
parent = Sketchup::Group.new('Cha', [100.0 / MM, 0.0, 0.0])
child = Sketchup::Group.new('Con', [50.0 / MM, 0.0, 0.0])
ctx_model = Sketchup::Model.new([child], [parent])
ctx_items = M.items(ctx_model)
ok('món trong group cha: vị trí thế giới = 100 + 50 = 150 mm', (ctx_items[0][:origin][0] - 150.0).abs < 0.01)
M.apply(ctx_model, [{index: 0, delta: [0.0, 40.0, 0.0]}], ctx_items)
w = M.items(ctx_model)[0][:origin]
ok('dời món trong group cha: thế giới đi đúng 40 mm theo Y, X giữ nguyên 150', (w[0] - 150.0).abs < 0.01 && (w[1] - 40.0).abs < 0.01)

# Món bị khóa: không dời, báo lỗi, không đổi model
locked_item = Sketchup::Group.new('Khóa', [0.0, 0.0, 0.0], locked: true)
lm = Sketchup::Model.new([locked_item])
li = M.items(lm)
ok('món bị khóa: báo lỗi khi cố dời, không đổi vị trí', error_of { M.apply(lm, [{index: 0, delta: [10.0, 0.0, 0.0]}], li) }.to_s.include?('đang bị khóa') && li[0][:origin] == M.items(lm)[0][:origin] && lm.ops.map(&:first) == [:start, :abort])

# Group cha bị khóa: mọi món bên trong coi là khóa
locked_parent = Sketchup::Group.new('Cha khóa', [0.0, 0.0, 0.0], locked: true)
kid = Sketchup::Group.new('Con', [0.0, 0.0, 0.0])
ok('món trong group cha bị khóa: tất cả coi là khóa', M.items(Sketchup::Model.new([kid], [locked_parent]))[0][:locked] == true)

# Kiểm tra sau dời: nếu SketchUp không đặt đúng vị trí thì hủy cả thao tác
class StubbornGroup < Sketchup::Group
  def transformation=(_value); end # không cho đổi: mô phỏng lỗi
end
stubborn = StubbornGroup.new('Cứng đầu', [0.0, 0.0, 0.0])
sm = Sketchup::Model.new([stubborn])
si = M.items(sm)
ok('sau dời vị trí không khớp: hủy cả thao tác, báo lỗi', error_of { M.apply(sm, [{index: 0, delta: [100.0, 0.0, 0.0]}], si) }.to_s.include?('không khớp') && sm.ops.map(&:first) == [:start, :abort])
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
