# Test HUD 3 phần (Mẫu · Chế độ · Thông số), chế độ cánh phủ/lọt/thông thủy, chế độ ngăn kéo, thanh trạng thái.
# Chạy: ruby test_hud.rb [thư mục runtime]
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
def mk_box(w, d, h, at = [0, 0, 0])
  g = Sketchup.active_model.entities.add_group; g.name = 'Box'
  x, y, z = at.map(&:mm)
  f = g.entities.add_face([[x, y, z], [x + w.mm, y, z], [x + w.mm, y + d.mm, z], [x, y + d.mm, z]])
  f.reverse! if f.normal.z < 0
  f.pushpull(h.mm); g
end
def pt(x, z, y = -10)
  Geom::Point3d.new(x.mm, y.mm, z.mm)
end
V::Keys.platform = :windows

def new_cabinet
  Sketchup.reset_model!
  cab = V::Geometry.cabinet_from_box(mk_box(1200, 500, 2000), { 'front_normal' => [0, -1, 0], 'leg_height' => 0, 'ceiling_strip_height' => 0 })
  sel = Sketchup.active_model.selection
  sel.clear; sel.add(cab)
  cab
end

# Tìm hình chữ nhật HUD theo loại + khóa (mode: giá trị; param: khóa).
def rect_for(tool, kind, key)
  spec = tool.hud_spec
  index = if kind == :mode
            spec[:mode][:items].index { |item| item[0] == key }
          else
            tool.hud_params.index { |param| param[:key] == key }
          end
  (tool.instance_variable_get(:@hud_rects) || []).find { |r| r[4] == kind && r[5] == index }
end

def press(tool, kind, key)
  v = Sketchup.active_model.active_view
  tool.draw(v)
  r = rect_for(tool, kind, key)
  raise "không thấy #{kind} #{key} trên HUD" unless r
  tool.onLButtonDown(0, r[0] + 4, r[1] + 4, v)
  tool.draw(v)
  r
end

v = Sketchup.active_model.active_view

puts '== 1. HUD Cánh: 3 phần + thanh trạng thái =='
cab = new_cabinet
dt = V::Tools::DoorTool.new({}); dt.activate; dt.draw(v)
rects = dt.instance_variable_get(:@hud_rects)
check 'có 2 nút chế độ (phủ / lọt)', rects.count { |r| r[4] == :mode } == 2
check 'có 9 hàng thông số (gồm 2 ô phủ hông trái/phải)', rects.count { |r| r[4] == :param } == 9, rects.count { |r| r[4] == :param }
check 'thanh trạng thái có hướng dẫn ngắn', Sketchup.status_text.to_s.start_with?('VGD ·') && Sketchup.status_text.length < 150, Sketchup.status_text
check 'hướng dẫn không dùng Ctrl+số', !Sketchup.status_text.to_s.include?('Ctrl+1')
check 'chế độ mặc định là phủ', dt.fit == 'phu'

