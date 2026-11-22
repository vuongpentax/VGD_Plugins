# Test móng đơn (core/levels.rb footing!, core/footing_plan.rb, footing_builder.rb, preview, dựng tất cả) bằng SketchUp giả lập:
# kiểm tra dữ liệu, đế dưới chân cột (cột theo lưới, tự do, xoay), cảnh báo nhỏ hơn cột / chồng nhau, dựng một bước hoàn tác, dữ liệu BIM, dọn mồ côi.
# Chạy: ruby dev/test_footing.rb (phần dựng thật chưa xác minh trong SketchUp)
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
files = File.read(File.join(ROOT, 'loader.rb'))[/FILES = %w\[(.*?)\]/m, 1].split - %w[su_tools panel su_scan su_section edit_sync]
files.each { |f| require File.join(ROOT, f) }
S = VGD::Structure
D = S::Schema::DICTIONARY
MM = 25.4
L1 = 'sl_00000001'
def footing_state(footing = {'l' => 1200, 'w' => 1000, 'h' => 400})
  st = S::State.default
  st['levels'][0]['footing'] = footing if footing
  st['levels'][0]['picks']['columns'] = S::Grid.intersections(st['grid']).each_with_object({}) { |i, h| h[i[:ref]] = {} }
  st
end
def norm(st); S::State.normalize!(st); end

# ---- Dữ liệu ----
ok('tầng không có móng: không thêm khóa footing (dữ liệu cũ không đổi)', !norm(footing_state(nil))['levels'][0].key?('footing'))
ok('móng hợp lệ: làm tròn và giữ', norm(footing_state({'l' => 1200.04, 'w' => 1000, 'h' => 400}))['levels'][0]['footing'] == {'l' => 1200.0, 'w' => 1000.0, 'h' => 400.0})
bad = ->(f) { error_of { norm(footing_state(f)) } }
ok('móng sai bị từ chối: thiếu số, quá nhỏ, quá dày, không phải bảng', bad.call({'l' => 1200, 'w' => 1000}).to_s.include?('dày móng') && bad.call({'l' => 100, 'w' => 1000, 'h' => 400}).to_s.include?('dài móng') &&
   bad.call({'l' => 1200, 'w' => 1000, 'h' => 9000}).to_s.include?('dày móng') && bad.call('x').to_s.include?('không hợp lệ'))

# ---- Kế hoạch ----
st = norm(footing_state)
plan = S::FootingPlan.plan(st['grid'], st['types'], st['levels'], L1)
cols = S::ColumnPlan.plan(st['grid'], st['types'], st['levels'], L1)
ok('mỗi cột một đế, tâm trùng tâm cột', plan[:items].size == cols[:items].size && plan[:items].zip(cols[:items]).all? { |f, c| f[:center] == c[:center] && f[:ref] == c[:ref] })
f = plan[:items][0]
ok('đỉnh đế = chân cột, dày xuống dưới', f[:z1] == cols[:z0] && f[:z0] == (cols[:z0] - 400).round(1) && f[:w] == 1200.0 && f[:d] == 1000.0)
ok('đế lớn hơn cột, không chồng: không cảnh báo', plan[:issues].empty?)
small = norm(footing_state({'l' => 300, 'w' => 300, 'h' => 300}))
small['types'][0]['w'] = 400
ok('đế nhỏ hơn tiết diện cột: cảnh báo', S::FootingPlan.plan(small['grid'], small['types'], small['levels'], L1)[:issues].any? { |m| m.include?('nhỏ hơn tiết diện cột') })
big = norm(footing_state({'l' => 5000, 'w' => 5000, 'h' => 400}))
ok('đế to làm chồng nhau: cảnh báo gộp móng', S::FootingPlan.plan(big['grid'], big['types'], big['levels'], L1)[:issues].any? { |m| m.include?('chồng lên nhau') })
fr = footing_state
fr['levels'][0]['picks']['columns'] = {'fc_00000001' => {'free' => {'x' => 1000, 'y' => 1000, 'rot' => 90}}, 'fc_00000002' => {'free' => {'x' => 5000, 'y' => 5000, 'rot' => 30}}}
fp = S::FootingPlan.plan(*norm(fr).values_at('grid', 'types', 'levels'), L1)
r90 = fp[:items].find { |i| i[:ref] == 'fc_00000001' }
r30 = fp[:items].find { |i| i[:ref] == 'fc_00000002' }
ok('cột tự do xoay 90 độ: đổi chỗ dài và rộng của đế', r90[:w] == 1000.0 && r90[:d] == 1200.0 && !r90.key?(:rot))
ok('cột xoay góc khác: đế xoay cùng góc, có đa giác', r30[:rot] == 30 && r30[:poly].size == 4)
ok('tầng không khai báo móng hoặc tầng trên cùng: báo lỗi rõ', error_of { S::FootingPlan.plan(*norm(footing_state(nil)).values_at('grid', 'types', 'levels'), L1) }.include?('chưa khai báo móng') &&
   error_of { top = footing_state; top['levels'].last['footing'] = {'l' => 1200, 'w' => 1000, 'h' => 400}; S::FootingPlan.plan(*norm(top).values_at('grid', 'types', 'levels'), top['levels'].last['id']) }.to_s.include?('trên cùng'))

