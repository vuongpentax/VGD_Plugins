# Test dựng tường (wall_builder.rb) bằng SketchUp giả lập: nhóm theo tầng, ComponentInstance dùng chung định nghĩa theo (phương, dày, cao, dài), vị trí và
# cao độ (từ mặt sàn, lên đáy dầm nếu có dầm), dữ liệu BIM đọc, tag A. WALL, một bước hoàn tác, dựng lại, dọn mồ côi, lỗi giữ model nguyên.
# Chạy: ruby dev/test_wall_builder.rb (phần dựng thật chưa xác minh trong SketchUp)
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[core/schema core/grid core/axis_symbol core/column_types core/beam_types core/wall_types core/levels core/column_plan core/beam_plan core/wall_plan core/slab_plan core/ceiling_plan core/proposal core/checker core/state core/preview model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder plate_builder all_builder].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
B = S::WallBuilder
D = S::Schema::DICTIONARY
MM = 25.4
def deep(x); Marshal.load(Marshal.dump(x)); end
ALL = S::Grid.spans(S::Grid.default).map { |sp| sp[:ref] }
def state_with(wall_refs, beam_refs = [])
  st = S::State.default
  cols = S::Grid.intersections(st['grid']).each_with_object({}) { |i, h| h[i[:ref]] = {} }
  st['levels'][0]['picks'] = {'columns' => cols, 'beams' => beam_refs.each_with_object({}) { |r, h| h[r] = {} }, 'walls' => wall_refs.each_with_object({}) { |r, h| h[r] = {} }}
  st
end
def groups(m); m.entities.grep(Sketchup::Group); end
mmv = ->(i) { [i.transformation.vector.x * MM, i.transformation.vector.y * MM, i.transformation.vector.z * MM].map { |v| v.round(3) } }

m = Sketchup::Model.new
res = B.build(m, state_with(ALL), ['sl_00000001'])
g = groups(m)
ok('dựng tầng 1: một nhóm "Tường - Tầng 1" ghi kind = walls và mã tầng', g.size == 1 && g[0].name == 'Tường - Tầng 1' && g[0].get_attribute(D, 'kind') == 'walls' && g[0].get_attribute(D, 'level') == 'sl_00000001')
ok('một bước hoàn tác', m.operations == [[:start, 'VGD Structure · Dựng tường'], [:commit]])
inst = g[0].entities.grep(Sketchup::Instance)
ok('17 tường là ComponentInstance tên "Tường <nhịp> (<tầng>)"', inst.size == 17 && inst.map(&:name).include?('Tường x:B:2-3 (Tầng 1)'))
names = m.definitions.list.map(&:name)
ok('định nghĩa dùng chung theo (phương, dày, cao, dài): tường X 3900 dùng chung, có cả tường Y; ít định nghĩa hơn số tường', names.include?('VGD Tường X 200x3480x3900') && names.any? { |n| n.start_with?('VGD Tường Y 200x3480x') } && m.definitions.list.size < 17)
bx = inst.find { |i| i.name.include?('x:B:2-3') }
ok('tường x:B:2-3 đặt tại (4350, 3600, 0): từ mặt sàn tầng 1, gốc ở tâm đầu tường', mmv.call(bx) == [4350.0, 3600.0, 0.0])
ok('tường biên x:A:1-2 đặt tại (300, 100, 0): mặt ngoài tiếp giáp trục A', mmv.call(inst.find { |i| i.name.include?('x:A:1-2') }) == [300.0, 100.0, 0.0])
ok('tường Y y:2:A-B đặt tại (4200, 300, 0)', mmv.call(inst.find { |i| i.name.include?('y:2:A-B') }) == [4200.0, 300.0, 0.0])
face = bx.definition.entities.grep(Sketchup::Face).first
ok('định nghĩa tường X: mặt đáy hướng lên, đùn cao 3480, dài 3900 theo +X, dày 200 theo Y', face.normal.z > 0 && (face.height * MM - 3480).abs < 1e-6 && face.points.map(&:x).minmax.map { |v| (v * MM).round(3) } == [0.0, 3900.0] && face.points.map(&:y).minmax.map { |v| (v * MM).round(3) } == [-100.0, 100.0])
ok('dữ liệu BIM đọc: nguồn plugin, kind wall, ref kèm mã tầng; kích thước, loại, vị trí, dưới dầm ở VGD_STRUCT', bx.get_attribute('VGD_BIM_SOURCE', 'kind') == 'wall' && bx.get_attribute('VGD_BIM_SOURCE', 'ref') == 'sl_00000001:x:B:2-3' && JSON.parse(bx.get_attribute(D, 'dims')) == {'thickness' => 200.0, 'height' => 3480.0, 'length' => 3900.0, 'under_beam' => false} && bx.get_attribute(D, 'type') == 'T200' && JSON.parse(bx.get_attribute(D, 'placement')) == {'position' => 'inner', 'p' => 'center', 'dir' => 'x'})
tag = m.layers['A. WALL']
ok('tag A. WALL theo bộ tag mẫu: màu (255, 153, 102), thư mục A. ARCHITECTURAL; nhóm và tường trên tag', tag && tag.color.rgb == [255, 153, 102] && tag.folder.name == 'A. ARCHITECTURAL' && g[0].layer.equal?(tag) && inst.all? { |i| i.layer.equal?(tag) })
ok('kết quả: 17 tường, không cảnh báo', res.total == 17 && res.levels == [{name: 'Tầng 1', count: 17, top: 3480.0}] && res.issues.empty?)
ok('dựng tường lưu dữ liệu nguồn (loại tường, lựa chọn) vào model', S::ModelStore.read(m)['levels'][0]['picks']['walls'].size == 17 && S::ModelStore.read(m)['wall_types'] == S::WallTypes.default)

