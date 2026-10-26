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

# --- 1. Keys ---
V::Keys.platform = :windows
check 'keys tab', V::Keys.tab?(9) && !V::Keys.tab?(13)
check 'keys backspace', V::Keys.backspace?(8)
check 'keys enter/esc', V::Keys.enter?(13) && V::Keys.escape?(27)
# --- 2. Schema / ModelData ---
s = V::Schema.merge_settings({'back_thickness' => nil, 'panels' => {'top' => {'enabled' => false}}})
check 'merge nil default', s['back_thickness'] == 6.0
check 'merge deep panels', s['panels']['top']['enabled'] == false && s['panels']['bottom']['enabled'] == true
check 'defaults not mutated', V::Schema::DEFAULTS['panels']['top']['enabled'] == true
e = Sketchup::Group.new(Sketchup.active_model.entities)
V::ModelData.stamp(e, 'cabinet', {'a' => 1}); id1 = V::ModelData.id_for(e)
V::ModelData.stamp(e, 'cabinet', {'a' => 2})
check 'stable id', id1 && id1 == V::ModelData.id_for(e)
check 'revision increments', e.get_attribute('VGD_Cabinet_Draw','revision') == 2
snap = V::ModelData.snapshot(e); e2 = Sketchup::Group.new(Sketchup.active_model.entities)
V::ModelData.restore(e2, snap); V::ModelData.new_id!(e2)
check 'restore + new id', V::ModelData.cabinet?(e2) && V::ModelData.id_for(e2) != id1
# --- 3. Geometry ---
box = mk_box(800, 500, 2000)
root = V::Geometry.cabinet_from_box(box, {'front_normal' => [0,-1,0], 'remove_source' => true})
check 'box erased', box.erased?
check 'root is cabinet', V::ModelData.cabinet?(root)
shell = V::Geometry.shell_for(root)
check 'shell found', !shell.nil?
check 'parts 5', shell.entities.to_a.length == 5, shell.entities.to_a.length
p0 = V::ModelData.params(root)
check 'params width', (p0['width_mm'] - 800).abs < 0.01 && (p0['height_mm'] - 2000).abs < 0.01, p0.inspect[0,120]
check 'default back 6', p0['back_thickness'] == 6.0
V::Geometry.share_components(root)
parts = V::Geometry.shell_for(root).definition.entities.to_a rescue shell.entities.to_a
shell = V::Geometry.shell_for(root)
sd = shell.respond_to?(:definition) ? shell.definition.entities : shell.entities
roles = sd.to_a.map { |x| V::ModelData.params(x)['role'] }.sort
check 'roles kept after sharing', roles == %w[back bottom side_left side_right top], roles.inspect
ids = sd.to_a.map { |x| V::ModelData.id_for(x) }
check 'ids unique after sharing', ids.compact.uniq.length == ids.length && !ids.include?(nil), ids.inspect
# nested parent
outer = Sketchup.active_model.entities.add_group
inner = mk_box(600, 400, 700, [0,0,0], outer.entities)
r2 = V::Geometry.cabinet_from_box(inner, {'front_normal' => [0,-1,0]})
check 'nested root in parent group', outer.entities.to_a.include?(r2) && !Sketchup.active_model.entities.to_a.include?(r2)
# box bị scale: dựng đúng kích thước thật, ván không méo
sb = mk_box(500, 500, 500, [8000, 0, 0]); sb.transformation = Geom::Transformation.new([[2,0,0],[0,1.5,0],[0,0,1],[8000.mm,0,0]])
sroot = V::Geometry.cabinet_from_box(sb, {'front_normal' => [0,-1,0], 'leg_height' => 0, 'ceiling_strip_height' => 0})
sdata = V::ModelData.params(sroot)
check 'scale: kích thước thật 1000 x 750 x 500', [sdata['width_mm'], sdata['depth_mm'], sdata['height_mm']].map { |n| n.round(3) } == [1000.0, 750.0, 500.0], [sdata['width_mm'], sdata['depth_mm'], sdata['height_mm']].inspect
check 'scale: tủ không bị scale', [sroot.transformation.xscale, sroot.transformation.yscale, sroot.transformation.zscale].all? { |n| (n - 1).abs < 1e-9 }
sshell = V::Geometry.shell_for(sroot)
side_l = sshell.definition.entities.to_a.find { |e| e.name == 'Hông Trái' }
check 'scale: hông dày đúng 17.5 (không méo)', (side_l.definition.bounds.width.to_mm - 17.5).abs < 1e-6, side_l.definition.bounds.width.to_mm
check 'scale: thùng tủ bao đúng kích thước box', (sshell.definition.bounds.width.to_mm - 1000).abs < 1e-6 && (sshell.definition.bounds.depth.to_mm - 750).abs < 1e-6 && (sshell.definition.bounds.height.to_mm - 500).abs < 1e-6
check 'scale: box gốc không bị đụng khi giữ lại', (sb2 = mk_box(400, 400, 400, [9000, 0, 0]); sb2.transformation = Geom::Transformation.new([[1,0,0],[0,1,0],[0,0,2],[9000.mm,0,0]]); r = V::Geometry.cabinet_from_box(sb2, {'front_normal' => [0,-1,0], 'remove_source' => false}); !sb2.erased? && (V::ModelData.params(r)['height_mm'] - 800).abs < 1e-6)
check 'scale: preview báo ok với box scale', (pv_s = V::Preview.new; V::Geometry.preview_cabinet(sb, [0,-1,0], {}, pv_s).nil? && pv_s.polygon_count > 0)
# xoay 90° quanh Z + scale: kích thước thật đúng, hướng giữ
rs = mk_box(500, 500, 500, [0, 0, 0]); rs.transformation = Geom::Transformation.new([[0,2,0],[-1,0,0],[0,0,1],[0,0,0]])
rroot = V::Geometry.cabinet_from_box(rs, {'front_normal' => [0,-1,0], 'leg_height' => 0, 'ceiling_strip_height' => 0})
rd = V::ModelData.params(rroot)
check 'scale + xoay: kích thước thật', [rd['width_mm'], rd['depth_mm']].map { |n| n.round(3) } == [1000.0, 500.0], [rd['width_mm'], rd['depth_mm']].inspect
check 'scale + xoay: tủ không scale', (rroot.transformation.xscale - 1).abs < 1e-9 && (rroot.transformation.yscale - 1).abs < 1e-9
# xiên (shear) và lật gương bị từ chối, không đụng model
shr = mk_box(300, 300, 300, [0, 3000, 0]); shr.transformation = Geom::Transformation.new([[1,0,0],[1,1,0],[0,0,1],[0,0,0]])
n_before_shear = Sketchup.active_model.entities.to_a.length
msg = raises?(ArgumentError) { V::Geometry.cabinet_from_box(shr, {'front_normal' => [0,-1,0]}) }
check 'box bị xiên bị từ chối', msg && msg.include?('xiên'), msg.inspect
mir = mk_box(300, 300, 300, [0, 4000, 0]); mir.transformation = Geom::Transformation.new([[-1,0,0],[0,1,0],[0,0,1],[0,0,0]])
msg = raises?(ArgumentError) { V::Geometry.cabinet_from_box(mir, {'front_normal' => [0,-1,0]}) }
check 'box bị lật gương bị từ chối', msg && msg.include?('lật gương'), msg.inspect
zero = mk_box(300, 300, 300, [0, 5000, 0]); zero.transformation = Geom::Transformation.new([[1,0,0],[0,0,0],[0,0,1],[0,0,0]])
msg = raises?(ArgumentError) { V::Geometry.cabinet_from_box(zero, {'front_normal' => [0,-1,0]}) }
check 'box scale 0 bị từ chối', msg && msg.include?('bằng 0'), msg.inspect
# top face as front
msg = raises?(ArgumentError) { V::Geometry.horizontal_front([0,0,1]) }
check 'top front rejected', msg && msg.include?('mặt đứng')
# tiny box → error before touching the model
n0 = Sketchup.active_model.entities.to_a.length
tiny = mk_box(10, 10, 10); n1 = Sketchup.active_model.entities.to_a.length
msg = raises?(ArgumentError) { V::Geometry.cabinet_from_box(tiny, {'front_normal' => [0,-1,0]}) }
check 'tiny box rejected', !msg.nil? && msg != false, msg.inspect
check 'tiny box no new entities', Sketchup.active_model.entities.to_a.length == n1
# rotated box: front vector in local; origin check
rb = mk_box(600, 300, 500)
# --- 4. BoxTool ---
Sketchup.reset_model!
b1 = mk_box(600, 500, 800); b2 = mk_box(400, 500, 800, [1000,0,0])
t = tool_with([b1, b2])
check 'preselected state', t.state == :pick_front
click(t, b1, [0,-1,0])
check 'sync fronts → preview', t.state == :preview, t.state
click(t, b1, [0,0,1])   # top face rejected
check 'top click keeps state', t.state == :preview
hud = t.hud_lines
check 'hud lines', hud.any? { |l| l.include?('2/2') } && hud.any? { |l| l.include?('âm 4 cạnh') }, hud.inspect
v = Sketchup.active_model.active_view
check 'tab reverses all', (t.onKeyDown(9, 0, 0, v); true)
t.onKeyDown(9, 0, 0, v) # back
# draw doesn't crash
t.draw(v); check 'draw ok', true
# shift override
click(t, b2, [0,-1,0], V::Keys.respond_to?(:shift?) ? CONSTRAIN_MODIFIER_MASK : 0)
check 'override registered', t.hud_lines.any? { |l| l.include?('Cấu hình riêng: 1') }, t.hud_lines.inspect
t.update_settings({'back_mode' => 'overlay', 'back_thickness' => 8})
check 'override holds own settings', t.instance_variable_get(:@overrides).values.first['back_mode'] == 'overlay'
check 'global unchanged', t.settings['back_mode'] == 'groove'
# backspace removes last
t.onKeyDown(8, 0, 0, v)
check 'backspace removes box', t.hud_lines.first.include?('Box: 1'), t.hud_lines.first
# commit one
t2 = tool_with([b1]); click(t2, b1, [0,-1,0])
n = Sketchup.active_model.ops.length
t2.commit(v)
ops = Sketchup.active_model.ops[n..-1].map(&:first)
check 'single undo op', ops == [:start, :commit], ops.inspect
check 'source removed, root selected', b1.erased? && Sketchup.active_model.selection.length == 1
# commit with missing front aborts clean
b3 = mk_box(500,500,500); t3 = tool_with([b3]); t3.commit(v)
check 'missing front not built', !b3.erased?
# enter / esc
check 'enableVCB', t3.enableVCB? == true
t3.onCancel(0, v); check 'esc deselects tool', Sketchup.active_model.tool.nil?
# two boxes, override with overlay, commit
Sketchup.reset_model!
c1 = mk_box(600,500,800); c2 = mk_box(600,500,800,[1000,0,0])
t4 = tool_with([c1,c2]); click(t4, c1, [0,-1,0]); click(t4, c2, [0,-1,0], CONSTRAIN_MODIFIER_MASK)
t4.commit(Sketchup.active_model.active_view)
roots = Sketchup.active_model.selection.to_a
check 'two cabinets created', roots.length == 2, roots.length
modes = roots.map { |r| V::ModelData.params(r)['back_mode'] }
check 'both cabinets get a config', modes.all?, modes.inspect
check 'no new group erased inside operation', $erased_new == 0, $erased_new
# observer của plugin khác ném lỗi lúc commit: không được abort
Sketchup.reset_model!
d1 = mk_box(600,500,800); t5 = tool_with([d1]); click(t5, d1, [0,-1,0])
$observer_fails = true; n = Sketchup.active_model.ops.length
t5.commit(Sketchup.active_model.active_view); $observer_fails = false
check 'commit error does not abort', !Sketchup.active_model.ops[n..-1].any? { |o| o.first == :abort }, Sketchup.active_model.ops[n..-1].inspect
check 'cabinet still selected after observer error', Sketchup.active_model.selection.length == 1

