# Test lệnh Quét & dời tấm: quét khung / quét cọ chọn nhiều tấm rồi dời cùng một khoảng (giả lập SketchUp).
# Chạy: ruby test_sweep_tool.rb [thư mục runtime]
$stdout.sync = true
src = File.read(File.join(__dir__, 'test_build.rb'), encoding: 'UTF-8')
eval(src.split("\nputs '== 1.").first, binding, File.join(__dir__, 'test_build.rb'))
def dims(c); d = V::ModelData.params(c); [d['width_mm'], d['depth_mm'], d['height_mm']]; end

# Nhìn thẳng từ phía trước (chiếu trực giao): màn hình x = 100 + 0.5 * x(mm), y = 700 - 0.3 * z(mm).
class OrthoCamera
  def direction; Geom::Vector3d.new(0, 1, 0); end
  def eye; Geom::Point3d.new(0, -10000.mm, 0); end
end
def ortho!
  vv = Sketchup.active_model.active_view
  vv.define_singleton_method(:screen_coords) { |p| Geom::Point3d.new(p.x.to_mm * 0.5 + 100, 700 - p.z.to_mm * 0.3, 0) }
  vv.define_singleton_method(:pickray) { |x, y| [Geom::Point3d.new(((x - 100) / 0.5).mm, -10000.mm, ((700 - y) / 0.3).mm), Geom::Vector3d.new(0, 1, 0)] }
  vv.define_singleton_method(:camera) { OrthoCamera.new }
  vv
end
def sx(x_mm); x_mm * 0.5 + 100; end
def sy(z_mm); 700 - z_mm * 0.3; end
def new_cab(*offsets)
  c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
  add_panel(c, 'vertical', offsets) unless offsets.empty?
  c
end
def add_panel(c, axis, offsets)
  sh = shell(c)
  inner = V::Interior.inner(sh)
  op = { 'type' => 'panel', 'axis' => axis, 'kind' => 'thong_thuy', 'thickness_mm' => 17.5, 'limit' => false,
         'anchor' => V::Rebuild.anchor_of(sh, (inner.x0 + inner.x1) / 2, (inner.z0 + inner.z1) / 2),
         'setback_mm' => 0.0, 'door_fit' => 'phu', 'mode' => 'free', 'offsets' => offsets }
  op['op'] = V::Rebuild.record(c, op)
  V::Rebuild.place_panels(c, sh, op)
end
def new_tool(c)
  reselect(c)
  t = V::Tools::SweepTool.new
  t.activate
  t
end
def drag(t, x0, y0, x1, y1, flags = 0)
  vv = Sketchup.active_model.active_view
  t.onLButtonDown(flags, x0, y0, vv)
  steps = 8
  (1..steps).each { |i| t.onMouseMove(flags, x0 + (x1 - x0) * i / steps.to_f, y0 + (y1 - y0) * i / steps.to_f, vv) }
  t.onLButtonUp(flags, x1, y1, vv)
end
def click(t, x, y, flags = 0)
  vv = Sketchup.active_model.active_view
  t.onMouseMove(flags, x, y, vv)
  t.onLButtonDown(flags, x, y, vv)
  t.onLButtonUp(flags, x, y, vv)
end
def names(t); t.selected.map { |e| e.name }.sort; end
def vach_x(c); parts_named(c, 'Vách').map { |g| bb(g)[0] }.sort; end
def dot_z(c); parts_named(c, 'Đợt').map { |g| bb(g)[2] }.sort; end
RIGHT = 39; LEFT = 37; UP = 38; TAB = 9; ESC = 27
V::Keys.platform = :windows

puts '== 1. Ứng viên: mọi group/component trong tủ =='
c = new_cab(282.5, 582.5)
ortho!
t = new_tool(c)
kinds = t.items.map { |e| e[:entity].name }
check 'có đủ hông, đáy, nóc, hậu và 2 vách', %w[Hông\ Trái Hông\ Phải Đáy Nóc Hậu].all? { |n| kinds.include?(n) } && kinds.count { |n| n.start_with?('Vách') } == 2, kinds.inspect
check 'vách có hướng dời ngang (trục 0), đợt trục 2, tấm khác không có trục', t.items.select { |e| e[:entity].name.start_with?('Vách') }.all? { |e| e[:axis] == 0 } && t.items.find { |e| e[:entity].name == 'Hậu' }[:axis].nil?
check 'chưa chọn gì, bước chọn, chế độ khung', t.selected.empty? && t.phase == :select && t.mode == :rect

