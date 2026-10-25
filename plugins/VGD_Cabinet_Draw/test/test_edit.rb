# Test SỬA TỦ ĐÃ TẠO (kiểu thông số DC). Chạy: ruby test_edit.rb [thư mục runtime]
def reselect(e); s = Sketchup.active_model.selection; s.clear; s.add(e); end
$stdout.sync = true
src = File.read(File.join(__dir__, 'test_build.rb'), encoding: 'UTF-8')
# Dùng lại phần khởi tạo + hàm phụ của test_build (cab, bb, clashes, ...).
eval(src.split("puts '== 1.").first, binding, File.join(__dir__, 'test_build.rb'))
v = Sketchup.active_model.active_view

def edit_tool(c, choice = nil)
  sel = Sketchup.active_model.selection; sel.clear; sel.add(c)
  t = V::Tools.build('box', {})
  t.manual_choice = choice if choice && t.respond_to?(:manual_choice=)
  t.activate
  t
end
def dims(c); d = V::ModelData.params(c); [d['width_mm'], d['depth_mm'], d['height_mm']]; end
def door_list(c); V::Operations.doors_of(c).sort_by { |d| V::Operations.door_bounds(d)[0] }; end

puts '== 1. Chọn tủ rồi Box → Board = Sửa tủ =='
c = cab('board_thickness' => 18)
t = edit_tool(c)
check 'chọn tủ -> công cụ Sửa tủ', t.is_a?(V::Tools::EditCabinetTool), t.class
check 'HUD đọc thông số của chính tủ (dày 18)', t.settings['board_thickness'] == 18.0
check 'HUD có Rộng/Sâu/Cao', t.hud_params.first(3).map { |p| p[:key] } == %w[_width _depth _height]
check 'HUD đọc kích thước tủ', t.hud_get('_width') == 800.0 && t.hud_get('_height') == 2000.0
t.draw(v)
check 'HUD sửa tủ dùng kho mẫu Box', t.preset_group == 'box'
sel = Sketchup.active_model.selection; sel.clear; sel.add(c); sel.add(mk_box(300, 300, 300))
check 'chọn tủ + box khác -> vẫn là Box → Board thường', V::Tools.build('box', {}).is_a?(V::Tools::BoxTool)

puts '== 2. Đổi rộng 800 -> 1000 =='
c = cab
t = edit_tool(c)
t.hud_set_value('_width', 1000.0, v)
t.commit(v)
check 'kích thước lưu mới', dims(c) == [1000.0, 560.0, 2000.0], dims(c).inspect
check 'hông phải dời tới 1000', near(bb(part(c, 'Hông Phải'))[3], 1000)
check 'nóc/đáy/hậu theo bề rộng mới', near(bb(part(c, 'Nóc'))[3], 982.5) && near(bb(part(c, 'Hậu'))[3], 1000 - 8.75)
check 'mỗi vai trò chỉ còn 1 tấm', %w[Hông\ Trái Hông\ Phải Nóc Đáy Hậu].all? { |n| groups(shell(c).definition.entities).count { |g| g.name == n } == 1 }
check 'ván chân/phào theo rộng mới', groups(container(c, 'Chân & phào').definition.entities).all? { |g| near(bb(g)[3], 1000) }
check 'một tủ duy nhất (không thêm nhóm thừa)', groups(c.definition.entities).count { |g| g.name == 'Chân & phào' } == 1

