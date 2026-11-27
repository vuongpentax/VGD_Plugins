# Test lỗ sàn tổng quát (H6): cầu thang vắt qua nhiều ô sàn được khoét từng ô; lỗ kỹ thuật chữ nhật theo 2 giao điểm lưới + lùi mỗi cạnh.
# Chạy từ plugins/VGD_Structure: ruby dev/test_slab_holes.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def near(a, b, tol = 0.01); (a - b).abs <= tol; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
files = File.read(File.join(ROOT, 'loader.rb'))[/FILES = %w\[(.*?)\]/m, 1].split - %w[su_tools panel su_scan su_section edit_sync]
files.each { |f| require File.join(ROOT, f) }
S = VGD::Structure
G = S::Geometry

# ---- Geometry.clip_to_box ----
sq = [[0, 0], [10, 0], [10, 10], [0, 10]]
ok('clip: đa giác nằm trọn trong hộp giữ nguyên', G.clip_to_box(sq, [-5, -5], [20, 20]) == sq)
ok('clip: cắt một nửa', G.area(G.clip_to_box(sq, [5, -5], [20, 20])) == 50)
ok('clip: nằm ngoài hộp cho vòng rỗng', G.clip_to_box(sq, [20, 20], [30, 30]).empty?)
tri = [[0, 0], [10, 0], [0, 10]]
ok('clip: tam giác cắt bởi hộp vuông', near(G.area(G.clip_to_box(tri, [0, 0], [5, 5])), 25 - 0, 0.001) && G.area(G.clip_to_box(tri, [0, 0], [5, 5])) > 0)

# ---- Cầu thang vắt qua nhiều ô ----
def state(slabs, holes = nil, with_stair = true)
  st = S::State.default
  st['levels'][0]['picks']['stairs'] = !with_stair ? {} : {'st_00000001' => {'type' => S::StairTypes.default[0]['id'], 'free' => {'a' => [6000, 300], 'b' => [6000, 5800]}}}
  st['levels'][1]['picks']['slabs'] = slabs
  st['levels'][1]['slab_holes'] = holes if holes
  st
end
def slab_plan(st)
  n = S::State.normalize!(st)
  S::Checker.plan_for('slabs', n, n['levels'][1]['id'])
end
cells = S::Grid.cells(S::State.default['grid']).each_with_object({}) { |c, h| h[c[:ref]] = {} }
stair = S::StairPlace.plan(*S::State.normalize!(state({})).values_at('grid', 'types', 'beam_types', 'wall_types', 'stair_types', 'levels'), 'sl_00000001')[:items][0]
plan = slab_plan(state(cells))
cut = plan[:items].select { |i| i[:stair_holes] }
ok('cầu thang vắt qua hai ô: mỗi ô bị cắt có đúng một lỗ', cut.map { |i| i[:ref] }.sort == ['2-3/A-B', '2-3/B-C'] && cut.all? { |i| i[:holes].size == 1 && i[:stair_holes] == ['st_00000001'] })
ok('tổng diện tích các lỗ bằng diện tích cầu thang', near(cut.sum { |i| i[:holes].sum { |h| G.area(h) } }, G.area(stair[:polygon]), 1.0))
ok('mỗi lỗ nằm trong ô của nó', cut.all? { |i| i[:holes][0].all? { |x, y| x >= i[:min][0] - 0.01 && x <= i[:max][0] + 0.01 && y >= i[:min][1] - 0.01 && y <= i[:max][1] + 0.01 } })
ok('diện tích sàn đã trừ lỗ', cut.all? { |i| near(i[:area], (i[:max][0] - i[:min][0]) * (i[:max][1] - i[:min][1]) / 1e6 - G.area(i[:holes][0]) / 1e6, 0.002) })
ok('không còn cảnh báo vắt qua mép', plan[:issues].none? { |m| m.include?('Cầu thang') })
ok('ô không chạm cầu thang không bị khoét', plan[:items].reject { |i| i[:stair_holes] }.all? { |i| (i[:holes] || []).empty? })

# ---- Lỗ kỹ thuật ----
def tech(inset = nil)
  h = {'a' => '2-B', 'b' => '3-C'}
  h['inset'] = inset if inset
  {'sh_00000001' => h}
