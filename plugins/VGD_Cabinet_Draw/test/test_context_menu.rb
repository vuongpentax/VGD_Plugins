# Test menu chuột phải "VGD Cabinet ▸" (beta.17): danh sách theo loại tủ/cánh/công cụ, lệnh đổi nhanh, Chia nhanh, đăng ký một lần.
# Chạy: ruby test_context_menu.rb [thư mục runtime]
$stdout.sync = true
RT = File.expand_path(ARGV[0] || '../runtime/VGD_Cabinet_Draw', __dir__)
require 'tmpdir'
require_relative 'mock_su'
$LOAD_PATH.unshift(__dir__)
ENV['APPDATA'] = Dir.mktmpdir('vgdappdata')
load File.join(RT, 'main.rb')
V = VGD_Cabinet_Draw
def cm; V::ContextMenu; end
$pass = 0; $fail = []
def check(name, cond, extra = nil)
  if cond then $pass += 1 else $fail << "#{name} #{extra}"; puts "FAIL: #{name} #{extra}" end
end
V::Keys.platform = :windows

# Menu giả: ghi lại cây mục + block để chạy thử.
class FakeMenu
  attr_reader :entries
  def initialize; @entries = []; end
  def add_item(label, &block); e = { label: label, block: block }; @entries << e; e; end
  def add_submenu(label); m = FakeMenu.new; @entries << { label: label, sub: m }; m; end
  def add_separator; @entries << { separator: true }; end
  def set_validation_proc(item, &block); item[:validation] = block; end
  def labels; @entries.reject { |e| e[:separator] }.map { |e| e[:label] }; end
  def find(label); @entries.find { |e| e[:label] == label }; end
  def dig(*path)
    node = self
    path.each { |l| e = node.find(l); return nil unless e; node = e[:sub] || e }
    node
  end
end

def mk_box(w, d, h)
  g = Sketchup.active_model.entities.add_group; g.name = 'Box'
  f = g.entities.add_face([[0, 0, 0], [w.mm, 0, 0], [w.mm, d.mm, 0], [0, d.mm, 0]])
  f.reverse! if f.normal.z < 0
  f.pushpull(h.mm); g
end

def new_cabinet(type = 'standard', w = 1200, d = 500, h = 2000)
  Sketchup.reset_model!
  opts = { 'front_normal' => [0, -1, 0], 'cabinet_type' => type }.merge(V::Schema::TYPE_PRESETS[type] || {})
  cab = V::Geometry.cabinet_from_box(mk_box(w, d, h), opts)
  Sketchup.active_model.selection.clear
  Sketchup.active_model.selection.add(cab)
  cab
end

def menu_for_selection
  m = FakeMenu.new
  shown = cm.populate(m)
  [m, shown]
end

UI.next_answer = nil
cm.manual_choice = nil; cm.confirm_answer = true

# --- 1. Đăng ký một lần ---
count_before = UI.context_handlers.length
check 'đã đăng ký đúng 1 handler khi nạp', count_before == 1, count_before
V.start; V.start; V.register_context_menu
check 'gọi lại không nhân đôi', UI.context_handlers.length == count_before
V.reload!
check 'reload! không nhân đôi', UI.context_handlers.length == count_before
CM_RELOADED = true
cm.manual_choice = nil; cm.confirm_answer = true

# Giả lập SketchUp đang chạy bản cũ: start đã chạy nhưng chưa đăng ký menu; nạp bản mới (Tải lại) phải đăng ký được.
V.instance_variable_set(:@ctx_registered, nil)
UI.context_handlers.clear
V.reload!
check 'nạp lại khi bản cũ đang chạy: menu chuột phải vẫn được đăng ký', UI.context_handlers.length == 1, UI.context_handlers.length
cm.manual_choice = nil; cm.confirm_answer = true

# --- 2. Không phải tủ -> không hiện menu ---
Sketchup.reset_model!
plain = mk_box(300, 300, 300)
Sketchup.active_model.selection.add(plain)
m, shown = menu_for_selection
check 'đối tượng thường: không thêm menu', !shown && m.entries.empty?
Sketchup.active_model.selection.clear
m, shown = menu_for_selection
check 'không chọn gì: không thêm menu', !shown && m.entries.empty?