# ---- Xem trước ----
pv = S::Preview.build(footing_state.merge('level' => L1))
ok('xem trước có đế móng của tầng đang xem', pv[:footings] && pv[:footings][:count] == cols[:items].size && pv[:footings][:items][0].key?(:center))
ok('tầng không có móng: xem trước không có mục móng', !S::Preview.build(footing_state(nil).merge('level' => L1)).key?(:footings))

# ---- Dựng ----
m = Sketchup::Model.new
res = S::FootingBuilder.build(m, footing_state, [L1])
g = m.entities.grep(Sketchup::Group).find { |x| x.get_attribute(D, 'kind') == 'footings' }
inst = g.entities.grep(Sketchup::Instance)
ok('dựng: một nhóm "Móng - Tầng 1", một bước hoàn tác', g.name == 'Móng - Tầng 1' && m.operations == [[:start, 'VGD Structure · Dựng móng'], [:commit]] && res.total == inst.size)
ok('mọi đế dùng chung một định nghĩa 1200x1000x400, tag S. FOOTING', inst.map(&:definition).uniq.size == 1 && inst[0].definition.name == 'VGD Móng 1200x1000x400' && g.layer.name == 'S. FOOTING')
one = inst[0]
ok('đế đặt ở đỉnh = chân cột trừ dày', ((one.transformation.vector.z * MM) - (cols[:z0] - 400)).abs < 1e-6)
ok('dữ liệu BIM: kind footing, dims như cột (w, d, height), vân tay', one.get_attribute('VGD_BIM_SOURCE', 'kind') == 'footing' && JSON.parse(one.get_attribute(D, 'dims')) == {'w' => 1200.0, 'd' => 1000.0, 'height' => 400.0} && one.get_attribute(D, 'fp').is_a?(String))
ok('tầng chưa khai báo móng: dựng báo lỗi, model không đổi', error_of { S::FootingBuilder.build(Sketchup::Model.new, footing_state(nil), [L1]) }.include?('chưa khai báo móng'))
all = S::AllBuilder.build(m, footing_state, [L1])
ok('dựng tất cả: gồm móng, thay nhóm cũ (vẫn một nhóm móng)', all[:kinds].key?('footings') && m.entities.grep(Sketchup::Group).count { |x| x.get_attribute(D, 'kind') == 'footings' } == 1)
S::AllBuilder.build(m, footing_state(nil), [L1], %w[columns])
ok('bỏ khai báo móng rồi dựng cột: nhóm móng vẫn còn (chỉ dựng loại đã chọn)', m.entities.grep(Sketchup::Group).count { |x| x.get_attribute(D, 'kind') == 'footings' } == 1)
s2 = footing_state
s2['levels'][0].delete('footing')
s2['levels'][1]['footing'] = {'l' => 1200, 'w' => 1000, 'h' => 400}
s2['levels'] << {'id' => 'sl_0000000b', 'name' => 'Mái 2', 'elevation' => 20_000}
s2['levels'][1]['picks'] = {'columns' => {'1-A' => {}}}
S::FootingBuilder.build(m, s2, ['sl_00000002'])
ok('dựng móng tầng khác: nhóm móng của tầng đã bỏ khai báo bị dọn', m.entities.grep(Sketchup::Group).select { |x| x.get_attribute(D, 'kind') == 'footings' }.map { |x| x.get_attribute(D, 'level') } == ['sl_00000002'])

# ---- Đề xuất cho tầng móng ----
pst = footing_state
pst['levels'][0]['picks'] = {}
pnorm = norm(pst)
proposed, added = S::Proposal.propose(pnorm['grid'], pnorm['levels'], [L1])
ok('đề xuất tầng móng: chỉ cổ cột và giằng (dầm), không tường, sàn, trần', added['columns'] > 0 && added['beams'] > 0 && added['walls'].zero? && added['slabs'].zero? && added['ceilings'].zero?)

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
