# Test tủ quá khổ (beta.39): tự tách theo ngưỡng, ba kiểu liên kết, dựng hai tủ trong group 'Tủ quá khổ'.
# Chạy: ruby test_split.rb [thư mục runtime]
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
  if cond then $pass += 1 else $fail << name; puts "FAIL: #{name} #{extra}" end
end
def near(a, b, tol = 0.01); (a - b).abs <= tol; end
def mk_box(w, d, h)
  g = Sketchup.active_model.entities.add_group; g.name = 'Box'
  f = g.entities.add_face([[0, 0, 0], [w.mm, 0, 0], [w.mm, d.mm, 0], [0, d.mm, 0]]); f.reverse! if f.normal.z < 0; f.pushpull(h.mm); g
end
def groups(ents); ents.to_a.select { |e| e.is_a?(Sketchup::Group) }; end
def split_group
  groups(Sketchup.active_model.entities).find { |g| g.name == V::Split::GROUP_NAME }
end
def settings(extra = {})
  { 'front_normal' => [0, -1, 0], 'cabinet_type' => 'standard' }.merge(extra)
end
def raises_msg(re)
  yield
  false
rescue ArgumentError => e
  e.message =~ re ? true : (puts("    thông báo thực tế: #{e.message}") || false)
end

puts '== 1. Quyết định tách (thuần) =='
S = V::Schema
std = S.merge_settings(settings)
check('standard 2400 không tách (ngưỡng là > 2400)', V::Split.plan(2400.0, std).nil?)
check('standard 2401 tách thành 2100 + 301', begin
  p = V::Split.plan(2401.0, std)
  p && near(p[0].height, 2100.0) && near(p[1].height, 301.0)
end)
check('tủ bếp trên không tách', V::Split.plan(2600.0, S.merge_settings(settings('cabinet_type' => 'wall'))).nil?)
check('thùng tủ lạnh cao 2600 cũng tách', !V::Split.plan(2600.0, S.merge_settings(settings('cabinet_type' => 'fridge'))).nil?)
check('tủ trên của thùng tủ lạnh thành tủ tùy biến', V::Split.plan(2600.0, S.merge_settings(settings('cabinet_type' => 'fridge')))[1].overrides['cabinet_type'] == 'standard')
check('tủ bếp trên không tách', V::Split.plan(2600.0, S.merge_settings(settings('cabinet_type' => 'wall'))).nil?)
check('ngưỡng cài 3000 vẫn tách khi quá khổ ván (2700 > 2440)', !V::Split.plan(2700.0, S.merge_settings(settings('split_height' => 3000))).nil?)
check('ngưỡng cài 3000 và cao 2430 (dưới khổ ván): không tách', V::Split.plan(2430.0, S.merge_settings(settings('split_height' => 3000))).nil?)
check('tủ trên vượt 2440 báo lỗi khổ ván', raises_msg(/khổ ván/) { V::Split.plan(5000.0, std) })
check('cao tủ dưới ≥ cao tổng báo lỗi', raises_msg(/nhỏ hơn/) { V::Split.plan(2430.0, S.merge_settings(settings('split_lower_height' => 2430))) })
check('liên kết lạ báo lỗi', raises_msg(/Liên kết/) { V::Split.plan(2600.0, S.merge_settings(settings('split_joint' => 'xyz'))) })

puts '== 2. Thông số ghi đè theo liên kết =='
pl = V::Split.plan(2600.0, S.merge_settings(settings('split_joint' => 'xa_duoi')))
check('xà dưới: tủ dưới thay nóc bằng xà', pl[0].overrides['top_mode'] == 'rails' && pl[1].overrides['bottom_mode'] == 'full')
pl = V::Split.plan(2600.0, S.merge_settings(settings('split_joint' => 'xa_tren')))
check('xà trên: tủ trên thay đáy bằng xà, tủ dưới có nóc', pl[1].overrides['bottom_mode'] == 'rails' && pl[0].overrides['top_mode'] == 'full')
pl = V::Split.plan(2600.0, S.merge_settings(settings('split_joint' => 'dau_dinh')))
check('đấu đình: không xà, cả hai có nóc/đáy nguyên tấm', pl[0].overrides['top_mode'] == 'full' && pl[1].overrides['bottom_mode'] == 'full')
check('tủ trên không có chân', pl[1].overrides['leg_height'] == 0.0)
check('tủ dưới không có phào trần', pl[0].overrides['ceiling_strip_height'] == 0.0)

