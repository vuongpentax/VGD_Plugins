# Test nối góc tường (cột mốc 9): góc L, góc T, nhiều tường gặp nhau, tường xiên, tắt nối, cửa giữ đúng chỗ, dựng bằng SketchUp giả lập.
# Chạy: ruby dev/test_joins.rb (phần dựng thật chưa xác minh trong SketchUp)
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/slab_plan core/ceiling_plan core/proposal core/checker core/state core/preview model_sync model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder all_builder].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
L = S::Levels
D = S::Schema::DICTIONARY
MM = 25.4
grid = S::Grid.default
types = S::ColumnTypes.default
bt = S::BeamTypes.default
wt = S::WallTypes.default
ot = S::OpeningTypes.default
def deep(x); Marshal.load(Marshal.dump(x)); end
def state_with(cols: {}, beams: {}, walls: {}, openings: {}, slabs: {}, ceilings: {})
  st = S::State.default
  st['levels'][0]['picks'] = {'columns' => cols, 'beams' => beams, 'walls' => walls, 'openings' => openings, 'slabs' => slabs, 'ceilings' => ceilings}
  S::State.normalize!(st)
end
def lv(st); st['levels']; end

FC1 = 'fc_0000000a'; FB1 = 'fb_0000000b'; FW1 = 'fw_0000000c'; FW2 = 'fw_0000000d'; FB2 = 'fb_0000000e'
lvl = 'sl_00000001'
def fw(a, b, extra = {}); {'free' => {'a' => a, 'b' => b}}.merge(extra); end
def wplan(walls = {}, openings: {}, cols: {}, **extra)
  walls = walls.merge(extra)
  st = state_with(walls: walls, openings: openings, cols: cols)
  p = S::WallPlan.plan(st['grid'], st['types'], st['beam_types'], st['wall_types'], st['levels'], 'sl_00000001', st['opening_types'])
  [st, p, ->(ref) { p[:items].find { |i| i[:ref] == ref } }]
end
W1 = 'fw_00000001'; W2 = 'fw_00000002'; W3 = 'fw_00000003'; W4 = 'fw_00000004'

# ---- Góc L vuông ----
st, pl, w = wplan(W1 => fw([0, 0], [4000, 0]), W2 => fw([0, 0], [0, 3000]))
x = w.call(W1); y = w.call(W2)
ok('góc L vuông (tường 200): tường ngang chạy suốt tới mặt ngoài (start -100), tường dọc dừng ở mặt tường ngang (start 100)', x[:start] == -100.0 && x[:finish] == 4000.0 && y[:start] == 100.0 && y[:finish] == 3000.0)
ok('chiều dài, hộp bao khớp: ngang dài 4100, dọc dài 2900', x[:length] == 4100.0 && x[:min][0] == -100.0 && y[:length] == 2900.0 && y[:min][1] == 100.0)
ok('ghi lại đầu đã nối và mức dịch đầu (ngang -100, dọc +100)', x[:joined] == [:start] && x[:join_shift] == -100.0 && y[:joined] == [:start] && y[:join_shift] == 100.0)
ok('sau nối: không còn cảnh báo chồng nhau', pl[:issues].none? { |m| m.include?('chồng') })
st0, pl0, w0 = wplan(W1 => fw([0, 0], [4000, 0], 'join' => false), W2 => fw([0, 0], [0, 3000], 'join' => false))
ok('cả hai tắt nối: giữ nguyên hình cũ (đầu đúng tọa độ nhập) và báo chồng như trước', w0.call(W1)[:start] == 0.0 && w0.call(W2)[:start] == 0.0 && pl0[:issues].any? { |m| m.include?('chồng') } && w0.call(W1)[:joined].nil?)
st1, pl1, w1 = wplan(W1 => fw([0, 0], [4000, 0]), W2 => fw([0, 0], [0, 3000], 'join' => false))
ok('chỉ tắt nối ở tường dọc: tường dọc không đổi và không làm đối tác, tường ngang không bị kéo', w1.call(W1)[:start] == 0.0 && w1.call(W2)[:start] == 0.0)
ok('tường đã tắt nối có join = false trong mục kế hoạch, mặc định true', w1.call(W2)[:join] == false && w.call(W1)[:join] == true)

# ---- Thứ tự tạo / quy tắc chạy suốt ----
st, pl, w = wplan(W1 => fw([0, 0], [0, 3000]), W2 => fw([0, 0], [4000, 0]))
ok('quy tắc tường chạy suốt không phụ thuộc thứ tự mã: vẫn là tường ngang chạy suốt', w.call(W2)[:start] == -100.0 && w.call(W1)[:start] == 100.0)
st, pl, w = wplan(W1 => fw([0, 0], [3000, 4000]), W2 => fw([0, 0], [1000, -500]))
ok('hai tường xiên: tường DÀI hơn chạy suốt (mặt ngoài), tường ngắn dừng ở mặt', w.call(W1)[:joined] == [:start] && w.call(W1)[:join_shift] < 0 && w.call(W2)[:join_shift] > 0)
r = w.call(W1); b = w.call(W2)
d_axis = ->(pt, a, bb) { ux = bb[0] - a[0]; uy = bb[1] - a[1]; l = Math.hypot(ux, uy); ((pt[0] - a[0]) * -uy + (pt[1] - a[1]) * ux).abs / l }
ok('đầu tường dừng nằm đúng mặt tường chạy suốt (cách trục 100 mm)', (d_axis.call(b[:a], r[:a], r[:b]) - 100.0).abs < 0.5)

