# Test móng vẽ tự do (core/levels.rb free_footings!, core/footing_plan.rb free_items, footing_builder.rb, preview, dựng tất cả) bằng SketchUp giả lập:
# kiểm tra dữ liệu, móng đơn tại điểm bất kỳ (xoay), móng băng theo đường tim (ngang, dọc, xiên), tầng chỉ có móng tự do, dựng một bước hoàn tác, dữ liệu BIM.
# Chạy từ plugins/VGD_Structure: ruby dev/test_free_footing.rb (phần dựng thật chưa xác minh trong SketchUp)
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
L1 = 'sl_00000001'
PAD = {'kind' => 'pad', 'x' => 2000, 'y' => 1500, 'l' => 1200, 'w' => 1000, 'h' => 400}.freeze
STRIP = {'kind' => 'strip', 'a' => [0, 3000], 'b' => [4000, 3000], 'w' => 600, 'h' => 300}.freeze
def state(free)
  st = S::State.default
  st['levels'][0]['free_footings'] = free if free
  st
end
def norm(st); S::State.normalize!(st); end
bad = ->(f) { error_of { norm(state(f)) } }

# ---- Dữ liệu ----
ok('không có móng tự do: không thêm khóa free_footings (dữ liệu cũ không đổi)', !norm(state(nil))['levels'][0].key?('free_footings'))
n = norm(state('ff_00000001' => PAD.merge('x' => 2000.04), 'ff_00000002' => STRIP))['levels'][0]['free_footings']
ok('móng hợp lệ: làm tròn, thêm góc xoay 0 cho móng đơn', n['ff_00000001'] == {'kind' => 'pad', 'x' => 2000.0, 'y' => 1500.0, 'rot' => 0, 'l' => 1200.0, 'w' => 1000.0, 'h' => 400.0} && n['ff_00000002']['a'] == [0.0, 3000.0] && n['ff_00000002']['b'] == [4000.0, 3000.0])
ok('móng băng: đầu mút gần thẳng được làm thẳng, đầu a là đầu nhỏ hơn', norm(state('ff_00000002' => STRIP.merge('a' => [4000, 3000], 'b' => [0, 3000.02])))['levels'][0]['free_footings']['ff_00000002'].values_at('a', 'b') == [[0.0, 3000.0], [4000.0, 3000.0]])
ok('góc xoay chuẩn hóa về 0..360', norm(state('ff_00000001' => PAD.merge('rot' => -90)))['levels'][0]['free_footings']['ff_00000001']['rot'] == 270)
ok('mã sai bị từ chối', bad.call('xx' => PAD).to_s.include?('mã móng tự do'))
ok('loại sai bị từ chối', bad.call('ff_00000001' => PAD.merge('kind' => 'x')).to_s.include?('pad (móng đơn)'))
ok('khóa lạ bị từ chối', bad.call('ff_00000001' => PAD.merge('z' => 1)).to_s.include?('khóa lạ'))
ok('kích thước ngoài khoảng bị từ chối: dài, rộng, dày', bad.call('ff_00000001' => PAD.merge('l' => 100)).to_s.include?('dài từ 300') && bad.call('ff_00000001' => PAD.merge('w' => 9000)).to_s.include?('rộng từ 300') && bad.call('ff_00000001' => PAD.merge('h' => 50)).to_s.include?('dày từ 150'))
ok('móng băng: rộng ngoài khoảng và đoạn quá ngắn bị từ chối', bad.call('ff_00000002' => STRIP.merge('w' => 100)).to_s.include?('rộng từ 200') && bad.call('ff_00000002' => STRIP.merge('b' => [30, 3000])).to_s.include?('ít nhất'))
ok('tọa độ không phải số bị từ chối', bad.call('ff_00000001' => PAD.merge('x' => 'a')).to_s.include?('tọa độ'))
ok('quá 200 móng bị từ chối', bad.call((1..201).to_h { |i| [format('ff_%08x', i), PAD] }).to_s.include?('quá nhiều móng'))

