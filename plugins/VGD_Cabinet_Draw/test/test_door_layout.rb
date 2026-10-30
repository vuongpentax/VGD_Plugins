# Test lõi bố cục cánh theo vùng (Ruby thuần, không cần SketchUp).
# Chạy: ruby test_door_layout.rb [thư mục runtime]
$stdout.sync = true
RT = File.expand_path(ARGV[0] || '../runtime/VGD_Cabinet_Draw', __dir__)
module VGD_Cabinet_Draw; end
load File.join(RT, 'door_layout.rb')
L = VGD_Cabinet_Draw::DoorLayout
$pass = 0
$fail = []
def check(name, cond, extra = nil)
  if cond then $pass += 1 else $fail << name; puts "FAIL: #{name} #{extra}" end
end
def raises?
  yield
  false
rescue ArgumentError => e
  e.message
end
def area(layout)
  layout.regions.sum { |r| (r['u1'] - r['u0']) * (r['v1'] - r['v0']) }
end
def tiled?(layout)
  return false unless (area(layout) - 1.0).abs < 1e-9
  layout.regions.combination(2).none? do |a, b|
    [a['u1'], b['u1']].min - [a['u0'], b['u0']].max > 1e-9 && [a['v1'], b['v1']].min - [a['v0'], b['v0']].max > 1e-9
  end
end

puts '== 1. Mặc định và chia =='
l = L::Layout.new(1200, 1940)
check 'mặc định 1 vùng', l.regions.length == 1 && l.regions.first.values_at('u0', 'u1', 'v0', 'v1') == [0.0, 1.0, 0.0, 1.0]
a, b = l.split(1, 'vertical', 0.25)
check 'chia dọc thành 2', l.regions.length == 2 && a['u1'] == 0.25 && b['u0'] == 0.25
check 'vùng cũ bị thay bằng id mới', l.find(1).nil? && a['id'] != b['id']
check 'còn ghép đúng hình vuông', tiled?(l)
c, d = l.split(b['id'], 'horizontal', 0.5)
check 'chia ngang trong vùng phải: chỉ vùng đó bị chia', l.regions.length == 3 && c['u0'] == 0.25 && d['u0'] == 0.25 && l.find(a['id'])['v1'] == 1.0
check 'dọc + ngang cùng lúc vẫn ghép đúng', tiled?(l)
check 'chia sát mép bị từ chối', raises? { l.split(a['id'], 'vertical', 0.005) }
check 'chia ngoài vùng bị từ chối', raises? { l.split(a['id'], 'vertical', 0.5) }
check 'vùng không tồn tại', raises? { l.split(999, 'vertical', 0.5) }

puts '== 2. Chia đều, /n =='
l = L::Layout.new(1200, 1940)
made = l.split_even(1, 'vertical', 3)
check '/3 ra 3 vùng đều', made.length == 3 && made.map { |r| (r['u1'] - r['u0']).round(6) }.uniq == [(1.0 / 3).round(6)] && tiled?(l)
mid = l.sorted[1]
sub = l.split_even(mid['id'], 'horizontal', 2)
check 'chia đều ngang trong ô giữa', sub.length == 2 && l.regions.length == 4 && tiled?(l)
check 'ô trái/phải không đổi', l.sorted.first['v1'] == 1.0 && l.sorted.last['v1'] == 1.0
check 'chia quá nhiều bị từ chối', raises? { l.split_even(l.sorted.first['id'], 'vertical', 40) }
check 'n<2 bị từ chối', raises? { l.split_even(l.sorted.first['id'], 'vertical', 1) }
l.reset_even('horizontal', 4)
check 'reset_even ngang 4 vùng', l.regions.length == 4 && l.regions.all? { |r| r['u0'] == 0.0 && r['u1'] == 1.0 } && tiled?(l)
check 'reset_even hoàn tác được', l.undo && l.regions.length == 4 && l.regions.any? { |r| r['u1'] < 1.0 }

puts '== 3. Chia theo mm =='
l = L::Layout.new(1200, 1940)
a, b = l.split_mm(1, 'vertical', 300, :low)
check 'chia 300 mm từ mép trái', (a['u1'] * 1200).round(6) == 300.0
l = L::Layout.new(1200, 1940)
a, b = l.split_mm(1, 'vertical', 300, :high)
check 'chia 300 mm từ mép phải', ((1 - b['u0']) * 1200).round(6) == 300.0
check 'khoảng cách 0 bị từ chối', raises? { l.split_mm(a['id'], 'vertical', 0) }

