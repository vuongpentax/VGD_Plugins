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
   bad.call('shape' => 'dome').include?('kiểu mái') && bad.call('shape' => 'shed', 'slope' => 0, 'dir' => 'x+').include?('độ dốc') && bad.call('shape' => 'shed', 'slope' => 70, 'dir' => 'x+').include?('độ dốc') &&
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

# ---- Mái bốn dốc (hip): bốn tấm, cùng độ dốc, nóc là đoạn ngắn hơn khung (hoặc một điểm nếu khung vuông) ----
def poly_area(poly); poly.each_with_index.sum { |(x, y), i| nx, ny = poly[(i + 1) % poly.size]; x * ny - nx * y }.abs / 2.0; end
hp_roof = norm(roof_state('shape' => 'hip', 'slope' => 30, 'dir' => 'x'))['levels'][-1]['roof']
ok('mái bốn dốc: có độ dốc, không có hướng (hướng gửi kèm bị bỏ)', hp_roof['slope'] == 30.0 && !hp_roof.key?('dir'))
ok('mái bốn dốc: độ dốc 0 hoặc 70 bị từ chối', bad.call('shape' => 'hip', 'slope' => 0).include?('độ dốc') && bad.call('shape' => 'hip', 'slope' => 70).include?('độ dốc'))
hp = plan_of('shape' => 'hip', 'slope' => 30, 'thickness' => 100, 'overhang' => 600)
mid = (Y1 - Y0) / 2.0
ok('mái bốn dốc: bốn tấm theo thứ tự nam, đông, bắc, tây; nam và bắc là hình thang, đông và tây là tam giác (khung dài hơn rộng)', hp[:items].map { |it| it[:ref] } == %w[roof_1 roof_2 roof_3 roof_4] && hp[:items].map { |it| it[:poly].size } == [4, 3, 4, 3])
ok('mái bốn dốc: bốn tấm phủ kín khung cộng chìa, không chồng nhau trên mặt bằng', near(hp[:items].sum { |it| poly_area(it[:poly]) }, (X1 - X0 + 1200) * (Y1 - Y0 + 1200), 1.0))
all_ok = hp[:items].all? { |it| it[:top].all? { |x, y, z| near(z, TOP + tv + [x - X0, X1 - x, y - Y0, Y1 - y].min * t, 0.1) } }
ok('mái bốn dốc: mọi đỉnh nằm đúng trên mặt dốc (cao độ = chân + dày + dốc x khoảng cách tới mép gần nhất)', all_ok)
ridge_pts = hp[:items].flat_map { |it| it[:top] }.select { |_, _, z| near(z, TOP + tv + mid * t, 0.1) }.map { |x, y, _| [x.round(1), y.round(1)] }.uniq.sort
ok('mái bốn dốc: nóc là đoạn dài (X1 - X0) - (Y1 - Y0) nằm giữa khung theo phương dài', ridge_pts == [[(X0 + mid).round(1), ((Y0 + Y1) / 2.0).round(1)], [(X1 - mid).round(1), ((Y0 + Y1) / 2.0).round(1)]] && near(hp[:ridge], TOP + tv + mid * t))
ok('mái bốn dốc: diện tích nghiêng = diện tích mặt bằng của tấm / cos(dốc)', hp[:items].all? { |it| near(it[:area], poly_area(it[:poly]) / 1e6 / Math.cos(Math::PI / 6), 0.002) })
sq_state = roof_state('shape' => 'hip', 'slope' => 30, 'thickness' => 100, 'overhang' => 0)
sq_state['grid']['y_axes'] = [{'name' => 'A', 'offset' => 0.0}, {'name' => 'B', 'offset' => 4200.0}, {'name' => 'C', 'offset' => 8400.0}, {'name' => 'D', 'offset' => 12600.0}]
sq = (n = norm(sq_state); S::RoofPlan.plan(n['grid'], n['levels'], n['levels'][-1]['id']))
ok('mái bốn dốc, khung vuông: bốn tam giác gặp nhau ở một điểm nóc', sq[:items].map { |it| it[:poly].size } == [3, 3, 3, 3] && sq[:items].flat_map { |it| it[:top] }.select { |_, _, z| near(z, sq[:ridge], 0.1) }.map { |x, y, _| [x.round(1), y.round(1)] }.uniq == [[6300.0, 6300.0]])
tall = roof_state('shape' => 'hip', 'slope' => 30, 'thickness' => 100, 'overhang' => 0)
tall['grid']['x_axes'] = [{'name' => '1', 'offset' => 0.0}, {'name' => '2', 'offset' => 4200.0}]
tl = (n = norm(tall); S::RoofPlan.plan(n['grid'], n['levels'], n['levels'][-1]['id']))
ok('mái bốn dốc, khung rộng hơn dài theo Y: nóc chạy theo phương Y, nam và bắc là tam giác', tl[:items].map { |it| it[:poly].size } == [3, 4, 3, 4])

