# Test dựng cửa (opening_builder.rb) và tường có lỗ cửa (wall_builder.rb) bằng SketchUp giả lập: lỗ trên mặt tường, khung và cánh, vị trí và cao độ, dữ liệu BIM đọc,
# tag A. DOOR / A. WINDOW, một bước hoàn tác, dựng lại giữ ID, dọn mồ côi, lỗi giữ model nguyên. Chạy: ruby dev/test_opening_builder.rb (chưa xác minh trong SketchUp thật)
require 'json'
require 'securerandom'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/slab_plan core/ceiling_plan core/proposal core/checker core/state core/preview model_sync model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder all_builder].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
O = S::OpeningBuilder
W = S::WallBuilder
D = S::Schema::DICTIONARY
MM = 25.4
def deep(x); Marshal.load(Marshal.dump(x)); end
def op(wall, type, pos, flip = false); {'wall' => wall, 'type' => type, 'pos' => pos, 'flip' => flip}; end
def state_with(openings, walls = %w[x:B:2-3 y:2:A-B])
  st = S::State.default
  cols = S::Grid.intersections(st['grid']).each_with_object({}) { |i, h| h[i[:ref]] = {} }
  st['levels'][0]['picks'] = {'columns' => cols, 'beams' => {}, 'walls' => walls.each_with_object({}) { |r, h| h[r] = {} }, 'slabs' => {}, 'ceilings' => {}, 'openings' => openings}
  st
end
def groups(m, kind); m.entities.grep(Sketchup::Group).select { |g| g.get_attribute(S::Schema::DICTIONARY, 'kind') == kind }; end
mmv = ->(i) { [i.transformation.vector.x * MM, i.transformation.vector.y * MM, i.transformation.vector.z * MM].map { |v| v.round(3) } }
DOOR = 'ot_00000001'; WIN = 'ot_00000002'
OPS = {'op_00000001' => op('x:B:2-3', DOOR, 1950), 'op_00000002' => op('x:B:2-3', WIN, 3200), 'op_00000003' => op('y:2:A-B', DOOR, 1000, true)}

# Tường có lỗ
m = Sketchup::Model.new
W.build(m, state_with(OPS), ['sl_00000001'])
wi = groups(m, 'walls')[0].entities.grep(Sketchup::Instance)
wx = wi.find { |i| i.name.include?('x:B:2-3') }
ok('tường có 2 cửa dùng định nghĩa riêng ghi các lỗ trong tên (khác tường không cửa)', wx.definition.name.start_with?('VGD Tường X 200x3480x3900 lỗ ') && wi.find { |i| i.name.include?('y:2:A-B') }.definition.name.include?('lỗ'))
faces = wx.definition.entities.grep(Sketchup::Face)
ok('định nghĩa tường có lỗ: một mặt đứng ngoài (đùn 200 theo +Y) và 2 mặt lỗ bị xóa (tạo lỗ)', faces.size == 3 && faces.count(&:erased) == 2 && faces.reject(&:erased).size == 1 && (faces.find { |f| !f.erased }.height * MM - 200).abs < 1e-6)
outer = faces.find { |f| !f.erased }
ok('mặt ngoài nằm trong mặt phẳng đứng y = -100, dài 3900 cao 3480; chiều đùn hướng +Y', outer.points.map { |p| (p.y * MM).round(3) }.uniq == [-100.0] && outer.points.map { |p| (p.x * MM).round(3) }.minmax == [0.0, 3900.0] && outer.points.map { |p| (p.z * MM).round(3) }.minmax == [0.0, 3480.0] && outer.normal.y > 0)
holes = faces.select(&:erased).map { |f| [f.points.map { |p| (p.x * MM).round(3) }.minmax, f.points.map { |p| (p.z * MM).round(3) }.minmax] }
ok('hai lỗ đúng vị trí: cửa đi x 1500..2400 z 0..2100; cửa sổ x 2600..3800 z 900..2100', holes == [[[1500.0, 2400.0], [0.0, 2100.0]], [[2600.0, 3800.0], [900.0, 2100.0]]])
wy = wi.find { |i| i.name.include?('y:2:A-B') }
fy = wy.definition.entities.grep(Sketchup::Face).find { |f| !f.erased }
ok('tường theo Y: mặt đứng trong mặt phẳng x = -100, đùn theo +X', fy.points.map { |p| (p.x * MM).round(3) }.uniq == [-100.0] && fy.normal.x > 0 && (fy.height * MM - 200).abs < 1e-6)
ok('dữ liệu BIM đọc của tường: số lỗ và diện tích lỗ (3,33 m²)', JSON.parse(wx.get_attribute(D, 'dims')).values_at('openings', 'openings_area') == [2, 3.33])
nw = wi.find { |i| i.name.include?('x:B:2-3') }
ok('tường KHÔNG có cửa vẫn dựng như cũ (không lỗ)', (m2 = Sketchup::Model.new) && W.build(m2, state_with({}), ['sl_00000001']) && groups(m2, 'walls')[0].entities.grep(Sketchup::Instance).all? { |i| !i.definition.name.include?('lỗ') } && true)

