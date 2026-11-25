# Test phần tử TỰ DO XIÊN (cột mốc P4b-2): cột xoay góc bất kỳ, dầm / tường xiên, cửa trên tường xiên: dữ liệu, kế hoạch, chồng nhau, dựng bằng SketchUp giả lập.
# Chạy: ruby dev/test_oblique.rb (phần dựng thật chưa xác minh trong SketchUp)
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/stair_types core/stair_plan core/stair_place core/layer_list core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/room_plan core/slab_plan core/ceiling_plan core/proposal core/checker core/model_edit core/state core/preview model_sync edit_sync model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder stair_builder all_builder].each { |f| require File.join(ROOT, f) }
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

# ---- Dữ liệu ----
c = lv(state_with(cols: {FC1 => {'free' => {'x' => 1000, 'y' => 1000, 'rot' => 30.004}}, 'fc_00000011' => {'free' => {'x' => 5000, 'y' => 1000, 'rot' => -90}}}))[0]['picks']['columns']
ok('cột xoay: góc làm tròn 0,01 độ, góc âm đưa về 0..360 (-90 -> 270)', c[FC1]['free']['rot'] == 30.0 && c['fc_00000011']['free']['rot'] == 270)
ok('góc xoay quá 360 hoặc không phải số bị từ chối', error_of { state_with(cols: {FC1 => {'free' => {'x' => 1, 'y' => 1, 'rot' => 400}}}) } && error_of { state_with(cols: {FC1 => {'free' => {'x' => 1, 'y' => 1, 'rot' => 'a'}}}) })
b = lv(state_with(beams: {FB1 => {'free' => {'a' => [4000, 3000], 'b' => [1000, 1000]}}}))[0]['picks']['beams'][FB1]['free']
ok('dầm xiên: đầu a luôn là đầu bên trái', b['a'] == [1000.0, 1000.0] && b['b'] == [4000.0, 3000.0])
ok('đoạn xiên quá ngắn bị từ chối', error_of { state_with(beams: {FB1 => {'free' => {'a' => [0, 0], 'b' => [60, 60]}}}) })
ok('đoạn gần ngang (lệch 0,02 mm) vẫn được làm thẳng thành ngang', lv(state_with(beams: {FB1 => {'free' => {'a' => [0, 0], 'b' => [3000, 0.02]}}}))[0]['picks']['beams'][FB1]['free']['b'][1] == 0.0)

# ---- Kế hoạch ----
st = state_with(cols: {FC1 => {'free' => {'x' => 8000, 'y' => 8000, 'rot' => 45}}}, beams: {FB1 => {'free' => {'a' => [1000, 1000], 'b' => [4000, 5000]}}},
                walls: {FW1 => {'free' => {'a' => [1000, 1000], 'b' => [4000, 5000]}}})
