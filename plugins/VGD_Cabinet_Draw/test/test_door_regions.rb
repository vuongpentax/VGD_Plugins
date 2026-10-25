# Test công cụ Cánh theo VÙNG + hướng mở (giả lập SketchUp). Chạy: ruby test_door_regions.rb [thư mục runtime]
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
def mk_box(w, d, h, at = [0, 0, 0])
  g = Sketchup.active_model.entities.add_group; g.name = 'Box'
  x, y, z = at.map(&:mm)
  f = g.entities.add_face([[x, y, z], [x + w.mm, y, z], [x + w.mm, y + d.mm, z], [x, y + d.mm, z]])
  f.reverse! if f.normal.z < 0
  f.pushpull(h.mm); g
end
def pt(x, z, y = -10)
  Geom::Point3d.new(x.mm, y.mm, z.mm)
end
SHIFT = CONSTRAIN_MODIFIER_MASK
V::Keys.platform = :windows

# Tủ 1200 x 500 x 2000, chân 0, phào 0 để thân tủ = 0..2000 cho dễ tính.
Sketchup.reset_model!
cab = V::Geometry.cabinet_from_box(mk_box(1200, 500, 2000), { 'front_normal' => [0, -1, 0], 'leg_height' => 0, 'ceiling_strip_height' => 0 })
v = Sketchup.active_model.active_view
sel = Sketchup.active_model.selection
sel.clear; sel.add(cab)
def hover(tool, x, z, flags = 0)
  v = Sketchup.active_model.active_view
  v.fake_path = [tool.instance_variable_get(:@root)]
  v.fake_point = pt(x, z)
  tool.onMouseMove(flags, 5, 5, v)
end
def click(tool, x, z, flags = 0)
  v = Sketchup.active_model.active_view
  v.fake_path = [tool.instance_variable_get(:@root)]
  v.fake_point = pt(x, z)
  tool.onLButtonDown(flags, 5, 5, v)
end
def hud(tool); tool.hud_lines.first; end

puts '== 1. Click chia vùng (dọc) =='
dt = V::Tools::DoorTool.new({}); dt.activate
check 'bắt đầu 1 vùng', dt.layout.regions.length == 1
hover(dt, 400, 1000)
check 'hover gợi ý đường chia 400 mm', ((dt.instance_variable_get(:@hover_split) * 1200).round(6) == 400.0), dt.instance_variable_get(:@hover_split)
check 'hover chưa đổi layout', dt.layout.regions.length == 1 && hud(dt).include?('Cánh: 2')
click(dt, 400, 1000)
check 'click chia thành 2 vùng', dt.layout.regions.length == 2
puts '== 2. Tab giữ đường chia, chia ngang trong vùng phải =='
dt.onKeyDown(17, 1, 0, v); dt.onKeyUp(17, 1, 0, v)
check 'Tab đổi sang ngang', dt.split_axis == 'horizontal'
check 'Tab KHÔNG xóa đường chia', dt.layout.regions.length == 2
click(dt, 800, 700)
check 'chia ngang chỉ ảnh hưởng vùng phải (3 vùng)', dt.layout.regions.length == 3
left = dt.layout.sorted.first
check 'vùng trái giữ nguyên', left['v0'] == 0.0 && left['v1'] == 1.0 && (left['u1'] * 1200).round(6) == 400.0
check 'cánh dọc + ngang cùng lúc, hud 3 cánh', hud(dt).include?('Cánh: 3')
check 'ghi rõ kích thước từng cánh', dt.hud_lines.any? { |l| l =~ /Cánh 1: 400 × 2000 mm/ } && dt.hud_lines.any? { |l| l =~ /Cánh 2: 800 × 700 mm/ } && dt.hud_lines.any? { |l| l =~ /Cánh 3: 800 × 1300 mm/ }, dt.hud_lines.inspect

puts '== 3. Hoàn tác (Backspace) =='
dt.onKeyDown(V::Keys::WINDOWS[:backspace], 0, 0, v)
check 'Backspace hoàn tác 1 bước', dt.layout.regions.length == 2
dt.onKeyDown(V::Keys::WINDOWS[:backspace], 0, 0, v)
check 'Backspace lần 2 về 1 vùng', dt.layout.regions.length == 1

