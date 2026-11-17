# Test dựng dầm (beam_builder.rb) bằng SketchUp giả lập: nhóm theo tầng, ComponentInstance dùng chung định nghĩa theo (phương, rộng, cao, dài), vị trí và cao độ,
# dữ liệu BIM đọc, tag S. BEAM, một bước hoàn tác, dựng lại thay nhóm, dọn nhóm mồ côi, lỗi giữ model nguyên. Chạy: ruby dev/test_beam_builder.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[core/schema core/grid core/axis_symbol core/column_types core/beam_types core/wall_types core/levels core/column_plan core/beam_plan core/wall_plan core/state core/preview model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
B = S::BeamBuilder
D = S::Schema::DICTIONARY
MM = 25.4
def deep(x); Marshal.load(Marshal.dump(x)); end
def state_with(beam_refs, col_refs = nil)
  st = S::State.default
  cols = col_refs || S::Grid.intersections(st['grid']).map { |i| i[:ref] }
  st['levels'][0]['picks'] = {'columns' => cols.each_with_object({}) { |r, h| h[r] = {} }, 'beams' => beam_refs.each_with_object({}) { |r, h| h[r] = {} }}
  st
end
def groups(m); m.entities.grep(Sketchup::Group); end
ALL = S::Grid.spans(S::Grid.default).map { |sp| sp[:ref] }

m = Sketchup::Model.new
res = B.build(m, state_with(ALL), ['sl_00000001'])
g = groups(m)
ok('dựng tầng 1: một nhóm "Dầm - Tầng 1" ghi kind = beams và mã tầng', g.size == 1 && g[0].name == 'Dầm - Tầng 1' && g[0].get_attribute(D, 'kind') == 'beams' && g[0].get_attribute(D, 'level') == 'sl_00000001')
ok('một bước hoàn tác', m.operations == [[:start, 'VGD Structure · Dựng dầm'], [:commit]])
inst = g[0].entities.grep(Sketchup::Instance)
ok('17 dầm là ComponentInstance tên "Dầm <nhịp> (<tầng>)"', inst.size == 17 && inst.map(&:name).include?('Dầm x:B:2-3 (Tầng 1)'))
names = m.definitions.list.map(&:name)
ok('định nghĩa dùng chung theo (phương, rộng, cao, dài): dầm X 3900 dùng chung cho các nhịp giữa, có cả dầm Y', names.include?('VGD Dầm X 200x400x3900') && names.any? { |n| n.start_with?('VGD Dầm Y 200x400x') } && m.definitions.list.size < 17)
shared = inst.select { |i| i.definition.name == 'VGD Dầm X 200x400x3900' }
ok('nhiều dầm cùng kích thước thật sự dùng chung một định nghĩa', shared.size >= 2 && shared.map(&:definition).uniq.size == 1)
bx = inst.find { |i| i.name.include?('x:B:2-3') }
mmv = ->(i) { [i.transformation.vector.x * MM, i.transformation.vector.y * MM, i.transformation.vector.z * MM].map { |v| v.round(3) } }
ok('dầm x:B:2-3 đặt tại (4350, 3600, đáy 3080): gốc ở tâm đầu dầm', mmv.call(bx) == [4350.0, 3600.0, 3080.0])
by = inst.find { |i| i.name.include?('y:2:A-B') }
ok('dầm Y y:2:A-B đặt tại (4200, 300, 3080)', mmv.call(by) == [4200.0, 300.0, 3080.0])
ba = inst.find { |i| i.name.include?('x:A:1-2') }
ok('dầm biên x:A:1-2 đặt tại (300, 100, 3080): mặt ngoài tiếp giáp trục A (y từ 0 đến 200)', mmv.call(ba) == [300.0, 100.0, 3080.0])
defn = bx.definition
face = defn.entities.grep(Sketchup::Face).first
ok('định nghĩa dầm X: mặt đáy hướng lên, đùn cao 400 mm, dài 3900 theo +X, rộng 200 theo Y', face.normal.z > 0 && (face.height * MM - 400).abs < 1e-6 && face.points.map(&:x).minmax.map { |v| (v * MM).round(3) } == [0.0, 3900.0] && face.points.map(&:y).minmax.map { |v| (v * MM).round(3) } == [-100.0, 100.0])
fy = by.definition.entities.grep(Sketchup::Face).first
ok('định nghĩa dầm Y: dài theo +Y (từ 0 đến 3150), rộng 200 theo X', fy.points.map(&:y).minmax.map { |v| (v * MM).round(3) } == [0.0, 3150.0] && fy.points.map(&:x).minmax.map { |v| (v * MM).round(3) } == [-100.0, 100.0] && fy.normal.z > 0)
ok('dữ liệu BIM đọc: nguồn plugin, kind beam, ref kèm mã tầng; kích thước, loại, vị trí ở VGD_STRUCT', bx.get_attribute('VGD_BIM_SOURCE', 'kind') == 'beam' && bx.get_attribute('VGD_BIM_SOURCE', 'ref') == 'sl_00000001:x:B:2-3' && JSON.parse(bx.get_attribute(D, 'dims')) == {'w' => 200.0, 'h' => 400.0, 'length' => 3900.0} && bx.get_attribute(D, 'type') == 'D20x40' && JSON.parse(bx.get_attribute(D, 'placement')) == {'position' => 'inner', 'p' => 'center', 'dir' => 'x'})
tag = m.layers['S. BEAM']
ok('tag S. BEAM theo bộ tag mẫu: màu (0, 170, 186), thư mục S. STRUCTURAL; nhóm và dầm trên tag', tag && tag.color.rgb == [0, 170, 186] && tag.folder.name == 'S. STRUCTURAL' && g[0].layer.equal?(tag) && inst.all? { |i| i.layer.equal?(tag) })
ok('kết quả: 1 tầng, 17 dầm, không cảnh báo', res.levels == [{name: 'Tầng 1', count: 17, top: 3480.0}] && res.total == 17 && res.issues.empty?)
ok('dựng dầm lưu dữ liệu nguồn (loại dầm, lựa chọn) vào model', S::ModelStore.read(m)['levels'][0]['picks']['beams'].size == 17 && S::ModelStore.read(m)['beam_types'] == S::BeamTypes.default)

