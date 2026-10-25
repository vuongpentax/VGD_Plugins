# Test rủi ro 27: tủ nằm trong group cha có dịch chuyển -> tọa độ thế giới phải tính cả group cha.
# Chạy: ruby test_world.rb [thư mục runtime]
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
def same?(a, b)
  (0..3).all? { |i| (0..2).all? { |j| (a.m[i][j] - b.m[i][j]).abs < 1e-6 } }
end
def mk_box_in(entities, w, d, h)
  g = entities.add_group; g.name = 'Box'
  f = g.entities.add_face([[0, 0, 0], [w.mm, 0, 0], [w.mm, d.mm, 0], [0, d.mm, 0]])
  f.reverse! if f.normal.z < 0
  f.pushpull(h.mm); g
end
opts = { 'front_normal' => [0, -1, 0], 'leg_height' => 0, 'ceiling_strip_height' => 0 }

# 1) Tủ ở cấp model: không có group cha
Sketchup.reset_model!
top = V::Geometry.cabinet_from_box(mk_box_in(Sketchup.active_model.entities, 1200, 500, 2000), opts)
shell = V::Geometry.shell_for(top)
check 'cấp model: world = root', same?(V::Operations.world_transform(top), top.transformation)
check 'cấp model: world có shell', same?(V::Operations.world_transform(top, shell), top.transformation * shell.transformation)

# 2) Tủ trong group cha dịch chuyển
Sketchup.reset_model!
parent = Sketchup.active_model.entities.add_group; parent.name = 'Cha'
parent.transformation = Geom::Transformation.translation(Geom::Vector3d.new(3000.mm, 1000.mm, 0))
cab = V::Geometry.cabinet_from_box(mk_box_in(parent.entities, 1200, 500, 2000), opts)
shell = V::Geometry.shell_for(cab)
check 'tủ nằm trong group cha', !cab.parent.is_a?(Sketchup::Model)
w = V::Operations.world_transform(cab)
check 'world = cha * root', same?(w, parent.transformation * cab.transformation), w.m.inspect
ws = V::Operations.world_transform(cab, shell)
check 'world+shell = cha * root * shell', same?(ws, parent.transformation * cab.transformation * shell.transformation)
# điểm thế giới -> tọa độ tủ rồi quay lại phải khớp
local = Geom::Point3d.new(100.mm, 200.mm, 300.mm)
back = local.transform(ws).transform(ws.inverse)
check 'khứ hồi điểm', (back - local).length < 1e-6

# 3) uv_at của công cụ Cánh với điểm ở thế giới
sel = Sketchup.active_model.selection; sel.clear; sel.add(cab)
tool = V::Tools.build('door', {}); tool.activate
rootv = tool.instance_variable_get(:@root); shellv = tool.instance_variable_get(:@shell)
if rootv && shellv
  b = V::Geometry.body_bounds(shellv)
  mid_local = Geom::Point3d.new((b.min.x + b.max.x) / 2, b.min.y, (b.min.z + b.max.z) / 2)
  mid_world = mid_local.transform(V::Operations.world_transform(rootv, shellv))
  u, v = tool.send(:uv_at, mid_world)
  check 'uv_at giữa mặt tủ trong group cha ≈ 0.5', (u - 0.5).abs < 0.05 && (v - 0.5).abs < 0.05, [u, v].inspect
else
  check 'Công cụ Cánh nhận tủ đang chọn', false, 'không có @root/@shell'
end

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.size}"
exit($fail.empty? ? 0 : 1)
