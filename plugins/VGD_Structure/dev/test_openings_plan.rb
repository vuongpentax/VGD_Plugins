# Test loại cửa, cửa trên tường và kế hoạch cửa (core/opening_types.rb, wall_plan.rb phần cửa, opening_plan.rb): dữ liệu sai bị từ chối, cửa nằm trọn trong tường,
# không chồng nhau, dưới dầm, tính diện tích lỗ mở, tọa độ thế giới theo hai phương, sao chép cửa giữa tầng. Chạy: ruby dev/test_openings_plan.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
%w[schema grid axis_symbol geometry column_types beam_types wall_types opening_types levels column_plan beam_plan wall_plan opening_plan plates slab_plan ceiling_plan state].each { |f| require File.join(ROOT, 'core', f) }
S = VGD::Structure
OT = S::OpeningTypes
L = S::Levels
grid = S::Grid.default
types = S::ColumnTypes.default
bt = S::BeamTypes.default
wt = S::WallTypes.default
ot = OT.default
cols = S::Grid.intersections(grid).each_with_object({}) { |i, h| h[i[:ref]] = {} }
def mk(grid, types, bt, wt, ot, walls, openings, beams = {}, cols = {})
  l = L.default
  l[0]['picks'] = {'columns' => cols, 'beams' => beams, 'walls' => walls, 'slabs' => {}, 'ceilings' => {}, 'openings' => openings}
  L.normalize!(l, grid, types, bt, wt, ot).first
end
def op(wall, type, pos, flip = false); {'wall' => wall, 'type' => type, 'pos' => pos, 'flip' => flip}; end
DOOR = 'ot_00000001'
WIN = 'ot_00000002'

# Loại cửa
ok('loại cửa mặc định: cửa đi D900x2100 và cửa sổ W1200x1200 cao ngưỡng 900', ot.map { |t| t.values_at('name', 'kind', 'w', 'h', 'sill') } == [['D900x2100', 'door', 900.0, 2100.0, 0.0], ['W1200x1200', 'window', 1200.0, 1200.0, 900.0]] && OT.normalize!(ot) == ot)
bad = {'không phải mảng' => 'x', 'rỗng' => [], 'mã sai' => [{'id' => 'wt_00000001', 'name' => 'A', 'kind' => 'door', 'w' => 900, 'h' => 2100, 'sill' => 0}],
       'kiểu lạ' => [{'id' => 'ot_00000001', 'name' => 'A', 'kind' => 'gate', 'w' => 900, 'h' => 2100, 'sill' => 0}], 'tên rỗng' => [{'id' => 'ot_00000001', 'name' => '', 'kind' => 'door', 'w' => 900, 'h' => 2100, 'sill' => 0}],
       'rộng quá nhỏ' => [{'id' => 'ot_00000001', 'name' => 'A', 'kind' => 'door', 'w' => 100, 'h' => 2100, 'sill' => 0}], 'cao quá lớn' => [{'id' => 'ot_00000001', 'name' => 'A', 'kind' => 'door', 'w' => 900, 'h' => 5000, 'sill' => 0}],
       'ngưỡng âm' => [{'id' => 'ot_00000001', 'name' => 'A', 'kind' => 'door', 'w' => 900, 'h' => 2100, 'sill' => -1}], 'ngưỡng là chuỗi' => [{'id' => 'ot_00000001', 'name' => 'A', 'kind' => 'door', 'w' => 900, 'h' => 2100, 'sill' => '0'}],
       'tên trùng' => ot + [ot[0].merge('id' => 'ot_00000003')], 'mã trùng' => [ot[0], ot[1].merge('id' => 'ot_00000001')]}
bad.each { |label, raw| ok("loại cửa sai bị từ chối: #{label}", !error_of { OT.normalize!(raw) }.nil?) }