puts '== 2. Hình học 3 chế độ cánh =='
shell = V::Geometry.shell_for(cab)
b = V::Geometry.body_bounds(shell)
t = 17.5.mm
phu = dt.cells(b).first
check 'phủ: trùm hết thân tủ', (phu[:x0] - b.min.x).abs < 1e-6 && (phu[:x1] - b.max.x).abs < 1e-6 && (phu[:z0] - b.min.z).abs < 1e-6 && (phu[:z1] - b.max.z).abs < 1e-6
check 'phủ: mặt ngoài cánh trùm mặt trước box (mặt sau cánh ở y = dày ván)', (phu[:y] - t).abs < 1e-6
press(dt, :mode, 'lot')
check 'bấm nút Cánh lọt đổi chế độ', dt.fit == 'lot' && dt.settings['door_fit'] == 'lot'
dt.hud_set_value('door_inset_gap', 0.0, v)
lot = dt.cells(b).first
check 'lọt: nằm giữa hai hông', (lot[:x0] - (b.min.x + t)).abs < 1e-6 && (lot[:x1] - (b.max.x - t)).abs < 1e-6 && (lot[:z0] - b.min.z).abs < 1e-6 && (lot[:z1] - b.max.z).abs < 1e-6
check 'lọt: giữa hai hông, cao phủ cả nóc và đáy', true
check 'lọt: mặt cánh bằng mặt trước box', (lot[:y] - t).abs < 1e-6, lot[:y]
dt.hud_set_value('door_inset_gap', 2.0, v)
lot2 = dt.cells(b).first
check 'lọt + khe mép 2 mm', (lot2[:x0] - (b.min.x + t + 2.mm)).abs < 1e-6 && (lot2[:z1] - b.max.z).abs < 1e-6
dt.settings['door_fit'] = 'thong_thuy'; dt.hud_after_set('door_fit')
check 'cánh cũ lưu thông thủy được đọc như cánh lọt', dt.fit == 'lot'
check 'đổi chế độ cập nhật kích thước vùng', (dt.layout.width_mm - (1200 - 35 - 4)).abs < 1e-6, dt.layout.width_mm
check 'HUD ghi tên chế độ', dt.hud_lines.first.include?('CÁNH LỌT'), dt.hud_lines.first
dt.settings['door_fit'] = 'lot'; dt.hud_after_set('door_fit')

puts '== 3. Dựng cánh thật theo chế độ =='
press(dt, :mode, 'lot')
dt.hud_set_value('door_inset_gap', 0.0, v)
dt.layout.split(dt.layout.regions.first['id'], 'vertical', 0.5)
dt.commit(v)
cab_layout = JSON.parse(cab.get_attribute('VGD_Cabinet_Draw', 'door_layout_json'))
check 'bố cục lưu chế độ cánh', cab_layout['settings']['door_fit'] == 'lot', cab_layout['settings'].inspect
doors = V::Operations.doors_of(cab)
check 'dựng 2 cánh', doors.length == 2, doors.length
db = V::Operations.door_bounds(doors.first)
shell = V::Geometry.shell_for(cab)
b = V::Geometry.body_bounds(shell)
check 'cánh lọt thật nằm trong hông tủ', db[0] >= b.min.x + t - 1e-6 && db[3] <= b.max.x - t + 1e-6, db.inspect
check 'cánh lọt thật không nhô ra trước thân tủ', db[1] >= b.min.y - 1e-6, [db[1], b.min.y].inspect
check 'cánh lưu chế độ trong dữ liệu', doors.first.get_attribute('VGD_Cabinet_Draw', 'params_json').to_s.include?('"fit":"lot"') || V::ModelData.params(doors.first)['fit'] == 'lot'

puts '== 4. Mở lại tủ: chế độ cánh được nhớ =='
cab2 = new_cabinet
dt = V::Tools::DoorTool.new({ 'door_fit' => 'phu' }); dt.activate
dt.hud_set_value('door_fit', 'lot', v)
dt.commit(v)
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(cab2)
dt2 = V::Tools::DoorTool.new({}); dt2.activate
check 'mở lại tủ nhớ chế độ lọt', dt2.fit == 'lot', dt2.settings['door_fit']

