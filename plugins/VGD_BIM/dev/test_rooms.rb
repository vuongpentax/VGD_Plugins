# Test Phòng (core/rooms.rb): danh sách phòng lưu trong model (kiểm tra dữ liệu sai, viền đa giác không tự cắt, id ổn định), số đo (diện tích,
# chu vi, thể tích, tường, trần), món thuộc phòng theo vị trí, nhãn phòng ở món. Chạy: ruby dev/test_rooms.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
require File.join(ROOT, 'core/levels')
require File.join(ROOT, 'core/rooms')
RM = VGD::BIM::Rooms

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
  def get_attribute(dict, key, default = nil); @attrs.dig(dict, key).nil? ? default : @attrs[dict][key]; end
  def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; end
  def delete_attribute(dict, key = nil); key ? @attrs[dict]&.delete(key) : @attrs.delete(dict); end
end

SQUARE = [[0, 0], [4000, 0], [4000, 3000], [0, 3000]].freeze # 4 x 3 m = 12 m2
room = {'name' => 'Phòng khách', 'number' => 'P01', 'boundary' => SQUARE, 'height' => 3000, 'elevation' => 0}

# ---- Hình học ----
ok('diện tích đa giác (mm2): 4 x 3 m = 12.000.000, không phụ thuộc chiều đi', RM.polygon_area(SQUARE) == 12_000_000 && RM.polygon_area(SQUARE.reverse) == 12_000_000)
ok('diện tích đa giác lõm (chữ L): 4x3 trừ 2x1', RM.polygon_area([[0, 0], [4000, 0], [4000, 1000], [2000, 1000], [2000, 3000], [0, 3000]]) == 8_000_000)
ok('chu vi: 14 m', RM.polygon_perimeter(SQUARE) == 14_000.0)
ok('đa giác tự cắt (hình nơ) bị phát hiện, hình thường thì không', RM.self_intersecting?([[0, 0], [4000, 3000], [4000, 0], [0, 3000]]) && !RM.self_intersecting?(SQUARE) && !RM.self_intersecting?([[0, 0], [4000, 0], [4000, 1000], [2000, 1000], [2000, 3000], [0, 3000]]))
ok('điểm trong đa giác: trong, ngoài, đa giác lõm', RM.contains?(SQUARE, 2000, 1500) && !RM.contains?(SQUARE, 5000, 1500) && !RM.contains?(SQUARE, -1, 1) && !RM.contains?([[0, 0], [4000, 0], [4000, 1000], [2000, 1000], [2000, 3000], [0, 3000]], 3000, 2000))

