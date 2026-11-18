# Test sàn / trần ĐA GIÁC tự do (cột mốc P4b-3): dữ liệu, kiểm tra hình, kế hoạch, chồng nhau, dựng bằng SketchUp giả lập (có lỗ).
# Chạy: ruby dev/test_polygon.rb (phần dựng thật chưa xác minh trong SketchUp)
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/layer_list core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/slab_plan core/ceiling_plan core/proposal core/checker core/model_edit core/state core/preview model_sync edit_sync model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder all_builder].each { |f| require File.join(ROOT, f) }
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
FS1 = 'fs_0000000a'; FS2 = 'fs_0000000b'; FK1 = 'fk_0000000a'; FK2 = 'fk_0000000b'
lvl = 'sl_00000001'
L_SHAPE = [[0, 0], [6000, 0], [6000, 2000], [2000, 2000], [2000, 5000], [0, 5000]]
SQUARE = [[1000, 1000], [3000, 1000], [3000, 3000], [1000, 3000]]
def poly_state(slabs: {}, ceilings: {}, **rest)
  state_with(slabs: slabs, ceilings: ceilings, **rest)
end
def free(poly, holes = []); {'free' => {'poly' => poly, 'holes' => holes}}; end

# ---- Dữ liệu ----
st = poly_state(slabs: {FS1 => free(L_SHAPE.reverse)})
f = lv(st)[0]['picks']['slabs'][FS1]['free']
ok('đa giác theo chiều kim đồng hồ được đảo thành ngược chiều kim đồng hồ', S::Geometry.area2(f['poly']) > 0 && f['poly'].size == 6)
ok('đỉnh lặp liền kề và điểm đóng vòng bị bỏ', lv(poly_state(slabs: {FS1 => free(SQUARE + [SQUARE[0], SQUARE[0]])}))[0]['picks']['slabs'][FS1]['free']['poly'].size == 4)
bad = {
  'ít hơn 3 đỉnh' => free([[0, 0], [1000, 0]]), 'tự cắt (hình nơ)' => free([[0, 0], [2000, 2000], [2000, 0], [0, 2000]]), 'diện tích bằng 0' => free([[0, 0], [1000, 0], [2000, 0]]),
  'tọa độ không phải số' => free([[0, 0], ['a', 0], [0, 1000]]), 'lỗ chạm cạnh ngoài' => free(SQUARE, [[[1000, 1500], [1500, 1500], [1500, 2000], [1000, 2000]]]),
  'lỗ ngoài đường bao' => free(SQUARE, [[[5000, 5000], [6000, 5000], [6000, 6000], [5000, 6000]]]),
  'hai lỗ chồng nhau' => free(SQUARE, [[[1500, 1500], [2200, 1500], [2200, 2200], [1500, 2200]], [[2000, 2000], [2800, 2000], [2800, 2800], [2000, 2800]]]),
  'lỗ chứa lỗ' => free(SQUARE, [[[1300, 1300], [2700, 1300], [2700, 2700], [1300, 2700]], [[1600, 1600], [2000, 1600], [2000, 2000], [1600, 2000]]]),
  'dữ liệu thiếu poly' => {'free' => {}}
}
bad.each { |name, pick| ok("sàn đa giác sai bị từ chối: #{name}", error_of { poly_state(slabs: {FS1 => pick}) }) }
ok('mã sàn đa giác sai bị từ chối', error_of { poly_state(slabs: {'xx_00000001' => free(SQUARE)}) } && error_of { poly_state(ceilings: {FS1 => free(SQUARE)}) })
ok('quá nhiều đỉnh bị từ chối', error_of { poly_state(slabs: {FS1 => free((0...250).map { |i| [Math.cos(i * 0.025) * 5000, Math.sin(i * 0.025) * 5000] })}) })
ok('lỗ hợp lệ được giữ (một lỗ vuông trong sàn vuông)', lv(poly_state(slabs: {FS1 => free([[0, 0], [5000, 0], [5000, 5000], [0, 5000]], [[[1000, 1000], [2000, 1000], [2000, 2000], [1000, 2000]]])}))[0]['picks']['slabs'][FS1]['free']['holes'].size == 1)

ok('điểm nằm đúng trên cạnh đa giác không tính là nằm trong; điểm bên trong thì có', !S::Geometry.inside_ring?([1500, 1000], SQUARE) && S::Geometry.inside_ring?([2000, 2000], SQUARE) && !S::Geometry.inside_ring?([1000, 1000], SQUARE))