lvl = 'sl_00000001'
cp = S::ColumnPlan.plan(st['grid'], st['types'], st['levels'], lvl)
col = cp[:items].find { |i| i[:ref] == FC1 }
ok('cột xoay 45°: giữ rộng, sâu, có góc và đa giác 4 đỉnh', col[:rot] == 45 && col[:w] == 300 && col[:poly].size == 4)
ok('cột xoay 45° vuông 300: hộp bao rộng 424,26', (S::ColumnPlan.box(col).then { |bx| bx[1][0] - bx[0][0] }).round(2) == 424.26)
bp = S::BeamPlan.plan(st['grid'], st['types'], st['beam_types'], st['levels'], lvl)
bi = bp[:items].find { |i| i[:ref] == FB1 }
ok('dầm xiên: dir "o", dài 5000 (3-4-5), góc 53,13°, 4 đỉnh', bi[:dir] == 'o' && bi[:length] == 5000.0 && bi[:angle].round(2) == 53.13 && bi[:poly].size == 4 && bi[:placement] == 'free')
w = S::BeamPlan.rects_overlap?([[0, 0], [10, 10], {poly: [[0, 0], [10, 0], [10, 10], [0, 10]]}], [[0, 0], [10, 10], {poly: [[8, 8], [12, 8], [12, 12], [8, 12]]}])
ok('đa giác chồng nhau thật thì báo chồng', w)
ok('hai dải xiên song song cách nhau không chồng dù hộp bao chồng', !S::Geometry.overlap?(S::Geometry.strip([0, 0], [1000, 1000], 100), S::Geometry.strip([300, 0], [1300, 1000], 100)))
ok('hai dải xiên cắt nhau thì chồng', S::Geometry.overlap?(S::Geometry.strip([0, 0], [1000, 1000], 100), S::Geometry.strip([0, 1000], [1000, 0], 100)))
ok('dầm chạm cạnh nhau (chung cạnh) không tính là chồng', !S::Geometry.overlap?([[0, 0], [10, 0], [10, 10], [0, 10]], [[10, 0], [20, 0], [20, 10], [10, 10]]))
wp = S::WallPlan.plan(st['grid'], st['types'], st['beam_types'], st['wall_types'], st['levels'], lvl, st['opening_types'])
wi = wp[:items].find { |i| i[:ref] == FW1 }
ok('tường xiên đặt dưới dầm xiên cùng tim: cao tới đáy dầm', wi[:dir] == 'o' && wi[:under_beam] && wi[:z_top] == bi[:z_bottom])
ok('tường xiên và dầm xiên khác tim thì không phải dầm đỡ', (st2 = state_with(beams: {FB1 => {'free' => {'a' => [1000, 1000], 'b' => [4000, 5000]}}}, walls: {FW1 => {'free' => {'a' => [1500, 1000], 'b' => [4500, 5000]}}})) &&
                                                         !S::WallPlan.plan(st2['grid'], st2['types'], st2['beam_types'], st2['wall_types'], st2['levels'], lvl, st2['opening_types'])[:items].find { |i| i[:ref] == FW1 }[:under_beam])
ok('cột xoay trong kế hoạch tường: cột chồng tường xiên thì báo', (st3 = state_with(cols: {FC1 => {'free' => {'x' => 2500, 'y' => 3000, 'rot' => 20}}}, walls: {FW1 => {'free' => {'a' => [1000, 1000], 'b' => [4000, 5000]}}})) &&
                                                               S::WallPlan.plan(st3['grid'], st3['types'], st3['beam_types'], st3['wall_types'], st3['levels'], lvl, st3['opening_types'])[:issues].any? { |m| m.include?('chồng lên cột') })

# ---- Cửa trên tường xiên ----
sto = state_with(walls: {FW1 => {'free' => {'a' => [1000, 1000], 'b' => [4000, 5000]}}}, openings: {'op_00000001' => {'wall' => FW1, 'type' => ot[0]['id'], 'pos' => 2000, 'flip' => false}, 'op_00000002' => {'wall' => FW1, 'type' => ot[0]['id'], 'pos' => 9000, 'flip' => false}})
op = S::OpeningPlan.plan(sto['grid'], sto['types'], sto['beam_types'], sto['wall_types'], sto['opening_types'], sto['levels'], lvl)
oi = op[:items].find { |i| i[:ref] == 'op_00000001' }
ok('cửa trên tường xiên: tâm cửa cách đầu tường 2000 dọc theo tường; gốc = a + u * (pos - w/2)', oi && oi[:dir] == 'o' && ((oi[:origin][0] - (1000 + 0.6 * (2000 - ot[0]['w'] / 2.0))).abs < 0.02) && ((oi[:origin][1] - (1000 + 0.8 * (2000 - ot[0]['w'] / 2.0))).abs < 0.02))
ok('cửa vượt chiều dài tường xiên bị bỏ kèm cảnh báo', op[:items].size == 1 && op[:issues].any? { |m| m.include?('vượt ra ngoài') })
ok('cửa xiên có đa giác 4 đỉnh và hộp bao chứa đa giác', oi[:poly].size == 4 && oi[:min][0] <= oi[:poly].map(&:first).min && oi[:max][1] >= oi[:poly].map(&:last).max)