puts '== 2. Kéo khung trái→phải: chỉ chọn tấm nằm TRỌN trong khung =='
drag(t, sx(280), sy(2000), sx(340), sy(-20))
check 'khung ôm trọn vách 1: chọn đúng vách 1', t.selected.length == 1 && names(t)[0].start_with?('Vách'), names(t).inspect
check 'chọn đúng vách ở x = 300', near(bb(t.selected.first)[0], 300.0, 0.05), bb(t.selected.first).inspect
drag(t, sx(280), sy(1500), sx(340), sy(500))
check 'khung chỉ ôm một phần vách: không chọn (thay thế vùng chọn cũ → rỗng)', t.selected.empty?, names(t).inspect

puts '== 3. Kéo khung phải→trái: chọn mọi tấm CHẠM khung =='
drag(t, sx(790), sy(1000) - 1, sx(10), sy(1000) + 1)
check 'đường ngang mảnh cắt qua: 2 hông + hậu + 2 vách', names(t).length == 5 && names(t).count { |n| n.start_with?('Vách') } == 2 && names(t).include?('Hậu'), names(t).inspect
check 'không chọn đáy / nóc', !names(t).include?('Đáy') && !names(t).include?('Nóc')

puts '== 4. Quét cọ (Tab đổi chế độ) =='
t.onKeyDown(TAB, 0, 0, Sketchup.active_model.active_view)
check 'Tab: đổi sang chế độ cọ', t.mode == :brush
drag(t, sx(280), sy(1000), sx(640), sy(1000))
check 'cọ đi qua hai vách + hậu, không chạm hông', names(t).count { |n| n.start_with?('Vách') } == 2 && names(t).include?('Hậu') && !names(t).include?('Hông Trái') && !names(t).include?('Hông Phải'), names(t).inspect
t.onKeyDown(TAB, 0, 0, Sketchup.active_model.active_view)
check 'Tab lần nữa: về chế độ khung', t.mode == :rect

puts '== 5. Click chọn một tấm, Shift thêm/bớt, bộ lọc F =='
t.onCancel(0, Sketchup.active_model.active_view)
check 'Esc bỏ vùng chọn cũ', t.selected.empty? && t.active?
click(t, sx(308), sy(1500))
check 'click trúng vách 1: chọn đúng một vách', names(t).length == 1 && names(t)[0].start_with?('Vách')
click(t, sx(608), sy(1500), CONSTRAIN_MODIFIER_MASK)
check 'Shift+click thêm vách 2', names(t).length == 2
click(t, sx(308), sy(1500), CONSTRAIN_MODIFIER_MASK)
check 'Shift+click vào tấm đã chọn: bỏ chọn tấm đó', names(t).length == 1
click(t, sx(400), sy(1000) - 130)
check 'đã có vùng chọn: click tiếp theo bắt đầu kéo đi (không cần Enter), không chọn lại', t.phase == :move && names(t).length == 1, [t.phase, names(t)].inspect
t.onCancel(0, Sketchup.active_model.active_view)
t.onCancel(0, Sketchup.active_model.active_view)
check 'Esc hai lần: bỏ kéo rồi bỏ chọn', t.phase == :select && t.selected.empty?
t.onKeyDown(70, 0, 0, Sketchup.active_model.active_view) # F: chỉ hồi/đợt
drag(t, sx(790), sy(1000) - 1, sx(10), sy(1000) + 1)
check 'bộ lọc chỉ hồi/đợt: quét cắt ngang chỉ chọn 2 vách', names(t).length == 2 && names(t).all? { |n| n.start_with?('Vách') }, names(t).inspect
t.onKeyDown(70, 0, 0, Sketchup.active_model.active_view)
t.onKeyDown(70, 0, 0, Sketchup.active_model.active_view)
t.onKeyDown(70, 0, 0, Sketchup.active_model.active_view)
check 'F quay vòng về lọc tất cả', t.filter == :all, t.filter.inspect

