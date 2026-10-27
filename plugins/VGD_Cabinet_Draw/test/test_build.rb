# Kiểm tra DỰNG HÌNH bằng số đo (mm): các tấm không xuyên nhau, đúng vị trí theo chuẩn xưởng.
def reselect(e); s = Sketchup.active_model.selection; s.clear; s.add(e); end
# Mỗi mục ứng với một lỗi trong báo cáo review beta.12. Chạy: ruby test_build.rb [thư mục runtime]
$stdout.sync = true
RT = File.expand_path(ARGV[0] || '../runtime/VGD_Cabinet_Draw', __dir__)
require 'tmpdir'
require_relative 'mock_su'
$LOAD_PATH.unshift(__dir__)
ENV['APPDATA'] = Dir.mktmpdir('vgdappdata')
load File.join(RT, 'main.rb')
V = VGD_Cabinet_Draw
DICT = 'VGD_Cabinet_Draw'.freeze
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
def overlap(a, b)
  d = (0..2).map { |i| [[a[i + 3], b[i + 3]].min - [a[i], b[i]].max, 0].max }
  d.inject(:*) > 1e-3 ? d.map { |x| x.round(2) } : nil
end
def groups(ents); ents.to_a.select { |e| e.is_a?(Sketchup::Group) }; end
def shell(c); V::Geometry.shell_for(c); end
def part(c, name); groups(shell(c).definition.entities).find { |p| p.name == name }; end
def parts_named(c, prefix); groups(shell(c).definition.entities).select { |p| p.name.start_with?(prefix) }; end
def container(c, name); groups(c.definition.entities).find { |e| e.name == name }; end
V::Keys.platform = :windows
v = Sketchup.active_model.active_view
def at(x, z, y = -10); Geom::Point3d.new(x.mm, y.mm, z.mm); end
def hover_panel(tool, c, x, z)
  vv = Sketchup.active_model.active_view
  vv.fake_path = [c]; vv.fake_point = at(x, z)
  tool.onMouseMove(0, 5, 5, vv)
end

# Mọi khối lá (tấm) trong tủ, cùng hệ thùng tủ: [tên, hộp]. Bỏ ký hiệu mở.
def leaves(c)
  out = []
  groups(shell(c).definition.entities).each do |g|
    kids = groups(g.definition.entities)
    if kids.empty? then out << [g.name, bb(g)] else kids.each { |k| out << ["#{g.name}/#{k.name}", bb(k)] } end
  end
  ['Cánh', 'Ngăn kéo'].each do |cn|
    box = container(c, cn)
    next unless box
    groups(box.definition.entities).each do |g|
      groups(g.definition.entities).each do |k|
        next if k.name == 'Ký Hiệu Hướng Mở'
        sub = groups(k.definition.entities)
        if sub.empty? || k.name == 'Kính' then out << ["#{g.name}/#{k.name}", bb(k)] else sub.each { |s| out << ["#{g.name}/#{k.name}/#{s.name}", bb(s)] } end
      end
    end
  end
  out
end
# Hậu ngậm rãnh nằm trong rãnh của hông/nóc/đáy: hộp bao chồng nhau là đúng thiết kế.
GROOVE_PAIR = ->(a, b) { [a, b].include?('Hậu') && ([a, b] & ['Hông Trái', 'Hông Phải', 'Nóc', 'Đáy']).any? }
def clashes(c)
  list = leaves(c)
  out = []
  list.each_with_index do |(na, a), i|
    list[(i + 1)..-1].each do |nb, b|
      next if GROOVE_PAIR.call(na, nb)
      o = overlap(a, b)
      out << "#{na} × #{nb} #{o.inspect}" if o
    end
  end
  out
end

puts '== 1. Đợt dừng ở mặt trước tấm hậu, lùi 20 mm (cánh phủ) =='
c = cab
pt = V::Tools::PanelTool.new({}); reselect(c); pt.activate; pt.onUserText('/2', v); pt.commit(v)
shelf = parts_named(c, 'Đợt').first; back = part(c, 'Hậu')
check 'đợt không cắt hậu', overlap(bb(shelf), bb(back)).nil?, bb(shelf).inspect
check 'đợt sát mặt trước hậu (khe 0)', near(bb(shelf)[4], bb(back)[1]), [bb(shelf)[4], bb(back)[1]].inspect
check 'đợt lùi 20 mm so với mặt trước', near(bb(shelf)[1], 20.0), bb(shelf)[1]
check 'đợt có vai trò shelf + tag', V::ModelData.params(shelf)['role'] == 'shelf' && shelf.layer.to_s.include?('VGD_CD_PARTS') || (shelf.layer && shelf.layer.name == 'VGD_CD_PARTS')
c = cab('back_mode' => 'overlay')
pt = V::Tools::PanelTool.new({}); reselect(c); pt.activate; pt.onUserText('/2', v); pt.commit(v)
check 'hậu phủ: đợt không cắt hậu', overlap(bb(parts_named(c, 'Đợt').first), bb(part(c, 'Hậu'))).nil?

puts '== 2. Tủ dày 18: công cụ đo tấm thật, không cắm vào hông =='
c = cab('board_thickness' => 18)
pt = V::Tools::PanelTool.new({}); reselect(c); pt.activate; pt.settings['panel_axis'] = 'horizontal'; pt.onUserText('/2', v); pt.commit(v)
check 'đợt bắt đầu đúng mặt trong hông 18 mm', near(bb(parts_named(c, 'Đợt').first)[0], 18.0), bb(parts_named(c, 'Đợt').first).inspect
check 'tủ dày 18: không tấm nào xuyên nhau', clashes(c).empty?, clashes(c).first(3).inspect