# --- 3b. DoorGeometry.parts / DoorTool / OpeningTool ---
Sketchup.reset_model!
base = {'board_thickness' => 17.5}
bnd = {x0: 0.0, x1: 400.mm, z0: 0.0, z1: 700.mm, y: -1.mm}
check 'parts flat = 1', V::DoorGeometry.parts(bnd, base.merge('door_style' => 'flat')).length == 1
check 'parts shaker = 5', V::DoorGeometry.parts(bnd, base.merge('door_style' => 'shaker')).length == 5
glass = V::DoorGeometry.parts(bnd, base.merge('door_style' => 'glass', 'glass_rows' => 2, 'glass_columns' => 2))
check 'parts glass = 4+4+3 (đố ngang chia đoạn)', glass.length == 11 && glass.count { |p| p[:kind] == :glass } == 4, glass.length
sh = V::DoorGeometry.parts(bnd, base.merge('door_style' => 'shaker')).last
check 'panel flush with door back', (sh[:y] - bnd[:y]).abs < 1e-9 && (sh[:depth].to_mm - 9.5).abs < 1e-6, [sh[:y], sh[:depth].to_mm].inspect
gl = glass.find { |p| p[:kind] == :glass }
mid = (gl[:y] + (gl[:y] - gl[:depth])) / 2
check 'glass centred in door thickness', (mid - (bnd[:y] - 17.5.mm / 2)).abs < 1e-9
check 'narrow frame error', raises?(StandardError) { V::DoorGeometry.parts({x0: 0.0, x1: 100.mm, z0: 0.0, z1: 700.mm, y: 0.0}, base.merge('door_style' => 'shaker')) }
cb = mk_box(1200, 500, 2000)
cab = V::Geometry.cabinet_from_box(cb, {'front_normal' => [0,-1,0]})
v = Sketchup.active_model.active_view
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(cab)
dt = V::Tools::DoorTool.new({}); dt.activate
check 'door tool takes preselected cabinet', dt.instance_variable_get(:@root) == cab
dt.onUserText('/3', v)
check 'door hud 3 cells', dt.hud_lines.first.include?('Cánh: 3'), dt.hud_lines.inspect
check 'door hud sizes in mm', dt.hud_lines.any? { |l| l =~ /Cánh 1: 400 × 1940 mm/ }, dt.hud_lines.inspect
pv = dt.instance_variable_get(:@preview)
check 'preview 3 doors x 6 faces', pv.polygon_count == 18, pv.polygon_count
v.fake_path = [cab]; v.fake_point = Geom::Point3d.new(300.mm, -10.mm, 1000.mm)
dt.onMouseMove(0, 5, 5, v)
check 'hover adds split preview', dt.instance_variable_get(:@preview).polygon_count > 18, dt.instance_variable_get(:@preview).polygon_count
check 'hover hud 4 doors', dt.hud_lines.first.include?('Cánh: 4'), dt.hud_lines.first
v.fake_point = Geom::Point3d.new(400.mm, -10.mm, 1000.mm)
dt.onMouseMove(CONSTRAIN_MODIFIER_MASK, 5, 5, v)
check 'shift hover: không gợi ý đường chia, chỉ tô vùng', dt.instance_variable_get(:@hover_split).nil? && dt.hud_lines.first.include?('Cánh: 3') && dt.instance_variable_get(:@preview).polygon_count == 24, [dt.hud_lines.first, dt.instance_variable_get(:@preview).polygon_count].inspect
dt.draw(v); check 'door draw ok', true
dt.onMouseMove(0, 5, 5, v); v.fake_point = Geom::Point3d.new(1.mm, -10.mm, 1000.mm)
dt.update_settings({'door_style' => 'glass', 'glass_rows' => 1, 'glass_columns' => 1, 'door_gap' => 3})
check 'update_settings keeps axis & rebuilds', dt.instance_variable_get(:@settings)['split_axis'] == 'vertical' && dt.instance_variable_get(:@error).nil?, dt.instance_variable_get(:@error)
dt.commit(v)
doors = V::Operations.doors_of(cab)
check 'commit made 3 glass doors', doors.length == 3, doors.length
cont = cab.definition.entities.to_a.find { |e| e.name == 'Cánh' }
check 'doors live in group Cánh, not loose in cabinet', cont && cont.entities.to_a.count { |e| e.name.to_s.start_with?('Cánh Draw') } == 3 && cab.definition.entities.to_a.none? { |e| e.name.to_s.start_with?('Cánh Draw') }
check 'container is a Group (no component)', cont.is_a?(Sketchup::Group) && doors.all? { |d| d.is_a?(Sketchup::Group) }
check 'door layout saved', cab.get_attribute('VGD_Cabinet_Draw', 'door_layout_json').to_s.include?('regions')
# hover-select cabinet when nothing selected
Sketchup.active_model.selection.clear
dt2 = V::Tools::DoorTool.new({}); dt2.activate
check 'no selection → no root', dt2.instance_variable_get(:@root).nil?
v.fake_path = [cab]; dt2.onMouseMove(0, 5, 5, v)
check 'hover cabinet outline', dt2.instance_variable_get(:@preview).polygon_count > 0
dt2.onLButtonDown(0, 5, 5, v); check 'click selects cabinet', dt2.instance_variable_get(:@root) == cab
# gap chỉ nằm giữa các cánh
gt = V::Tools::DoorTool.new({'door_gap' => 4, 'split_axis' => 'vertical'})
sb = V::Geometry.shell_for(cab).definition.bounds
lay_v = V::DoorLayout::Layout.new; lay_v.split(1, 'vertical', 0.5)
cs = gt.cells(sb, lay_v)
check 'outer edges flush (vertical split)', (cs.first[:x0] - sb.min.x).abs < 1e-9 && (cs.last[:x1] - sb.max.x).abs < 1e-9 && (cs.first[:z0] - sb.min.z).abs < 1e-9 && (cs.first[:z1] - sb.max.z).abs < 1e-9
check 'gap only between doors', ((cs[1][:x0] - cs[0][:x1]).to_mm - 4).abs < 1e-6, (cs[1][:x0] - cs[0][:x1]).to_mm
gt2 = V::Tools::DoorTool.new({'door_gap' => 4}); gt2.settings['split_axis'] = 'horizontal'
lay_h = V::DoorLayout::Layout.new; lay_h.split(1, 'horizontal', 0.5)
cs2 = gt2.cells(sb, lay_h)
check 'horizontal split full width & height', (cs2.first[:x0] - sb.min.x).abs < 1e-9 && (cs2.first[:x1] - sb.max.x).abs < 1e-9 && (cs2.first[:z0] - sb.min.z).abs < 1e-9 && (cs2.last[:z1] - sb.max.z).abs < 1e-9
# chia lại thay cánh cũ, không nhân đôi
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(cab)
dt3 = V::Tools::DoorTool.new({}); dt3.activate; dt3.onUserText('/2', v); dt3.commit(v)
check 're-split replaces old doors', V::Operations.doors_of(cab).length == 2, V::Operations.doors_of(cab).length
doors = V::Operations.doors_of(cab)
# --- opening tool: góc theo chuột ---
cont = cab.definition.entities.to_a.find { |e| e.name == 'Cánh' }
d0 = doors.first
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(d0)
ot = V::Tools::OpeningTool.new({}); ot.activate
check 'opening takes preselected door', ot.instance_variable_get(:@targets) == [d0]
pt_before = V::Operations.hinge_pivot(d0, 'left')
db_before = V::Operations.door_bounds(d0)
v.fake_path = [cab, cont, d0]
ot.onMouseMove(0, 100, 5, v)
ot.onMouseMove(0, 100 + 90 * 3, 5, v)
check 'mouse x → 90°', (ot.instance_variable_get(:@angle) - 90).abs < 1e-6, ot.instance_variable_get(:@angle)
ot.onMouseMove(CONSTRAIN_MODIFIER_MASK, 100 + 37 * 3, 5, v)
check 'shift snaps 15°', ot.instance_variable_get(:@angle) == 30.0, ot.instance_variable_get(:@angle)
check 'preview has arc + faces', ot.instance_variable_get(:@preview).polygon_count == 12 && !ot.instance_variable_get(:@preview).empty?
ot.onMouseMove(0, 100 + 90 * 3, 5, v)
ot.draw(v); check 'opening draw ok', true
ot.onLButtonDown(0, 5, 5, v)
check 'click applies 90°', V::Operations.door_angle(d0) == 90.0, V::Operations.door_angle(d0)
pt_after = V::Operations.hinge_pivot(d0, 'left')
check 'hinge point fixed while rotating', (pt_after - pt_before).length < 1e-6, (pt_after - pt_before).length
check 'door really rotated', (d0.transformation.m[0][1]).abs > 0.9, d0.transformation.m[0].inspect
marker = d0.definition.entities.to_a.find { |e| e.name == 'Ký Hiệu Hướng Mở' }
check 'marker exists inside door', marker && marker.entities.to_a.length > 4, marker && marker.entities.to_a.length
check 'marker is on door front face', marker.entities.to_a.all? { |e| (e.a.y - (V::Operations.door_bounds(d0)[1] - 0.5.mm)).abs < 1e-6 }
apex_pts = marker.entities.to_a.flat_map { |e| [e.a, e.b] }
db = V::Operations.door_bounds(d0)
check 'marker apex at hinge side mid-height', apex_pts.any? { |p| (p.x - db[0]).abs < 1e-6 && (p.z - (db[2] + db[5]) / 2).abs < 1e-6 }
# Nét đứt: điểm cuối cùng nằm trong một nét đứt (28 mm) tính từ góc, nên so với dung sai 28 mm.
check 'marker corners at free side', apex_pts.any? { |p| (p.x - db[3]).abs < 29.mm && (p.z - db[5]).abs < 29.mm } && apex_pts.any? { |p| (p.x - db[3]).abs < 29.mm && (p.z - db[2]).abs < 29.mm }
check 'door_bounds ignores marker', db == db_before, [db, db_before].inspect
check 'sau khi chốt, không còn cánh đang chỉnh', ot.instance_variable_get(:@targets).empty?
ot.onLButtonDown(0, 5, 5, v)
check 'click lại chọn cánh', ot.instance_variable_get(:@targets) == [d0]
ot.onUserText('45', v)
check 'typed 45°', V::Operations.door_angle(d0) == 45.0
ot.onLButtonDown(0, 5, 5, v)
ot.onUserText('0', v)
check 'typed 0 closes', V::Operations.door_angle(d0) == 0.0 && (d0.transformation.m[0][0] - 1).abs < 1e-6, d0.transformation.m.inspect
check 'hinge still fixed after close', (V::Operations.hinge_pivot(d0, 'left') - pt_before).length < 1e-6
ot.onLButtonDown(0, 5, 5, v)
ot.onUserText('abc', v); check 'bad text leaves door untouched', V::Operations.door_angle(d0) == 0.0
# tool selected via mouse when nothing preselected
Sketchup.active_model.selection.clear
ot2 = V::Tools::OpeningTool.new({}); ot2.activate
ot2.onMouseMove(0, 5, 5, v); check 'hover-only preview', ot2.instance_variable_get(:@preview).polygon_count == 12
ot2.onLButtonDown(0, 5, 5, v); check 'click adds target', ot2.instance_variable_get(:@targets) == [d0]
check 'parent transform from pick', ot2.instance_variable_get(:@parent_transforms)[d0]
# parent_transform tìm từ model
pf = V::Operations.parent_transform(d0)
check 'parent_transform lookup', pf && (0..2).all? { |i| (pf.m[3][i] - (cab.transformation * cont.transformation).m[3][i]).abs < 1e-6 }, pf.inspect
# --- Mở cánh: mỗi cánh một góc ---
d1 = doors.last
check 'có hai cánh để thử', doors.length == 2 && d0 != d1
V::Operations.set_door_angle(d0, 'left', 0); V::Operations.set_door_angle(d1, 'right', 0)
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(d0); Sketchup.active_model.selection.add(d1)
oq = V::Tools::OpeningTool.new({}); oq.activate
check 'hàng chờ: cánh đầu đang chỉnh, cánh sau chờ', oq.instance_variable_get(:@targets) == [d0] && oq.instance_variable_get(:@queue) == [d1]
check 'preview có cánh chờ (xanh lá)', oq.instance_variable_get(:@preview).polygon_count >= 12 + 6
check 'hud báo còn chờ', oq.hud_lines.first.include?('Còn chờ: 1')
v.fake_path = [cab, cont, d0]
oq.onMouseMove(0, 100, 5, v); oq.onMouseMove(0, 100 + 60 * 3, 5, v)
oq.onLButtonDown(0, 5, 5, v)
check 'cánh 1 mở 60°, cánh 2 chưa đổi', V::Operations.door_angle(d0) == 60.0 && V::Operations.door_angle(d1) == 0.0
check 'tự chuyển sang cánh 2', oq.instance_variable_get(:@targets) == [d1] && oq.instance_variable_get(:@queue).empty?
v.fake_path = [cab, cont, d1]
oq.onMouseMove(0, 400, 5, v); oq.onMouseMove(0, 400 + 30 * 3, 5, v)
check 'góc chuột bắt đầu từ góc hiện tại của cánh 2 (không nhảy)', (oq.instance_variable_get(:@angle) - 30).abs < 1e-6, oq.instance_variable_get(:@angle)
oq.onLButtonDown(0, 5, 5, v)
check 'mỗi cánh một góc riêng', V::Operations.door_angle(d0) == 60.0 && V::Operations.door_angle(d1) == 30.0, [V::Operations.door_angle(d0), V::Operations.door_angle(d1)].inspect
check 'hết hàng chờ: không cánh nào đang chỉnh', oq.instance_variable_get(:@targets).empty?
check 'bản lề phải lưu cho cánh 2', d1.get_attribute('VGD_Cabinet_Draw', 'opening_side') == 'right'
# Ctrl+click gom nhóm dùng chung một góc
V::Operations.set_door_angle(d0, 'left', 0); V::Operations.set_door_angle(d1, 'right', 0)
Sketchup.active_model.selection.clear
og = V::Tools::OpeningTool.new({}); og.activate
v.fake_path = [cab, cont, d0]; og.onLButtonDown(COPY_MODIFIER_MASK, 5, 5, v)
v.fake_path = [cab, cont, d1]; og.onLButtonDown(COPY_MODIFIER_MASK, 5, 5, v)
check 'Ctrl+click gom 2 cánh', og.instance_variable_get(:@targets) == [d0, d1]
og.onMouseMove(0, 100, 5, v); og.onMouseMove(0, 100 + 45 * 3, 5, v)
v.fake_path = [cab, cont, d0]; og.onLButtonDown(0, 5, 5, v)
check 'nhóm dùng chung một góc 45°', V::Operations.door_angle(d0) == 45.0 && V::Operations.door_angle(d1) == 45.0
v.fake_path = [cab, cont, d1]; og.onLButtonDown(COPY_MODIFIER_MASK, 5, 5, v); og.onLButtonDown(COPY_MODIFIER_MASK, 5, 5, v)
check 'Ctrl+click lần hai bỏ cánh khỏi nhóm', og.instance_variable_get(:@targets).empty?
# Click sang cánh khác khi đang chỉnh: chốt cánh cũ rồi chọn cánh mới
V::Operations.set_door_angle(d0, 'left', 0); V::Operations.set_door_angle(d1, 'right', 0)
oc = V::Tools::OpeningTool.new({}); oc.activate
v.fake_path = [cab, cont, d0]; oc.onLButtonDown(0, 5, 5, v)
oc.onMouseMove(0, 100, 5, v); oc.onMouseMove(0, 100 + 20 * 3, 5, v)
v.fake_path = [cab, cont, d1]; oc.onLButtonDown(0, 5, 5, v)
check 'click cánh khác: chốt cánh cũ', V::Operations.door_angle(d0) == 20.0
check 'click cánh khác: chọn cánh mới', oc.instance_variable_get(:@targets) == [d1]
# Esc: lần 1 bỏ chọn, lần 2 thoát
oc.cancel_tool(v); check 'Esc lần 1 bỏ cánh đang chỉnh, không đổi model', oc.instance_variable_get(:@targets).empty? && V::Operations.door_angle(d1) == 0.0
Sketchup.active_model.select_tool(oc)
oc.cancel_tool(v); check 'Esc lần 2 thoát công cụ', Sketchup.active_model.tool.nil?
# Enter khi không có cánh đang chỉnh: kết thúc
oe = V::Tools::OpeningTool.new({}); Sketchup.active_model.select_tool(oe); oe.activate
oe.commit(v); check 'Enter không có cánh: kết thúc công cụ', Sketchup.active_model.tool.nil?
# Click vào chỗ trống khi chưa chọn cánh nào: không làm gì
V::Operations.set_door_angle(d0, 'left', 0)
ox = V::Tools::OpeningTool.new({}); ox.activate; v.fake_path = []
ox.onLButtonDown(0, 5, 5, v); check 'click trống khi chưa chọn: không chọn gì', ox.instance_variable_get(:@targets).empty?
# Click vào chỗ trống khi đang chỉnh: chốt cánh đang chỉnh
v.fake_path = [cab, cont, d0]; ox.onLButtonDown(0, 5, 5, v)
ox.onMouseMove(0, 100, 5, v); ox.onMouseMove(0, 100 + 10 * 3, 5, v)
v.fake_path = []; ox.onLButtonDown(0, 5, 5, v)
check 'click trống khi đang chỉnh: chốt góc', V::Operations.door_angle(d0) == 10.0 && ox.instance_variable_get(:@targets).empty?
# --- PanelTool (beta.28): rê → khóa mặt → kéo → Tab điểm bắt → gõ mm → click tạo; /n chia cả ô ---
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(cab)
pt = V::Tools::PanelTool.new({}); pt.activate
check 'panel takes preselected cabinet', pt.instance_variable_get(:@root) == cab
shell_c = V::Geometry.shell_for(cab)
part_of = ->(name) { shell_c.definition.entities.to_a.find { |e| e.name == name } }
vach = -> { V::Operations.shell_for(cab).definition.entities.to_a.select { |e| e.name.start_with?('Vách') } }
dot = -> { V::Operations.shell_for(cab).definition.entities.to_a.select { |e| e.name.start_with?('Đợt') } }
v.fake_path = [cab]; v.fake_point = Geom::Point3d.new(600.mm, -10.mm, 1000.mm)
pt.onMouseMove(0, 5, 5, v)
check 'rê vào thân tủ (không trúng tấm): không có mặt tham chiếu', pt.instance_variable_get(:@hover).nil?
check 'hud: hướng dẫn rê vào tấm', pt.hud_lines.any? { |l| l.include?('Rê vào hông') }, pt.hud_lines.inspect
v.fake_path = [cab, shell_c, part_of.call('Hông Trái')]; v.fake_point = Geom::Point3d.new(600.mm, -10.mm, 1000.mm)
pt.onMouseMove(0, 5, 5, v)
check 'rê vào hông trái: mặt tham chiếu = vách đứng', pt.instance_variable_get(:@hover)[:axis] == 'vertical'
check 'rê vào hông: chỉ tô sáng đúng mặt tham chiếu (1 polygon, không phủ cả tủ)', pt.instance_variable_get(:@preview).polygon_count == 1, pt.instance_variable_get(:@preview).polygon_count
check 'panel_axis_at: hông trái → vertical', pt.panel_axis_at(v, 5, 5) == 'vertical'
v.fake_path = [cab, shell_c, part_of.call('Nóc')]; pt.onMouseMove(0, 5, 5, v)
check 'rê vào nóc: mặt tham chiếu = đợt ngang, hướng xuống', pt.instance_variable_get(:@hover)[:axis] == 'horizontal' && pt.instance_variable_get(:@hover)[:dir] == -1
v.fake_path = [cab, shell_c, part_of.call('Đáy')]; pt.onMouseMove(0, 5, 5, v)
check 'panel_axis_at: đáy → horizontal', pt.panel_axis_at(v, 5, 5) == 'horizontal'
v.fake_path = [cab, shell_c, part_of.call('Hậu')]; pt.onMouseMove(0, 5, 5, v)
check 'rê vào hậu: không khóa được mặt', pt.instance_variable_get(:@hover).nil?
v.fake_path = [cab, shell_c, part_of.call('Hông Trái')]; v.fake_point = Geom::Point3d.new(600.mm, -10.mm, 1000.mm); pt.onMouseMove(0, 5, 5, v)

