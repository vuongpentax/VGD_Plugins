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
# Chi tiết trong ván giữ nguyên kích thước (mm); chỉ vị trí dời theo tâm của nó (nội suy theo đoạn giữa của ván).
grow = (after.max.x - after.min.x) - (before.max.x - before.min.x)
# Dải 100 mm sát mỗi mép giữ nguyên: phần tăng chỉ chia cho đoạn giữa [min + 100, max - 100].
expect_x0 = 500.mm + grow * (525.mm - (before.min.x + 100.mm)) / ((before.max.x - before.min.x) - 200.mm)
notch_xs = notch.pts.map { |pt| pt.transform(nong2.transformation).x }
world_x = notch_xs.min
check 'vết khấu giữ nguyên rộng 50 mm và dời theo tâm', notch.valid? && near(world_x, expect_x0, 0.01) && near((notch_xs.max - notch_xs.min).to_mm, 50.0, 0.05), [world_x.to_mm, expect_x0.to_mm, (notch_xs.max - notch_xs.min).to_mm].inspect
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

puts '== 9. Scale dọc tủ không có nóc: vách khớp biên mới (khấu xà không hở) =='
def outline_mm(g)
  pts = g.entities.grep(Sketchup::Face).flat_map { |f| f.vertices.map { |vx| vx.position.transform(g.transformation) } }
  pts.map { |p| [p.y.to_mm.round(1), p.z.to_mm.round(1)] }.uniq.sort
end
c = cab('top_mode' => 'rails')
sh = shell(c)
inner = V::Interior.inner(sh)
op = { 'type' => 'panel', 'axis' => 'vertical', 'kind' => 'thong_thuy', 'thickness_mm' => 17.5, 'limit' => false,
       'anchor' => V::Rebuild.anchor_of(sh, (inner.x0 + inner.x1) / 2, (inner.z0 + inner.z1) / 2),
       'setback_mm' => 0.0, 'door_fit' => 'phu', 'mode' => 'free', 'offsets' => [282.5] }
op['op'] = V::Rebuild.record(c, op)
V::Rebuild.place_panels(c, sh, op)
pv0 = parts_named(c, 'Vách').first
mat = Sketchup.active_model.materials.add('Gỗ vách')
pv0.material = mat
scale_root(c, 1.0, 1.0, 1.1)
auto_run(c)
sh = shell(c)
pv = parts_named(c, 'Vách').first
check 'vách giữ nguyên đối tượng và vật liệu sau scale dọc', pv0.equal?(pv) && pv.valid? && pv.material == mat, [pv0.equal?(pv), pv.material.equal?(mat)].inspect
x0 = bb(pv)[0].mm
want = V::Rebuild.vertical_profile(sh, V::Interior.inner(sh), 0.0, [x0, x0 + 17.5.mm]).map { |y, z| [y.to_mm.round(1), z.to_mm.round(1)] }.uniq.sort
check 'vách sau scale dọc khớp biên mới (khấu theo xà mới)', pv && outline_mm(pv) == want, [outline_mm(pv), want].inspect