puts '== 6. Gõ số mm: dời cùng một khoảng, lưu vào bước tạo tấm =='
c = new_cab(282.5, 582.5)
ortho!
t = new_tool(c)
drag(t, sx(790), sy(1000) - 1, sx(10), sy(1000) + 1)
t.onKeyDown(70, 0, 0, Sketchup.active_model.active_view)
drag(t, sx(790), sy(1000) - 1, sx(10), sy(1000) + 1)
ops_before = Sketchup.active_model.instance_variable_get(:@ops).dup
t.onUserText('100', Sketchup.active_model.active_view)
check 'cả hai vách dời +100: x = 400 và 700', vach_x(c) == [400.0, 700.0], vach_x(c).inspect
offsets = V::Rebuild.ops(c).select { |o| o['type'] == 'panel' }.flat_map { |o| o['offsets'] }.sort
check 'bước tạo tấm lưu vị trí mới (mm từ lòng tủ): 382.5 và 682.5', offsets.length == 2 && near(offsets[0], 382.5, 0.01) && near(offsets[1], 682.5, 0.01), offsets.inspect
ops_after = Sketchup.active_model.instance_variable_get(:@ops)
check 'là một bước Undo (một operation)', ops_after.count { |o| o == [:start] } - ops_before.count { |o| o == [:start] } == 1 && ops_after.last == [:commit], ops_after.last(4).inspect
check 'sau khi dời: vẫn đang chọn lại tấm, về bước chọn', t.phase == :select
c2 = dims(c)
check 'kích thước tủ không đổi', c2 == [800.0, 560.0, 2000.0], c2.inspect
t.onUserText('-50', Sketchup.active_model.active_view)
check 'gõ số âm dời ngược (-50): 350 và 650', vach_x(c) == [350.0, 650.0], vach_x(c).inspect

puts '== 7. Kết hợp hồi và đợt: mỗi tấm dời theo hướng riêng cùng một khoảng =='
c = new_cab(282.5)
add_panel(c, 'horizontal', [500.0])
ortho!
t = new_tool(c)
t.onKeyDown(70, 0, 0, Sketchup.active_model.active_view)
drag(t, sx(790), sy(526) - 1, sx(10), sy(526) + 1) # cắt ngang đợt (z 517.5..535) và cả vách
check 'quét qua vách và đợt (lọc hồi/đợt)', names(t).length == 2 && names(t).any? { |n| n.start_with?('Vách') } && names(t).any? { |n| n.start_with?('Đợt') }, names(t).inspect
before_x = vach_x(c); before_z = dot_z(c)
t.onUserText('80', Sketchup.active_model.active_view)
check 'vách dời ngang +80, đợt dời lên +80', near(vach_x(c)[0], before_x[0] + 80, 0.05) && near(dot_z(c)[0], before_z[0] + 80, 0.05), [before_x, vach_x(c), before_z, dot_z(c)].inspect

puts '== 8. Tấm khác (hông, hậu...): chỉ dời khi đã khóa trục bằng phím mũi tên =='
c = new_cab(282.5)
ortho!
t = new_tool(c)
click(t, sx(791), sy(1000))
check 'click chọn hông phải', names(t) == ['Hông Phải'], names(t).inspect
before = bb(part(c, 'Hông Phải'))
t.onUserText('-40', Sketchup.active_model.active_view)
check 'chưa khóa trục: hông không dời, có thông báo', bb(part(c, 'Hông Phải')) == before && Sketchup.status_text.to_s.include?('khóa'), Sketchup.status_text.inspect
t.onKeyDown(RIGHT, 0, 0, Sketchup.active_model.active_view)
check 'phím → khóa trục trái–phải (X)', t.axis_lock == 0, t.axis_lock.inspect
t.onUserText('-40', Sketchup.active_model.active_view)
after = bb(part(c, 'Hông Phải'))
check 'khóa X: hông phải dời -40 theo trục X', near(after[0], before[0] - 40, 0.05) && near(after[3], before[3] - 40, 0.05), [before, after].inspect
check 'hông phải được đánh dấu chỉnh tay', V::Geometry.hand_edited?(part(c, 'Hông Phải')), V::Geometry.hand_edited?(part(c, 'Hông Phải')).inspect
check 'tấm khác không đổi', near(bb(part(c, 'Hông Trái'))[0], 0.0, 0.01)
t.onKeyDown(UP, 0, 0, Sketchup.active_model.active_view)
check 'phím ↑ khóa trục đứng (Z)', t.axis_lock == 2
t.onKeyDown(LEFT, 0, 0, Sketchup.active_model.active_view)
check 'phím ← khóa trục trước–sau (Y)', t.axis_lock == 1
t.onKeyDown(LEFT, 0, 0, Sketchup.active_model.active_view)
check 'bấm lại cùng phím mũi tên: bỏ khóa', t.axis_lock.nil?