# Dữ liệu cửa của tầng
good = mk(grid, types, bt, wt, ot, {'x:A:1-2' => {}}, {'op_00000001' => op('x:A:1-2', DOOR, 1500)})
ok('cửa hợp lệ lưu theo mã cửa: tường, loại, vị trí tâm, đổi mặt', good[0]['picks']['openings'] == {'op_00000001' => {'wall' => 'x:A:1-2', 'type' => DOOR, 'pos' => 1500.0, 'flip' => false}})
ok('cửa trên tường không còn trên lưới bị bỏ và đếm', L.normalize!([L.default[0].merge('picks' => {'openings' => {'op_00000001' => op('x:Z:1-2', DOOR, 1000), 'op_00000002' => op('x:A:1-2', DOOR, 1000)}}), L.default[1]], grid, types, bt, wt, ot).then { |l, n| l[0]['picks']['openings'].keys == ['op_00000002'] && n == 1 })
bad_open = {'mã sai' => {'cua1' => op('x:A:1-2', DOOR, 1000)}, 'loại không có' => {'op_00000001' => op('x:A:1-2', 'ot_ffffffff', 1000)}, 'vị trí âm' => {'op_00000001' => op('x:A:1-2', DOOR, -5)},
            'vị trí chuỗi' => {'op_00000001' => op('x:A:1-2', DOOR, '1000')}, 'vị trí quá lớn' => {'op_00000001' => op('x:A:1-2', DOOR, 200_000)}, 'đổi mặt không phải Có / Không' => {'op_00000001' => op('x:A:1-2', DOOR, 1000, 'x')},
            'cửa không phải bảng băm' => {'op_00000001' => 5}, 'picks không phải bảng băm' => 5}
bad_open.each { |label, o| ok("cửa sai bị từ chối: #{label}", !error_of { mk(grid, types, bt, wt, ot, {}, o) }.nil?) }
ok('dữ liệu cũ (chưa có loại cửa, lựa chọn cửa) bổ sung mặc định', (st = S::State.normalize!('grid' => grid, 'symbol' => {})) && st['opening_types'] == OT.default && st['levels'][0]['picks']['openings'] == {})

# Kế hoạch cửa trên tường
lv = mk(grid, types, bt, wt, ot, {'x:B:2-3' => {}, 'x:B:3-4' => {}, 'y:2:A-B' => {}}, {'op_00000001' => op('x:B:2-3', DOOR, 1950), 'op_00000002' => op('x:B:2-3', WIN, 3200), 'op_00000003' => op('y:2:A-B', DOOR, 1000)}, {}, cols)
wp = S::WallPlan.plan(grid, types, bt, wt, lv, 'sl_00000001', ot)
w = wp[:items].find { |i| i[:ref] == 'x:B:2-3' }
ok('tường x:B:2-3 (dài 3900, cao 3480) có 2 cửa hợp lệ sắp theo vị trí: cửa đi tâm 1950 và cửa sổ tâm 3200', w[:openings].map { |o| [o[:id], o[:kind]] } == [['op_00000001', 'door'], ['op_00000002', 'window']] && wp[:opening_issues].empty?)
d = w[:openings][0]
ok('cửa đi tâm 1950 rộng 900: từ x = 1500 đến 2400 (tính từ đầu tường), z từ 0 đến 2100', d.values_at(:x0, :x1, :z0, :z1) == [1500.0, 2400.0, 0.0, 2100.0])
wn = w[:openings][1]
ok('cửa sổ tâm 3200 rộng 1200 cao ngưỡng 900: x từ 2600 đến 3800, z từ 900 đến 2100', wn.values_at(:x0, :x1, :z0, :z1) == [2600.0, 3800.0, 900.0, 2100.0])
ok('diện tích lỗ mở của tường = 0,9 x 2,1 + 1,2 x 1,2 = 3,33 m²', w[:openings_area] == 3.33)
ok('tường không có cửa: danh sách rỗng, diện tích 0', wp[:items].find { |i| i[:ref] == 'x:B:3-4' }.then { |i| i[:openings].empty? && i[:openings_area] == 0.0 })
op_plan = S::OpeningPlan.plan(grid, types, bt, wt, ot, lv, 'sl_00000001')
ox = op_plan[:items].find { |i| i[:ref] == 'op_00000001' }
ok('kế hoạch cửa theo thế giới: cửa đi trên tường X bắt đầu ở x = 4350 + 1500 = 5850, tâm y = 3600, đáy z = 0, đỉnh 2100', ox.values_at(:along, :center, :z_bottom, :z_top, :thickness) == [5850.0, 3600.0, 0.0, 2100.0, 200.0] && ox[:dir] == 'x')
ok('hộp bao mặt bằng cửa: x 5850..6750, y 3500..3700', ox[:min] == [5850.0, 3500.0] && ox[:max] == [6750.0, 3700.0])
oy = op_plan[:items].find { |i| i[:ref] == 'op_00000003' }
ok('cửa trên tường theo Y (y:2:A-B từ y = 300): bắt đầu ở y = 300 + 550 = 850, tâm x = 4200, hộp bao x 4100..4300', oy.values_at(:along, :center, :dir) == [850.0, 4200.0, 'y'] && oy[:min] == [4100.0, 850.0] && oy[:max] == [4300.0, 1750.0])
ok('kế hoạch cửa theo thứ tự mã cửa của tầng; cửa sổ ở đáy 900', op_plan[:items].map { |i| i[:ref] } == %w[op_00000001 op_00000002 op_00000003] && op_plan[:items][1].values_at(:z_bottom, :z_top) == [900.0, 2100.0])