# Số học ba kiểu chia (lối tắt /n, chia cả ô của hông trái — chưa có vách nào)
bounds = shell_c.definition.bounds
t = pt.thickness
inner0 = bounds.min.x + t; inner1 = bounds.max.x - t
pt.onUserText('/4', v)
check 'khung kích thước: /4 → 4 khoang', pt.instance_variable_get(:@preview).text_count == 4, pt.instance_variable_get(:@preview).text_count
tt = pt.kind; ps = pt.send(:planned_positions)
cells = ([inner0] + ps.sort.flat_map { |p| [p, p + t] } + [inner1]).each_slice(2).map { |f, e| (e - f).to_mm }
check 'thông thủy: 4 ô trống bằng nhau', ps.length == 3 && cells.length == 4 && cells.max - cells.min < 1e-6, cells.inspect
pt.onKeyDown(9, 0, 0, v)
ps = pt.send(:planned_positions).sort
cells = ([inner0] + ps.flat_map { |p| [p, p + t] } + [inner1]).each_slice(2).map { |f, e| (e - f).to_mm }
check 'lọt lòng: tấm đặt giữa ranh giới chia đều lòng tủ', ps.each_with_index.all? { |p, i| ((p + t / 2) - (inner0 + (inner1 - inner0) * (i + 1) / 4)).abs < 1e-6 }
check 'lọt lòng: ô ngoài rộng hơn ô trong nửa dày tấm', (cells[0] - cells[1] - t.to_mm / 2).abs < 1e-6, cells.inspect
pt.onKeyDown(9, 0, 0, v)
ps = pt.send(:planned_positions).sort
o_lo = bounds.min.x; o_hi = bounds.max.x
centers = [o_lo] + ps.map { |p| p + t / 2 } + [o_hi]
pitch = centers.each_cons(2).map { |a, b| (b - a).to_mm }
check 'phủ bì: các cánh phủ (tim-tim) bằng nhau', pitch.length == 4 && pitch.max - pitch.min < 1e-6, pitch.inspect
check 'all boards inside interior', ps.all? { |p| p >= inner0 - 1e-9 && p + t <= inner1 + 1e-9 }
pt.onUserText('/50', v); check '/50 bị kẹp về 20 ô', pt.instance_variable_get(:@divide_count) == 20
pt.onUserText('/4', v)
big_t = ((bounds.width.to_mm - 200) / 21).ceil + 5
pt.update_settings(V::Schema.merge_settings('board_thickness' => big_t))
pt.onUserText('/20', v)
check 'báo lỗi ô quá nhỏ: giữ /4 cũ', (pt.instance_variable_get(:@divide_count) == 4)
pt.update_settings(V::Schema.merge_settings('board_thickness' => 17.5))
pt.onKeyDown(8, 0, 0, v)
check 'Backspace khi đang chờ /n: bỏ chờ', !pt.axis_locked?
pt.update_settings(V::Schema.merge_settings('board_thickness' => 17.5, 'panel_kind' => 'phu_bi'))
check 'dialog changes kind', pt.kind == 'phu_bi'
pt.onKeyDown(9, 0, 0, v); k_after_tab = pt.kind
pt.update_settings(V::Schema.merge_settings('board_thickness' => 17.5, 'panel_kind' => 'phu_bi'))
check 'unchanged dialog value keeps Tab choice', pt.kind == k_after_tab, [pt.kind, k_after_tab].inspect
pt.update_settings(V::Schema.merge_settings('board_thickness' => 17.5, 'panel_axis' => 'horizontal'))
check 'Hướng trong bảng được giữ làm dự phòng', pt.settings['panel_axis'] == 'horizontal'
pt.onKeyDown(9, 0, 0, v)
pt.onKeyDown(9, 0, 0, v)
check 'Tab khi chưa chờ /n: đổi phạm vi lọt ↔ xuyên', pt.span == 'full'
pt.onKeyDown(9, 0, 0, v)
check 'Tab lần nữa: về lọt trong ô', pt.span == 'cell'