puts '== 9. Vách + tấm khác cùng lúc: vách dời theo bước tạo, tấm khác theo trục khóa =='
c = new_cab(282.5)
ortho!
t = new_tool(c)
t.onKeyDown(RIGHT, 0, 0, Sketchup.active_model.active_view)
drag(t, sx(790), sy(1000) - 1, sx(10), sy(1000) + 1)
before_back = bb(part(c, 'Hậu'))
t.onUserText('60', Sketchup.active_model.active_view)
check 'vách dời +60', vach_x(c) == [360.0], vach_x(c).inspect
check 'hậu (khóa X) dời +60', near(bb(part(c, 'Hậu'))[0], before_back[0] + 60, 0.05), [before_back, bb(part(c, 'Hậu'))].inspect

puts '== 10. Giới hạn và kiểm tra =='
c = new_cab(282.5, 382.5)
ortho!
t = new_tool(c)
click(t, sx(308), sy(1500))
ops0 = V::Rebuild.ops(c).map { |o| o['offsets'] }
t.onUserText('90', Sketchup.active_model.active_view)
check 'dời vách 1 chồng lên vách 2: báo lỗi, không đổi', vach_x(c) == [300.0, 400.0] && V::Rebuild.ops(c).map { |o| o['offsets'] } == ops0 && Sketchup.status_text.to_s.include?('chồng'), [vach_x(c), Sketchup.status_text].inspect
t.onUserText('5000', Sketchup.active_model.active_view)
check 'dời quá lòng tủ: vách bị chặn ở mép lòng tủ, không xuyên hông, và không chồng vách bên cạnh hoặc báo lỗi', vach_x(c).all? { |x| x >= 17.5 && x <= 782.5 - 17.5 + 0.01 }, vach_x(c).inspect
t.onUserText('abc', Sketchup.active_model.active_view)
check 'gõ chữ: báo lỗi', Sketchup.status_text.to_s.include?('số'), Sketchup.status_text.inspect

puts '== 11. Cánh tự động đi theo vách đã dời =='
c = new_cab(282.5)
ortho!
reselect(c)
dt = V::Tools::DoorTool.new('door_auto_width' => 0.0); dt.activate
dt.auto_split_by_partitions
dt.commit(Sketchup.active_model.active_view)
def edges_of(c); V::Operations.doors_of(c).map { |d| b = V::Operations.door_bounds(d); [b[0].to_mm.round(2), b[3].to_mm.round(2)] }.sort; end
check 'trước khi dời: cánh chia ở tim vách 308.75', near(edges_of(c)[0][1], 308.75, 0.05), edges_of(c).inspect
t = new_tool(c)
click(t, sx(308), sy(1500))
t.onUserText('100', Sketchup.active_model.active_view)
check 'sau khi dời vách +100: cánh chia ở tim mới 408.75', near(edges_of(c)[0][1], 408.75, 0.05) && near(edges_of(c)[1][0], 408.75, 0.05), edges_of(c).inspect