puts '== 10. Chi tiết trong tấm giữ nguyên kích thước (mm) khi scale: mộng, lỗ, khối lẻ =='
# Bảng độ dời theo trục: chỉ nhịp trống lớn giãn, chi tiết nhỏ (mộng 35 mm, khấu xà 82.5 / 17.5 mm) giữ nguyên.
mm_list = ->(list) { list.map(&:mm) }
knots = V::Rebuild.stretch_knots(mm_list.call([57.5, 900, 935, 1880, 1962.5, 1980]), 57.5.mm, 1980.mm, 57.5.mm, 2180.mm)
shift = ->(c) { V::Rebuild.knot_shift(knots, 57.5.mm, 1980.mm, 57.5.mm, 2180.mm, c.mm).to_mm }
check 'mép dưới không dời, mép trên dời đúng 200 mm', near(shift.call(57.5), 0.0, 0.05) && near(shift.call(1980), 200.0, 0.05), [shift.call(57.5), shift.call(1980)].inspect
check 'mộng 35 mm giữ nguyên (cùng độ dời ở hai mép mộng)', near(shift.call(935) - shift.call(900), 0.0, 0.05), [shift.call(900), shift.call(935)].inspect
check 'khấu 82.5 mm giữ nguyên', near(shift.call(1962.5) - shift.call(1880), 0.0, 0.05), [shift.call(1880), shift.call(1962.5)].inspect
check 'dải 100 mm sát mép tấm giữ nguyên: nhịp lớn chỉ tính từ 157.5 đến 1880 (88 mm trước mộng)', near(shift.call(900), 200.0 * 742.5 / 1687.5, 0.05), shift.call(900).to_s
check 'trong dải 100 mm sát mép dưới: không dời so với mép', near(shift.call(100), 0.0, 0.05) && near(shift.call(157.5), 0.0, 0.05), [shift.call(100), shift.call(157.5)].inspect
check 'trong dải 100 mm sát mép trên: dời nguyên khối theo mép trên (200)', near(shift.call(1900), 200.0, 0.05) && near(shift.call(1962.5), 200.0, 0.05), [shift.call(1900), shift.call(1962.5)].inspect
k = V::Rebuild.stretch_knots([], 0.mm, 1000.mm, 0.mm, 1200.mm)
sh2 = ->(c) { V::Rebuild.knot_shift(k, 0.mm, 1000.mm, 0.mm, 1200.mm, c.mm).to_mm }
check 'tấm trơn 1000 -> 1200: 100 mm hai đầu giữ nguyên, phần giữa giãn đều', near(sh2.call(100), 0.0, 0.05) && near(sh2.call(500), 100.0, 0.05) && near(sh2.call(900), 200.0, 0.05), [sh2.call(100), sh2.call(500), sh2.call(900)].inspect
k = V::Rebuild.stretch_knots([50.mm, 950.mm], 0.mm, 1000.mm, 0.mm, 1200.mm)
sh3 = ->(c) { V::Rebuild.knot_shift(k, 0.mm, 1000.mm, 0.mm, 1200.mm, c.mm).to_mm }
check 'chi tiết ở 50 mm và 950 mm (trong dải 100 mm) dời nguyên khối theo mép', near(sh3.call(50), 0.0, 0.05) && near(sh3.call(950), 200.0, 0.05), [sh3.call(50), sh3.call(950)].inspect
k = V::Rebuild.stretch_knots([], 0.mm, 300.mm, 0.mm, 400.mm)
sh4 = ->(c) { V::Rebuild.knot_shift(k, 0.mm, 300.mm, 0.mm, 400.mm, c.mm).to_mm }
check 'tấm quá ngắn (còn dưới 150 mm ở giữa): bỏ dải 100 mm, vẫn nhận đủ phần tăng', near(sh4.call(300), 100.0, 0.05) && near(sh4.call(150), 50.0, 0.05), [sh4.call(150), sh4.call(300)].inspect

# Khối lẻ nằm giữa vách (qua điểm giữa) di chuyển nguyên khối, không bị kéo giãn.
c = cab('top_mode' => 'rails')
sh = shell(c)
inner = V::Interior.inner(sh)
op = { 'type' => 'panel', 'axis' => 'vertical', 'kind' => 'thong_thuy', 'thickness_mm' => 17.5, 'limit' => false,
       'anchor' => V::Rebuild.anchor_of(sh, (inner.x0 + inner.x1) / 2, (inner.z0 + inner.z1) / 2),
       'setback_mm' => 0.0, 'door_fit' => 'phu', 'mode' => 'free', 'offsets' => [282.5] }
op['op'] = V::Rebuild.record(c, op)
V::Rebuild.place_panels(c, sh, op)
pv = parts_named(c, 'Vách').first
px = bb(pv)[0].mm
loose = pv.entities.add_face([[px, 200.mm, 900.mm], [px, 300.mm, 900.mm], [px, 300.mm, 1200.mm], [px, 200.mm, 1200.mm]])
scale_root(c, 1.0, 1.0, 1.1)
auto_run(c)
zs = loose.vertices.map { |vx| vx.position.z.to_mm }
ys = loose.vertices.map { |vx| vx.position.y.to_mm }
check 'khối lẻ giữa vách giữ nguyên cao 300 mm khi scale dọc', near(zs.max - zs.min, 300.0, 0.05), zs.inspect
check 'khối lẻ giữa vách giữ nguyên rộng 100 mm', near(ys.max - ys.min, 100.0, 0.05), ys.inspect
check 'khối lẻ dời theo vách (không đứng yên): đáy khối dời lên', zs.min > 900.0 + 1.0, zs.inspect

