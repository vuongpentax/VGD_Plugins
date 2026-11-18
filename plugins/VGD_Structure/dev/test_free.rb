# Test phần tử TỰ DO ngoài lưới (cột mốc P4b-1): dữ liệu, kế hoạch cột / dầm / tường / cửa / trần, sao chép tầng, dựng bằng SketchUp giả lập, dữ liệu BIM đọc.
# Chạy: ruby dev/test_free.rb (phần dựng thật chưa xác minh trong SketchUp)
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
FC1 = 'fc_0000000a'; FB1 = 'fb_0000000b'; FW1 = 'fw_0000000c'; FW2 = 'fw_0000000d'

# ---- Dữ liệu ----
st = state_with(cols: {FC1 => {'free' => {'x' => 1234.56, 'y' => 800}}}, beams: {FB1 => {'free' => {'a' => [5000, 2000], 'b' => [1000, 2000]}}}, walls: {FW1 => {'free' => {'a' => [3000, 100], 'b' => [3000.02, 4100]}}})
c = lv(st)[0]['picks']
ok('cột tự do: tọa độ làm tròn 0,1 mm, xoay mặc định 0, không thêm kiểu đặt', c['columns'][FC1] == {'free' => {'x' => 1234.6, 'y' => 800.0, 'rot' => 0}})
ok('dầm tự do: đầu a luôn là đầu nhỏ hơn (đảo lại nếu nhập ngược)', c['beams'][FB1]['free'] == {'a' => [1000.0, 2000.0], 'b' => [5000.0, 2000.0]})
ok('tường tự do lệch dưới 0,05 mm thì làm thẳng đứng', c['walls'][FW1]['free'] == {'a' => [3000.0, 100.0], 'b' => [3000.0, 4100.0]})
ok('phần tử tự do còn nguyên khi lưới đổi (không bị bỏ như phần tử theo lưới)', (g2 = deep(S::State.default['grid'])) && (g2['x_axes'] = g2['x_axes'].first(3)) && (st2 = S::State.normalize!(deep(st).merge('grid' => g2))) && st2['levels'][0]['picks']['columns'].key?(FC1) && st2['removed'] == 0)
bad = {
  'mã cột sai tiền tố' => {cols: {'fb_0000000a' => {'free' => {'x' => 1, 'y' => 1}}}},
  'mã không đủ 8 chữ số' => {cols: {'fc_00a' => {'free' => {'x' => 1, 'y' => 1}}}},
  'tọa độ cột là chuỗi' => {cols: {FC1 => {'free' => {'x' => '1', 'y' => 1}}}},
  'tọa độ cột quá lớn' => {cols: {FC1 => {'free' => {'x' => 2_000_000, 'y' => 1}}}},
  'dầm ngắn dưới 100' => {beams: {FB1 => {'free' => {'a' => [0, 0], 'b' => [50, 0]}}}},
  'tường thiếu đầu mút' => {walls: {FW1 => {'free' => {'a' => [0, 0]}}}},
  'tường mã dầm' => {walls: {FB1 => {'free' => {'a' => [0, 0], 'b' => [1000, 0]}}}},
  'loại cột tự do không tồn tại' => {cols: {FC1 => {'type' => 'ct_ffffffff', 'free' => {'x' => 1, 'y' => 1}}}}
}
bad.each { |label, kw| ok("phần tử tự do sai bị từ chối: #{label}", !error_of { state_with(**kw) }.nil?) }
ok('dữ liệu cũ (không có phần tử tự do) vẫn đọc được, không thêm khóa lạ', (old = state_with(cols: {'1-A' => {}})) && lv(old)[0]['picks']['columns'] == {'1-A' => {}})