puts '== 4. /n =='
dt.settings['split_axis'] = 'vertical'
hover(dt, 600, 1000)
dt.onUserText('/3', v)
check '/3 khi chưa chia: 3 vùng', dt.layout.regions.length == 3
hover(dt, 1000, 1000)                       # vùng thứ 3 (800..1200)
dt.onKeyDown(17, 1, 0, v); dt.onKeyUp(17, 1, 0, v); hover(dt, 1000, 1000)
dt.onUserText('/2', v)
check '/2 ngang trong vùng đang trỏ: 4 vùng, 2 vùng bên trái giữ nguyên', dt.layout.regions.length == 4 && dt.layout.sorted.first['v1'] == 1.0
dt.onKeyDown(17, 1, 0, v); dt.onKeyUp(17, 1, 0, v)
dt.layout.reset_even('vertical', 1) rescue nil
check 'reset_even 1 vùng', dt.layout.regions.length == 1
dt.settings['split_axis'] = 'vertical'
hover(dt, 600, 1000)
dt.onUserText('/3', v)
dt.reset_hover; dt.instance_variable_set(:@hover_region, nil)
dt.onUserText('/2', v)
check '/n khi không trỏ vùng nào và đã có nhiều vùng: chia đều lại toàn tủ', dt.layout.regions.length == 2
dt.onUserText('/99', v)
check '/99 bị kẹp tối đa 20', dt.layout.regions.length == 20

puts '== 5. Gõ số mm =='
dt = V::Tools::DoorTool.new({}); dt.activate
hover(dt, 300, 1000)                        # con trỏ ở nửa trái -> đo từ mép trái
dt.onUserText('250', v)
check 'gõ 250 gần mép trái: vùng trái rộng 250', dt.layout.regions.length == 2 && (dt.layout.sorted.first['u1'] * 1200).round(6) == 250.0
dt = V::Tools::DoorTool.new({}); dt.activate
hover(dt, 900, 1000)                        # nửa phải -> đo từ mép phải
dt.onUserText('250 mm', v)
check 'gõ 250 mm gần mép phải: vùng phải rộng 250', ((1 - dt.layout.sorted.last['u0']) * 1200).round(6) == 250.0
dt.onUserText('xyz', v)
check 'gõ bậy không hỏng', dt.layout.regions.length == 2

puts '== 6. Chọn vùng (Shift) và gộp =='
dt = V::Tools::DoorTool.new({}); dt.activate
dt.onUserText('/4', v)
hover(dt, 150, 1000)
click(dt, 150, 1000, SHIFT)
click(dt, 450, 1000, SHIFT)
check 'Shift-click chọn 2 vùng', dt.selected.length == 2 && hud(dt).include?('Đã chọn: 2')
check 'vùng chọn được tô (có lăng trụ nổi bật)', dt.instance_variable_get(:@preview).polygon_count == 4 * 6 + 2 * 6
click(dt, 450, 1000, SHIFT)
check 'Shift-click lại bỏ chọn', dt.selected.length == 1
click(dt, 450, 1000, SHIFT)
dt.onKeyDown(71, 0, 0, v)                   # phím G
check 'phím G gộp 2 vùng kề nhau', dt.layout.regions.length == 3 && dt.selected.length == 1
dt.onKeyDown(V::Keys::WINDOWS[:backspace], 0, 0, v)
check 'Backspace hoàn tác phép gộp', dt.layout.regions.length == 4
click(dt, 150, 1000, SHIFT); click(dt, 950, 1000, SHIFT)
dt.onUserText('g', v)
check 'gõ g vào VCB gộp vùng không kề nhau thì bị từ chối', dt.layout.regions.length == 4
dt.selected.clear
dt.onUserText('g', v)
check 'gõ g khi chưa chọn gì: không lỗi', dt.layout.regions.length == 4
puts '== 7. Chia lại sau khi gộp =='
dt = V::Tools::DoorTool.new({}); dt.activate
dt.onUserText('/4', v)
click(dt, 450, 1000, SHIFT); click(dt, 750, 1000, SHIFT)
dt.onKeyDown(71, 0, 0, v)
merged = dt.layout.regions.find { |r| ((r['u1'] - r['u0']) * 1200).round(3) == 600.0 }
check 'gộp 2 ô giữa thành 600 mm', merged && dt.layout.regions.length == 3
hover(dt, 600, 1000)
dt.settings['split_axis'] = 'horizontal'; hover(dt, 600, 1000)
dt.onUserText('/2', v)
check 'chia ngang ô vừa gộp', dt.layout.regions.length == 4