# Có dầm: tường cao tới đáy dầm
bm = Sketchup::Model.new
B.build(bm, state_with(%w[x:B:2-3 x:B:3-4], %w[x:B:2-3]), ['sl_00000001'])
bi = groups(bm)[0].entities.grep(Sketchup::Instance)
ok('nhịp có dầm: tường cao 3080 (đáy dầm); nhịp không dầm: cao 3480; định nghĩa riêng theo chiều cao', bm.definitions.list.map(&:name).sort == ['VGD Tường X 200x3080x3900', 'VGD Tường X 200x3480x3750'] && JSON.parse(bi.find { |i| i.name.include?('x:B:2-3') }.get_attribute(D, 'dims'))['under_beam'] == true)

# Dựng lại, không đụng cột và dầm
old = g[0]
B.build(m, state_with(%w[x:B:2-3]), ['sl_00000001'])
ok('dựng lại thay nhóm cũ: một nhóm với 1 tường; thao tác riêng; không thêm tag', !old.valid? && groups(m).size == 1 && groups(m)[0].entities.grep(Sketchup::Instance).size == 1 && m.operations.count { |o| o[0] == :commit } == 2 && m.layers.count { |l| l.name == 'A. WALL' } == 1)
cm = Sketchup::Model.new
st = state_with(ALL, ALL)
S::ColumnBuilder.build(cm, st, ['sl_00000001']); S::BeamBuilder.build(cm, st, ['sl_00000001']); B.build(cm, st, ['sl_00000001'])
ok('cột, dầm, tường cùng tầng là ba nhóm riêng', groups(cm).map(&:name).sort == ['Cột - Tầng 1', 'Dầm - Tầng 1', 'Tường - Tầng 1'])
S::ColumnBuilder.build(cm, st, ['sl_00000001']); S::BeamBuilder.build(cm, st, ['sl_00000001'])
ok('dựng lại cột hoặc dầm (kể cả dọn mồ côi) không xóa nhóm tường', groups(cm).map(&:name).sort == ['Cột - Tầng 1', 'Dầm - Tầng 1', 'Tường - Tầng 1'])
B.remove(cm, 'sl_00000001')
ok('xóa tường không xóa cột và dầm', groups(cm).map(&:name).sort == ['Cột - Tầng 1', 'Dầm - Tầng 1'])
B.build(cm, st, ['sl_00000001']); S::BeamBuilder.remove(cm); S::ColumnBuilder.remove(cm)
ok('xóa cột và dầm không xóa tường', groups(cm).map(&:name) == ['Tường - Tầng 1'])

