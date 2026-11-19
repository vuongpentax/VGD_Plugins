# Test đề xuất bán tự động, kiểm tra kết cấu và dựng tất cả (core/proposal.rb, core/checker.rb, all_builder.rb) bằng SketchUp giả lập.
# Chạy: ruby dev/test_proposal.rb (phần dựng thật chưa xác minh trong SketchUp)
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/stair_types core/stair_plan core/stair_place core/layer_list core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/slab_plan core/ceiling_plan core/proposal core/checker core/model_edit core/state core/preview model_sync edit_sync model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder all_builder].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
def deep(x); Marshal.load(Marshal.dump(x)); end
st = S::State.default
st['levels'].push(deep(st['levels'][1]).merge('id' => 'sl_00000003', 'name' => 'Mái', 'elevation' => 7200.0))
st = S::State.normalize!(st)
grid = st['grid']

# Đề xuất
levels, added = S::Proposal.propose(grid, st['levels'], ['sl_00000001'])
p1 = levels[0]['picks']
ok('đề xuất tầng 1: 12 cột, 17 dầm, 10 tường biên, 6 sàn, 6 trần', [p1['columns'].size, p1['beams'].size, p1['walls'].size, p1['slabs'].size, p1['ceilings'].size] == [12, 17, 10, 6, 6] && added == {'columns' => 12, 'beams' => 17, 'walls' => 10, 'slabs' => 6, 'ceilings' => 6})
ok('tường chỉ ở các nhịp biên (mọi mã tường là nhịp biên của lưới)', p1['walls'].keys.all? { |r| S::Grid.spans(grid).find { |s| s[:ref] == r }[:placement] == 'edge' } && !p1['walls'].key?('x:B:2-3'))
ok('chỉ đề xuất cho tầng được chọn: các tầng khác không đổi; không đổi dữ liệu vào', levels[1]['picks']['columns'].empty? && st['levels'][0]['picks']['columns'].empty?)
l2, a2 = S::Proposal.propose(grid, st['levels'], ['sl_00000003'])
ok('tầng trên cùng chỉ đề xuất sàn (6), không cột, dầm, tường, trần', l2[2]['picks']['slabs'].size == 6 && %w[columns beams walls ceilings].all? { |k| l2[2]['picks'][k].empty? } && a2['slabs'] == 6 && a2['columns'] == 0)
l3, a3 = S::Proposal.propose(grid, st['levels'], st['levels'].map { |l| l['id'] })
ok('đề xuất cho mọi tầng: tầng 1 và tầng 2 đủ năm loại, mái chỉ sàn; tổng cột 24', l3[0]['picks']['columns'].size == 12 && l3[1]['picks']['columns'].size == 12 && l3[2]['picks']['columns'].empty? && a3['columns'] == 24 && a3['slabs'] == 18)
# Không phá dữ liệu có sẵn
mine = deep(st['levels'])
mine[0]['picks']['columns'] = {'1-A' => {'x' => 'center'}, '2-B' => {'type' => 'ct_00000001'}}
mine[0]['picks']['beams'] = {'x:A:1-2' => {'p' => 'max'}}
l4, a4 = S::Proposal.propose(grid, mine, ['sl_00000001'])
ok('giữ nguyên lựa chọn đã có (kiểu đặt, loại riêng), chỉ thêm phần thiếu', l4[0]['picks']['columns']['1-A'] == {'x' => 'center'} && l4[0]['picks']['columns']['2-B'] == {'type' => 'ct_00000001'} && l4[0]['picks']['beams']['x:A:1-2'] == {'p' => 'max'} && a4['columns'] == 10 && a4['beams'] == 16)
l5, a5 = S::Proposal.propose(grid, l4, ['sl_00000001'])
ok('đề xuất lần hai không thêm gì nữa (idempotent)', a5.values.all?(&:zero?) && l5 == l4)
ok('kết quả đề xuất qua kiểm tra dữ liệu tầng được (Levels.normalize!)', error_of { S::Levels.normalize!(levels, grid, st['types'], st['beam_types'], st['wall_types']) }.nil?)
ok('tầng không tồn tại hoặc danh sách rỗng bị từ chối', !error_of { S::Proposal.propose(grid, st['levels'], ['sl_deadbeef']) }.nil? && !error_of { S::Proposal.propose(grid, st['levels'], []) }.nil? && !error_of { S::Proposal.propose(grid, st['levels'], 'x') }.nil?)