# --- 3. Tủ tùy biến (loại standard) ---
cab = new_cabinet('standard')
m, shown = menu_for_selection
check 'tủ thường: có menu VGD Cabinet', shown && m.labels == ['VGD Cabinet']
root_menu = m.dig('VGD Cabinet')
labels = root_menu.labels
%w[Sửa\ tủ… Chia\ cánh… Thêm\ đợt\ /\ vách… Thêm\ ngăn\ kéo… Mở\ tất\ cả\ cánh… Đóng\ tất\ cả\ cánh Đặt\ tay\ nắm\ tự\ động Đổi\ loại\ tủ].each do |l|
  check "tủ thường có mục #{l}", labels.include?(l), labels.inspect
end
check 'tủ thường: Hông chạm đất / đụng trần / khoang ngăn kéo', %w[Hông\ chạm\ đất Hông\ đụng\ trần Thêm\ khoang\ ngăn\ kéo…].all? { |l| labels.include?(l) }
check 'tủ thường: không có mục của bếp/tủ lạnh', (labels & ['Nóc', 'Chân cao', 'Chia nhanh', 'Xà treo', 'Hiện khối tham chiếu']).empty?
check 'Đổi loại tủ có 4 loại', root_menu.dig('Đổi loại tủ').labels.length == 4
check 'loại hiện tại được tick', root_menu.dig('Đổi loại tủ').find('Tủ tùy biến')[:validation].call == 8
check 'mục không tick trả 0 (bỏ tick)', (root_menu.dig('Đổi loại tủ').find('Tủ bếp dưới')[:validation].call & 8) == 0

# --- 4. Đổi loại tủ: dựng lại, một bước Undo, dữ liệu đổi ---
ops_before = Sketchup.active_model.respond_to?(:operations_log) ? Sketchup.active_model.operations_log.length : nil
root_menu.dig('Đổi loại tủ').find('Tủ bếp dưới')[:block].call
check 'đổi sang bếp dưới: dữ liệu loại tủ', V::ModelData.params(cab)['cabinet_type'] == 'base', V::ModelData.params(cab)['cabinet_type']
check 'đổi sang bếp dưới: chân 100', V::Rebuild.settings_of(cab)['leg_height'] == 100.0
check 'sau đổi tủ vẫn được chọn', Sketchup.active_model.selection.include?(cab)
check 'không có hộp thoại lỗi', UI.msgs.none? { |t| t.to_s.include?('Không đổi được') }, UI.msgs.last

# --- 5. Bếp dưới ---
m, _ = menu_for_selection
labels = m.dig('VGD Cabinet').labels
check 'bếp dưới: Nóc / Chân cao / Chia nhanh / chậu rửa', ['Nóc', 'Chân cao', 'Chia nhanh', 'Tủ chậu rửa (bỏ hậu)'].all? { |l| labels.include?(l) }, labels.inspect
check 'bếp dưới: không có Xà treo', !labels.include?('Xà treo')
leg = m.dig('VGD Cabinet', 'Chân cao')
check 'chân cao 3 mức', leg.labels == ['100 mm', '120 mm', '150 mm']
check 'chân 100 đang tick', leg.find('100 mm')[:validation].call == 8
leg.find('150 mm')[:block].call
check 'chân cao 150 áp dụng', V::Rebuild.settings_of(cab)['leg_height'] == 150.0
m, _ = menu_for_selection
m.dig('VGD Cabinet', 'Nóc').find('Nóc nguyên')[:block].call
check 'nóc nguyên áp dụng', V::Rebuild.settings_of(cab)['top_mode'] == 'full'
m, _ = menu_for_selection
m.dig('VGD Cabinet').find('Tủ chậu rửa (bỏ hậu)')[:block].call
check 'chậu rửa: bỏ hậu', cm.back_removed?(cab)
check 'chậu rửa: thùng tủ không còn tấm hậu', V::Interior.containers(V::Geometry.shell_for(cab)).none? { |e| V::Interior.role_of(e) == 'back' }
m, _ = menu_for_selection
check 'chậu rửa đang tick', m.dig('VGD Cabinet').find('Tủ chậu rửa (bỏ hậu)')[:validation].call == 8
m.dig('VGD Cabinet').find('Tủ chậu rửa (bỏ hậu)')[:block].call
check 'bỏ tick: có hậu lại', !cm.back_removed?(cab) && V::Interior.containers(V::Geometry.shell_for(cab)).any? { |e| V::Interior.role_of(e) == 'back' }