puts '== 3. Vách/đợt giới hạn trong ô; gõ khoảng cách =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
pv = V::Tools::PanelTool.new({}); reselect(c); pv.activate; pv.settings['panel_axis'] = 'vertical'; pv.onUserText('/2', v); pv.commit(v)
wall = parts_named(c, 'Vách').first
check 'vách bằng mặt trước, dừng ở hậu', near(bb(wall)[1], 0.0) && near(bb(wall)[4], bb(part(c, 'Hậu'))[1])
check 'vách có vai trò partition', V::ModelData.params(wall)['role'] == 'partition'
ps = V::Tools::PanelTool.new({}); reselect(c); ps.activate; ps.settings['panel_axis'] = 'horizontal'
hover_panel(ps, c, 200, 1000)
ps.onUserText('350', v)
ps.commit(v)
s1 = parts_named(c, 'Đợt').first
check 'đợt trong ô trái: dừng ở vách', near(bb(s1)[0], 17.5) && near(bb(s1)[3], bb(wall)[0]), bb(s1).inspect
check 'gõ 350: đợt cách đáy ô 350 mm', near(bb(s1)[2], 17.5 + 350), bb(s1)[2]
ps2 = V::Tools::PanelTool.new({}); reselect(c); ps2.activate; ps2.settings['panel_axis'] = 'horizontal'
hover_panel(ps2, c, 600, 1500); ps2.onUserText('/2', v); ps2.commit(v)
s2 = parts_named(c, 'Đợt').find { |p| p != s1 }
check 'đợt ô phải: từ vách tới hông phải', near(bb(s2)[0], bb(wall)[3]) && near(bb(s2)[3], 800 - 17.5), bb(s2).inspect
check 'tủ có vách + đợt: không xuyên nhau', clashes(c).empty?, clashes(c).first(3).inspect

puts '== 4. Ngăn kéo không làm lệch thân tủ; nằm trong nhóm riêng =='
c = cab
y0 = V::Geometry.body_bounds(shell(c)).min.y
V::Operations.drawers([c], V::Schema.merge_settings({ 'drawer_count' => 3, 'drawer_front_height' => 0 }), [])
check 'thân tủ không đổi sau ngăn kéo', near(V::Geometry.body_bounds(shell(c)).min.y, y0)
check 'ngăn kéo nằm trong nhóm Ngăn kéo', container(c, 'Ngăn kéo') && groups(container(c, 'Ngăn kéo').definition.entities).count { |g| g.name == 'Mặt Ngăn Kéo' } == 3
reselect(c); dt = V::Tools::DoorTool.new({}); dt.activate
check 'cánh tạo sau ngăn kéo: mặt ngoài trùm mặt trước box', near(dt.cells(V::Geometry.body_bounds(shell(c))).first[:y].to_mm, 17.5)

puts '== 5. Mặt hộc phủ: thẳng mép với cánh phủ; thùng đúng chỗ =='
fronts = groups(container(c, 'Ngăn kéo').definition.entities).select { |g| g.name == 'Mặt Ngăn Kéo' }.map { |g| V::Operations.door_bounds(g).map { |x| x.to_mm.round(3) } }.sort_by { |b| b[2] }
check 'mặt hộc phủ hết bề ngang thân tủ (0 → 800)', fronts.all? { |b| near(b[0], 0) && near(b[3], 800) }, fronts.first.inspect
check 'mặt hộc dưới phủ đáy (từ 40), trên cùng phủ nóc (tới 1980)', near(fronts.first[2], 40) && near(fronts.last[5], 1980), [fronts.first[2], fronts.last[5]].inspect
check 'mặt hộc áp sát mặt trước thân tủ', fronts.all? { |b| near(b[4], 0) && near(b[1], -17.5) }
boxes = groups(container(c, 'Ngăn kéo').definition.entities).select { |g| g.name == 'Thùng Ngăn Kéo' }
bx = boxes.first; kids = groups(bx.definition.entities).map { |k| [k.name, bb(k)] }.to_h
check 'thùng nằm ngay sau mặt hộc (y bắt đầu 0)', near(kids['Hông Trái'][1], 0.0), kids['Hông Trái'].inspect
check 'ray bi: chừa 13 mm mỗi bên', near(kids['Hông Trái'][0], 17.5 + 13) && near(kids['Hông Phải'][3], 800 - 17.5 - 13)
check 'đáy thùng phủ hết chân thùng (không bậc hở)', near(kids['Đáy'][0], kids['Hông Trái'][0]) && near(kids['Đáy'][3], kids['Hông Phải'][3]) && near(kids['Đáy'][2] + 8, kids['Hông Trái'][2]), kids['Đáy'].inspect
check 'đáy thùng dày 8 mm', near(kids['Đáy'][5] - kids['Đáy'][2], 8.0)
check 'sâu thùng theo ray chuẩn 500 mm', near(kids['Hông Trái'][4] - kids['Hông Trái'][1], 500.0), kids['Hông Trái'].inspect
check 'thùng thấp nhất nằm trên mặt đáy tủ (+10)', near(boxes.map { |b| bb(b)[2] }.min, 57.5 + 10)
check 'ngăn kéo + thùng: không xuyên nhau', clashes(c).empty?, clashes(c).first(3).inspect

