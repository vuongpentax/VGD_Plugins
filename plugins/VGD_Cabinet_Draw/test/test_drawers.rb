# Test bản A (beta.24): 3 loại đáy ngăn kéo + mở/đóng trượt. Chạy: ruby test_drawers.rb [thư mục runtime]
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
def near(a, b, tol = 0.01); (a - b).abs <= tol; end
def mk_box(w, d, h)
  g = Sketchup.active_model.entities.add_group; g.name = 'Box'
  f = g.entities.add_face([[0, 0, 0], [w.mm, 0, 0], [w.mm, d.mm, 0], [0, d.mm, 0]]); f.reverse! if f.normal.z < 0; f.pushpull(h.mm); g
end
def cab(opts = {})
  Sketchup.reset_model!
  c = V::Geometry.cabinet_from_box(mk_box(800, 560, 2000), { 'front_normal' => [0, -1, 0] }.merge(opts))
  sel = Sketchup.active_model.selection; sel.clear; sel.add(c)
  c
end
def bb(e); b = e.bounds; [b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z].map { |x| x.to_mm.round(3) }; end
def groups(ents); ents.to_a.select { |e| e.is_a?(Sketchup::Group) }; end
def container(c); groups(c.definition.entities).find { |e| e.name == 'Ngăn kéo' }; end
def boxes(c); groups(container(c).definition.entities).select { |g| g.name == 'Thùng Ngăn Kéo' }; end
def fronts(c); groups(container(c).definition.entities).select { |g| g.name == 'Mặt Ngăn Kéo' }; end
def box_part(box, name); groups(box.definition.entities).find { |g| g.name == name }; end
def overlap(a, b)
  d = (0..2).map { |i| [[a[i + 3], b[i + 3]].min - [a[i], b[i]].max, 0].max }
  d.inject(:*) > 1e-3 ? d.map { |x| x.round(2) } : nil
end
def make_drawers(settings)
  c = cab
  V::Operations.build_drawers(c, V::Schema.merge_settings({ 'drawer_count' => 2, 'drawer_front_height' => 0 }.merge(settings)), nil)
  c
end
def part_boxes(c)
  boxes(c).first.then { |b| groups(b.definition.entities).map { |g| [g.name, bb(g)] }.to_h }
end
V::Keys.platform = :windows
mm = ->(x) { x.mm }

puts '== 1. DrawerParts (ruby thuần) =='
base = { slide: 'side', x0: 0.0, x1: 600.mm, y0: 0.0, y1: 500.mm, z0: 0.0, top: 150.mm, side: 15.mm, bottom_t: 8.mm, lift: 13.mm, groove_depth: 8.mm, groove_height: 10.mm }
under = V::DrawerParts.parts(base.merge(bottom: 'under'))
check 'đặt dưới: đáy phủ cả chiều rộng và sâu', under.find { |p| p[0] == 'Đáy' }.values_at(2, 3, 4, 5) == [0.0, 600.mm, 0.0, 500.mm]
inset = V::DrawerParts.parts(base.merge(bottom: 'inset'))
bi = inset.find { |p| p[0] == 'Đáy' }
check 'lọt: đáy nằm giữa hai hông (x từ 15 tới 585)', near(bi[2].to_mm, 15) && near(bi[3].to_mm, 585)
check 'lọt: đáy giữa mặt trước và mặt sau (y 15..485)', near(bi[4].to_mm, 15) && near(bi[5].to_mm, 485)
check 'lọt: đáy cùng mép dưới các thành (z 0..8)', near(bi[6].to_mm, 0) && near(bi[7].to_mm, 8)
check 'lọt: hông cao hết từ mép dưới', inset.find { |p| p[0] == 'Hông Trái' }.values_at(6, 7) == [0.0, 150.mm]
groove = V::DrawerParts.parts(base.merge(bottom: 'groove', bottom_t: 6.mm))
bg = groove.find { |p| p[0] == 'Đáy' }
check 'ngậm rãnh: đáy chồng vào thành 8 mm mỗi phía', near(bg[2].to_mm, 15 - 8) && near(bg[3].to_mm, 585 + 8) && near(bg[4].to_mm, 15 - 8) && near(bg[5].to_mm, 485 + 8)
check 'ngậm rãnh: đáy cao 10 mm tính từ mép dưới, dày 6', near(bg[6].to_mm, 10) && near(bg[7].to_mm, 16)
under_mount = V::DrawerParts.parts(base.merge(slide: 'under', bottom: 'inset'))
check 'ray âm lọt: đáy nâng 13 mm', near(under_mount.find { |p| p[0] == 'Đáy' }[6].to_mm, 13)
begin
  V::DrawerParts.parts(base.merge(bottom: 'groove', groove_depth: 14.mm)); ok = false