end
tp = slab_plan(state({'2-3/B-C' => {}}, tech('l' => 100, 'b' => 200, 'r' => 300, 't' => 400), false))
item = tp[:items][0]
want = [[4300, 3800], [8100, 3800], [8100, 6800], [4300, 6800]]
ok('lỗ kỹ thuật: chữ nhật theo 2 giao điểm, lùi trái 100, dưới 200, phải 300, trên 400', item[:holes].size == 1 && item[:holes][0].map { |p| p.map(&:round) }.sort == want.sort)
ok('lỗ kỹ thuật: trừ diện tích và ghi mã lỗ', near(item[:area], 4200 * 3600 / 1e6 - 3800 * 3000 / 1e6, 0.002) && item[:tech_holes] == ['sh_00000001'])
tp0 = slab_plan(state({'2-3/B-C' => {}}, tech, false))
ok('lỗ kỹ thuật trùm hết ô sàn: bỏ tấm đó và cảnh báo', tp0[:items].empty? && tp0[:issues].any? { |m| m.include?('2-3/B-C') && m.include?('trùm hết') })
edge = slab_plan(state({'2-3/B-C' => {}}, {'sh_00000001' => {'a' => '2-B', 'b' => '3-C', 'inset' => {'r' => 1000}}}, false))
ok('lỗ kỹ thuật chạm ba mép tấm: vẫn khoét (chỗ khuyết ở mép), trừ đúng diện tích', edge[:items][0][:holes].size == 1 && near(edge[:items][0][:area], 1000 * 3600 / 1e6, 0.002) && edge[:issues].empty?)
both = slab_plan(state({'2-3/B-C' => {}}, tech('l' => 100, 'b' => 200, 'r' => 300, 't' => 400)))
ok('lỗ kỹ thuật chồng lên lỗ cầu thang: không khoét lỗ thứ hai, cảnh báo', both[:items][0][:holes].size == 1 && both[:issues].any? { |m| m.include?('sh_00000001') && m.include?('chưa khoét') })
ok('hai điểm gõ ngược thứ tự vẫn ra cùng lỗ', slab_plan(state({'2-3/B-C' => {}}, {'sh_00000001' => {'a' => '3-C', 'b' => '2-B', 'inset' => {'l' => 100, 'b' => 200, 'r' => 300, 't' => 400}}}, false))[:items][0][:holes][0].map { |p| p.map(&:round) }.sort == want.sort)
span = slab_plan(state(cells, {'sh_00000001' => {'a' => '2-A', 'b' => '3-C', 'inset' => {'l' => 500, 'b' => 500, 'r' => 500, 't' => 500}}}, false))
ok('lỗ kỹ thuật trải qua nhiều ô: cắt từng ô, tổng diện tích lỗ đúng', span[:items].select { |i| i[:tech_holes] }.map { |i| i[:ref] }.sort == ['2-3/A-B', '2-3/B-C'] && near(span[:items].select { |i| i[:tech_holes] }.sum { |i| i[:holes].sum { |h| G.area(h) } }, 3200.0 * 6200.0, 1.0))
nowhere = slab_plan(state({'1-2/A-B' => {}}, {'sh_00000001' => {'a' => '3-B', 'b' => '4-C'}}, false))
ok('lỗ kỹ thuật không nằm trên tấm sàn nào: cảnh báo', nowhere[:issues].any? { |m| m.include?('sh_00000001') && m.include?('không nằm trên tấm sàn') })

# ---- Kiểm tra dữ liệu ----
def bad(holes)
  S::State.normalize!(state({}, holes))
  nil
rescue S::Levels::Error => e
  e.message
end
ok('giao điểm không tồn tại: bỏ lỗ, không báo lỗi', S::State.normalize!(state({}, {'sh_00000001' => {'a' => '9-Z', 'b' => '3-C'}}))['levels'][1]['slab_holes'].nil?)
ok('hai điểm trùng hàng hoặc cột bị chặn', bad('sh_00000001' => {'a' => '2-B', 'b' => '3-B'}).to_s.include?('chéo') && bad('sh_00000001' => {'a' => '2-B', 'b' => '2-C'}).to_s.include?('chéo'))
ok('lùi quá lớn làm lỗ nhỏ hơn 100 mm bị chặn', bad('sh_00000001' => {'a' => '2-B', 'b' => '3-C', 'inset' => {'l' => 2000, 'r' => 2200}}).to_s.include?('nhỏ hơn'))
ok('lùi âm hoặc không phải số bị chặn', bad('sh_00000001' => {'a' => '2-B', 'b' => '3-C', 'inset' => {'l' => -5}}).to_s.include?('lùi') && bad('sh_00000001' => {'a' => '2-B', 'b' => '3-C', 'inset' => {'l' => 'x'}}).to_s.include?('lùi'))
ok('mã lỗ sai định dạng bị chặn', bad('abc' => {'a' => '2-B', 'b' => '3-C'}).to_s.include?('mã'))
ok('quá nhiều lỗ bị chặn', bad((1..(S::Levels::MAX_SLAB_HOLES + 1)).to_h { |i| [format('sh_%08x', i), {'a' => '2-B', 'b' => '3-C'}] }).to_s.include?('quá nhiều'))
ok('khóa lạ trong lỗ bị chặn', bad('sh_00000001' => {'a' => '2-B', 'b' => '3-C', 'x' => 1}).to_s.include?('không hợp lệ'))
n = S::State.normalize!(state({}, tech('l' => 100.456)))
ok('lưu chuẩn: inset đủ 4 cạnh, làm tròn 0,1', n['levels'][1]['slab_holes']['sh_00000001'] == {'a' => '2-B', 'b' => '3-C', 'inset' => {'l' => 100.5, 'b' => 0.0, 'r' => 0.0, 't' => 0.0}})
ok('tầng không có lỗ kỹ thuật: không có khóa slab_holes (dữ liệu cũ không đổi)', !S::State.normalize!(state({}))['levels'][1].key?('slab_holes'))

# ---- Xem trước và dựng ----
pv = S::Preview.build(state({'2-3/B-C' => {}}, tech('l' => 100), false).merge('level' => 'sl_00000002'))
ok('xem trước có lỗ kỹ thuật', pv[:slabs][:items][0][:holes].size == 1)
m = Sketchup::Model.new
S::PlateBuilder.build(m, state({'2-3/B-C' => {}}, tech('l' => 100), false), ['sl_00000002'], 'slabs')
g = m.entities.grep(Sketchup::Group).find { |x| x.get_attribute(S::Schema::DICTIONARY, 'kind') == 'slabs' }
ok('dựng sàn có lỗ kỹ thuật (tên định nghĩa băm)', g.entities.grep(Sketchup::Instance)[0].definition.name.match?(/[0-9a-f]{12}/))

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