puts '== 6. Ngăn kéo ray âm, mặt hộc lọt =='
c = cab
V::Operations.drawers([c], V::Schema.merge_settings({ 'drawer_count' => 2, 'drawer_slide' => 'under', 'drawer_fit' => 'lot' }), [])
fr = groups(container(c, 'Ngăn kéo').definition.entities).select { |g| g.name == 'Mặt Ngăn Kéo' }.map { |g| V::Operations.door_bounds(g).map { |x| x.to_mm.round(3) } }
check 'mặt hộc lọt: trong lòng tủ, chừa khe 2 mm', fr.all? { |b| near(b[0], 17.5 + 2) && near(b[3], 800 - 17.5 - 2) && near(b[1], 0) && near(b[4], 17.5) }, fr.first.inspect
bxs = groups(container(c, 'Ngăn kéo').definition.entities).select { |g| g.name == 'Thùng Ngăn Kéo' }
k = groups(bxs.first.definition.entities).map { |x| [x.name, bb(x)] }.to_h
check 'ray âm: lòng thùng = lòng ô − 42', near(k['Hông Phải'][0] - k['Hông Trái'][3], 765 - 42), (k['Hông Phải'][0] - k['Hông Trái'][3])
check 'mặt hộc lọt: thùng bắt đầu sau mặt hộc', near(k['Hông Trái'][1], 17.5)
check 'ray âm + lọt: không xuyên nhau', clashes(c).empty?, clashes(c).first(3).inspect

puts '== 7. Ngăn kéo trong ô dưới đợt: mặt hộc phủ nửa đợt =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
ps = V::Tools::PanelTool.new({}); reselect(c); ps.activate; ps.settings['panel_axis'] = 'horizontal'; hover_panel(ps, c, 400, 600); ps.onUserText('700', v); ps.commit(v)
sh = parts_named(c, 'Đợt').first
dk = V::Tools.build('drawer', { 'drawer_count' => 2, 'drawer_gap' => 3 }); dk.activate
vv = Sketchup.active_model.active_view; vv.fake_path = [c]; vv.fake_point = at(400, 300)
dk.onMouseMove(0, 5, 5, vv); dk.onLButtonDown(0, 5, 5, vv); dk.commit(vv)
fr = groups(container(c, 'Ngăn kéo').definition.entities).select { |g| g.name == 'Mặt Ngăn Kéo' }.map { |g| V::Operations.door_bounds(g).map { |x| x.to_mm.round(3) } }.sort_by { |b| b[2] }
mid = (bb(sh)[2] + bb(sh)[5]) / 2
check 'mặt hộc trên dừng ở tim đợt trừ nửa khe', near(fr.last[5], mid - 1.5), [fr.last[5], mid].inspect
check 'khe giữa 2 mặt hộc 3 mm', near(fr.last[2] - fr.first[5], 3.0)
check 'ô dưới đợt: không xuyên nhau', clashes(c).empty?, clashes(c).first(3).inspect

puts '== 8. Cánh lọt và đợt =='
c = cab
reselect(c); dl = V::Tools::DoorTool.new({ 'door_fit' => 'lot' }); dl.activate; dl.commit(v)
pl = V::Tools::PanelTool.new({}); reselect(c); pl.activate; pl.onUserText('/3', v); pl.commit(v)
check 'đợt tạo sau cánh lọt tự lùi thêm dày cánh (20 + 17.5)', parts_named(c, 'Đợt').all? { |s| near(bb(s)[1], 37.5) }, parts_named(c, 'Đợt').map { |s| bb(s)[1] }.inspect
check 'cánh lọt + đợt: không xuyên nhau', clashes(c).empty?, clashes(c).first(3).inspect
door = V::Operations.doors_of(c).first
db = V::Operations.door_bounds(door).map { |x| x.to_mm.round(3) }
check 'cánh lọt: giữa hai hông + khe 2 mm, cao phủ nóc và đáy, mặt ngoài trùng mặt trước box', near(db[0], 19.5) && near(db[3], 780.5) && near(db[2], 40.0) && near(db[5], 1980.0) && near(db[1], 0.0) && near(db[4], 17.5), db.inspect
c = cab
pf = V::Tools::PanelTool.new({ 'panel_door_fit' => 'lot' }); pf.activate; pf.onUserText('/2', v); pf.commit(v)
reselect(c); dl = V::Tools::DoorTool.new({ 'door_fit' => 'lot' }); dl.activate; dl.commit(v)
check 'đợt tạo TRƯỚC, chọn "cánh lọt": không chạm cánh', clashes(c).empty?, clashes(c).first(3).inspect
c = cab
pf = V::Tools::PanelTool.new({}); reselect(c); pf.activate; pf.onUserText('/2', v); pf.commit(v)
reselect(c); dl = V::Tools::DoorTool.new({ 'door_fit' => 'lot' }); dl.activate; dl.commit(v)
check 'đợt cánh phủ (lùi 20) vẫn không chạm cánh lọt dày 17.5', clashes(c).empty? && dl.shelf_clash_warning == ''
c = cab
pf = V::Tools::PanelTool.new({ 'shelf_front_setback' => 0 }); pf.activate; pf.onUserText('/2', v); pf.commit(v)
reselect(c); dl = V::Tools::DoorTool.new({ 'door_fit' => 'lot' }); dl.activate; dl.commit(v)
check 'đợt cũ (lùi 0) khi chốt cánh lọt: tự lùi theo dày cánh, không chạm cánh', clashes(c).empty? && dl.shelf_clash_warning == '', dl.shelf_clash_warning.inspect