# Luồng mới: click khóa mặt → kéo → Tab điểm bắt → gõ mm → click tạo (lệnh vẫn chạy)
v.fake_path = [cab, shell_c, part_of.call('Hông Trái')]; v.fake_point = Geom::Point3d.new(600.mm, -10.mm, 1000.mm); pt.onMouseMove(0, 5, 5, v)
n_v = vach.call.length
pt.onLButtonDown(0, 5, 5, v)
check 'click 1: khóa mặt, chưa tạo tấm', pt.instance_variable_get(:@ref) && pt.axis_locked? && vach.call.length == n_v
v.fake_point = Geom::Point3d.new(600.mm, 200.mm, 1000.mm); pt.onMouseMove(0, 5, 5, v)
check 'kéo ra: khoảng cách theo chuột > 0', pt.send(:distance_for, pt.instance_variable_get(:@ref)) > 0
pt.onKeyDown(9, 0, 0, v)
check 'Tab: điểm bắt đổi sang Giữa', pt.instance_variable_get(:@point) == 1
pt.onKeyDown(9, 0, 0, v); pt.onKeyDown(9, 0, 0, v)
check 'Tab vòng về Trong', pt.instance_variable_get(:@point) == 0
pt.onUserText('200', v)
check 'gõ 200 mm: khoảng cách đúng 200 mm', (pt.send(:distance_for, pt.instance_variable_get(:@ref)) - 200.mm).abs < 1e-6
pt.onLButtonDown(0, 5, 5, v)
check 'click 2: tạo đúng 1 vách', vach.call.length == n_v + 1, vach.call.length - n_v
check 'vách đặt đúng: mặt gần hông trái cách 200 mm', (vach.call.last.bounds.min.x - (V::Interior.inner(shell_c).x0 + 200.mm)).abs < 0.01.mm, vach.call.last.bounds.min.x.to_mm.inspect
check 'sau khi tạo: không còn khóa mặt, lệnh vẫn chạy', !pt.axis_locked? && pt.active?
pt.onKeyDown(8, 0, 0, v)
check 'Backspace: hoàn tác vách vừa tạo', vach.call.length == n_v
pt.onKeyDown(8, 0, 0, v)
check 'Backspace lần 2: không có bước của lệnh để hoàn tác', vach.call.length == n_v

