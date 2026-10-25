# Test bản B (beta.25): khoang ngăn kéo. Chạy: ruby test_bay.rb [thư mục runtime]
$stdout.sync = true
RT = File.expand_path(ARGV[0] || '../runtime/VGD_Cabinet_Draw', __dir__)
require 'tmpdir'
require_relative 'mock_su'
$LOAD_PATH.unshift(__dir__)
ENV['APPDATA'] = Dir.mktmpdir('vgdappdata')
load File.join(RT, 'main.rb')
V = VGD_Cabinet_Draw
$pass = 0; $fail = []
def check(name, cond, extra = nil)
  if cond then $pass += 1 else $fail << "#{name} #{extra}"; puts "FAIL: #{name} #{extra}" end
end
def near(a, b, tol = 0.01); (a - b).abs <= tol; end
def mk_box(w, d, h)
  g = Sketchup.active_model.entities.add_group; g.name = 'Box'
  f = g.entities.add_face([[0, 0, 0], [w.mm, 0, 0], [w.mm, d.mm, 0], [0, d.mm, 0]]); f.reverse! if f.normal.z < 0; f.pushpull(h.mm); g
end
def cab(opts = {})
  Sketchup.reset_model!
  c = V::Geometry.cabinet_from_box(mk_box(800, 560, 2000), { 'front_normal' => [0, -1, 0] }.merge(opts))
  sel = Sketchup.active_model.selection; sel.clear; sel.add(c)
  c
end
def bb(e); b = e.bounds; [b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z].map { |x| x.to_mm.round(3) }; end
def groups(ents); ents.to_a.select { |e| e.is_a?(Sketchup::Group) }; end
def container(c); groups(c.definition.entities).find { |e| e.name == 'Ngăn kéo' }; end
def boxes(c); groups(container(c).definition.entities).select { |g| g.name == 'Thùng Ngăn Kéo' }; end
def fronts(c); groups(container(c).definition.entities).select { |g| g.name == 'Mặt Ngăn Kéo' }; end
def box_part(box, name); groups(box.definition.entities).find { |g| g.name == name }; end
def overlap(a, b)
  d = (0..2).map { |i| [[a[i + 3], b[i + 3]].min - [a[i], b[i]].max, 0].max }
  d.inject(:*) > 1e-3 ? d.map { |x| x.round(2) } : nil
end
def shell_defs(c); V::Operations.shell_for(c).definition.entities; end
def bay_group(c); groups(shell_defs(c)).find { |g| g.name == 'Khoang Ngăn Kéo' }; end
def bay_part(c, name); groups(bay_group(c).definition.entities).find { |g| g.name == name }; end
def make_bay(settings = {}, opts = {})
  c = cab(opts)
  V::DrawerBay.run([c], V::Schema.merge_settings({ 'drawer_count' => 3 }.merge(settings)), [])
  c
end

puts '== 1. Dựng khoang + ngăn kéo bằng một lệnh =='
c = make_bay
check 'có nhóm Khoang Ngăn Kéo', !bay_group(c).nil?
check 'khoang có 4 tấm', groups(bay_group(c).definition.entities).length == 4
check '3 mặt hộc', fronts(c).length == 3
check '3 thùng', boxes(c).length == 3
ops = V::Rebuild.ops(c)
check 'ghi đúng 1 bước loại bay', ops.length == 1 && ops[0]['type'] == 'bay', ops.inspect

puts '== 2. Kích thước: hông khoang cách hông tủ 35, lùi 20 sau cánh =='
inner = V::Interior.inner(V::Operations.shell_for(c))
g = bay_group(c)
sh = V::Operations.shell_for(c)
t = 17.5
l = bay_part(c, 'Hông Khoang Trái'); r = bay_part(c, 'Hông Khoang Phải')
bl = bb(l); br = bb(r)
check 'hông khoang trái cách hông tủ 35', near(bl[0], inner.x0.to_mm + 35, 0.05), bl.inspect + " in.x0=#{inner.x0.to_mm}"
check 'hông khoang phải cách hông tủ 35', near(br[3], inner.x1.to_mm - 35, 0.05), br.inspect
check 'tủ cũ (chưa lùi cánh): mặt trước khoang = mặt trước tủ + 20', near(bl[1], 20, 0.05), bl[1].to_s
d = bb(bay_part(c, 'Đáy Khoang')); n = bb(bay_part(c, 'Nóc Khoang'))
check 'đáy khoang dày 17.5', near(d[5] - d[2], 17.5, 0.05)
check 'khoang cao hết ô', near(d[2], inner.z0.to_mm, 0.05) && near(n[5], inner.z1.to_mm, 0.05), "#{d[2]} #{n[5]} #{inner.z0.to_mm} #{inner.z1.to_mm}"

puts '== 3. Ngăn kéo nằm trong khoang, không cấn hông khoang =='
fs = fronts(c).map { |f| bb(f) }
check 'mặt hộc nằm lọt giữa hai hông khoang', fs.all? { |f| f[0] > bl[3] - 0.01 && f[3] < br[0] + 0.01 }, fs.first.inspect
check 'mặt hộc không vượt đáy/nóc khoang', fs.all? { |f| f[2] >= d[5] - 0.01 && f[5] <= n[2] + 0.01 }
check 'mặt hộc ngoài cùng ngang mặt trước khoang', fs.all? { |f| near(f[1], bl[1], 0.05) }, fs.first.inspect + bl.inspect
all_boxes = boxes(c).map { |b| bb(b) }
check 'thùng không xuyên hông khoang', all_boxes.all? { |b| b[0] >= bl[3] - 0.01 && b[3] <= br[0] + 0.01 }, all_boxes.first.inspect
check 'thùng không xuyên đáy/nóc khoang', all_boxes.all? { |b| b[2] >= d[5] - 0.01 && b[5] <= n[2] + 0.01 }
check 'thùng không vượt phía sau khoang', all_boxes.all? { |b| b[4] <= bl[4] + 0.01 }
all = [bb(bay_part(c, 'Đáy Khoang')), bb(bay_part(c, 'Nóc Khoang')), bl, br]
clash = boxes(c).flat_map { |b| groups(b.definition.entities).map { |p| bb(p) } }.any? { |p| all.any? { |q| overlap(p, q) } }
check 'thùng ngăn kéo không xuyên 4 tấm khoang', !clash