puts '== 9. Xà chặn và hộc tủ áo nằm trong lòng tủ =='
c = cab
V::Operations.blockers([c], V::Schema.merge_settings({ 'blocker_profile' => 'C' }), [])
check 'xà C: không cắm vào hông/hậu', clashes(c).empty?, clashes(c).first(3).inspect
c = cab
V::Operations.blockers([c], V::Schema.merge_settings({ 'blocker_profile' => 'I' }), [])
check 'xà I: không xuyên nhau', clashes(c).empty?, clashes(c).first(3).inspect
c = cab
V::Operations.blockers([c], V::Schema.merge_settings({ 'blocker_profile' => 'L' }), [])
check 'xà L: không xuyên nhau', clashes(c).empty?, clashes(c).first(3).inspect
c = cab
V::Operations.wardrobe([c], V::Schema.merge_settings({}), [])
check 'hộc tủ áo: không xuyên nhau', clashes(c).empty?, clashes(c).first(3).inspect

puts '== 10. Tay nắm =='
c = cab
reselect(c); dt = V::Tools::DoorTool.new({}); dt.activate
dt.layout.split(dt.layout.regions.first['id'], 'vertical', 0.5); dt.commit(v)
doors = V::Operations.doors_of(c).sort_by { |d| V::Operations.door_bounds(d)[0] }
V::Operations.apply_opening_metadata(doors[0], 'left')
V::Operations.apply_opening_metadata(doors[1], 'right')
p0 = V::Operations.hinge_pivot(doors[0], 'left').to_a
V::Operations.handles(doors, V::Schema.merge_settings({}), [])
h0 = groups(doors[0].definition.entities).find { |g| g.name == 'Tay Nắm' }
h1 = groups(doors[1].definition.entities).find { |g| g.name == 'Tay Nắm' }
d0 = V::Operations.door_bounds(doors[0]).map { |x| x.to_mm.round(3) }
check 'tay nắm áp sát mặt cánh (không lơ lửng)', near(bb(h0)[4], d0[1]), [bb(h0)[4], d0[1]].inspect
check 'tay nắm nhô ra 30 mm', near(d0[1] - bb(h0)[1], 30.0)
check 'thêm tay nắm KHÔNG dời trục bản lề', V::Operations.hinge_pivot(doors[0], 'left').to_a.zip(p0).all? { |a, b| (a - b).abs < 1e-9 }
check 'bản lề trái: tay nắm dọc gần mép phải (cách 50)', near((bb(h0)[0] + bb(h0)[3]) / 2, d0[3] - 50) && (bb(h0)[5] - bb(h0)[2]) > (bb(h0)[3] - bb(h0)[0])
d1 = V::Operations.door_bounds(doors[1]).map { |x| x.to_mm.round(3) }
check 'bản lề phải: tay nắm gần mép trái', near((bb(h1)[0] + bb(h1)[3]) / 2, d1[0] + 50)
check 'cánh cao 1940: tâm tay nắm ở cao 1000 mm', near((bb(h0)[2] + bb(h0)[5]) / 2, 1000.0), (bb(h0)[2] + bb(h0)[5]) / 2
V::Operations.set_door_angle(doors[0], 'left', 60)
reselect(c); dt2 = V::Tools::DoorTool.new({}); dt2.activate; dt2.commit(v)
again = V::Operations.doors_of(c).sort_by { |d| V::Operations.door_bounds(d)[0] }
check 'chia lại cánh: giữ tay nắm', again.all? { |d| groups(d.definition.entities).any? { |g| g.name == 'Tay Nắm' } }
check 'chia lại cánh: giữ góc mở 60°', again.any? { |d| near(V::Operations.door_angle(d), 60.0) }
dw = V::Operations.drawers([cab], V::Schema.merge_settings({ 'drawer_count' => 1 }), [])
c = Sketchup.active_model.entities.to_a.find { |e| V::ModelData.cabinet?(e) }
front = groups(container(c, 'Ngăn kéo').definition.entities).find { |g| g.name == 'Mặt Ngăn Kéo' }
V::Operations.handles([front], V::Schema.merge_settings({}), [])
hf = groups(front.definition.entities).find { |g| g.name == 'Tay Nắm' }
fb = V::Operations.door_bounds(front).map { |x| x.to_mm.round(3) }
check 'mặt hộc: tay nắm ngang ở giữa', near((bb(hf)[0] + bb(hf)[3]) / 2, (fb[0] + fb[3]) / 2) && (bb(hf)[3] - bb(hf)[0]) > (bb(hf)[5] - bb(hf)[2])

puts '== 11. Chân tủ =='
c = cab
trim = container(c, 'Chân & phào')
names = groups(trim.definition.entities).map(&:name)
check 'có ván chân sau đỡ thân tủ', names.include?('Ván chân sau')
back_kick = groups(trim.definition.entities).find { |g| g.name == 'Ván chân sau' }
check 'ván chân sau sát mặt sau tủ', near(bb(back_kick)[4], 560.0)
c = cab('sides_to_floor' => true, 'panels' => { 'bottom' => { 'cover_left' => true } })
kick = groups(container(c, 'Chân & phào').definition.entities).find { |g| g.name == 'Ván chân' }
check 'đáy trùm hông trái + hông chạm đất: ván chân kín bên trái', near(bb(kick)[0], 0.0) && near(bb(kick)[3], 800 - 17.5), bb(kick).inspect