# Mồ côi
om = Sketchup::Model.new
mk = ->(id, name, elev, walls) { {'id' => id, 'name' => name, 'elevation' => elev, 'slab_thickness' => 120, 'column_type' => nil, 'beam_type' => nil, 'wall_type' => nil, 'picks' => {'columns' => {}, 'beams' => {}, 'walls' => walls}} }
st2 = S::State.default
st2['levels'] = [mk.call('sl_00000001', 'Tầng 1', 0, {'x:B:1-2' => {}}), mk.call('sl_00000002', 'Tầng 2', 3600, {'x:B:1-2' => {}}), mk.call('sl_00000003', 'Mái', 7200, {})]
r = B.build(om, st2, %w[sl_00000001 sl_00000002])
ok('hai tầng: hai nhóm, một thao tác hoàn tác; tường tầng 2 đặt ở cao độ 3600', groups(om).map(&:name).sort == ['Tường - Tầng 1', 'Tường - Tầng 2'] && r.total == 2 && om.operations.count { |o| o[0] == :start } == 1 && (groups(om).find { |x| x.name == 'Tường - Tầng 2' }.entities.grep(Sketchup::Instance).first.transformation.vector.z * MM - 3600).abs < 1e-6)
st3 = deep(st2); st3['levels'].delete_at(1); st3['levels'][1]['elevation'] = 7200
r = B.build(om, st3, ['sl_00000001'])
ok('tầng 2 bị xóa khỏi danh sách: nhóm tường tầng 2 được dọn', groups(om).map(&:name) == ['Tường - Tầng 1'] && r.removed_orphans == 1)

# Từ chối trước khi đụng model
bad = Sketchup::Model.new
checks = {'tầng trên cùng' => [state_with(ALL), ['sl_00000002']], 'không chọn tầng' => [state_with(ALL), []], 'chưa chọn tường nào' => [S::State.default, ['sl_00000001']],
          'tầng không tồn tại' => [state_with(ALL), ['sl_deadbeef']], 'dữ liệu sai' => [{'grid' => 5}, ['sl_00000001']],
          'loại tường sai' => [state_with(ALL).merge('wall_types' => [{'id' => 'x'}]), ['sl_00000001']]}
checks.each { |label, (s, ids)| ok("dữ liệu sai bị từ chối, model không đổi: #{label}", !error_of { B.build(bad, s, ids) }.nil? && bad.operations.empty? && groups(bad).empty? && bad.layers.to_a.empty?) }
fm = Sketchup::Model.new
fm.definitions.define_singleton_method(:add) { |*| raise 'lỗi giả lập khi tạo định nghĩa' }
msg = error_of { B.build(fm, state_with(ALL), ['sl_00000001']) }
ok('lỗi khi dựng: hủy thao tác, báo lỗi', msg.to_s.include?('giả lập') && fm.operations.last == [:abort] && !fm.operations.include?([:commit]))
lm = Sketchup::Model.new
B.build(lm, state_with(ALL), ['sl_00000001'])
groups(lm).first.lock!
ops = lm.operations.size
ok('nhóm tường của tầng bị khóa: từ chối, không mở thao tác, không xóa', error_of { B.build(lm, state_with(ALL), ['sl_00000001']) }.to_s.include?('khóa') && lm.operations.size == ops && error_of { B.remove(lm) }.to_s.include?('khóa'))
ok('xóa khi chưa có: 0, không mở thao tác', (e = Sketchup::Model.new) && B.remove(e) == 0 && e.operations.empty?)
wm = Sketchup::Model.new
sw = state_with(%w[x:A:1-2]); sw['levels'][0]['picks']['walls']['x:A:1-2'] = {'p' => 'center'}
ok('tường đặt tâm trên trục biên: dựng được, kết quả có cảnh báo nhô ra', B.build(wm, sw, ['sl_00000001']).issues.any? { |x| x.include?('nhô ra') })
tm = Sketchup::Model.new
pre = tm.layers.add('A. WALL'); pre.color = :user_color
B.build(tm, state_with(ALL), ['sl_00000001'])
ok('tag A. WALL đã có: giữ màu của người dùng', tm.layers['A. WALL'].equal?(pre) && pre.color == :user_color)
puts $fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
