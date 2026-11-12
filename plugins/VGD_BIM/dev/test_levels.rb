# Test Tầng (core/levels.rb): danh sách tầng lưu trong model (kiểm tra dữ liệu sai, sắp theo cao độ, id ổn định), gán tầng cho món
# (dictionary riêng VGD_BIM_LOC), gợi ý tầng theo cao độ Z. SketchUp giả lập đơn giản. Chạy: ruby dev/test_levels.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
require File.join(ROOT, 'core/levels')
L = VGD::BIM::Levels

class FakeModel
  attr_reader :attrs, :ops
  def initialize; @attrs = {}; @ops = []; end
  def get_attribute(dict, key, default = nil); @attrs.dig(dict, key) || default; end
  def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; end
  def start_operation(name, disable_ui = false, next_transparent = false, transparent = false); @ops << [:start, name, transparent]; true; end
  def commit_operation; @ops << [:commit]; true; end
  def abort_operation; @ops << [:abort]; true; end
end
class FakeEntity
  attr_reader :attrs
  attr_writer :locked
  def initialize(locked = false); @attrs = {}; @locked = locked; end
  def locked?; @locked; end
  def valid?; true; end
  def get_attribute(dict, key, default = nil); @attrs.dig(dict, key).nil? ? default : @attrs[dict][key]; end
  def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; end
  def delete_attribute(dict, key = nil); key ? @attrs[dict]&.delete(key) : @attrs.delete(dict); end
end

good = [{'name' => 'Tầng 2', 'elevation' => 3300, 'height' => 3300}, {'name' => 'Tầng 1', 'elevation' => 0, 'height' => 3300}]
# ---- Dữ liệu sai ----
ok('không phải mảng: từ chối', error_of { L.sanitize!('x') }.to_s.include?('không hợp lệ'))
ok('quá nhiều tầng: từ chối', error_of { L.sanitize!(Array.new(L::MAX_LEVELS + 1) { |i| {'name' => "T#{i}", 'elevation' => i * 3000, 'height' => 3000} }) }.to_s.include?('tối đa'))
ok('mục không phải bảng băm: từ chối', error_of { L.sanitize!([1]) }.to_s.include?('không hợp lệ'))
ok('tên rỗng / quá dài / ký tự điều khiển / không phải chữ: từ chối', ['', '  ', 'a' * (L::MAX_NAME + 1), "T\u0001", 5].all? { |n| error_of { L.sanitize!([good[0].merge('name' => n)]) }.to_s.include?('tên tầng') })
ok('tên tầng trùng (không phân biệt hoa thường): từ chối', error_of { L.sanitize!([good[0], good[1].merge('name' => 'tầng 2')]) }.to_s.include?('trùng'))
ok('cao độ sai (chữ, vô cực, ngoài khoảng): từ chối', ['3', nil, Float::INFINITY, Float::NAN, -100_000, 1_000_000].all? { |v| error_of { L.sanitize!([good[0].merge('elevation' => v)]) }.to_s.include?('cao độ') })
ok('chiều cao sai (0, âm, quá lớn, chữ): từ chối', [0, -5, 200_000, '3000', nil].all? { |v| error_of { L.sanitize!([good[0].merge('height' => v)]) }.to_s.include?('chiều cao') })
ok('id lạ bị từ chối', error_of { L.sanitize!([good[0].merge('id' => 'x y')]) }.to_s.include?('không hợp lệ'))

# ---- Chuẩn hóa ----
clean = L.sanitize!(good)
ok('chuẩn hóa: sắp theo cao độ tăng dần, mỗi tầng có id dạng lv_xxxxxxxx, id khác nhau', clean.map { |l| l['name'] } == ['Tầng 1', 'Tầng 2'] && clean.all? { |l| l['id'].match?(/\Alv_[0-9a-f]{8}\z/) } && clean.map { |l| l['id'] }.uniq.size == 2)
again = L.sanitize!(clean)
ok('chuẩn hóa lại giữ nguyên id', again.map { |l| l['id'] } == clean.map { |l| l['id'] })
ok('số được làm tròn 1 chữ số lẻ, tên cắt khoảng trắng, khóa thừa bị bỏ', L.sanitize!([{'name' => '  T  ', 'elevation' => 12.345, 'height' => 3000.04, 'x' => 1}]).first.values_at('name', 'elevation', 'height') == ['T', 12.3, 3000.0] && !L.sanitize!([{'name' => 'T', 'elevation' => 0, 'height' => 3000, 'x' => 1}]).first.key?('x'))
ok('danh sách rỗng hợp lệ', L.sanitize!([]) == [])