# Cửa
mo = Sketchup::Model.new
res = O.build(mo, state_with(OPS), ['sl_00000001'])
g = groups(mo, 'openings')
ok('dựng cửa: một nhóm "Cửa - Tầng 1" ghi kind = openings và mã tầng; một bước hoàn tác', g.size == 1 && g[0].name == 'Cửa - Tầng 1' && g[0].get_attribute(D, 'level') == 'sl_00000001' && mo.operations == [[:start, 'VGD Structure · Dựng cửa'], [:commit]])
inst = g[0].entities.grep(Sketchup::Instance)
ok('3 cửa là ComponentInstance (2 cửa đi, 1 cửa sổ), tên theo loại', inst.size == 3 && inst.count { |i| i.name.start_with?('Cửa đi D900x2100') } == 2 && inst.count { |i| i.name.start_with?('Cửa sổ W1200x1200') } == 1)
d1 = inst.find { |i| i.get_attribute('VGD_BIM_SOURCE', 'ref') == 'sl_00000001:op_00000001' }
d2 = inst.find { |i| i.get_attribute('VGD_BIM_SOURCE', 'ref') == 'sl_00000001:op_00000003' }
w1 = inst.find { |i| i.get_attribute('VGD_BIM_SOURCE', 'kind') == 'window' }
ok('cửa đi trên tường X đặt tại (5850, 3600, 0); cửa sổ tại (6950, 3600, 900); cửa trên tường Y tại (4200, 850, 0)', mmv.call(d1) == [5850.0, 3600.0, 0.0] && mmv.call(w1) == [6950.0, 3600.0, 900.0] && mmv.call(d2) == [4200.0, 850.0, 0.0])
ok('định nghĩa riêng theo phương và mặt cánh: cửa đi X, cửa đi Y lật, cửa sổ X', mo.definitions.list.map(&:name).sort == ['VGD Cửa sổ X 1200x1200x200', 'VGD Cửa đi X 900x2100x200', 'VGD Cửa đi Y 900x2100x200 lật'])
dd = d1.definition.entities.grep(Sketchup::Face)
ok('cửa đi: khung chữ U (8 đỉnh) đùn 200 theo bề dày tường và cánh đặc đùn 40', dd.size == 2 && dd.map { |f| f.points.size }.sort == [4, 8] && dd.map { |f| (f.height * MM).round(3) }.sort == [40.0, 200.0])
frame = dd.find { |f| f.points.size == 8 }
ok('khung cửa đi chữ U đúng đa giác: thanh 50 hai bên và trên, không có thanh ngưỡng', frame.points.map { |p| [(p.x * MM).round(3), (p.z * MM).round(3)] } == [[0.0, 0.0], [50.0, 0.0], [50.0, 2050.0], [850.0, 2050.0], [850.0, 0.0], [900.0, 0.0], [900.0, 2100.0], [0.0, 2100.0]])
leaf = dd.find { |f| f.points.size == 4 }
ok('cánh cửa đi thụt 20 mm vào mặt tường (y từ -80), rộng 900 - 2 x (50 + 5) = 790, cao 2100 - 50 - 5 - 5 = 2040', leaf.points.map { |p| (p.y * MM).round(3) }.uniq == [-80.0] && leaf.points.map { |p| (p.x * MM).round(3) }.minmax == [55.0, 845.0] && leaf.points.map { |p| (p.z * MM).round(3) }.minmax == [5.0, 2045.0])
leaf_flip = d2.definition.entities.grep(Sketchup::Face).find { |f| f.points.size == 4 }
ok('cửa đi lật (flip) đặt cánh về mặt kia: trên tường Y, cánh ở x từ +40 (100 - 20 - 40)', leaf_flip.points.map { |p| (p.x * MM).round(3) }.uniq == [40.0] && leaf_flip.normal.x > 0)
wd = w1.definition.entities.grep(Sketchup::Face)
ok('cửa sổ: khung vòng kín (mặt ngoài và lỗ trong bị xóa) đùn 200 và kính dày 6', wd.count(&:erased) == 1 && wd.reject(&:erased).size == 2 && wd.reject(&:erased).map { |f| (f.height * MM).round(3) }.sort == [6.0, 200.0])
glass = wd.reject(&:erased).find { |f| (f.height * MM).round(3) == 6.0 }
ok('kính nằm giữa bề dày tường (y từ -3), phủ vùng trong khung 1100 x 1100', glass.points.map { |p| (p.y * MM).round(3) }.uniq == [-3.0] && glass.points.map { |p| (p.x * MM).round(3) }.minmax == [50.0, 1150.0] && glass.points.map { |p| (p.z * MM).round(3) }.minmax == [50.0, 1150.0])
ok('dữ liệu BIM đọc: kind door / window, ref, kích thước, tường chủ, vị trí, tầng', d1.get_attribute('VGD_BIM_SOURCE', 'kind') == 'door' && w1.get_attribute('VGD_BIM_SOURCE', 'kind') == 'window' && JSON.parse(d1.get_attribute(D, 'dims')) == {'w' => 900.0, 'h' => 2100.0, 'sill' => 0.0, 'thickness' => 200.0, 'wall' => 'x:B:2-3'} && JSON.parse(d2.get_attribute(D, 'placement')) == {'dir' => 'y', 'pos' => 1000.0, 'flip' => true} && d1.get_attribute(D, 'level_name') == 'Tầng 1' && d1.get_attribute(D, 'type') == 'D900x2100')
ok('tag A. DOOR (255, 119, 102) cho cửa đi và A. WINDOW (204, 186, 237) cho cửa sổ, đúng thư mục A. ARCHITECTURAL', mo.layers['A. DOOR'].color.rgb == [255, 119, 102] && mo.layers['A. WINDOW'].color.rgb == [204, 186, 237] && mo.layers['A. DOOR'].folder.name == 'A. ARCHITECTURAL' && d1.layer.equal?(mo.layers['A. DOOR']) && w1.layer.equal?(mo.layers['A. WINDOW']))
ok('kết quả: 3 cửa; dựng cửa lưu dữ liệu nguồn (loại cửa, cửa đã đặt)', res.total == 3 && S::ModelStore.read(mo)['levels'][0]['picks']['openings'].size == 3 && S::ModelStore.read(mo)['opening_types'].size == 2)