# ---- Góc T và nhiều tường ----
st, pl, w = wplan(W1 => fw([0, 0], [4000, 0]), W2 => fw([2000, 0], [2000, 3000]))
ok('góc T: đầu tường dọc chạm thân tường ngang thì dừng ở mặt (start 100), tường ngang không đổi', w.call(W2)[:start] == 100.0 && w.call(W1)[:start] == 0.0 && w.call(W1)[:finish] == 4000.0 && w.call(W1)[:joined].nil?)
st, pl, w = wplan(W1 => fw([0, 0], [2000, 0]), W2 => fw([2000, 0], [4000, 0]), W3 => fw([2000, -3000], [2000, 0]), W4 => fw([2000, 0], [2000, 3000]))
ok('chữ thập (hai tường ngang nối tiếp + hai tường dọc): tường ngang giữ nguyên, hai tường dọc dừng ở mặt', w.call(W1)[:finish] == 2000.0 && w.call(W2)[:start] == 2000.0 && w.call(W3)[:finish] == -100.0 && w.call(W4)[:start] == 100.0)
st, pl, w = wplan(W1 => fw([0, 0], [2000, 0]), W2 => fw([2000, 0], [4000, 0]))
ok('hai tường nối tiếp thẳng hàng: không đổi', w.call(W1)[:finish] == 2000.0 && w.call(W2)[:start] == 2000.0)
st, pl, w = wplan(W1 => fw([0, 0], [2000, 0]), W2 => fw([2000, 0], [2000, 3000]), W3 => fw([2000, 0], [4000, 500]))
ok('ba tường gặp nhau mà không có cặp thẳng hàng: không nối (tránh đoán sai)', w.call(W2)[:start] == 0.0 && w.call(W1)[:finish] == 2000.0)
st, pl, w = wplan(W1 => fw([0, 0], [4000, 0]), W2 => fw([0, 300], [0, 3000]))
ok('đầu cách tường kia 300 mm (hở lớn): không nối', w.call(W2)[:start] == 300.0 && w.call(W1)[:start] == 0.0)
st, pl, w = wplan(W1 => fw([0, 0], [4000, 0]), W2 => fw([0, 100], [0, 3000]))
ok('đầu cách 100 mm (trong phạm vi dung sai theo bề dày): vẫn nối khít', w.call(W2)[:start] == 100.0 && w.call(W1)[:start] == -100.0)

# ---- Cột ----
st, pl, w = wplan({W1 => fw([150, 0], [4000, 0]), W2 => fw([0, 0], [0, 3000])}, cols: {'1-A' => {}})
ok('đầu tường đã chạm mặt cột (cột 300 tại 1-A: mặt tại x = 300) thì không nối thêm', (cc = S::ColumnPlan.plan(st['grid'], st['types'], st['levels'], lvl)[:items].first) && w.call(W1)[:start] == 150.0)

# ---- Lưới ----
gst = state_with(cols: {}, walls: {'x:B:1-2' => {}, 'x:B:2-3' => {}, 'y:2:A-B' => {}, 'y:2:B-C' => {}})
gp = S::WallPlan.plan(gst['grid'], gst['types'], gst['beam_types'], gst['wall_types'], gst['levels'], lvl, gst['opening_types'])
g = ->(ref) { gp[:items].find { |i| i[:ref] == ref } }
ok('lưới, nút không có cột, bốn tường gặp nhau (chữ thập): giữ nguyên như trước (X tới trục, Y dừng ở mặt X)', g.call('x:B:1-2')[:finish] == 4200.0 && g.call('x:B:2-3')[:start] == 4200.0 && g.call('y:2:A-B')[:finish] == 3500.0 && g.call('y:2:B-C')[:start] == 3700.0)
gl = state_with(cols: {}, walls: {'x:A:1-2' => {'p' => 'center'}, 'y:1:A-B' => {'p' => 'center'}})
glp = S::WallPlan.plan(gl['grid'], gl['types'], gl['beam_types'], gl['wall_types'], gl['levels'], lvl, gl['opening_types'])
gx = glp[:items].find { |i| i[:ref] == 'x:A:1-2' }; gy = glp[:items].find { |i| i[:ref] == 'y:1:A-B' }
ok('lưới, góc L ở nút 1-A không có cột (tường tâm trên trục): X chạy suốt ra mặt ngoài, Y dừng ở mặt X (không còn khuyết góc)', gx[:start] == -100.0 && gy[:start] == 100.0)

