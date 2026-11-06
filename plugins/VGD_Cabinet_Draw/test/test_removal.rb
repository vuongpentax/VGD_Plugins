# Test XÓA TẤM / CÁNH / NGĂN KÉO (Removal). Chạy: ruby test_removal.rb [thư mục runtime]
$stdout.sync = true
src = File.read(File.join(__dir__, 'test_build.rb'), encoding: 'UTF-8')
eval(src.split("puts '== 1.").first, binding, File.join(__dir__, 'test_build.rb'))
v = Sketchup.active_model.active_view
$pass ||= 0

def doors_sorted(c); V::Operations.doors_of(c).sort_by { |d| V::Operations.door_bounds(d)[0] }; end
def shelves(c); parts_named(c, 'Đợt'); end
def drawer_fronts(c); groups(container(c, 'Ngăn kéo').definition.entities).select { |g| g.name == 'Mặt Ngăn Kéo' }; end
def drawer_boxes(c); groups(container(c, 'Ngăn kéo').definition.entities).select { |g| g.name == 'Thùng Ngăn Kéo' }; end

puts '== 1. Xóa một đợt trong nhóm chia đều (/3) =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
pv = V::Tools::PanelTool.new({}); reselect(c); pv.activate; pv.settings['panel_axis'] = 'horizontal'
hover_panel(pv, c, 200, 1000); pv.onUserText('/3', v); pv.commit(v)
check 'có 2 đợt sau khi chia /3', shelves(c).length == 2, shelves(c).length.to_s
first = shelves(c).min_by { |s| bb(s)[2] }
Sketchup.active_model.start_operation('t', true)
V::Removal.remove_members(c, [first]); Sketchup.active_model.commit_operation
check 'xóa 1 đợt: còn 1 đợt', shelves(c).length == 1, shelves(c).length.to_s
check 'bước vẫn còn, có danh sách omit', V::Rebuild.ops(c).any? { |o| o['type'] == 'panel' && Array(o['omit']).length == 1 }, V::Rebuild.ops(c).inspect
left_z = bb(shelves(c).first)[2]
Sketchup.active_model.start_operation('t', true)
V::Rebuild.run(c, V::Rebuild.settings_of(c), V::Rebuild.dimensions_of(c)); Sketchup.active_model.commit_operation
check 'dựng lại (Sửa tủ) không làm đợt đã xóa hiện lại', shelves(c).length == 1 && near(bb(shelves(c).first)[2], left_z), shelves(c).length.to_s

puts '== 2. Xóa đợt cuối cùng của một bước: gỡ hẳn bước =='
Sketchup.active_model.start_operation('t', true)
V::Removal.remove_members(c, shelves(c))
Sketchup.active_model.commit_operation
check 'không còn đợt', shelves(c).empty?
check 'bước đợt đã được gỡ', V::Rebuild.ops(c).none? { |o| o['type'] == 'panel' }, V::Rebuild.ops(c).inspect

puts '== 3. Xóa đợt theo mm (tự do) =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
pl = V::Tools::PanelTool.new({}); reselect(c); pl.activate; pl.settings['panel_axis'] = 'horizontal'
hover_panel(pl, c, 200, 1000); pl.onUserText('350', v); pl.commit(v)
pl2 = V::Tools::PanelTool.new({}); reselect(c); pl2.activate; pl2.settings['panel_axis'] = 'horizontal'
hover_panel(pl2, c, 200, 1000); pl2.onUserText('900', v); pl2.commit(v)
check 'có 2 đợt theo mm', shelves(c).length == 2, shelves(c).length.to_s
low = shelves(c).min_by { |s| bb(s)[2] }
high_z = bb(shelves(c).max_by { |s| bb(s)[2] })[2]
Sketchup.active_model.start_operation('t', true)
V::Removal.remove_members(c, [low]); Sketchup.active_model.commit_operation
check 'xóa đợt thấp: còn đợt cao đúng vị trí', shelves(c).length == 1 && near(bb(shelves(c).first)[2], high_z), shelves(c).map { |s| bb(s)[2] }.inspect
check 'bước đã đổi sang vị trí tuyệt đối: 1 tấm còn lại', V::Removal.panel_sources(V::Rebuild.ops(c).find { |o| o['type'] == 'panel' }).length == 1

puts '== 4. Xóa cánh: vùng thành trống, cánh kia không bị gộp to ra =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
reselect(c)
dt = V::Tools::DoorTool.new({}); dt.activate
dt.layout.split(dt.layout.regions.first['id'], 'vertical', 0.5); dt.commit(v)
ds = doors_sorted(c)
check 'trước: 2 cánh', ds.length == 2, ds.length.to_s
w_keep = V::Operations.door_bounds(ds[1])[3] - V::Operations.door_bounds(ds[1])[0]
Sketchup.active_model.start_operation('t', true)
V::Removal.remove_doors(c, [ds[0]]); Sketchup.active_model.commit_operation
check 'xóa 1 cánh: còn 1 cánh', doors_sorted(c).length == 1, doors_sorted(c).length.to_s
w_after = V::Operations.door_bounds(doors_sorted(c)[0])[3] - V::Operations.door_bounds(doors_sorted(c)[0])[0]
check 'cánh còn lại giữ nguyên rộng (không gộp vào)', near(w_after, w_keep, 0.01), [w_after.to_mm, w_keep.to_mm].inspect
Sketchup.active_model.start_operation('t', true)
V::Rebuild.run(c, V::Rebuild.settings_of(c), V::Rebuild.dimensions_of(c)); Sketchup.active_model.commit_operation
check 'dựng lại không làm cánh đã xóa hiện lại', doors_sorted(c).length == 1
check 'vùng trống được lưu trong bố cục', JSON.parse(c.get_attribute(V::Schema::DICTIONARY, 'door_layout_json'))['regions'].any? { |r| r['empty'] }

