# Test dựng cột (column_builder.rb, tag_store.rb) bằng SketchUp giả lập: nhóm theo tầng, ComponentInstance dùng chung định nghĩa, vị trí và cao độ,
# dữ liệu BIM đọc, tag S. COLUMN theo bộ tag mẫu, một bước hoàn tác, dựng lại thay nhóm cũ, dọn nhóm mồ côi, lỗi giữ model nguyên.
# Chạy: ruby dev/test_column_builder.rb (phần dựng thật chưa xác minh trong SketchUp)
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[core/schema core/grid core/axis_symbol core/column_types core/beam_types core/wall_types core/levels core/column_plan core/beam_plan core/wall_plan core/slab_plan core/ceiling_plan core/proposal core/checker core/state core/preview model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder plate_builder all_builder].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
B = S::ColumnBuilder
D = S::Schema::DICTIONARY
MM = 25.4
def deep(x); Marshal.load(Marshal.dump(x)); end
def state_with_picks(refs = nil)
  st = S::State.default
  all = S::Grid.intersections(st['grid']).map { |i| i[:ref] }
  st['levels'][0]['picks']['columns'] = (refs || all).each_with_object({}) { |r, h| h[r] = {} }
  st
end
def groups(m); m.entities.grep(Sketchup::Group); end

m = Sketchup::Model.new
st = state_with_picks
res = B.build(m, st, ['sl_00000001'])
g = groups(m)
ok('dựng tầng 1: một nhóm "Cột - Tầng 1" ghi kind = columns và mã tầng', g.size == 1 && g[0].name == 'Cột - Tầng 1' && g[0].get_attribute(D, 'kind') == 'columns' && g[0].get_attribute(D, 'level') == 'sl_00000001')
ok('một bước hoàn tác (start rồi commit)', m.operations == [[:start, 'VGD Structure · Dựng cột'], [:commit]])
inst = g[0].entities.grep(Sketchup::Instance)
ok('12 cột là ComponentInstance, tên "Cột <ref> (<tầng>)"', inst.size == 12 && inst.map(&:name).include?('Cột 2-B (Tầng 1)'))
ok('mọi cột dùng chung MỘT định nghĩa 300x300x3480 (nhẹ model)', m.definitions.list.size == 1 && m.definitions.list[0].name == 'VGD Cột 300x300x3480' && inst.map(&:definition).uniq.size == 1)
defn = m.definitions.list[0]
face = defn.entities.grep(Sketchup::Face).first
ok('định nghĩa là lăng trụ: mặt đáy hướng lên, đùn cao 3480 mm, tâm đáy ở gốc', face.normal.z > 0 && (face.height * MM - 3480).abs < 1e-6 && face.points.map(&:x).minmax.map { |v| (v * MM).round(3) } == [-150.0, 150.0])
c2b = inst.find { |i| i.name.include?('2-B') }
ok('cột giữa 2-B đặt tại (4200, 3600, 0)', ((c2b.transformation.vector.x * MM) - 4200).abs < 1e-6 && ((c2b.transformation.vector.y * MM) - 3600).abs < 1e-6 && c2b.transformation.vector.z.abs < 1e-9)
c1a = inst.find { |i| i.name.include?('1-A') }
ok('cột góc 1-A tiếp giáp trục biên: tâm (150, 150)', ((c1a.transformation.vector.x * MM) - 150).abs < 1e-6 && ((c1a.transformation.vector.y * MM) - 150).abs < 1e-6)
ok('dữ liệu BIM đọc: nguồn plugin, kind column, ref kèm mã tầng', c2b.get_attribute('VGD_BIM_SOURCE', 'plugin') == 'vgd_structure' && c2b.get_attribute('VGD_BIM_SOURCE', 'kind') == 'column' && c2b.get_attribute('VGD_BIM_SOURCE', 'ref') == 'sl_00000001:2-B' && c2b.get_attribute('VGD_BIM_SOURCE', 'plugin_version') == '9.9.9')
ok('kích thước, loại, vị trí ghi ở VGD_STRUCT để BIM lập bảng', JSON.parse(c2b.get_attribute(D, 'dims')) == {'w' => 300.0, 'd' => 300.0, 'height' => 3480.0} && c2b.get_attribute(D, 'type') == 'C30x30' && JSON.parse(c2b.get_attribute(D, 'placement'))['position'] == 'middle' && c2b.get_attribute(D, 'level') == 'sl_00000001')
tag = m.layers['S. COLUMN']
ok('tag S. COLUMN theo bộ tag mẫu: màu (102, 221, 0), thư mục S. STRUCTURAL; nhóm và cột nằm trên tag', tag && tag.color.rgb == [102, 221, 0] && tag.folder.name == 'S. STRUCTURAL' && g[0].layer.equal?(tag) && inst.all? { |i| i.layer.equal?(tag) })
ok('kết quả: tầng, số cột, chiều cao', res.levels == [{name: 'Tầng 1', count: 12, height: 3480.0}] && res.total == 12 && res.issues.empty?)
ok('dựng cột lưu luôn dữ liệu nguồn (loại cột, tầng) vào model', S::ModelStore.read(m)['saved'] == true && S::ModelStore.read(m)['levels'][0]['picks']['columns'].size == 12)

