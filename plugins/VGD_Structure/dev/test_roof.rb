# Test mái (core/levels.rb roof!, core/roof_plan.rb, roof_builder.rb, xem trước, dựng tất cả) bằng SketchUp giả lập: kiểm tra dữ liệu, mái bằng / một dốc /
# hai dốc (cao độ mặt trên tại mép, nóc, phần chìa), diện tích nghiêng, dựng một bước hoàn tác, dữ liệu BIM, dọn mồ côi. Chạy: ruby dev/test_roof.rb
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
def roof_state(roof)
  st = S::State.default
  st['levels'][-1]['roof'] = roof
  st
end
def norm(st); S::State.normalize!(st); end
def plan_of(roof)
  n = norm(roof_state(roof))
  S::RoofPlan.plan(n['grid'], n['levels'], n['levels'][-1]['id'])
end
def near(a, b, tol = 0.05); (a - b).abs <= tol; end
X0, Y0, X1, Y1 = S::Grid.bounds(S::State.default['grid'])
TOP = S::State.default['levels'][-1]['elevation']

# ---- Dữ liệu ----
ok('không khai báo mái: không thêm khóa roof', !norm(S::State.default)['levels'][-1].key?('roof'))
ok('mái bằng: điền mặc định dày 120, chìa 600, chân 0; không có dốc, hướng', norm(roof_state('shape' => 'flat'))['levels'][-1]['roof'] == {'shape' => 'flat', 'thickness' => 120.0, 'overhang' => 600.0, 'base' => 0.0})
ok('mái dốc hợp lệ: giữ dốc và hướng', norm(roof_state('shape' => 'gable', 'slope' => 25, 'dir' => 'x'))['levels'][-1]['roof'].values_at('slope', 'dir') == [25.0, 'x'])
bad = ->(r) { error_of { norm(roof_state(r)) }.to_s }
ok('dữ liệu mái sai bị từ chối: kiểu lạ, dốc 0 / 70, hướng sai theo kiểu, dày quá mỏng, chìa quá xa',
   bad.call('shape' => 'hip').include?('kiểu mái') && bad.call('shape' => 'shed', 'slope' => 0, 'dir' => 'x+').include?('độ dốc') && bad.call('shape' => 'shed', 'slope' => 70, 'dir' => 'x+').include?('độ dốc') &&
   bad.call('shape' => 'gable', 'slope' => 30, 'dir' => 'x+').include?('hướng') && bad.call('shape' => 'flat', 'thickness' => 5).include?('dày mái') && bad.call('shape' => 'flat', 'overhang' => 5000).include?('chìa mái'))

# ---- Kế hoạch ----
fl = plan_of('shape' => 'flat', 'thickness' => 150, 'overhang' => 500)
i = fl[:items][0]
ok('mái bằng: một tấm phủ khung lưới cộng chìa 500 mỗi phía, mặt trên = cốt tầng + dày', fl[:items].size == 1 && i[:poly] == [[X0 - 500, Y0 - 500], [X1 + 500, Y0 - 500], [X1 + 500, Y1 + 500], [X0 - 500, Y1 + 500]].map { |p| p.map { |v| v.round(2) } } &&
   i[:top].all? { |p| near(p[2], TOP + 150) } && near(i[:area], (X1 - X0 + 1000) * (Y1 - Y0 + 1000) / 1e6))