# ---- Cửa giữ đúng chỗ ----
op = {'op_00000001' => {'wall' => W1, 'type' => ot[0]['id'], 'pos' => 1000, 'flip' => false}}
st, pl, w = wplan({W1 => fw([0, 0], [4000, 0]), W2 => fw([0, 0], [0, 3000])}, openings: op)
oplan = S::OpeningPlan.plan(st['grid'], st['types'], st['beam_types'], st['wall_types'], st['opening_types'], st['levels'], lvl)
oi = oplan[:items].first
ok('đầu tường ngang dịch -100: cửa vẫn đứng đúng chỗ thật (tâm cách điểm đầu nhập 1000, nghĩa là mép trái tại 1000 - rộng/2)', (oi[:min][0] - (1000 - ot[0]['w'] / 2.0)).abs < 0.02)
op2 = {'op_00000001' => {'wall' => W2, 'type' => ot[0]['id'], 'pos' => 200, 'flip' => false}}
st, pl, w = wplan({W1 => fw([0, 0], [4000, 0]), W2 => fw([0, 0], [0, 3000])}, openings: op2)
ok('cửa nằm trong đoạn tường bị rút ngắn do nối góc: bị bỏ kèm cảnh báo (không dựng cửa lơ lửng ngoài tường)', pl[:opening_issues].any? { |m| m.include?('vượt ra ngoài') } && w.call(W2)[:openings].empty?)
sx = {W1 => fw([0, 0], [0, 3000]), W2 => fw([0, 0], [3000, 4000])}
op3 = {'op_00000001' => {'wall' => W2, 'type' => ot[0]['id'], 'pos' => 2500, 'flip' => false}}
st, pl, w = wplan(sx, openings: op3)
o3 = S::OpeningPlan.plan(st['grid'], st['types'], st['beam_types'], st['wall_types'], st['opening_types'], st['levels'], lvl)[:items].first
ok('tường xiên dịch đầu: cửa trên tường xiên vẫn đứng đúng chỗ (gốc cửa cách điểm đầu nhập pos - rộng/2 dọc tường)', (Math.hypot(o3[:origin][0], o3[:origin][1]) - (2500 - ot[0]['w'] / 2.0)).abs < 0.05)

# ---- Dữ liệu ----
ok('khóa join: chỉ nhận true / false, true bị bỏ (mặc định), false được giữ', error_of { state_with(walls: {W1 => fw([0, 0], [4000, 0], 'join' => 'no')}) } && !lv(state_with(walls: {W1 => fw([0, 0], [4000, 0], 'join' => true)}))[0]['picks']['walls'][W1].key?('join') && lv(state_with(walls: {W1 => fw([0, 0], [4000, 0], 'join' => false)}))[0]['picks']['walls'][W1]['join'] == false)
ok('join áp cho tường theo lưới cũng được lưu', lv(state_with(walls: {'x:B:1-2' => {'join' => false}}))[0]['picks']['walls']['x:B:1-2']['join'] == false)
ok('join không áp cho dầm (bị bỏ qua khi chuẩn hóa)', !lv(state_with(beams: {'x:B:1-2' => {'join' => false}}))[0]['picks']['beams']['x:B:1-2'].key?('join'))
m = Sketchup::Model.new
saved = S::ModelStore.write(m, state_with(walls: {W1 => fw([0, 0], [4000, 0], 'join' => false)}))
ok('lưu rồi nạp lại giữ cờ tắt nối', S::ModelStore.read(m)['levels'][0]['picks']['walls'][W1]['join'] == false)

# ---- Dựng ----
st, pl, w = wplan(W1 => fw([0, 0], [4000, 0]), W2 => fw([0, 0], [0, 3000]))
mb = Sketchup::Model.new
S::WallBuilder.build(mb, st, [lvl])
grp = mb.entities.grep(Sketchup::Group).find { |gg| gg.get_attribute(D, 'kind') == 'walls' }
ix = grp.entities.grep(Sketchup::Instance).find { |i| i.get_attribute('VGD_BIM_SOURCE', 'ref') == "#{lvl}:#{W1}" }
iy = grp.entities.grep(Sketchup::Instance).find { |i| i.get_attribute('VGD_BIM_SOURCE', 'ref') == "#{lvl}:#{W2}" }
ok('dựng: tường ngang đặt tại x = -100, dài 4100; tường dọc đặt tại y = 100, dài 2900', (ix.transformation.vector.x * MM).round(2) == -100.0 && (iy.transformation.vector.y * MM).round(2) == 100.0 && JSON.parse(ix.get_attribute(D, 'dims'))['length'] == 4100.0 && JSON.parse(iy.get_attribute(D, 'dims'))['length'] == 2900.0)
ok('trạng thái model: tường đã nối vừa dựng là "ok"', S::ModelSync.status(mb, st, lvl)[:items]["wall|#{W1}"] == 'ok')
stoff = state_with(walls: {W1 => fw([0, 0], [4000, 0], 'join' => false), W2 => fw([0, 0], [0, 3000], 'join' => false)})
ok('tắt nối sau khi đã dựng: trạng thái báo lệch (cần dựng lại)', S::ModelSync.status(mb, stoff, lvl)[:items]["wall|#{W1}"] == 'stale')
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