# Kiểm tra kết cấu
full = deep(st)
full['levels'] = S::Levels.normalize!(S::Proposal.propose(grid, full['levels'], full['levels'].map { |l| l['id'] }).first, grid, full['types'], full['beam_types'], full['wall_types']).first
rep = S::Checker.run(full)
ok('đề xuất đầy đủ: không lỗi; tầng mái chỉ báo không có cảnh báo; số lượng từng loại đúng', rep[:errors] == 0 && rep[:levels].map { |r| r[:id] } == %w[sl_00000001 sl_00000002 sl_00000003] && rep[:levels][0][:counts] == {'columns' => 12, 'beams' => 17, 'walls' => 10, 'openings' => 0, 'slabs' => 6, 'ceilings' => 6} && rep[:levels][2][:top] && rep[:levels][2][:warnings].empty?)
ok('đề xuất đầy đủ: không có cảnh báo nào (không nhô ra, không chồng, dầm đều gối cột)', rep[:warnings] == 0)
nocol = deep(full); nocol['levels'][0]['picks']['columns'].delete('2-B')
nr = S::Checker.run(nocol)
ok('thiếu cột 2-B: cảnh báo các dầm tại 2-B không có cột để gối (4 dầm)', nr[:levels][0][:warnings].count { |m| m.include?('2-B') && m.include?('không có cột để gối') } == 4)
bad = deep(full); bad['levels'][2]['elevation'] = 4100.0; bad['levels'][2]['screed'] = 300.0
brep = S::Checker.run(S::State.normalize!(bad))
ok('tầng cách nhau quá sát (cột cao 250 < 300 do cán nền tầng trên 300): báo lỗi ở tầng đó, không dừng cả kiểm tra', brep[:errors] > 0 && brep[:levels][1][:errors].any? { |m| m.include?('Chiều cao cột') } && brep[:levels][0][:errors].empty?)
ok('tầng không chọn gì: cảnh báo "chưa chọn"', S::Checker.run(st)[:levels][0][:warnings].first.include?('chưa chọn'))
topbad = deep(st); topbad['levels'][2]['picks']['columns'] = {'1-A' => {}}
ok('tầng trên cùng có cột đã chọn: cảnh báo sẽ bị bỏ qua', S::Checker.run(topbad)[:levels][2][:warnings].any? { |m| m.include?('bị bỏ qua') })
over = deep(full); over['levels'][0]['picks']['columns']['1-A'] = {'x' => 'center', 'y' => 'center'}
ok('cột tâm trên trục biên: cảnh báo nhô ra ngoài từ kế hoạch được gom vào báo cáo', S::Checker.run(over)[:levels][0][:warnings].any? { |m| m.start_with?('Cột:') && m.include?('nhô ra') })