sh = plan_of('shape' => 'shed', 'slope' => 30, 'dir' => 'y+', 'thickness' => 100, 'overhang' => 0)
t = Math.tan(Math::PI / 6); tv = 100 / Math.cos(Math::PI / 6)
low = sh[:items][0][:top].select { |p| near(p[1], Y0) }.map(&:last)
high = sh[:items][0][:top].select { |p| near(p[1], Y1) }.map(&:last)
ok('mái một dốc y+: mép thấp ở trục biên dưới (đáy = cốt tầng), dốc lên theo +Y đúng tan(30°)', low.all? { |z| near(z, TOP + tv) } && high.all? { |z| near(z, TOP + tv + (Y1 - Y0) * t) })
ok('diện tích nghiêng = diện tích mặt bằng / cos(dốc)', near(sh[:items][0][:area], (X1 - X0) * (Y1 - Y0) / 1e6 / Math.cos(Math::PI / 6), 0.002))
ga = plan_of('shape' => 'gable', 'slope' => 30, 'dir' => 'x', 'thickness' => 100, 'overhang' => 600)
ym = (Y0 + Y1) / 2.0
ok('mái hai dốc nóc theo X: hai tấm gặp nhau ở nóc giữa khung, không chồng trên mặt bằng', ga[:items].size == 2 && ga[:items][0][:poly][2][1] == ym && ga[:items][1][:poly][0][1] == ym)
ridge = TOP + tv + (ym - Y0) * t
ok('nóc cao đúng, hai tấm cùng cao độ ở nóc', near(ga[:ridge], ridge) && ga[:items].all? { |it| it[:top].select { |p| near(p[1], ym) }.all? { |p| near(p[2], ridge) } })
ok('phần chìa thấp hơn chân mái (dốc kéo dài ra ngoài)', ga[:items][0][:top].select { |p| near(p[1], Y0 - 600) }.all? { |p| near(p[2], TOP + tv - 600 * t) })
gy = plan_of('shape' => 'gable', 'slope' => 30, 'dir' => 'y', 'overhang' => 0)
ok('mái hai dốc nóc theo Y: chia khung theo X ở giữa', gy[:items].map { |it| it[:poly].map(&:first).minmax } == [[X0, (X0 + X1) / 2.0], [(X0 + X1) / 2.0, X1]])
ok('base: chân mái nâng lên theo cao độ khai báo', plan_of('shape' => 'flat', 'base' => 300, 'thickness' => 100)[:items][0][:top].all? { |p| near(p[2], TOP + 400) })
ok('tầng chưa khai báo mái: báo lỗi rõ', error_of { n = norm(S::State.default); S::RoofPlan.plan(n['grid'], n['levels'], n['levels'][-1]['id']) }.include?('chưa khai báo mái'))

# ---- Xem trước ----
pv = S::Preview.build(roof_state('shape' => 'gable', 'slope' => 30, 'dir' => 'x').merge('level' => S::State.default['levels'][-1]['id']))
ok('xem trước tầng có mái: hai tấm kèm nóc', pv[:roofs] && pv[:roofs][:count] == 2 && pv[:roofs][:ridge] > pv[:roofs][:z_base])

# ---- Dựng ----
m = Sketchup::Model.new
lid = S::State.default['levels'][-1]['id']
res = S::RoofBuilder.build(m, roof_state('shape' => 'gable', 'slope' => 30, 'dir' => 'x', 'thickness' => 100), [lid])
g = m.entities.grep(Sketchup::Group).find { |x| x.get_attribute(D, 'kind') == 'roofs' }
plates = g.entities.grep(Sketchup::Group)
ok('dựng: nhóm "Mái - <tầng>" tag A. ROOF, hai tấm, một bước hoàn tác', g.name.start_with?('Mái - ') && g.layer.name == 'A. ROOF' && plates.size == 2 && m.operations == [[:start, 'VGD Structure · Dựng mái'], [:commit]] && res.total == 2)
faces = plates[0].entities.grep(Sketchup::Face)
ok('mỗi tấm là khối kín 6 mặt (trên, dưới, 4 bên)', faces.size == 6)
zs = faces[0].points.map { |p| (p.z * MM).round(1) }
ok('mặt trên đúng cao độ mép thấp (phần chìa) và nóc', zs.min.round == (TOP + tv - 600 * t).round && zs.max.round == ridge.round)
dims = JSON.parse(plates[0].get_attribute(D, 'dims'))
ok('dữ liệu BIM: kind roof, dày, diện tích nghiêng, vân tay', plates[0].get_attribute('VGD_BIM_SOURCE', 'kind') == 'roof' && dims['thickness'] == 100.0 && dims['area'] > 0 && plates[0].get_attribute(D, 'fp').is_a?(String))
all = S::AllBuilder.build(m, roof_state('shape' => 'flat'), [lid])
ok('dựng tất cả có mái ở tầng trên cùng; dựng lại thay nhóm cũ', all[:kinds].key?('roofs') && m.entities.grep(Sketchup::Group).count { |x| x.get_attribute(D, 'kind') == 'roofs' } == 1)
ok('tầng chưa khai báo mái: dựng mái báo lỗi', error_of { S::RoofBuilder.build(Sketchup::Model.new, S::State.default, [lid]) }.include?('chưa khai báo mái'))

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