# ---- Cột ----
types2 = types + [{'id' => 'ct_00000002', 'name' => 'C20x50', 'w' => 200, 'd' => 500}]
st = S::State.default.tap { |s| s['types'] = types2; s['levels'][0]['picks']['columns'] = {'1-A' => {}, FC1 => {'free' => {'x' => 2000, 'y' => 2000}}, 'fc_00000011' => {'type' => 'ct_00000002', 'free' => {'x' => 6000, 'y' => 2000, 'rot' => 90}}} }
st = S::State.normalize!(st)
cp = S::ColumnPlan.plan(st['grid'], st['types'], st['levels'], 'sl_00000001')
free = cp[:items].select { |i| i[:placement] == 'free' }
ok('cột tự do thành mục kế hoạch: tâm đúng tọa độ, mã riêng, kiểu đặt "free", cao như cột theo lưới', free.size == 2 && free[0][:center] == [2000.0, 2000.0] && free[0][:modes] == {'x' => 'free', 'y' => 'free'} && free[0][:height] == cp[:items][0][:height])
ok('xoay 90 độ đổi chỗ rộng và sâu (200x500 thành 500x200)', free[1][:w] == 500 && free[1][:d] == 200)
ok('cột tự do nằm ngoài khung lưới không bị cảnh báo "nhô ra ngoài"', (o = state_with(cols: {FC1 => {'free' => {'x' => 99_000, 'y' => 99_000}}})) && S::ColumnPlan.plan(o['grid'], o['types'], o['levels'], 'sl_00000001')[:issues].empty?)
ov = state_with(cols: {'1-A' => {}, FC1 => {'free' => {'x' => 150, 'y' => 150}}})
ok('cột tự do chồng cột theo lưới được cảnh báo chồng nhau', S::ColumnPlan.plan(ov['grid'], ov['types'], ov['levels'], 'sl_00000001')[:issues].any? { |m| m.include?('chồng') })

# ---- Dầm ----
st = state_with(cols: {FC1 => {'free' => {'x' => 500, 'y' => 2000}}}, beams: {FB1 => {'free' => {'a' => [1000, 2000], 'b' => [5000, 2000]}}, 'fb_00000012' => {'free' => {'a' => [7000, 500], 'b' => [7000, 3500]}}})
bp = S::BeamPlan.plan(st['grid'], st['types'], st['beam_types'], st['levels'], 'sl_00000001')
b1 = bp[:items].find { |i| i[:ref] == FB1 }; b2 = bp[:items].find { |i| i[:ref] == 'fb_00000012' }
ok('dầm tự do ngang: đầu mút đúng tọa độ (không dừng ở mặt cột), dài 4000, tâm y = 2000, hộp theo rộng dầm', b1[:dir] == 'x' && b1[:start] == 1000.0 && b1[:finish] == 5000.0 && b1[:length] == 4000.0 && b1[:center] == 2000.0 && b1[:min] == [1000.0, 2000 - b1[:w] / 2.0] && b1[:max] == [5000.0, 2000 + b1[:w] / 2.0])
ok('dầm tự do dọc: phương y, start / finish theo y', b2[:dir] == 'y' && b2[:start] == 500.0 && b2[:finish] == 3500.0 && b2[:center] == 7000.0)
ok('dầm tự do treo dưới sàn: đỉnh = đáy sàn tầng trên, đáy thấp hơn cao dầm', b1[:z_top] == bp[:z_top] && b1[:z_bottom] == (bp[:z_top] - b1[:h]).round(1) && b1[:placement] == 'free' && b1[:mode] == 'free')
hit = state_with(cols: {FC1 => {'free' => {'x' => 3000, 'y' => 2000}}}, beams: {FB1 => {'free' => {'a' => [1000, 2000], 'b' => [5000, 2000]}}})
ok('dầm tự do đi xuyên qua cột tự do: cảnh báo dầm chồng lên cột', S::BeamPlan.plan(hit['grid'], hit['types'], hit['beam_types'], hit['levels'], 'sl_00000001')[:issues].any? { |m| m.include?('chồng lên cột') })
cross = state_with(beams: {FB1 => {'free' => {'a' => [1000, 2000], 'b' => [5000, 2000]}}, 'fb_00000013' => {'free' => {'a' => [3000, 1000], 'b' => [3000, 3000]}}})
ok('hai dầm tự do cắt nhau: cảnh báo chồng', S::BeamPlan.plan(cross['grid'], cross['types'], cross['beam_types'], cross['levels'], 'sl_00000001')[:issues].any? { |m| m.include?('chồng') })

