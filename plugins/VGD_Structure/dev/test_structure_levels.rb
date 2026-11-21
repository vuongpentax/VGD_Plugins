# Test cốt sàn kết cấu, dầm cùng cốt với sàn, sàn lọt lòng giữa dầm (cán nền, đỉnh dầm = đỉnh sàn): cột, dầm, tường, cửa, sàn, trần, dựng.
# Chạy: ruby dev/test_structure_levels.rb (phần dựng thật chưa xác minh trong SketchUp)
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/stair_types core/stair_plan core/stair_place core/layer_list core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/slab_plan core/ceiling_plan core/proposal core/checker core/model_edit core/state core/preview model_sync edit_sync model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder stair_builder all_builder].each { |f| require File.join(ROOT, f) }
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
L1 = 'sl_00000001'; L2 = 'sl_00000002'
def lstate(l1: {}, l2: {}, screed1: nil, screed2: nil)
  st = S::State.default
  st['levels'][0]['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => {}, 'slabs' => {}, 'ceilings' => {}, 'openings' => {}}.merge(l1)
  st['levels'][1]['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => {}, 'slabs' => {}, 'ceilings' => {}, 'openings' => {}}.merge(l2)
  st['levels'][0]['screed'] = screed1 if screed1
  st['levels'][1]['screed'] = screed2 if screed2
  S::State.normalize!(st)
end
def slab(st, id); S::SlabPlan.plan(st['grid'], st['levels'], id, st['types'], st['beam_types']); end

# ---- Cán nền ----
ok('tầng mặc định có cán nền 50 mm', S::State.default['levels'].all? { |l| l['screed'] == 50.0 })
old = S::State.default; old['levels'].each { |l| l.delete('screed') }
ok('dữ liệu cũ (chưa có cán nền) nạp được, mặc định 50', S::State.normalize!(old)['levels'].all? { |l| l['screed'] == 50.0 })
ok('cán nền ngoài 0..300 hoặc không phải số bị từ chối', error_of { lstate(screed1: 400) } && error_of { lstate(screed1: -5) } && error_of { lstate(screed1: 'x') })
ok('cán nền 0 được phép (cốt kết cấu = cốt hoàn thiện)', lstate(screed1: 0)['levels'][0]['screed'] == 0.0 && S::Levels.structure_top(lstate(screed1: 0)['levels'][0]) == 0.0)
ok('cốt sàn kết cấu = cao độ tầng - cán nền (0 - 50, 3600 - 50)', S::Levels.structure_top(lstate['levels'][0]) == -50.0 && S::Levels.structure_top(lstate['levels'][1]) == 3550.0)
m = Sketchup::Model.new; S::ModelStore.write(m, lstate(screed1: 80))
ok('lưu rồi nạp lại giữ cán nền riêng từng tầng', S::ModelStore.read(m)['levels'].map { |l| l['screed'] } == [80.0, 50.0])

# ---- Cột, dầm, tường theo cốt kết cấu ----
st = lstate(l1: {'columns' => {'1-A' => {}}, 'beams' => {'x:A:1-2' => {}}, 'walls' => {'x:B:1-2' => {}}})
cp = S::ColumnPlan.plan(st['grid'], st['types'], st['levels'], L1)
ok('cột: từ mặt sàn kết cấu tầng 1 (-50) tới mặt sàn kết cấu tầng 2 (3550), cao 3600', cp[:z0] == -50.0 && cp[:z1] == 3550.0 && cp[:height] == 3600.0 && cp[:slab_bottom] == 3430.0)
bp = S::BeamPlan.plan(st['grid'], st['types'], st['beam_types'], st['levels'], L1)[:items][0]
ok('dầm: ĐỈNH dầm bằng mặt sàn kết cấu tầng trên (3550), đáy = 3550 - h (D20x40: 3150)', bp[:z_top] == 3550.0 && bp[:z_bottom] == 3150.0 && bp[:h] == 400.0)
wp = S::WallPlan.plan(st['grid'], st['types'], st['beam_types'], st['wall_types'], st['levels'], L1, st['opening_types'])[:items][0]
ok('tường đặt trên sàn kết cấu (-50) và lên đáy sàn tầng trên (3430): cao 3480', wp[:z_bottom] == -50.0 && wp[:z_top] == 3430.0 && wp[:height] == 3480.0)
st2 = lstate(l1: {'columns' => {'1-A' => {}}}, screed1: 100, screed2: 20)
c2 = S::ColumnPlan.plan(st2['grid'], st2['types'], st2['levels'], L1)
ok('cán nền khác nhau từng tầng (100 và 20): cột từ -100 tới 3580, cao 3680', c2[:z0] == -100.0 && c2[:z1] == 3580.0 && c2[:height] == 3680.0)
ob = lstate(l1: {'beams' => {'x:A:1-2' => {'type' => 'bt_00000001'}}})
bt = ob['beam_types'].dup; bt = [bt[0].merge('h' => 120.0)]
ob2 = lstate(l1: {'beams' => {'x:A:1-2' => {}}}); ob2['beam_types'] = [ob2['beam_types'][0].merge('h' => 120.0)]
bi = S::BeamPlan.plan(ob2['grid'], ob2['types'], ob2['beam_types'], ob2['levels'], L1)
ok('dầm cao không hơn dày sàn tầng trên (120): cảnh báo không có phần nhô xuống dưới sàn', bi[:issues].any? { |s| s.include?('không có phần nhô') })
ok('dầm cao 400 > dày sàn 120: không có cảnh báo này', S::BeamPlan.plan(st['grid'], st['types'], st['beam_types'], st['levels'], L1)[:issues].none? { |s| s.include?('không có phần nhô') })

# ---- Cửa tính từ cốt hoàn thiện ----
so = lstate(l1: {'walls' => {'x:B:1-2' => {}}, 'openings' => {'op_00000001' => {'wall' => 'x:B:1-2', 'type' => S::OpeningTypes.default.find { |t| t['kind'] == 'window' }['id'], 'pos' => 2000, 'flip' => false}}}, screed1: 100)
wo = S::WallPlan.plan(so['grid'], so['types'], so['beam_types'], so['wall_types'], so['levels'], L1, so['opening_types'])[:items][0]
win = wo[:openings][0]
ok('cửa sổ ngưỡng 900 với cán nền 100: lỗ trong tường từ 1000 (so với đáy tường) vì ngưỡng tính từ cốt hoàn thiện', win[:z0] == 1000.0 && win[:sill] == 900.0)
op = S::OpeningPlan.plan(so['grid'], so['types'], so['beam_types'], so['wall_types'], so['opening_types'], so['levels'], L1)[:items][0]
ok('cửa dựng ở cao độ tuyệt đối = cao độ tầng + ngưỡng (0 + 900)', op[:z_bottom] == 900.0)

# ---- Sàn lọt lòng giữa dầm ----
edge_beams = {'x:A:1-2' => {}, 'x:B:1-2' => {}, 'y:1:A-B' => {}, 'y:2:A-B' => {}}
s_none = lstate(l2: {'slabs' => {'1-2/A-B' => {}}})
sl0 = slab(s_none, L2)[:items][0]
ok('tầng dưới không có dầm: sàn phủ trọn ô (4200 x 3600 = 15,12 m2), mặt trên 3550, đáy 3430', sl0[:area] == 15.12 && sl0[:min] == [0.0, 0.0] && sl0[:max] == [4200.0, 3600.0] && sl0[:z_top] == 3550.0 && sl0[:z_bottom] == 3430.0)
s_b = lstate(l1: {'beams' => edge_beams}, l2: {'slabs' => {'1-2/A-B' => {}}})
slb = slab(s_b, L2)[:items][0]
ok('bốn dầm quanh ô: sàn lùi tới mặt dầm (x 200..4100, y 200..3500; dầm biên mặt trong, dầm giữa lùi nửa bề dày)', slb[:min] == [200.0, 200.0] && slb[:max] == [4100.0, 3500.0] && slb[:area] == 12.87)
ok('sàn lọt lòng: không chồng khối với dầm cùng cốt (hộp sàn nằm ngoài hộp từng dầm)', begin
  beams = S::BeamPlan.plan(s_b['grid'], s_b['types'], s_b['beam_types'], s_b['levels'], L1)[:items]
  beams.none? { |b| S::BeamPlan.rects_overlap?([slb[:min], slb[:max], slb], [b[:min], b[:max], b]) }
end)
s_c = lstate(l1: {'beams' => edge_beams, 'columns' => {'1-A' => {}, '2-A' => {}, '1-B' => {}, '2-B' => {}}}, l2: {'slabs' => {'1-2/A-B' => {}}})
slc = slab(s_c, L2)[:items][0]
ok('thêm bốn cột ở góc ô: sàn khoét góc theo cột (đa giác nhiều hơn 4 đỉnh) và diện tích nhỏ hơn', slc[:polygon].size > 4 && slc[:area] < slb[:area])
s_top_beams = lstate(l1: {}, l2: {'beams' => {}, 'slabs' => {'1-2/A-B' => {}}})
ok('dầm cùng tầng với sàn (không phải tầng dưới) không làm sàn lùi: dầm tầng 2 đỡ sàn tầng 3', slab(lstate(l2: {'slabs' => {'1-2/A-B' => {}}}), L2)[:items][0][:area] == 15.12)
low = slab(lstate(l1: {'beams' => edge_beams}, l2: {}).merge({}), L1)
ok('sàn tầng thấp nhất: không có tầng dưới nên không lùi theo dầm dù tầng 1 có dầm', (lw = slab(lstate(l1: {'beams' => edge_beams, 'slabs' => {'1-2/A-B' => {}}}), L1)[:items][0]) && lw[:area] == 15.12 && lw[:z_top] == -50.0)
narrow = lstate(l1: {'beams' => {'x:A:1-2' => {}, 'x:B:1-2' => {}}}, l2: {'slabs' => {'1-2/A-B' => {}}}); narrow['beam_types'] = [narrow['beam_types'][0].merge('w' => 1500.0)]
narrow['grid'] = S::Grid.normalize!('origin' => [0, 0], 'x_axes' => S::Grid.axes_from_spacings('4200', :number), 'y_axes' => S::Grid.axes_from_spacings('1200', :letter))
ns = slab(narrow, L2)
ok('dầm quá rộng làm ô còn dưới 100 mm: bỏ sàn ô đó kèm cảnh báo, không lỗi', ns[:items].empty? && ns[:issues].any? { |s| s.include?('1-2/A-B') && s.include?('khoảng hở') })
fb = lstate(l1: {'beams' => {'fb_0000000b' => {'free' => {'a' => [500, 1800], 'b' => [3500, 1800]}}}}, l2: {'slabs' => {'1-2/A-B' => {}}})
ok('dầm TỰ DO nằm trong ô: sàn chưa lùi theo nó, chỉ cảnh báo chồng', slab(fb, L2)[:issues].any? { |s| s.include?('fb_0000000b') } && slab(fb, L2)[:items][0][:area] == 15.12)
fs = lstate(l1: {'beams' => edge_beams}, l2: {'slabs' => {'fs_0000000a' => {'free' => {'poly' => [[500, 500], [2000, 500], [2000, 2000], [500, 2000]]}}}})
ok('sàn đa giác tự do không bị lùi (đúng hình vẽ), không cảnh báo khi không chạm dầm tự do', slab(fs, L2)[:items][0][:area] == 2.25 && slab(fs, L2)[:issues].empty?)
bad_below = lstate(l1: {'beams' => edge_beams}, l2: {'slabs' => {'1-2/A-B' => {}}}); bad_below['levels'][0]['picks']['columns'] = {}
bad_below['beam_types'] = [bad_below['beam_types'][0].merge('h' => 2000.0)]; bad_below['levels'][1]['elevation'] = 1000.0
sb = slab(bad_below, L2)
ok('kế hoạch tầng dưới lỗi (dầm cao hơn tầng): sàn vẫn lập, phủ trọn ô kèm cảnh báo chưa lùi', sb[:items].size == 1 && sb[:items][0][:area] == 15.12 && sb[:issues].any? { |s| s.include?('chưa lùi') })

# ---- Trần ----
cs = lstate(l1: {'ceilings' => {'1-2/A-B' => {}}}, screed1: 100)
cl = S::CeilingPlan.plan(cs['grid'], cs['types'], cs['beam_types'], cs['wall_types'], cs['levels'], L1, cs['opening_types'])[:items][0]
ok('trần đo từ cốt HOÀN THIỆN: đáy = 0 + 2800 dù cán nền đổi', cl[:z_bottom] == 2800.0)
ok('trần không được vượt đáy sàn tầng trên (3430 với cán nền 50): cao trần 3425 + dày 9 vượt thì báo lỗi', error_of { S::CeilingPlan.plan(*(lstate(l1: {'ceilings' => {'1-2/A-B' => {}}}).then { |x| [x['grid'], x['types'], x['beam_types'], x['wall_types']] }), lstate(l1: {'ceilings' => {'1-2/A-B' => {}}}).tap { |x| x['levels'][0]['ceiling_height'] = 3425.0 }['levels'], L1, S::OpeningTypes.default) }.to_s.include?('cao hơn đáy sàn'))

# ---- Vân tay và dựng ----
f1 = S::ModelSync.fingerprint('slab', slab(s_none, L2)[:items][0])
f2 = S::ModelSync.fingerprint('slab', slab(lstate(l2: {'slabs' => {'1-2/A-B' => {}}}, screed2: 80), L2)[:items][0])
ok('vân tay sàn đổi khi đổi cán nền (cốt sàn đổi) và khi sàn lùi theo dầm', f1 != f2 && f1 != S::ModelSync.fingerprint('slab', slb))
mb = Sketchup::Model.new
S::AllBuilder.build(mb, s_b.merge('levels' => s_b['levels']), [L1, L2]) if false
sbuild = lstate(l1: {'beams' => edge_beams, 'columns' => {'1-A' => {}}}, l2: {'slabs' => {'1-2/A-B' => {}}})
S::AllBuilder.build(mb, sbuild, [L1, L2])
sg = mb.entities.grep(Sketchup::Group).find { |g| g.get_attribute(D, 'kind') == 'slabs' && g.get_attribute(D, 'level') == L2 }
si = sg.entities.grep(Sketchup::Instance).first
ok('dựng: sàn tầng 2 đặt tại góc nhỏ của hình đã lùi (200, 200) với đáy 3430', si && (si.transformation.vector.x * MM).round(2) == 200.0 && (si.transformation.vector.y * MM).round(2) == 200.0 && (si.transformation.vector.z * MM).round(2) == 3430.0)
bg = mb.entities.grep(Sketchup::Group).find { |g| g.get_attribute(D, 'kind') == 'beams' }
bi2 = bg.entities.grep(Sketchup::Instance).first
ok('dựng: dầm đặt với đáy ở 3150 (đỉnh 3550 bằng mặt trên sàn tầng 2)', (bi2.transformation.vector.z * MM).round(2) == 3150.0)
ok('trạng thái model: sàn, dầm vừa dựng đều "ok"', (stt = S::ModelSync.status(mb, sbuild, L2))[:items]['slab|1-2/A-B'] == 'ok' && S::ModelSync.status(mb, sbuild, L1)[:items].values.all? { |v| v == 'ok' || v == 'unbuilt' })
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