# ---- Tường thu hồi (H5b): giao của mặt phẳng đứng ở biên khung với ĐÁY mái; chỉ ở cạnh mà đáy mái đổi độ cao dọc cạnh (đầu hồi, hai bên mái một dốc) ----
WT = S::State.default['wall_types'][0]['id']
SCREED = S::State.default['levels'][-1]['screed']
FLOOR = TOP - SCREED
def gw(r); r.merge('gable_wall' => {'type' => WT}); end
ok('tường thu hồi: giữ ở mái hai dốc và một dốc; bỏ ở mái bằng và bốn dốc', norm(roof_state(gw('shape' => 'gable', 'slope' => 30, 'dir' => 'x')))['levels'][-1]['roof']['gable_wall'] == {'type' => WT} &&
   norm(roof_state(gw('shape' => 'shed', 'slope' => 30, 'dir' => 'x+')))['levels'][-1]['roof']['gable_wall'] == {'type' => WT} &&
   !norm(roof_state(gw('shape' => 'flat')))['levels'][-1]['roof'].key?('gable_wall') && !norm(roof_state(gw('shape' => 'hip', 'slope' => 30)))['levels'][-1]['roof'].key?('gable_wall'))
ok('tường thu hồi: dữ liệu sai (không phải bảng, thiếu loại) bị từ chối', bad.call('shape' => 'gable', 'slope' => 30, 'dir' => 'x', 'gable_wall' => 'x').include?('tường thu hồi') && bad.call('shape' => 'gable', 'slope' => 30, 'dir' => 'x', 'gable_wall' => {}).include?('tường thu hồi'))
gwp = plan_of(gw('shape' => 'gable', 'slope' => 30, 'dir' => 'x', 'thickness' => 100, 'overhang' => 600))
ok('mái hai dốc có tường thu hồi: hai tường ở hai đầu hồi (tây và đông), không có ở hai cạnh mái hiên', gwp[:gables].map { |g| g[:edge] } == %w[east west] || gwp[:gables].map { |g| g[:edge] }.sort == %w[east west])
g_west = gwp[:gables].find { |g| g[:edge] == 'west' }
g_east = gwp[:gables].find { |g| g[:edge] == 'east' }
under0 = TOP + tv - tv # đáy mái tại mép (cao độ tầng + chân mái 0)
ok('đầu hồi: biên dạng là tam giác theo đáy mái (thấp ở hai góc, cao nhất ở nóc giữa khung)', g_west[:profile].size == 3 && near(g_west[:profile][0][1], TOP) && near(g_west[:profile][1][1], TOP + (Y1 - Y0) / 2.0 * t) && near(g_west[:profile][2][1], TOP) && near(g_west[:profile][1][0], (Y1 - Y0) / 2.0))
ok('đầu hồi: nằm trên trục biên, mặt ngoài trùng trục (tường tây chiếm x từ X0 vào trong, tường đông từ X1 lùi vào), dày theo loại tường', near(g_west[:a][0], X0) && g_west[:inward] == [1.0, 0.0] && near(g_east[:a][0], X1) && g_east[:inward] == [-1.0, 0.0] && g_west[:t] == 200.0)
tri = (Y1 - Y0) * ((Y1 - Y0) / 2.0 * t) / 2.0 / 1e6 + (Y1 - Y0) * (TOP - FLOOR) / 1e6
ok('đầu hồi: diện tích biên dạng = đáy chữ nhật (từ mặt sàn kết cấu tới đáy mái ở hai góc) + tam giác phía trên; chiều cao trung bình x dài = diện tích', near(g_west[:area], tri, 0.01) && near(g_west[:height] * g_west[:length] / 1e6, g_west[:area], 0.01) && near(g_west[:floor], FLOOR))
shw = plan_of(gw('shape' => 'shed', 'slope' => 30, 'dir' => 'x+', 'thickness' => 100, 'overhang' => 0))
ok('mái một dốc lên theo +X: tường thu hồi ở hai cạnh song song hướng dốc (nam và bắc), hình thang; đầu cao và đầu thấp không sinh tường', shw[:gables].map { |g| g[:edge] }.sort == %w[north south] && shw[:gables].all? { |g| g[:profile].size == 2 && near((g[:profile][1][1] - g[:profile][0][1]).abs, (X1 - X0) * t, 0.5) })
shy = plan_of(gw('shape' => 'shed', 'slope' => 30, 'dir' => 'y+', 'thickness' => 100, 'overhang' => 0))
ok('mái một dốc lên theo +Y: tường thu hồi ở hai cạnh tây và đông', shy[:gables].map { |g| g[:edge] }.sort == %w[east west])
ok('không bật tường thu hồi: không có tường nào; mái bằng, bốn dốc cũng không có', plan_of('shape' => 'gable', 'slope' => 30, 'dir' => 'x')[:gables].empty? && plan_of(gw('shape' => 'flat'))[:gables].empty? && plan_of(gw('shape' => 'hip', 'slope' => 30))[:gables].empty?)
ok('loại tường không tồn tại: báo lỗi rõ', error_of { n = norm(roof_state(gw('shape' => 'gable', 'slope' => 30, 'dir' => 'x'))); n['levels'][-1]['roof']['gable_wall'] = {'type' => 'wt_zzzzzzzz'}; S::RoofPlan.plan(n['grid'], n['levels'], n['levels'][-1]['id'], n['wall_types']) }.include?('loại tường'))

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
mh = Sketchup::Model.new
S::RoofBuilder.build(mh, roof_state('shape' => 'hip', 'slope' => 30, 'thickness' => 100), [lid])
hg = mh.entities.grep(Sketchup::Group).find { |x| x.get_attribute(D, 'kind') == 'roofs' }
hplates = hg.entities.grep(Sketchup::Group)
ok('dựng mái bốn dốc: bốn tấm, hình thang có 6 mặt, tam giác có 5 mặt (trên, dưới, các mặt bên)', hplates.size == 4 && hplates.map { |pl| pl.entities.grep(Sketchup::Face).size } == [6, 5, 6, 5])
ok('dựng mái bốn dốc: kiểu "Mái bốn dốc", dữ liệu BIM đủ dày và diện tích', hplates.all? { |pl| pl.get_attribute(D, 'type') == 'Mái bốn dốc' && JSON.parse(pl.get_attribute(D, 'dims'))['area'] > 0 })
mg = Sketchup::Model.new
S::RoofBuilder.build(mg, roof_state(gw('shape' => 'gable', 'slope' => 30, 'dir' => 'x', 'thickness' => 100)), [lid])
gg = mg.entities.grep(Sketchup::Group).find { |x| x.get_attribute(D, 'kind') == 'roofs' }
gwalls = gg.entities.grep(Sketchup::Group).select { |x| x.get_attribute('VGD_BIM_SOURCE', 'kind') == 'wall' }
ok('dựng tường thu hồi: hai tường nằm trong nhóm mái, tag A. WALL, mỗi tường là khối kín (hai mặt đầu hồi + một mặt cho mỗi cạnh biên dạng)', gwalls.size == 2 && gwalls.all? { |x| x.layer.name == 'A. WALL' && x.entities.grep(Sketchup::Face).size == 2 + 5 })
gd = JSON.parse(gwalls[0].get_attribute(D, 'dims'))
ok('dữ liệu BIM của tường thu hồi: kind wall, dày theo loại tường, dài x cao trung bình = diện tích biên dạng', gd['thickness'] == 200.0 && gd['length'] > 0 && gd['height'] > 0 && gwalls[0].get_attribute('VGD_BIM_SOURCE', 'ref').include?('gable') && gwalls[0].get_attribute(D, 'type').include?('thu hồi'))
ok('dựng lại mái bỏ tick tường thu hồi: tường cũ bị thay, không còn tường', (S::RoofBuilder.build(mg, roof_state('shape' => 'gable', 'slope' => 30, 'dir' => 'x', 'thickness' => 100), [lid]) &&
   mg.entities.grep(Sketchup::Group).find { |x| x.get_attribute(D, 'kind') == 'roofs' }.entities.grep(Sketchup::Group).count { |x| x.get_attribute('VGD_BIM_SOURCE', 'kind') == 'wall' }.zero?))
all = S::AllBuilder.build(m, roof_state('shape' => 'flat'), [lid])
ok('dựng tất cả có mái ở tầng trên cùng; dựng lại thay nhóm cũ', all[:kinds].key?('roofs') && m.entities.grep(Sketchup::Group).count { |x| x.get_attribute(D, 'kind') == 'roofs' } == 1)
ok('tầng chưa khai báo mái: dựng mái báo lỗi', error_of { S::RoofBuilder.build(Sketchup::Model.new, S::State.default, [lid]) }.include?('chưa khai báo mái'))

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