# Dựng lại
old = g[0]
B.build(m, state_with(%w[x:B:2-3]), ['sl_00000001'])
ok('dựng lại thay nhóm cũ: còn một nhóm với 1 dầm; thao tác riêng', !old.valid? && groups(m).size == 1 && groups(m)[0].entities.grep(Sketchup::Instance).size == 1 && m.operations.count { |o| o[0] == :commit } == 2 && m.layers.count { |l| l.name == 'S. BEAM' } == 1)

# Cột và dầm cùng tầng không đụng nhau
cm = Sketchup::Model.new
st = state_with(ALL)
S::ColumnBuilder.build(cm, st, ['sl_00000001'])
B.build(cm, st, ['sl_00000001'])
ok('cột và dầm cùng tầng là hai nhóm riêng, dựng dầm không xóa cột (và ngược lại)', groups(cm).map(&:name).sort == ['Cột - Tầng 1', 'Dầm - Tầng 1'])
S::ColumnBuilder.build(cm, st, ['sl_00000001'])
ok('dựng lại cột không đụng nhóm dầm; dọn mồ côi cột không xóa nhóm dầm', groups(cm).map(&:name).sort == ['Cột - Tầng 1', 'Dầm - Tầng 1'])
B.remove(cm, 'sl_00000001')
ok('xóa dầm không xóa cột', groups(cm).map(&:name) == ['Cột - Tầng 1'])
ok('xóa cột không xóa dầm', (B.build(cm, st, ['sl_00000001']); S::ColumnBuilder.remove(cm) == 1 && groups(cm).map(&:name) == ['Dầm - Tầng 1']))