puts '== 12. Đố kính không chồng nhau =='
parts = V::DoorGeometry.parts({ x0: 0, x1: 600.mm, z0: 0, z1: 900.mm, y: 0 }, V::Schema.merge_settings({ 'door_style' => 'glass', 'glass_rows' => 3, 'glass_columns' => 2 }))
bars = parts.select { |p| p[:name].start_with?('Đố') }.map { |p| xs = p[:polygon].map(&:first); zs = p[:polygon].map(&:last); [xs.min, zs.min, xs.max, zs.max] }
ov = bars.combination(2).count { |a, b| [a[2], b[2]].min - [a[0], b[0]].max > 1e-6 && [a[3], b[3]].min - [a[1], b[1]].max > 1e-6 }
check 'đố dọc/ngang không chồng nhau', ov.zero?, ov

puts '== 13. Tủ đầy đủ: thùng + vách + đợt + ngăn kéo + cánh + tay nắm =='
c = cab
pv = V::Tools::PanelTool.new({}); reselect(c); pv.activate; pv.settings['panel_axis'] = 'vertical'; pv.onUserText('/2', v); pv.commit(v)
ps = V::Tools::PanelTool.new({}); reselect(c); ps.activate; ps.settings['panel_axis'] = 'horizontal'; hover_panel(ps, c, 600, 1000); ps.onUserText('/4', v); ps.commit(v)
pl = V::Tools::PanelTool.new({}); reselect(c); pl.activate; pl.settings['panel_axis'] = 'horizontal'; hover_panel(pl, c, 200, 1000); pl.onUserText('600', v); pl.commit(v)
dk = V::Tools.build('drawer', { 'drawer_count' => 3, 'drawer_gap' => 2 }); dk.activate
vv.fake_path = [c]; vv.fake_point = at(200, 300); dk.onMouseMove(0, 5, 5, vv); dk.onLButtonDown(0, 5, 5, vv); dk.commit(vv)
check 'tủ đầy đủ: không có hai tấm nào xuyên nhau', clashes(c).empty?, clashes(c).first(5).inspect
check 'tủ đầy đủ: mọi tấm đều có vai trò', groups(shell(c).definition.entities).all? { |g| V::ModelData.params(g)['role'] }

puts '== 14. Tủ bếp dưới: 2 thanh giằng thay nóc, chân 100 lùi 50 =='
def kcab(w, d, h, opts)
  Sketchup.reset_model!
  c = V::Geometry.cabinet_from_box(mk_box(w, d, h), { 'front_normal' => [0, -1, 0] }.merge(V::Schema::TYPE_PRESETS[opts['cabinet_type']] || {}).merge(opts))
  sel = Sketchup.active_model.selection; sel.clear; sel.add(c)
  c
end
c = kcab(800, 580, 820, { 'cabinet_type' => 'base' })
names = groups(shell(c).definition.entities).map(&:name)
check 'bếp dưới: không có nóc, có 2 giằng', !names.include?('Nóc') && names.include?('Giằng trước') && names.include?('Giằng sau'), names.inspect
gf = bb(part(c, 'Giằng trước')); gs = bb(part(c, 'Giằng sau')); bk = bb(part(c, 'Hậu'))
check 'giằng trước nằm ngang 100 mm sát mặt trước, ở đỉnh tủ', near(gf[1], 0) && near(gf[4], 100) && near(gf[5], 820) && near(gf[5] - gf[2], 17.5), gf.inspect
check 'giằng sau đứng 100 mm áp mặt trước hậu', near(gs[4], bk[1]) && near(gs[5] - gs[2], 100) && near(gs[4] - gs[1], 17.5), gs.inspect
check 'giằng nằm giữa hai hông', near(gf[0], 17.5) && near(gf[3], 782.5)
check 'hông cao tới đỉnh tủ (mặt đá đặt lên)', near(bb(part(c, 'Hông Trái'))[5], 820)
kick = groups(container(c, 'Chân & phào').definition.entities).map { |g| [g.name, bb(g)] }.to_h
check 'chân 100, len chân lùi 50, có ván chân sau', near(kick['Ván chân'][5], 100) && near(kick['Ván chân'][1], 50) && kick.key?('Ván chân sau') && !kick.key?('Phào trần'), kick.keys.inspect
check 'bếp dưới: không xuyên nhau', clashes(c).empty?, clashes(c).first(3).inspect
inner = V::Interior.inner(shell(c))
check 'lòng tủ dưới tính tới mặt dưới giằng trước', near(inner.z1.to_mm, 820 - 17.5) && inner.top.kind == :outer
V::Operations.drawers([c], V::Schema.merge_settings({ 'drawer_count' => 3 }), [])
reselect(c); dt = V::Tools::DoorTool.new({}); dt.activate
check 'bếp dưới + 3 ngăn kéo: không xuyên nhau (thùng trên cùng tránh giằng)', clashes(c).empty?, clashes(c).first(3).inspect
fr = groups(container(c, 'Ngăn kéo').definition.entities).select { |g| g.name == 'Mặt Ngăn Kéo' }.map { |g| V::Operations.door_bounds(g).map { |x| x.to_mm.round(3) } }
check 'mặt hộc trên cùng phủ tới đỉnh tủ', near(fr.map { |b| b[5] }.max, 820)
c = kcab(800, 580, 820, { 'cabinet_type' => 'base' })
pt = V::Tools::PanelTool.new({}); reselect(c); pt.activate; pt.onUserText('/2', v); pt.commit(v)
reselect(c); dd = V::Tools::DoorTool.new({}); dd.activate; dd.commit(v)
check 'bếp dưới + đợt + cánh: không xuyên nhau', clashes(c).empty?, clashes(c).first(3).inspect
c = kcab(800, 580, 820, { 'cabinet_type' => 'base', 'top_mode' => 'full' })
check 'bếp dưới chọn nóc nguyên tấm', groups(shell(c).definition.entities).map(&:name).include?('Nóc')