# ---- Dữ liệu sai ----
ok('không phải mảng / mục sai kiểu: từ chối', error_of { RM.sanitize!('x') }.to_s.include?('không hợp lệ') && error_of { RM.sanitize!([1]) }.to_s.include?('không hợp lệ'))
ok('quá nhiều phòng: từ chối', error_of { RM.sanitize!(Array.new(RM::MAX_ROOMS + 1) { |i| room.merge('name' => "P#{i}") }) }.to_s.include?('tối đa'))
ok('tên phòng rỗng / quá dài / điều khiển / sai kiểu: từ chối', ['', ' ', 'a' * (RM::MAX_NAME + 1), "P\u0001", 3].all? { |n| error_of { RM.sanitize!([room.merge('name' => n)]) }.to_s.include?('tên phòng') })
ok('mã phòng quá dài hoặc có ký tự điều khiển: từ chối', error_of { RM.sanitize!([room.merge('number' => 'a' * (RM::MAX_TEXT + 1))]) }.to_s.include?('mã phòng') && error_of { RM.sanitize!([room.merge('number' => "a\u0001")]) }.to_s.include?('mã phòng'))
ok('mã phòng trùng (không phân biệt hoa thường): từ chối; mã rỗng không tính là trùng', error_of { RM.sanitize!([room, room.merge('name' => 'B', 'number' => 'p01')]) }.to_s.include?('trùng') && RM.sanitize!([room.merge('number' => ''), room.merge('name' => 'B', 'number' => '')]).size == 2)
ok('tên phòng trùng: từ chối', error_of { RM.sanitize!([room, room.merge('number' => 'P02')]) }.to_s.include?('trùng'))
ok('viền ít hơn 3 điểm / quá nhiều điểm / không phải số: từ chối', [[[0, 0], [1, 1]], Array.new(RM::MAX_POINTS + 1) { |i| [i, i * i] }, [[0, 0], [1, 'a'], [2, 3]], [[0, 0], [1], [2, 3]], 'x', [[0, 0], [Float::NAN, 1], [2, 3]]].all? { |b| error_of { RM.sanitize!([room.merge('boundary' => b)]) }.to_s.include?('viền') })
ok('viền tự cắt hoặc diện tích gần 0: từ chối', error_of { RM.sanitize!([room.merge('boundary' => [[0, 0], [4000, 3000], [4000, 0], [0, 3000]])]) }.to_s.include?('viền') && error_of { RM.sanitize!([room.merge('boundary' => [[0, 0], [1000, 0], [2000, 0]])]) }.to_s.include?('viền'))
ok('chiều cao sai (0, âm, quá lớn, chữ): từ chối', [0, -1, 100_001, '3000', nil].all? { |v| error_of { RM.sanitize!([room.merge('height' => v)]) }.to_s.include?('chiều cao') })
ok('cao độ sàn sai: từ chối', ['0', nil, Float::INFINITY, 600_000].all? { |v| error_of { RM.sanitize!([room.merge('elevation' => v)]) }.to_s.include?('cao độ') })
ok('hoàn thiện quá dài / điều khiển: từ chối', error_of { RM.sanitize!([room.merge('finish_floor' => 'a' * (RM::MAX_TEXT + 1))]) }.to_s.include?('hoàn thiện') && error_of { RM.sanitize!([room.merge('finish_wall' => "a\u0001")]) }.to_s.include?('hoàn thiện'))
ok('mã tầng sai dạng: từ chối', error_of { RM.sanitize!([room.merge('level' => 'x y')]) }.to_s.include?('tầng'))
ok('id phòng lạ: từ chối', error_of { RM.sanitize!([room.merge('id' => 'zz')]) }.to_s.include?('không hợp lệ'))

# ---- Chuẩn hóa ----
clean = RM.sanitize!([room, room.merge('name' => 'Bếp', 'number' => 'P02', 'level' => 'lv_aaaaaaaa', 'finish_floor' => ' Gạch 600x600 ')])
ok('chuẩn hóa: có id rm_xxxxxxxx khác nhau, giữ thứ tự nhập, số làm tròn 1 chữ số lẻ, chữ cắt khoảng trắng', clean.map { |r| r['id'] }.uniq.size == 2 && clean.all? { |r| r['id'].match?(/\Arm_[0-9a-f]{8}\z/) } && clean.map { |r| r['name'] } == ['Phòng khách', 'Bếp'] && clean[1]['finish_floor'] == 'Gạch 600x600' && clean[1]['level'] == 'lv_aaaaaaaa' && clean[0]['level'] == '' && RM.sanitize!([room.merge('boundary' => [[0.04, 0], [4000.06, 0], [4000, 3000.123]])]).first['boundary'].flatten.all? { |v| (v * 10).round == v * 10 })
ok('chuẩn hóa lại giữ nguyên id', RM.sanitize!(clean).map { |r| r['id'] } == clean.map { |r| r['id'] })
ok('khóa thừa bị bỏ', !RM.sanitize!([room.merge('x' => 1)]).first.key?('x'))

# ---- Lưu trong model ----
m = FakeModel.new
ok('model chưa có phòng: rỗng, không lỗi', RM.read(m) == [] && RM.read(Object.new) == [] && RM.write(Object.new, clean) == false)
RM.write(m, [room])
saved = RM.read(m)
ok('ghi / đọc phòng trong thao tác trong suốt', saved.size == 1 && saved[0]['name'] == 'Phòng khách' && m.ops == [[:start, 'VGD_BIM · Phòng', true], [:commit]])
m.ops.clear; RM.write(m, saved)
ok('ghi lại y hệt: không đụng model', m.ops.empty?)
m.set_attribute('VGD_BIM_MODEL', 'rooms', 'hỏng')
ok('dữ liệu lưu hỏng: coi như chưa có phòng', RM.read(m) == [])
bad = FakeModel.new
bad.define_singleton_method(:set_attribute) { |*_| raise 'ghi hỏng' }
ok('ghi lỗi: hủy thao tác và báo lỗi', error_of { RM.write(bad, [room]) } == 'ghi hỏng' && bad.ops.last == [:abort])