# Đợt ngang từ đáy: /3 rồi click tạo (lối tắt cả ô)
v.fake_path = [cab, shell_c, part_of.call('Đáy')]; v.fake_point = Geom::Point3d.new(600.mm, 200.mm, 300.mm); pt.onMouseMove(0, 5, 5, v)
pt.onUserText('/3', v)
n_d = dot.call.length
pt.commit(v)
check 'panel commit adds 2 shelves', dot.call.length == n_d + 2, dot.call.length - n_d
shelf = dot.call.first
check 'shelf bounds inside interior', shelf && shelf.definition.bounds.min.z.to_mm > 17 && shelf.definition.bounds.max.z.to_mm < 1983, shelf && shelf.definition.bounds.min.z.to_mm

# --- 5. PresetStore ---
dir = Dir.mktmpdir('vgdpreset'); ps = V::PresetStore.new(dir)
File.write(ps.path, JSON.generate({'schema' => 1, 'groups' => ['A'], 'presets' => [{'id' => 'x', 'name' => 'Cũ', 'group' => 'A', 'params' => {'board_thickness' => 18}}]}))
ps.save('Mới', {'board_thickness' => 17.5}, 'B')
check 'schema1 backup', File.file?(ps.path + '.schema1.bak')
data = ps.all
check 'migrated to 2', data['schema'] == 2 && data['presets'].length == 2
id = data['presets'].last['id']
ps.move(id, 'Nhóm Mới'); check 'move', ps.all['presets'].last['group'] == 'Nhóm Mới'
ps.delete_group('Nhóm Mới'); check 'delete_group → default', ps.all['presets'].last['group'] == V::PresetStore::DEFAULT_GROUP
check 'cannot delete default group', raises?(StandardError) { ps.delete_group('Chưa phân nhóm') }
check 'duplicate name rejected', raises?(StandardError) { ps.save('mới', {}) }
# --- 5b. Chân cao / ván chân / phào trần dựng thật ---
lbox = mk_box(600, 560, 2000, [3000, 0, 0])
lroot = V::Geometry.cabinet_from_box(lbox, {'front_normal' => [0,-1,0]})
lshell = V::Geometry.shell_for(lroot)
check 'leg: shell bounds = thân tủ (z 40..1980)', (lshell.definition.bounds.min.z.to_mm - 40).abs < 1e-6 && (lshell.definition.bounds.max.z.to_mm - 1980).abs < 1e-6, [lshell.definition.bounds.min.z.to_mm, lshell.definition.bounds.max.z.to_mm].inspect
ltrim = lroot.definition.entities.to_a.find { |e| e.respond_to?(:name) && e.name == 'Chân & phào' }
check 'leg: nhóm Chân & phào tạo cạnh thùng tủ', ltrim && ltrim.definition.entities.to_a.map(&:name).sort == ['Phào trần', 'Ván chân', 'Ván chân sau']
check 'leg: trim nằm ngoài thùng tủ', lshell.definition.entities.to_a.none? { |e| ['Phào trần', 'Ván chân'].include?(e.name) }
check 'leg: tag vai trò toe_kick', ltrim.definition.entities.to_a.any? { |e| e.get_attribute('VGD_Cabinet_Draw', 'params_json').to_s.include?('toe_kick') }
nbox = mk_box(600, 560, 2000, [4000, 0, 0])
nroot = V::Geometry.cabinet_from_box(nbox, {'front_normal' => [0,-1,0], 'leg_height' => 0, 'ceiling_strip_height' => 0})
check 'leg=0 & phào=0: không có nhóm trim, thân đầy đủ', nroot.definition.entities.to_a.none? { |e| e.respond_to?(:name) && e.name == 'Chân & phào' } && V::Geometry.shell_for(nroot).definition.bounds.min.z.to_mm.abs < 1e-6
check 'leg: data lưu tổng cao', V::ModelData.params(lroot)['height_mm'] == 2000.0 && V::ModelData.params(lroot)['leg_height'] == 40.0
check 'leg: box quá thấp báo lỗi, không tạo gì', (lb = mk_box(600, 560, 60, [5000, 0, 0]); n = Sketchup.active_model.entities.to_a.length; raises?(ArgumentError) { V::Geometry.cabinet_from_box(lb, {'front_normal' => [0,-1,0]}) }.is_a?(String) && Sketchup.active_model.entities.to_a.length == n)
prev = V::Preview.new
check 'leg: preview có thêm ván chân/phào', (lb2 = mk_box(600, 560, 2000, [6000, 0, 0]); V::Geometry.preview_cabinet(lb2, [0,-1,0], {}, prev).nil? && prev.polygon_count == (V::PanelModel.compute(600, 560, 2000, V::Schema.merge_settings({})).parts.length + 3) * 6 + 1), prev.polygon_count
# --- 5c. Hông chạm đất / đụng trần dựng thật ---
fbox = mk_box(600, 560, 2000, [12000, 0, 0])
froot = V::Geometry.cabinet_from_box(fbox, {'front_normal' => [0,-1,0], 'sides_to_floor' => true, 'sides_to_ceiling' => true})
fshell = V::Geometry.shell_for(froot)
fh = ->(name) { fshell.definition.entities.to_a.find { |e| e.name == name } }
check 'hông chạm đất: hông trái bắt đầu ở sàn', fh.call('Hông Trái').definition.bounds.min.z.to_mm.abs < 1e-6
check 'hông đụng trần: hông trái cao tới đỉnh box', (fh.call('Hông Trái').definition.bounds.max.z.to_mm - 2000).abs < 1e-6
check 'đáy vẫn ở độ cao chân', (fh.call('Đáy').definition.bounds.min.z.to_mm - 40).abs < 1e-6
check 'nóc thấp hơn đỉnh một khoảng phào', (fh.call('Nóc').definition.bounds.max.z.to_mm - 1980).abs < 1e-6
ftrim = froot.definition.entities.to_a.find { |e| e.respond_to?(:name) && e.name == 'Chân & phào' }
kick = ftrim.definition.entities.to_a.find { |e| e.name == 'Ván chân' }
corn = ftrim.definition.entities.to_a.find { |e| e.name == 'Phào trần' }
check 'ván chân nằm giữa hai hông (rộng 565)', (kick.definition.bounds.width.to_mm - 565).abs < 1e-6 && (kick.definition.bounds.min.x.to_mm - 17.5).abs < 1e-6, kick.definition.bounds.width.to_mm
check 'phào nằm giữa hai hông (rộng 565)', (corn.definition.bounds.width.to_mm - 565).abs < 1e-6, corn.definition.bounds.width.to_mm
fb = V::Geometry.body_bounds(fshell)
check 'body_bounds: thân tủ z 40..1980 dù hông dài hơn', (fb.min.z.to_mm - 40).abs < 1e-6 && (fb.max.z.to_mm - 1980).abs < 1e-6 && (fb.height.to_mm - 1940).abs < 1e-6, [fb.min.z.to_mm, fb.max.z.to_mm].inspect
check 'shell bounds thật cao 0..2000', fshell.definition.bounds.min.z.to_mm.abs < 1e-6 && (fshell.definition.bounds.max.z.to_mm - 2000).abs < 1e-6
check 'body_bounds tủ cũ (không có khóa) = hộp bao', (old = V::Geometry.shell_for(V::Geometry.cabinet_from_box(mk_box(500, 500, 500, [13000, 0, 0]), {'front_normal' => [0,-1,0], 'leg_height' => 0, 'ceiling_strip_height' => 0})); old.set_attribute('VGD_Cabinet_Draw', 'params_json', '{}'); ob = V::Geometry.body_bounds(old); ob.is_a?(V::Geometry::BodyBounds) && (ob.min.z - old.definition.bounds.min.z).abs < 1e-9 && (ob.height - (old.definition.bounds.max.z - old.definition.bounds.min.z)).abs < 1e-9)
# Cánh/đợt/vách tính theo thân tủ, không phủ xuống phần chân
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(froot)
fdt = V::Tools::DoorTool.new({}); fdt.activate; fdt.onUserText('/2', V.instance_variable_get(:@x) || Sketchup.active_model.active_view)
fcells = fdt.cells(V::Geometry.body_bounds(fshell))
check 'cánh chỉ phủ từ đáy tới nóc (40..1980), không xuống chân', fcells.all? { |c| (c[:z0].to_mm - 40).abs < 1e-6 && (c[:z1].to_mm - 1980).abs < 1e-6 }, fcells.map { |c| [c[:z0].to_mm, c[:z1].to_mm] }.inspect
fpt = V::Tools::PanelTool.new({}); fpt.activate
inner = V::Interior.inner(fshell)
check 'đợt/vách: lòng tủ z từ mặt đáy tới mặt dưới nóc', (inner.z0.to_mm - 57.5).abs < 1e-6 && (inner.z1.to_mm - 1962.5).abs < 1e-6, [inner.z0.to_mm, inner.z1.to_mm].inspect
check 'không bật hai cờ: hông vẫn trong thân (hành vi cũ)', (nb = V::Geometry.cabinet_from_box(mk_box(600, 560, 2000, [14000, 0, 0]), {'front_normal' => [0,-1,0]}); ns = V::Geometry.shell_for(nb); ns.definition.bounds.min.z.to_mm.round(6) == 40.0 && ns.definition.bounds.max.z.to_mm.round(6) == 1980.0)

