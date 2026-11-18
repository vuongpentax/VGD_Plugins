# Test kế hoạch sàn và trần (core/slab_plan.rb, ceiling_plan.rb) và dữ liệu tầng liên quan (cao trần, dày trần, lựa chọn ô):
# sàn phủ ô, mặt trên tại cao độ tầng; trần lùi tới mặt tường, khoét góc theo cột, giới hạn cao độ. Chạy: ruby dev/test_plates_plan.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
%w[schema grid axis_symbol geometry column_types beam_types wall_types opening_types layer_list levels column_plan beam_plan wall_joins wall_plan opening_plan plates slab_plan ceiling_plan state].each { |f| require File.join(ROOT, 'core', f) }
S = VGD::Structure
L = S::Levels
grid = S::Grid.default
types = S::ColumnTypes.default
bt = S::BeamTypes.default
wt = S::WallTypes.default
cells = S::Grid.cells(grid).map { |c| c[:ref] }
cols = S::Grid.intersections(grid).each_with_object({}) { |i, h| h[i[:ref]] = {} }
spans = S::Grid.spans(grid).map { |sp| sp[:ref] }
def mk(grid, types, bt, wt, picks, lv0 = {}, lv1 = {})
  l = L.default
  l[0]['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => {}, 'slabs' => {}, 'ceilings' => {}}.merge(picks)
  l[0].merge!(lv0)
  l[1].merge!(lv1)
  L.normalize!(l, grid, types, bt, wt).first
end
all_cells = cells.each_with_object({}) { |r, h| h[r] = {} }

# Dữ liệu tầng
d = L.default[0]
ok('tầng mặc định: cao trần 2800, dày trần 9, chưa chọn sàn / trần', d['ceiling_height'] == 2800.0 && d['ceiling_thickness'] == 9.0 && d['picks']['slabs'] == {} && d['picks']['ceilings'] == {})
bad = {'cao trần quá thấp' => {'ceiling_height' => 1000}, 'cao trần quá cao' => {'ceiling_height' => 30_000}, 'cao trần là chuỗi' => {'ceiling_height' => '2800'},
       'dày trần quá mỏng' => {'ceiling_thickness' => 1}, 'dày trần quá dày' => {'ceiling_thickness' => 200}}
bad.each { |label, o| ok("tầng sai bị từ chối: #{label}", !error_of { L.normalize!([L.default[0].merge(o), L.default[1]], grid, types, bt, wt) }.nil?) }
ok('picks sàn không phải bảng băm hoặc ô không phải bảng băm bị từ chối', !error_of { mk(grid, types, bt, wt, {'slabs' => 5}) }.nil? && !error_of { mk(grid, types, bt, wt, {'slabs' => {'1-2/A-B' => 1}}) }.nil?)
pr = L.normalize!([L.default[0].merge('picks' => {'slabs' => {'1-2/A-B' => {}, '9-9/Z-Z' => {}}, 'ceilings' => {'8-9/A-B' => {}}}), L.default[1]], grid, types, bt, wt)
ok('ô không còn trên lưới bị bỏ khi đọc và được đếm', pr[0][0]['picks']['slabs'].keys == ['1-2/A-B'] && pr[0][0]['picks']['ceilings'].empty? && pr[1] == 2)
ok('dữ liệu cũ (chưa có cao trần, sàn, trần) bổ sung mặc định', (st = S::State.normalize!('grid' => grid, 'symbol' => {}, 'levels' => [{'id' => 'sl_00000001', 'name' => 'A', 'elevation' => 0}, {'id' => 'sl_00000002', 'name' => 'B', 'elevation' => 3600}])) && st['levels'][0]['ceiling_height'] == 2800.0 && st['levels'][0]['picks']['slabs'] == {})
ok('mã ô có tên trục thành phần (xa, xb, ya, yb) khớp mã', S::Grid.cells(grid).all? { |c| c[:ref] == "#{c[:xa]}-#{c[:xb]}/#{c[:ya]}-#{c[:yb]}" })

# Sàn
levels = mk(grid, types, bt, wt, {'slabs' => all_cells})
sp = S::SlabPlan.plan(grid, levels, 'sl_00000001')
ok('6 sàn phủ 6 ô, mặt trên sàn kết cấu = cao độ tầng 0 trừ cán nền 50 = -50, dày 120 xuống dưới (đáy -170)', sp[:items].size == 6 && sp[:items].all? { |i| i[:z_top] == -50.0 && i[:z_bottom] == -170.0 && i[:thickness] == 120.0 })
s12 = sp[:items].find { |i| i[:ref] == '1-2/A-B' }
ok('sàn ô 1-2/A-B phủ từ trục tới trục (0,0)-(4200,3600), diện tích 15,12 m²', s12[:min] == [0.0, 0.0] && s12[:max] == [4200.0, 3600.0] && s12[:area] == 15.12)
ok('sàn theo thứ tự ô của lưới', sp[:items].map { |i| i[:ref] } == cells)
top = SlabTop = S::SlabPlan.plan(grid, levels, 'sl_00000002')
ok('tầng trên cùng cũng có sàn (chưa chọn ô nào thì rỗng)', top[:items].empty? && top[:z_top] == 3550.0)
l2 = mk(grid, types, bt, wt, {}, {}, 'picks' => {'slabs' => {'1-2/A-B' => {}}})
ok('sàn tầng trên cùng: mặt trên kết cấu 3600 - 50 = 3550, đáy 3430', S::SlabPlan.plan(grid, l2, 'sl_00000002')[:items][0].values_at(:z_top, :z_bottom) == [3550.0, 3430.0])
lt = mk(grid, types, bt, wt, {'columns' => cols, 'slabs' => all_cells}, {}, 'slab_thickness' => 200)
ok('cột tầng dưới lên tới mặt sàn kết cấu tầng trên (3550), đáy sàn 3550 - 200 = 3350; sàn lọt lòng nên không chồng cột', S::ColumnPlan.plan(grid, types, lt, 'sl_00000001')[:z1] == 3550.0 && S::ColumnPlan.plan(grid, types, lt, 'sl_00000001')[:slab_bottom] == 3350.0 && S::SlabPlan.plan(grid, lt, 'sl_00000002')[:items].empty? && true)
ok('tầng không tồn tại: báo lỗi', !error_of { S::SlabPlan.plan(grid, levels, 'sl_deadbeef') }.nil?)

# Trần
cp = mk(grid, types, bt, wt, {'ceilings' => all_cells})
cplan = S::CeilingPlan.plan(grid, types, bt, wt, cp, 'sl_00000001')
ok('6 trần, mặt dưới ở 2800, dày 9 (mặt trên 2809); chưa có cột / tường: hình chữ nhật cả ô', cplan[:items].size == 6 && cplan[:items].all? { |i| i[:z_bottom] == 2800.0 && i[:z_top] == 2809.0 && i[:thickness] == 9.0 && i[:polygon].size == 4 } && cplan[:issues].empty?)
ok('trần ô 1-2/A-B: đa giác ngược chiều kim đồng hồ (0,0),(4200,0),(4200,3600),(0,3600)', cplan[:items][0][:polygon] == [[0.0, 0.0], [4200.0, 0.0], [4200.0, 3600.0], [0.0, 3600.0]])
# Có cột: khoét góc
cc = mk(grid, types, bt, wt, {'columns' => cols, 'ceilings' => {'2-3/A-B' => {}, '1-2/A-B' => {}}})
cn = S::CeilingPlan.plan(grid, types, bt, wt, cc, 'sl_00000001')
c1 = cn[:items].find { |i| i[:ref] == '1-2/A-B' }
ok('ô 1-2/A-B có cột ở 4 góc (cột góc 1-A tiếp giáp trục: chiếm 300x300; cột biên 2-A, 1-B nửa trong ô): đa giác có khoét góc, 12 đỉnh', c1[:polygon].size == 12)
ok('khoét góc dưới trái theo cột 1-A (tâm 150,150 rộng 300): đỉnh (0,300),(300,300),(300,0)', c1[:polygon][0..2] == [[0.0, 300.0], [300.0, 300.0], [300.0, 0.0]])
ok('khoét góc dưới phải theo cột 2-A (tâm 4200,150): phần nằm trong ô rộng 150 sâu 300: đỉnh (4050,0),(4050,300),(4200,300)', c1[:polygon][3..5] == [[4050.0, 0.0], [4050.0, 300.0], [4200.0, 300.0]])
ok('diện tích trần = diện tích ô trừ phần cột chiếm (15,12 trừ 0,09 + 0,045 + 0,0225 + 0,045)', (c1[:area] - (15.12 - 0.09 - 0.045 - 0.0225 - 0.045)).abs < 0.002)
ok('cột giữa 2-B chiếm góc ô: ô 2-3/A-B khoét ở góc trên trái (cột 2-B tâm (4200,3600) 300x300: 150 x 150 trong ô)', cn[:items].find { |i| i[:ref] == '2-3/A-B' }[:polygon].include?([4350.0, 3600.0]) && cn[:items].find { |i| i[:ref] == '2-3/A-B' }[:polygon].include?([4200.0, 3450.0]))
ok('không có cảnh báo khi cột và trần khớp nhau', cn[:issues].empty?)
# Có tường: lùi tới mặt tường
cw = mk(grid, types, bt, wt, {'columns' => cols, 'walls' => {'x:A:1-2' => {}, 'x:B:1-2' => {}, 'y:1:A-B' => {}, 'y:2:A-B' => {}}, 'ceilings' => {'1-2/A-B' => {}}})
cwp = S::CeilingPlan.plan(grid, types, bt, wt, cw, 'sl_00000001')[:items][0]
ok('tường 4 cạnh dày 200 (biên dày vào trong, nhịp giữa tâm trên trục): trần lùi tới mặt tường: x từ 200 đến 4100, y từ 200 đến 3500', cwp[:min] == [200.0, 200.0] && cwp[:max] == [4100.0, 3500.0])
ok('trần lùi khỏi tường thì không còn chạm cột: cột góc 1-A (300x300) vẫn khoét góc nhỏ hơn: (300 - 200) x (300 - 200)', cwp[:polygon].size == 12 && cwp[:polygon][0..2] == [[200.0, 300.0], [300.0, 300.0], [300.0, 200.0]])
cw1 = mk(grid, types, bt, wt, {'walls' => {'x:A:1-2' => {}}, 'ceilings' => {'1-2/A-B' => {}}})
ok('chỉ có một tường (cạnh dưới): trần lùi cạnh dưới 200, các cạnh khác tới trục', S::CeilingPlan.plan(grid, types, bt, wt, cw1, 'sl_00000001')[:items][0].values_at(:min, :max) == [[0.0, 200.0], [4200.0, 3600.0]])
# Cột đặt lệch: khoét theo phần cột thật sự nằm trong ô (không đối xứng)
ca = mk(grid, types, bt, wt, {'columns' => {'2-A' => {'x' => 'max', 'y' => 'min'}, '1-A' => {'x' => 'center', 'y' => 'center'}}, 'ceilings' => {'1-2/A-B' => {}}})
pa = S::CeilingPlan.plan(grid, types, bt, wt, ca, 'sl_00000001')[:items][0]
ok('cột 2-A đặt cạnh lớn tại trục X (cột nằm hết trong ô, rộng 300): khoét dưới phải rộng 300 sâu 300; cột 1-A tâm trên giao điểm: khoét 150 x 150', pa[:polygon].include?([3900.0, 0.0]) && pa[:polygon].include?([3900.0, 300.0]) && pa[:polygon].include?([150.0, 0.0]) && pa[:polygon].include?([0.0, 150.0]))
# Cao độ trần
ok('cao trần làm mặt trên vượt đáy sàn tầng trên (3480): báo lỗi', error_of { S::CeilingPlan.plan(grid, types, bt, wt, mk(grid, types, bt, wt, {'ceilings' => all_cells}, 'ceiling_height' => 3475), 'sl_00000001') }.to_s.include?('cao hơn đáy sàn'))
ok('cao trần vừa đủ (đáy sàn 3430 - 9 = 3421): hợp lệ', error_of { S::CeilingPlan.plan(grid, types, bt, wt, mk(grid, types, bt, wt, {'ceilings' => all_cells}, 'ceiling_height' => 3421), 'sl_00000001') }.nil?)
cb = mk(grid, types, bt, wt, {'beams' => spans.each_with_object({}) { |r, h| h[r] = {} }, 'ceilings' => {'1-2/A-B' => {}}}, 'ceiling_height' => 3200)
ok('trần cao 3200 chạm đáy dầm 3150: cảnh báo', S::CeilingPlan.plan(grid, types, bt, wt, cb, 'sl_00000001')[:issues].any? { |m| m.include?('chạm dầm') })
ok('trần cao 2800 thấp hơn đáy dầm: không cảnh báo', S::CeilingPlan.plan(grid, types, bt, wt, mk(grid, types, bt, wt, {'beams' => spans.each_with_object({}) { |r, h| h[r] = {} }, 'ceilings' => {'1-2/A-B' => {}}}), 'sl_00000001')[:issues].empty?)
ok('tầng trên cùng không có trần, tầng không tồn tại báo lỗi', error_of { S::CeilingPlan.plan(grid, types, bt, wt, cp, 'sl_00000002') }.to_s.include?('tầng trên cùng') && !error_of { S::CeilingPlan.plan(grid, types, bt, wt, cp, 'sl_deadbeef') }.nil?)
# Khoảng hở quá nhỏ
fat = [{'id' => 'wt_00000001', 'name' => 'F', 't' => 1000.0}]
narrow = S::Grid.normalize!('origin' => [0, 0], 'x_axes' => S::Grid.axes_from_spacings('1500', :number), 'y_axes' => S::Grid.axes_from_spacings('3000', :letter))
ln = mk(narrow, types, bt, fat, {'walls' => {'y:1:A-B' => {}, 'y:2:A-B' => {}}, 'ceilings' => {'1-2/A-B' => {}}})
pn = S::CeilingPlan.plan(narrow, types, bt, fat, ln, 'sl_00000001')
ok('hai tường dày 1000 ở hai bên ô rộng 1500: khoảng hở 0 hoặc nhỏ: bỏ trần, báo, không văng', pn[:items].empty? && pn[:issues].any? { |m| m.include?('khoảng hở') })
tiny = S::Grid.normalize!('origin' => [0, 0], 'x_axes' => S::Grid.axes_from_spacings('400', :number), 'y_axes' => S::Grid.axes_from_spacings('3000', :letter))
cols_t = S::Grid.intersections(tiny).each_with_object({}) { |i, h| h[i[:ref]] = {} }
lc = mk(tiny, [{'id' => 'ct_00000001', 'name' => 'W', 'w' => 300.0, 'd' => 300.0}], bt, wt, {'columns' => cols_t, 'ceilings' => {'1-2/A-B' => {}}})
ok('ô rộng 400 với hai cột 300 ở hai góc chiếm trọn cạnh: bỏ trần và báo', S::CeilingPlan.plan(tiny, [{'id' => 'ct_00000001', 'name' => 'W', 'w' => 300.0, 'd' => 300.0}], bt, wt, lc, 'sl_00000001')[:issues].any? { |m| m.include?('chiếm hết') })
# Sao chép
three = L.normalize!([L.default[0].merge('picks' => {'slabs' => {'1-2/A-B' => {}}, 'ceilings' => {'2-3/A-B' => {}}}), L.default[1].merge('picks' => {'slabs' => {'3-4/B-C' => {}}}), L.default[1].merge('id' => 'sl_00000003', 'name' => 'T3', 'elevation' => 7200.0)], grid, types, bt, wt).first
ok('sao chép lựa chọn sàn và trần giữa tầng (từng loại riêng)', L.copy_picks(three, 'sl_00000001', 'sl_00000002', grid, types, 'slabs', bt, wt)[1]['picks']['slabs'].keys == ['1-2/A-B'] && L.copy_picks(three, 'sl_00000001', 'sl_00000002', grid, types, 'ceilings', bt, wt)[1]['picks']['ceilings'].keys == ['2-3/A-B'] && L.copy_picks(three, 'sl_00000001', 'sl_00000002', grid, types, 'ceilings', bt, wt)[1]['picks']['slabs'].keys == ['3-4/B-C'])
puts $fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
