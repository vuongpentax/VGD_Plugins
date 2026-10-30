# Test lệnh Scale VGD: 6 điểm neo ở tâm các mặt, chọn điểm neo rồi kéo/gõ số để co giãn kiểu stretch (giả lập SketchUp).
# Chạy: ruby test_scale_tool.rb [thư mục runtime]
$stdout.sync = true
src = File.read(File.join(__dir__, 'test_build.rb'), encoding: 'UTF-8')
eval(src.split("puts '== 1.").first, binding, File.join(__dir__, 'test_build.rb'))
v = Sketchup.active_model.active_view
def dims(c); d = V::ModelData.params(c); [d['width_mm'], d['depth_mm'], d['height_mm']]; end
def mmpt(x, y, z); Geom::Point3d.new(x.mm, y.mm, z.mm); end
def new_tool(c)
  reselect(c)
  t = V::Tools::ScaleTool.new
  t.activate
  t
end
def move_to(t, point, x = 5, y = 5)
  vv = Sketchup.active_model.active_view
  vv.fake_point = point
  t.onMouseMove(0, x, y, vv)
end
def screen_of(point)
  s = Sketchup.active_model.active_view.screen_coords(point)
  [s.x, s.y]
end

puts '== 1. Điểm neo: 6 điểm ở tâm các mặt của hộp tủ =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0) # 800 x 560 x 2000
t = new_tool(c)
g = t.grips
check 'có 6 điểm neo', g.length == 6, g.length.to_s
want = { [0, :min] => [0, 280, 1000], [0, :max] => [800, 280, 1000], [1, :min] => [400, 0, 1000], [1, :max] => [400, 560, 1000], [2, :min] => [400, 280, 0], [2, :max] => [400, 280, 2000] }
ok = want.all? do |(axis, side), mm|
  grip = g.find { |x| x[:axis] == axis && x[:side] == side }
  grip && grip[:point].to_a.map { |q| q.to_mm.round(1) } == mm.map(&:to_f)
end
check 'vị trí 6 điểm neo đúng tâm 6 mặt (mm)', ok, g.map { |x| [x[:axis], x[:side], x[:point].to_a.map { |q| q.to_mm.round(1) }] }.inspect
check 'chưa chọn điểm neo: đang ở bước chọn', t.phase == :pick && t.anchor.nil?

puts '== 2. Rê chuột vào điểm neo thì sáng, chọn điểm neo rồi kéo ra =='
right = g.find { |x| x[:axis] == 0 && x[:side] == :max }
sx, sy = screen_of(right[:point])
move_to(t, right[:point], sx + 3, sy + 2)
check 'rê gần điểm neo hông phải: điểm neo đó sáng', t.hover && t.hover[:axis] == 0 && t.hover[:side] == :max, t.hover.inspect
move_to(t, mmpt(400, 280, 1000), 50, 50)
check 'rê ra xa: không còn sáng', t.hover.nil?
move_to(t, right[:point], sx, sy)
vv = Sketchup.active_model.active_view
t.onLButtonDown(0, sx, sy, vv)
check 'bấm vào điểm neo: vào bước kéo, điểm neo là mặt phải', t.phase == :drag && t.anchor[:axis] == 0 && t.anchor[:side] == :max, t.anchor.inspect
move_to(t, mmpt(-200, 280, 1000))
check 'kéo tới x = -200 (cách điểm neo 1000): kích thước mới 1000', near(t.size_mm, 1000.0, 0.01), t.size_mm.inspect
check 'VCB hiện kích thước mới', Sketchup.vcb_value.to_s.include?('1000'), Sketchup.vcb_value.inspect
before_ops = dims(c)
check 'đang kéo: tủ chưa đổi (chỉ preview)', before_ops == [800.0, 560.0, 2000.0]
t.onLButtonDown(0, 5, 5, vv)
check 'click: tủ rộng 1000 và vẫn là cùng tủ', dims(c) == [1000.0, 560.0, 2000.0] && c.valid?, dims(c).inspect
ox = c.transformation.origin.x.to_mm # bb() đo trong hệ của tủ: đổi sang toạ độ thế giới bằng gốc của tủ
check 'điểm neo (hông phải) đứng yên tại x = 800', near(ox + bb(part(c, 'Hông Phải'))[3], 800.0, 0.05), [ox, bb(part(c, 'Hông Phải'))].inspect
check 'hông trái dời tới x = -200', near(ox + bb(part(c, 'Hông Trái'))[0], -200.0, 0.05), [ox, bb(part(c, 'Hông Trái'))].inspect
check 'tủ hết trạng thái Scale, ván giữ độ dày 17.5', V::Rebuild.scale_of(c).nil? && near(bb(part(c, 'Hông Phải'))[3] - bb(part(c, 'Hông Phải'))[0], 17.5, 0.01)
check 'xong thì quay về bước chọn điểm neo', t.phase == :pick && t.anchor.nil?

