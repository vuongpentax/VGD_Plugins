# Vị trí thế giới của món khi đang mở sửa group (Quét & xuất, Thông tin, Kiểm tra): lấy bằng tích biến đổi của các group trong active_path,
# không dựa vào Model#edit_transform (SketchUp có thể báo sai, xem CLAUDE.md). Chạy: ruby dev/test_open_group.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)

module Sketchup
  class Group; end
  class ComponentInstance; end
  class Face; end
end
module Geom
  # Biến đổi chỉ gồm tịnh tiến (đủ để kiểm tra việc nhân biến đổi của các group cha)
  class Transformation
    attr_reader :shift
    def initialize(shift = [0.0, 0.0, 0.0]); @shift = shift.map(&:to_f); end
    def *(other); Transformation.new(@shift.zip(other.shift).map { |a, b| a + b }); end
    def to_a; [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, *@shift, 1.0]; end
  end
end
module VGD; module BIM; module Data
  def self.supported?(entity); entity.is_a?(Sketchup::Group); end
end; end; end

require File.join(ROOT, 'core/geometry')
require File.join(ROOT, 'core/scanner')

# Nhóm giả: có biến đổi, vật liệu, định nghĩa rỗng (đủ để Scanner duyệt như group thật).
class TestGroup < Sketchup::Group
  attr_reader :transformation
  def initialize(shift = [0, 0, 0]); @transformation = Geom::Transformation.new(shift); end
  def valid?; true; end
  def locked?; false; end
  def material; nil; end
  def entities; Struct.new(:parent).new(Struct.new(:entities).new([])); end
end
# Mô hình giả: đang mở group `outer` (dịch 100 mm theo X), chọn `child` trong đó. edit_transform báo SAI (dịch 128).
class TestModel
  attr_reader :active_path, :selection
  def initialize(path, picked); @active_path = path; @selection = Struct.new(:items) { def to_a; items; end }.new(picked); end
  def edit_transform; Geom::Transformation.new([128.0, 0.0, 0.0]); end
end

outer = TestGroup.new([100, 0, 0])
child = TestGroup.new([5, 0, 0])
model = TestModel.new([outer], [child])

ok('tích biến đổi của đường dẫn: group cha dịch 100 cộng món dịch 5 = 105',
   VGD::BIM::Geometry.path_transform([outer, child]).shift == [105.0, 0.0, 0.0])
ok('đường dẫn rỗng (không mở group): đơn vị',
   VGD::BIM::Geometry.path_transform([]).shift == [0.0, 0.0, 0.0])

records = VGD::BIM::Scanner.scan_selection(model)
ok('quét lựa chọn trong group đang mở: món ở đúng vị trí thế giới (105), không theo edit_transform (133)',
   records.size == 1 && records.first[:transform].shift == [105.0, 0.0, 0.0])
ok('đường dẫn của bản ghi giữ group đang mở', records.first[:path] == [outer, child])

puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "$fails LỖI")
exit($fails.zero? ? 0 : 1)