# ---- Kế hoạch ----
st = norm(state('ff_00000001' => PAD.merge('rot' => 90), 'ff_00000002' => STRIP, 'ff_00000003' => STRIP.merge('a' => [0, 0], 'b' => [3000, 3000]), 'ff_00000004' => PAD.merge('x' => 6000, 'rot' => 30)))
cols = S::ColumnPlan.plan(st['grid'], st['types'], st['levels'], L1)
plan = S::FootingPlan.plan(st['grid'], st['types'], st['levels'], L1, st['beam_types'], st['wall_types'], st['opening_types'])
by = plan[:items].to_h { |i| [i[:ref], i] }
ok('tầng chỉ có móng tự do (không khai báo móng theo cột): lập được kế hoạch, 4 mục', plan[:items].size == 4 && plan[:items].all? { |i| i[:free] })
ok('móng đơn xoay 90: đổi chỗ dài / rộng, không có poly', by['ff_00000001'][:w] == 1000.0 && by['ff_00000001'][:d] == 1200.0 && !by['ff_00000001'].key?(:poly))
ok('đỉnh móng = chân cột, dày xuống dưới', (by['ff_00000001'][:z1] - cols[:z0]).abs < 0.11 && (by['ff_00000001'][:z0] - (cols[:z0] - 400)).abs < 0.11)
ok('móng đơn xoay 30: có góc và đa giác xoay', by['ff_00000004'][:rot] == 30.0 && by['ff_00000004'][:poly].size == 4)
s = by['ff_00000002']
ok('móng băng ngang: dài theo x, rộng theo y, tâm giữa đoạn', s[:along] == 'x' && s[:w] == 4000.0 && s[:d] == 600.0 && s[:center] == [2000.0, 3000.0] && s[:length] == 4000.0 && s[:width] == 600.0)
o = by['ff_00000003']
ok('móng băng xiên: xoay theo đoạn, dài đúng, đa giác 4 đỉnh', o[:along] == 'o' && (o[:length] - 4242.64).abs < 0.01 && (o[:rot] - 45.0).abs < 0.001 && o[:poly].size == 4 && o[:w] == o[:length])
ok('chiều dày tổng = lớn nhất trong các móng (400)', plan[:h] == 400.0)
ov = norm(state('ff_00000001' => PAD, 'ff_00000002' => PAD.merge('x' => 2500)))
ok('hai móng đơn chồng nhau: cảnh báo', S::FootingPlan.plan(ov['grid'], ov['types'], ov['levels'], L1)[:issues].any? { |m| m.include?('chồng lên nhau') })
ok('tầng không có móng nào: báo lỗi như cũ', error_of { S::FootingPlan.plan(*(n0 = norm(state(nil))).values_at('grid', 'types', 'levels'), L1) }.to_s.include?('chưa khai báo móng'))

# ---- Dựng ----
m = Sketchup::Model.new
res = S::FootingBuilder.build(m, st, [L1])
g = m.entities.grep(Sketchup::Group).find { |x| x.get_attribute(D, 'kind') == 'footings' }
inst = g.entities.grep(Sketchup::Instance)
ok('dựng: một nhóm móng, 4 đế, một bước hoàn tác', g.name == 'Móng - Tầng 1' && inst.size == 4 && res.total == 4 && m.operations == [[:start, 'VGD Structure · Dựng móng'], [:commit]])
strip = inst.find { |i| i.get_attribute('VGD_BIM_SOURCE', 'ref') == "#{L1}:ff_00000002" }
ok('móng băng tự do: BIM kind footing, dims rộng / dài / dày, tên có "tự do"', strip.get_attribute('VGD_BIM_SOURCE', 'kind') == 'footing' && JSON.parse(strip.get_attribute(D, 'dims')) == {'w' => 600.0, 'd' => 4000.0, 'height' => 300.0} && strip.name.include?('Móng băng tự do ff_00000002'))
ok('mọi móng ở tag S. FOOTING', inst.all? { |i| i.layer.name == 'S. FOOTING' })
all = S::AllBuilder.build(m, st, [L1])
ok('dựng tất cả: tầng chỉ có móng tự do vẫn dựng móng (thay nhóm cũ, vẫn một nhóm)', all[:kinds].key?('footings') && m.entities.grep(Sketchup::Group).count { |x| x.get_attribute(D, 'kind') == 'footings' } == 1)
st2 = norm(state(nil))
S::FootingBuilder.build(m, st, [L1])
st2['levels'][0].delete('free_footings')
S::AllBuilder.build(m, st2, [L1], %w[columns]) rescue nil
ok('tầng không có móng: dựng móng báo lỗi, model không đổi', error_of { S::FootingBuilder.build(Sketchup::Model.new, st2, [L1]) }.to_s.include?('chưa khai báo móng'))

# ---- Xem trước ----
pv = S::Preview.build(st.merge('level' => L1))
ok('xem trước có móng tự do kèm cờ free, a, b của móng băng', pv[:footings][:count] == 4 && pv[:footings][:items].any? { |i| i[:free] && i[:kind] == 'strip' && i[:a] && i[:b] })

puts $fails.zero? ? 'TẤT CẢ ĐẠT' : "CÓ #{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
