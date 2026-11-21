# Test khóa sheet (core/sheet_lock.rb): chuỗi mã bền của món, chụp lại lựa chọn, tìm lại món trong model (kể cả group dùng chung),
# món đã xóa được đếm là thiếu, dữ liệu khóa sai bị từ chối. SketchUp giả lập đơn giản. Chạy: ruby dev/test_sheet_lock.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
require File.join(ROOT, 'core/sheet_lock')
L = VGD::BIM::SheetLock

# Thực thể giả: có mã bền, biến đổi, và (với group / component) definition.entities như SketchUp.
class FakeDefinition
  attr_reader :entities
  def initialize(entities = []); @entities = entities; end
end
class FakeItem
  attr_reader :persistent_id, :transformation, :definition
  def initialize(pid, children = nil)
    @persistent_id = pid
    @transformation = Object.new
    @definition = FakeDefinition.new(children || []) # group / component thật luôn có definition
  end
  def respond_to?(name, *rest); [:definition, :persistent_id].include?(name) || super; end
end
class FakeModel
  attr_reader :entities
  def initialize(entities); @entities = entities; end
end

# Mô hình: group A (mã 11) chứa cột (21) và ghế (22); group B (mã 13) dùng chung định nghĩa với A nên có cột (21) riêng bản sao;
# một món đứng riêng (mã 12). Mã con 21 xuất hiện trong cả A và B: chỉ tiền tố mã cha mới phân biệt được.
shared = [FakeItem.new('21'), FakeItem.new('22')]
group_a = FakeItem.new('11', shared)
group_b = FakeItem.new('13', shared)
loose = FakeItem.new('12')
MODEL = FakeModel.new([group_a, loose, group_b])

# ---- Chuỗi mã bền ----
ok('chuỗi của món lồng: mã cha rồi mã con', L.chain([group_a, shared[0]]) == %w[11 21])
ok('chuỗi của món đứng riêng: một mã', L.chain([loose]) == %w[12])

# ---- Chụp lựa chọn ----
ok('chụp: món lồng trong group, ngữ cảnh gốc', L.snapshot([shared[0]], [group_a]) == [%w[11 21]])
ok('chụp: lựa chọn rỗng bị từ chối', error_of { L.snapshot([], []) }.to_s.include?('Chưa có đối tượng'))
ok('chụp: món chưa có mã bền (0) bị từ chối', error_of { L.snapshot([FakeItem.new(0)], []) }.to_s.include?('mã bền'))
ok('chụp: quá nhiều món bị từ chối', error_of { L.snapshot(Array.new(L::MAX_ITEMS + 1) { FakeItem.new('5') }, []) }.to_s.include?('Quá nhiều'))

# ---- Tìm lại trong model ----
found = L.resolve(MODEL, [%w[11 21], %w[13 21], %w[12]])
ok('tìm lại: đủ ba món, không thiếu', found[:missing] == 0 && found[:paths].size == 3)
ok('tìm lại: cùng mã con 21 nhưng hai bản sao khác nhau', found[:paths][0].last.equal?(shared[0]) && found[:paths][1].first.equal?(group_b))
ok('tìm lại: đường dẫn bắt đầu từ group cha đúng', found[:paths][0].first.equal?(group_a) && found[:paths][2].first.equal?(loose))
gone = L.resolve(MODEL, [%w[11 21], %w[99 21], %w[12]])
ok('món đã xóa: đếm là thiếu, món còn lại vẫn tìm được', gone[:missing] == 1 && gone[:paths].size == 2)
ok('chuỗi con không tồn tại trong group: thiếu', L.resolve(MODEL, [%w[11 99]])[:missing] == 1)

# ---- Dữ liệu khóa từ giao diện / settings.json ----
ok('dữ liệu đúng: nhận và giữ nguyên', L.clean({'items' => [%w[11 21], %w[12]]}) == {'items' => [%w[11 21], %w[12]]})
ok('không phải Hash: bị từ chối', L.clean([1]).nil?)
ok('thiếu items / items rỗng: bị từ chối', L.clean({}).nil? && L.clean({'items' => []}).nil?)
ok('mã không phải số: bị từ chối', L.clean({'items' => [%w[11 abc]]}).nil?)
ok('mã quá dài: bị từ chối', L.clean({'items' => [['1' * 41]]}).nil?)
ok('chuỗi quá sâu: bị từ chối', L.clean({'items' => [Array.new(L::MAX_DEPTH + 1) { '1' }]}).nil?)
ok('mã là số (không phải chuỗi): bị từ chối', L.clean({'items' => [[11, 21]]}).nil?)
ok('quá nhiều món: bị từ chối', L.clean({'items' => Array.new(L::MAX_ITEMS + 1) { %w[1] }}).nil?)
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "$fails LỖI")
exit($fails.zero? ? 0 : 1)