# --- 6. Chia nhanh bếp dưới ---
def drawers_count(root); cm.drawer_fronts_of(root).length; end
def run_split(cab, label)
  m, _ = menu_for_selection
  m.dig('VGD Cabinet', 'Chia nhanh').find(label)[:block].call
end
run_split(cab, '3 ngăn kéo đều')
check '3 ngăn kéo đều: 3 mặt hộc', drawers_count(cab) == 3, drawers_count(cab)
check '3 ngăn kéo đều: không còn cánh', V::Operations.doors_of(cab).empty?
check 'ngăn kéo có bước dựng lại', V::Rebuild.ops(cab).any? { |op| op['type'] == 'drawer' }
run_split(cab, '2 cánh')
check '2 cánh: 2 cánh, hết ngăn kéo', V::Operations.doors_of(cab).length == 2 && drawers_count(cab) == 0, [V::Operations.doors_of(cab).length, drawers_count(cab)].inspect
types = V::Operations.doors_of(cab).map { |d| V::Operations.opening_type_of(d) }.sort
check '2 cánh: bản lề trái + phải', types == %w[left right], types.inspect
run_split(cab, '1 kéo trên + 2 cánh dưới')
doors = V::Operations.doors_of(cab)
check '1 kéo + 2 cánh: 3 vùng cánh', doors.length == 3, doors.length
check '1 kéo + 2 cánh: một vùng ngăn kéo', doors.map { |d| V::Operations.opening_type_of(d) }.sort == %w[drawer left right], doors.map { |d| V::Operations.opening_type_of(d) }.inspect
check '1 kéo + 2 cánh: có thùng hộc (box_only)', V::Interior.containers(V::Geometry.shell_for(cab)).size > 0 && cab.definition.entities.to_a.any? { |e| e.respond_to?(:name) && e.name == V::Operations::DRAWER_CONTAINER }
check '1 kéo + 2 cánh: có một đợt ngăn', V::Interior.members(V::Geometry.shell_for(cab))[:shelves].length == 1
# chia nhanh lần nữa thì dọn sạch đợt cũ
run_split(cab, '3 ngăn kéo đều')
check 'chia nhanh lại: đợt do chia nhanh bị xóa', V::Interior.members(V::Geometry.shell_for(cab))[:shelves].empty?
check 'chia nhanh lại: 3 mặt hộc', drawers_count(cab) == 3
# Không đồng ý -> không đổi gì
cm.confirm_answer = false
run_split(cab, '2 cánh')
check 'không đồng ý: giữ nguyên 3 ngăn kéo', drawers_count(cab) == 3
cm.confirm_answer = true
# Sửa tủ dựng lại vẫn giữ kết quả chia nhanh
V::Rebuild.run(cab, V::Rebuild.settings_of(cab), V::Rebuild.dimensions_of(cab), [])
check 'dựng lại tủ vẫn còn 3 mặt hộc', drawers_count(cab) == 3, drawers_count(cab)

# --- 7. Bếp trên ---
cab = new_cabinet('standard', 800, 350, 720)
cm.change_type([cab], 'wall')
m, _ = menu_for_selection
labels = m.dig('VGD Cabinet').labels
check 'bếp trên: Xà treo / Chiều cao / Chia nhanh', labels.include?('Xà treo') && labels.any? { |l| l.start_with?('Chiều cao') } && labels.include?('Chia nhanh'), labels.inspect
check 'bếp trên: không có Chân cao', !labels.include?('Chân cao')
check 'xà treo đang tick', m.dig('VGD Cabinet').find('Xà treo')[:validation].call == 8
m.dig('VGD Cabinet').find('Xà treo')[:block].call
check 'tắt xà treo', V::Rebuild.settings_of(cab)['hang_rail'] == false
z_before = cab.transformation.origin.z
h_menu = m.dig('VGD Cabinet', 'Chiều cao (giữ nguyên đỉnh tủ)')
m, _ = menu_for_selection
m.dig('VGD Cabinet', 'Chiều cao (giữ nguyên đỉnh tủ)').find('900 mm')[:block].call
check 'chiều cao 900', (V::Rebuild.dimensions_of(cab)[2] - 900).abs < 0.5, V::Rebuild.dimensions_of(cab).inspect
check 'giữ nguyên đỉnh tủ (gốc hạ đúng 180)', ((cab.transformation.origin.z - z_before) + 180.mm).abs < 0.01.mm, (cab.transformation.origin.z - z_before).to_mm
def run_wall(cab, label)
  m, _ = menu_for_selection
  m.dig('VGD Cabinet', 'Chia nhanh').find(label)[:block].call