puts '== 12. Chọn xong click tiếp theo là kéo đi; di chuột, click đặt; Esc =='
c = new_cab(282.5)
vv = ortho!
t = new_tool(c)
click(t, sx(308), sy(1500))
check 'click đầu: chọn vách', names(t).length == 1 && t.phase == :select
click(t, sx(308), sy(1500))
check 'click tiếp theo: vào bước kéo ngay, không cần Enter', t.phase == :move, t.phase.inspect
t.onMouseMove(0, sx(308) + 40, sy(1500), vv)
check 'chuột sang phải 40 px (= 80 mm): khoảng dời 80', near(t.distance_mm, 80.0, 0.6), t.distance_mm.inspect
t.onLButtonDown(0, sx(308) + 40, sy(1500), vv)
check 'click: vách dời 80 mm', near(vach_x(c)[0], 380.0, 0.6), vach_x(c).inspect
check 'xong thì về bước chọn, vẫn giữ vùng chọn để kéo tiếp', t.phase == :select && t.selected.length == 1
click(t, sx(388), sy(1500))
check 'click kéo tiếp lần hai', t.phase == :move
t.onCancel(0, vv)
check 'Esc khi đang kéo: về bước chọn, vẫn giữ vùng chọn', t.phase == :select && t.selected.length == 1
t.onReturn(vv)
check 'Enter vẫn bắt đầu kéo như cũ', t.phase == :move
t.onCancel(0, vv)
t.onCancel(0, vv)
check 'Esc khi đang có vùng chọn: bỏ chọn', t.selected.empty? && t.active?
t.onCancel(0, vv)
check 'Esc lần nữa: thoát lệnh', Sketchup.active_model.instance_variable_get(:@tool).nil?
c = new_cab
vv = ortho!
t = new_tool(c)
click(t, sx(791), sy(1000))
click(t, sx(791), sy(1000))
check 'chọn tấm khác (hông) chưa khóa trục: click tiếp theo chưa kéo, nhắc khóa trục', t.phase == :select && Sketchup.status_text.to_s.include?('khóa trục'), Sketchup.status_text.inspect
t.onKeyDown(RIGHT, 0, 0, vv)
click(t, sx(791), sy(1000))
check 'đã khóa trục: click tiếp theo kéo được', t.phase == :move

puts '== 12b. Preview chỉ hiện số =='
c = new_cab(282.5)
vv = ortho!
t = new_tool(c)
click(t, sx(308), sy(1500))
click(t, sx(308), sy(1500))
t.onMouseMove(0, sx(308) + 25, sy(1500), vv)
vv.drawn = []
t.draw(vv)
texts = vv.drawn.select { |e| e[0] == :text }.map { |e| e[1][1] }
check 'nhãn khi kéo chỉ là số, không mm, không chữ', texts.length == 1 && texts.first.match?(/\A-?\d+(\.\d+)?\z/), texts.inspect

puts '== 13. Vẽ, không có chữ góc trên trái, nút thanh công cụ =='
c = new_cab(282.5)
vv = ortho!
t = new_tool(c)
vv.drawn = []
t.draw(vv)
check 'bước chọn: không vẽ chữ nào', vv.drawn.none? { |e| e[0] == :text }
t.onLButtonDown(0, sx(790), sy(1000), vv)
t.onMouseMove(0, sx(10), sy(1000) + 5, vv)
check 'đang kéo khung: vẽ không lỗi', (t.draw(vv); true)
t.onLButtonUp(0, sx(10), sy(1000) + 5, vv)
check 'đang có vùng chọn: vẽ không lỗi', (t.draw(vv); true)
tb = V.instance_variable_get(:@toolbar).commands.map(&:title)
check 'toolbar có nút Quét & dời tấm', tb.include?('Quét & dời tấm'), tb.inspect
cmd = V.instance_variable_get(:@toolbar).commands.find { |x| x.title == 'Quét & dời tấm' }
Sketchup.active_model.selection.clear
cmd.run
check 'nút mở lệnh Quét & dời tấm', Sketchup.active_model.instance_variable_get(:@tool).is_a?(V::Tools::SweepTool)
check 'icon PNG 16/24 của nút tồn tại', cmd.small_icon.to_s.end_with?('sweep_16.png') && cmd.large_icon.to_s.end_with?('sweep_24.png') && File.file?(cmd.small_icon) && File.file?(cmd.large_icon), [cmd.small_icon, cmd.large_icon].inspect

puts "\n== Kết quả test_sweep_tool: Đạt: #{$pass}   Không đạt: #{$fail.length} =="
$fail.each { |x| puts "  - #{x}" }
exit($fail.empty? ? 0 : 1)