puts '== 4. Gộp =='
l = L::Layout.new(1200, 1940)
l.split_even(1, 'vertical', 3)
r = l.sorted
m = l.merge([r[0]['id'], r[1]['id']])
check 'gộp 2 vùng kề nhau', l.regions.length == 2 && m['u0'] == 0.0 && (m['u1'] - 2.0 / 3).abs < 1e-6 && tiled?(l)
l = L::Layout.new(1200, 1940)
l.split_even(1, 'vertical', 3)
r = l.sorted
check 'gộp 2 vùng không kề nhau bị từ chối', raises? { l.merge([r[0]['id'], r[2]['id']]) }
check 'gộp 1 vùng bị từ chối', raises? { l.merge([r[0]['id']]) }
# chữ L: không gộp được
l = L::Layout.new(1200, 1940)
l.split_even(1, 'vertical', 2)
right = l.sorted.last
top, bottom = l.split_even(right['id'], 'horizontal', 2).sort_by { |x| -x['v0'] }
left = l.sorted.first
check 'gộp hình chữ L bị từ chối', raises? { l.merge([left['id'], top['id']]) } && raises? { l.merge([left['id'], top['id'], bottom['id']]) } == false
check 'gộp trái + phải trên + phải dưới ra 1 vùng', l.regions.length == 1 && tiled?(l)
# gộp rồi chia lại
l = L::Layout.new(1200, 1940)
l.split_even(1, 'vertical', 4)
ids = l.sorted.map { |x| x['id'] }
l.merge(ids[1..2])
merged = l.regions.find { |x| (x['u1'] - x['u0'] - 0.5).abs < 1e-6 }
check 'gộp 2 ô giữa của 4', merged && l.regions.length == 3
l.split_even(merged['id'], 'vertical', 2)
check 'chia lại sau khi gộp', l.regions.length == 4 && tiled?(l)

puts '== 5. Hoàn tác và batch =='
l = L::Layout.new(1200, 1940)
l.split(1, 'vertical', 0.5)
l.split(l.sorted.first['id'], 'horizontal', 0.5)
check 'undo lần 1', l.undo && l.regions.length == 2
check 'undo lần 2', l.undo && l.regions.length == 1
check 'hết undo', !l.undo && !l.can_undo?
l.batch { l.split(1, 'vertical', 0.5); l.split(l.sorted.first['id'], 'horizontal', 0.5) }
check 'batch = 1 bước hoàn tác', l.regions.length == 3 && l.undo && l.regions.length == 1 && !l.can_undo?
l.split(1, 'vertical', 0.5)
copy = l.dup
copy.split(copy.sorted.first['id'], 'horizontal', 0.5)
check 'dup không ảnh hưởng bản gốc', l.regions.length == 2 && copy.regions.length == 3

puts '== 6. Gợi ý vị trí chia (propose) =='
l = L::Layout.new(1200, 1940)
l.split(1, 'vertical', 0.5)
rgn = l.sorted.first
check 'làm tròn 1 mm', (l.propose(rgn['id'], 'horizontal', 0.5003) * 1940).round(6) == (0.5003 * 1940).round.to_f
check 'sát mép vùng bị từ chối', l.propose(rgn['id'], 'vertical', 0.001).nil?
# hút vào đường chia sẵn có (ở trục ngang của ô khác)
l2 = L::Layout.new(1200, 1940)
l2.split(1, 'vertical', 0.5)
rgt = l2.sorted.last
l2.split(rgt['id'], 'horizontal', 0.4)
lft = l2.sorted.first
check 'hút vào đường chia ở ô bên cạnh', l2.propose(lft['id'], 'horizontal', 0.4 + 3.0 / 1940) == 0.4
check 'xa thì không hút', l2.propose(lft['id'], 'horizontal', 0.4 + 30.0 / 1940) != 0.4
check 'region_at', l2.region_at(0.2, 0.9)['id'] == lft['id'] && l2.region_at(0.8, 0.1)['u0'] == 0.5

