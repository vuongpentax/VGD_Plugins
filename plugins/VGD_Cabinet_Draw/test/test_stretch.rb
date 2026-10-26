# Test TỰ CẬP NHẬT TỦ KHI KÉO SCALE (co giãn tại chỗ, giữ ván và chi tiết). Chạy: ruby test_stretch.rb [thư mục runtime]
$stdout.sync = true
src = File.read(File.join(__dir__, 'test_build.rb'), encoding: 'UTF-8')
# Dùng lại phần khởi tạo + hàm phụ của test_build (cab, part, bb, hover_panel, ...).
eval(src.split("puts '== 1.").first, binding, File.join(__dir__, 'test_build.rb'))
v = Sketchup.active_model.active_view

def dims(c); d = V::ModelData.params(c); [d['width_mm'], d['depth_mm'], d['height_mm']]; end
# Giả lập kéo Scale: SketchUp đổi phép biến đổi của tủ, rồi báo đã xong thao tác với tủ đang chọn.
def scale_root(c, sx, sy = 1.0, sz = 1.0)
  c.transformation = Geom::Transformation.scaling(sx, sy, sz) * c.transformation
end
def auto_run(c)
  reselect(c)
  V::AutoStretch.after_commit(Sketchup.active_model)
end
def op_log; Sketchup.active_model.instance_variable_get(:@ops).dup; end
def msgs_with(text); UI.msgs.select { |m| m.include?(text) }; end

puts '== 1. Kéo Scale rộng x1.25 -> tự cập nhật, giữ đối tượng ván =='
c = cab
hong = part(c, 'Hông Phải'); nong = part(c, 'Nóc'); day = part(c, 'Đáy')
scale_root(c, 1.25)
check 'trước khi chạy: tủ đang ở trạng thái Scale', V::Rebuild.scale_of(c)
auto_run(c)
check 'kích thước lưu theo rộng mới 1000', dims(c) == [1000.0, 560.0, 2000.0], dims(c).inspect
check 'tủ hết trạng thái Scale', V::Rebuild.scale_of(c).nil?
check 'hông phải dời tới 1000', near(bb(part(c, 'Hông Phải'))[3], 1000)
check 'nóc theo rộng mới', near(bb(part(c, 'Nóc'))[3], 982.5)
check 'hậu theo rộng mới', near(bb(part(c, 'Hậu'))[3], 1000 - 8.75)
check 'ván giữ nguyên đối tượng (không tạo lại)', hong.valid? && part(c, 'Hông Phải').equal?(hong) && part(c, 'Nóc').equal?(nong) && part(c, 'Đáy').equal?(day)
check 'dày ván vẫn 17.5 mm', near(bb(part(c, 'Hông Phải'))[3] - bb(part(c, 'Hông Phải'))[0], 17.5)
check 'một tấm mỗi vai trò', %w[Hông\ Trái Hông\ Phải Nóc Đáy Hậu].all? { |n| groups(shell(c).definition.entities).count { |g| g.name == n } == 1 }

puts '== 2. Tắt công tắc: kéo Scale xong không tự cập nhật =='
c = cab
V::AutoStretch.enabled = false
scale_root(c, 1.25)
auto_run(c)
check 'tắt: kích thước lưu vẫn 800', dims(c) == [800.0, 560.0, 2000.0], dims(c).inspect
check 'tắt: tủ vẫn ở trạng thái Scale', V::Rebuild.scale_of(c)
V::AutoStretch.enabled = true

