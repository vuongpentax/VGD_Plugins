# Test cánh lọt / phủ mới (beta.23): thùng tủ lùi theo dày cánh, phủ bì giữ nguyên, Tab/Ctrl, giao tia, khung kích thước.
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
def shell(c); V::Geometry.shell_for(c); end
def part(c, name); groups(shell(c).definition.entities).find { |p| p.name == name }; end
def trim_part(c, name)
  t = groups(c.definition.entities).find { |e| e.name == 'Chân & phào' }
  t && groups(t.definition.entities).find { |p| p.name == name }
end
V::Keys.platform = :windows
v = Sketchup.active_model.active_view
T = 17.5

def door_tool(c, settings = {})
  Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(c)
  dt = V::Tools::DoorTool.new(settings); dt.activate; dt
end

puts '== 1. Cánh PHỦ (cả hai hông): thùng tủ lùi, phủ bì giữ nguyên =='
c = cab
dt = door_tool(c, 'door_fit' => 'phu')
dt.layout.split(dt.layout.regions.first['id'], 'vertical', 0.5)
dt.commit(v)
check 'nóc lùi 17.5', near(bb(part(c, 'Nóc'))[1], T), bb(part(c, 'Nóc')).inspect
check 'đáy lùi 17.5', near(bb(part(c, 'Đáy'))[1], T)
check 'hông trái lùi 17.5 (được phủ)', near(bb(part(c, 'Hông Trái'))[1], T)
check 'hông phải lùi 17.5 (được phủ)', near(bb(part(c, 'Hông Phải'))[1], T)
check 'ván chân lùi thêm bằng hông khi phủ (50 + 17.5)', near(bb(trim_part(c, 'Ván chân'))[1], 50.0 + T), bb(trim_part(c, 'Ván chân')).inspect
doors = V::Operations.doors_of(c)
check 'có 2 cánh', doors.length == 2
db = V::Operations.door_bounds(doors.first)
check 'cánh phủ: mặt ngoài đúng mặt trước box (y=0), dày 17.5', near(db[1].to_mm, 0.0) && near(db[4].to_mm, T), db.map(&:to_mm).inspect
check 'cánh phủ trùm tới mép hông trái và cao nóc đáy', near(db[0].to_mm, 0.0) && near(db[2].to_mm, 40.0) && near(db[5].to_mm, 1980.0), db.map { |x| x.to_mm.round(2) }.inspect
all = [bb(shell(c)), db.map { |x| x.to_mm.round(3) }]
check 'phủ bì (thùng + cánh) vẫn sâu đúng 560: mép trước 0', near([bb(part(c, 'Hậu'))[1], db[1].to_mm].min, 0.0)
check 'hông vẫn tới mép sau box (560): thùng tủ chỉ lùi phía trước', near(bb(part(c, 'Hông Trái'))[4], 560.0), bb(part(c, 'Hông Trái')).inspect
check 'lưu độ lùi vào dữ liệu tủ', V::Rebuild.settings_of(c)['door_recess'].is_a?(Hash) && V::Rebuild.settings_of(c)['door_recess']['top'] == T

puts '== 2. Đổi sang cánh LỌT trên cùng tủ: thùng tủ dựng lại =='
dt = door_tool(c)
dt.settings['door_fit'] = 'lot'; dt.hud_after_set('door_fit')
dt.commit(v)
check 'lọt: hông trái về mép trước box (0)', near(bb(part(c, 'Hông Trái'))[1], 0.0), bb(part(c, 'Hông Trái')).inspect
check 'lọt: hông phải về mép trước box (0)', near(bb(part(c, 'Hông Phải'))[1], 0.0)
check 'lọt: nóc lùi 17.5', near(bb(part(c, 'Nóc'))[1], T)
check 'lọt: đáy lùi 17.5', near(bb(part(c, 'Đáy'))[1], T)
check 'lọt: ván chân lùi thêm 17.5 (50 + 17.5)', near(bb(trim_part(c, 'Ván chân'))[1], 50.0 + T), bb(trim_part(c, 'Ván chân')).inspect
check 'lọt: phào trần lùi 17.5', near(bb(trim_part(c, 'Phào trần'))[1], T), (trim_part(c, 'Phào trần') ? bb(trim_part(c, 'Phào trần')).inspect : 'không có phào')
doors = V::Operations.doors_of(c)
db = V::Operations.door_bounds(doors.first).map { |x| x.to_mm.round(3) }
dlast = V::Operations.door_bounds(doors.max_by { |d| V::Operations.door_bounds(d)[0] }).map { |x| x.to_mm.round(3) }
check 'lọt: cánh giữa hai hông (+ khe 2), cao phủ nóc đáy', near(db[0], 19.5) && near(dlast[3], 780.5) && near(db[2], 40.0) && near(db[5], 1980.0), [db, dlast].inspect
check 'lọt: mặt ngoài cánh bằng mặt trước hông (y=0)', near(db[1], 0.0) && near(db[4], T)
check 'cánh còn lại 1 vùng sau khi đổi (bố cục giữ 2 cánh)', doors.length >= 1