# --- 5d. Face → ván ---
def mk_face(pts, ents = nil)
  (ents || Sketchup.active_model.entities).add_face(pts.map { |p| p.map(&:mm) })
end
Sketchup.active_model.selection.clear
bf1 = mk_face([[20000, 0, 0], [20600, 0, 0], [20600, 400, 0], [20000, 400, 0]])
bf2 = mk_face([[21000, 0, 0], [21500, 0, 0], [21500, 300, 0], [21000, 300, 0]])
Sketchup.active_model.selection.add(bf1); Sketchup.active_model.selection.add(bf2)
check 'faces_only? khi chỉ chọn face', V::Tools::FaceBoardTool.faces_only?(Sketchup.active_model.selection)
check 'faces_only? false khi có group', !V::Tools::FaceBoardTool.faces_only?([bf1, mk_box(100, 100, 100, [30000, 0, 0])])
check 'faces_only? false khi rỗng', !V::Tools::FaceBoardTool.faces_only?([])
check 'Tools.build box + face → FaceBoardTool', V::Tools.build('box', {}).is_a?(V::Tools::FaceBoardTool)
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(mk_box(100, 100, 100, [31000, 0, 0]))
check 'Tools.build box + group → BoxTool', V::Tools.build('box', {}).is_a?(V::Tools::BoxTool)
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(bf1); Sketchup.active_model.selection.add(bf2)
UI.next_input = ['18', 'Theo pháp tuyến']
ft = V::Tools::FaceBoardTool.new({}); ft.activate
check 'hộp thoại hỏi độ dày (mặc định = dày ván chung 17.5)', UI.inputbox_calls.last[1][0] == 17.5 && UI.inputbox_calls.last[0].first.include?('Độ dày'), UI.inputbox_calls.last.inspect
check 'nhận độ dày 18', ft.thickness_mm == 18.0
check 'preview 2 face = 2 lăng trụ (6 mặt)', ft.instance_variable_get(:@preview).polygon_count == 12
ft.draw(Sketchup.active_model.active_view); check 'face tool draw ok', true
check 'hud mô tả', ft.hud_lines.first.include?('2 face') && ft.hud_lines[1].include?('18')
n_ents = Sketchup.active_model.entities.to_a.length
ft.commit(Sketchup.active_model.active_view)
boards = Sketchup.active_model.entities.to_a.select { |e| e.is_a?(Sketchup::Group) && e.name.to_s.start_with?('Ván ') }
check 'tạo 2 ván', boards.length == 2, boards.length
b1 = boards.first
check 'ván dày 18 mm, dựng lên phía +Z theo pháp tuyến', (b1.definition.bounds.height.to_mm - 18).abs < 1e-6 && b1.definition.bounds.min.z.to_mm.abs < 1e-6 && (b1.definition.bounds.width.to_mm - 600).abs < 1e-6
check 'ván có vai trò board và độ dày', b1.get_attribute('VGD_Cabinet_Draw', 'params_json').to_s.include?('"role":"board"') && b1.get_attribute('VGD_Cabinet_Draw', 'params_json').to_s.include?('18')
check 'face gốc còn nguyên', !bf1.erased? && !bf2.erased?
check 'sau khi tạo, ván được chọn', Sketchup.active_model.selection.to_a.length == 2 && Sketchup.active_model.selection.all? { |e| e.name.to_s.start_with?('Ván ') }
# Tab đổi phía: ngược và chia đều
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(bf1)
UI.next_input = ['20', 'Theo pháp tuyến']
f2 = V::Tools::FaceBoardTool.new({}); f2.activate
f2.onKeyDown(9, 0, 0, Sketchup.active_model.active_view); check 'Tab → ngược pháp tuyến', f2.side == 'reverse'
f2.commit(Sketchup.active_model.active_view)
rev = Sketchup.active_model.entities.to_a.select { |e| e.is_a?(Sketchup::Group) && e.name == 'Ván 1' }.last
check 'ngược: ván nằm phía -Z (z -20..0)', (rev.definition.bounds.min.z.to_mm + 20).abs < 1e-6 && rev.definition.bounds.max.z.to_mm.abs < 1e-6, [rev.definition.bounds.min.z.to_mm, rev.definition.bounds.max.z.to_mm].inspect
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(bf2)
UI.next_input = ['10', 'Chia đều hai phía']
f3 = V::Tools::FaceBoardTool.new({}); f3.activate
check 'chọn chia đều trong hộp thoại', f3.side == 'center'
f3.commit(Sketchup.active_model.active_view)
cen = Sketchup.active_model.entities.to_a.select { |e| e.is_a?(Sketchup::Group) && e.name == 'Ván 1' }.last
check 'chia đều: z -5..5', (cen.definition.bounds.min.z.to_mm + 5).abs < 1e-6 && (cen.definition.bounds.max.z.to_mm - 5).abs < 1e-6
# gõ số đổi độ dày, hủy hộp thoại, giá trị sai
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(bf1)
UI.next_input = ['12', 'Theo pháp tuyến']
f4 = V::Tools::FaceBoardTool.new({}); f4.activate
f4.onUserText('25', Sketchup.active_model.active_view); check 'gõ 25 đổi độ dày', f4.thickness_mm == 25.0
f4.onUserText('abc', Sketchup.active_model.active_view); check 'gõ chữ giữ nguyên độ dày', f4.thickness_mm == 25.0
f4.onUserText('0', Sketchup.active_model.active_view); check 'gõ 0 giữ nguyên độ dày', f4.thickness_mm == 25.0
UI.next_input = false
f5 = V::Tools::FaceBoardTool.new({}); f5.activate
check 'hủy hộp thoại: không có độ dày, không tạo ván', f5.thickness_mm.nil? && (before_n = Sketchup.active_model.entities.to_a.length; f5.commit(Sketchup.active_model.active_view); Sketchup.active_model.entities.to_a.length == before_n)
UI.next_input = ['abc', 'Theo pháp tuyến']
f6 = V::Tools::FaceBoardTool.new({}); f6.activate; check 'độ dày chữ bị từ chối', f6.thickness_mm.nil?
UI.next_input = ['9999', 'Theo pháp tuyến']
f7 = V::Tools::FaceBoardTool.new({}); f7.activate; check 'độ dày quá lớn bị từ chối', f7.thickness_mm.nil?
# face có lỗ: ván có lỗ
Sketchup.active_model.selection.clear
hf = mk_face([[40000, 0, 0], [40600, 0, 0], [40600, 600, 0], [40000, 600, 0]])
hf.holes = [[[40200, 200, 0], [40400, 200, 0], [40400, 400, 0], [40200, 400, 0]].map { |p| Geom::Point3d.new(*p.map(&:mm)) }]
Sketchup.active_model.selection.add(hf)
UI.next_input = ['18', 'Theo pháp tuyến']
f8 = V::Tools::FaceBoardTool.new({}); f8.activate; f8.commit(Sketchup.active_model.active_view)
hole_board = Sketchup.active_model.entities.to_a.select { |e| e.is_a?(Sketchup::Group) && e.name == 'Ván 1' }.last
inner_faces = hole_board.definition.entities.to_a.select { |e| e.is_a?(Sketchup::Face) }
check 'face có lỗ: vòng trong được cắt (face phụ bị xóa)', inner_faces.length == 1, inner_faces.length
# --- 6. ToolSettings (kho setting theo công cụ) ---
tdir = Dir.mktmpdir('vgdts')
legacy = {'schema' => 2, 'groups' => ['Chưa phân nhóm', 'Bếp'], 'presets' => [
  {'id' => 'old1', 'name' => 'Tủ bếp', 'group' => 'Bếp', 'params' => {'board_thickness' => 18, 'back_mode' => 'overlay'}},
  {'id' => 'old2', 'name' => 'Tủ bếp', 'group' => 'Chưa phân nhóm', 'params' => {'back_mode' => 'none'}}]}