puts '== 3. Khấu và vật liệu giữ nguyên; texture giữ kích thước thật =='
c = cab
nong = part(c, 'Nóc')
mat = Sketchup.active_model.materials.add('Gỗ sồi')
mat.class.send(:attr_accessor, :texture)
mat.texture = Struct.new(:width, :height).new(12.0, 24.0)
nong.material = mat
zt = nong.bounds.max.z
notch = nong.entities.add_face([[500.mm, 100.mm, zt], [550.mm, 100.mm, zt], [550.mm, 150.mm, zt], [500.mm, 150.mm, zt]].map { |pt| Geom::Point3d.new(*pt).transform(nong.transformation.inverse) })
before = nong.bounds
scale_root(c, 1.25)
auto_run(c)
nong2 = part(c, 'Nóc')
after = nong2.bounds
f = (after.max.x - after.min.x) / (before.max.x - before.min.x)
expect_x0 = after.min.x + (500.mm - before.min.x) * f
world_x = notch.pts.map { |pt| pt.transform(nong2.transformation).x }.min
check 'vết khấu co theo tỷ lệ của ván', notch.valid? && near(world_x, expect_x0, 0.01), [world_x.to_mm, expect_x0.to_mm].inspect
check 'ván khấu vẫn là cùng đối tượng', nong2.equal?(nong) && nong2.valid?
check 'vật liệu của ván còn', nong2.material.equal?(mat)
check 'texture được đặt lại cho mặt có vật liệu', !notch.positioned.empty?
check 'texture: cặp điểm (mặt, ảnh) và một ô vân rộng 12, cao 24 inch', notch.positioned.all? { |_, pts, _| pts.length == 6 && near((pts[2] - pts[0]).length, 12.0) && near((pts[4] - pts[0]).length, 24.0) }, notch.positioned.map { |_, pts, _| pts.length }.inspect

puts '== 4. Đợt đã dời bằng tay: giữ độ lệch so với công thức =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
pl = V::Tools::PanelTool.new({}); reselect(c); pl.activate; pl.settings['panel_axis'] = 'horizontal'
hover_panel(pl, c, 200, 1000); pl.onUserText('350', v); pl.commit(v)
shelf = parts_named(c, 'Đợt').first
shelf.transformation = Geom::Transformation.translation([0, 0, 30.mm]) * shelf.transformation
z_before = bb(shelf)[2]
w_before = bb(shelf)[3] - bb(shelf)[0]
scale_root(c, 1.25)
auto_run(c)
shelf2 = parts_named(c, 'Đợt').first
check 'đợt vẫn là cùng đối tượng', shelf2.equal?(shelf) && shelf2.valid?
check 'đợt giữ độ lệch 30 mm khi rộng đổi', near(bb(shelf2)[2], z_before), [bb(shelf2)[2], z_before].inspect
ratio = (bb(shelf2)[3] - bb(shelf2)[0]) / w_before
check 'đợt dài theo lòng tủ mới (965 / 765)', near(ratio, 965.0 / 765.0, 0.02), ratio.inspect

puts '== 5. Scale rộng và sâu và cao cùng lúc =='
c = cab
scale_root(c, 1.0, 0.7, 0.9)
auto_run(c)
check 'kích thước lưu: sâu 392, cao 1800', dims(c) == [800.0, 392.0, 1800.0], dims(c).inspect
check 'hông cao theo tủ mới (trừ phào trần 20 mm)', near(bb(part(c, 'Hông Phải'))[5], 1780), bb(part(c, 'Hông Phải')).inspect
check 'hông vẫn dày 17.5 mm', near(bb(part(c, 'Hông Phải'))[3] - bb(part(c, 'Hông Phải'))[0], 17.5)

puts '== 6. Tủ không khớp công thức (tủ cũ): dựng lại như cũ và báo =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
pl = V::Tools::PanelTool.new({}); reselect(c); pl.activate; pl.settings['panel_axis'] = 'horizontal'
hover_panel(pl, c, 200, 1000); pl.onUserText('350', v); pl.commit(v)
shelf = parts_named(c, 'Đợt').first
legacy = JSON.parse(shelf.get_attribute(V::Schema::DICTIONARY, 'params_json')).reject { |k, _| k == 'op' }
shelf.set_attribute(V::Schema::DICTIONARY, 'params_json', JSON.generate(legacy))
msgs_before = UI.msgs.length
scale_root(c, 1.25)
auto_run(c)
check 'tủ cũ: vẫn cập nhật kích thước', dims(c) == [1000.0, 560.0, 2000.0], dims(c).inspect
check 'tủ cũ: có báo cho người dùng', UI.msgs.drop(msgs_before).any? { |m| m.include?('không khớp công thức') }, UI.msgs.drop(msgs_before).inspect

puts '== 7. Undo: một thao tác riêng, không có abort khi thành công =='
c = cab
scale_root(c, 1.25)
log_before = op_log.length
auto_run(c)
added = op_log.drop(log_before)
check 'có start rồi commit', added.first == [:start] && added.last == [:commit], added.inspect
check 'không abort', !added.include?([:abort])