# Khối lẻ trong nóc: scale ngang không làm khối lẻ giãn theo nóc.
c = cab
nong = part(c, 'Nóc')
loose = nong.entities.add_face([[100.mm, 100.mm, 0], [200.mm, 100.mm, 0], [200.mm, 200.mm, 0], [100.mm, 200.mm, 0]])
scale_root(c, 1.25)
auto_run(c)
xs = loose.vertices.map { |vx| vx.position.x.to_mm }
check 'khối lẻ trong nóc giữ nguyên rộng 100 mm khi scale ngang', near(xs.max - xs.min, 100.0, 0.05), xs.inspect
check 'nóc vẫn theo rộng mới 1000', near(bb(part(c, 'Nóc'))[3], 982.5), bb(part(c, 'Nóc')).inspect

puts '== 11. Dời đỉnh một lần cho cả tấm (tránh bước trung gian làm mặt không phẳng) =='
c = cab('top_mode' => 'rails')
sh = shell(c)
inner = V::Interior.inner(sh)
op = { 'type' => 'panel', 'axis' => 'vertical', 'kind' => 'thong_thuy', 'thickness_mm' => 17.5, 'limit' => false,
       'anchor' => V::Rebuild.anchor_of(sh, (inner.x0 + inner.x1) / 2, (inner.z0 + inner.z1) / 2),
       'setback_mm' => 0.0, 'door_fit' => 'phu', 'mode' => 'free', 'offsets' => [282.5] }
op['op'] = V::Rebuild.record(c, op)
V::Rebuild.place_panels(c, sh, op)
pv = parts_named(c, 'Vách').first
before_calls = pv.entities.vector_calls
scale_root(c, 1.0, 1.0, 1.1)
auto_run(c)
check 'vách: mọi đỉnh dời trong đúng một lần transform_by_vectors', pv.entities.vector_calls - before_calls == 1, (pv.entities.vector_calls - before_calls).to_s

puts '== 12. Kiểm tra an toàn sau co giãn; công tắc di chuyển nhóm con =='
# Nếu hình học sau khi dời lệch kế hoạch (SketchUp hoặc tool khác chỉnh thêm), báo lỗi để hoàn tác thay vì để hỏng tấm.
c = cab
nong = part(c, 'Nóc')
old_box = V::Interior.box_of(nong)
new_box = old_box.dup
new_box[3] += 100.mm
ents = nong.entities
orig = ents.method(:transform_by_vectors)
ents.define_singleton_method(:transform_by_vectors) do |es, vs|
  bad = vs.each_with_index.map { |vec, k| k.zero? ? Geom::Vector3d.new(vec.x, vec.y + 1000.mm, vec.z) : vec }
  orig.call(es, bad)
end
err = begin
  V::Rebuild.stretch_features!(nong, old_box, new_box)
  nil
rescue StandardError => e
  e.message
end
check 'hình học lệch kế hoạch: báo lỗi (để hoàn tác), không im lặng', err.to_s.include?('méo'), err.inspect

# Công tắc: tắt thì nhóm con (ví dụ mặt tiết diện CNC) đứng yên, bật thì dời theo tâm.
def nested_after_scale(move)
  V::Rebuild.move_nested = move
  c = cab
  nong = part(c, 'Nóc')
  inner = nong.entities.add_group
  inner.entities.add_face([[100.mm, 100.mm, 0], [200.mm, 100.mm, 0], [200.mm, 200.mm, 0], [100.mm, 200.mm, 0]])
  before = inner.transformation.to_a
  scale_root(c, 1.25)
  auto_run(c)
  [before, inner.transformation.to_a]
ensure
  V::Rebuild.move_nested = true
end
before, after = nested_after_scale(false)
check 'tắt di chuyển nhóm con: nhóm con đứng yên', before == after, after.inspect
before, after = nested_after_scale(true)
check 'bật (mặc định): nhóm con dời theo tâm', before != after, after.inspect

puts '== 13. Báo rõ lệch xảy ra ở bước nào: dời đỉnh hay dời nhóm con =='
def stretch_error(part, old_box, new_box)
  V::Rebuild.stretch_features!(part, old_box, new_box)
  nil
rescue StandardError => e
  e.message