puts '== 7. Khe (rects) =='
l = L::Layout.new(1200, 1940)
l.split(1, 'vertical', 0.5)
rc = l.rects(1200.0, 1940.0, 4.0)
check 'mép ngoài sát mặt tủ', rc.first[:x0] == 0.0 && rc.last[:x1] == 1200.0 && rc.first[:z0] == 0.0 && rc.first[:z1] == 1940.0
check 'khe chỉ nằm giữa 2 cánh', (rc[1][:x0] - rc[0][:x1]).round(9) == 4.0
l = L::Layout.new(1200, 1940)
l.split(1, 'vertical', 0.5)
l.split(l.sorted.last['id'], 'horizontal', 0.5)
rc = l.rects(1200.0, 1940.0, 6.0)
check '3 ô', rc.length == 3
tops = rc.select { |x| x[:x0] > 600 }
check 'khe ngang giữa 2 ô chồng nhau', tops.length == 2 && (tops.max_by { |x| x[:z0] }[:z0] - tops.min_by { |x| x[:z0] }[:z1]).round(9) == 6.0
check 'số cánh trái->phải rồi dưới->trên', rc.map { |x| x[:index] } == [0, 1, 2] && rc[0][:x0] == 0.0
check 'khe quá lớn làm vùng biến mất, không lỗi', L::Layout.new(100, 100).rects(100.0, 100.0, 500.0).length == 1

puts '== 8. Lưu / đọc =='
l = L::Layout.new(1200, 1940)
l.split_even(1, 'vertical', 3)
l.set_opening(l.sorted[0]['id'], 'left')
l.set_opening(l.sorted[2]['id'], 'right')
require 'json'
data = JSON.parse(JSON.generate(l.to_h))
back = L::Layout.from_h(data, 1200, 1940)
check 'đọc lại giữ vùng và loại mở', back.sorted.map { |x| x['opening_type'] } == %w[left none right] && tiled?(back)
check 'id được giữ', back.ids.sort == l.ids.sort
check 'next_id không đụng id cũ', (back.split(back.sorted[1]['id'], 'horizontal', 0.5).map { |x| x['id'] } & l.ids).empty?
check 'loại mở sai về none', L::Layout.from_h({ 'schema' => 2, 'regions' => [{ 'id' => 1, 'u0' => 0, 'u1' => 1, 'v0' => 0, 'v1' => 1, 'opening_type' => 'xyz' }] }).regions.first['opening_type'] == 'none'
# Schema 1 (bản cũ)
old_v = { 'schema' => 1, 'regions' => [{ 'index' => 0, 'u0' => 0.0, 'u1' => 0.25, 'axis' => 'vertical' }, { 'index' => 1, 'u0' => 0.25, 'u1' => 1.0, 'axis' => 'vertical' }] }
lv = L::Layout.from_h(old_v, 1200, 1940)
check 'schema 1 dọc -> 2 vùng', lv.regions.length == 2 && lv.sorted.first['u1'] == 0.25 && lv.sorted.first['v1'] == 1.0 && tiled?(lv)
old_h = { 'schema' => 1, 'regions' => [{ 'index' => 0, 'u0' => 0.0, 'u1' => 0.5, 'axis' => 'horizontal' }, { 'index' => 1, 'u0' => 0.5, 'u1' => 1.0, 'axis' => 'horizontal' }] }
lh = L::Layout.from_h(old_h, 1200, 1940)
check 'schema 1 ngang -> 2 vùng xếp chồng', lh.regions.length == 2 && lh.regions.all? { |x| x['u0'] == 0.0 && x['u1'] == 1.0 } && tiled?(lh)
# Dữ liệu hỏng
bad = { 'schema' => 2, 'regions' => [{ 'id' => 1, 'u0' => 0, 'u1' => 0.6, 'v0' => 0, 'v1' => 1 }, { 'id' => 2, 'u0' => 0.4, 'u1' => 1, 'v0' => 0, 'v1' => 1 }] }
check 'vùng chồng nhau -> về bố cục đơn', L::Layout.from_h(bad).regions.length == 1
check 'dữ liệu rỗng / sai kiểu -> bố cục đơn', L::Layout.from_h(nil).regions.length == 1 && L::Layout.from_h({}).regions.length == 1 && L::Layout.from_h('x').regions.length == 1
check 'vùng thiếu một khoảng -> về bố cục đơn', L::Layout.from_h({ 'schema' => 2, 'regions' => [{ 'id' => 1, 'u0' => 0, 'u1' => 0.5, 'v0' => 0, 'v1' => 1 }] }).regions.length == 1