puts '== 8. Chạy lại khi không còn Scale: không làm gì =='
log_before = op_log.length
auto_run(c)
check 'không có thao tác mới', op_log.length == log_before, op_log.drop(log_before).inspect
check 'kích thước giữ nguyên', dims(c) == [1000.0, 560.0, 2000.0], dims(c).inspect

puts '== 9. Lật gương (scale âm): không co giãn, báo người dùng =='
c = cab
msgs_before = UI.msgs.length
scale_root(c, -1.0, 1.0, 1.0)
auto_run(c)
check 'lật gương: kích thước không đổi', dims(c) == [800.0, 560.0, 2000.0], dims(c).inspect
check 'lật gương: không bật hộp thoại (chỉ ghi thanh trạng thái)', UI.msgs.drop(msgs_before).none?, UI.msgs.drop(msgs_before).inspect

puts '== 10. Ngăn kéo, cánh (đang mở 45°), tay nắm: co giãn tại chỗ, không tạo lại =='
def fronts_of(c); groups(container(c, 'Ngăn kéo').definition.entities).select { |g| g.name == 'Mặt Ngăn Kéo' }; end
def boxes_of(c); groups(container(c, 'Ngăn kéo').definition.entities).select { |g| g.name == 'Thùng Ngăn Kéo' }; end
def doors_of_test(c); V::Operations.doors_of(c).sort_by { |d| V::Operations.door_bounds(d)[0] }; end
def door_width(d); b = V::Operations.door_bounds(d); b[3] - b[0]; end
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
reselect(c)
dk = V::Tools.build('drawer', { 'drawer_count' => 2 }); dk.activate
vv = Sketchup.active_model.active_view; vv.fake_path = [c]; vv.fake_point = at(200, 150)
dk.onMouseMove(0, 5, 5, vv); dk.onLButtonDown(0, 5, 5, vv); dk.commit(vv)
reselect(c)
dt = V::Tools::DoorTool.new({}); dt.activate
dt.layout.split(dt.layout.regions.first['id'], 'vertical', 0.5); dt.commit(v)
doors0 = doors_of_test(c)
V::Operations.apply_opening_metadata(doors0[1], 'right')
V::Operations.save_opening_to_layout(doors0[1], 'right')
V::Operations.handles([doors0[1]], V::Schema.merge_settings({}), [])
V::Operations.set_door_angle(doors0[1], 'right', 45)
fronts_before = fronts_of(c); boxes_before = boxes_of(c)
ids_before = (fronts_before + boxes_before + doors0).map(&:persistent_id).sort
door_w_before = doors0.sum { |d| door_width(d) }
front_w_before = fronts_before.sum { |g| V::Operations.door_bounds(g)[3] - V::Operations.door_bounds(g)[0] }
handles_before = doors0.map { |d| V::Operations.handle_groups(d).length }
msgs_before = UI.msgs.length
check 'trước khi scale: có ngăn kéo, cánh và tay nắm', fronts_before.length == 2 && boxes_before.length == 2 && doors0.length == 2 && handles_before.sum >= 1, [fronts_before.length, boxes_before.length, doors0.length, handles_before].inspect
scale_root(c, 1.25)
auto_run(c)
fronts = fronts_of(c); boxes = boxes_of(c); doors = doors_of_test(c)
check 'không báo lỗi dựng lại (đi đường co giãn)', UI.msgs.drop(msgs_before).none? { |m| m.include?('không khớp') }, UI.msgs.drop(msgs_before).inspect
check 'mặt hộc / thùng / cánh giữ nguyên đối tượng', (fronts + boxes + doors).map(&:persistent_id).sort == ids_before, (fronts + boxes + doors).map(&:persistent_id).sort.inspect
check 'không nhân đôi: số mặt, thùng, cánh không đổi', fronts.length == 2 && boxes.length == 2 && doors.length == 2
check 'kích thước lưu theo rộng mới', dims(c) == [1000.0, 560.0, 2000.0], dims(c).inspect
door_ratio = doors.sum { |d| door_width(d) } / door_w_before
check 'cánh co theo lòng tủ mới (tổng rộng x1.25)', near(door_ratio, 1.25, 0.03), door_ratio.inspect
front_ratio = fronts.sum { |g| V::Operations.door_bounds(g)[3] - V::Operations.door_bounds(g)[0] } / front_w_before
check 'mặt hộc co theo rộng mới', near(front_ratio, 1.25, 0.03), front_ratio.inspect
check 'cánh đang mở giữ đúng góc 45°', V::Operations.door_angle(doors[1]) == 45.0, V::Operations.door_angle(doors[1]).inspect
check 'tay nắm còn đủ, không nhân đôi', doors.map { |d| V::Operations.handle_groups(d).length } == handles_before, doors.map { |d| V::Operations.handle_groups(d).length }.inspect
check 'không còn cánh lẻ ngoài nhóm Cánh', groups(c.definition.entities).none? { |g| g.name.to_s.start_with?('Cánh Draw') }
check 'ngăn kéo vẫn đóng (không mở khi co giãn)', fronts.all? { |g| V::DrawerSlide.open_mm(g).zero? }