end
# Lệch ngay khi dời đỉnh (SketchUp chỉnh thêm).
c = cab
nong = part(c, 'Nóc')
old_box = V::Interior.box_of(nong)
new_box = old_box.dup
new_box[3] += 100.mm
ents = nong.entities
orig = ents.method(:transform_by_vectors)
ents.define_singleton_method(:transform_by_vectors) do |es, vs|
  orig.call(es, vs.each_with_index.map { |vec, k| k.zero? ? Geom::Vector3d.new(vec.x, vec.y + 1000.mm, vec.z) : vec })
end
err = stretch_error(nong, old_box, new_box)
check 'lệch ngay khi dời đỉnh: thông báo nói rõ bước dời đỉnh', err.to_s.include?('dời đỉnh') && !err.to_s.include?('nhóm con'), err.inspect

# Chỉ lệch sau khi dời nhóm con (tool khác phản ứng với việc dời nhóm con).
c = cab
nong = part(c, 'Nóc')
nong.entities.add_group.entities.add_face([[100.mm, 100.mm, 0], [200.mm, 100.mm, 0], [200.mm, 200.mm, 0], [100.mm, 200.mm, 0]])
old_box = V::Interior.box_of(nong)
new_box = old_box.dup
new_box[3] += 100.mm
ents = nong.entities
body_vertex = ents.grep(Sketchup::Face).first.vertices.first
ents.define_singleton_method(:transform_entities) do |t, list = nil|
  result = super(t, list)
  transform_by_vectors([body_vertex], [Geom::Vector3d.new(0, 1000.mm, 0)]) if Array(list).any? { |e| e.is_a?(Sketchup::Group) }
  result
end
err = stretch_error(nong, old_box, new_box)
check 'lệch sau khi dời nhóm con: thông báo nói rõ bước dời nhóm con', err.to_s.include?('nhóm con'), err.inspect

# Không lệch: không báo lỗi.
c = cab
nong = part(c, 'Nóc')
old_box = V::Interior.box_of(nong)
new_box = old_box.dup
new_box[3] += 100.mm
check 'không lệch: không báo lỗi', stretch_error(nong, old_box, new_box).nil?

puts '== 14. SketchUp chỉnh lệch khi dời đỉnh: dựng lại tấm từ vị trí kế hoạch =='
c = cab
g = shell(c).definition.entities.add_group
g.name = 'Tấm thử'
g.entities.add_face([[0, 0, 0], [0, 300.mm, 0], [0, 300.mm, 300.mm], [0, 0, 300.mm]])
old_box = [0, 0, 0, 0, 300.mm, 300.mm]
new_box = [0, 0, 0, 0, 300.mm, 500.mm]
ents = g.entities
orig = ents.method(:transform_by_vectors)
ents.define_singleton_method(:transform_by_vectors) do |es, vs|
  orig.call(es, vs.each_with_index.map { |vec, k| k.zero? ? Geom::Vector3d.new(vec.x, vec.y + 1000.mm, vec.z) : vec })
end
err = stretch_error(g, old_box, new_box)
faces = g.entities.grep(Sketchup::Face)
pts = faces.flat_map { |f| f.vertices.map { |vx| [vx.position.y.to_mm.round(1), vx.position.z.to_mm.round(1)] } }.uniq.sort
check 'lệch khi dời đỉnh: dựng lại từ kế hoạch, không báo lỗi', err.nil? && faces.length == 1 && pts == [[0.0, 0.0], [0.0, 500.0], [300.0, 0.0], [300.0, 500.0]], [err, pts].inspect

puts '== 15. Tủ copy dùng chung dữ liệu: tách riêng mọi tầng trước khi sửa tại chỗ =='
c = cab
part(c, 'Nóc').entities.add_group
all_groups = [c]
collect = lambda do |group|
  group.entities.to_a.each do |child|
    next unless child.is_a?(Sketchup::Group)
    all_groups << child
    collect.call(child)
  end
end
collect.call(c)
made_unique = []
all_groups.each { |g| g.define_singleton_method(:make_unique) { made_unique << self; self } }
V::Rebuild.make_unique_tree(c)
missing = all_groups.reject { |g| made_unique.include?(g) }.map(&:name)
check 'make_unique_tree tách riêng mọi tầng (tủ, thùng tủ, các tấm, nhóm con trong tấm)', missing.empty?, missing.inspect