puts '== 3. Đổi kích thước: đợt/vách/ngăn kéo/cánh giữ theo cách đã tạo =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
pv = V::Tools::PanelTool.new({}); reselect(c); pv.activate; pv.settings['panel_axis'] = 'vertical'; pv.onUserText('/2', v); pv.commit(v)
pl = V::Tools::PanelTool.new({}); reselect(c); pl.activate; pl.settings['panel_axis'] = 'horizontal'; hover_panel(pl, c, 200, 1000); pl.onUserText('350', v); pl.commit(v)
pr = V::Tools::PanelTool.new({}); reselect(c); pr.activate; pr.settings['panel_axis'] = 'horizontal'; hover_panel(pr, c, 600, 1000); pr.onUserText('/3', v); pr.commit(v)
dk = V::Tools.build('drawer', { 'drawer_count' => 2, 'drawer_mode' => 'box_only' }); dk.activate
vv = Sketchup.active_model.active_view; vv.fake_path = [c]; vv.fake_point = at(200, 150); dk.onMouseMove(0, 5, 5, vv); dk.onLButtonDown(0, 5, 5, vv); dk.commit(vv)
check 'đã ghi 4 bước tạo', V::Rebuild.ops(c).map { |o| o['type'] } == %w[panel panel panel drawer], V::Rebuild.ops(c).map { |o| o['type'] }.inspect
sel = Sketchup.active_model.selection; sel.clear; sel.add(c)
dt = V::Tools::DoorTool.new({}); dt.activate
dt.layout.split(dt.layout.regions.first['id'], 'vertical', 0.5); dt.commit(v)
doors = door_list(c)
V::Operations.apply_opening_metadata(doors[1], 'right')
V::Operations.save_opening_to_layout(doors[1], 'right')
V::Operations.handles([doors[1]], V::Schema.merge_settings({}), [])
V::Operations.set_door_angle(doors[1], 'right', 45)
check 'trước khi sửa: không xuyên nhau', clashes(c).empty?, clashes(c).first(3).inspect
t = edit_tool(c)
t.hud_set_value('_width', 1200.0, v)
t.hud_set_value('_height', 2400.0, v)
t.commit(v)
wall = parts_named(c, 'Vách').first
check 'vách chia đều /2 -> vẫn ở giữa', near((bb(wall)[0] + bb(wall)[3]) / 2, 600), bb(wall).inspect
left_shelf = parts_named(c, 'Đợt').find { |s| bb(s)[3] <= bb(wall)[0] + 0.01 }
check 'đợt đặt 350 mm -> giữ 350 mm từ đáy ô', left_shelf && near(bb(left_shelf)[2], 17.5 + 350), left_shelf && bb(left_shelf).inspect
right = parts_named(c, 'Đợt').select { |s| bb(s)[0] >= bb(wall)[3] - 0.01 }.sort_by { |s| bb(s)[2] }
gaps = ([17.5] + right.flat_map { |s| [bb(s)[2], bb(s)[5]] } + [2400 - 17.5]).each_slice(2).map { |a, b| b - a }
check 'đợt chia đều /3 -> chia lại đều theo chiều cao mới', right.length == 2 && gaps.all? { |g| near(g, gaps.first, 0.05) }, gaps.inspect
check 'đợt ô phải chạy từ vách tới hông phải mới', right.all? { |s| near(bb(s)[0], bb(wall)[3]) && near(bb(s)[3], 1200 - 17.5) }
boxes = groups(container(c, 'Ngăn kéo').definition.entities).select { |g| g.name == 'Thùng Ngăn Kéo' }
check 'ngăn kéo dựng lại đúng 2 thùng trong ô trái dưới', boxes.length == 2 && boxes.all? { |b| bb(b)[3] <= bb(wall)[0] + 0.01 && bb(b)[5] <= bb(left_shelf)[2] + 0.01 }, boxes.map { |b| bb(b) }.inspect
doors = door_list(c)
check 'cánh vẫn 2 cánh chia đôi theo rộng mới', doors.length == 2 && near(V::Operations.door_bounds(doors[0])[3].to_mm, 600), V::Operations.door_bounds(doors[0]).map { |x| x.to_mm.round(1) }.inspect
check 'cánh giữ tay nắm', groups(doors[1].definition.entities).any? { |g| g.name == 'Tay Nắm' }
check 'cánh giữ góc mở 45°', near(V::Operations.door_angle(doors[1]), 45.0)
V::Operations.close_doors(c)
check 'sau khi sửa: không xuyên nhau', clashes(c).empty?, clashes(c).first(5).inspect

