# Chạy: ruby test_mock.rb <đường dẫn thư mục runtime>
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
def raises?(klass = StandardError); yield; false; rescue klass => e; e.message; end
def mk_box(w, d, h, at = [0,0,0], parent_entities = nil)
  ents = parent_entities || Sketchup.active_model.entities
  g = ents.add_group; g.name = 'Box'
  x,y,z = at.map(&:mm)
  f = g.entities.add_face([[x,y,z],[x+w.mm,y,z],[x+w.mm,y+d.mm,z],[x,y+d.mm,z]])
  f.reverse! if f.normal.z < 0
  f.pushpull(h.mm); g
end
def tool_with(boxes, extra = {})
  m = Sketchup.active_model; m.selection.clear; boxes.each { |b| m.selection.add(b) }
  t = V::Tools::BoxTool.new(extra); t.activate; t
end
def click(tool, box, nrm, flags = 0, point = nil)
  view = Sketchup.active_model.active_view
  face = Sketchup::Face.new([Geom::Point3d.new(0,0,0), Geom::Point3d.new(1,0,0), Geom::Point3d.new(1,1,0)])
  # đặt pháp tuyến mong muốn bằng cách ghi đè
  face.define_singleton_method(:normal) { Geom::Vector3d.new(*nrm) }
  view.fake_path = [box, face]
  c = box.definition.bounds.center
  view.fake_point = point || Geom::Point3d.new(c.x + nrm[0]*1000, c.y + nrm[1]*1000, c.z + nrm[2]*1000)
  tool.onLButtonDown(flags, 10, 10, view)
end


def mk_face(pts)
  Sketchup.active_model.entities.add_face(pts.map { |p| p.map(&:mm) })
end
def empty_click(tool)
  view = Sketchup.active_model.active_view
  view.fake_path = []
  tool.onLButtonDown(0, 10, 10, view)
end
def space_key(tool)
  tool.onKeyDown(V::Keys::WINDOWS[:space], 0, 0, Sketchup.active_model.active_view)
end
def esc_key(tool)
  tool.onCancel(0, Sketchup.active_model.active_view)
end
def cabinets_in_model
  Sketchup.active_model.entities.to_a.select { |e| ModelData_ok(e) }
end
def ModelData_ok(e)
  V::ModelData.cabinet?(e)
end
V::Keys.platform = :windows

puts '== 1. Space: thoát về Chọn của SketchUp và tắt chế độ VGD Chọn =='
Sketchup.reset_model!
b1 = mk_box(600, 500, 800)
V.instance_variable_set(:@pick_mode, true)
t = tool_with([b1]); Sketchup.active_model.instance_variable_set(:@tool, t)
check 'đang ở lệnh Box', Sketchup.active_model.tool.equal?(t)
space_key(t)
check 'Space: không còn lệnh VGD', Sketchup.active_model.tool.nil?
check 'Space: VGD Chọn đã tắt (không bị bật lại)', !V.pick_active?

puts '== 2. Esc: lần 1 hủy bước đang chờ, lần 2 thoát =='
Sketchup.reset_model!
b1 = mk_box(600, 500, 800); b2 = mk_box(400, 500, 800, [1000, 0, 0])
t = tool_with([b1, b2]); Sketchup.active_model.instance_variable_set(:@tool, t); click(t, b1, [0, -1, 0])
esc_key(t)
check 'Esc lần 1: bỏ box đang chờ', t.hud_lines.first.include?('Box: 0'), t.hud_lines.first
check 'Esc lần 1: lệnh vẫn chạy', Sketchup.active_model.tool.equal?(t)
esc_key(t)
check 'Esc lần 2: thoát lệnh', Sketchup.active_model.tool.nil?