puts '== 8. Dựng cánh, lưu schema 2 =='
dt = V::Tools::DoorTool.new({}); dt.activate
hover(dt, 600, 1000); click(dt, 600, 1000)
dt.onKeyDown(17, 1, 0, v); dt.onKeyUp(17, 1, 0, v); hover(dt, 900, 700); click(dt, 900, 700)
dt.commit(v)
doors = V::Operations.doors_of(cab)
check 'dựng 3 cánh', doors.length == 3, doors.length
json = JSON.parse(cab.get_attribute(DICT, 'door_layout_json'))
check 'layout lưu schema 2 có 3 vùng và id', json['schema'] == 2 && json['regions'].length == 3 && json['regions'].all? { |r| r['id'].to_i > 0 }
check 'cánh có region_id và part_index', doors.all? { |d| d.get_attribute(DICT, 'region_id').to_i > 0 && d.get_attribute(DICT, 'part_index').to_i > 0 }
check 'cánh đúng kích thước theo vùng', doors.map { |d| b = V::Operations.door_bounds(d); [((b[3] - b[0]).to_mm).round(3), ((b[5] - b[2]).to_mm).round(3)] }.sort == [[600.0, 2000.0], [600.0, 700.0], [600.0, 1300.0]].sort, doors.map { |d| b = V::Operations.door_bounds(d); [((b[3] - b[0]).to_mm).round(3), ((b[5] - b[2]).to_mm).round(3)] }.inspect
check 'thoát công cụ sau khi dựng', Sketchup.active_model.tool.nil?

puts '== 9. Mở lại tủ: tải đúng bố cục, chia lại giữ các cánh khác =='
sel.clear; sel.add(cab)
dt2 = V::Tools::DoorTool.new({}); dt2.activate
check 'tải lại đúng 3 vùng', dt2.layout.regions.length == 3
ids_before = dt2.layout.ids.sort
dt2.commit(v)
check 'dựng lại không nhân đôi cánh', V::Operations.doors_of(cab).length == 3
check 'id vùng được giữ khi dựng lại', JSON.parse(cab.get_attribute(DICT, 'door_layout_json'))['regions'].map { |r| r['id'] }.sort == ids_before

puts '== 10. Tương thích bố cục bản cũ (schema 1) =='
old = V::Geometry.cabinet_from_box(mk_box(900, 500, 2000, [5000, 0, 0]), { 'front_normal' => [0, -1, 0], 'leg_height' => 0, 'ceiling_strip_height' => 0 })
old.set_attribute(DICT, 'door_layout_json', JSON.generate('schema' => 1, 'splits' => [0.5], 'regions' => [{ 'index' => 0, 'u0' => 0.0, 'u1' => 0.5, 'gap_mm' => 0, 'axis' => 'horizontal' }, { 'index' => 1, 'u0' => 0.5, 'u1' => 1.0, 'gap_mm' => 0, 'axis' => 'horizontal' }]))
sel.clear; sel.add(old)
dt3 = V::Tools::DoorTool.new({}); dt3.activate
check 'schema 1 ngang -> 2 vùng xếp chồng', dt3.layout.regions.length == 2 && dt3.layout.regions.all? { |r| r['u0'] == 0.0 && r['u1'] == 1.0 }
dt3.commit(v)
check 'ghi lại thành schema 2', JSON.parse(old.get_attribute(DICT, 'door_layout_json'))['schema'] == 2
old.set_attribute(DICT, 'door_layout_json', '{hỏng')
sel.clear; sel.add(old)
dt4 = V::Tools::DoorTool.new({}); dt4.activate
check 'json hỏng -> 1 vùng, không lỗi', dt4.layout.regions.length == 1