end
run_wall(cab, 'Cánh lật lên')
d = V::Operations.doors_of(cab)
check 'cánh lật lên: 1 cánh bản lề trên', d.length == 1 && V::Operations.opening_type_of(d.first) == 'top'
run_wall(cab, '2 cánh mở')
check '2 cánh mở: 2 cánh', V::Operations.doors_of(cab).length == 2
run_wall(cab, 'Đợt chia đều (không cánh)')
check 'đợt chia đều: hết cánh, có 2 đợt', V::Operations.doors_of(cab).empty? && V::Interior.members(V::Geometry.shell_for(cab))[:shelves].length == 2, V::Interior.members(V::Geometry.shell_for(cab))[:shelves].length

# --- 8. Thùng tủ lạnh ---
cab = new_cabinet('standard', 900, 700, 2200)
cm.change_type([cab], 'fridge')
m, _ = menu_for_selection
labels = m.dig('VGD Cabinet').labels
check 'tủ lạnh: Cỡ / Khe / khối tham chiếu', labels.any? { |l| l.start_with?('Cỡ tủ lạnh') } && labels.any? { |l| l.start_with?('Khe') } && labels.include?('Hiện khối tham chiếu'), labels.inspect
sizes = m.dig('VGD Cabinet', 'Cỡ tủ lạnh (tham khảo, rộng × cao × sâu)')
check 'cỡ tủ lạnh có 4 cỡ', sizes.labels.length == 4
sizes.find('Vừa 700 × 1800 × 650')[:block].call
check 'đã áp cỡ tủ lạnh vừa', V::Rebuild.settings_of(cab)['fridge_width'] == 700.0
m, _ = menu_for_selection
m.dig('VGD Cabinet', 'Khe (hai bên / trên / sau)').find('Rộng rãi (50 / 100 / 50)')[:block].call
check 'đã áp khe tủ lạnh', V::Rebuild.settings_of(cab)['fridge_side_gap'] == 50.0 && V::Rebuild.settings_of(cab)['fridge_top_gap'] == 100.0
# cỡ quá lớn so với tủ -> báo lỗi, tủ giữ nguyên
UI.msgs.clear
m, _ = menu_for_selection
m.dig('VGD Cabinet', 'Cỡ tủ lạnh (tham khảo, rộng × cao × sâu)').find('Side-by-side 900 × 1800 × 750')[:block].call
check 'cỡ không vừa: báo lỗi', UI.msgs.any? { |t| t.to_s.include?('Không đổi được') }, UI.msgs.inspect
check 'cỡ không vừa: tủ giữ nguyên', V::Rebuild.settings_of(cab)['fridge_width'] == 700.0
m, _ = menu_for_selection
ref = cm.reference_group(cab)
if ref
  was = ref.visible?
  m.dig('VGD Cabinet').find('Hiện khối tham chiếu')[:block].call
  check 'bật/tắt khối tham chiếu', cm.reference_group(cab).visible? == !was
else
  check 'tủ lạnh có khối tham chiếu', false, 'không thấy nhóm Tủ lạnh (tham chiếu)'
end

# --- 9. Chọn nhiều tủ ---
Sketchup.reset_model!
a = V::Geometry.cabinet_from_box(mk_box(600, 500, 2000), { 'front_normal' => [0, -1, 0] })
b = V::Geometry.cabinet_from_box(mk_box(600, 500, 2000), { 'front_normal' => [0, -1, 0] })
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(a); Sketchup.active_model.selection.add(b)
m, _ = menu_for_selection
m.dig('VGD Cabinet', 'Đổi loại tủ').find('Tủ bếp dưới')[:block].call
check 'nhiều tủ: cả hai đổi loại', V::ModelData.params(a)['cabinet_type'] == 'base' && V::ModelData.params(b)['cabinet_type'] == 'base'
b2 = V::Geometry.cabinet_from_box(mk_box(600, 500, 720), { 'front_normal' => [0, -1, 0] })
cm.change_type([b2], 'wall')
[a, b, b2].each { |c| Sketchup.active_model.selection.add(c) }
m, _ = menu_for_selection
labels = m.dig('VGD Cabinet').labels
check 'nhiều tủ khác loại: chỉ lệnh chung', !labels.include?('Chân cao') && !labels.include?('Xà treo') && labels.include?('Đổi loại tủ'), labels.inspect