rescue ArgumentError => e
  ok = e.message.include?('ngậm rãnh')
end
check 'rãnh quá sâu bị từ chối', ok
begin
  V::DrawerParts.parts(base.merge(bottom: 'groove', groove_height: 150.mm)); ok = false
rescue ArgumentError => e
  ok = e.message.include?('quá cao')
end
check 'rãnh quá cao bị từ chối', ok
check 'loại lạ → đặt dưới', V::DrawerParts.bottom_type('xyz') == 'under'

puts '== 2. Dựng thùng theo 3 loại đáy =='
%w[under inset groove].each do |type|
  c = make_drawers('drawer_bottom_type' => type, 'drawer_bottom_thickness' => 8)
  pb = part_boxes(c)
  check "#{type}: đủ 5 tấm thùng", pb.keys.sort == ['Hông Phải', 'Hông Trái', 'Mặt Sau', 'Mặt Trước', 'Đáy'].sort, pb.keys.inspect
  clash = pb.keys.combination(2).map { |a, b| [a, b, overlap(pb[a], pb[b])] }.select { |x| x[2] }
  if type == 'groove'
    check 'groove: chỉ đáy giao với 4 thành (ngậm rãnh), các thành không xuyên nhau', clash.all? { |a, b, _| a == 'Đáy' || b == 'Đáy' }, clash.inspect
  else
    check "#{type}: các tấm không xuyên nhau", clash.empty?, clash.inspect
  end
  check "#{type}: lưu loại đáy vào thùng", boxes(c).first.get_attribute('VGD_Cabinet_Draw', 'params_json').to_s.include?(type) || V::ModelData.params(boxes(c).first)['bottom'] == type
end
c = make_drawers('drawer_bottom_type' => 'inset', 'drawer_slide' => 'under')
pb = part_boxes(c)
check 'ray âm + đáy lọt dựng được, đáy nâng so với mép dưới hông', pb['Đáy'][2] > pb['Hông Trái'][2] + 12.9, [pb['Đáy'][2], pb['Hông Trái'][2]].inspect

puts '== 3. Mở / đóng trượt =='
oy = ->(e) { e.transformation.origin.y.to_mm }
c = make_drawers({})
fr = fronts(c); bx = boxes(c)
check 'có 2 mặt hộc + 2 thùng', fr.length == 2 && bx.length == 2
f0_y = oy.call(fr[0]); b0_y = oy.call(bx[0])
max = V::DrawerSlide.max_mm(bx[0])
check 'tầm trượt = sâu thùng − 20', max > 100 && near(max, V::ModelData.params(bx[0])['depth_mm'].to_f - 20.0), max
check 'mặt hộc có cùng tầm trượt với thùng', near(V::DrawerSlide.max_mm(fr[0]), max)
moved = V::DrawerSlide.open_all(c, 50, '%')
check 'mở 50% di chuyển 4 tấm', moved == 4, moved
check 'mặt hộc trượt ra phía trước (−Y) đúng 50%', near(f0_y - oy.call(fr[0]), max / 2, 0.05), f0_y - oy.call(fr[0])
check 'thùng trượt cùng mặt hộc', near(b0_y - oy.call(bx[0]), max / 2, 0.05)
check 'ghi độ mở vào thuộc tính', near(V::DrawerSlide.open_mm(fr[0]), max / 2, 0.01)
V::DrawerSlide.open_all(c, 50, '%')
check 'mở lại cùng giá trị: không trượt thêm', near(f0_y - oy.call(fr[0]), max / 2, 0.05)
V::DrawerSlide.set_open([fr[0], bx[0]], 100, 'mm')
check 'mở 100 mm đúng 100 mm', near(f0_y - oy.call(fr[0]), 100.0, 0.05) && near(b0_y - oy.call(bx[0]), 100.0, 0.05)
check 'hộc kia vẫn mở 50%', near(V::DrawerSlide.open_mm(fr[1]), max / 2, 0.01)
V::DrawerSlide.set_open([fr[0]], 9999, 'mm')
check 'mở quá tầm bị kẹp ở tối đa', near(V::DrawerSlide.open_mm(fr[0]), max, 0.01)
check 'any_open?', V::DrawerSlide.any_open?(c)
V::DrawerSlide.close_all(c)
check 'đóng hết về chỗ cũ', near(oy.call(fr[0]), f0_y, 0.05) && near(oy.call(bx[0]), b0_y, 0.05) && !V::DrawerSlide.any_open?(c)
begin
  V::DrawerSlide.set_open([fr[0]], -5, 'mm'); ok = false
