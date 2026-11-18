# Test sửa trong SketchUp thì dữ liệu cập nhật (cột mốc P7b, phần tính bản vá): dời, xoay, xóa từng loại phần tử, mở khóa phần tử theo lưới, cửa theo tường, chuẩn hóa lại.
# Chạy: ruby dev/test_model_edit.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/slab_plan core/ceiling_plan core/proposal core/checker core/model_edit core/state core/preview model_sync edit_sync model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder all_builder].each { |f| require File.join(ROOT, f) }
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
ME = S::ModelEdit
lvl = 'sl_00000001'
def mstate(cols: {}, beams: {}, walls: {}, openings: {}, slabs: {}, ceilings: {})
  st = S::State.default
  st['levels'][0]['picks'] = {'columns' => cols, 'beams' => beams, 'walls' => walls, 'openings' => openings, 'slabs' => slabs, 'ceilings' => ceilings}
  S::State.normalize!(st)
end
def chg(kind, ref, from, to, dangle = 0.0); {'kind' => kind, 'level' => 'sl_00000001', 'ref' => ref, 'from' => from, 'to' => to, 'dangle' => dangle}; end
# Áp bản vá vào dữ liệu rồi chuẩn hóa (giống cửa sổ áp bản vá vào dữ liệu của tầng).
def apply(st, patch)
  out = Marshal.load(Marshal.dump(st))
  picks = out['levels'].find { |l| l['id'] == patch['level'] }['picks']
  patch['remove'].each { |box, refs| refs.each { |r| picks[box].delete(r) } }
  patch['set'].each { |box, h| h.each { |r, pick| picks[box][r] = pick } }
  S::State.normalize!(out)
end
def plan_item(st, plural, ref); S::Checker.plan_for(plural, st, 'sl_00000001')[:items].find { |i| i[:ref] == ref }; end
W1 = 'fw_00000001'; W2 = 'fw_00000002'
ot = S::OpeningTypes.default

# ---- Cột ----
st = mstate(cols: {'1-A' => {}, '2-B' => {'type' => 'ct_00000001'}})
p1 = ME.move(st, chg('column', '2-B', [4200, 3600], [5200, 4100]))
new_id = p1['set']['columns'].keys.first
ok('dời cột theo lưới 2-B (+1000, +500): bỏ mã lưới, thêm cột tự do mã fc_ tại (5200, 4100), giữ loại, đổi mã 2-B -> mã mới', p1['remove'] == {'columns' => ['2-B']} && new_id.match?(/\Afc_[0-9a-f]{8}\z/) && p1['set']['columns'][new_id] == {'free' => {'x' => 5200.0, 'y' => 4100.0, 'rot' => 0}, 'type' => 'ct_00000001'} && p1['retag'] == {'2-B' => new_id} && p1['kinds'] == ['columns'])
st2 = apply(st, p1)
ok('áp bản vá rồi chuẩn hóa: dữ liệu hợp lệ, cột mới đúng chỗ, cột 1-A còn', st2['levels'][0]['picks']['columns'].size == 2 && plan_item(st2, 'columns', new_id)[:center] == [5200.0, 4100.0])
fst = mstate(cols: {'fc_0000000a' => {'free' => {'x' => 1000, 'y' => 1000, 'rot' => 0}}})
p2 = ME.move(fst, chg('column', 'fc_0000000a', [1000, 1000], [1000, 1000], 30))
ok('xoay cột tự do 30° quanh tâm: sửa tại chỗ (cùng mã, không đổi mã), góc 30', p2['set']['columns']['fc_0000000a']['free'] == {'x' => 1000.0, 'y' => 1000.0, 'rot' => 30} && p2['remove'].empty? && p2['retag'].empty?)
p3 = ME.move(fst, chg('column', 'fc_0000000a', [0, 0], [0, 0], 90))
ok('xoay 90° quanh gốc (0, 0): tâm (1000, 1000) sang (-1000, 1000), góc 90', p3['set']['columns']['fc_0000000a']['free'] == {'x' => -1000.0, 'y' => 1000.0, 'rot' => 90})
p4 = ME.move(fst, chg('column', 'fc_0000000a', [1000, 1000], [1000, 1000], -90))
ok('góc cộng dồn và đưa về 0..360 (0 - 90 = 270)', p4['set']['columns']['fc_0000000a']['free']['rot'] == 270)
ok('không dời không xoay: bỏ qua; dời dưới 0,05 mm bỏ qua', ME.move(fst, chg('column', 'fc_0000000a', [1000, 1000], [1000, 1000]))[:skip] && ME.move(fst, chg('column', 'fc_0000000a', [1000, 1000], [1000.03, 1000]))[:skip])
ok('phần tử không còn trong dữ liệu / tầng không còn: bỏ qua có lý do', ME.move(fst, chg('column', 'fc_ffffffff', [0, 0], [5, 5]))[:skip] && ME.move(fst, chg('column', 'fc_0000000a', [0, 0], [5, 5]).merge('level' => 'sl_xx'))[:skip])

