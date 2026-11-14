# Mốc phiên bản (core/snapshots.rb): chụp, lưu / đọc trong model, so sánh thêm / xóa / đổi. Chạy: ruby dev/test_snapshots.rb
require_relative '../runtime/vgd_bim/core/snapshots'
$fails = 0
def ok(name, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{name}"; $fails += 1 unless cond; end
S = VGD::BIM::Snapshots
def raises?(&block); block.call; nil; rescue ArgumentError => e; e.message; end
def row(i, over = {}); {index: i, pid: 100 + i, vgd_id: '', name: "Món #{i}", definition: "D#{i}", code: "C#{i}", level: 'T1', room: 'P1', material: 'Go', lenX: 600.0 + i, lenY: 500.0, lenZ: 720.0, calc_qty: 1.0}.merge(over); end
class FakeModel
  attr_reader :ops
  def initialize; @attrs = {}; @ops = []; end
  def get_attribute(d, k, default = nil); @attrs.dig(d, k) || default; end
  def set_attribute(d, k, v); (@attrs[d] ||= {})[k] = v; end
  def start_operation(*); @ops << :start; end
  def commit_operation; @ops << :commit; end
  def abort_operation; @ops << :abort; end
end

ok('khóa: VGD ID nếu có, không thì pid, không có gì thì rỗng', S.key_for(vgd_id: 'abc', pid: 5) == 'abc' && S.key_for(vgd_id: '', pid: 5) == 'pid:5' && S.key_for(vgd_id: '', pid: nil).empty? && S.key_for(vgd_id: '', pid: 0).empty?)
rows = [row(1), row(2, vgd_id: 'idx'), row(3, pid: nil), row(1)]
snap = S.capture('Bản 1', rows, Time.utc(2026, 11, 12, 8, 0, 0))
ok('chụp mốc: id sn_, tên, thời gian, bỏ dòng không nhận diện và dòng trùng khóa', snap['id'].match?(S::ID_PATTERN) && snap['name'] == 'Bản 1' && snap['created'] == '2026-11-12T08:00:00Z' && snap['items'].map { |i| i['key'] } == ['pid:101', 'idx'])
ok('mốc giữ giá trị chính đã làm tròn', snap['items'][0].values_at('name', 'code', 'level', 'room', 'material', 'lenX', 'calc_qty') == ['Món 1', 'C1', 'T1', 'P1', 'Go', 601.0, 1.0])
ok('tên trống: lỗi; bảng trống: lỗi', raises? { S.capture(' ', rows) }.to_s.include?('tên mốc') && raises? { S.capture('X', [row(3, pid: nil)]) }.to_s.include?('chưa có món'))
ok('tên có ký tự điều khiển được làm sạch, tên quá dài bị cắt', S.capture("a\nb", rows)['name'] == 'a b' && S.capture('x' * 100, rows)['name'].length == 60)
ok('quá nhiều món: lỗi', raises? { S.capture('X', Array.new(5001) { |i| row(i + 1) }) }.to_s.include?('quá'))

m = FakeModel.new
ok('chưa lưu: đọc ra rỗng', S.read(m) == [])
S.write(m, [snap])
back = S.read(m)
ok('lưu rồi đọc lại đúng; một thao tác', back.size == 1 && back[0]['items'] == snap['items'] && m.ops == [:start, :commit])
S.write(m, back)
ok('không đổi gì thì không mở thao tác', m.ops == [:start, :commit])
m.set_attribute('VGD_BIM_MODEL', 'snapshots', '[{"id":"sai"}]')
ok('dữ liệu hỏng: coi như chưa có', S.read(m) == [])
ok('ghi danh sách sai: lỗi', raises? { S.write(m, [{'id' => 'x'}]) }.to_s.include?('không hợp lệ'))
list = []
7.times { list = S.add(list, S.capture("M#{list.size}", rows)) }
ok('thêm quá số tối đa: bỏ mốc cũ nhất', list.size == 5 && list.first['name'] == 'M2')
ok('danh sách gọn có số món', S.summary([snap]) == [{'id' => snap['id'], 'name' => 'Bản 1', 'created' => snap['created'], 'count' => 2}])

now = [row(1, lenX: 700.0, level: 'T2'), row(4), row(5, pid: nil)]
diff = S.compare(snap, now)
ok('so sánh: món mới (có chỉ số dòng), bỏ dòng không nhận diện', diff['added'].map { |a| [a['key'], a['index']] } == [['pid:104', 4]])
ok('so sánh: món không còn trong bảng', diff['removed'] == [{'key' => 'idx', 'name' => 'Món 2'}])
ch = diff['changed']
ok('so sánh: món đổi, kèm từng trường đổi', ch.size == 1 && ch[0]['key'] == 'pid:101' && ch[0]['index'] == 1 && ch[0]['diffs'].map { |d| [d['field'], d['old'], d['new']] }.sort == [['level', 'T1', 'T2'], ['lenX', 601.0, 700.0]].sort)
ok('so sánh: không đổi gì thì không có thay đổi', (same = S.compare(snap, rows))['added'].empty? && same['removed'].empty? && same['changed'].empty? && same['unchanged'] == 2)
ok('làm tròn 0,1 nên sai số nhỏ không bị tính là đổi', S.compare(snap, [row(1, lenX: 601.04), row(2, vgd_id: 'idx')])['changed'].empty?)
ok('đổi tên món cũng được báo', S.compare(snap, [row(1, name: 'Tủ'), row(2, vgd_id: 'idx')])['changed'].map { |c| c['diffs'].map { |d| d['field'] } } == [['name']])
puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