puts '== 15. Tủ bếp trên: xà treo =='
c = kcab(800, 350, 720, { 'cabinet_type' => 'wall' })
names = groups(shell(c).definition.entities).map(&:name)
check 'bếp trên: có nóc, đáy, xà treo; không chân/phào', names.include?('Nóc') && names.include?('Đáy') && names.include?('Xà treo') && container(c, 'Chân & phào').nil?, names.inspect
xt = bb(part(c, 'Xà treo')); bk = bb(part(c, 'Hậu')); top = bb(part(c, 'Nóc'))
check 'xà treo áp hậu, sát dưới nóc, cao 100', near(xt[4], bk[1]) && near(xt[5], top[2]) && near(xt[5] - xt[2], 100), xt.inspect
pt = V::Tools::PanelTool.new({}); reselect(c); pt.activate; hover_panel(pt, c, 400, 400); pt.onUserText('620', v); pt.commit(v)
sh = parts_named(c, 'Đợt').first
check 'đợt sát nóc dừng trước xà treo', near(bb(sh)[4], xt[1]), [bb(sh)[4], xt[1]].inspect
pt = V::Tools::PanelTool.new({}); reselect(c); pt.activate; hover_panel(pt, c, 400, 200); pt.onUserText('200', v); pt.commit(v)
low = parts_named(c, 'Đợt').find { |p| p != sh }
check 'đợt thấp vẫn sâu tới mặt hậu', near(bb(low)[4], bk[1]), bb(low).inspect
reselect(c); dd = V::Tools::DoorTool.new({}); dd.activate; dd.commit(v)
check 'bếp trên + đợt + cánh: không xuyên nhau', clashes(c).empty?, clashes(c).first(3).inspect

puts '== 16. Thùng tủ lạnh =='
fopts = { 'cabinet_type' => 'fridge', 'fridge_width' => 700, 'fridge_height' => 1800, 'fridge_depth' => 650, 'fridge_side_gap' => 20, 'fridge_top_gap' => 80, 'fridge_back_gap' => 50 }
c = kcab(800, 700, 2400, fopts)
bo = bb(part(c, 'Đáy')); bk = bb(part(c, 'Hậu')); hl = bb(part(c, 'Hông Trái'))
check 'hông chạm đất', near(hl[2], 0)
check 'đáy hộc trên ở cao tủ lạnh + khe trên (1880)', near(bo[2], 1880), bo.inspect
check 'phần tủ lạnh không có hậu (hậu bắt đầu từ hộc trên)', bk[2] >= 1880 - 9 && bk[2] < 1897.5, bk.inspect
check 'không chân, không ván chân', container(c, 'Chân & phào').nil? || groups(container(c, 'Chân & phào').definition.entities).none? { |g| g.name.start_with?('Ván chân') }
bodyb = V::Geometry.body_bounds(shell(c))
check 'thân tủ (cho cánh/đợt) bắt đầu ở hộc trên', near(bodyb.min.z.to_mm, 1880)
ref = groups(c.definition.entities).find { |g| g.name == 'Tủ lạnh (tham chiếu)' }
check 'có khối tham chiếu tủ lạnh 700×650×1800 giữa thùng', ref && near(bb(ref)[0], 50) && near(bb(ref)[3] - bb(ref)[0], 700) && near(bb(ref)[5], 1800) && near(bb(ref)[4], 650), ref && bb(ref).inspect
check 'tủ lạnh tham chiếu không chạm hông', ref && overlap(bb(ref), hl).nil? && overlap(bb(ref), bb(part(c, 'Hông Phải'))).nil? && overlap(bb(ref), bo).nil?
pt = V::Tools::PanelTool.new({}); reselect(c); pt.activate; pt.onUserText('/2', v); pt.commit(v)
sh = parts_named(c, 'Đợt').first
check 'đợt chỉ nằm trong hộc trên', bb(sh)[2] > 1897.5, bb(sh).inspect
reselect(c); dd = V::Tools::DoorTool.new({}); dd.activate; dd.commit(v)
db = V::Operations.door_bounds(V::Operations.doors_of(c).first).map { |x| x.to_mm.round(3) }
check 'cánh chỉ che hộc trên (từ 1880 tới 2380)', near(db[2], 1880) && near(db[5], 2380), db.inspect
check 'thùng tủ lạnh + đợt + cánh: không xuyên nhau', clashes(c).empty?, clashes(c).first(3).inspect
err = (begin; kcab(800, 700, 2400, fopts.merge('fridge_width' => 750)); nil; rescue ArgumentError => e; e.message; end)
check 'thùng hẹp hơn tủ lạnh + khe: báo lỗi rõ', err.to_s.include?('hẹp') && err.to_s.include?('790'), err
err = (begin; kcab(800, 650, 2400, fopts); nil; rescue ArgumentError => e; e.message; end)
check 'thùng nông: báo lỗi', err.to_s.include?('nông'), err
puts '== 17. Vách khấu xà (không hở phía sau) =='
c = kcab(800, 350, 720, { 'cabinet_type' => 'wall' })
sh = shell(c); bk = bb(part(c, 'Hậu')); xt = bb(part(c, 'Xà treo')); top = bb(part(c, 'Nóc'))
pv = V::Tools::PanelTool.new({}); reselect(c); pv.activate; pv.settings['panel_axis'] = 'vertical'; pv.onUserText('/2', v); pv.commit(v)
wall = parts_named(c, 'Vách').first
check 'tủ treo: vách đi tới mặt hậu (không cắt cả chiều cao)', near(bb(wall)[4], bk[1]), [bb(wall), bk].inspect
prof = V::Rebuild.vertical_profile(sh, V::Interior.inner(sh), 0.0).map { |y, z| [y.to_mm.round(2), z.to_mm.round(2)] }
xa = [xt[1], xt[2]]; xb = [xt[1], xt[5]]
check 'khấu: góc trong dưới xà', prof.any? { |y, z| near(y, xa[0]) && near(z, xa[1]) }, prof.inspect
check 'khấu: góc trong trên xà (sát nóc)', prof.any? { |y, z| near(y, xb[0]) && near(z, xb[1]) }, prof.inspect
check 'khấu: dưới xà vách sâu tới mặt hậu', prof.any? { |y, z| near(y, bk[1]) && z < xt[2] - 1 }, prof.inspect
check 'khấu: phía trên xà vẫn không vượt mặt hậu', prof.all? { |y, _z| y <= bk[1] + 0.01 }, prof.inspect
c = kcab(800, 560, 800, { 'cabinet_type' => 'base' })
sh = shell(c); bk = bb(part(c, 'Hậu')); gs = bb(part(c, 'Giằng sau'))
prof = V::Rebuild.vertical_profile(sh, V::Interior.inner(sh), 0.0).map { |y, z| [y.to_mm.round(2), z.to_mm.round(2)] }
check 'tủ dưới: khấu theo giằng sau', prof.any? { |y, z| near(y, gs[1]) && near(z, gs[2]) } && prof.any? { |y, z| near(y, bk[1]) && z < gs[2] - 1 }, [gs, prof].inspect