# ---- Dầm, tường ----
bs = mstate(cols: {'1-A' => {}, '2-A' => {}}, beams: {'x:A:1-2' => {}})
bi = plan_item(bs, 'beams', 'x:A:1-2')
pb = ME.move(bs, chg('beam', 'x:A:1-2', [bi[:start], bi[:center]], [bi[:start], bi[:center] + 500]))
nb = pb['set']['beams'].values.first['free']
ok('dời dầm theo lưới (0, +500): thành dầm tự do, hai đầu đúng mặt cột cũ, dời 500 theo Y, cùng chiều dài', nb['a'][0] == bi[:start] && (nb['a'][1] - bi[:center] - 500).abs < 0.1 && (nb['b'][0] - bi[:finish]).abs < 0.1 && pb['retag'].keys == ['x:A:1-2'])
ws = mstate(walls: {W1 => {'free' => {'a' => [0, 0], 'b' => [4000, 0]}}, W2 => {'free' => {'a' => [0, 0], 'b' => [0, 3000]}}})
wi = plan_item(ws, 'walls', W1)
ok('(chuẩn bị) tường ngang bị nối góc dịch đầu -100', wi[:join_shift] == -100.0 && wi[:join_shift_end] == 0.0)
pw = ME.move(ws, chg('wall', W1, [wi[:start], wi[:center]], [wi[:start] + 500, wi[:center]]))
ok('dời tường đã nối góc (+500): dữ liệu lưu hai đầu CHƯA nối (500 và 4500, không phải 400) để nối góc không cộng dồn', pw['set']['walls'][W1]['free'] == {'a' => [500.0, 0.0], 'b' => [4500.0, 0.0]})
wd = mstate(cols: {'1-A' => {}, '2-A' => {}}, walls: {'x:B:1-2' => {}, 'x:B:2-3' => {}})
wdi = plan_item(wd, 'walls', 'x:B:1-2')
ok('tường theo lưới có nối góc ở đầu cuối (nút không cột): join_shift_end có trong kế hoạch (đầu cuối có thể dịch)', wdi.key?(:join_shift_end) || wdi[:join_shift].nil?)
op = {'op_00000001' => {'wall' => W1, 'type' => ot[0]['id'], 'pos' => 1500, 'flip' => false}}
wo = mstate(walls: {W1 => {'free' => {'a' => [0, 0], 'b' => [4000, 0]}}}, openings: op)
pwo = ME.move(wo, chg('wall', W1, [0, 0], [300, 200]))
ok('tường tự do có cửa dời (+300, +200): cửa đi theo (cùng tường, cùng vị trí), cần dựng lại cả cửa', pwo['set']['openings'] == {'op_00000001' => op['op_00000001']} && pwo['kinds'].sort == %w[openings walls] && pwo['set']['walls'][W1]['free'] == {'a' => [300.0, 200.0], 'b' => [4300.0, 200.0]})
pwr = ME.move(wo, chg('wall', W1, [2000, 0], [2000, 0], 180))
ok('xoay tường 180° quanh tâm: hai đầu đổi chỗ khi chuẩn hóa nên vị trí cửa tính lại (4000 - 1500 = 2500) và đổi mặt cánh', (wn = apply(wo, pwr)['levels'][0]['picks']['walls'][W1]['free']) && wn == {'a' => [0.0, 0.0], 'b' => [4000.0, 0.0]} && pwr['set']['openings']['op_00000001']['pos'] == 2500.0 && pwr['set']['openings']['op_00000001']['flip'] == true)
gw = mstate(cols: {}, walls: {'x:B:1-2' => {}}, openings: {'op_00000001' => {'wall' => 'x:B:1-2', 'type' => ot[0]['id'], 'pos' => 1000, 'flip' => false}})
gwi = plan_item(gw, 'walls', 'x:B:1-2')
pg = ME.move(gw, chg('wall', 'x:B:1-2', [0, 3600], [0, 4100]))
nw = pg['retag']['x:B:1-2']
ok('dời tường theo lưới có cửa: thành tường tự do mã mới, cửa chuyển sang mã tường mới', nw.to_s.start_with?('fw_') && pg['set']['openings']['op_00000001']['wall'] == nw && pg['remove'] == {'walls' => ['x:B:1-2']})
ok('áp bản vá tường lưới đã mở khóa: dữ liệu hợp lệ, cửa vẫn đặt được trên tường mới', (g2 = apply(gw, pg)) && S::WallPlan.plan(g2['grid'], g2['types'], g2['beam_types'], g2['wall_types'], g2['levels'], lvl, g2['opening_types'])[:items].first[:openings].size == 1)
sw = mstate(walls: {W1 => {'free' => {'a' => [0, 0], 'b' => [3000, 4000]}}})
psw = ME.move(sw, chg('wall', W1, [0, 0], [0, 0], 90))
ok('xoay tường xiên 90° quanh đầu a: đầu b (3000, 4000) sang (-4000, 3000), chuẩn hóa a ở bên trái', psw['set']['walls'][W1]['free'] == {'a' => [0.0, 0.0], 'b' => [-4000.0, 3000.0]} && (apply(sw, psw)['levels'][0]['picks']['walls'][W1]['free']['a'] == [-4000.0, 3000.0]))
ok('cờ tắt nối góc (join false) giữ khi mở khóa / dời', ME.move(mstate(walls: {'x:B:1-2' => {'join' => false}}), chg('wall', 'x:B:1-2', [0, 3600], [0, 3700]))['set']['walls'].values.first['join'] == false)