puts '== 12. Tự chia theo vách giữa: cánh chia tại tim mặt trước vách =='
check 'một vách: chia ở tim vách', L.partition_splits([[300.0, 320.0]], 0.0, 1000.0) == [310.0], L.partition_splits([[300.0, 320.0]], 0.0, 1000.0).inspect
check 'hai vách liền kề: chia ở giữa hai vách', L.partition_splits([[300.0, 320.0], [320.0, 340.0]], 0.0, 1000.0) == [320.0], L.partition_splits([[300.0, 320.0], [320.0, 340.0]], 0.0, 1000.0).inspect
check 'hai vách cách xa: mỗi vách một chỗ chia (sắp tăng dần)', L.partition_splits([[600.0, 620.0], [200.0, 220.0]], 0.0, 1000.0) == [210.0, 610.0]
check 'vách sát mép (dưới 20 mm) bị bỏ', L.partition_splits([[5.0, 25.0]], 0.0, 1000.0).empty?
check 'khe 1 mm giữa hai vách vẫn tính liền kề', L.partition_splits([[300.0, 320.0], [321.0, 341.0]], 0.0, 1000.0, 2.0) == [320.5]
check 'không có vách: không chia', L.partition_splits([], 0.0, 1000.0).empty?
l = L::Layout.new(1000, 2000)
regions = l.reset_at('vertical', [0.31, 0.61])
check 'reset_at: 3 vùng ghép đúng', regions.length == 3 && tiled?(l), regions.length.to_s
check 'reset_at: bỏ điểm chia sát nhau (dưới 20 mm)', l.reset_at('vertical', [0.5, 0.505]).length == 2
check 'reset_at: không có điểm chia thì một vùng', l.reset_at('vertical', []).length == 1
check 'reset_at: bước hoàn tác được', (l.reset_at('vertical', [0.25]); l.undo; l.regions.length == 1)
l = L::Layout.new(1000, 2000)
id = l.regions.first['id']
check 'propose hút vào điểm phụ (tim vách) khi đủ gần', l.propose(id, 'vertical', 0.3125, [0.31], 10.0) == 0.31, l.propose(id, 'vertical', 0.3125, [0.31], 10.0).inspect
check 'propose không hút khi xa hơn ngưỡng', l.propose(id, 'vertical', 0.33, [0.31], 10.0) == 0.33, l.propose(id, 'vertical', 0.33, [0.31], 10.0).inspect
check 'propose ngưỡng hút theo tham số (xa hơn 6 mm vẫn hút)', l.propose(id, 'vertical', 0.318, [0.31], 10.0) == 0.31

puts '== 13. Xóa cánh rồi tạo lại: vùng mới có cánh, gộp 1 vùng trống để tạo lại =='
l = L::Layout.new(1000, 2000)
rid = l.regions.first['id']
l.regions.first['empty'] = true
check 'tất cả vùng trống', l.all_empty?
a, b = l.split(rid, 'vertical', 0.5)
check 'chia vùng trống: hai vùng mới đều có cánh', !a['empty'] && !b['empty'] && !l.all_empty?
l = L::Layout.new(1000, 2000)
l.split_even(l.regions.first['id'], 'vertical', 2)
l.regions.first['empty'] = true
empty_id = l.regions.first['id']
l.merge([empty_id])
check 'merge một vùng trống: tạo lại cánh', !l.find(empty_id)['empty']
check 'merge một vùng có cánh: vẫn báo lỗi', raises? { l.merge([l.regions.last['id']]) }.to_s.include?('ít nhất 2')

puts '== 14. Chia khoang theo ngưỡng (bay_splits), khe ngang/dọc riêng, cờ tự động =='
# vách 400..417.5 trong lòng tủ 17.5..1182.5 (cửa 0..1200); khoang trái 382.5, khoang phải 765
cuts = L.bay_splits([[400.0, 417.5]], 17.5, 1182.5, 0.0, 1200.0, 450.0)
check 'bay_splits: vách + khoang phải rộng hơn ngưỡng chia đôi', cuts == [408.75, 800.0], cuts.inspect
cuts = L.bay_splits([[400.0, 417.5]], 17.5, 1182.5, 0.0, 1200.0, 0.0)
check 'bay_splits: ngưỡng 0 = tắt chia đôi khoang, chỉ chia ở vách', cuts == [408.75], cuts.inspect
cuts = L.bay_splits([], 17.5, 1182.5, 0.0, 1200.0, 450.0)
check 'bay_splits: không vách, tủ rộng hơn ngưỡng: 2 cánh', cuts == [600.0], cuts.inspect
cuts = L.bay_splits([], 17.5, 417.5, 0.0, 435.0, 450.0)
check 'bay_splits: khoang không quá ngưỡng: 1 cánh', cuts.empty?, cuts.inspect
cuts = L.bay_splits([], 0.0, 450.0, 0.0, 450.0, 450.0)
check 'bay_splits: đúng bằng ngưỡng vẫn 1 cánh (chỉ lớn hơn mới chia)', cuts.empty?
cuts = L.bay_splits([[400.0, 417.5], [417.5, 435.0]], 17.5, 1182.5, 0.0, 1200.0, 450.0)
check 'bay_splits: hai vách liền kề tính một cụm (chia ở giữa cụm)', cuts == [417.5, 808.75], cuts.inspect
cuts = L.bay_splits([[300.0, 317.5], [650.0, 667.5]], 17.5, 982.5, 0.0, 1000.0, 450.0)
check 'bay_splits: ba khoang đều dưới ngưỡng: chỉ chia ở vách', cuts == [308.75, 658.75], cuts.inspect
cuts = L.bay_splits([[0.0, 17.5]], 17.5, 1182.5, 0.0, 1200.0, 450.0)
check 'bay_splits: vách sát mép bị bỏ, khoang lớn vẫn chia đôi', cuts.include?(600.0) && !cuts.include?(8.75), cuts.inspect