# --- 10. Cánh ---
cab = new_cabinet('base', 800, 560, 800)
cm.quick_split([cab], '2 cánh') { |root| cm.split_two_doors(root) }
doors = V::Operations.doors_of(cab)
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(doors.first)
m, shown = menu_for_selection
check 'chọn cánh: có menu', shown
dl = m.dig('VGD Cabinet').labels
check 'menu cánh: mở/đóng/bản lề/tay nắm', ['Mở cánh…', 'Đóng cánh', 'Bản lề', 'Đặt tay nắm', 'Xóa tay nắm'].all? { |l| dl.include?(l) }, dl.inspect
check 'menu cánh: không có lệnh của tủ', !dl.include?('Đổi loại tủ')
m.dig('VGD Cabinet').find('Mở cánh…')[:block].call
open_tool = Sketchup.active_model.instance_variable_get(:@tool)
check 'Mở cánh…: bật công cụ mở cánh rê chuột với cánh đang chọn', open_tool.is_a?(V::Tools::OpeningTool) && open_tool.instance_variable_get(:@targets).include?(doors.first), open_tool.class.to_s
Sketchup.active_model.select_tool(nil)
cm.open_doors(doors, 90.0, 'Mở cánh')
check 'mở cánh 90°', V::Operations.door_angle(doors.first) == 90.0, V::Operations.door_angle(doors.first)
m.dig('VGD Cabinet').find('Đóng cánh')[:block].call
check 'đóng cánh', V::Operations.door_angle(doors.first) == 0.0
m.dig('VGD Cabinet', 'Bản lề').find('Lật lên (bản lề trên)')[:block].call
check 'đổi bản lề sang trên', V::Operations.opening_type_of(doors.first) == 'top'
json = JSON.parse(cab.get_attribute(V::Schema::DICTIONARY, 'door_layout_json'))
check 'bản lề được ghi vào bố cục', json['regions'].any? { |r| r['opening_type'] == 'top' }
m.dig('VGD Cabinet').find('Đặt tay nắm')[:block].call
check 'đặt tay nắm', V::Operations.handle_groups(doors.first).length == 1, V::Operations.handle_groups(doors.first).length
m.dig('VGD Cabinet').find('Xóa tay nắm')[:block].call
check 'xóa tay nắm', V::Operations.handle_groups(doors.first).empty?
# lệnh tủ: mở tất cả cánh + tay nắm tự động
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(cab)
m, _ = menu_for_selection
m.dig('VGD Cabinet').find('Đặt tay nắm tự động')[:block].call
check 'tay nắm tự động cho mọi cánh', V::Operations.doors_of(cab).all? { |dd| V::Operations.handle_groups(dd).length == 1 }
cm.angle_answer = 45.0
m.dig('VGD Cabinet').find('Mở tất cả cánh…')[:block].call
check 'mở tất cả cánh 45°', V::Operations.doors_of(cab).all? { |dd| V::Operations.door_angle(dd) == 45.0 }
m.dig('VGD Cabinet').find('Đóng tất cả cánh')[:block].call
check 'đóng tất cả cánh', V::Operations.doors_of(cab).all? { |dd| V::Operations.door_angle(dd) == 0.0 }
cm.angle_answer = nil

# --- 11. Tấm chỉnh tay -> hỏi, Cancel thì giữ nguyên ---
cab = new_cabinet('standard')
shell = V::Geometry.shell_for(cab)
panel = V::Interior.containers(shell).find { |e| V::Interior.role_of(e) == 'top' }
panel.entities.add_face([[0, 0, 0], [10.mm, 0, 0], [10.mm, 10.mm, 0]]) rescue nil
big = V::Rebuild.hand_edited(cab)
if big.empty?
  puts 'LƯU Ý: mock không giả lập được tấm chỉnh tay bằng cách này, bỏ qua mục 11'
else
  cm.manual_choice = :cancel
  cm.change_type([cab], 'base')
  check 'Cancel: loại tủ giữ nguyên', V::ModelData.params(cab)['cabinet_type'] != 'base'
  cm.manual_choice = nil