# ---- Cửa ----
po = ME.move(wo, chg('opening', 'op_00000001', [1050, 0], [1550, 20]))
ok('dời cửa dọc tường (+500) và lệch 20 mm khỏi tim: vị trí +500, chỉ cửa và tường cần dựng lại', po['set']['openings']['op_00000001']['pos'] == 2000.0 && po['kinds'] == %w[openings walls])
ok('cửa bị kéo lệch khỏi tường quá 100 mm: bỏ qua', ME.move(wo, chg('opening', 'op_00000001', [1050, 0], [1050, 500]))[:skip].to_s.include?('ra khỏi tường'))
ok('cửa chỉ dời vuông góc nhỏ (không dọc tường): bỏ qua', ME.move(wo, chg('opening', 'op_00000001', [1050, 0], [1050, 30]))[:skip])
ow = mstate(walls: {W1 => {'free' => {'a' => [0, 0], 'b' => [3000, 4000]}}}, openings: {'op_00000001' => {'wall' => W1, 'type' => ot[0]['id'], 'pos' => 1000, 'flip' => false}})
po2 = ME.move(ow, chg('opening', 'op_00000001', [0, 0], [300, 400]))
ok('cửa trên tường xiên dời (300, 400) dọc tường (dài 500): vị trí +500', po2['set']['openings']['op_00000001']['pos'] == 1500.0)