puts '== 3b. Mặt hộc + tay nắm theo kích thước mới =='
c = cab
V::Operations.drawers([c], V::Schema.merge_settings({ 'drawer_count' => 3, 'drawer_gap' => 2 }), [])
fr0 = groups(container(c, 'Ngăn kéo').definition.entities).select { |g| g.name == 'Mặt Ngăn Kéo' }
V::Operations.handles(fr0, V::Schema.merge_settings({}), [])
t = edit_tool(c); t.hud_set_value('_width', 1000.0, v); t.hud_set_value('_height', 1800.0, v); t.commit(v)
fr = groups(container(c, 'Ngăn kéo').definition.entities).select { |g| g.name == 'Mặt Ngăn Kéo' }.map { |g| [g, V::Operations.door_bounds(g).map { |x| x.to_mm.round(3) }] }.sort_by { |_, b| b[2] }
check 'vẫn 3 mặt hộc, phủ hết rộng mới 0 → 1000', fr.length == 3 && fr.all? { |_, b| near(b[0], 0) && near(b[3], 1000) }, fr.map(&:last).inspect
check 'mặt hộc chia đều lại theo cao mới (40 → 1780)', near(fr.first[1][2], 40) && near(fr.last[1][5], 1780)
check 'mặt hộc giữ tay nắm', fr.all? { |g, _| groups(g.definition.entities).any? { |h| h.name == 'Tay Nắm' } }
check 'mặt hộc + thùng sau khi sửa: không xuyên nhau', clashes(c).empty?, clashes(c).first(3).inspect

puts '== 4. Đổi thông số: dày ván, loại tủ =='
c = cab
pt = V::Tools::PanelTool.new({}); reselect(c); pt.activate; pt.onUserText('/2', v); pt.commit(v)
t = edit_tool(c)
t.hud_set_value('board_thickness', 18.0, v)
t.commit(v)
check 'hông dày 18', near(bb(part(c, 'Hông Trái'))[3], 18.0)
check 'đợt dựng lại theo lòng tủ mới', near(bb(parts_named(c, 'Đợt').first)[0], 18.0)
check 'dày 18: không xuyên nhau', clashes(c).empty?, clashes(c).first(3).inspect
c = cab
t = edit_tool(c)
press = lambda do |tool, kind, key|
  tool.draw(v)
  idx = kind == :mode ? tool.hud_spec[:mode][:items].index { |i| i[0] == key } : tool.hud_params.index { |p| p[:key] == key }
  r = tool.instance_variable_get(:@hud_rects).find { |x| x[4] == kind && x[5] == idx }
  tool.onLButtonDown(0, r[0] + 3, r[1] + 3, v)
end
press.call(t, :mode, 'base')
check 'Sửa tủ: đổi sang Bếp dưới áp chân 100', t.settings['cabinet_type'] == 'base' && t.settings['leg_height'] == 100.0
t.commit(v)
names = groups(shell(c).definition.entities).map(&:name)
check 'tủ đổi thành bếp dưới: có giằng, mất nóc', names.include?('Giằng trước') && !names.include?('Nóc'), names.inspect
check 'loại tủ lưu vào tủ', V::ModelData.params(c)['cabinet_type'] == 'base'

puts '== 5. Kéo Scale tủ rồi Box → Board =='
c = cab
c.transformation = Geom::Transformation.new([[1.25, 0, 0], [0, 1, 0], [0, 0, 1], [0, 0, 0]])
t = edit_tool(c)
check 'đọc kích thước từ Scale (800 × 1.25 = 1000)', near(t.hud_get('_width'), 1000.0), t.hud_get('_width')
t.commit(v)
check 'sau dựng lại: tủ hết bị scale', V::Rebuild.scale_of(c).nil?
check 'kích thước thật 1000, ván vẫn dày 17.5', dims(c)[0] == 1000.0 && near(bb(part(c, 'Hông Trái'))[3], 17.5) && near(bb(part(c, 'Hông Phải'))[3], 1000)