# ---- Lưu trong model ----
m = FakeModel.new
ok('model chưa có tầng: danh sách rỗng', L.read(m) == [] && L.read(Object.new) == [] && L.write(Object.new, clean) == false)
L.write(m, good)
saved = L.read(m)
ok('ghi / đọc tầng: đã sắp xếp, có id, ghi trong thao tác trong suốt có commit', saved.map { |l| l['name'] } == ['Tầng 1', 'Tầng 2'] && m.ops == [[:start, 'VGD_BIM · Tầng', true], [:commit]])
m.ops.clear
L.write(m, saved)
ok('ghi lại y hệt: không đụng model', m.ops.empty?)
m.set_attribute('VGD_BIM_MODEL', 'levels', 'hỏng')
ok('dữ liệu lưu hỏng: coi như chưa có tầng, không lỗi', L.read(m) == [])
bad = FakeModel.new
bad.define_singleton_method(:set_attribute) { |*_| raise 'ghi hỏng' }
ok('ghi lỗi: hủy thao tác và báo lỗi', error_of { L.write(bad, good) } == 'ghi hỏng' && bad.ops.last == [:abort])
ok('ghi dữ liệu sai: từ chối, không mở thao tác', (m2 = FakeModel.new; error_of { L.write(m2, [{'name' => ''}]) }.to_s.include?('tên tầng') && m2.ops.empty?))

# ---- Gợi ý theo cao độ ----
ok('for_z: tầng cao nhất có cao độ <= z + dung sai', L.for_z(saved, 0) == saved[0]['id'] && L.for_z(saved, 3299) == saved[1]['id'] && L.for_z(saved, 3300) == saved[1]['id'] && L.for_z(saved, 2000) == saved[0]['id'] && L.for_z(saved, 9000) == saved[1]['id'])
ok('for_z: dung sai cho món đặt hơi thấp hơn cao độ sàn (3280 vẫn thuộc tầng 2)', L.for_z(saved, 3280) == saved[1]['id'] && L.for_z(saved, 3200) == saved[0]['id'])
ok('for_z: thấp hơn mọi tầng hoặc không có tầng: không gợi ý', L.for_z(saved, -500).nil? && L.for_z([], 100).nil? && L.for_z(saved, nil).nil?)

# ---- Gán cho món ----
e = FakeEntity.new
ok('chưa gán: rỗng', L.entity_level(e) == '' && L.entity_level(Object.new) == '')
L.assign(e, saved[0]['id'])
ok('gán tầng: lưu ở dictionary riêng VGD_BIM_LOC, không đụng VGD_BIM', e.attrs.keys == ['VGD_BIM_LOC'] && L.entity_level(e) == saved[0]['id'])
L.assign(e, '')
ok('gán rỗng: bỏ tầng và dọn dictionary rỗng', L.entity_level(e) == '' && e.attrs['VGD_BIM_LOC'].to_h.empty?)
ok('món khóa: không gán', error_of { L.assign(FakeEntity.new(true), saved[0]['id']) }.to_s.include?('khóa'))
ok('id tầng sai kiểu: từ chối', error_of { L.assign(FakeEntity.new, 'x y') }.to_s.include?('không hợp lệ') && error_of { L.assign(FakeEntity.new, 5) }.to_s.include?('không hợp lệ'))

# ---- Kế hoạch gán tự động ----
items = [{index: 0, z: 0, locked: false}, {index: 1, z: 3350, locked: false}, {index: 2, z: 100, locked: true}, {index: 3, z: -900, locked: false}, {index: 4, z: nil, locked: false}]
plan = L.plan_auto(items, saved)
ok('gán theo cao độ: món gán được theo Z, món khóa bỏ qua, món thấp hơn mọi tầng / không có cao độ vào danh sách không gợi ý được', plan == {assign: {0 => saved[0]['id'], 1 => saved[1]['id']}, locked: [2], none: [3, 4]})
ok('không có tầng nào: mọi món không gợi ý được', L.plan_auto(items, [])[:assign].empty? && L.plan_auto(items, [])[:none] == [0, 1, 3, 4])

puts($fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