# Nếu sau khi tách vẫn còn dùng chung với tủ khác thì dừng, không sửa đè tủ kia.
c = cab
nong = part(c, 'Nóc')
nong.define_singleton_method(:definition) do
  d = super()
  d.define_singleton_method(:count_instances) { 2 }
  d
end
err = begin
  V::Rebuild.ensure_unshared!(c)
  nil
rescue StandardError => e
  e.message
end
check 'còn dùng chung với tủ khác: báo lỗi rõ, không sửa', err.to_s.include?('dùng chung'), err.inspect

puts '== 15. Cánh tự động bám hồi/hông khi scale tủ =='
def door_xs(c); doors_of_test(c).map { |d| b = V::Operations.door_bounds(d); [b[0].to_mm.round(2), b[3].to_mm.round(2)] }; end
def add_auto_partition(c, offset_mm)
  sh = shell(c)
  inner = V::Interior.inner(sh)
  op = { 'type' => 'panel', 'axis' => 'vertical', 'kind' => 'thong_thuy', 'thickness_mm' => 17.5, 'limit' => false,
         'anchor' => V::Rebuild.anchor_of(sh, (inner.x0 + inner.x1) / 2, (inner.z0 + inner.z1) / 2),
         'setback_mm' => 0.0, 'door_fit' => 'phu', 'mode' => 'free', 'offsets' => [offset_mm] }
  op['op'] = V::Rebuild.record(c, op)
  V::Rebuild.place_panels(c, sh, op)
end
def build_auto_doors(c, settings = {})
  reselect(c)
  dt = V::Tools::DoorTool.new(settings); dt.activate
  dt.auto_split_by_partitions
  dt.commit(Sketchup.active_model.active_view)
end
def partition_centre(c); b = bb(parts_named(c, 'Vách').first); (b[0] + b[3]) / 2.0; end

c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
add_auto_partition(c, 282.5)
build_auto_doors(c)
check 'trước scale: 3 cánh (khoang trái ≤ 450, khoang phải > 450 chia đôi)', door_xs(c).length == 3, door_xs(c).inspect
scale_root(c, 1.25)
auto_run(c)
xs = door_xs(c)
check 'sau scale rộng: vẫn 3 cánh', xs.length == 3, xs.inspect
check 'cánh đầu kết thúc đúng tim hồi giữa mới', near(xs[0][1], partition_centre(c), 0.1) && near(xs[1][0], partition_centre(c), 0.1), [xs, partition_centre(c)].inspect
check 'cánh cuối phủ đến hông phải mới (1000)', near(xs.last[1], 1000, 0.1), xs.inspect
check 'cánh ở khoang phải chia đôi giữa khoang mới', near(xs[1][1], xs[2][0], 0.1) && near(xs[1][1], (partition_centre(c) + 8.75 + 982.5) / 2.0, 0.6), xs.inspect
dt = V::Tools::DoorTool.new({}); dt.load_cabinet(c)
check 'bố cục lưu được cập nhật theo tủ mới (tự động)', dt.layout.auto? && near(dt.layout.sorted.first['u1'] * 1000.0, partition_centre(c), 0.2), dt.layout.sorted.map { |r| r['u1'] }.inspect

c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
build_auto_doors(c)
check 'không vách, tủ 800 > 450: 2 cánh', door_xs(c).length == 2, door_xs(c).inspect
UI.msgs.clear
scale_root(c, 0.5)
auto_run(c)
xs = door_xs(c)
check 'thu nhỏ còn 400 (≤ 450): chỉ còn 1 cánh phủ cả tủ', xs.length == 1 && near(xs[0][0], 0.0, 0.1) && near(xs[0][1], 400.0, 0.1), xs.inspect
check 'không báo "không khớp công thức" và tủ vẫn đủ ván', msgs_with('không khớp công thức').empty? && parts_named(c, 'Hông Phải').length == 1, UI.msgs.last.inspect
scale_root(c, 2.0)
auto_run(c)
xs = door_xs(c)
check 'phóng lại 800: trở lại 2 cánh, mỗi cánh nửa tủ', xs.length == 2 && near(xs[0][1], xs[1][0], 0.1) && near(xs[1][1], 800.0, 0.1), xs.inspect