puts '== 11. Khe cánh trên bố cục vùng =='
sel.clear; sel.add(cab)
gt = V::Tools::DoorTool.new({}); gt.activate; gt.settings['door_gap'] = 4
cs = gt.cells(V::Geometry.body_bounds(V::Geometry.shell_for(cab)))
check 'khe 4 mm: mép ngoài sát tủ', cs.map { |c| c[:x0] }.min == 0.0 && (cs.map { |c| c[:x1] }.max - 1200.mm).abs < 1e-9
right = cs.select { |c| c[:x0] > 1.mm }.sort_by { |c| c[:z0] }
check 'khe 4 mm giữa 2 cánh chồng nhau bên phải', right.length == 2 && ((right[1][:z0] - right[0][:z1]).to_mm - 4).abs < 1e-6, right.map { |c| [c[:z0].to_mm, c[:z1].to_mm] }.inspect

puts '== 12. Hướng mở: trái/phải/trên/dưới/ngăn kéo =='
sel.clear; sel.add(cab)
cont = cab.definition.entities.to_a.find { |e| e.name == 'Cánh' }
d_full = V::Operations.doors_of(cab).find { |d| b = V::Operations.door_bounds(d); ((b[5] - b[2]).to_mm - 2000).abs < 1e-6 }
d_top = V::Operations.doors_of(cab).find { |d| b = V::Operations.door_bounds(d); ((b[5] - b[2]).to_mm - 700).abs < 1e-6 }
d_bot = V::Operations.doors_of(cab).find { |d| b = V::Operations.door_bounds(d); ((b[5] - b[2]).to_mm - 1300).abs < 1e-6 }
check 'cánh mới: chưa có loại mở', V::Operations.opening_type_of(d_full) == 'none'
def front_y(door)
  b = V::Operations.door_bounds(door)
  [b[1], door.transformation]
end
# Mở cánh trên ra 90° với bản lề phía trên: mép dưới phải bay ra phía trước (-Y)
def world_pt(door, local)
  Geom::Point3d.new(*local).transform(door.transformation)
end
bt = V::Operations.door_bounds(d_top)
free_before = world_pt(d_top, [(bt[0] + bt[3]) / 2, bt[1], bt[2]])
piv_before = V::Operations.hinge_pivot(d_top, 'top')
V::Operations.set_door_angle(d_top, 'top', 90)
free_after = world_pt(d_top, [(bt[0] + bt[3]) / 2, bt[1], bt[2]])
piv_after = V::Operations.hinge_pivot(d_top, 'top')
check 'bản lề trên: mép dưới bay ra phía trước (-Y)', free_after.y < free_before.y - 600.mm, [free_before.y.to_mm, free_after.y.to_mm].inspect
check 'bản lề trên: mép dưới bay lên đến ngang bản lề (90°)', (free_after.z - piv_after.z).abs < 1.mm, [free_after.z.to_mm, piv_after.z.to_mm].inspect
check 'bản lề trên: điểm bản lề không dịch chuyển', (piv_after - piv_before).length < 1e-6
V::Operations.set_door_angle(d_top, 'top', 0)
check 'bản lề trên: đóng lại về đúng chỗ cũ', (world_pt(d_top, [(bt[0] + bt[3]) / 2, bt[1], bt[2]]) - free_before).length < 1e-6
bb = V::Operations.door_bounds(d_bot)
top_before = world_pt(d_bot, [(bb[0] + bb[3]) / 2, bb[1], bb[5]])
V::Operations.set_door_angle(d_bot, 'bottom', 90)
top_after = world_pt(d_bot, [(bb[0] + bb[3]) / 2, bb[1], bb[5]])
piv = V::Operations.hinge_pivot(d_bot, 'bottom')
check 'bản lề dưới: mép trên bay ra phía trước (-Y)', top_after.y < top_before.y - 600.mm, [top_before.y.to_mm, top_after.y.to_mm].inspect
check 'bản lề dưới: mép trên hạ xuống ngang bản lề (90°)', (top_after.z - piv.z).abs < 1.mm
V::Operations.set_door_angle(d_bot, 'bottom', 0)
bf = V::Operations.door_bounds(d_full)
free = world_pt(d_full, [bf[3], bf[1], (bf[2] + bf[5]) / 2])
V::Operations.set_door_angle(d_full, 'left', 90)
check 'bản lề trái vẫn mở ra phía trước (hành vi cũ)', world_pt(d_full, [bf[3], bf[1], (bf[2] + bf[5]) / 2]).y < free.y - 500.mm
V::Operations.set_door_angle(d_full, 'left', 0)

