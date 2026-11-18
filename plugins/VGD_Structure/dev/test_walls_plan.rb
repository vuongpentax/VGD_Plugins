# Test loại tường và kế hoạch tường (core/wall_types.rb, wall_plan.rb): cao từ mặt sàn lên đáy dầm (hoặc đáy sàn tầng trên), dừng ở mặt cột,
# biên tiếp giáp trục biên, nút không có cột, cảnh báo, sao chép lựa chọn tường. Chạy: ruby dev/test_walls_plan.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
%w[schema grid axis_symbol geometry column_types beam_types wall_types opening_types levels column_plan beam_plan wall_joins wall_plan opening_plan plates slab_plan ceiling_plan state].each { |f| require File.join(ROOT, 'core', f) }
S = VGD::Structure
WT = S::WallTypes
L = S::Levels
WP = S::WallPlan
grid = S::Grid.default
types = S::ColumnTypes.default
bt = S::BeamTypes.default
wt = WT.default
spans = S::Grid.spans(grid).map { |sp| sp[:ref] }
cols = S::Grid.intersections(grid).each_with_object({}) { |i, h| h[i[:ref]] = {} }
def mk(grid, types, bt, wt, cols, beams, walls, extra = {})
  l = L.default
  l[0]['picks'] = {'columns' => cols, 'beams' => beams, 'walls' => walls}
  l[0].merge!(extra)
  L.normalize!(l, grid, types, bt, wt).first
end
all_walls = spans.each_with_object({}) { |r, h| h[r] = {} }

ok('loại tường mặc định T200 hợp lệ', WT.normalize!(WT.default) == WT.default)
bad = {'không phải mảng' => 'x', 'rỗng' => [], 'mã sai' => [{'id' => 'ct_00000001', 'name' => 'A', 't' => 200}], 'dày quá nhỏ' => [{'id' => 'wt_00000001', 'name' => 'A', 't' => 49}],
       'dày quá lớn' => [{'id' => 'wt_00000001', 'name' => 'A', 't' => 1001}], 'dày là chuỗi' => [{'id' => 'wt_00000001', 'name' => 'A', 't' => '200'}], 'tên rỗng' => [{'id' => 'wt_00000001', 'name' => ' ', 't' => 200}],
       'tên trùng' => [{'id' => 'wt_00000001', 'name' => 'A', 't' => 200}, {'id' => 'wt_00000002', 'name' => 'a', 't' => 100}], 'mã trùng' => [{'id' => 'wt_00000001', 'name' => 'A', 't' => 200}, {'id' => 'wt_00000001', 'name' => 'B', 't' => 100}]}
bad.each { |label, raw| ok("loại tường sai bị từ chối: #{label}", !error_of { WT.normalize!(raw) }.nil?) }
ok('dữ liệu cũ (không có loại tường, lựa chọn tường): bổ sung mặc định', (st = S::State.normalize!('grid' => grid, 'symbol' => {})) && st['wall_types'] == WT.default && st['levels'][0]['picks']['walls'] == {} && st['levels'][0]['wall_type'].nil?)
ok('loại tường mặc định hoặc loại của tường không tồn tại bị từ chối', !error_of { mk(grid, types, bt, wt, {}, {}, {}, 'wall_type' => 'wt_ffffffff') }.nil? && !error_of { mk(grid, types, bt, wt, {}, {}, {'x:A:1-2' => {'type' => 'wt_ffffffff'}}) }.nil?)

levels = mk(grid, types, bt, wt, cols, {}, all_walls)
plan = WP.plan(grid, types, bt, wt, levels, 'sl_00000001')
w = ->(ref) { plan[:items].find { |i| i[:ref] == ref } }
ok('17 tường, từ mặt sàn kết cấu (-50) lên đáy sàn tầng trên (3550 - 120 = 3430) khi không có dầm: cao 3480', plan[:items].size == 17 && plan[:items].all? { |i| i[:z_bottom] == -50.0 && i[:z_top] == 3430.0 && i[:height] == 3480.0 && !i[:under_beam] })
ok('tường biên x:A:1-2: mặt ngoài tiếp giáp trục A (y từ 0 đến 200), tâm 100; tường biên cuối x:C:1-2: y từ 7000 đến 7200; tường giữa x:B:1-2 tâm 3600', w['x:A:1-2'][:min][1] == 0.0 && w['x:A:1-2'][:max][1] == 200.0 && w['x:C:1-2'][:max][1] == 7200.0 && w['x:B:1-2'][:center] == 3600.0)
ok('tường dừng ở mặt cột: x:B:2-3 từ 4350 đến 8250; y:1:A-B từ 300 đến 3450', w['x:B:2-3'][:start] == 4350.0 && w['x:B:2-3'][:finish] == 8250.0 && w['y:1:A-B'][:start] == 300.0 && w['y:1:A-B'][:finish] == 3450.0)
ok('đủ cột, tường theo quy ước: không có cảnh báo', plan[:issues].empty?)