# VGD ID
VGD::Bridge.providers.clear
VGD::Bridge.register('vgd_bim', {bridge_version: 1, version: 'x', provides: ['vgd_id'], commands: {'generate' => -> { SecureRandom.uuid }}})
mi = Sketchup::Model.new
O.build(mi, state_with(OPS), ['sl_00000001'])
ids = groups(mi, 'openings')[0].entities.grep(Sketchup::Instance).to_h { |i| [i.get_attribute('VGD_BIM_SOURCE', 'ref'), i.get_attribute('VGD_BIM_ID', 'guid')] }
smaller = OPS.reject { |k, _| k == 'op_00000002' }
O.build(mi, state_with(smaller), ['sl_00000001'])
ids2 = groups(mi, 'openings')[0].entities.grep(Sketchup::Instance).to_h { |i| [i.get_attribute('VGD_BIM_SOURCE', 'ref'), i.get_attribute('VGD_BIM_ID', 'guid')] }
ok('cửa có VGD ID từ BIM; bỏ một cửa rồi dựng lại: các cửa còn lại GIỮ ID', ids.values.all? { |x| x =~ /\A[0-9a-f-]{36}\z/ } && ids2.keys.sort == %w[sl_00000001:op_00000001 sl_00000001:op_00000003] && ids2.all? { |k, v| ids[k] == v })
VGD::Bridge.providers.clear

# Dựng lại, mồ côi, từ chối
old = g[0]
O.build(mo, state_with({'op_00000001' => OPS['op_00000001']}), ['sl_00000001'])
ok('dựng lại thay nhóm cũ: một nhóm với 1 cửa; không thêm tag', !old.valid? && groups(mo, 'openings').size == 1 && groups(mo, 'openings')[0].entities.grep(Sketchup::Instance).size == 1 && mo.layers.count { |l| l.name == 'A. DOOR' } == 1)
bad = Sketchup::Model.new
checks = {'chưa có cửa' => [state_with({}), ['sl_00000001']], 'không chọn tầng' => [state_with(OPS), []], 'tầng trên cùng' => [state_with(OPS), ['sl_00000002']], 'tầng không tồn tại' => [state_with(OPS), ['sl_deadbeef']],
          'dữ liệu sai' => [{'grid' => 5}, ['sl_00000001']], 'loại cửa sai' => [state_with(OPS).merge('opening_types' => [{'id' => 'x'}]), ['sl_00000001']],
          'cửa trên tường chưa chọn (bị bỏ hết)' => [state_with({'op_00000001' => op('x:B:3-4', DOOR, 1950)}), ['sl_00000001']]}