err = (begin; kcab(800, 700, 1950, fopts); nil; rescue ArgumentError => e; e.message; end)
check 'thùng thấp không đủ hộc trên: báo lỗi', err.to_s.include?('hộc trên'), err

puts '== 18. Vách khấu sát mép trên/dưới: biên dạng không đi chồng lên chính nó =='
# Hai đoạn thẳng cùng nằm trên một đường và chồng lên nhau (ví dụ mép trên đi qua hai lần) làm khối không kín.
def overlap_1d?(a, b, c, d)
  lo = [[a, b].min, [c, d].min].max
  hi = [[a, b].max, [c, d].max].min
  hi - lo > 0.01
end

def collinear_overlap?(a1, a2, b1, b2)
  if (a1[1] - a2[1]).abs < 0.01 && (b1[1] - b2[1]).abs < 0.01 && (a1[1] - b1[1]).abs < 0.01
    overlap_1d?(a1[0], a2[0], b1[0], b2[0])
  elsif (a1[0] - a2[0]).abs < 0.01 && (b1[0] - b2[0]).abs < 0.01 && (a1[0] - b1[0]).abs < 0.01
    overlap_1d?(a1[1], a2[1], b1[1], b2[1])
  else
    false
  end
end

def overlapping_edges?(pts)
  edges = pts.each_index.map { |i| [pts[i], pts[(i + 1) % pts.length]] }
  edges.each_index.any? do |i|
    edges.each_index.any? do |j|
      # Cạnh liền kề chỉ chung một đỉnh; nếu chồng nhau thì là cạnh gấp ngược (lỗi), nên vẫn kiểm.
      next false if i == j
      collinear_overlap?(*edges[i], *edges[j])
    end
  end
end

c = cab('top_mode' => 'rails')
sh = shell(c)
prof = V::Rebuild.vertical_profile(sh, V::Interior.inner(sh), 0.0).map { |y, z| [y.to_mm.round(2), z.to_mm.round(2)] }
check 'xà trên sát nóc: biên dạng không có cạnh chồng lên cạnh khác', !overlapping_edges?(prof), prof.inspect
check 'xà trên sát nóc: vẫn có khấu góc sau-trên', prof.any? { |y, z| z > 1900 && y < bb(sh)[4] - 1 }, prof.inspect

puts '== 19. Biên tấm sau khi trừ xà chắn; xem trước = tấm tạo ra =='
def boxes_overlap?(a, b)
  (0..2).all? { |i| [a[i + 3], b[i + 3]].min - [a[i], b[i]].max > 0.01 }
end

def panel_op(sh, c, axis, offset_mm, setback_mm)
  inner = V::Interior.inner(sh)
  op = { 'type' => 'panel', 'axis' => axis, 'kind' => 'thong_thuy', 'thickness_mm' => 17.5, 'limit' => false,
         'anchor' => V::Rebuild.anchor_of(sh, (inner.x0 + inner.x1) / 2, (inner.z0 + inner.z1) / 2),
         'setback_mm' => setback_mm, 'door_fit' => 'phu', 'mode' => 'free', 'offsets' => [offset_mm] }
  op['op'] = V::Rebuild.record(c, op)
  V::Rebuild.place_panels(c, sh, op)
