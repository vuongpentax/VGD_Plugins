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
notch = nong.entities.add_face([[500.mm, 100.mm, zt], [550.mm, 100.mm, zt], [550.mm, 150.mm, zt], [500.mm, 150.mm, zt]])
before = nong.bounds
scale_root(c, 1.25)
auto_run(c)
nong2 = part(c, 'Nóc')
after = nong2.bounds
f = (after.max.x - after.min.x) / (before.max.x - before.min.x)
expect_x0 = after.min.x + (500.mm - before.min.x) * f
check 'vết khấu co theo tỷ lệ của ván', notch.valid? && near(notch.pts.map(&:x).min, expect_x0, 0.01), [notch.pts.map(&:x).min.to_mm, expect_x0.to_mm].inspect
check 'ván khấu vẫn là cùng đối tượng', nong2.equal?(nong) && nong2.valid?
check 'vật liệu của ván còn', nong2.material.equal?(mat)
check 'texture được đặt lại cho mặt có vật liệu', !notch.positioned.empty?
check 'texture: một ô vân rộng 12 và cao 24 inch (kích thước thật)', notch.positioned.all? { |_, pts, _| near((pts[1] - pts[0]).length, 12.0) && near((pts[2] - pts[0]).length, 24.0) }, notch.positioned.map { |_, pts, _| [(pts[1] - pts[0]).length, (pts[2] - pts[0]).length] }.inspect

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
check 'lật gương: có báo hướng dẫn', UI.msgs.drop(msgs_before).any? { |m| m.include?('lật gương') }, UI.msgs.drop(msgs_before).inspect

puts "\n== Kết quả test_stretch: Đạt: #{$pass}   Không đạt: #{$fail.length} =="
$fail.each { |x| puts "  - #{x}" }