checks.each { |label, (s, ids)| ok("dữ liệu sai bị từ chối, model không đổi: #{label}", !error_of { O.build(bad, s, ids) }.nil? && bad.operations.empty? && groups(bad, 'openings').empty? && bad.layers.to_a.empty?) }
fm = Sketchup::Model.new
fm.definitions.define_singleton_method(:add) { |*| raise 'lỗi giả lập khi tạo định nghĩa' }
ok('lỗi khi dựng: hủy thao tác', error_of { O.build(fm, state_with(OPS), ['sl_00000001']) }.to_s.include?('giả lập') && fm.operations.last == [:abort] && !fm.operations.include?([:commit]))
lm = Sketchup::Model.new
O.build(lm, state_with(OPS), ['sl_00000001'])
groups(lm, 'openings').first.lock!
ops = lm.operations.size
ok('nhóm cửa bị khóa: từ chối, không mở thao tác; xóa cũng từ chối', error_of { O.build(lm, state_with(OPS), ['sl_00000001']) }.to_s.include?('khóa') && lm.operations.size == ops && error_of { O.remove(lm) }.to_s.include?('khóa'))
ok('xóa cửa: một thao tác; xóa khi chưa có: 0, không mở thao tác', (rm = Sketchup::Model.new) && O.build(rm, state_with(OPS), ['sl_00000001']) && O.remove(rm, 'sl_00000001') == 1 && groups(rm, 'openings').empty? && rm.operations.last == [:commit] && (n = rm.operations.size) && O.remove(rm) == 0 && rm.operations.size == n)
om = Sketchup::Model.new
st2 = state_with(OPS)
st2['levels'].push(deep(st2['levels'][1]).merge('id' => 'sl_00000003', 'name' => 'Mái', 'elevation' => 7200.0))
st2['levels'][1]['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => {'x:B:2-3' => {}}, 'slabs' => {}, 'ceilings' => {}, 'openings' => {'op_00000009' => op('x:B:2-3', DOOR, 1950)}}
st2['levels'][1]['picks']['columns'] = st2['levels'][0]['picks']['columns'].dup
O.build(om, st2, %w[sl_00000001 sl_00000002])
st3 = deep(st2); st3['levels'].delete_at(1)
r = O.build(om, st3, ['sl_00000001'])
ok('tầng 2 bị xóa khỏi danh sách: nhóm cửa tầng 2 được dọn', groups(om, 'openings').map(&:name) == ['Cửa - Tầng 1'] && r.removed_orphans == 1)
# Cửa sai thì bỏ nhưng vẫn dựng cửa hợp lệ, báo trong kết quả
mix = Sketchup::Model.new
rmix = O.build(mix, state_with(OPS.merge('op_00000004' => op('x:B:2-3', DOOR, 100))), ['sl_00000001'])
ok('có một cửa sai vị trí (vượt đầu tường): vẫn dựng 3 cửa hợp lệ, kết quả có cảnh báo', rmix.total == 3 && rmix.issues.any? { |m| m.include?('vượt ra ngoài') })
# Dựng tất cả có cả cửa, một thao tác
ma = Sketchup::Model.new
full = state_with(OPS)
S::AllBuilder.build(ma, full, ['sl_00000001'])
names = ma.entities.grep(Sketchup::Group).map(&:name)
ok('dựng tất cả gồm cả cửa trong MỘT bước hoàn tác; thứ tự: cột, dầm, tường, cửa', names.include?('Cửa - Tầng 1') && names.include?('Tường - Tầng 1') && ma.operations == [[:start, 'VGD Structure · Dựng kết cấu'], [:commit]])
ok('không có cửa nào thì dựng tất cả bỏ qua loại cửa (không lỗi)', (mb = Sketchup::Model.new) && S::AllBuilder.build(mb, state_with({}), ['sl_00000001']) && mb.entities.grep(Sketchup::Group).none? { |x| x.name.start_with?('Cửa') })
ck = S::Checker.run(S::State.normalize!(state_with(OPS.merge('op_00000004' => op('x:B:2-3', DOOR, 100)))))
ok('kiểm tra kết cấu gom cảnh báo cửa và đếm số cửa', ck[:levels][0][:counts]['openings'] == 4 && ck[:levels][0][:warnings].any? { |m| m.start_with?('Cửa:') && m.include?('vượt ra ngoài') })
puts $fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