end

# Hình chữ nhật [0,0]-[100,50] có xà chắn góc dưới-trái [0,0]-[30,20]: biên phải khấu góc, không còn góc (0,0).
notched = V::Rebuild.board_outline([0.0, 0.0, 100.0, 50.0], [[0.0, 0.0, 30.0, 20.0]])
check 'khấu góc: biên có điểm khấu (30,0), (30,20), (0,20)', notched && [[30.0, 0.0], [30.0, 20.0], [0.0, 20.0]].all? { |p| notched.any? { |q| near(q[0], p[0]) && near(q[1], p[1]) } } && notched.none? { |q| near(q[0], 0.0) && near(q[1], 0.0) }, notched.inspect
check 'khấu góc: 6 đỉnh, không chồng cạnh', notched && notched.length == 6 && !overlapping_edges?(notched.map { |a, b| [a, b] }), notched.inspect
hole = V::Rebuild.board_outline([0.0, 0.0, 100.0, 50.0], [[40.0, 20.0, 60.0, 30.0]])
check 'xà chắn giữa tấm (tạo lỗ): không dựng được, trả nil', hole.nil?, hole.inspect

c = cab('top_mode' => 'rails', 'rail_front_double' => true)
sh = shell(c)
inner = V::Interior.inner(sh)
pt = V::Tools::PanelTool.new('shelf_front_setback' => 0.0, 'panel_door_fit' => 'phu', 'panel_span' => 'cell',
                             'board_thickness' => 17.5)
pt.instance_variable_set(:@root, c)
pt.instance_variable_set(:@shell, sh)
[['đợt', 'horizontal', 1900.0, 'Đợt'], ['vách', 'vertical', 300.0, 'Vách']].each do |label, axis, pos_mm, prefix|
  pos = pos_mm.mm
  ref = { axis: axis, cell: inner, role: 'top', plane: pos, dir: 1 }
  preview = pt.send(:board_faces_for, pos, ref).flatten(1)
  offset = axis == 'horizontal' ? pos_mm - inner.z0.to_mm : pos_mm - inner.x0.to_mm
  panel_op(sh, c, axis, offset, 0.0)
  made = parts_named(c, prefix).last
  axes = [0, 1, 2].map { |i| preview.map { |p| p[i].to_mm } }
  prev_box = axes.map(&:min) + axes.map(&:max)
  check "#{label}: xem trước khớp tấm tạo ra", made && (0..5).all? { |i| (prev_box[i] - bb(made)[i]).abs < 0.05 }, [prev_box.map { |v| v.round(2) }, made && bb(made)].inspect
end

puts '== 20. Tủ không có nóc: vách cao tới mép xà, xà trước khấu vách =='
c = cab('top_mode' => 'rails')
sh = shell(c)
prof = V::Rebuild.vertical_profile(sh, V::Interior.inner(sh), 0.0, [300.mm, 317.5.mm]).map { |y, z| [y.to_mm.round(2), z.to_mm.round(2)] }
check 'xà trên phẳng: vách cao tới mép trên xà (1980)', prof.map { |_y, z| z }.max && near(prof.map { |_y, z| z }.max, 1980.0), prof.inspect
check 'xà trên phẳng: góc xà trước (100, 1962.5) có trong biên', prof.any? { |y, z| near(y, 100.0) && near(z, 1962.5) }, prof.inspect
check 'xà trên phẳng: vách không chồng cạnh', !overlapping_edges?(prof), prof.inspect

c = cab('top_mode' => 'rails', 'rail_front_orient' => 'upright')
sh = shell(c)
prof = V::Rebuild.vertical_profile(sh, V::Interior.inner(sh), 0.0, [300.mm, 317.5.mm]).map { |y, z| [y.to_mm.round(2), z.to_mm.round(2)] }
check 'xà đứng: vách cao tới 1980, khấu góc (17.5, 1880)', near(prof.map { |_y, z| z }.max, 1980.0) && prof.any? { |y, z| near(y, 17.5) && near(z, 1880.0) }, prof.inspect
check 'xà đứng: vách không chồng cạnh', !overlapping_edges?(prof), prof.inspect

c = cab({})
sh = shell(c)
prof = V::Rebuild.vertical_profile(sh, V::Interior.inner(sh), 0.0, [300.mm, 317.5.mm]).map { |y, z| [y.to_mm.round(2), z.to_mm.round(2)] }
check 'tủ có nóc: vách không vượt nóc (1962.5)', near(prof.map { |_y, z| z }.max, 1962.5), prof.inspect

c = cab('top_mode' => 'rails')
sh = shell(c)
pt = V::Tools::PanelTool.new({})
pt.instance_variable_set(:@shell, sh)
hl = pt.send(:reference_face, { axis: 'vertical', cell: V::Interior.inner(sh), plane: 300.mm, dir: 1 })
check 'khung tô sáng vách lên tới mép xà (1980)', near(hl.map { |p| p[2].to_mm }.max, 1980.0), hl.map { |p| p[2].to_mm.round(1) }.inspect
check 'khung tô sáng vách có khấu xà trước (góc (100, 1962.5))', hl.any? { |p| near(p[1].to_mm, 100.0) && near(p[2].to_mm, 1962.5) }, hl.map { |p| [p[1].to_mm.round(1), p[2].to_mm.round(1)] }.inspect

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.length}"
exit($fail.empty? ? 0 : 1)