l = L::Layout.new(1000, 2000)
l.split(l.regions.first['id'], 'vertical', 0.5)
l.split(l.regions.first['id'], 'horizontal', 0.5)
cell = ->(rects, z0) { rects.find { |r| (r[:z0] - z0).abs < 1e-6 } }
r = l.rects(1000.0, 2000.0, 4.0, 25.0)
check 'rects: khe trái–phải 4, trên–dưới 25 độc lập', r.any? { |x| (x[:x1] - 498.0).abs < 1e-6 } && r.any? { |x| (x[:z1] - 987.5).abs < 1e-6 }, r.map { |x| x.values_at(:x0, :x1, :z0, :z1) }.inspect
r2 = l.rects(1000.0, 2000.0, 4.0)
check 'rects: không truyền khe dọc thì dùng chung một khe (như cũ)', r2.any? { |x| (x[:z1] - 998.0).abs < 1e-6 }, r2.map { |x| x[:z1] }.inspect

l = L::Layout.new(1000, 2000)
check 'layout mới không phải tự động', !l.auto? && !l.to_h.key?('auto')
l.reset_at('vertical', [0.5]); l.mark_auto!
check 'đánh dấu tự động và lưu vào to_h', l.auto? && l.to_h['auto'] == true
check 'from_h giữ cờ tự động', L::Layout.from_h(l.to_h, 1000, 2000).auto?
l.set_opening(l.regions.first['id'], 'left')
check 'đổi hướng mở không bỏ cờ tự động', l.auto?
l.regions.last['empty'] = true
check 'xóa cánh (vùng trống) không bỏ cờ tự động', l.auto?
l.split(l.regions.first['id'], 'horizontal', 0.5)
check 'chia tay bỏ cờ tự động', !l.auto?
l.undo
check 'hoàn tác khôi phục cờ tự động', l.auto?
l.merge([l.regions.first['id'], l.regions.last['id']]) rescue nil
l = L::Layout.new(1000, 2000); l.reset_at('vertical', [0.5]); l.mark_auto!
l.reset_even('vertical', 3)
check 'chia đều lại bỏ cờ tự động', !l.auto?

# reset_at(keep: true): giữ id, hướng mở, vùng trống theo vùng cũ chồng nhiều nhất
l = L::Layout.new(1000, 2000)
l.reset_at('vertical', [0.4, 0.7]); l.mark_auto!
a, b, c = l.sorted.map { |x| x['id'] }
l.set_opening(a, 'left'); l.set_opening(c, 'right'); l.find(b)['empty'] = true
l.reset_at('vertical', [0.45, 0.75], keep: true); l.mark_auto!
n = l.sorted
check 'retarget: vẫn 3 vùng, giữ id', n.map { |x| x['id'] } == [a, b, c], n.map { |x| x['id'] }.inspect
check 'retarget: giữ hướng mở và vùng trống', n[0]['opening_type'] == 'left' && n[2]['opening_type'] == 'right' && n[1]['empty'], n.inspect
check 'retarget: vị trí chia mới', (n[0]['u1'] - 0.45).abs < 1e-9 && (n[1]['u1'] - 0.75).abs < 1e-9
l.reset_at('vertical', [0.3, 0.45, 0.75], keep: true)
n = l.sorted
check 'retarget: thêm vùng, vùng cũ giữ id không trùng', n.map { |x| x['id'] }.uniq.length == 4 && tiled?(l), n.map { |x| x['id'] }.inspect
l.reset_at('vertical', [], keep: true)
check 'retarget: gộp còn một vùng vẫn hợp lệ', l.regions.length == 1 && tiled?(l)

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.length}"
exit($fail.empty? ? 0 : 1)