rescue ArgumentError
  ok = true
end
check 'độ mở âm bị từ chối', ok

puts '== 4. Đối tác mặt hộc + thùng, tìm tủ chứa =='
part = V::DrawerSlide.partners(c, [fr[1]])
check 'chọn mặt hộc 2 → kèm thùng 2', part.length == 2 && part.include?(bx[1]) && part.include?(fr[1])
check 'tìm tủ chứa mặt hộc', V::DrawerSlide.cabinet_of(fr[0]) == c

puts '== 5. Menu chuột phải =='
sel = Sketchup.active_model.selection; sel.clear; sel.add(c)
labels = V::ContextMenu.items_for(sel).map { |i| i[:label] }
check 'tủ có ngăn kéo: có Mở / Đóng ngăn kéo', labels.include?('Mở ngăn kéo…') && labels.include?('Đóng ngăn kéo'), labels.inspect
V::ContextMenu.slide_answer = [40, '%']
V::ContextMenu.items_for(sel).find { |i| i[:label] == 'Mở ngăn kéo…' }[:run].call
check 'Mở ngăn kéo… 40% cho cả tủ', fr.all? { |f| near(V::DrawerSlide.open_mm(f), max * 0.4, 0.01) }
check 'một bước Undo cho lệnh mở', Sketchup.active_model.ops.last == [:commit]
V::ContextMenu.items_for(sel).find { |i| i[:label] == 'Đóng ngăn kéo' }[:run].call
check 'Đóng ngăn kéo cả tủ', !V::DrawerSlide.any_open?(c)
sel.clear; sel.add(fr[1])
dl = V::ContextMenu.items_for(sel).map { |i| i[:label] }
check 'chọn mặt hộc: menu ngăn kéo, không có Bản lề/Mở cánh', dl.include?('Mở ngăn kéo…') && !dl.include?('Mở cánh…') && !dl.include?('Bản lề'), dl.inspect
V::ContextMenu.slide_answer = [120, 'mm']
V::ContextMenu.items_for(sel).find { |i| i[:label] == 'Mở ngăn kéo…' }[:run].call
check 'chỉ hộc được chọn mở (mặt hộc + thùng của nó)', near(V::DrawerSlide.open_mm(fr[1]), 120) && near(V::DrawerSlide.open_mm(bx[1]), 120) && near(V::DrawerSlide.open_mm(fr[0]), 0) && near(V::DrawerSlide.open_mm(bx[0]), 0)
V::ContextMenu.slide_answer = nil
sel.clear; sel.add(cab)
check 'tủ chưa có ngăn kéo: không có mục Mở ngăn kéo', !V::ContextMenu.items_for(sel).map { |i| i[:label] }.include?('Mở ngăn kéo…')

puts '== 6. Sửa tủ đóng ngăn kéo đang mở và báo =='
c = make_drawers('drawer_bottom_type' => 'inset')
V::DrawerSlide.open_all(c, 100, '%')
warnings = V::Rebuild.run(c, V::Rebuild.settings_of(c), V::Rebuild.dimensions_of(c), [])
check 'cảnh báo ngăn kéo đang mở', warnings.any? { |w| w.include?('đang mở') }, warnings.inspect
check 'sau dựng lại: ngăn kéo đóng, loại đáy giữ nguyên', !V::DrawerSlide.any_open?(c) && part_boxes(c).key?('Đáy')
inset_bottom = part_boxes(c)['Đáy']; hong = part_boxes(c)['Hông Trái']
check 'sau dựng lại vẫn là đáy lọt (đáy cùng mép dưới hông)', near(inset_bottom[2], hong[2]), [inset_bottom[2], hong[2]].inspect

puts '== 7. HUD ngăn kéo =='
dt = V::Tools::DrawerTool.new({}); dt.activate; dt.draw(Sketchup.active_model.active_view)
keys = dt.hud_params.map { |p| p[:key] }
check 'HUD có Loại đáy', keys.include?('drawer_bottom_type')
check 'rãnh ẩn khi không phải ngậm rãnh', !keys.include?('drawer_groove_depth'), keys.inspect
dt.settings['drawer_bottom_type'] = 'groove'; dt.draw(Sketchup.active_model.active_view)
check 'rãnh hiện khi chọn ngậm rãnh', dt.hud_params.map { |p| p[:key] }.include?('drawer_groove_depth')

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.length}"
exit($fail.empty? ? 0 : 1)