# ---- Kế hoạch sàn ----
sp = poly_state(slabs: {FS1 => free([[0, 0], [5000, 0], [5000, 5000], [0, 5000]], [[[1000, 1000], [2000, 1000], [2000, 2000], [1000, 2000]]]), '1-2/A-B' => {}})
plan = S::SlabPlan.plan(sp['grid'], sp['levels'], lvl)
item = plan[:items].find { |i| i[:ref] == FS1 }
ok('sàn đa giác: diện tích đã trừ lỗ (25 - 1 = 24 m2), hộp bao, placement free', item[:area] == 24.0 && item[:min] == [0.0, 0.0] && item[:max] == [5000.0, 5000.0] && item[:placement] == 'free' && item[:holes].size == 1)
ok('sàn đa giác trộn với sàn theo ô: cả hai có mặt, ô vẫn đúng', plan[:items].size == 2 && plan[:items].any? { |i| i[:ref] == '1-2/A-B' && i[:placement].nil? })
ok('sàn đa giác chồng lên sàn theo ô: chỉ cảnh báo, không lỗi', plan[:issues].any? { |m| m.include?(FS1) && m.include?('1-2/A-B') })
sl = poly_state(slabs: {FS1 => free(L_SHAPE), FS2 => free([[10000, 0], [12000, 0], [12000, 2000], [10000, 2000]])})
ok('hai sàn đa giác cách xa nhau: không cảnh báo chồng', S::SlabPlan.plan(sl['grid'], sl['levels'], lvl)[:issues].empty?)
sl2 = poly_state(slabs: {FS1 => free(L_SHAPE), FS2 => free([[1000, 1000], [3000, 1000], [3000, 3000], [1000, 3000]])})
ok('hai sàn đa giác chồng nhau thật (đỉnh nằm trong sàn kia): cảnh báo', S::SlabPlan.plan(sl2['grid'], sl2['levels'], lvl)[:issues].size == 1)
sl3 = poly_state(slabs: {FS1 => free(L_SHAPE), FS2 => free([[1000, 2500], [1800, 2500], [1800, 4500], [1000, 4500]])})
ok('sàn chữ L và hình chữ nhật nằm trong nhánh đứng (không chạm phần khuyết): vẫn là chồng', S::SlabPlan.plan(sl3['grid'], sl3['levels'], lvl)[:issues].size == 1)
sl4 = poly_state(slabs: {FS1 => free(L_SHAPE), FS2 => free([[2500, 2500], [5000, 2500], [5000, 4500], [2500, 4500]])})
ok('hình đặt vào chỗ khuyết của chữ L: KHÔNG báo chồng (so theo miền thật, không theo hộp bao)', S::SlabPlan.plan(sl4['grid'], sl4['levels'], lvl)[:issues].empty?)
sl5 = poly_state(slabs: {FS1 => free([[0, 0], [8000, 0], [8000, 8000], [0, 8000]], [[[2000, 2000], [6000, 2000], [6000, 6000], [2000, 6000]]]), FS2 => free([[3000, 3000], [5000, 3000], [5000, 5000], [3000, 5000]])})
ok('hình nằm trọn trong lỗ của sàn khác: không chồng', S::SlabPlan.plan(sl5['grid'], sl5['levels'], lvl)[:issues].empty?)

# ---- Kế hoạch trần ----
cp = poly_state(ceilings: {FK1 => free(L_SHAPE, [[[500, 500], [1500, 500], [1500, 1500], [500, 1500]]])})
cpl = S::CeilingPlan.plan(cp['grid'], cp['types'], cp['beam_types'], cp['wall_types'], cp['levels'], lvl, cp['opening_types'])
ci = cpl[:items].find { |i| i[:ref] == FK1 }
ok('trần đa giác: cao độ, dày, diện tích (chữ L 18 m2 trừ lỗ 1 m2 = 17 m2)', ci && ci[:area] == 17.0 && ci[:z_bottom] == cpl[:z_bottom] && ci[:thickness] == cp['levels'][0]['ceiling_thickness'] && ci[:placement] == 'free')
cw = poly_state(ceilings: {FK1 => free([[0, 0], [5000, 0], [5000, 5000], [0, 5000]])}, walls: {FW = 'fw_0000000c' => {'free' => {'a' => [1000, 1000], 'b' => [4000, 1000]}}})
cwp = S::CeilingPlan.plan(cw['grid'], cw['types'], cw['beam_types'], cw['wall_types'], cw['levels'], lvl, cw['opening_types'])
ok('trần đa giác chồng lên tường: cảnh báo trần không lùi theo tường', cwp[:issues].any? { |m| m.include?('chồng lên tường') })
mix = poly_state(ceilings: {FK1 => free([[20000, 0], [22000, 0], [22000, 2000], [20000, 2000]]), '1-2/A-B' => {}})
ok('trần đa giác trộn với trần theo ô', S::CeilingPlan.plan(mix['grid'], mix['types'], mix['beam_types'], mix['wall_types'], mix['levels'], lvl, mix['opening_types'])[:items].size == 2)