puts '== 11. Khoang ngăn kéo (có 3 hộc): co giãn tại chỗ =='
def bay_of(c); groups(shell(c).definition.entities).find { |g| g.name == 'Khoang Ngăn Kéo' }; end
def bay_bottom_w(c); b = bb(groups(bay_of(c).definition.entities).find { |g| g.name == 'Đáy Khoang' }); b[3] - b[0]; end
c = cab
V::DrawerBay.run([c], V::Schema.merge_settings({ 'drawer_count' => 3 }), [])
bay0 = bay_of(c)
fronts0 = fronts_of(c); boxes0 = boxes_of(c)
ids0 = ([bay0] + fronts0 + boxes0).map(&:persistent_id).sort
bw0 = bay_bottom_w(c)
msgs_before = UI.msgs.length
scale_root(c, 1.25)
auto_run(c)
bay1 = bay_of(c)
check 'khoang: không nhân đôi, cùng đối tượng', groups(shell(c).definition.entities).count { |g| g.name == 'Khoang Ngăn Kéo' } == 1 && bay1.equal?(bay0) && bay1.valid?
check 'khoang và các hộc giữ đúng đối tượng', ([bay1] + fronts_of(c) + boxes_of(c)).map(&:persistent_id).sort == ids0
check 'không báo lỗi dựng lại', UI.msgs.drop(msgs_before).none? { |m| m.include?('không khớp') }, UI.msgs.drop(msgs_before).inspect
bw1 = bay_bottom_w(c)
check 'đáy khoang rộng theo lòng tủ mới', bw1 > bw0 * 1.2 && bw1 < bw0 * 1.3, [bw0.to_mm, bw1.to_mm].inspect
check 'số hộc không đổi (3)', fronts_of(c).length == 3 && boxes_of(c).length == 3

puts '== 12. Xà chặn (blocker) và hộc tủ áo: co giãn tại chỗ =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
V::Operations.blockers([c], V::Schema.merge_settings({}), [[c, at(400, 1200)]])
blk0 = groups(shell(c).definition.entities).find { |g| g.get_attribute(V::Schema::DICTIONARY, 'kind') == 'blocker' }
check 'có xà chặn trước khi scale', !blk0.nil?
blk_id = blk0 && blk0.persistent_id
bw0 = blk0 && (bb(blk0)[3] - bb(blk0)[0])
msgs_before = UI.msgs.length
scale_root(c, 1.25)
auto_run(c)
blk1 = groups(shell(c).definition.entities).select { |g| g.get_attribute(V::Schema::DICTIONARY, 'kind') == 'blocker' }
check 'xà chặn: một cái, cùng đối tượng', blk1.length == 1 && blk1.first.persistent_id == blk_id, blk1.map(&:persistent_id).inspect
check 'xà chặn: không báo lỗi dựng lại', UI.msgs.drop(msgs_before).none? { |m| m.include?('không khớp') }, UI.msgs.drop(msgs_before).inspect
check 'xà chặn: rộng theo lòng tủ mới', blk1.any? && (bb(blk1.first)[3] - bb(blk1.first)[0]) > bw0 * 1.2, blk1.any? ? bb(blk1.first).inspect : 'none'