puts '== 6. Tấm chỉnh tay =='
c = cab
side = part(c, 'Hông Trái')
side.set_attribute('VGD_Cabinet_Draw', 'geo_sig', 'đã sửa tay')
check 'phát hiện hông trái chỉnh tay', V::Rebuild.hand_edited(c).map { |i| i[:entity] } == [side]
t = edit_tool(c, :cancel); t.hud_set_value('_width', 900.0, v); t.commit(v)
check 'Hủy: không đổi gì', dims(c)[0] == 800.0 && side.valid?
t = edit_tool(c, :keep); t.hud_set_value('_width', 900.0, v); t.commit(v)
check 'Giữ: hông trái cũ còn nguyên, không dựng thêm hông trái', side.valid? && groups(shell(c).definition.entities).count { |g| g.name == 'Hông Trái' } == 1 && dims(c)[0] == 900.0
t = edit_tool(c, :overwrite); t.hud_set_value('_width', 950.0, v); t.commit(v)
check 'Ghi đè: hông trái dựng lại mới', !side.valid? && groups(shell(c).definition.entities).count { |g| g.name == 'Hông Trái' } == 1
check 'sau ghi đè: hết tấm chỉnh tay', V::Rebuild.hand_edited(c).empty?
c = cab
t = edit_tool(c)
UI.next_answer = 2
part(c, 'Đáy').set_attribute('VGD_Cabinet_Draw', 'notched', true)
t2 = edit_tool(c); t2.hud_set_value('_depth', 600.0, v); t2.commit(v)
check 'hỏi bằng hộp thoại; Cancel = không sửa', dims(c)[1] == 560.0 && UI.msgs.last.to_s.include?('chỉnh tay')
UI.next_answer = nil

puts '== 7. Tủ tạo bằng bản cũ (đợt chưa có bước tạo) =='
c = cab
pt = V::Tools::PanelTool.new({}); reselect(c); pt.activate; pt.onUserText('350', v); pt.commit(v)
c.set_attribute('VGD_Cabinet_Draw', 'build_ops_json', '[]')
s0 = parts_named(c, 'Đợt').first
p = V::ModelData.params(s0); p.delete('op'); s0.set_attribute('VGD_Cabinet_Draw', 'params_json', JSON.generate(p))
t = edit_tool(c); t.hud_set_value('_height', 2200.0, v); t.commit(v)
s1 = parts_named(c, 'Đợt').first
check 'đợt cũ được nhận và giữ khoảng cách 350 mm', parts_named(c, 'Đợt').length == 1 && near(bb(s1)[2], 57.5 + 350), s1 && bb(s1).inspect

puts '== 8. Thùng tủ lạnh: sửa cao tủ lạnh =='
Sketchup.reset_model!
c = V::Geometry.cabinet_from_box(mk_box(800, 700, 2400), { 'front_normal' => [0, -1, 0], 'cabinet_type' => 'fridge' }.merge(V::Schema::TYPE_PRESETS['fridge']))
t = edit_tool(c)
t.draw(v)
check 'Sửa tủ lạnh: HUD có hàng kích thước tủ lạnh', t.hud_params.any? { |p| p[:key] == 'fridge_height' }
t.hud_set_value('fridge_height', 1700.0, v); t.commit(v)
check 'đáy hộc trên hạ theo tủ lạnh mới (1780)', near(bb(part(c, 'Đáy'))[2], 1780), bb(part(c, 'Đáy')).inspect
check 'chỉ còn 1 khối tham chiếu tủ lạnh', groups(c.definition.entities).count { |g| g.name == 'Tủ lạnh (tham chiếu)' } == 1

puts '== 9. Lỗi người dùng báo: đổi loại tủ trên HUD (qua nút thanh công cụ) rồi Enter =='
c = cab
tb = V.instance_variable_get(:@toolbar)
sel = Sketchup.active_model.selection; sel.clear; sel.add(c)
tb.commands[0].run
t = Sketchup.active_model.tool
check 'nút Box → Board với tủ đang chọn mở Sửa tủ', t.is_a?(V::Tools::EditCabinetTool)
t.draw(v)
idx = t.hud_spec[:mode][:items].index { |i| i[0] == 'wall' }
r = t.instance_variable_get(:@hud_rects).find { |x| x[4] == :mode && x[5] == idx }
t.onMouseMove(0, r[0] + 3, r[1] + 3, v); t.onLButtonDown(0, r[0] + 3, r[1] + 3, v)
check 'HUD báo đang xem trước, chờ Enter', t.hud_lines.first.include?('Enter')
t.onReturn(v)
names = groups(shell(c).definition.entities).map(&:name)
check 'tủ có chân/phào đổi được sang Bếp trên (không lỗi đọc nhóm đã xóa)', V::ModelData.params(c)['cabinet_type'] == 'wall' && names.include?('Xà treo'), names.inspect
check 'bỏ chân & phào cũ', container(c, 'Chân & phào').nil?