# Cửa sai: bỏ và báo
bad_plan = ->(openings, walls = {'x:B:2-3' => {}}, beams = {}) { S::WallPlan.plan(grid, types, bt, wt, mk(grid, types, bt, wt, ot, walls, openings, beams, cols), 'sl_00000001', ot) }
r = bad_plan.call({'op_00000001' => op('x:B:2-3', DOOR, 300)})
ok('cửa vượt đầu tường (tâm 300, rộng 900): bỏ và báo', r[:items][0][:openings].empty? && r[:opening_issues].first.include?('vượt ra ngoài'))
r = bad_plan.call({'op_00000001' => op('x:B:2-3', DOOR, 3700)})
ok('cửa vượt cuối tường: bỏ và báo', r[:items][0][:openings].empty? && r[:opening_issues].first.include?('vượt ra ngoài'))
r = bad_plan.call({'op_00000001' => op('x:B:2-3', DOOR, 450)})
ok('cửa vừa chạm đầu tường (tâm 450, rộng 900, x từ 0): hợp lệ', r[:items][0][:openings].size == 1 && r[:opening_issues].empty?)
r = bad_plan.call({'op_00000001' => op('x:B:2-3', DOOR, 1000), 'op_00000002' => op('x:B:2-3', DOOR, 1800)})
ok('hai cửa chồng nhau (x 550..1450 và 1350..2250): giữ cửa đầu, bỏ cửa sau và báo', r[:items][0][:openings].map { |o| o[:id] } == ['op_00000001'] && r[:opening_issues].first.include?('chồng hoặc sát'))
r = bad_plan.call({'op_00000001' => op('x:B:2-3', DOOR, 1000), 'op_00000002' => op('x:B:2-3', DOOR, 1960)})
ok('hai cửa cách nhau 60 mm (>= 50): cả hai hợp lệ; cách 40 mm thì bỏ', r[:items][0][:openings].size == 2 && bad_plan.call({'op_00000001' => op('x:B:2-3', DOOR, 1000), 'op_00000002' => op('x:B:2-3', DOOR, 1940)})[:items][0][:openings].size == 1)
tall = ot + [{'id' => 'ot_00000003', 'name' => 'Cao', 'kind' => 'window', 'w' => 900.0, 'h' => 3000.0, 'sill' => 900.0}]
lt = mk(grid, types, bt, wt, tall, {'x:B:2-3' => {}}, {'op_00000001' => op('x:B:2-3', 'ot_00000003', 2000)}, {}, cols)
rt = S::WallPlan.plan(grid, types, bt, wt, lt, 'sl_00000001', tall)
ok('cửa cao quá tường (900 + 3000 > 3480): bỏ và báo', rt[:items][0][:openings].empty? && rt[:opening_issues].first.include?('hơn tường'))
rb = bad_plan.call({'op_00000001' => op('x:B:2-3', DOOR, 1950)}, {'x:B:2-3' => {}}, {'x:B:2-3' => {}})
ok('tường dưới dầm (cao 3080): cửa đi cao 2100 vẫn lọt; cửa sổ cao ngưỡng 900 + cao 2400 thì không', rb[:items][0][:openings].size == 1 && rb[:opening_issues].empty?)
big_win = ot + [{'id' => 'ot_00000003', 'name' => 'Cao', 'kind' => 'window', 'w' => 900.0, 'h' => 2400.0, 'sill' => 900.0}]
lb = mk(grid, types, bt, wt, big_win, {'x:B:2-3' => {}}, {'op_00000001' => op('x:B:2-3', 'ot_00000003', 1950)}, {'x:B:2-3' => {}}, cols)
ok('đúng như trên: lọt tường 3480 nhưng không lọt tường dưới dầm 3080', S::WallPlan.plan(grid, types, bt, wt, lb, 'sl_00000001', big_win)[:opening_issues].first.include?('hơn tường') && S::WallPlan.plan(grid, types, bt, wt, mk(grid, types, bt, wt, big_win, {'x:B:2-3' => {}}, {'op_00000001' => op('x:B:2-3', 'ot_00000003', 1950)}, {}, cols), 'sl_00000001', big_win)[:opening_issues].empty?)
r = bad_plan.call({'op_00000001' => op('x:B:3-4', DOOR, 1950)}, {'x:B:2-3' => {}})
ok('cửa trên tường chưa được chọn: báo, không dựng', r[:opening_issues].first.include?('chưa được chọn'))
ok('tầng trên cùng không có cửa; tầng không tồn tại báo lỗi', error_of { S::OpeningPlan.plan(grid, types, bt, wt, ot, lv, 'sl_00000002') }.to_s.include?('tầng trên cùng') && !error_of { S::OpeningPlan.plan(grid, types, bt, wt, ot, lv, 'sl_deadbeef') }.nil?)
# Không có cửa: kế hoạch cũ không đổi
nl = mk(grid, types, bt, wt, ot, {'x:B:2-3' => {}}, {}, {}, cols)
ok('không có cửa: tường vẫn như trước (không lỗ), kế hoạch cửa rỗng', S::WallPlan.plan(grid, types, bt, wt, nl, 'sl_00000001', ot)[:items][0][:openings].empty? && S::OpeningPlan.plan(grid, types, bt, wt, ot, nl, 'sl_00000001')[:items].empty?)

# Sao chép cửa giữa tầng
three = L.normalize!([L.default[0].merge('picks' => {'walls' => {'x:B:2-3' => {}}, 'openings' => {'op_00000001' => op('x:B:2-3', DOOR, 1950)}}), L.default[1].merge('picks' => {'walls' => {'x:B:2-3' => {}}}), L.default[1].merge('id' => 'sl_00000003', 'name' => 'T3', 'elevation' => 7200.0)], grid, types, bt, wt, ot).first
cp = L.copy_picks(three, 'sl_00000001', 'sl_00000002', grid, types, 'openings', bt, wt, ot)
copied = cp[1]['picks']['openings']
ok('sao chép cửa: tầng đích có cửa giống (tường, loại, vị trí) nhưng MÃ CỬA MỚI', copied.size == 1 && copied.keys != ['op_00000001'] && copied.keys.first =~ /\Aop_[0-9a-f]{8}\z/ && copied.values.first == three[0]['picks']['openings']['op_00000001'] && cp[0]['picks']['openings'].keys == ['op_00000001'])
ok('sao chép cửa không đổi tường của tầng đích', cp[1]['picks']['walls'] == {'x:B:2-3' => {}})
puts $fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