# ---- Tường, cửa trên tường tự do ----
wall = {FW1 => {'free' => {'a' => [1000, 2000], 'b' => [5000, 2000]}}}
st = state_with(walls: wall, beams: {FB1 => {'free' => {'a' => [1500, 2000], 'b' => [4500, 2000]}}}, openings: {'op_00000001' => {'wall' => FW1, 'type' => ot[0]['id'], 'pos' => 1500, 'flip' => false}})
wp = S::WallPlan.plan(st['grid'], st['types'], st['beam_types'], st['wall_types'], st['levels'], 'sl_00000001', st['opening_types'])
w = wp[:items].find { |i| i[:ref] == FW1 }
ok('tường tự do ngang: đầu mút, dài, tim, hộp theo bề dày; kiểu đặt free', w[:dir] == 'x' && w[:start] == 1000.0 && w[:finish] == 5000.0 && w[:length] == 4000.0 && w[:center] == 2000.0 && w[:min][0] == 1000.0 && w[:placement] == 'free')
ok('tường tự do có dầm tự do cùng tim nằm trên: cao tới ĐÁY DẦM, đánh dấu dưới dầm', w[:under_beam] && w[:z_top] < wp[:z_slab] && w[:height] == w[:z_top] + 50)
no_beam = state_with(walls: wall)
w0 = S::WallPlan.plan(no_beam['grid'], no_beam['types'], no_beam['beam_types'], no_beam['wall_types'], no_beam['levels'], 'sl_00000001', no_beam['opening_types'])[:items][0]
ok('không có dầm: tường tự do cao tới đáy sàn tầng trên', !w0[:under_beam] && w0[:z_top] == 3430.0 && w0[:height] == 3480.0)
off = state_with(walls: wall, beams: {FB1 => {'free' => {'a' => [1500, 2500], 'b' => [4500, 2500]}}})
ok('dầm tự do KHÔNG cùng tim với tường: không coi là nằm trên tường', !S::WallPlan.plan(off['grid'], off['types'], off['beam_types'], off['wall_types'], off['levels'], 'sl_00000001', off['opening_types'])[:items][0][:under_beam])
ok('cửa đặt trên tường tự do hợp lệ: nằm trong tường, có trong danh sách của tường', w[:openings].size == 1 && w[:openings][0][:pos] == 1500.0 && wp[:opening_issues].empty?)
opp = S::OpeningPlan.plan(st['grid'], st['types'], st['beam_types'], st['wall_types'], st['opening_types'], st['levels'], 'sl_00000001')
o = opp[:items][0]
ok('kế hoạch cửa trên tường tự do: tọa độ thế giới theo đầu tường (1000 + 1500 - rộng/2)', o[:wall] == FW1 && (o[:along] - (1000 + 1500 - o[:w] / 2.0)).abs < 0.01 && o[:min][1] == 2000.0 - w[:t] / 2.0)
past = state_with(walls: wall, openings: {'op_00000001' => {'wall' => FW1, 'type' => ot[0]['id'], 'pos' => 3900, 'flip' => false}})
ok('cửa vượt ra ngoài tường tự do: bị bỏ và báo (cùng quy tắc với tường theo lưới)', (pw = S::WallPlan.plan(past['grid'], past['types'], past['beam_types'], past['wall_types'], past['levels'], 'sl_00000001', past['opening_types'])) && pw[:items][0][:openings].empty? && pw[:opening_issues].any? { |m| m.include?('vượt ra ngoài') })
ok('cửa gắn vào mã tường tự do không còn: bị bỏ khi chuẩn hóa dữ liệu (không treo)', (gone = state_with(openings: {'op_00000001' => {'wall' => FW2, 'type' => ot[0]['id'], 'pos' => 1000, 'flip' => false}})) && lv(gone)[0]['picks']['openings'].empty? && gone['removed'] == 1)
sl = state_with(walls: {FW1 => {'free' => {'a' => [3000, 500], 'b' => [3000, 4000]}}, 'fw_00000014' => {'free' => {'a' => [3000, 3000], 'b' => [3000, 6000]}}})
ok('hai tường tự do chồng nhau: cảnh báo', S::WallPlan.plan(sl['grid'], sl['types'], sl['beam_types'], sl['wall_types'], sl['levels'], 'sl_00000001', sl['opening_types'])[:issues].any? { |m| m.include?('chồng') })

# ---- Trần cảnh báo phần tử tự do ----
cc = state_with(ceilings: {'1-2/A-B' => {}}, walls: {FW1 => {'free' => {'a' => [1000, 1800], 'b' => [3000, 1800]}}})
ceil = S::CeilingPlan.plan(cc['grid'], cc['types'], cc['beam_types'], cc['wall_types'], cc['levels'], 'sl_00000001', cc['opening_types'])
ok('trần ô có tường tự do đi qua: cảnh báo trần chưa lùi theo phần tử tự do', ceil[:issues].any? { |m| m.include?(FW1) })