puts '== 10. Xà chặn sửa nhiều lần không bị nhân đôi =='
c = cab
V::Operations.blockers([c], V::Schema.merge_settings({}), [])
2.times { |i| t = edit_tool(c); t.hud_set_value('_width', 900.0 + i * 50, v); t.commit(v) }
check 'chỉ còn 1 xà chặn', groups(shell(c).definition.entities).count { |g| g.name.start_with?('Xà Chặn') } == 1
check 'xà chặn mang số bước', groups(shell(c).definition.entities).all? { |g| !g.name.start_with?('Xà Chặn') || V::ModelData.params(g)['op'] }

puts '== 11. Bước không dựng lại được: hủy và báo rõ =='
c = cab
V::Operations.drawers([c], V::Schema.merge_settings({ 'drawer_count' => 4 }), [])
UI.msgs.clear
t = edit_tool(c); t.hud_set_value('_height', 280.0, v); t.commit(v)
check 'báo lỗi bằng hộp thoại', UI.msgs.any? { |m| m.to_s.include?('Không sửa được tủ') && m.to_s.include?('Ngăn kéo') }, UI.msgs.inspect
check 'lỗi hiện trên HUD', t.hud_lines.any? { |l| l.start_with?('Lỗi:') }
check 'lỗi hiện ở thanh trạng thái', Sketchup.status_text.to_s.include?('Không sửa được tủ')

puts '== 12. Đợt bản cũ: giữ đúng thứ tự (đợt trên đo tới đợt dưới) =='
c = cab
p1 = V::Tools::PanelTool.new({}); reselect(c); p1.activate; p1.onUserText('300', v); p1.commit(v)
p2 = V::Tools::PanelTool.new({}); reselect(c); p2.activate; hover_panel(p2, c, 400, 1500); p2.onUserText('282', v); p2.commit(v)
z_before = parts_named(c, 'Đợt').map { |s| bb(s)[2] }.sort
c.set_attribute('VGD_Cabinet_Draw', 'build_ops_json', '[]')
parts_named(c, 'Đợt').reverse.each { |s| q = V::ModelData.params(s); q.delete('op'); s.set_attribute('VGD_Cabinet_Draw', 'params_json', JSON.generate(q)) }
t = edit_tool(c); t.hud_set_value('_width', 900.0, v); t.commit(v)
z_after = parts_named(c, 'Đợt').map { |s| bb(s)[2] }.sort
check 'hai đợt bản cũ giữ nguyên cao độ', z_after.length == 2 && z_after.zip(z_before).all? { |a, b| near(a, b) }, [z_before, z_after].inspect

puts '== 13. Gõ số khi chưa chọn hàng / bảng gửi khóa của tab khác =='
c = cab
t = edit_tool(c)
check 'gõ số khi chưa chọn hàng: không lỗi, có nhắc', !(begin; t.onUserText('900', v); false; rescue StandardError => e; e.message; end).is_a?(String) && Sketchup.status_text.to_s.include?('Bấm vào hàng')
check 'click ngoài HUD: không lỗi', !(begin; t.onLButtonDown(0, 500, 500, v); false; rescue StandardError => e; e.message; end).is_a?(String)
t.update_settings(t.settings.merge('door_gap' => 7.0, 'drawer_count' => 9, 'leg_height' => 60.0))
dirty = t.instance_variable_get(:@dirty)
check 'chỉ nhận thông số thùng tủ từ bảng (bỏ door_gap, drawer_count)', dirty.keys == ['leg_height'], dirty.keys.inspect

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.length}"
exit($fail.empty? ? 0 : 1)