# ---- Sao chép, kiểm tra, xem trước, đề xuất ----
st = poly_state(slabs: {FS1 => free(L_SHAPE), '1-2/A-B' => {}}, ceilings: {FK1 => free(SQUARE)})
cop = L.copy_picks(lv(st), 'sl_00000001', 'sl_00000002', st['grid'], st['types'], 'slabs', st['beam_types'], st['wall_types'], st['opening_types'])
ok('sao chép sàn sang tầng khác: kèm sàn đa giác (bản sao độc lập)', cop[1]['picks']['slabs'][FS1]['free']['poly'].size == 6 && !cop[1]['picks']['slabs'][FS1]['free'].equal?(cop[0]['picks']['slabs'][FS1]['free']))
ck = S::Checker.run(st)
ok('kiểm tra kết cấu đếm cả sàn và trần đa giác (2 sàn, 1 trần)', ck[:levels][0][:counts]['slabs'] == 2 && ck[:levels][0][:counts]['ceilings'] == 1 && ck[:errors] == 0)
pv = S::Preview.build(st.merge('level' => lvl).reject { |k, _| k == 'removed' })
ok('xem trước giao diện có polygon, holes, placement của sàn và trần đa giác', pv[:slabs][:items].any? { |i| i[:placement] == 'free' && i[:polygon].size == 6 && i[:holes] == [] } && pv[:ceilings][:items].any? { |i| i[:placement] == 'free' })
pr, = S::Proposal.propose(st['grid'], lv(st), [lvl])
ok('đề xuất bán tự động không đụng sàn / trần đa giác', pr[0]['picks']['slabs'][FS1] == lv(st)[0]['picks']['slabs'][FS1] && pr[0]['picks']['ceilings'][FK1] == lv(st)[0]['picks']['ceilings'][FK1])

# ---- Vân tay ----
fps = ->(item) { S::ModelSync.fingerprint('slab', item) }
base = S::SlabPlan.plan(sp['grid'], sp['levels'], lvl)[:items].find { |i| i[:ref] == FS1 }
ok('vân tay sàn đa giác đổi khi đổi lỗ hoặc đỉnh', fps.call(base) != fps.call(base.merge(holes: [])) && fps.call(base) != fps.call(base.merge(polygon: base[:polygon].reverse.rotate)))
ok('vân tay sàn theo ô không đổi so với bản trước', S::ModelSync.fingerprint('slab', {min: [0, 0], max: [1, 1], thickness: 100, z_top: 0, z_bottom: -100}) == begin require 'digest'; Digest::SHA1.hexdigest(JSON.generate([[:min, [0, 0]], [:max, [1, 1]], [:thickness, 100], [:z_top, 0], [:z_bottom, -100]]))[0, 12] end)

# ---- Dựng ----
m = Sketchup::Model.new
S::AllBuilder.build(m, sp, [lvl])
grp = m.entities.grep(Sketchup::Group).find { |g| g.get_attribute(D, 'kind') == 'slabs' }
inst = grp.entities.grep(Sketchup::Instance).find { |i| i.get_attribute('VGD_BIM_SOURCE', 'ref') == "#{lvl}:#{FS1}" }
ok('dựng sàn đa giác có lỗ: một thể hiện, gốc ở góc nhỏ của hộp bao, diện tích 24 m2 ghi cho BIM', inst && (inst.transformation.vector.x * MM).round(2) == 0.0 && JSON.parse(inst.get_attribute(D, 'dims'))['area'] == 24.0)
faces = inst.definition.entities.grep(Sketchup::Face)
ok('định nghĩa sàn có lỗ: 1 mặt ngoài còn, 1 mặt trong lỗ đã bị xóa; tên ngắn theo mã băm', inst.definition.name =~ /VGD .* [0-9a-f]{12}\z/ && faces.count { |fc| !fc.erased } >= 1 && faces.count(&:erased) == 1)
stt = S::ModelSync.status(m, sp, lvl)
ok('trạng thái model: sàn đa giác vừa dựng là "ok"', stt[:items]["slab|#{FS1}"] == 'ok' && stt[:items]['slab|1-2/A-B'] == 'ok')
m2 = Sketchup::Model.new
S::AllBuilder.build(m2, cp, [lvl])
cg = m2.entities.grep(Sketchup::Group).find { |g| g.get_attribute(D, 'kind') == 'ceilings' }
ok('dựng trần đa giác: có thể hiện cho mã fk_', cg.entities.grep(Sketchup::Instance).any? { |i| i.get_attribute('VGD_BIM_SOURCE', 'ref') == "#{lvl}:#{FK1}" })
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
