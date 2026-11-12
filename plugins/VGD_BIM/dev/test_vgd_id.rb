# Test VGD ID (core/vgd_id.rb): UUID ngẫu nhiên lưu ở dictionary riêng VGD_BIM_ID, kiểm tra dữ liệu, kế hoạch gán, phát hiện và sửa trùng
# (giữ ID cho món có mã bền nhỏ nhất). SketchUp giả lập đơn giản. Chạy: ruby dev/test_vgd_id.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
require File.join(ROOT, 'core/vgd_id')
V = VGD::BIM::VgdId

class FakeEntity
  attr_reader :attrs
  attr_writer :locked
  def initialize(pid = 1, locked: false); @attrs = {}; @pid = pid; @locked = locked; end
  def persistent_id; @pid; end
  def locked?; @locked; end
  def valid?; true; end
  def get_attribute(dict, key, default = nil); @attrs.dig(dict, key).nil? ? default : @attrs[dict][key]; end
  def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; end
end

# ---- ID hợp lệ ----
ok('ID mới là UUID chữ thường, hợp lệ, mỗi lần một giá trị khác', (a = V.generate; b = V.generate; V.valid?(a) && a != b && a.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)))
ok('valid?: từ chối chuỗi rỗng, nil, số, chữ hoa, thiếu gạch, thừa ký tự', [nil, '', 12, 'ABC', V.generate.upcase, V.generate.delete('-'), V.generate + 'x', " #{V.generate}"].none? { |x| V.valid?(x) })
ok('short: dạng VGD-XXXXXX (6 ký tự đầu, chữ hoa); ID sai thì rỗng', (id = '8a42f1c0-1111-4222-8333-444455556666'; V.short(id) == 'VGD-8A42F1') && V.short('abc') == '' && V.short(nil) == '')

# ---- Đọc / ghi ----
e = FakeEntity.new(5)
ok('chưa có ID: đọc ra rỗng, không lỗi', V.read(e) == '' && V.read(Object.new) == '')
id = V.assign(e)
ok('gán ID: lưu ở dictionary riêng VGD_BIM_ID, KHÔNG đụng dictionary VGD_BIM (không làm món thành "đã có dữ liệu VGD")', V.valid?(id) && e.attrs.keys == ['VGD_BIM_ID'] && e.attrs['VGD_BIM_ID']['guid'] == id && V.read(e) == id)
ok('đã có ID: gán lại giữ nguyên, không đổi', V.assign(e) == id && V.read(e) == id)
e.attrs['VGD_BIM_ID']['guid'] = 'hỏng'
ok('ID trong món bị hỏng: coi như chưa có, gán lại được ID mới', V.read(e) == '' && V.valid?(V.assign(e)))
locked = FakeEntity.new(6, locked: true)
ok('món khóa: không gán được', error_of { V.assign(locked) }.to_s.include?('khóa') && locked.attrs.empty?)
ok('đối tượng không có thuộc tính: không gán được', error_of { V.assign(Object.new) }.to_s.include?('không hỗ trợ'))

# ---- Kế hoạch gán ----
items = [{index: 0, guid: '', locked: false}, {index: 1, guid: V.generate, locked: false}, {index: 2, guid: '', locked: true}, {index: 3, guid: 'sai', locked: false}]
plan = V.assign_plan(items)
ok('kế hoạch gán: món chưa có ID (kể cả ID hỏng) được gán, món đã có giữ nguyên, món khóa bị bỏ qua', plan == {assign: [0, 3], keep: [1], locked: [2]})

# ---- Trùng ----
g1 = V.generate; g2 = V.generate
dup_items = [{index: 0, pid: 30, guid: g1}, {index: 1, pid: 10, guid: g1}, {index: 2, pid: 20, guid: g1}, {index: 3, pid: 5, guid: g2}, {index: 4, pid: 6, guid: ''}, {index: 5, pid: nil, guid: g2}]
ok('trùng: nhóm các dòng cùng ID, bỏ ID rỗng / hỏng', V.duplicates(dup_items).sort == [[0, 1, 2], [3, 5]].map(&:sort).sort && V.duplicates([{index: 0, pid: 1, guid: ''}, {index: 1, pid: 2, guid: 'sai'}, {index: 2, pid: 3, guid: 'sai'}]).empty?)
ok('không trùng: danh sách rỗng', V.duplicates([{index: 0, pid: 1, guid: g1}, {index: 1, pid: 2, guid: g2}]).empty?)
fix = V.fix_plan(dup_items)
ok('sửa trùng: giữ ID cho món có mã bền nhỏ nhất, các món còn lại nhận ID mới; món không có mã bền xếp sau cùng', fix == {keep: [1, 3], renew: [0, 2, 5], locked: []})
locked_dup = [{index: 0, pid: 1, guid: g1, locked: true}, {index: 1, pid: 2, guid: g1}]
ok('sửa trùng: món khóa không được đổi ID (giữ nguyên, ghi vào danh sách khóa); món khóa giữ ID thì món còn lại vẫn đổi', V.fix_plan(locked_dup) == {keep: [0], renew: [1], locked: []} && V.fix_plan([{index: 0, pid: 1, guid: g1}, {index: 1, pid: 2, guid: g1, locked: true}]) == {keep: [0], renew: [], locked: [1]})
ok('sửa trùng khi không có trùng: không đổi gì', V.fix_plan([{index: 0, pid: 1, guid: g1}]) == {keep: [], renew: [], locked: []})
ok('renew ghi ID mới khác ID cũ', (x = FakeEntity.new(9); x.set_attribute('VGD_BIM_ID', 'guid', g1); new_id = V.renew(x); V.valid?(new_id) && new_id != g1 && V.read(x) == new_id))
ok('renew món khóa: từ chối', error_of { V.renew(FakeEntity.new(9, locked: true)) }.to_s.include?('khóa'))

puts($fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