puts '== 13. Công cụ Mở cánh: Tab đổi bản lề, lưu vào bố cục =='
[d_top, d_bot].each { |d| %w[opening_type opening_side].each { |k| d.set_attribute(DICT, k, nil) } }
sel.clear; sel.add(d_top)
ot = V::Tools::OpeningTool.new({}); ot.activate
check 'cánh mới bắt đầu bản lề trái', ot.hinge_side == 'left'
ot.onKeyDown(V::Keys::WINDOWS[:tab], 0, 0, v); ot.onKeyDown(V::Keys::WINDOWS[:tab], 0, 0, v)
check 'Tab 2 lần: bản lề trên', ot.hinge_side == 'top', ot.hinge_side
check 'HUD hiện tên bản lề', ot.hud_lines.first.include?('trên')
v.fake_path = [cab, cont, d_top]
ot.onMouseMove(0, 100, 5, v); ot.onMouseMove(0, 100 + 60 * 3, 5, v)
pv = ot.instance_variable_get(:@preview)
check 'preview có cung quét + nhãn góc cho bản lề trên', pv.instance_variable_get(:@lines).length >= 20 && pv.instance_variable_get(:@labels).length == 1
ot.onLButtonDown(0, 5, 5, v)
check 'chốt 60° bản lề trên', V::Operations.door_angle(d_top) == 60.0 && d_top.get_attribute(DICT, 'opening_type') == 'top' && d_top.get_attribute(DICT, 'opening_side') == 'top'
mk = d_top.definition.entities.to_a.find { |e| e.name == 'Ký Hiệu Hướng Mở' }
mb = V::Operations.door_bounds(d_top)
mpts = mk.entities.to_a.flat_map { |e| [e.a, e.b] }
check 'ký hiệu bản lề trên: đỉnh ở cạnh trên giữa bề rộng', mpts.any? { |p| (p.x - (mb[0] + mb[3]) / 2).abs < 1.mm && (p.z - mb[5]).abs < 1.mm }
check 'ký hiệu bản lề trên: hai góc về cạnh dưới', mpts.any? { |p| (p.x - mb[0]).abs < 29.mm && (p.z - mb[2]).abs < 29.mm } && mpts.any? { |p| (p.x - mb[3]).abs < 29.mm && (p.z - mb[2]).abs < 29.mm }
layout_json = JSON.parse(cab.get_attribute(DICT, 'door_layout_json'))
rid = d_top.get_attribute(DICT, 'region_id')
check 'loại mở được ghi vào bố cục của tủ', layout_json['regions'].find { |r| r['id'] == rid }['opening_type'] == 'top', layout_json['regions'].inspect
check 'bố cục vẫn giữ settings/khe', layout_json['settings'].is_a?(Hash)

puts '== 14. Góc 0 = chỉ đánh dấu, cánh đóng =='
sel.clear; sel.add(d_full)
og = V::Tools::OpeningTool.new({}); og.activate
og.onKeyDown(V::Keys::WINDOWS[:tab], 0, 0, v)
check 'đổi sang bản lề phải', og.hinge_side == 'right'
v.fake_path = [cab, cont, d_full]
og.onUserText('0', v)
check 'góc 0: cánh vẫn đóng nhưng có loại mở và ký hiệu', V::Operations.door_angle(d_full) == 0.0 && V::Operations.opening_type_of(d_full) == 'right' && d_full.definition.entities.to_a.any? { |e| e.name == 'Ký Hiệu Hướng Mở' }