puts '== 3. Box: click vùng trống khi đã chọn đủ mặt = tạo tủ, lệnh vẫn chạy =='
Sketchup.reset_model!
b1 = mk_box(600, 500, 800)
t = tool_with([b1]); Sketchup.active_model.instance_variable_set(:@tool, t); click(t, b1, [0, -1, 0])
check 'đã chọn đủ mặt: sẵn sàng', t.ready?
empty_click(t)
check 'click vùng trống: tạo đúng 1 tủ', cabinets_in_model.length == 1, cabinets_in_model.length
check 'click vùng trống: lệnh vẫn chạy', Sketchup.active_model.tool.equal?(t)
check 'sau khi tạo: không còn box chờ', t.hud_lines.first.include?('Box: 0'), t.hud_lines.first

puts '== 4. Đợt/vách: chọn tủ xong không tô vàng; Esc hai bước =='
Sketchup.reset_model!
c = V::Geometry.cabinet_from_box(mk_box(600, 560, 2000), { 'front_normal' => [0, -1, 0] })
m = Sketchup.active_model; m.selection.clear; m.selection.add(c)
pt = V::Tools::PanelTool.new({}); pt.activate; m.instance_variable_set(:@tool, pt)
check 'đợt: nhận đúng tủ đang chọn', pt.instance_variable_get(:@root).equal?(c)
check 'đợt: bỏ chọn tủ (hết tô vàng)', m.selection.to_a.empty?
pt.onUserText('/2', Sketchup.active_model.active_view)
check 'đợt /2: đang chờ', pt.pending?
esc_key(pt)
check 'Esc lần 1: hủy bước chờ, lệnh vẫn chạy', !pt.pending? && m.tool.equal?(pt)
esc_key(pt)
check 'Esc lần 2: thoát lệnh', m.tool.nil?

puts '== 5. Sửa tủ: click bất kỳ = dựng lại, lệnh vẫn chạy =='
Sketchup.reset_model!
c = V::Geometry.cabinet_from_box(mk_box(600, 560, 2000), { 'front_normal' => [0, -1, 0] })
m = Sketchup.active_model; m.selection.clear; m.selection.add(c)
et = V::Tools::EditCabinetTool.new({}); m.select_tool(et)
check 'sửa tủ: sẵn sàng khi có tủ', et.ready?
et.update_settings(et.settings.merge('board_thickness' => 18.0))
check 'sửa tủ: có thay đổi chờ áp dụng', et.changed?
et.onLButtonDown(0, 5, 5, Sketchup.active_model.active_view)
check 'sửa tủ: click áp dụng, lệnh vẫn chạy', m.tool.equal?(et)
check 'sửa tủ: thay đổi đã áp dụng (hết chờ)', !et.changed?
check 'sửa tủ: tủ dày 18 mm', V::Rebuild.settings_of(c)['board_thickness'].to_f == 18.0, V::Rebuild.settings_of(c)['board_thickness'].inspect

puts '== 6. Mặt → ván: click vùng trống tạo ván, click face thêm/bỏ face =='
Sketchup.reset_model!
bf1 = mk_face([[20000, 0, 0], [20600, 0, 0], [20600, 400, 0], [20000, 400, 0]])
bf2 = mk_face([[21000, 0, 0], [21500, 0, 0], [21500, 300, 0], [21000, 300, 0]])
m = Sketchup.active_model; m.selection.clear; m.selection.add(bf1); m.selection.add(bf2)
UI.next_input = ['18', 'Theo pháp tuyến']
ft = V::Tools::FaceBoardTool.new({}); m.select_tool(ft)
check 'mặt: sẵn sàng sau khi nhập dày', ft.ready?
empty_click(ft)
boards = m.entities.to_a.select { |e| e.is_a?(Sketchup::Group) && e.name.to_s.start_with?('Ván ') }
check 'mặt: click vùng trống tạo 2 ván', boards.length == 2, boards.length
check 'mặt: lệnh vẫn chạy', m.tool.equal?(ft)
check 'mặt: danh sách face đã xóa', !ft.pending?
view = m.active_view; view.fake_path = [bf1]
ft.onLButtonDown(0, 5, 5, view)
check 'mặt: click face thêm vào danh sách', ft.pending? && ft.instance_variable_get(:@faces).length == 1
ft.onLButtonDown(0, 5, 5, view)
check 'mặt: click lại cùng face thì bỏ ra', !ft.pending?