puts '== 4. Chỉnh trong bảng: lùi, khe hông, cao khoang =='
c2 = make_bay({ 'bay_setback' => 40, 'bay_side_gap' => 50, 'bay_height' => 500, 'drawer_count' => 2 })
bl2 = bb(bay_part(c2, 'Hông Khoang Trái')); in2 = V::Interior.inner(V::Operations.shell_for(c2))
check 'khe hông 50', near(bl2[0], in2.x0.to_mm + 50, 0.05)
check 'lùi 40', near(bl2[1], 40, 0.05), bl2[1].to_s
d2 = bb(bay_part(c2, 'Đáy Khoang')); n2 = bb(bay_part(c2, 'Nóc Khoang'))
check 'cao khoang 500', near(n2[5] - d2[2], 500, 0.05), (n2[5] - d2[2]).to_s
check '2 mặt hộc', fronts(c2).length == 2

puts '== 5. Lỗi rõ ràng =='
begin
  make_bay({ 'bay_side_gap' => 340 }); check 'khe hông quá lớn phải báo lỗi', false
rescue StandardError => e
  check 'khe hông quá lớn báo "Khoang quá hẹp"', e.message.include?('Khoang quá hẹp'), e.message
end

puts '== 6. Sửa tủ dựng lại đủ khoang + ngăn kéo =='
c3 = make_bay
before = [fronts(c3).length, boxes(c3).length]
res = V::Rebuild.run(c3, V::Rebuild.settings_of(c3), V::Rebuild.dimensions_of(c3), []) rescue (puts "rebuild lỗi: #{$!.message}"; nil)
check 'dựng lại không lỗi', !res.nil?
check 'sau dựng lại vẫn 1 khoang', groups(shell_defs(c3)).count { |g| g.name == 'Khoang Ngăn Kéo' } == 1
check 'sau dựng lại vẫn 3 mặt + 3 thùng', [fronts(c3).length, boxes(c3).length] == before, [fronts(c3).length, boxes(c3).length].inspect
check 'bước tạo vẫn 1 bước bay', V::Rebuild.ops(c3).length == 1

puts '== 7. Tủ có cánh lọt/phủ + lùi cánh =='
%w[phu lot].each do |fit|
  cc = cab('door_fit' => fit)
  dt = V::Tools::DoorTool.new(V::Schema.merge_settings({ 'door_fit' => fit }))
  dt.load_cabinet(cc) rescue nil
  V::DrawerBay.run([cc], V::Schema.merge_settings({ 'drawer_count' => 2 }), [])
  check "fit #{fit}: có khoang và 2 mặt hộc", !bay_group(cc).nil? && fronts(cc).length == 2
end

puts '== 7b. Tủ đã lùi thùng theo cánh: khoang lùi 20 tính từ mặt trong cánh =='
cr = cab
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(cr)
dtool = V::Tools::DoorTool.new(V::Schema.merge_settings({ 'door_fit' => 'phu' })); dtool.activate
dtool.layout.split(dtool.layout.regions.first['id'], 'vertical', 0.5)
dtool.commit(Sketchup.active_model.active_view)
V::DrawerBay.run([cr], V::Schema.merge_settings({ 'drawer_count' => 2 }), [])
blr = bb(bay_part(cr, 'Hông Khoang Trái'))
check 'cánh lùi: mặt trước khoang = 17.5 + 20', near(blr[1], 37.5, 0.05), blr.inspect
wr = V::Rebuild.run(cr, V::Rebuild.settings_of(cr), V::Rebuild.dimensions_of(cr), []) rescue (puts "lỗi: #{$!.message}"; nil)
check 'tủ lùi cánh dựng lại được, khoang giữ nguyên chỗ', !wr.nil? && near(bb(bay_part(cr, 'Hông Khoang Trái'))[1], 37.5, 0.05)

puts '== 8. Hộc tủ áo cũ vẫn dựng lại được =='
cw = cab
V::Operations.wardrobe([cw], V::Schema.merge_settings({}), [])
res = V::Rebuild.run(cw, V::Rebuild.settings_of(cw), V::Rebuild.dimensions_of(cw), []) rescue (puts "lỗi: #{$!.message}"; nil)
check 'tủ có hộc áo cũ dựng lại được', !res.nil?
check 'hộc áo cũ còn nguyên', groups(shell_defs(cw)).count { |g| g.name == 'Hộc Tủ Áo' } == 1

puts '== 9. Menu và HUD =='
check 'công cụ bay có HUD', V::PresetHud::SPECS.key?('bay')
keys = V::PresetHud::SPECS['bay'][:params].map { |p| p[:key] }
check 'HUD có lùi/khe/cao khoang', %w[bay_setback bay_side_gap bay_height drawer_count].all? { |k| keys.include?(k) }
check 'mặc định 20 và 35', V::Schema::DEFAULTS['bay_setback'] == 20.0 && V::Schema::DEFAULTS['bay_side_gap'] == 35.0
check 'công cụ bay tạo được', V::Tools.build('bay', {}).is_a?(V::Tools::SelectAndApplyTool)
puts
puts "Đạt: #{$pass}   Không đạt: #{$fail.length}"
exit($fail.empty? ? 0 : 1)
