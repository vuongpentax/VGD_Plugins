# Test loại dầm và kế hoạch dầm (core/beam_types.rb, beam_plan.rb): dầm treo dưới sàn, dừng ở mặt cột, vị trí vuông góc (biên tiếp giáp trục biên),
# nút không có cột, cảnh báo chồng / nhô ra, sao chép lựa chọn dầm. Chạy: ruby dev/test_beams_plan.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
%w[schema grid axis_symbol column_types beam_types wall_types levels column_plan beam_plan wall_plan state].each { |f| require File.join(ROOT, 'core', f) }
S = VGD::Structure
BT = S::BeamTypes
L = S::Levels
BP = S::BeamPlan
def deep(x); Marshal.load(Marshal.dump(x)); end
grid = S::Grid.default
types = S::ColumnTypes.default
btypes = BT.default
spans = S::Grid.spans(grid)
all_cols = S::Grid.intersections(grid).each_with_object({}) { |i, h| h[i[:ref]] = {} }
all_beams = spans.each_with_object({}) { |sp, h| h[sp[:ref]] = {} }
def mk(grid, types, btypes, cols, beams, extra = {})
  l = L.default
  l[0]['picks'] = {'columns' => cols, 'beams' => beams}
  l[0].merge!(extra)
  L.normalize!(l, grid, types, btypes).first
end
levels = mk(grid, types, btypes, all_cols, all_beams)

# Loại dầm
ok('loại dầm mặc định D20x40 hợp lệ', BT.normalize!(BT.default) == BT.default)
bad = {
  'không phải mảng' => 'x', 'rỗng' => [], 'mã sai' => [{'id' => 'ct_00000001', 'name' => 'A', 'w' => 200, 'h' => 400}],
  'rộng quá nhỏ' => [{'id' => 'bt_00000001', 'name' => 'A', 'w' => 99, 'h' => 400}], 'cao quá lớn' => [{'id' => 'bt_00000001', 'name' => 'A', 'w' => 200, 'h' => 2001}],
  'tên rỗng' => [{'id' => 'bt_00000001', 'name' => '', 'w' => 200, 'h' => 400}], 'cao là chuỗi' => [{'id' => 'bt_00000001', 'name' => 'A', 'w' => 200, 'h' => '400'}],
  'tên trùng' => [{'id' => 'bt_00000001', 'name' => 'A', 'w' => 200, 'h' => 400}, {'id' => 'bt_00000002', 'name' => 'a', 'w' => 200, 'h' => 400}],
  'mã trùng' => [{'id' => 'bt_00000001', 'name' => 'A', 'w' => 200, 'h' => 400}, {'id' => 'bt_00000001', 'name' => 'B', 'w' => 200, 'h' => 400}]
}
bad.each { |label, raw| ok("loại dầm sai bị từ chối: #{label}", !error_of { BT.normalize!(raw) }.nil?) }

# Tầng có dầm
ok('lựa chọn dầm theo mã nhịp, mặc định không có kiểu đặt', levels[0]['picks']['beams'].size == 17 && levels[0]['picks']['beams'].values.all?(&:empty?) && levels[0]['beam_type'].nil?)
ok('mã nhịp không còn trên lưới bị bỏ khi đọc (đếm)', L.normalize!([levels[0].merge('picks' => {'columns' => {}, 'beams' => {'x:A:1-2' => {}, 'x:Z:1-2' => {}}})] + levels[1..1], grid, types, btypes).then { |l, n| l[0]['picks']['beams'].keys == ['x:A:1-2'] && n == 1 })
ok('loại dầm mặc định không tồn tại bị từ chối', !error_of { L.normalize!([levels[0].merge('beam_type' => 'bt_ffffffff'), levels[1]], grid, types, btypes) }.nil?)
ok('dầm dùng loại không tồn tại bị từ chối', !error_of { mk(grid, types, btypes, {}, {'x:A:1-2' => {'type' => 'bt_ffffffff'}}) }.nil?)
ok('kiểu đặt dầm chỉ nhận p (x / y của dầm bị bỏ qua, p lạ bị từ chối)', !error_of { mk(grid, types, btypes, {}, {'x:A:1-2' => {'p' => 'left'}}) }.nil? && mk(grid, types, btypes, {}, {'x:A:1-2' => {'p' => 'center'}})[0]['picks']['beams'] == {'x:A:1-2' => {'p' => 'center'}})