puts '== 5. Xóa ngăn kéo (mặt + thùng) theo bước tạo =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
reselect(c)
dk = V::Tools.build('drawer', { 'drawer_count' => 2 }); dk.activate
vv = Sketchup.active_model.active_view; vv.fake_path = [c]; vv.fake_point = at(200, 150)
dk.onMouseMove(0, 5, 5, vv); dk.onLButtonDown(0, 5, 5, vv); dk.commit(vv)
check 'có ngăn kéo trước khi xóa', drawer_fronts(c).length == 2 && drawer_boxes(c).length == 2, [drawer_fronts(c).length, drawer_boxes(c).length].inspect
step = V::Removal.step_of(drawer_fronts(c).first)
check 'nhận đúng bước tạo của mặt hộc', !step.nil?
Sketchup.active_model.start_operation('t', true)
V::Removal.remove_steps(c, [step]); Sketchup.active_model.commit_operation
check 'xóa bước: hết mặt và thùng của bước đó', drawer_fronts(c).empty? && drawer_boxes(c).empty?, [drawer_fronts(c).length, drawer_boxes(c).length].inspect
Sketchup.active_model.start_operation('t', true)
V::Rebuild.run(c, V::Rebuild.settings_of(c), V::Rebuild.dimensions_of(c)); Sketchup.active_model.commit_operation
check 'dựng lại không làm ngăn kéo đã xóa hiện lại', drawer_fronts(c).empty?

puts '== 6. Tìm đúng tủ chứa tấm =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
pl = V::Tools::PanelTool.new({}); reselect(c); pl.activate; pl.settings['panel_axis'] = 'horizontal'
hover_panel(pl, c, 200, 1000); pl.onUserText('350', v); pl.commit(v)
check 'cabinet_of tìm đúng tủ từ một đợt', V::Removal.cabinet_of(shelves(c).first).equal?(c)

puts '== 3. Xóa vách: đợt chỉ nở tới vách gần nhất còn lại, không nở cả tủ =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
sh = shell(c)
inner = V::Interior.inner(sh)
vop = { 'type' => 'panel', 'axis' => 'vertical', 'kind' => 'thong_thuy', 'thickness_mm' => 17.5, 'limit' => true, 'setback_mm' => 0.0,
        'door_fit' => 'phu', 'mode' => 'free', 'anchor' => V::Rebuild.anchor_of(sh, 450.mm, (inner.z0 + inner.z1) / 2), 'offsets' => [282.5, 582.5] }
vop['op'] = V::Rebuild.record(c, vop)
V::Rebuild.place_panels(c, sh, vop)
sop = { 'type' => 'panel', 'axis' => 'horizontal', 'kind' => 'thong_thuy', 'thickness_mm' => 17.5, 'limit' => true, 'setback_mm' => 0.0,
        'door_fit' => 'phu', 'mode' => 'free', 'anchor' => V::Rebuild.anchor_of(sh, 700.mm, 1000.mm), 'offsets' => [942.5] }
sop['op'] = V::Rebuild.record(c, sop)
V::Rebuild.place_panels(c, sh, sop)
shelf = parts_named(c, 'Đợt').first
check 'trước khi xóa: đợt nằm trong ô phải (617.5..782.5)', near(bb(shelf)[0], 617.5) && near(bb(shelf)[3], 782.5), bb(shelf).inspect
part_b = parts_named(c, 'Vách').max_by { |p| bb(p)[0] }
Sketchup.active_model.start_operation('t', true)
V::Removal.remove_members(c, [part_b]); Sketchup.active_model.commit_operation
shelf = parts_named(c, 'Đợt').first
check 'xóa vách bên phải: đợt nở tới vách còn lại (317.5..782.5), không nở tới hông trái', shelf && near(bb(shelf)[0], 317.5) && near(bb(shelf)[3], 782.5), shelf && bb(shelf).inspect

puts '== 4b. Xóa hết cánh rồi tạo lại cánh bằng công cụ Cánh =='
c = cab('leg_height' => 0, 'ceiling_strip_height' => 0)
reselect(c)
dt = V::Tools::DoorTool.new({}); dt.activate
dt.commit(v)
check 'trước: 1 cánh', doors_sorted(c).length == 1, doors_sorted(c).length.to_s
Sketchup.active_model.start_operation('t', true)
V::Removal.remove_doors(c, doors_sorted(c)); Sketchup.active_model.commit_operation
check 'xóa hết: không còn cánh', doors_sorted(c).empty?
reselect(c)
dt2 = V::Tools::DoorTool.new({}); dt2.activate
dt2.layout.split(dt2.layout.regions.first['id'], 'vertical', 0.5)
dt2.commit(v)
check 'tạo lại sau khi xóa hết: có 2 cánh', doors_sorted(c).length == 2, doors_sorted(c).length.to_s
# Mở công cụ khi mọi vùng đang trống: bắt đầu bố cục mới, Enter tạo lại cánh.
Sketchup.active_model.start_operation('t', true)
V::Removal.remove_doors(c, doors_sorted(c)); Sketchup.active_model.commit_operation
reselect(c)
dt3 = V::Tools::DoorTool.new({}); dt3.activate
dt3.commit(v)
check 'mọi vùng trống: mở công cụ rồi Enter tạo lại được cánh', doors_sorted(c).length >= 1, doors_sorted(c).length.to_s

puts "\n== Kết quả test_removal: Đạt: #{$pass}   Không đạt: #{$fail.length} =="
$fail.each { |x| puts "  - #{x}" }