# Dựng lại thay nhóm cũ
old = g[0]
st2 = state_with_picks(%w[1-A 2-B])
B.build(m, st2, ['sl_00000001'])
ok('dựng lại: nhóm cũ bị xóa, còn một nhóm mới 2 cột; thao tác thứ hai riêng', !old.valid? && groups(m).size == 1 && groups(m)[0].entities.grep(Sketchup::Instance).size == 2 && m.operations.count { |o| o[0] == :commit } == 2)
ok('dựng lại không tạo thêm tag hay định nghĩa trùng', m.layers.count { |l| l.name == 'S. COLUMN' } == 1 && m.definitions.list.size == 1)

# Nhiều tầng, định nghĩa khác theo chiều cao, một thao tác
m2 = Sketchup::Model.new
st3 = S::State.default
st3['levels'] = [{'id' => 'sl_00000001', 'name' => 'Tầng 1', 'elevation' => 0, 'slab_thickness' => 120, 'column_type' => nil, 'picks' => {'columns' => {'1-A' => {}, '2-A' => {}}}},
                 {'id' => 'sl_00000002', 'name' => 'Tầng 2', 'elevation' => 3600, 'slab_thickness' => 120, 'column_type' => nil, 'picks' => {'columns' => {'1-A' => {}, '2-A' => {}, '3-A' => {}}}},
                 {'id' => 'sl_00000003', 'name' => 'Mái', 'elevation' => 6900, 'slab_thickness' => 100, 'column_type' => nil, 'picks' => {'columns' => {}}}]
r = B.build(m2, st3, %w[sl_00000001 sl_00000002])
ok('hai tầng: hai nhóm, 2 + 3 cột, một thao tác hoàn tác duy nhất', groups(m2).map(&:name).sort == ['Cột - Tầng 1', 'Cột - Tầng 2'] && r.total == 5 && m2.operations.count { |o| o[0] == :start } == 1)
ok('chiều cao khác nhau cho hai định nghĩa riêng: 3480 (tầng 1) và 3200 (tầng 2: 6900 - 100 - 3600)', m2.definitions.list.map(&:name).sort == ['VGD Cột 300x300x3200', 'VGD Cột 300x300x3480'])
z2 = groups(m2).find { |x| x.name == 'Cột - Tầng 2' }.entities.grep(Sketchup::Instance).first
ok('cột tầng 2 đặt ở cao độ 3600 mm', (z2.transformation.vector.z * MM - 3600).abs < 1e-6)

# Dọn nhóm mồ côi (tầng đã xóa khỏi danh sách)
st4 = deep(st3); st4['levels'].delete_at(1)
st4['levels'][1]['elevation'] = 6900
r = B.build(m2, st4, ['sl_00000001'])
ok('tầng 2 đã bị xóa khỏi danh sách: nhóm cột tầng 2 được dọn', groups(m2).map(&:name) == ['Cột - Tầng 1'] && r.removed_orphans == 1)
locked_m = Sketchup::Model.new
B.build(locked_m, st3, ['sl_00000002'])
groups(locked_m).first.lock!
ok('nhóm mồ côi bị khóa thì giữ nguyên và đếm', (r2 = B.build(locked_m, st4, ['sl_00000001'])) && r2.locked_orphans == 1 && groups(locked_m).size == 2)

# Từ chối trước khi đụng model
bad = Sketchup::Model.new
checks = {
  'tầng trên cùng' => [st3, ['sl_00000003']], 'không chọn tầng' => [st3, []], 'mã tầng không phải mảng' => [st3, 'sl_00000001'],
  'tầng không tồn tại' => [st3, ['sl_deadbeef']], 'chưa chọn cột nào' => [S::State.default, ['sl_00000001']],
  'dữ liệu sai' => [{'grid' => 5}, ['sl_00000001']], 'loại cột sai' => [st3.merge('types' => [{'id' => 'x'}]), ['sl_00000001']],
  'chiều cao cột âm' => [deep(st3).tap { |s| s['levels'][1]['elevation'] = 600; s['levels'][1]['slab_thickness'] = 500 }, ['sl_00000001']]
}
checks.each { |label, (s, ids)| ok("dữ liệu sai bị từ chối, model không đổi: #{label}", !error_of { B.build(bad, s, ids) }.nil? && bad.operations.empty? && groups(bad).empty? && bad.layers.to_a.empty?) }
many = deep(st3); many['grid'] = S::Grid.normalize!('origin' => [0, 0], 'x_axes' => S::Grid.axes_from_spacings('4000*59', :number), 'y_axes' => S::Grid.axes_from_spacings('4000*59', :letter))
refs = S::Grid.intersections(many['grid']).map { |i| i[:ref] }
many['levels'][0]['picks']['columns'] = refs.each_with_object({}) { |r, h| h[r] = {} }
many['levels'][1]['picks']['columns'] = refs.first(1500).each_with_object({}) { |r, h| h[r] = {} }
many['levels'][2]['elevation'] = 10_200
ok('vượt 5000 cột trong một lần dựng bị từ chối trước khi đụng model', error_of { B.build(bad, many, %w[sl_00000001 sl_00000002]) }.to_s.include?('Quá nhiều') && bad.operations.empty?)