# ---- Vân tay ----
fp = ->(item) { S::ModelSync.fingerprint('beam', item) }
ok('vân tay dầm xiên đổi khi dời đầu mút (dù hộp bao như cũ)', fp.call(bi) != fp.call(bi.merge(b: [4000.0, 5200.0])))
ok('vân tay dầm theo lưới không đổi so với bản trước (không có trường xiên)', S::ModelSync.fingerprint('beam', {dir: 'x', min: [0, 0], max: [1, 1], z_top: 1, z_bottom: 0, type_id: 't'}) == begin
  require 'digest'; Digest::SHA1.hexdigest(JSON.generate([[:dir, 'x'], [:min, [0, 0]], [:max, [1, 1]], [:z_top, 1], [:z_bottom, 0], [:type_id, 't']]))[0, 12]
end)
ok('vân tay cột đổi theo góc xoay', S::ModelSync.fingerprint('column', col) != S::ModelSync.fingerprint('column', col.merge(rot: 50)))

# ---- Dựng ----
rad = ->(i) { (i.transformation.angle * 180 / Math::PI).round(3) }
mi = lambda { |model, kind, ref| model.entities.grep(Sketchup::Group).find { |g| g.get_attribute(D, 'kind') == kind }.entities.grep(Sketchup::Instance).find { |i| i.get_attribute('VGD_BIM_SOURCE', 'ref') == "#{lvl}:#{ref}" } }
sb = state_with(cols: {FC1 => {'free' => {'x' => 8000, 'y' => 8000, 'rot' => 30}}}, beams: {FB1 => {'free' => {'a' => [1000, 1000], 'b' => [4000, 5000]}}}, walls: {FW2 => {'free' => {'a' => [1000, 6000], 'b' => [4000, 8000]}}},
                openings: {'op_00000001' => {'wall' => FW2, 'type' => ot[0]['id'], 'pos' => 1500, 'flip' => false}})
m = Sketchup::Model.new
S::AllBuilder.build(m, sb, [lvl])
ci = mi.call(m, 'columns', FC1)
ok('dựng cột xoay 30°: thể hiện đặt tại (8000, 8000) và xoay 30° quanh trục đứng', ci && (ci.transformation.vector.x * MM).round(2) == 8000.0 && rad.call(ci) == 30.0)
bi_i = mi.call(m, 'beams', FB1)
ok('dựng dầm xiên: gốc ở đầu a (1000, 1000), xoay 53,13°, kích thước dài 5000', bi_i && (bi_i.transformation.vector.x * MM).round(2) == 1000.0 && (bi_i.transformation.vector.y * MM).round(2) == 1000.0 && rad.call(bi_i) == 53.130 && JSON.parse(bi_i.get_attribute(D, 'dims'))['length'] == 5000.0)
ok('dầm xiên dùng chung định nghĩa dầm X (không có định nghĩa riêng "O")', bi_i.definition.name.start_with?('VGD Dầm X'))
wi_i = mi.call(m, 'walls', FW2)
ok('dựng tường xiên có lỗ cửa: gốc ở a, xoay đúng góc, định nghĩa tường X có lỗ', wi_i && rad.call(wi_i) == 33.69 && wi_i.definition.name.start_with?('VGD Tường X') && wi_i.definition.name.include?('lỗ'))
oi_i = mi.call(m, 'openings', 'op_00000001')
ok('dựng cửa trên tường xiên: xoay cùng góc với tường, định nghĩa cửa X', oi_i && (rad.call(oi_i) - rad.call(wi_i)).abs < 0.01 && oi_i.definition.name.include?(' X '))
ok('vân tay ghi trên phần tử xiên khớp tính lại', bi_i.get_attribute(D, 'fp') == fp.call(S::BeamPlan.plan(sb['grid'], sb['types'], sb['beam_types'], sb['levels'], lvl)[:items].find { |i| i[:ref] == FB1 }))
stt = S::ModelSync.status(m, sb, lvl)
ok('trạng thái model: toàn bộ phần tử xiên vừa dựng đều "ok"', %W[column|#{FC1} beam|#{FB1} wall|#{FW2} opening|op_00000001].all? { |k| stt[:items][k] == 'ok' })
pv = S::Preview.build(sb.merge('level' => lvl).reject { |k, _| k == 'removed' })
ok('xem trước giao diện có a, b, angle, poly cho dầm, tường, cửa xiên và rot, poly cho cột', pv[:beams][:items].first[:poly] && pv[:walls][:items].first[:a] && pv[:openings][:items].first[:origin] && pv[:columns][:items].first[:rot] == 30)
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
