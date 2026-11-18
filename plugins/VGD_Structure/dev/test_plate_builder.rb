# Test dựng sàn và trần (plate_builder.rb) bằng SketchUp giả lập: nhóm theo tầng, định nghĩa dùng chung, vị trí và cao độ, đa giác trần khoét góc, dữ liệu BIM đọc,
# tag S. SLAB / A. FINISHING CEILING, một bước hoàn tác, dựng lại, dọn mồ côi, lỗi giữ model nguyên. Chạy: ruby dev/test_plate_builder.rb (chưa xác minh trong SketchUp thật)
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/levels core/column_plan core/beam_plan core/wall_plan core/opening_plan core/plates core/slab_plan core/ceiling_plan core/proposal core/checker core/state core/preview model_sync model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder all_builder].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
P = S::PlateBuilder
D = S::Schema::DICTIONARY
MM = 25.4
def deep(x); Marshal.load(Marshal.dump(x)); end
CELLS = S::Grid.cells(S::Grid.default).map { |c| c[:ref] }
def state_with(picks, extra = {})
  st = S::State.default
  st['levels'][0]['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => {}, 'slabs' => {}, 'ceilings' => {}}.merge(picks)
  st['levels'][0].merge!(extra)
  st
end
def cellmap(refs); refs.each_with_object({}) { |r, h| h[r] = {} }; end
def groups(m, kind); m.entities.grep(Sketchup::Group).select { |g| g.get_attribute(S::Schema::DICTIONARY, 'kind') == kind }; end
mmv = ->(i) { [i.transformation.vector.x * MM, i.transformation.vector.y * MM, i.transformation.vector.z * MM].map { |v| v.round(3) } }

# Sàn
m = Sketchup::Model.new
res = P.build(m, state_with('slabs' => cellmap(CELLS)), ['sl_00000001'], 'slabs')
g = groups(m, 'slabs')
ok('dựng sàn tầng 1: một nhóm "Sàn - Tầng 1" ghi kind = slabs và mã tầng', g.size == 1 && g[0].name == 'Sàn - Tầng 1' && g[0].get_attribute(D, 'level') == 'sl_00000001')
ok('một bước hoàn tác', m.operations == [[:start, 'VGD Structure · Dựng sàn'], [:commit]])
inst = g[0].entities.grep(Sketchup::Instance)
ok('6 sàn là ComponentInstance tên "Sàn <ô> (<tầng>)"', inst.size == 6 && inst.map(&:name).include?('Sàn 1-2/A-B (Tầng 1)'))
names = m.definitions.list.map(&:name)
ok('định nghĩa dùng chung theo (đa giác, dày): các ô cùng kích thước dùng chung (ít hơn 6 định nghĩa)', m.definitions.list.size < 6 && names.all? { |n| n.start_with?('VGD Sàn ') })
s1 = inst.find { |i| i.name.include?('1-2/A-B') }
ok('sàn ô 1-2/A-B đặt tại (0, 0) với đáy ở -120 (mặt trên tại cao độ tầng 0)', mmv.call(s1) == [0.0, 0.0, -120.0])
s2 = inst.find { |i| i.name.include?('2-3/B-C') }
ok('sàn ô 2-3/B-C đặt tại (4200, 3600, -120)', mmv.call(s2) == [4200.0, 3600.0, -120.0])
face = s1.definition.entities.grep(Sketchup::Face).first
ok('định nghĩa sàn: hình chữ nhật 4200 x 3600, mặt đáy hướng lên, đùn 120', face.normal.z > 0 && (face.height * MM - 120).abs < 1e-6 && face.points.map(&:x).minmax.map { |v| (v * MM).round(3) } == [0.0, 4200.0] && face.points.map(&:y).minmax.map { |v| (v * MM).round(3) } == [0.0, 3600.0])
ok('dữ liệu BIM đọc: kind slab, ref kèm mã tầng, dày và diện tích', s1.get_attribute('VGD_BIM_SOURCE', 'kind') == 'slab' && s1.get_attribute('VGD_BIM_SOURCE', 'ref') == 'sl_00000001:1-2/A-B' && JSON.parse(s1.get_attribute(D, 'dims')) == {'thickness' => 120.0, 'area' => 15.12, 'z_top' => 0.0})
tag = m.layers['S. SLAB']
ok('tag S. SLAB theo bộ tag mẫu: màu (186, 51, 0), thư mục S. STRUCTURAL; nhóm và sàn trên tag', tag && tag.color.rgb == [186, 51, 0] && tag.folder.name == 'S. STRUCTURAL' && g[0].layer.equal?(tag) && inst.all? { |i| i.layer.equal?(tag) })
ok('kết quả: 6 sàn', res.total == 6 && res.levels == [{name: 'Tầng 1', count: 6}])
ok('dựng sàn lưu dữ liệu nguồn vào model', S::ModelStore.read(m)['levels'][0]['picks']['slabs'].size == 6)

# Sàn tầng trên cùng được
tm = Sketchup::Model.new
st = state_with({})
st['levels'][1]['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => {}, 'slabs' => cellmap(%w[1-2/A-B]), 'ceilings' => {}}
P.build(tm, st, ['sl_00000002'], 'slabs')
ok('dựng sàn tầng trên cùng: đặt ở đáy 3480 (mặt trên 3600)', mmv.call(groups(tm, 'slabs')[0].entities.grep(Sketchup::Instance).first) == [0.0, 0.0, 3480.0])

# Trần
cm = Sketchup::Model.new
cols = S::Grid.intersections(S::Grid.default).each_with_object({}) { |i, h| h[i[:ref]] = {} }
cres = P.build(cm, state_with('columns' => cols, 'ceilings' => cellmap(%w[1-2/A-B 2-3/B-C])), ['sl_00000001'], 'ceilings')
cg = groups(cm, 'ceilings')
ci = cg[0].entities.grep(Sketchup::Instance)
ok('dựng trần: nhóm "Trần - Tầng 1", 2 trần, thao tác riêng', cg.size == 1 && cg[0].name == 'Trần - Tầng 1' && ci.size == 2 && cm.operations == [[:start, 'VGD Structure · Dựng trần'], [:commit]])
c1 = ci.find { |i| i.name.include?('1-2/A-B') }
ok('trần ô 1-2/A-B: đáy ở 2800, đặt tại góc nhỏ (0, 0)', mmv.call(c1) == [0.0, 0.0, 2800.0])
cface = c1.definition.entities.grep(Sketchup::Face).first
ok('trần có khoét góc theo cột (12 đỉnh), mặt đáy hướng lên dù đa giác có đỉnh lõm, dày 9', cface.points.size == 12 && cface.normal.z > 0 && (cface.height * MM - 9).abs < 1e-6)
ok('dữ liệu BIM đọc: kind ceiling; tag A. FINISHING CEILING (màu 153, 0, 255; thư mục A. ARCHITECTURAL)', c1.get_attribute('VGD_BIM_SOURCE', 'kind') == 'ceiling' && cm.layers['A. FINISHING CEILING'].color.rgb == [153, 0, 255] && cm.layers['A. FINISHING CEILING'].folder.name == 'A. ARCHITECTURAL')
ok('trần cùng tầng với sàn hoặc cột là nhóm riêng (không đụng nhau)', (P.build(cm, state_with('slabs' => cellmap(CELLS), 'ceilings' => cellmap(%w[1-2/A-B])), ['sl_00000001'], 'slabs')) && groups(cm, 'slabs').size == 1 && groups(cm, 'ceilings').size == 1)
P.build(cm, state_with('slabs' => cellmap(CELLS), 'ceilings' => cellmap(%w[1-2/A-B])), ['sl_00000001'], 'ceilings')
ok('dựng lại trần không xóa sàn; xóa sàn không xóa trần', groups(cm, 'slabs').size == 1 && P.remove(cm, 'slabs') == 1 && groups(cm, 'ceilings').size == 1 && groups(cm, 'slabs').empty?)

# Dựng lại, mồ côi
rm = Sketchup::Model.new
P.build(rm, state_with('slabs' => cellmap(CELLS)), ['sl_00000001'], 'slabs')
old = groups(rm, 'slabs')[0]
P.build(rm, state_with('slabs' => cellmap(%w[1-2/A-B])), ['sl_00000001'], 'slabs')
ok('dựng lại thay nhóm cũ: còn một nhóm với 1 sàn; thao tác riêng; không thêm tag', !old.valid? && groups(rm, 'slabs').size == 1 && groups(rm, 'slabs')[0].entities.grep(Sketchup::Instance).size == 1 && rm.layers.count { |l| l.name == 'S. SLAB' } == 1)
om = Sketchup::Model.new
st2 = state_with('slabs' => cellmap(%w[1-2/A-B]))
st2['levels'].push(deep(st2['levels'][1]).merge('id' => 'sl_00000003', 'name' => 'Mái', 'elevation' => 7200.0))
st2['levels'][1]['picks']['slabs'] = cellmap(%w[1-2/A-B])
P.build(om, st2, %w[sl_00000001 sl_00000002], 'slabs')
ok('hai tầng: hai nhóm sàn trong một thao tác hoàn tác', groups(om, 'slabs').map(&:name).sort == ['Sàn - Tầng 1', 'Sàn - Tầng 2'] && om.operations.count { |o| o[0] == :start } == 1)
st3 = deep(st2); st3['levels'].delete_at(1)
r = P.build(om, st3, ['sl_00000001'], 'slabs')
ok('tầng 2 bị xóa khỏi danh sách: nhóm sàn tầng 2 được dọn', groups(om, 'slabs').map(&:name) == ['Sàn - Tầng 1'] && r.removed_orphans == 1)

# Từ chối trước khi đụng model
bad = Sketchup::Model.new
checks = {['slabs', 'chưa chọn ô'] => [S::State.default, ['sl_00000001']], ['slabs', 'không chọn tầng'] => [state_with('slabs' => cellmap(CELLS)), []], ['slabs', 'tầng không tồn tại'] => [state_with('slabs' => cellmap(CELLS)), ['sl_deadbeef']],
          ['slabs', 'dữ liệu sai'] => [{'grid' => 5}, ['sl_00000001']], ['ceilings', 'tầng trên cùng'] => [state_with('ceilings' => cellmap(CELLS)), ['sl_00000002']],
          ['ceilings', 'cao trần vượt đáy sàn tầng trên'] => [state_with({'ceilings' => cellmap(CELLS)}, 'ceiling_height' => 3475), ['sl_00000001']], ['ceilings', 'chưa chọn ô'] => [S::State.default, ['sl_00000001']]}
checks.each { |(kind, label), (s, ids)| ok("dữ liệu sai bị từ chối (#{kind}), model không đổi: #{label}", !error_of { P.build(bad, s, ids, kind) }.nil? && bad.operations.empty? && groups(bad, kind).empty? && bad.layers.to_a.empty?) }
ok('loại tấm lạ bị từ chối', !error_of { P.build(bad, S::State.default, ['sl_00000001'], 'floors') }.nil?)
fm = Sketchup::Model.new
fm.definitions.define_singleton_method(:add) { |*| raise 'lỗi giả lập khi tạo định nghĩa' }
msg = error_of { P.build(fm, state_with('slabs' => cellmap(CELLS)), ['sl_00000001'], 'slabs') }
ok('lỗi khi dựng: hủy thao tác, báo lỗi', msg.to_s.include?('giả lập') && fm.operations.last == [:abort] && !fm.operations.include?([:commit]))
lm = Sketchup::Model.new
P.build(lm, state_with('slabs' => cellmap(CELLS)), ['sl_00000001'], 'slabs')
groups(lm, 'slabs').first.lock!
ops = lm.operations.size
ok('nhóm sàn của tầng bị khóa: từ chối, không mở thao tác, không xóa', error_of { P.build(lm, state_with('slabs' => cellmap(CELLS)), ['sl_00000001'], 'slabs') }.to_s.include?('khóa') && lm.operations.size == ops && error_of { P.remove(lm, 'slabs') }.to_s.include?('khóa'))
ok('xóa khi chưa có: 0, không mở thao tác', (e = Sketchup::Model.new) && P.remove(e, 'slabs') == 0 && e.operations.empty?)
tg = Sketchup::Model.new
pre = tg.layers.add('S. SLAB'); pre.color = :user_color
P.build(tg, state_with('slabs' => cellmap(CELLS)), ['sl_00000001'], 'slabs')
ok('tag S. SLAB đã có: giữ màu của người dùng', tg.layers['S. SLAB'].equal?(pre) && pre.color == :user_color)
puts $fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