# Dựng tất cả
m = Sketchup::Model.new
ids = %w[sl_00000001 sl_00000002 sl_00000003]
res = S::AllBuilder.build(m, full, ids)
groups = m.entities.grep(Sketchup::Group).map(&:name).sort
ok('dựng tất cả: các nhóm của 3 tầng theo từng loại (cột, dầm, tường, trần: 2 tầng; sàn: 3 tầng)', groups.count { |n| n.start_with?('Cột - ') } == 2 && groups.count { |n| n.start_with?('Dầm - ') } == 2 && groups.count { |n| n.start_with?('Tường - ') } == 2 && groups.count { |n| n.start_with?('Trần - ') } == 2 && groups.count { |n| n.start_with?('Sàn - ') } == 3)
ok('MỘT bước hoàn tác duy nhất cho tất cả (một start và một commit)', m.operations == [[:start, 'VGD Structure · Dựng kết cấu'], [:commit]])
ok('kết quả: tổng đối tượng và số theo loại (24 cột, 34 dầm, 20 tường, 18 sàn, 12 trần)', res[:total] == 24 + 34 + 20 + 18 + 12 && res[:kinds].transform_values(&:total) == {'columns' => 24, 'beams' => 34, 'walls' => 20, 'slabs' => 18, 'ceilings' => 12})
ok('cả năm tag được tạo theo bộ tag mẫu', ['S. COLUMN', 'S. BEAM', 'A. WALL', 'S. SLAB', 'A. FINISHING CEILING'].all? { |n| m.layers[n] })
ok('dữ liệu nguồn được lưu một lần cùng thao tác', S::ModelStore.read(m)['levels'][0]['picks']['walls'].size == 10)
ok('dựng lại tất cả: thay nhóm cũ, không nhân đôi; vẫn một thao tác mỗi lần', (S::AllBuilder.build(m, full, ids)) && m.entities.grep(Sketchup::Group).size == groups.size && m.operations.last == [:commit] && m.operations.count { |o| o[0] == :start } == 2)
# Chỉ một tầng, bỏ qua loại không có lựa chọn
m2 = Sketchup::Model.new
only = deep(full); only['levels'][0]['picks']['walls'] = {}; only['levels'][0]['picks']['ceilings'] = {}
r2 = S::AllBuilder.build(m2, only, ['sl_00000001'])
ok('loại không có lựa chọn thì bỏ qua (không có nhóm tường, trần)', r2[:kinds].keys.sort == %w[beams columns slabs] && m2.entities.grep(Sketchup::Group).none? { |g| g.name.start_with?('Tường') || g.name.start_with?('Trần') })
# Có lỗi thì không dựng gì
m3 = Sketchup::Model.new
broken = deep(full); broken['levels'][2]['elevation'] = 4100.0; broken['levels'][2]['screed'] = 300.0
msg = error_of { S::AllBuilder.build(m3, broken, ids) }
ok('một loại có lỗi kế hoạch: không dựng gì cả, model và thao tác không đổi, báo rõ loại nào', msg.to_s.start_with?('Cột:') && m3.operations.empty? && m3.entities.grep(Sketchup::Group).empty? && m3.layers.to_a.empty?)
lm = Sketchup::Model.new
S::AllBuilder.build(lm, full, ids)
lm.entities.grep(Sketchup::Group).find { |g| g.name.start_with?('Tường - Tầng 2') }.lock!
before = lm.entities.grep(Sketchup::Group).map(&:name).sort
ops = lm.operations.size
ok('một nhóm bị khóa: từ chối trước khi đụng gì, báo loại tường', error_of { S::AllBuilder.build(lm, full, ids) }.to_s.start_with?('Tường:') && lm.operations.size == ops && lm.entities.grep(Sketchup::Group).map(&:name).sort == before)
fm = Sketchup::Model.new
fm.definitions.define_singleton_method(:add) { |*| raise 'lỗi giả lập khi tạo định nghĩa' }
msg = error_of { S::AllBuilder.build(fm, full, ids) }
ok('lỗi giữa chừng khi dựng: hủy cả thao tác (abort), không commit', msg.to_s.include?('giả lập') && fm.operations.last == [:abort] && !fm.operations.include?([:commit]))
ok('không chọn tầng, tầng lạ, chưa chọn gì: từ chối', !error_of { S::AllBuilder.build(Sketchup::Model.new, full, []) }.nil? && !error_of { S::AllBuilder.build(Sketchup::Model.new, full, 'x') }.nil? && S::AllBuilder.targets(full, ['sl_deadbeef']).empty? && !error_of { S::AllBuilder.build(Sketchup::Model.new, st, ['sl_00000001']) }.nil?)
ok('dữ liệu sai bị từ chối trước khi đụng model', (e = Sketchup::Model.new) && !error_of { S::AllBuilder.build(e, {'grid' => 5}, ids) }.nil? && e.operations.empty?)
puts $fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