# Kế hoạch
plan = BP.plan(grid, types, btypes, levels, 'sl_00000001')
b = ->(ref) { plan[:items].find { |i| i[:ref] == ref } }
ok('17 dầm, đỉnh dầm = đáy sàn tầng trên (3480), đáy dầm 3480 - 400 = 3080', plan[:items].size == 17 && plan[:z_top] == 3480.0 && plan[:items].all? { |i| i[:z_top] == 3480.0 && i[:z_bottom] == 3080.0 })
ok('dầm biên x:A:1-2 (trục A là trục biên đầu): mặt ngoài tiếp giáp trục: tâm y = 100 (nửa rộng), p = min', b['x:A:1-2'][:center] == 100.0 && b['x:A:1-2'][:mode] == 'min' && b['x:A:1-2'][:min][1] == 0.0 && b['x:A:1-2'][:max][1] == 200.0)
ok('dầm biên cuối x:C:1-2 (trục C): tâm y = 7200 - 100, p = max', b['x:C:1-2'][:center] == 7100.0 && b['x:C:1-2'][:mode] == 'max' && b['x:C:1-2'][:max][1] == 7200.0)
ok('dầm giữa x:B:1-2 tâm đúng trục (y = 3600), p = center', b['x:B:1-2'][:center] == 3600.0 && b['x:B:1-2'][:mode] == 'center')
ok('dầm theo Y: y:1:A-B biên trái (mặt ngoài tại x = 0, tâm x = 100); y:4:A-B biên phải (tâm 12500); y:2:A-B giữa (tâm 4200)', b['y:1:A-B'][:center] == 100.0 && b['y:4:A-B'][:center] == 12_500.0 && b['y:2:A-B'][:center] == 4200.0 && b['y:1:A-B'][:dir] == 'y')
ok('hai đầu dầm dừng ở MẶT CỘT: x:B:1-2 từ x = 4200-150... cột 1-B biên (tâm x 150, mặt phải 300) đến cột 2-B (tâm 4200, mặt trái 4050)', b['x:B:1-2'][:start] == 300.0 && b['x:B:1-2'][:finish] == 4050.0 && b['x:B:1-2'][:length] == 3750.0)
ok('dầm giữa hai cột giữa x:B:2-3: từ 4350 đến 8250, dài 3900', b['x:B:2-3'][:start] == 4350.0 && b['x:B:2-3'][:finish] == 8250.0 && b['x:B:2-3'][:length] == 3900.0)
ok('dầm theo Y dừng ở mặt cột theo Y (cột 1-A tâm y 150, mặt trên 300; cột 1-B tâm y 3600, mặt dưới 3450)', b['y:1:A-B'][:start] == 300.0 && b['y:1:A-B'][:finish] == 3450.0)
ok('chiều dài trong kế hoạch = hộp bao: dầm X rộng theo Y, dầm Y rộng theo X', b['x:B:1-2'][:max][1] - b['x:B:1-2'][:min][1] == 200.0 && b['y:2:A-B'][:max][0] - b['y:2:A-B'][:min][0] == 200.0)
ok('đủ cột và dầm theo quy ước: không có cảnh báo (không chồng cột, không nhô ra)', plan[:issues].empty?)

# Đổi loại, đổi kiểu đặt
bt2 = btypes + [{'id' => 'bt_00000002', 'name' => 'D30x60', 'w' => 300.0, 'h' => 600.0}]
lv2 = mk(grid, types, bt2, all_cols, {'x:B:1-2' => {'type' => 'bt_00000002', 'p' => 'min'}, 'x:B:2-3' => {}}, 'beam_type' => nil)
p2 = BP.plan(grid, types, bt2, lv2, 'sl_00000001')
c = ->(ref) { p2[:items].find { |i| i[:ref] == ref } }
ok('dầm có loại riêng D30x60, p = min: cạnh nhỏ tại trục (y từ 3600 đến 3900), cao 600 => đáy 2880', c['x:B:1-2'][:min][1] == 3600.0 && c['x:B:1-2'][:max][1] == 3900.0 && c['x:B:1-2'][:z_bottom] == 2880.0)
ok('dầm không ghi loại dùng loại đầu danh sách (D20x40)', c['x:B:2-3'][:type_name] == 'D20x40' && c['x:B:2-3'][:w] == 200.0)
lv2b = mk(grid, types, bt2, all_cols, {'x:B:2-3' => {}}, 'beam_type' => 'bt_00000002')
ok('loại dầm mặc định của tầng áp cho dầm không ghi riêng', BP.plan(grid, types, bt2, lv2b, 'sl_00000001')[:items].first[:type_name] == 'D30x60')
lv3 = mk(grid, types, btypes, all_cols, {'x:A:1-2' => {'p' => 'center'}})
p3 = BP.plan(grid, types, btypes, lv3, 'sl_00000001')
ok('đặt tâm trên trục biên: dầm nhô ra ngoài khung lưới và có cảnh báo', p3[:items][0][:center] == 0.0 && p3[:issues].any? { |m| m.include?('x:A:1-2') && m.include?('nhô ra') })