File.write(File.join(tdir, 'presets_v1.json'), JSON.generate(legacy))
before_legacy = File.read(File.join(tdir, 'presets_v1.json'))
ts = V::ToolSettings.new(tdir)
check 'ts migrate: 2 presets into box', ts.presets('box').length == 2
check 'ts migrate: ids kept', ts.presets('box').map { |p| p['id'] } == %w[old1 old2]
check 'ts migrate: other tools empty', %w[panel door drawer].all? { |g| ts.presets(g).empty? }
check 'ts migrate: names deduped', ts.presets('box').map { |p| p['name'].downcase }.uniq.length == 2, ts.presets('box').map { |p| p['name'] }.inspect
check 'ts migrate: does not write', !File.file?(ts.path)
check 'ts migrate: legacy untouched', File.read(File.join(tdir, 'presets_v1.json')) == before_legacy
p1 = ts.save('door', 'Cánh thường', {'door_gap' => 2, 'board_thickness' => 99})
check 'ts save → file', File.file?(ts.path)
check 'ts save strips base keys', !ts.presets('door').first['params'].key?('board_thickness')
check 'ts legacy still there after write', ts.presets('box').length == 2
check 'ts duplicate name rejected', raises?(StandardError) { ts.save('door', 'cánh THƯỜNG', {}) }
check 'ts same name other tool ok', !raises?(StandardError) { ts.save('drawer', 'Cánh thường', {'drawer_count' => 3}) }.is_a?(String)
check 'ts bad group rejected', raises?(StandardError) { ts.save('cut', 'x', {}) }
check 'ts empty name rejected', raises?(StandardError) { ts.save('box', '  ', {}) }
check 'ts non-hash params rejected', raises?(StandardError) { ts.save('box', 'y', 'oops') }
ts.update('door', p1['id'], {'door_gap' => 3}); check 'ts update', ts.presets('door').first['params']['door_gap'] == 3
ts.rename('door', p1['id'], 'Cánh đôi'); check 'ts rename', ts.presets('door').first['name'] == 'Cánh đôi'
ts.set_default('door', p1['id']); check 'ts default set', ts.all['tools']['door']['default_id'] == p1['id']
ts.save_base({'board_thickness' => 18, 'back_thickness' => 5})
eff = ts.effective('door')
check 'ts effective: default preset applied', eff['door_gap'] == 3, eff['door_gap']
check 'ts effective: base applied', eff['board_thickness'] == 18.0 && eff['back_thickness'] == 5.0
check 'ts effective: defaults filled', eff['back_mode'] == 'groove'
check 'ts effective: other tool untouched by door default', ts.effective('drawer')['drawer_count'] != 99
check 'ts base negative rejected', raises?(StandardError) { ts.save_base({'board_thickness' => -1}) }
check 'ts base string rejected', raises?(StandardError) { ts.save_base({'board_thickness' => 'abc'}) }
ts.delete('door', p1['id'])
check 'ts delete clears default', ts.all['tools']['door']['default_id'].nil? && ts.presets('door').empty?
check 'ts delete unknown rejected', raises?(StandardError) { ts.delete('door', 'nope') }
ts.set_default('box', 'old1'); ts.set_default('box', nil); check 'ts default cleared', ts.all['tools']['box']['default_id'].nil?
dump = ts.export_json
ts2 = V::ToolSettings.new(Dir.mktmpdir('vgdts2'))
check 'ts import counts', ts2.import_json(dump) == ts.presets('box').length + ts.presets('drawer').length
check 'ts import new ids', (ts2.presets('box').map { |p| p['id'] } & %w[old1 old2]).empty?
n = ts2.presets('box').length
ts2.import_json(dump); check 'ts import merges without overwrite', ts2.presets('box').length == n * 2
check 'ts import bad json rejected', raises?(StandardError) { ts2.import_json('{{{') }
check 'ts import bad structure rejected', raises?(StandardError) { ts2.import_json('[1,2]') }
File.write(ts.path, '{broken'); File.write(ts.path + '.bak', JSON.generate({'schema' => 3, 'base' => {}, 'tools' => {'box' => {'presets' => [{'id' => 'z', 'name' => 'Z', 'params' => {}}]}}}))
check 'ts corrupt file falls back to .bak', ts.presets('box').map { |p| p['id'] } == ['z']
File.delete(ts.path + '.bak'); check 'ts corrupt without bak is reported', raises?(StandardError) { ts.all }