# Lỗi giữa chừng
fail_model = Sketchup::Model.new
fail_model.definitions.define_singleton_method(:add) { |*| raise 'lỗi giả lập khi tạo định nghĩa' }
msg = error_of { B.build(fail_model, st, ['sl_00000001']) }
ok('lỗi khi dựng: hủy thao tác (abort), báo lỗi', msg.to_s.include?('giả lập') && fail_model.operations.last == [:abort] && !fail_model.operations.include?([:commit]))
# Khóa
lm = Sketchup::Model.new
B.build(lm, st, ['sl_00000001'])
groups(lm).first.lock!
ops = lm.operations.size
ok('nhóm cột của tầng bị khóa: từ chối, không mở thao tác, không xóa', error_of { B.build(lm, st, ['sl_00000001']) }.to_s.include?('khóa') && lm.operations.size == ops && groups(lm).size == 1)

# Xóa cột
rm = Sketchup::Model.new
B.build(rm, st3, %w[sl_00000001 sl_00000002])
ok('xóa cột một tầng: chỉ nhóm tầng đó, một thao tác', B.remove(rm, 'sl_00000001') == 1 && groups(rm).map(&:name) == ['Cột - Tầng 2'] && rm.operations.last == [:commit])
ok('xóa mọi cột', B.remove(rm) == 1 && groups(rm).empty?)
ok('xóa khi chưa có: 0, không mở thao tác mới', (n = rm.operations.size) && B.remove(rm) == 0 && rm.operations.size == n)
B.build(rm, st3, ['sl_00000001'])
groups(rm).first.lock!
ok('xóa nhóm bị khóa: từ chối', error_of { B.remove(rm) }.to_s.include?('khóa'))

# Lưới vẽ lại giữ tầng và loại cột, bỏ lựa chọn ở giao điểm mất
gm = Sketchup::Model.new
B.build(gm, st, ['sl_00000001'])
small = S::Grid.normalize!('origin' => [0, 0], 'x_axes' => S::Grid.axes_from_spacings('4200', :number), 'y_axes' => S::Grid.axes_from_spacings('3600', :letter))
S::GridBuilder.build(gm, small, nil)
saved = S::ModelStore.read(gm)
ok('vẽ lại lưới nhỏ hơn: tầng và loại cột giữ nguyên, lựa chọn cột chỉ còn 4 giao điểm còn trên lưới', saved['levels'].size == 2 && saved['types'] == S::ColumnTypes.default && saved['levels'][0]['picks']['columns'].size == 4)

# Tag có sẵn không bị đổi
tm = Sketchup::Model.new
pre = tm.layers.add('S. COLUMN'); pre.color = :user_color
B.build(tm, st, ['sl_00000001'])
ok('tag S. COLUMN đã có: giữ màu và thư mục của người dùng', tm.layers['S. COLUMN'].equal?(pre) && pre.color == :user_color && pre.folder.nil?)

# Khớp bộ tag mẫu BIM
catalog = File.expand_path('../../VGD_BIM/runtime/vgd_bim/config/tag_catalog.json', __dir__)
if File.exist?(catalog)
  clusters = JSON.parse(File.read(catalog, encoding: 'bom|utf-8'))
  ok('mọi tag của 5 loại có trong bộ tag mẫu của BIM, đúng cụm', S::Schema::TAGS.values.all? { |t| clusters.find { |c| c['group'] == t[:folder] }&.fetch('tags')&.any? { |x| x['name'] == t[:name] } })
end
summary = File.expand_path('../../../docs/reference/5d_auto_tag/assets/default_tags_summary.json', __dir__)
if File.exist?(summary)
  tags = JSON.parse(File.read(summary, encoding: 'bom|utf-8'))['folders'].flat_map { |f| f['tags'] }
  ok('màu 5 tag khớp bộ tag mẫu', S::Schema::TAGS.values.all? { |t| tags.find { |x| x['name'] == t[:name] }&.fetch('color') == "Color(#{t[:color].join(', ')}, 1.0)" })
end
puts $fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