puts '== 7. Cánh lọt: vách lùi mặt trước đúng bằng dày cánh như đợt =='
v = Sketchup.active_model.active_view
Sketchup.reset_model!
c = V::Geometry.cabinet_from_box(mk_box(600, 560, 2000), { 'front_normal' => [0, -1, 0] })
m = Sketchup.active_model; m.selection.clear; m.selection.add(c)
pt = V::Tools::PanelTool.new({ 'panel_door_fit' => 'lot', 'panel_axis' => 'vertical' }); pt.activate
pt.onUserText('/2', v); pt.commit(v)
shell = V::Geometry.shell_for(c)
walls = shell.definition.entities.to_a.select { |e| e.respond_to?(:name) && e.name.to_s.start_with?('Vách') }
check 'lọt: có vách được tạo', walls.length == 1, walls.length
front = walls.first && walls.first.bounds.min.y.to_mm
check 'lọt: mặt trước vách lùi đúng dày cánh 17.5 mm', front && (front - 17.5).abs < 1e-6, front.inspect
pt2 = V::Tools::PanelTool.new({ 'panel_door_fit' => 'phu', 'panel_axis' => 'vertical' }); m.selection.clear; m.selection.add(c); pt2.activate
c2 = V::Geometry.cabinet_from_box(mk_box(600, 560, 2000, [4000, 0, 0]), { 'front_normal' => [0, -1, 0] })
m.selection.clear; m.selection.add(c2); pt2.activate
pt2.onUserText('/2', v); pt2.commit(v)
w2 = V::Geometry.shell_for(c2).definition.entities.to_a.select { |e| e.respond_to?(:name) && e.name.to_s.start_with?('Vách') }
check 'phủ: vách không lùi (mặt trước = 0)', w2.length == 1 && (w2.first.bounds.min.y.to_mm).abs < 1e-6, w2.first && w2.first.bounds.min.y.to_mm.inspect

puts '== 8. Tạo vách/đợt TRƯỚC, chốt cánh lọt SAU: vách và đợt phải lùi đúng dày cánh =='
Sketchup.reset_model!
c = V::Geometry.cabinet_from_box(mk_box(600, 560, 2000), { 'front_normal' => [0, -1, 0] })
m = Sketchup.active_model; m.selection.clear; m.selection.add(c)
pt = V::Tools::PanelTool.new({ 'panel_axis' => 'vertical' }); pt.activate
pt.onUserText('/2', v); pt.commit(v)
pt2 = V::Tools::PanelTool.new({ 'panel_axis' => 'horizontal' }); reselect_c = m.selection.clear; m.selection.add(c); pt2.activate
pt2.onUserText('/2', v); pt2.commit(v)
dl = V::Tools::DoorTool.new({ 'door_fit' => 'lot' }); m.selection.clear; m.selection.add(c); dl.activate; dl.commit(v)
shell = V::Geometry.shell_for(c)
walls = shell.definition.entities.to_a.select { |e| e.respond_to?(:name) && e.name.to_s.start_with?('Vách') }
shelves = shell.definition.entities.to_a.select { |e| e.respond_to?(:name) && e.name.to_s.start_with?('Đợt') }
check 'sau khi chốt cánh lọt: vách lùi đúng 17.5 mm', walls.length == 1 && (walls.first.bounds.min.y.to_mm - 17.5).abs < 1e-6, walls.map { |w| w.bounds.min.y.to_mm }.inspect
check 'sau khi chốt cánh lọt: đợt lùi đúng 17.5 + 20 mm', shelves.length >= 1 && shelves.all? { |s| (s.bounds.min.y.to_mm - 37.5).abs < 1e-6 }, shelves.map { |s| s.bounds.min.y.to_mm }.inspect

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.length}"
$fail.each { |f| puts "  - #{f}" }