# Nút không có cột
nocol = mk(grid, types, btypes, {}, {'x:B:1-2' => {}, 'x:B:2-3' => {}, 'y:2:A-B' => {}, 'y:2:B-C' => {}})
pn = BP.plan(grid, types, btypes, nocol, 'sl_00000001')
n = ->(ref) { pn[:items].find { |i| i[:ref] == ref } }
ok('không có cột: dầm X chạy tới trục (x:B:1-2 từ 0 đến 4200; x:B:2-3 từ 4200 đến 8400)', n['x:B:1-2'][:start] == 0.0 && n['x:B:1-2'][:finish] == 4200.0 && n['x:B:2-3'][:start] == 4200.0)
ok('dầm Y dừng ở mặt dầm X chạm nút: y:2:A-B từ trục A (0) đến mặt dưới dầm X tại B (3600 - 100 = 3500)', n['y:2:A-B'][:start] == 0.0 && n['y:2:A-B'][:finish] == 3500.0)
ok('dầm Y phía trên bắt đầu ở mặt trên dầm X (3700) tới trục C (7200)', n['y:2:B-C'][:start] == 3700.0 && n['y:2:B-C'][:finish] == 7200.0)
ok('không có cột nhưng dầm gặp nhau theo quy tắc: không chồng nhau, không cảnh báo chồng', pn[:issues].none? { |m| m.include?('chồng') })
# Hai dầm X khác bề rộng / vị trí cùng chạm một nút không có cột: dầm Y dừng ở mặt xa nhất (an toàn, không chồng)
mix = mk(grid, types, bt2, {}, {'x:B:1-2' => {'type' => 'bt_00000002', 'p' => 'min'}, 'x:B:2-3' => {}, 'y:2:A-B' => {}, 'y:2:B-C' => {}})
pm = BP.plan(grid, types, bt2, mix, 'sl_00000001')
ok('hai dầm X (3600 đến 3900 và 3500 đến 3700) chạm nút 2-B: dầm Y phía dưới dừng ở mặt dưới thấp nhất 3500, dầm Y phía trên bắt đầu ở mặt trên cao nhất 3900', pm[:items].find { |i| i[:ref] == 'y:2:A-B' }[:finish] == 3500.0 && pm[:items].find { |i| i[:ref] == 'y:2:B-C' }[:start] == 3900.0 && pm[:issues].none? { |m| m.include?('chồng') })
lonely = mk(grid, types, btypes, {}, {'y:2:A-B' => {}})
ok('dầm Y một mình, không dầm X và không cột: chạy từ trục tới trục', (BP.plan(grid, types, btypes, lonely, 'sl_00000001')[:items][0].values_at(:start, :finish)) == [0.0, 3600.0])

# Cảnh báo chồng cột
fat = [{'id' => 'ct_00000001', 'name' => 'F', 'w' => 300.0, 'd' => 300.0}]
wide_col = mk(grid, fat, btypes, {'2-B' => {'x' => 'max', 'y' => 'center'}}, {'x:B:2-3' => {'p' => 'center'}})
pwc = BP.plan(grid, fat, btypes, wide_col, 'sl_00000001')
ok('một cột bị đặt lệch, dầm quanh đó không chồng cột (đầu dầm tại mặt cột)', pwc[:issues].none? { |m| m.include?('chồng lên cột') } && pwc[:items][0][:start] == 4200.0)
cx = mk(grid, types, btypes, {'1-B' => {'x' => 'center'}}, {'y:1:A-B' => {'p' => 'center'}})
pcx = BP.plan(grid, types, btypes, cx, 'sl_00000001')
ok('dầm đặt tâm trên trục biên và cột đặt tâm trên trục biên chồng nhau hoặc nhô ra được báo', pcx[:issues].any?)