# --- 7. Dialog callbacks ---
V::Dialog.show
win = V::Dialog.instance_variable_get(:@window)
win.call('ready'); check 'ready → state pushed', win.scripts.any? { |x| x.start_with?('VGD.state(') }
win.call('ts_save', JSON.generate({'group' => 'box', 'name' => 'Nền', 'settings' => {'back_mode' => 'overlay'}}))
check 'ts_save pushes state', win.scripts.last.start_with?('VGD.state(') && win.scripts.last.include?('Nền'), win.scripts.last[0, 80]
pid = V::ToolSettings.new.presets('box').first['id']
win.call('ts_load', JSON.generate({'group' => 'box', 'id' => pid}))
check 'ts_load notifies with group', win.scripts.any? { |x| x.start_with?('VGD.loadSettings(') && x.end_with?(', true, "box")') }, win.scripts.last
win.call('ts_save', JSON.generate({'group' => 'box', 'name' => 'Nền', 'settings' => {}}))
check 'duplicate reported in status', win.scripts.last.include?('VGD.status') && win.scripts.last.include?('tồn tại')
win.call('apply'); check 'apply without tool is reported', win.scripts.last.include?('VGD.status')
win.call('tool', JSON.generate({'name' => 'box', 'settings' => {}, 'preset_id' => pid}))
check 'tool launched', Sketchup.active_model.tool.is_a?(V::Tools::BoxTool)
check 'tool remembers preset id', Sketchup.active_model.tool.active_preset_id == pid
win.call('settings', JSON.generate({'back_mode' => 'none'}))
check 'settings reach tool', Sketchup.active_model.tool.settings['back_mode'] == 'none'
win.call('cancel'); check 'cancel button deselects', Sketchup.active_model.tool.nil?

# --- 8. Thanh setting trên viewport (PresetHud) ---
hts = V::ToolSettings.new
a1 = hts.save('box', 'Chân 100', {'back_mode' => 'none'})
a2 = hts.save('box', 'Chân 50', {'back_mode' => 'overlay'})
view = Sketchup.active_model.active_view
t = V::Tools::BoxTool.new({}); t.activate
t.draw(view)
rects = t.instance_variable_get(:@hud_rects)
preset_rects = rects.select { |r| r[4] == :preset }
check 'hud draws rows for box', preset_rects.length == hts.presets('box').length, preset_rects.length
check 'hud có 4 nút Loại tủ cho Box', rects.count { |r| r[4] == :mode } == 4
check 'hud có hàng thông số cho Box', rects.count { |r| r[4] == :param } >= 8
row2 = preset_rects.find { |r| r[5] == 1 }
t.onLButtonDown(0, row2[0] + 5, row2[1] + 5, view)
check 'hud click selects preset', t.active_preset_id == hts.presets('box')[1]['id']
check 'hud click applies params', t.settings['back_mode'] == hts.presets('box')[1]['params']['back_mode'], t.settings['back_mode']
check 'hud click syncs dialog dropdown', win.scripts.any? { |x| x.start_with?('VGD.pickPreset("box"') }
t.onKeyDown(49, 0, 4, view)  # Ctrl+1: không còn chọn mẫu
check 'hud KHÔNG còn Ctrl+số', t.active_preset_id == hts.presets('box')[1]['id']
check 'hud passes Tab to tool', t.onKeyDown(9, 0, 0, view) == true
check 'hud click outside passes through', !raises?(StandardError) { t.onLButtonDown(0, 5, 900, view) }.is_a?(String)
t.deactivate(view)
op = V::Tools::OpeningTool.new({}); op.activate; op.draw(view)
check 'opening uses door group', op.preset_group == 'door'
cut = V::Tools::CutTool.new({}); cut.activate; cut.draw(view)
check 'cut tool has no preset bar', cut.preset_group.nil? && cut.instance_variable_get(:@hud_rects).empty?
dr = V::Tools.build('drawer', {}); dr.activate
check 'drawer group', dr.preset_group == 'drawer'
hts.delete('box', a1['id']); t2 = V::Tools::BoxTool.new({}); t2.active_preset_id = a1['id']; t2.activate
check 'deleted preset id is dropped from tool', t2.active_preset_id.nil?
# --- 8b. Thanh công cụ và chạy nhanh ---
tb = V.instance_variable_get(:@toolbar)
check 'toolbar có 6 nút', tb.commands.length == 6, tb.commands.length
check 'toolbar thứ tự', tb.commands.map(&:title) == ['Box → Board', 'Chia đợt / vách', 'Cánh tủ', 'Ngăn kéo', 'VGD Chọn', 'Setting']
check 'mọi nút có icon tồn tại', tb.commands.all? { |c| File.file?(c.small_icon.to_s) && File.file?(c.large_icon.to_s) }, tb.commands.map(&:small_icon).inspect
check 'submenu Extensions có đủ nút', UI.menu('Extensions').subs['VGD Cabinet Draw'].items.length == 10
sd = V::ToolSettings.new
sd.save_base({'board_thickness' => 18})
d1 = sd.save('door', 'Khe 3', {'door_gap' => 3}); sd.set_default('door', d1['id'])
Sketchup.active_model.select_tool(nil)
tb.commands[2].run
dtool = Sketchup.active_model.tool
check 'nút Cánh chạy công cụ cánh với setting mặc định', dtool.is_a?(V::Tools::DoorTool) && dtool.settings['door_gap'] == 3 && dtool.settings['board_thickness'] == 18.0, dtool.settings.values_at('door_gap', 'board_thickness').inspect
check 'nút nhớ preset mặc định', dtool.active_preset_id == d1['id']
Sketchup.active_model.select_tool(nil)
tb.commands[0].run
check 'nút Box chạy BoxTool', Sketchup.active_model.tool.is_a?(V::Tools::BoxTool)
check 'Box nhận chân 40 mặc định', Sketchup.active_model.tool.settings['leg_height'] == 40.0
Sketchup.active_model.select_tool(nil)
tb.commands[3].run; check 'nút Ngăn kéo', Sketchup.active_model.tool.preset_group == 'drawer'
Sketchup.active_model.select_tool(nil)
tb.commands[1].run; check 'nút Đợt/vách', Sketchup.active_model.tool.is_a?(V::Tools::PanelTool)
Sketchup.active_model.select_tool(nil)
check 'launch_default công cụ lạ báo lỗi', (n = UI.msgs.length; V.launch_default('cut'); UI.msgs.length == n + 1 && UI.msgs.last.include?('chưa có kho setting'))
tb.commands[4].run; check 'nút Setting mở bảng', V::Dialog.instance_variable_get(:@window).visible?
Sketchup.active_model.select_tool(nil)

# --- 9. reload ---
menus_before = UI.menu('Extensions').items.length
n_consts = V.constants.length
V.reload!
check 'reload no dup menu', UI.menu('Extensions').items.length == menus_before
check 'reload no dup constants', V.constants.length == n_consts, "#{n_consts} → #{V.constants.length}"
check 'reload message', UI.msgs.last.include?('đã nạp lại')
check 'tools after reload', V::Tools.respond_to?(:build)
puts "\nTHÀNH CÔNG: #{$pass}  THẤT BẠI: #{$fail.length}"
exit($fail.empty? ? 0 : 1)