puts '== 15. Ngăn kéo: chỉ lưu dữ liệu =='
sel.clear; sel.add(d_bot)
od = V::Tools::OpeningTool.new({}); od.activate
4.times { od.onKeyDown(V::Keys::WINDOWS[:tab], 0, 0, v) }
check 'Tab tới ngăn kéo', od.hinge_side == 'drawer', od.hinge_side
before = d_bot.transformation.m.map(&:dup)
od.onUserText('45', v)
check 'ngăn kéo: lưu loại mở, KHÔNG xoay', V::Operations.opening_type_of(d_bot) == 'drawer' && d_bot.transformation.m == before && V::Operations.door_angle(d_bot) == 0.0
layout_json = JSON.parse(cab.get_attribute(DICT, 'door_layout_json'))
check 'loại ngăn kéo vào bố cục', layout_json['regions'].find { |r| r['id'] == d_bot.get_attribute(DICT, 'region_id') }['opening_type'] == 'drawer'
od.draw(v); check 'vẽ công cụ ngăn kéo không lỗi', true
od.onKeyDown(V::Keys::WINDOWS[:tab], 0, 0, v)
check 'Tab vòng lại bản lề trái', od.hinge_side == 'left'

puts '== 16. Chia lại cánh: giữ loại mở của vùng không đổi =='
sel.clear; sel.add(cab)
dt5 = V::Tools::DoorTool.new({}); dt5.activate
types_before = dt5.layout.regions.map { |r| [r['id'], r['opening_type']] }.to_h
check 'bố cục tải lại có loại mở đã lưu', types_before.values.sort == %w[drawer right top], types_before.inspect
angles_before = V::Operations.doors_of(cab).map { |d| [d.get_attribute(DICT, 'region_id'), V::Operations.door_angle(d)] }.to_h
dt5.commit(v)
doors_now = V::Operations.doors_of(cab)
check 'dựng lại: cánh có ký hiệu theo loại đã lưu', doors_now.map { |d| V::Operations.opening_type_of(d) }.sort == %w[drawer right top], doors_now.map { |d| V::Operations.opening_type_of(d) }.inspect
check 'dựng lại: GIỮ góc mở cũ của từng vùng', V::Operations.doors_of(cab).all? { |d| (V::Operations.door_angle(d) - angles_before[d.get_attribute(DICT, 'region_id')].to_f).abs < 1e-6 }, angles_before.inspect
# chia một vùng khác thì vùng khác giữ loại mở
sel.clear; sel.add(cab)
dt6 = V::Tools::DoorTool.new({}); dt6.activate
hover(dt6, 900, 1800); dt6.settings['split_axis'] = 'vertical'; hover(dt6, 900, 1800)
click(dt6, 900, 1800)
rtype = dt6.layout.regions.map { |r| r['opening_type'] }.sort
check 'chia vùng dưới: vùng bị chia về none, vùng khác giữ', dt6.layout.regions.length == 4 && rtype.count('none') == 2 && rtype.include?('right') || rtype.include?('top') || rtype.include?('drawer'), rtype.inspect

puts '== 17. Đóng tất cả cánh (menu) =='
sel.clear; sel.add(cab)
d_full2 = V::Operations.doors_of(cab).first
V::Operations.set_door_angle(d_full2, 'left', 75)
V::Operations.set_door_angle(V::Operations.doors_of(cab).last, 'right', 40)
UI.msgs.clear
n = V.close_selected_doors
check 'đóng tất cả cánh đang mở', n >= 2 && V::Operations.doors_of(cab).all? { |d| V::Operations.door_angle(d) == 0.0 }, n
rot_ok = V::Operations.doors_of(cab).all? { |d| (d.transformation.m[0][0] - 1).abs < 1e-6 && d.transformation.m[0][1].abs < 1e-6 }
check 'cánh trở về đúng vị trí đóng (không lệch)', rot_ok
sel.clear
UI.msgs.clear
check 'không chọn tủ: báo nhẹ nhàng, không lỗi', V.close_selected_doors == 0 && UI.msgs.last.to_s.include?('chọn')

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.length}"
exit($fail.empty? ? 0 : 1)