puts '== 3. Phủ chỉ hông trái =='
c = cab
dt = door_tool(c, 'door_fit' => 'phu', 'door_cover_right' => false)
dt.commit(v)
check 'hông trái lùi (được phủ)', near(bb(part(c, 'Hông Trái'))[1], T)
check 'hông phải KHÔNG lùi (không phủ)', near(bb(part(c, 'Hông Phải'))[1], 0.0), bb(part(c, 'Hông Phải')).inspect
db = V::Operations.door_bounds(V::Operations.doors_of(c).first).map { |x| x.to_mm.round(3) }
check 'cánh từ mép hông trái tới mặt trong hông phải (+ khe 2)', near(db[0], 0.0) && near(db[3], 780.5), db.inspect

puts '== 4. Tab đổi lọt/phủ; Ctrl đổi dọc/ngang =='
c = cab
dt = door_tool(c)
check 'mặc định phủ', dt.fit == 'phu'
dt.onKeyDown(9, 1, 0, v)
check 'Tab → lọt', dt.fit == 'lot' && dt.settings['door_fit'] == 'lot'
dt.onKeyDown(9, 1, 0, v)
check 'Tab lần nữa → phủ', dt.fit == 'phu'
check 'Tab không đổi hướng chia', dt.split_axis == 'vertical'
dt.onKeyDown(17, 1, 0, v)
check 'Ctrl → ngang', dt.split_axis == 'horizontal'
dt.onKeyDown(17, 2, 0, v)
check 'giữ Ctrl không đổi liên tục', dt.split_axis == 'horizontal'
dt.onKeyUp(17, 1, 0, v)
dt.onKeyDown(17, 1, 0, v)
check 'nhả rồi nhấn Ctrl lại → dọc', dt.split_axis == 'vertical'
dt.onKeyUp(17, 1, 0, v)
check 'Tab không còn đổi dọc/ngang', (dt.onKeyDown(9, 1, 0, v); dt.split_axis == 'vertical')

puts '== 5. Khe chia theo con trỏ khi xoay view (giao tia với mặt trước) =='
c = cab
dt = door_tool(c, 'door_fit' => 'phu')
# Điểm suy luận giả nằm SAU mặt trước (hông/hậu) rất xa; tia nhìn xiên chạm mặt cánh đúng tại x=400, z=1000.
target = Geom::Point3d.new(400.mm, 0.mm, 1000.mm)
dir = Geom::Vector3d.new(0.5, 1, 0.2).normalize
origin = Geom::Point3d.new(target.x - dir.x * 5000.mm, target.y - dir.y * 5000.mm, target.z - dir.z * 5000.mm)
v.fake_ray = [origin, dir]
v.fake_path = [c]; v.fake_point = Geom::Point3d.new(700.mm, 500.mm, 300.mm)
dt.onMouseMove(0, 5, 5, v)
split = dt.instance_variable_get(:@hover_split)
check 'đường chia đúng 400/800 dù điểm suy luận ở xa', split && near(split * 800.0, 400.0, 0.5), split.inspect
v.fake_ray = nil

puts '== 6. Đợt sau cánh phủ / lọt không chạm cánh =='
c = cab
dt = door_tool(c, 'door_fit' => 'phu'); dt.commit(v)
pl = V::Tools::PanelTool.new({}); Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(c); pl.activate; pl.onUserText('/2', v); pl.commit(v)
shelf = groups(shell(c).definition.entities).find { |g| g.name.start_with?('Đợt') }
check 'đợt sau cánh phủ: lùi 20 sau mặt trước thùng (17.5 + 20)', shelf && near(bb(shelf)[1], T + 20.0), shelf && bb(shelf).inspect
c = cab
dt = door_tool(c, 'door_fit' => 'lot'); dt.commit(v)
pl = V::Tools::PanelTool.new({}); Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(c); pl.activate; pl.onUserText('/2', v); pl.commit(v)
shelf = groups(shell(c).definition.entities).find { |g| g.name.start_with?('Đợt') }
check 'đợt sau cánh lọt: lùi 20 + dày cánh (37.5)', shelf && near(bb(shelf)[1], 37.5), shelf && bb(shelf).inspect

puts '== 7. Sửa tủ giữ độ lùi theo cánh =='
c = cab
dt = door_tool(c, 'door_fit' => 'lot'); dt.commit(v)
settings = V::Rebuild.settings_of(c)
V::Rebuild.run(c, settings.merge('board_thickness' => 18.0), V::Rebuild.dimensions_of(c), [])
check 'sau Sửa tủ: nóc vẫn lùi theo cánh', near(bb(part(c, 'Nóc'))[1], T), bb(part(c, 'Nóc')).inspect
check 'sau Sửa tủ: vẫn còn cánh', V::Operations.doors_of(c).length >= 1