c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
reselect(c)
dt = V::Tools::DoorTool.new({}); dt.activate
dt.layout.split(dt.layout.regions.first['id'], 'vertical', 0.25); dt.commit(v)
scale_root(c, 1.25)
auto_run(c)
xs = door_xs(c)
check 'cánh chia tay (không tự động) giữ tỷ lệ vùng 25%', xs.length == 2 && near(xs[0][1], 250.0, 0.5), xs.inspect

c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
add_auto_partition(c, 282.5)
build_auto_doors(c)
doors = doors_of_test(c)
V::Operations.apply_opening_metadata(doors[0], 'left')
V::Operations.save_opening_to_layout(doors[0], 'left')
scale_root(c, 1.25)
auto_run(c)
check 'hướng mở của cánh được giữ sau khi tính lại', V::Operations.opening_type_of(doors_of_test(c).first) == 'left', V::Operations.opening_type_of(doors_of_test(c).first).inspect


puts '== 16. Bản lề bắt vào hông HOẶC hồi giữa gần nhất khi scale =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
add_auto_partition(c, 282.5)
build_auto_doors(c)
ds = doors_of_test(c)
%w[left left right].each_with_index do |type, i|
  V::Operations.apply_opening_metadata(ds[i], type)
  V::Operations.save_opening_to_layout(ds[i], type)
end
check 'cánh khoang giữa có bản lề: liên kết vào hồi giữa nên không báo lỗi', V::Links.problems(shell(c), doors_of_test(c)).empty?, V::Links.problems(shell(c), doors_of_test(c)).inspect
UI.msgs.clear
scale_root(c, 1.25)
auto_run(c)
check 'scale tủ có cánh bản lề ở khoang giữa: không báo lỗi', msgs_with('Không tự cập nhật được').empty? && V::Rebuild.scale_of(c).nil?, UI.msgs.last.inspect
check 'tủ đã được cập nhật theo rộng mới 1000', dims(c) == [1000.0, 560.0, 2000.0], dims(c).inspect
check 'hướng mở của ba cánh được giữ', doors_of_test(c).map { |d| V::Operations.opening_type_of(d) } == %w[left left right], doors_of_test(c).map { |d| V::Operations.opening_type_of(d) }.inspect

# Số cánh tự động đổi khi scale: cánh có bản lề phải còn bản lề hợp lệ (mép bản lề sát một tấm đứng)
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
build_auto_doors(c)
ds = doors_of_test(c)
%w[left right].each_with_index { |type, i| V::Operations.apply_opening_metadata(ds[i], type); V::Operations.save_opening_to_layout(ds[i], type) }
UI.msgs.clear
scale_root(c, 0.5)
auto_run(c)
check 'thu còn 1 cánh: bản lề hợp lệ, scale không bị chặn', doors_of_test(c).length == 1 && msgs_with('Không tự cập nhật được').empty?, UI.msgs.inspect
scale_root(c, 2.0)
auto_run(c)
types = doors_of_test(c).map { |d| V::Operations.opening_type_of(d) }
check 'phóng lại 2 cánh: không bị chặn bởi bản lề, cánh trái chuyển bản lề sang mép sát hông', doors_of_test(c).length == 2 && msgs_with('Không tự cập nhật được').empty? && types.first != 'right', [types, UI.msgs.last].inspect
check 'mọi bản lề còn bắt được vào tấm', V::Links.problems(shell(c), doors_of_test(c)).empty?, V::Links.problems(shell(c), doors_of_test(c)).inspect

# Cánh bản lề phải mà mép xa mọi tấm đứng (không phải hông, không phải hồi) vẫn báo lỗi
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
reselect(c)
dt = V::Tools::DoorTool.new({}); dt.activate
dt.layout.split(dt.layout.regions.first['id'], 'vertical', 0.5); dt.commit(v)
d0 = doors_of_test(c).first
V::Operations.apply_opening_metadata(d0, 'right')
check 'bản lề phải cách hông và mọi hồi xa (400 mm): vẫn báo lỗi', V::Links.problems(shell(c), [d0]).length == 1, V::Links.problems(shell(c), [d0]).inspect

puts "\n== Kết quả test_stretch: Đạt: #{$pass}   Không đạt: #{$fail.length} =="
$fail.each { |x| puts "  - #{x}" }