# Mồ côi
om = Sketchup::Model.new
st2 = S::State.default
st2['levels'] = [{'id' => 'sl_00000001', 'name' => 'Tầng 1', 'elevation' => 0, 'slab_thickness' => 120, 'column_type' => nil, 'beam_type' => nil, 'picks' => {'columns' => {}, 'beams' => {'x:B:1-2' => {}}}},
                 {'id' => 'sl_00000002', 'name' => 'Tầng 2', 'elevation' => 3600, 'slab_thickness' => 120, 'column_type' => nil, 'beam_type' => nil, 'picks' => {'columns' => {}, 'beams' => {'x:B:1-2' => {}}}},
                 {'id' => 'sl_00000003', 'name' => 'Mái', 'elevation' => 7200, 'slab_thickness' => 100, 'column_type' => nil, 'beam_type' => nil, 'picks' => {'columns' => {}, 'beams' => {}}}]
r = B.build(om, st2, %w[sl_00000001 sl_00000002])
ok('hai tầng: hai nhóm (mỗi tầng một dầm), một thao tác hoàn tác', groups(om).map(&:name).sort == ['Dầm - Tầng 1', 'Dầm - Tầng 2'] && r.total == 2 && om.operations.count { |o| o[0] == :start } == 1)
st3 = deep(st2); st3['levels'].delete_at(1); st3['levels'][1]['elevation'] = 7200
r = B.build(om, st3, ['sl_00000001'])
ok('tầng 2 bị xóa khỏi danh sách: nhóm dầm của tầng 2 được dọn', groups(om).map(&:name) == ['Dầm - Tầng 1'] && r.removed_orphans == 1)

# Từ chối trước khi đụng model
bad = Sketchup::Model.new
checks = {'tầng trên cùng' => [state_with(ALL), ['sl_00000002']], 'không chọn tầng' => [state_with(ALL), []], 'chưa chọn dầm nào' => [S::State.default, ['sl_00000001']],
          'tầng không tồn tại' => [state_with(ALL), ['sl_deadbeef']], 'dữ liệu sai' => [{'grid' => 5}, ['sl_00000001']],
          'loại dầm sai' => [state_with(ALL).merge('beam_types' => [{'id' => 'x'}]), ['sl_00000001']],
          'dầm cao hơn tầng' => [state_with(ALL).tap { |s| s['beam_types'][0]['h'] = 2000; s['levels'][1]['elevation'] = 1500 }, ['sl_00000001']]}
checks.each { |label, (s, ids)| ok("dữ liệu sai bị từ chối, model không đổi: #{label}", !error_of { B.build(bad, s, ids) }.nil? && bad.operations.empty? && groups(bad).empty? && bad.layers.to_a.empty?) }
fm = Sketchup::Model.new
fm.definitions.define_singleton_method(:add) { |*| raise 'lỗi giả lập khi tạo định nghĩa' }
msg = error_of { B.build(fm, state_with(ALL), ['sl_00000001']) }
ok('lỗi khi dựng: hủy thao tác, báo lỗi', msg.to_s.include?('giả lập') && fm.operations.last == [:abort] && !fm.operations.include?([:commit]))
lm = Sketchup::Model.new
B.build(lm, state_with(ALL), ['sl_00000001'])
groups(lm).first.lock!
ops = lm.operations.size
ok('nhóm dầm của tầng bị khóa: từ chối, không mở thao tác, không xóa', error_of { B.build(lm, state_with(ALL), ['sl_00000001']) }.to_s.include?('khóa') && lm.operations.size == ops && error_of { B.remove(lm) }.to_s.include?('khóa'))
ok('xóa khi chưa có: 0, không mở thao tác', (e = Sketchup::Model.new) && B.remove(e) == 0 && e.operations.empty?)

# Cảnh báo kèm kết quả
wm = Sketchup::Model.new
sw = state_with(%w[x:A:1-2])
sw['levels'][0]['picks']['beams']['x:A:1-2'] = {'p' => 'center'}
rw = B.build(wm, sw, ['sl_00000001'])
ok('dầm đặt tâm trên trục biên: dựng được nhưng kết quả có cảnh báo nhô ra', rw.issues.any? { |m| m.include?('nhô ra') })
# Tag có sẵn
tm = Sketchup::Model.new
pre = tm.layers.add('S. BEAM'); pre.color = :user_color
B.build(tm, state_with(ALL), ['sl_00000001'])
ok('tag S. BEAM đã có: giữ màu của người dùng', tm.layers['S. BEAM'].equal?(pre) && pre.color == :user_color)
puts $fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