puts '== 13. Liên kết: gờ khung giữ mm, tay nắm cách mép đúng mm, độ dày thùng/hông khoang giữ nguyên =='
def sz(g); b = bb(g); [b[3] - b[0], b[4] - b[1], b[5] - b[2]]; end # mm (bb đã đổi sang mm)
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
reselect(c)
dt = V::Tools::DoorTool.new({ 'door_style' => 'frame', 'frame_width' => 50.0 }); dt.activate
dt.layout.split(dt.layout.regions.first['id'], 'vertical', 0.5); dt.commit(v)
dk = doors_of_test(c)
d0 = dk[1]
V::Operations.apply_opening_metadata(d0, 'right')
V::Operations.save_opening_to_layout(d0, 'right')
V::Operations.handles([d0], V::Schema.merge_settings({}), [])
mat = Sketchup.active_model.materials.add('Gỗ sồi (gờ)')
rail = groups(d0.definition.entities).find { |g| g.name == 'Khung Hông Phải' || g.name == 'Khung Hông Trái' }
rail.material = mat
frame_w_before = sz(rail)[0]
rail_name = rail.name
hdl = V::Operations.handle_groups(d0).first
hdl_gap_before = (bb(hdl)[0] - V::Operations.door_bounds(d0)[0].to_mm).round(2)
msgs_before = UI.msgs.length
scale_root(c, 1.25)
auto_run(c)
dk2 = doors_of_test(c)
d1 = dk2[1]
rail2 = groups(d1.definition.entities).find { |g| g.name == rail_name }
check 'cánh khung: gờ giữ đúng 50 mm sau khi rộng đổi', rail2 && near(sz(rail2)[0], 50.0, 0.05), (rail2 ? sz(rail2)[0] : nil).inspect
check 'cánh khung: gờ trước = sau (50 mm)', near(frame_w_before, 50.0, 0.05)
check 'cánh khung: vật liệu sơn trên gờ còn', rail2 && rail2.material.equal?(mat)
hdl2 = V::Operations.handle_groups(d1).first
hdl_gap_after = (bb(hdl2)[0] - V::Operations.door_bounds(d1)[0].to_mm).round(2)
check 'tay nắm: cách mép cánh vẫn đúng mm', hdl2 && near(hdl_gap_after, hdl_gap_before, 0.05), [hdl_gap_before, hdl_gap_after].inspect
check 'cánh khung: không báo lỗi dựng lại', UI.msgs.drop(msgs_before).none? { |m| m.include?('không khớp') }, UI.msgs.drop(msgs_before).inspect
check 'liên kết: mọi bản lề còn bắt được vào thân tủ', V::Links.problems(shell(c), dk2) == [], V::Links.problems(shell(c), dk2).inspect

fake = Struct.new(:type) do
  def get_attribute(_dict, key, default = nil)
    key == 'opening_type' && type ? type : default
  end
end
order = V::Links.ordered([fake.new('left'), fake.new('top'), fake.new('right'), fake.new('bottom')]).map { |f| f.type }
check 'liên kết: cánh mở lên/xuống xử lý trước', order == %w[top bottom left right], order.inspect

c = cab
V::DrawerBay.run([c], V::Schema.merge_settings({ 'drawer_count' => 2 }), [])
hong = nil
hongs = groups(bay_of(c).definition.entities).select { |g| g.name == 'Hông Khoang Trái' }
hong = hongs.first
t_before = sz(hong)[0].round(2)
bthick0 = boxes_of(c).map { |b| groups(b.definition.entities).map { |g| sz(g).min.round(2) }.sort }
scale_root(c, 1.25)
auto_run(c)
hong2 = groups(bay_of(c).definition.entities).find { |g| g.name == 'Hông Khoang Trái' }
check 'khoang: hông khoang giữ đúng dày 17.5 mm', near(t_before, 17.5, 0.05) && near(sz(hong2)[0], 17.5, 0.05), [t_before, sz(hong2)[0]].inspect
boxes_now = boxes_of(c)
bthick = boxes_now.map { |b| groups(b.definition.entities).map { |g| sz(g).min.round(2) }.sort }
bthick_before = bthick0
check 'ngăn kéo: độ dày các tấm thùng giữ nguyên', bthick == bthick_before, [bthick_before, bthick].inspect

puts "\n== Kết quả test_stretch: Đạt: #{$pass}   Không đạt: #{$fail.length} =="
$fail.each { |x| puts "  - #{x}" }