# Lỗi
ok('tầng trên cùng không có dầm', error_of { BP.plan(grid, types, btypes, levels, 'sl_00000002') }.to_s.include?('tầng trên cùng'))
tall = [{'id' => 'bt_00000001', 'name' => 'T', 'w' => 200.0, 'h' => 2000.0}]
ltall = mk(grid, types, tall, all_cols, {'x:B:1-2' => {}})
ok('dầm cao hơn chiều cao tầng (cột cao 3480; dầm 2000 vẫn lọt; tầng thấp thì báo)', error_of { BP.plan(grid, types, tall, ltall, 'sl_00000001') }.nil? && !error_of {
  low = L.normalize!([L.default[0].merge('picks' => {'columns' => {}, 'beams' => {'x:B:1-2' => {}}}), L.default[1].merge('elevation' => 1500.0)], grid, types, tall).first
  BP.plan(grid, types, tall, low, 'sl_00000001')
}.nil?)
short = S::Grid.normalize!('origin' => [0, 0], 'x_axes' => S::Grid.axes_from_spacings('300', :number), 'y_axes' => S::Grid.axes_from_spacings('3000', :letter))
ls = mk(short, types, btypes, S::Grid.intersections(short).each_with_object({}) { |i, h| h[i[:ref]] = {} }, {'x:A:1-2' => {}})
ps = BP.plan(short, types, btypes, ls, 'sl_00000001')
ok('nhịp 300 giữa hai cột 300 rộng: khoảng hở 0 hoặc âm: bỏ dầm và báo, không văng', ps[:items].empty? && ps[:issues].any? { |m| m.include?('khoảng hở') })

# Sao chép lựa chọn dầm
three = L.normalize!([L.default[0].merge('picks' => {'columns' => {'1-A' => {}}, 'beams' => {'x:A:1-2' => {'p' => 'center'}}}), L.default[1].merge('picks' => {'columns' => {'3-C' => {}}, 'beams' => {'x:B:2-3' => {}}}), L.default[1].merge('id' => 'sl_00000003', 'name' => 'Tầng 3', 'elevation' => 7200.0)], grid, types, btypes).first
cp = L.copy_picks(three, 'sl_00000001', 'sl_00000002', grid, types, 'beams', btypes)
ok('sao chép lựa chọn dầm: thay dầm của tầng đích, giữ nguyên cột của tầng đích', cp[1]['picks']['beams'] == {'x:A:1-2' => {'p' => 'center'}} && cp[1]['picks']['columns'] == {'3-C' => {}})
cp2 = L.copy_picks(three, 'sl_00000001', 'sl_00000002', grid, types, 'columns', btypes)
ok('sao chép lựa chọn cột: giữ nguyên dầm của tầng đích', cp2[1]['picks']['columns'] == {'1-A' => {}} && cp2[1]['picks']['beams'] == {'x:B:2-3' => {}})
ok('loại lựa chọn lạ bị từ chối', !error_of { L.copy_picks(three, 'sl_00000001', 'sl_00000002', grid, types, 'ceilings', btypes) }.nil?)

# Trạng thái gộp, dữ liệu cũ
st = S::State.normalize!('grid' => grid, 'symbol' => {}, 'types' => types, 'levels' => [{'id' => 'sl_00000001', 'name' => 'A', 'elevation' => 0, 'slab_thickness' => 120, 'column_type' => nil, 'picks' => {'columns' => {'1-A' => {}}}}, {'id' => 'sl_00000002', 'name' => 'B', 'elevation' => 3600}])
ok('dữ liệu cột mốc 2 (chưa có loại dầm, lựa chọn dầm) vẫn nạp được: bổ sung loại dầm mặc định, dầm rỗng', st['beam_types'] == BT.default && st['levels'][0]['picks']['beams'] == {} && st['levels'][0]['beam_type'].nil? && st['levels'][0]['picks']['columns'].size == 1)
ok('mã nhịp nhất quán: from_ref, to_ref là giao điểm có thật', spans.all? { |sp| [sp[:from_ref], sp[:to_ref]].all? { |r| all_cols.key?(r) } } && spans.all? { |sp| %w[min max].include?(sp[:side]) == (sp[:placement] == 'edge') })

puts $fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