# Tường dưới dầm: cao tới đáy dầm
beams = spans.each_with_object({}) { |r, h| h[r] = {} }
lb = mk(grid, types, bt, wt, cols, beams, {'x:B:2-3' => {}, 'x:A:1-2' => {}})
pb = WP.plan(grid, types, bt, wt, lb, 'sl_00000001')
ok('nhịp có dầm D20x40 (đáy dầm 3550 - 400 = 3150): tường cao 3150 + 50 = 3200, đánh dấu dưới dầm', pb[:items].all? { |i| i[:z_top] == 3150.0 && i[:height] == 3200.0 && i[:under_beam] })
lp = mk(grid, types, bt, wt, cols, {'x:B:2-3' => {}}, {'x:B:2-3' => {}, 'x:B:3-4' => {}})
pp = WP.plan(grid, types, bt, wt, lp, 'sl_00000001')
ok('chỉ nhịp x:B:2-3 có dầm: tường đó cao 3200 (tới đáy dầm), tường x:B:3-4 (không dầm) cao 3480', pp[:items].find { |i| i[:ref] == 'x:B:2-3' }[:height] == 3200.0 && pp[:items].find { |i| i[:ref] == 'x:B:3-4' }[:height] == 3480.0)
bt2 = bt + [{'id' => 'bt_00000002', 'name' => 'D30x60', 'w' => 300.0, 'h' => 600.0}]
lbt = mk(grid, types, bt2, wt, cols, {'x:B:2-3' => {'type' => 'bt_00000002'}}, {'x:B:2-3' => {}})
ok('dầm cao 600: tường cao tới đáy dầm (3550 - 600 = 2950, từ -50: 3000)', WP.plan(grid, types, bt2, wt, lbt, 'sl_00000001')[:items][0][:height] == 3000.0)

# Loại tường
wt2 = wt + [{'id' => 'wt_00000002', 'name' => 'T100', 't' => 100.0}]
l2 = mk(grid, types, bt, wt2, cols, {}, {'x:B:1-2' => {'type' => 'wt_00000002', 'p' => 'min'}, 'x:B:2-3' => {}})
p2 = WP.plan(grid, types, bt, wt2, l2, 'sl_00000001')
ok('tường có loại riêng T100, p = min: y từ 3600 đến 3700; tường không ghi loại dùng loại đầu danh sách (T200)', p2[:items][0][:min][1] == 3600.0 && p2[:items][0][:max][1] == 3700.0 && p2[:items][1][:t] == 200.0)
l3 = mk(grid, types, bt, wt2, cols, {}, {'x:B:2-3' => {}}, 'wall_type' => 'wt_00000002')
ok('loại tường mặc định của tầng áp cho tường không ghi riêng', WP.plan(grid, types, bt, wt2, l3, 'sl_00000001')[:items][0][:t] == 100.0)
l4 = mk(grid, types, bt, wt, cols, {}, {'x:A:1-2' => {'p' => 'center'}})
ok('đặt tâm trên trục biên: tường nhô ra ngoài khung lưới, có cảnh báo', WP.plan(grid, types, bt, wt, l4, 'sl_00000001')[:issues].any? { |m| m.include?('nhô ra') })

# Nút không có cột
nc = mk(grid, types, bt, wt, {}, {}, {'x:B:1-2' => {}, 'x:B:2-3' => {}, 'y:2:A-B' => {}, 'y:2:B-C' => {}})
pn = WP.plan(grid, types, bt, wt, nc, 'sl_00000001')
n = ->(ref) { pn[:items].find { |i| i[:ref] == ref } }
ok('không có cột: tường X tới trục (0 đến 4200); tường Y dừng ở mặt tường X (A đến 3500; 3700 đến C)', n['x:B:1-2'][:start] == 0.0 && n['x:B:1-2'][:finish] == 4200.0 && n['y:2:A-B'][:finish] == 3500.0 && n['y:2:B-C'][:start] == 3700.0 && pn[:issues].none? { |m| m.include?('chồng') })

# Lỗi
ok('tầng trên cùng không có tường', error_of { WP.plan(grid, types, bt, wt, levels, 'sl_00000002') }.to_s.include?('tầng trên cùng'))
ok('tầng không tồn tại: báo lỗi', !error_of { WP.plan(grid, types, bt, wt, levels, 'sl_deadbeef') }.nil?)
short = S::Grid.normalize!('origin' => [0, 0], 'x_axes' => S::Grid.axes_from_spacings('300', :number), 'y_axes' => S::Grid.axes_from_spacings('3000', :letter))
ls = mk(short, types, bt, wt, S::Grid.intersections(short).each_with_object({}) { |i, h| h[i[:ref]] = {} }, {}, {'x:A:1-2' => {}})
ps = WP.plan(short, types, bt, wt, ls, 'sl_00000001')
ok('nhịp 300 giữa hai cột 300 rộng: khoảng hở không dương: bỏ tường và báo, không văng', ps[:items].empty? && ps[:issues].any? { |m| m.include?('khoảng hở') })

# Sao chép lựa chọn tường
three = L.normalize!([L.default[0].merge('picks' => {'columns' => {'1-A' => {}}, 'beams' => {'x:B:1-2' => {}}, 'walls' => {'x:A:1-2' => {'p' => 'center'}}}), L.default[1].merge('picks' => {'columns' => {}, 'beams' => {}, 'walls' => {'x:B:2-3' => {}}}), L.default[1].merge('id' => 'sl_00000003', 'name' => 'Tầng 3', 'elevation' => 7200.0)], grid, types, bt, wt).first
cp = L.copy_picks(three, 'sl_00000001', 'sl_00000002', grid, types, 'walls', bt, wt)
ok('sao chép lựa chọn tường: thay tường của tầng đích, giữ cột và dầm của tầng đích', cp[1]['picks']['walls'] == {'x:A:1-2' => {'p' => 'center'}} && cp[1]['picks']['beams'] == {} && cp[1]['picks']['columns'] == {})
cp2 = L.copy_picks(three, 'sl_00000001', 'sl_00000002', grid, types, 'beams', bt, wt)
ok('sao chép lựa chọn dầm: giữ nguyên tường của tầng đích', cp2[1]['picks']['walls'] == {'x:B:2-3' => {}} && cp2[1]['picks']['beams'] == {'x:B:1-2' => {}})
puts $fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