puts '== 3. Neo mặt trái: mặt phải dời; gõ số + Enter cho kích thước chuẩn =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
t = new_tool(c)
left = t.grips.find { |x| x[:axis] == 0 && x[:side] == :min }
sx, sy = screen_of(left[:point])
move_to(t, left[:point], sx, sy)
t.onLButtonDown(0, sx, sy, vv)
check 'neo mặt trái', t.phase == :drag && t.anchor[:side] == :min
t.onUserText('1200', vv)
check 'gõ 1200 + Enter: rộng đúng 1200', dims(c) == [1200.0, 560.0, 2000.0], dims(c).inspect
check 'mặt trái đứng yên tại 0, hông phải tới 1200', near(bb(part(c, 'Hông Trái'))[0], 0.0, 0.05) && near(bb(part(c, 'Hông Phải'))[3], 1200.0, 0.05), [bb(part(c, 'Hông Trái')), bb(part(c, 'Hông Phải'))].inspect

puts '== 4. Chiều sâu và chiều cao (chọn điểm neo bằng hàm), số gõ là kích thước mới =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
t = new_tool(c)
t.select_grip(t.grips.find { |x| x[:axis] == 2 && x[:side] == :min }, vv)
t.onUserText('2300', vv)
check 'neo đáy, gõ 2300: cao 2300', dims(c) == [800.0, 560.0, 2300.0], dims(c).inspect
check 'đáy đứng yên z = 0, nóc lên cao', near(bb(part(c, 'Đáy'))[2], 0.0, 0.05) && near(bb(part(c, 'Nóc'))[5], 2300.0, 0.05), [bb(part(c, 'Đáy')), bb(part(c, 'Nóc'))].inspect
t.select_grip(t.grips.find { |x| x[:axis] == 1 && x[:side] == :min }, vv)
t.onUserText('600', vv)
check 'neo một mặt sâu, gõ 600: sâu 600, rộng và cao giữ nguyên', dims(c) == [800.0, 600.0, 2300.0], dims(c).inspect

# Neo mặt sâu phía max (y = 560): mặt min dời ra, gốc tủ dịch theo
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
t = new_tool(c)
t.select_grip(t.grips.find { |x| x[:axis] == 1 && x[:side] == :max }, vv)
t.onUserText('700', vv)
oy = c.transformation.origin.y.to_mm
check 'neo mặt sâu phía max, gõ 700: sâu 700, rộng và cao giữ nguyên', dims(c) == [800.0, 700.0, 2000.0], dims(c).inspect
check 'gốc tủ dịch -140 theo trục sâu', near(oy, -140.0, 0.05), oy.inspect

puts '== 5. Hủy, số sai, Esc =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
t = new_tool(c)
t.select_grip(t.grips.first, vv)
UI.msgs.clear
t.onUserText('abc', vv)
check 'gõ chữ: báo lỗi, tủ không đổi, vẫn ở bước kéo', dims(c) == [800.0, 560.0, 2000.0] && t.phase == :drag && !Sketchup.status_text.to_s.empty?
t.onUserText('10', vv)
check 'quá nhỏ (dưới 50 mm): không áp dụng', dims(c) == [800.0, 560.0, 2000.0] && t.phase == :drag
t.onCancel(0, vv)
check 'Esc khi đang kéo: về bước chọn điểm neo, không thoát lệnh', t.phase == :pick && t.anchor.nil? && t.active?
t.onUserText('1000', vv)
check 'chưa chọn điểm neo mà gõ số: bỏ qua', dims(c) == [800.0, 560.0, 2000.0]
t.onCancel(0, vv)
check 'Esc ở bước chọn: thoát lệnh', Sketchup.active_model.instance_variable_get(:@tool).nil?, Sketchup.active_model.instance_variable_get(:@tool).inspect

puts '== 6. Không chọn tủ / chọn nhiều tủ / tủ đang bị Scale dở =='
Sketchup.active_model.selection.clear
t = V::Tools::ScaleTool.new; t.activate
check 'không chọn tủ: nhắc chọn tủ, chưa có điểm neo', t.grips.empty? && Sketchup.status_text.to_s.include?('chọn'), Sketchup.status_text.inspect
vv.fake_path = [c]
t.onLButtonDown(0, 5, 5, vv)
check 'click vào tủ khi chưa chọn: chọn tủ đó và hiện điểm neo', t.grips.length == 6, t.grips.length.to_s
c2 = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
c.transformation = Geom::Transformation.scaling(1.5, 1, 1) * c.transformation
t = new_tool(c)
check 'tủ đang bị Scale chưa cập nhật: không hiện điểm neo, báo rõ', t.grips.empty? && Sketchup.status_text.to_s.include?('Scale'), Sketchup.status_text.inspect

puts '== 7. Vẽ và nút trên thanh công cụ =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
t = new_tool(c)
vv.drawn = []
check 'vẽ bước chọn không lỗi', (t.draw(vv); true)
t.select_grip(t.grips.first, vv)
move_to(t, mmpt(500, 280, 1000))
check 'vẽ bước kéo không lỗi và có vẽ khung preview', (t.draw(vv); true) && !vv.drawn.nil?
cmd = V.instance_variable_get(:@toolbar).commands.find { |x| x.title == 'Scale VGD' }
Sketchup.active_model.selection.clear
cmd.run
check 'nút Scale VGD mở lệnh Scale', Sketchup.active_model.instance_variable_get(:@tool).is_a?(V::Tools::ScaleTool), Sketchup.active_model.instance_variable_get(:@tool).class.inspect

puts "\n== Kết quả test_scale_tool: Đạt: #{$pass}   Không đạt: #{$fail.length} =="
$fail.each { |x| puts "  - #{x}" }
exit($fail.empty? ? 0 : 1)