# ---- Sao chép tầng, kiểm tra, đếm ----
st = state_with(cols: {FC1 => {'free' => {'x' => 2000, 'y' => 2000}}, '1-A' => {}}, walls: wall, openings: {'op_00000001' => {'wall' => FW1, 'type' => ot[0]['id'], 'pos' => 1500, 'flip' => false}})
cop = L.copy_picks(lv(st), 'sl_00000001', 'sl_00000002', st['grid'], st['types'], 'columns', st['beam_types'], st['wall_types'], st['opening_types'])
ok('sao chép lựa chọn cột sang tầng khác: kèm cột tự do (cùng mã, nội dung độc lập)', cop[1]['picks']['columns'][FC1]['free']['x'] == 2000.0 && !cop[1]['picks']['columns'][FC1]['free'].equal?(cop[0]['picks']['columns'][FC1]['free']))
cop = L.copy_picks(cop, 'sl_00000001', 'sl_00000002', st['grid'], st['types'], 'walls', st['beam_types'], st['wall_types'], st['opening_types'])
cop = L.copy_picks(cop, 'sl_00000001', 'sl_00000002', st['grid'], st['types'], 'openings', st['beam_types'], st['wall_types'], st['opening_types'])
ok('sao chép tường tự do rồi cửa: cửa ở tầng đích bám đúng tường tự do (mã cửa mới)', cop[1]['picks']['openings'].size == 1 && cop[1]['picks']['openings'].values[0]['wall'] == FW1 && !cop[1]['picks']['openings'].key?('op_00000001'))
ck = S::Checker.run(st)
ok('kiểm tra kết cấu đếm cả phần tử tự do (2 cột, 1 tường, 1 cửa)', ck[:levels][0][:counts]['columns'] == 2 && ck[:levels][0][:counts]['walls'] == 1 && ck[:levels][0][:counts]['openings'] == 1 && ck[:errors] == 0)
pv = S::Preview.build(st.merge('level' => 'sl_00000001').reject { |k, _| k == 'removed' })
ok('xem trước (giao diện) có phần tử tự do: cột, tường, cửa với kiểu đặt "free"', pv[:columns][:items].any? { |i| i[:placement] == 'free' } && pv[:walls][:items].any? { |i| i[:placement] == 'free' && i[:ref] == FW1 } && pv[:openings][:items].size == 1)
pr, _added = S::Proposal.propose(st['grid'], lv(st), ['sl_00000001'])
ok('đề xuất bán tự động không đụng phần tử tự do (chỉ thêm mục theo lưới)', pr[0]['picks']['columns'][FC1] == lv(st)[0]['picks']['columns'][FC1] && pr[0]['picks']['walls'][FW1] == lv(st)[0]['picks']['walls'][FW1])

# ---- Dựng ----
m = Sketchup::Model.new
S::ColumnBuilder.build(m, st, ['sl_00000001'])
g = m.entities.grep(Sketchup::Group).find { |x| x.get_attribute(D, 'kind') == 'columns' }
inst = g.entities.grep(Sketchup::Instance).find { |i| i.get_attribute('VGD_BIM_SOURCE', 'ref') == "sl_00000001:#{FC1}" }
ok('dựng cột tự do: ComponentInstance đặt đúng tọa độ, ref theo mã tự do, BIM đọc được loại và kích thước', inst && ((inst.transformation.vector.x * MM).round(2) == 2000.0) && ((inst.transformation.vector.y * MM).round(2) == 2000.0) && JSON.parse(inst.get_attribute(D, 'dims'))['w'] == 300 && JSON.parse(inst.get_attribute(D, 'placement'))['position'] == 'free')
m2 = Sketchup::Model.new
S::WallBuilder.build(m2, st, ['sl_00000001'])
wg = m2.entities.grep(Sketchup::Group).find { |x| x.get_attribute(D, 'kind') == 'walls' }
wi = wg.entities.grep(Sketchup::Instance).find { |i| i.get_attribute('VGD_BIM_SOURCE', 'ref') == "sl_00000001:#{FW1}" }
ok('dựng tường tự do có lỗ cửa: một thể hiện, kích thước (dài 4000), placement "free"', wi && JSON.parse(wi.get_attribute(D, 'dims'))['length'] == 4000.0 && JSON.parse(wi.get_attribute(D, 'placement'))['position'] == 'free')
m3 = Sketchup::Model.new
S::AllBuilder.build(m3, st, ['sl_00000001'])
ok('Dựng tất cả có phần tử tự do: không lỗi, có đủ nhóm cột, tường, cửa', %w[columns walls openings].all? { |k| m3.entities.grep(Sketchup::Group).any? { |x| x.get_attribute(D, 'kind') == k } })
only = state_with(cols: {FC1 => {'free' => {'x' => 2000, 'y' => 2000}}})
ok('tầng chỉ có cột tự do vẫn được dựng (đếm theo số mục, không chỉ theo lưới)', (mm = Sketchup::Model.new) && S::ColumnBuilder.build(mm, only, ['sl_00000001']).total == 1)
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