puts '== 8. PanelModel nhận door_recess =='
r = V::PanelModel.compute(800, 560, 2000, 'leg_height' => 40.0, 'toe_kick_setback' => 50.0, 'door_recess' => { 'top' => 17.5, 'bottom' => 17.5, 'toe' => 10.0 })
top = r.parts.find { |p| p.role == 'top' }
check 'nóc bắt đầu ở y = 17.5', near(top.bounds[1], 17.5), top.bounds.inspect
side = r.parts.find { |p| p.role == 'side_left' }
check 'hông không đổi', near(side.bounds[1], 0.0)
toe = r.trim.find { |p| p.role == 'toe_kick' }
check 'ván chân lùi thêm 10', near(toe.bounds[1], 50.0 + 10.0), toe.bounds.inspect
check 'không có door_recess thì như cũ', V::PanelModel.compute(800, 560, 2000, 'leg_height' => 40.0).parts.find { |p| p.role == 'top' }.bounds[1] == 0.0
check 'DoorFit phủ trái', V::DoorFit.recess_for('phu', true, false, 17.5).values_at('side_left', 'side_right') == [17.5, 0.0]
check 'DoorFit lọt', V::DoorFit.recess_for('lot', true, true, 17.5).values_at('side_left', 'toe', 'cornice') == [0.0, 17.5, 17.5]
check 'DoorFit phủ cả hai hông: ván chân lùi bằng hông', V::DoorFit.recess_for('phu', true, true, 17.5)['toe'] == 17.5
check 'DoorFit phủ không phủ hông nào: ván chân không lùi', V::DoorFit.recess_for('phu', false, false, 17.5)['toe'] == 0.0
rr = V::DoorFit.recess_for('phu', true, true, 17.5)
r_phu = V::PanelModel.compute(800, 560, 2000, 'leg_height' => 40.0, 'door_recess' => rr)
side_phu = r_phu.parts.find { |p| p.role == 'side_left' }
toe_phu = r_phu.trim.find { |p| p.role == 'toe_kick' }
check 'cánh phủ: mặt trước ván chân thẳng mặt trước hông', near(toe_phu.bounds[1], side_phu.bounds[1]), [toe_phu.bounds[1], side_phu.bounds[1]].inspect

puts '== 9. Tủ cũ (chưa có door_recess): dựng lại cánh vẫn như cũ =='
c = cab
legacy = V::Tools::DoorTool.new({}); legacy.load_cabinet(c)
a = legacy.area(V::Geometry.body_bounds(shell(c)))
check 'tủ cũ: cánh phủ vẫn nằm ngoài thân (y = mặt trước thân)', near(a[:y].to_mm, 0.0), a[:y].to_mm

puts '== 10. Khung kích thước khoang (đợt/vách): chữ song song mặt tủ =='
c = cab
pt = V::Tools::PanelTool.new({}); Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(c); pt.activate
v.fake_path = [c]; v.fake_point = Geom::Point3d.new(400.mm, -10.mm, 1000.mm)
pt.onMouseMove(0, 5, 5, v)
pt.onUserText('/2', v) # hover chỉ tô sáng; nhãn khoang chỉ hiện khi đã chia (/n)
pv = pt.instance_variable_get(:@preview)
check 'đã chia /2: 2 khoang (trên/dưới tấm) → 2 khung', pv.text_count == 2, pv.text_count
box = pv.text_boxes.first
check 'chữ nằm trong mặt phẳng X-Z (song song mặt tủ)', near(box[:x].x, 1.0, 1e-6) && near(box[:z].z, 1.0, 1e-6) && near(box[:x].y, 0.0, 1e-6)
check 'không còn nhãn kích thước kiểu cũ', pv.instance_variable_get(:@labels).empty?
check 'nội dung là rộng x cao khoang', box[:text] =~ /\A\d+(\.\d)? x \d+(\.\d)?\z/, box[:text]
strokes, width = V::Preview.layout_text('123.5 x 45')
check 'font nét có đường nét và độ rộng', !strokes.empty? && width > 10, width
v.drawn = []
pt.draw(v)
check 'vẽ khung kích thước không lỗi', v.drawn.any? { |d| d[0] == :draw2d && d[1][0] == GL_LINE_STRIP }, v.drawn.map { |d| d[1][0] }.uniq.inspect
pt.onUserText('/3', v)
check 'chia 3 → 3 khung', pt.instance_variable_get(:@preview).text_count == 3

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.length}"
exit($fail.empty? ? 0 : 1)