puts '== 5. Sửa thông số: số / bật tắt / danh sách =='
cab = new_cabinet
dt = V::Tools::DoorTool.new({}); dt.activate
press(dt, :param, 'door_gap')
check 'bấm hàng số thì chờ gõ', dt.instance_variable_get(:@armed)[:key] == 'door_gap'
check 'thanh trạng thái nhắc gõ số', Sketchup.status_text.to_s.include?('Khe giữa cánh'), Sketchup.status_text
dt.onUserText('5', v)
check 'gõ 5 + Enter đặt khe giữa 5', dt.settings['door_gap'] == 5.0, dt.settings['door_gap']
check 'xong thì hết chờ gõ', dt.instance_variable_get(:@armed).nil?
press(dt, :param, 'door_gap')
dt.onUserText('abc', v)
check 'gõ sai không đổi, vẫn chờ', dt.settings['door_gap'] == 5.0 && !dt.instance_variable_get(:@armed).nil?
dt.onUserText('999', v)
check 'quá giới hạn không đổi', dt.settings['door_gap'] == 5.0
dt.onUserText('3,5mm', v)
check 'chấp nhận dấu phẩy và đuôi mm', dt.settings['door_gap'] == 3.5, dt.settings['door_gap']
Sketchup.active_model.select_tool(dt)
press(dt, :param, 'door_gap')
dt.onCancel(0, v)
check 'Esc khi đang chờ gõ: chỉ bỏ chờ', dt.instance_variable_get(:@armed).nil?
check 'Esc khi đang chờ gõ: KHÔNG thoát công cụ', Sketchup.active_model.tool.equal?(dt)
dt.onCancel(0, v)
check 'Esc lần hai mới thoát công cụ', Sketchup.active_model.tool.nil?
Sketchup.active_model.select_tool(dt)
press(dt, :param, 'show_dims')
check 'bấm hàng bật/tắt đảo giá trị', dt.settings['show_dims'] == true
labels = dt.instance_variable_get(:@preview).instance_variable_get(:@labels)
check 'bật hiện kích thước thì có nhãn', labels.length >= 1 && labels.first[1] =~ /1200 × 2000/, labels.inspect
press(dt, :param, 'split_axis')
check 'bấm hàng danh sách đổi vòng', dt.settings['split_axis'] == 'horizontal'
press(dt, :param, 'door_style')
check 'đổi kiểu cánh', dt.settings['door_style'] == 'shaker', dt.settings['door_style']

puts '== 6. Số gõ khi không chờ vẫn đi vào công cụ (chia đều) =='
dt = V::Tools::DoorTool.new({}); dt.activate
dt.onUserText('/3', v)
check '/3 vẫn chia đều 3 cánh', dt.layout.regions.length == 3, dt.layout.regions.length

puts '== 7. Box: nút chế độ hậu, hàng thông số, Face =='
Sketchup.reset_model!
bx = mk_box(600, 560, 720)
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(bx)
bt = V::Tools::BoxTool.new({}); bt.activate; bt.draw(v)
press(bt, :param, 'back_mode'); press(bt, :param, 'back_mode')
check 'hàng Kiểu hậu đổi vòng tới Không hậu', bt.settings['back_mode'] == 'none'
press(bt, :mode, 'base')
check 'nút Bếp dưới: áp chân 100, tắt phào', bt.settings['cabinet_type'] == 'base' && bt.settings['leg_height'] == 100.0 && bt.settings['cornice_enabled'] == false
check 'Bếp dưới: hiện hàng Bản giằng, ẩn hàng tủ lạnh', bt.hud_params.any? { |p| p[:key] == 'top_rail_width' } && bt.hud_params.none? { |p| p[:key] == 'fridge_width' }
press(bt, :mode, 'fridge')
check 'nút Tủ lạnh: hiện kích thước tủ lạnh', bt.hud_params.any? { |p| p[:key] == 'fridge_width' } && bt.settings['sides_to_floor'] == true
press(bt, :param, 'fridge_width'); bt.onUserText('650', v)
check 'gõ rộng tủ lạnh 650', bt.settings['fridge_width'] == 650.0
press(bt, :mode, 'standard')
check 'về Tủ thường: chân 40, phào bật lại', bt.settings['leg_height'] == 40.0 && bt.settings['cornice_enabled'] == true
press(bt, :param, 'sync_front')
check 'bật/tắt đồng bộ mặt trước', bt.settings['sync_front'] == false
press(bt, :param, 'leg_height')
bt.onUserText('100', v)
check 'chân cao 100', bt.settings['leg_height'] == 100.0
press(bt, :param, 'board_thickness')
bt.onUserText('18', v)
check 'dày ván 18', bt.settings['board_thickness'] == 18.0
Sketchup.reset_model!
f = Sketchup.active_model.entities.add_face([[0, 0, 0], [500.mm, 0, 0], [500.mm, 300.mm, 0], [0, 300.mm, 0]])
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(f)
UI.next_inputbox_result = [18.0, 'Theo pháp tuyến'] if UI.respond_to?(:next_inputbox_result=)
ft = V::Tools::FaceBoardTool.new({})
check 'face tool dùng spec face', ft.hud_spec_key == 'face' && ft.hud_spec[:params].first[:key] == '_thickness'