puts '== 3. Dựng trong SketchUp mô phỏng =='
Sketchup.reset_model!
box = mk_box(800, 560, 2600)
roots = V::Geometry.cabinets_from_box(box, settings('split_joint' => 'dau_dinh', 'remove_source' => true))
check('2600 mm tạo hai tủ', roots.length == 2, roots.length)
check('tạo group cha Tủ quá khổ', !split_group.nil?)
check('tủ dưới cao 2100', near(V::ModelData.params(roots[0])['height_mm'], 2100.0), V::ModelData.params(roots[0])['height_mm'])
check('tủ trên cao 500', near(V::ModelData.params(roots[1])['height_mm'], 500.0), V::ModelData.params(roots[1])['height_mm'])
check('đánh dấu phần tách', V::ModelData.params(roots[0])['split_part'] == 'lower' && V::ModelData.params(roots[1])['split_part'] == 'upper')
check('box nguồn đã xóa', !box.valid?)

Sketchup.reset_model!
roots = V::Geometry.cabinets_from_box(mk_box(800, 560, 2600), settings('split_joint' => 'xa_tren'))
upper = V::Interior.carcass(V::Geometry.shell_for(roots[1]))
lower = V::Interior.carcass(V::Geometry.shell_for(roots[0]))
check('xà trên: tủ trên có xà đáy, không có đáy', upper.key?('rail_front_bottom') && !upper.key?('bottom'), upper.keys.inspect)
check('xà trên: tủ dưới có nóc', lower.key?('top') && !lower.key?('rail_front_bottom'), lower.keys.inspect)

Sketchup.reset_model!
roots = V::Geometry.cabinets_from_box(mk_box(800, 560, 2600), settings('split_joint' => 'xa_duoi'))
lower = V::Interior.carcass(V::Geometry.shell_for(roots[0]))
upper = V::Interior.carcass(V::Geometry.shell_for(roots[1]))
check('xà dưới: tủ dưới có xà nóc, không có nóc', lower.key?('rail_front') && !lower.key?('top'), lower.keys.inspect)
check('xà dưới: tủ trên có đáy', upper.key?('bottom'), upper.keys.inspect)

puts '== 3b. Thùng tủ lạnh cao 2600 =='
Sketchup.reset_model!
fridge_roots = V::Geometry.cabinets_from_box(mk_box(900, 800, 2600), settings('cabinet_type' => 'fridge', 'split_joint' => 'dau_dinh'))
check('thùng tủ lạnh tạo hai tủ', fridge_roots.length == 2, fridge_roots.length)
check('tủ dưới giữ là thùng tủ lạnh, tủ trên là tủ tùy biến',
      V::ModelData.params(fridge_roots[0])['cabinet_type'] == 'fridge' && V::ModelData.params(fridge_roots[1])['cabinet_type'] == 'standard')

puts '== 4. Không tách và không ghi gì khi lỗi =='
Sketchup.reset_model!
single = V::Geometry.cabinets_from_box(mk_box(800, 560, 2000), settings)
check('2000 mm: một tủ, không có group cha', single.length == 1 && split_group.nil?)
Sketchup.reset_model!
check('quá khổ không tạo group khi lỗi', raises_msg(/khổ ván/) { V::Geometry.cabinets_from_box(mk_box(800, 560, 5000), settings) } && split_group.nil?)
check('dựng nhanh bằng cabinet_from_box vẫn trả về một tủ', V::Geometry.cabinet_from_box(mk_box(800, 560, 2000), settings).is_a?(Sketchup::Group))

puts '== 5. Group quá khổ: chọn, sửa, scale cả nhóm =='
Sketchup.reset_model!
roots = V::Geometry.cabinets_from_box(mk_box(800, 560, 2600), settings('split_joint' => 'dau_dinh'))
group = split_group
check('chọn group quá khổ = chọn hai tủ con', V::ModelData.cabinets_in([group]).length == 2)
sel = Sketchup.active_model.selection; sel.clear; sel.add(group)
check('lệnh Sửa tủ nhận group quá khổ', V::Tools::EditCabinetTool.cabinets_only?(sel))
group.transformation = Geom::Transformation.scaling(1.0, 1.0, 1.1) * group.transformation
UI.msgs.clear
V::AutoStretch.after_commit(Sketchup.active_model)
check('scale nhóm: group trở về không scale', !V::Geometry.split_scaled?(group))
kids = V::ModelData.cabinets_in([group])
check('scale nhóm: tủ dưới cao 2310 (2100 × 1.1)', kids.any? { |k| near(V::ModelData.params(k)['height_mm'], 2310.0, 0.05) })
check('scale nhóm: tủ trên cao 550 (500 × 1.1)', kids.any? { |k| near(V::ModelData.params(k)['height_mm'], 550.0, 0.05) })
check('scale nhóm: không có hộp thoại lỗi', UI.msgs.none? { |m| m.include?('Tự cập nhật') }, UI.msgs.inspect)

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.size}"
exit($fail.empty? ? 0 : 1)