end

# --- 12. Menu trong công cụ ---
cab = new_cabinet('base', 800, 560, 800)
dt = V::Tools.build('door', {}); dt.activate
m = FakeMenu.new
check 'công cụ Cánh có getMenu', dt.respond_to?(:getMenu)
V::ContextMenu.populate_tool(m, dt)
tl = m.dig('VGD Cabinet').labels
check 'menu công cụ Cánh', ['Loại mở của vùng', 'Chọn tất cả vùng', 'Bỏ chọn vùng', 'Mở bảng Setting'].all? { |l| tl.include?(l) }, tl.inspect
check 'menu công cụ KHÔNG chứa lệnh đã có phím', (tl & ['Gộp vùng', 'Hoàn tác', 'Tab', 'Enter', 'Esc']).empty? && tl.none? { |l| l =~ /\(G\)|Backspace|Tab|Shift/ }
m.dig('VGD Cabinet').find('Chọn tất cả vùng')[:block].call
check 'chọn tất cả vùng', dt.instance_variable_get(:@selected) == dt.instance_variable_get(:@layout).ids
m.dig('VGD Cabinet').find('Bỏ chọn vùng')[:block].call
check 'bỏ chọn vùng', dt.instance_variable_get(:@selected).empty?
layout = dt.instance_variable_get(:@layout)
layout.split_even(layout.ids.first, 'vertical', 2)
dt.instance_variable_set(:@selected, [layout.ids.first])
m.dig('VGD Cabinet', 'Loại mở của vùng').find('Bản lề phải')[:block].call
check 'đặt loại mở cho vùng đang chọn', layout.find(layout.ids.first)['opening_type'] == 'right', layout.regions.inspect
dt.instance_variable_set(:@selected, [])
UI.msgs.clear
m.dig('VGD Cabinet', 'Loại mở của vùng').find('Bản lề trái')[:block].call
check 'không trỏ vùng nào: không đổi, không lỗi', layout.regions.count { |r| r['opening_type'] == 'left' } == 0
# Mở công cụ -> menu đối tượng không xuất hiện (menu công cụ đã đủ)
V.instance_variable_set(:@active_tool, dt)
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(cab)
m2, shown2 = menu_for_selection
check 'đang dùng công cụ VGD: không thêm menu theo đối tượng', !shown2 && m2.entries.empty?
ot = V::Tools.build('opening', {}); ot.activate
m = FakeMenu.new; V::ContextMenu.populate_tool(m, ot)
check 'công cụ Mở cánh có lệnh đóng tất cả', m.dig('VGD Cabinet').labels.include?('Đóng tất cả cánh của tủ đang chọn')
bt = V::Tools.build('panel', {}); bt.activate
m = FakeMenu.new; V::ContextMenu.populate_tool(m, bt)
check 'công cụ Đợt/vách chỉ có mục Setting', m.dig('VGD Cabinet').labels == ['Mở bảng Setting'], m.dig('VGD Cabinet').labels.inspect
V.instance_variable_set(:@active_tool, nil)

puts '== 12. Cánh tự động theo hồi (menu) =='
cab = new_cabinet('standard', 1200, 500, 2000)
sh = V::Geometry.shell_for(cab)
inner = V::Interior.inner(sh)
op = { 'type' => 'panel', 'axis' => 'vertical', 'kind' => 'thong_thuy', 'thickness_mm' => 17.5, 'limit' => false,
       'anchor' => V::Rebuild.anchor_of(sh, (inner.x0 + inner.x1) / 2, (inner.z0 + inner.z1) / 2),
       'setback_mm' => 0.0, 'door_fit' => 'phu', 'mode' => 'free', 'offsets' => [382.5] }
op['op'] = V::Rebuild.record(cab, op)
V::Rebuild.place_panels(cab, sh, op)
Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(cab)
m, _ = menu_for_selection
check 'menu tủ có Cánh tự động theo hồi', m.dig('VGD Cabinet').labels.include?('Cánh tự động theo hồi'), m.dig('VGD Cabinet').labels.inspect
m.dig('VGD Cabinet').find('Cánh tự động theo hồi')[:block].call
check 'Cánh tự động theo hồi: 2 cánh theo 1 vách', V::Operations.doors_of(cab).length == 2, V::Operations.doors_of(cab).length.to_s

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.size}"
exit($fail.empty? ? 0 : 1)