# ---- Số đo ----
metrics = RM.metrics(saved[0])
ok('số đo: diện tích sàn 12 m2, chu vi 14 m, thể tích 36 m3, tường (chu vi x cao) 42 m2, trần 12 m2', metrics == {area: 12.0, perimeter: 14.0, volume: 36.0, wall_area: 42.0, ceiling_area: 12.0})
ok('số đo làm tròn 3 chữ số (tam giác 3,333 m: 5,554 m2)', RM.metrics(RM.sanitize!([room.merge('boundary' => [[0, 0], [3333, 0], [3333, 3333]])]).first)[:area] == 5.554)

# ---- Món thuộc phòng ----
other = RM.sanitize!([room, room.merge('name' => 'Bếp', 'number' => 'P02', 'boundary' => [[4000, 0], [7000, 0], [7000, 3000], [4000, 3000]])])
items = [{index: 0, x: 1000, y: 1000, z: 0, locked: false}, {index: 1, x: 5000, y: 1000, z: 100, locked: false}, {index: 2, x: 1000, y: 1000, z: 0, locked: true}, {index: 3, x: 20_000, y: 0, z: 0, locked: false}, {index: 4, x: 1000, y: 1000, z: 5000, locked: false}, {index: 5, x: nil, y: 1, z: 0, locked: false}]
plan = RM.plan_auto(items, other)
ok('món thuộc phòng theo vị trí: trong viền và trong khoảng cao của phòng; ngoài phòng, quá cao, không đo được thì không gán; món khóa bỏ qua', plan == {assign: {0 => other[0]['id'], 1 => other[1]['id']}, locked: [2], none: [3, 4, 5]})
ok('không có phòng: mọi món không gán được', RM.plan_auto(items, [])[:assign].empty?)
ok('dung sai chiều cao: món đặt hơi thấp hơn sàn phòng (-40 mm) vẫn trong phòng', RM.plan_auto([{index: 0, x: 1000, y: 1000, z: -40, locked: false}], other)[:assign].keys == [0])

# ---- Nhãn phòng ở món ----
e = FakeEntity.new
ok('chưa gán: rỗng', RM.entity_room(e) == '' && RM.entity_room(Object.new) == '')
RM.assign(e, other[0]['id'])
ok('gán phòng: lưu ở dictionary VGD_BIM_LOC khóa room, giữ nguyên nhãn tầng', (e.set_attribute('VGD_BIM_LOC', 'level', 'lv_aaaaaaaa'); RM.assign(e, other[0]['id']); RM.entity_room(e) == other[0]['id'] && e.get_attribute('VGD_BIM_LOC', 'level') == 'lv_aaaaaaaa'))
RM.assign(e, '')
ok('bỏ phòng bằng giá trị rỗng, vẫn giữ nhãn tầng', RM.entity_room(e) == '' && e.get_attribute('VGD_BIM_LOC', 'level') == 'lv_aaaaaaaa')
ok('món khóa / id sai: từ chối', error_of { RM.assign(FakeEntity.new(true), other[0]['id']) }.to_s.include?('khóa') && error_of { RM.assign(FakeEntity.new, 'x y') }.to_s.include?('không hợp lệ'))

# ---- Viền từ các điểm đo được (mặt sàn) ----
pts = [[0, 0, 100], [4000, 0, 100], [4000, 3000, 100], [0, 3000, 100]]
ok('viền từ mặt phẳng ngang: bỏ Z, lấy cao độ sàn', RM.boundary_from_points(pts) == {boundary: SQUARE.map { |x, y| [x.to_f, y.to_f] }, elevation: 100.0})
ok('mặt không nằm ngang (lệch Z): từ chối', error_of { RM.boundary_from_points([[0, 0, 0], [4000, 0, 0], [4000, 3000, 500]]) }.to_s.include?('nằm ngang'))
ok('bỏ điểm trùng liên tiếp và điểm thẳng hàng thừa', RM.boundary_from_points([[0, 0, 0], [2000, 0, 0], [4000, 0, 0], [4000, 3000, 0], [0, 3000, 0], [0, 3000, 0]])[:boundary].size == 4)

puts($fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
