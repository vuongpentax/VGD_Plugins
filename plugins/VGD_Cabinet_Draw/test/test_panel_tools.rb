# Test beta.18: tấm sạch (rãnh hậu không khoét), tìm tấm trùng, chuẩn hóa tên ván.
# Chạy: ruby test_panel_tools.rb [thư mục runtime]
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
V::Keys.platform = :windows
def mk_box(w, d, h)
  g = Sketchup.active_model.entities.add_group; g.name = 'Box'
  f = g.entities.add_face([[0, 0, 0], [w.mm, 0, 0], [w.mm, d.mm, 0], [0, d.mm, 0]])
  f.reverse! if f.normal.z < 0
  f.pushpull(h.mm); g
end
def new_cabinet
  Sketchup.reset_model!
  cab = V::Geometry.cabinet_from_box(mk_box(800, 500, 2000), { 'front_normal' => [0, -1, 0], 'leg_height' => 0, 'ceiling_strip_height' => 0 })
  Sketchup.active_model.selection.clear; Sketchup.active_model.selection.add(cab)
  cab
end
def add_shelf(cab, offset_mm)
  shell = V::Geometry.shell_for(cab)
  settings = V::Rebuild.settings_of(cab)
  inner = V::Interior.inner(shell)
  op = { 'type' => 'panel', 'axis' => 'horizontal', 'kind' => 'thong_thuy', 'thickness_mm' => 17.5, 'limit' => false,
         'anchor' => V::Rebuild.anchor_of(shell, (inner.x0 + inner.x1) / 2, (inner.z0 + inner.z1) / 2),
         'setback_mm' => 20.0, 'door_fit' => 'phu', 'mode' => 'free', 'offsets' => [offset_mm] }
  op['op'] = V::Rebuild.record(cab, op)
  V::Rebuild.place_panels(cab, shell, op)
end

# --- 1. Tấm sạch ---
cab = new_cabinet
shell = V::Geometry.shell_for(cab)
parts = V::Interior.containers(shell).select { |e| V::Interior.role_of(e) }
roles = parts.map { |e| V::Interior.role_of(e) }
%w[side_left side_right top bottom].each do |role|
  entity = parts.find { |e| V::Interior.role_of(e) == role }
  b = V::Interior.box_of(entity)
  face = entity.entities.grep(Sketchup::Face).first rescue nil
  check "#{role}: có mặt", !entity.nil?
end
r = V::PanelModel.compute(800, 500, 2000, {})
%w[side_left side_right top bottom].each { |role| check "#{role}: mặt cắt chữ nhật (4 đỉnh)", r.parts.find { |p| p.role == role }.points.length == 4 }
back = r.parts.find { |p| p.role == 'back' }
check 'hậu giữ kích thước thật (lòng + 2 × ngậm)', (back.bounds[3] - back.bounds[0] - (800 - 35 + 2 * 8.75)).abs < 1e-6, back.bounds.inspect
# Sửa tủ dựng lại vẫn sạch
V::Rebuild.run(cab, V::Rebuild.settings_of(cab), V::Rebuild.dimensions_of(cab), [])
check 'dựng lại tủ vẫn đủ tấm vỏ', %w[side_left side_right top bottom back].all? { |ro| V::Interior.containers(V::Geometry.shell_for(cab)).any? { |e| V::Interior.role_of(e) == ro } }

# --- 2. Tìm tấm trùng ---
cab = new_cabinet
add_shelf(cab, 800)
add_shelf(cab, 1200)
UI.msgs.clear
found = V::PanelTools.find_duplicates([cab])
check 'tủ sạch: không có tấm trùng (hậu ngậm rãnh không bị báo)', found.empty?, found.map { |f| [f[:keep_label], f[:duplicate_label]] }.inspect
add_shelf(cab, 800) # trùng với đợt đầu tiên
found = V::PanelTools.find_duplicates([cab])
check 'thêm một đợt trùng: phát hiện đúng 1 cặp', found.length == 1, found.length
check 'cặp trùng đều là đợt', found.first && found.first[:keep_label] =~ /Đợt/ && found.first[:duplicate_label] =~ /Đợt/
V::PanelTools.select_duplicates([cab])
check 'đã chọn bản trùng', Sketchup.active_model.selection.length == 1 && Sketchup.active_model.selection.first == found.first[:duplicate]
check 'có thông báo kết quả', UI.msgs.last.to_s.include?('trùng')
# qua menu Extensions
V.run_panel_tool(:find_duplicates)
check 'run_panel_tool chạy được khi chọn tủ', UI.msgs.last.to_s.include?('trùng') || UI.msgs.last.to_s.include?('Không có tấm')

# --- 3. Chuẩn hóa tên ---
cab = new_cabinet
add_shelf(cab, 1200)
add_shelf(cab, 400)
add_shelf(cab, 800)
shell = V::Geometry.shell_for(cab)
V::Interior.containers(shell).each { |e| e.name = 'Group#1' if V::Interior.role_of(e) }
count = V::PanelTools.normalize_names_command([cab])
names = V::Interior.containers(shell).select { |e| V::Interior.role_of(e) }.map { |e| [V::Interior.role_of(e), e.name] }
check 'đã đổi tên các ván', count == names.length, [count, names.length].inspect
check 'tên vai trò cố định', names.include?(['side_left', 'Hông Trái']) && names.include?(['top', 'Nóc']) && names.include?(['back', 'Hậu']), names.inspect
shelves = V::Interior.containers(shell).select { |e| V::Interior.role_of(e) == 'shelf' }.sort_by { |e| V::Interior.box_of(e)[2] }
check 'đợt đánh số từ dưới lên', shelves.map(&:name) == ['Đợt 1', 'Đợt 2', 'Đợt 3'], shelves.map(&:name).inspect
check 'chạy lại không đổi gì thêm', V::PanelTools.normalize_names_command([cab]) == 0
# cánh không bị đổi tên
V::ContextMenu.quick_split([cab], '2 cánh') { |root| V::ContextMenu.split_two_doors(root) } if false
dtool = V::Tools::DoorTool.new({}); dtool.load_cabinet(cab); dtool.build_doors
before = V::Operations.doors_of(cab).map(&:name)
V::PanelTools.normalize_names([cab])
check 'cánh giữ nguyên tên (dùng để nhận diện)', V::Operations.doors_of(cab).map(&:name) == before && !before.empty?
# menu chuột phải có 2 mục mới
class FM; attr_reader :e; def initialize; @e=[]; end; def add_item(l,&b); @e<<l; x={}; x; end; def add_submenu(l); m=FM.new; @e<<[l,m]; m; end; def add_separator; end; def set_validation_proc(*); end; end
m = FM.new; V::ContextMenu.populate(m, [cab])
sub = m.e.find { |x| x.is_a?(Array) }[1]
check 'menu chuột phải có Tìm tấm trùng + Chuẩn hóa tên', sub.e.include?('Tìm tấm bị trùng') && sub.e.include?('Chuẩn hóa tên ván'), sub.e.inspect

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.size}"
exit($fail.empty? ? 0 : 1)