# ---- Sàn, trần ----
ss = mstate(slabs: {'1-2/A-B' => {}}, ceilings: {'1-2/A-B' => {}})
psl = ME.move(ss, chg('slab', '1-2/A-B', [0, 0], [1000, 500]))
sid = psl['set']['slabs'].keys.first
ok('dời sàn theo ô (+1000, +500): thành sàn đa giác fs_ dời đúng (đỉnh (1000, 500)), bỏ mã ô', sid.start_with?('fs_') && psl['set']['slabs'][sid]['free']['poly'].first == [1000.0, 500.0] && psl['remove'] == {'slabs' => ['1-2/A-B']} && apply(ss, psl)['levels'][0]['picks']['slabs'].keys == [sid])
pce = ME.move(ss, chg('ceiling', '1-2/A-B', [0, 0], [200, 0]))
ok('dời trần theo ô: thành trần đa giác fk_', pce['set']['ceilings'].keys.first.start_with?('fk_'))
fp = mstate(slabs: {'fs_0000000a' => {'free' => {'poly' => [[0, 0], [4000, 0], [4000, 3000], [0, 3000]], 'holes' => [[[1000, 1000], [2000, 1000], [2000, 2000], [1000, 2000]]]}}})
pfs = ME.move(fp, chg('slab', 'fs_0000000a', [0, 0], [100, 100]))
ok('dời sàn đa giác có lỗ: đường bao và lỗ cùng dời, giữ mã', pfs['set']['slabs']['fs_0000000a']['free']['poly'][0] == [100.0, 100.0] && pfs['set']['slabs']['fs_0000000a']['free']['holes'][0][0] == [1100.0, 1100.0] && pfs['retag'].empty?)
prs = ME.move(fp, chg('slab', 'fs_0000000a', [0, 0], [0, 0], 90))
ok('xoay sàn đa giác 90° quanh gốc: dữ liệu sau chuẩn hóa vẫn hợp lệ (ngược chiều kim đồng hồ)', apply(fp, prs)['levels'][0]['picks']['slabs']['fs_0000000a']['free']['poly'].size == 4)

# ---- Xóa ----
ok('xóa cột: bỏ khỏi dữ liệu, dựng lại nhóm cột', ME.erase(st, chg('column', '2-B', [0, 0], [0, 0])) == {'level' => lvl, 'set' => {}, 'remove' => {'columns' => ['2-B']}, 'retag' => {}, 'kinds' => ['columns']})
pe = ME.erase(wo, chg('wall', W1, [0, 0], [0, 0]))
ok('xóa tường: bỏ cả cửa trên tường đó, dựng lại tường và cửa', pe['remove'] == {'walls' => [W1], 'openings' => ['op_00000001']} && pe['kinds'] == %w[walls openings])
ok('xóa phần tử không còn trong dữ liệu hoặc tầng không còn: bỏ qua', ME.erase(wo, chg('column', '9-Z', [0, 0], [0, 0]))[:skip] && ME.erase(wo, chg('column', '1-A', [0, 0], [0, 0]).merge('level' => 'sl_xx'))[:skip])
ok('xóa sàn, trần, cửa, dầm đều cho bản vá đúng loại', ME.erase(ss, chg('slab', '1-2/A-B', [0, 0], [0, 0]))['remove'] == {'slabs' => ['1-2/A-B']} && ME.erase(ss, chg('ceiling', '1-2/A-B', [0, 0], [0, 0]))['remove'] == {'ceilings' => ['1-2/A-B']} && ME.erase(wo, chg('opening', 'op_00000001', [0, 0], [0, 0]))['remove'] == {'openings' => ['op_00000001']} && ME.erase(bs, chg('beam', 'x:A:1-2', [0, 0], [0, 0]))['remove'] == {'beams' => ['x:A:1-2']})
ok('mã mới do ModelEdit sinh luôn hợp lệ với Levels (qua chuẩn hóa) cho cả năm loại', %w[column beam wall slab ceiling].all? { |k| id = ME.id_for(k); id.match?(S::Levels::FREE_ID.values.find { |r| r.match?(id) } || S::Levels::PLATE_ID.values.find { |r| r.match?(id) } || /x\A/) })
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