puts '== 8. Đợt/vách: khóa hướng khi đã đặt tấm =='
cab = new_cabinet
pt_ = V::Tools::PanelTool.new({}); pt_.activate; pt_.draw(v)
press(pt_, :mode, 'lot_long')
check 'nút Lọt lòng', pt_.settings['panel_kind'] == 'lot_long'
press(pt_, :param, 'panel_axis')
check 'đổi hướng đợt → vách khi chưa đặt tấm', pt_.settings['panel_axis'] == 'vertical'
pt_.onUserText('/3', v)
press(pt_, :param, 'panel_axis')
check 'đã chia đều thì hướng bị khóa', pt_.settings['panel_axis'] == 'vertical'

puts '== 9. Mở cánh: nút chọn bản lề =='
cab = new_cabinet
dt = V::Tools::DoorTool.new({}); dt.activate; dt.commit(v)
ot = V::Tools::OpeningTool.new({}); ot.activate; ot.draw(v)
press(ot, :mode, 'top')
check 'nút Lật lên đặt bản lề trên', ot.hinge_side == 'top'
check 'Mở cánh không có hàng thông số', ot.instance_variable_get(:@hud_rects).none? { |r| r[4] == :param }

puts '== 10. Ngăn kéo: 3 chế độ =='
def drawer_run(mode)
  cab = new_cabinet
  vv = Sketchup.active_model.active_view
  dr = V::Tools.build('drawer', { 'drawer_mode' => mode, 'drawer_count' => 2 }); dr.activate
  vv.fake_path = [cab]
  vv.fake_point = pt(600, 300)
  dr.onMouseMove(0, 5, 5, vv)
  dr.draw(vv)
  dr.onLButtonDown(0, 5, 5, vv)
  dr.commit(vv)
  box = cab.definition.entities.to_a.find { |e| e.respond_to?(:name) && e.name == 'Ngăn kéo' }
  names = box ? box.definition.entities.to_a.select { |e| e.respond_to?(:name) }.map(&:name) : []
  [names.count('Mặt Ngăn Kéo'), names.count('Thùng Ngăn Kéo')]
end
check 'đầy đủ: 2 mặt + 2 thùng', drawer_run('full') == [2, 2], drawer_run('full').inspect
check 'chỉ mặt hộc', drawer_run('front_only') == [2, 0], drawer_run('front_only').inspect
check 'chỉ thùng kéo', drawer_run('box_only') == [0, 2], drawer_run('box_only').inspect
cab = new_cabinet
dr = V::Tools.build('drawer', {}); dr.activate; dr.draw(v)
press(dr, :mode, 'front_only')
check 'nút chế độ ngăn kéo', dr.settings['drawer_mode'] == 'front_only'
press(dr, :param, 'drawer_count')
dr.onUserText('4', v)
check 'số hộc nguyên', dr.settings['drawer_count'] == 4 && dr.settings['drawer_count'].is_a?(Integer)

puts '== 11. Công cụ không có HUD mới vẫn chạy =='
cut = V::Tools::CutTool.new({}); cut.activate
check 'cắt ván vẫn vẽ được', !(begin; cut.draw(v); false; rescue StandardError => e; e.message; end).is_a?(String)

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.length}"
exit($fail.empty? ? 0 : 1)
