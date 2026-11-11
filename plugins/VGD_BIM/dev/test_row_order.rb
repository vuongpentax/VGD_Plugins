# Test thứ tự dòng do người dùng kéo tay (core/row_order.rb): dữ liệu sai bị từ chối, gộp theo chỗ, lưu / đọc trong dictionary của model,
# món mới và bảng của lần chọn khác không bị đụng. SketchUp giả lập đơn giản. Chạy: ruby dev/test_row_order.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
require File.join(ROOT, 'core/row_order')
R = VGD::BIM::RowOrder

class FakeModel
  attr_reader :attrs, :ops
  def initialize; @attrs = {}; @ops = []; end
  def get_attribute(dict, key, default = nil); @attrs.dig(dict, key) || default; end
  def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; end
  def start_operation(name, disable_ui = false, next_transparent = false, transparent = false); @ops << [:start, name, transparent]; true; end
  def commit_operation; @ops << [:commit]; true; end
  def abort_operation; @ops << [:abort]; true; end
end

# ---- Dữ liệu sai (viết trước) ----
ok('không phải mảng: bị từ chối', error_of { R.sanitize!('abc') }.to_s.include?('không hợp lệ'))
ok('mã không phải số nguyên: bị từ chối', error_of { R.sanitize!([1, 'a']) }.to_s.include?('mã món'))
ok('mã số thực: bị từ chối', error_of { R.sanitize!([1, 2.5]) }.to_s.include?('mã món'))
ok('mã âm hoặc 0: bị từ chối', error_of { R.sanitize!([0]) } && error_of { R.sanitize!([-3]) })
ok('mã nil: bị từ chối', error_of { R.sanitize!([nil]) }.to_s.include?('mã món'))
ok('quá dài: bị từ chối', error_of { R.sanitize!((1..R::MAX_ENTRIES + 1).to_a) }.to_s.include?('quá dài'))
ok('đúng giới hạn: nhận', R.sanitize!((1..R::MAX_ENTRIES).to_a).size == R::MAX_ENTRIES)
ok('mã trùng: giữ lần đầu', R.sanitize!([3, 1, 3, 2, 1]) == [3, 1, 2])

# ---- Gộp thứ tự ----
ok('chưa lưu gì: lấy đúng thứ tự mới', R.merge([], [5, 3, 9]) == [5, 3, 9])
ok('bảng đủ món: thay hẳn bằng thứ tự mới', R.merge([1, 2, 3], [3, 1, 2]) == [3, 1, 2])
ok('món của bảng khác giữ nguyên chỗ, món của bảng này chiếm lại chỗ theo thứ tự mới', R.merge([1, 100, 2, 200, 3], [3, 2, 1]) == [3, 100, 2, 200, 1])
ok('món mới chưa từng lưu: thêm vào cuối rồi xếp chỗ', R.merge([1, 2], [2, 7, 1]) == [2, 7, 1] && R.merge([100, 1], [7, 1]) == [100, 7, 1])
ok('gộp hai lần liên tiếp cho kết quả ổn định', (a = R.merge([], [4, 5, 6]); R.merge(a, [6, 4, 5]) == [6, 4, 5]))
ok('thứ tự mới không đổi: danh sách giữ nguyên', R.merge([1, 100, 2], [1, 2]) == [1, 100, 2])
ok('merge không sửa danh sách đã lưu', (stored = [1, 2, 3]; R.merge(stored, [3, 2, 1]); stored == [1, 2, 3]))
ok('merge: thứ tự mới sai kiểu bị từ chối', error_of { R.merge([1], [1, 'x']) }.to_s.include?('mã món'))
ok('merge: vượt giới hạn sau khi gộp bị từ chối', error_of { R.merge((1..R::MAX_ENTRIES).to_a, [R::MAX_ENTRIES + 1]) }.to_s.include?('quá dài'))
ok('without: bỏ đúng các món, giữ thứ tự còn lại', R.without([1, 100, 2, 200, 3], [2, 3, 999]) == [1, 100, 200])
ok('without: mã sai bị từ chối', error_of { R.without([1], ['a']) }.to_s.include?('mã món'))

# ---- Lưu / đọc trong model ----
model = FakeModel.new
ok('model chưa có dữ liệu: danh sách rỗng', R.read(model) == [])
ok('model không có API thuộc tính: danh sách rỗng, không lỗi', R.read(Object.new) == [] && R.write(Object.new, [1]) == false)
ok('apply order: ghi vào dictionary VGD_BIM_MODEL dạng JSON', (R.apply(model, {'order' => [3, 1, 2]}); JSON.parse(model.attrs['VGD_BIM_MODEL']['row_order']) == [3, 1, 2]))
ok('đọc lại đúng thứ tự', R.read(model) == [3, 1, 2])
ok('ghi trong thao tác trong suốt, có commit (không thêm bước hoàn tác)', model.ops == [[:start, 'VGD_BIM · Thứ tự dòng', true], [:commit]])
model.ops.clear
R.apply(model, {'order' => [3, 1, 2]})
ok('thứ tự không đổi: không ghi lại model', model.ops.empty?)
R.apply(model, {'order' => [2, 3]})
ok('bảng của lần chọn khác: món không có trong bảng giữ chỗ', R.read(model) == [2, 1, 3])
R.apply(model, {'reset' => [2, 3]})
ok('reset: bỏ các món của bảng, món khác còn', R.read(model) == [1])
R.apply(model, {'reset' => []})
ok('reset danh sách rỗng: không đổi', R.read(model) == [1])
ok('payload không phải hash bị từ chối', error_of { R.apply(model, [1, 2]) }.to_s.include?('không hợp lệ'))
ok('payload thiếu order / reset bị từ chối', error_of { R.apply(model, {'x' => 1}) }.to_s.include?('không hợp lệ'))
ok('payload sai kiểu không làm đổi dữ liệu đã lưu', (error_of { R.apply(model, {'order' => [1, 'x']}) }; R.read(model) == [1]))
model.set_attribute('VGD_BIM_MODEL', 'row_order', 'không phải json')
ok('dữ liệu lưu bị hỏng: coi như chưa sắp, không lỗi', R.read(model) == [])
model.set_attribute('VGD_BIM_MODEL', 'row_order', '[1,"a"]')
ok('dữ liệu lưu có mã sai: coi như chưa sắp', R.read(model) == [])

# ghi lỗi giữa chừng: hủy thao tác, ném lại lỗi
bad = FakeModel.new
bad.define_singleton_method(:set_attribute) { |*_| raise 'ghi hỏng' }
ok('ghi lỗi: hủy thao tác và báo lỗi', error_of { R.apply(bad, {'order' => [1]}) } == 'ghi hỏng' && bad.ops.last == [:abort])

puts($fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
