# Test vẽ lưới trục (grid_builder.rb, grid_tag.rb, model_store.rb) bằng SketchUp giả lập: nhóm, tag theo bộ mẫu, nét gạch chấm,
# ký hiệu trục (vòng tròn + chữ giữa vòng), một bước hoàn tác, vẽ lại thay nhóm cũ, lỗi giữ model nguyên. Phần vẽ thật chưa xác minh trong SketchUp.
# Chạy: ruby dev/test_grid_builder.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[core/schema core/grid core/axis_symbol core/column_types core/levels core/column_plan core/state core/preview model_store tag_store grid_tag grid_builder].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
B = S::GridBuilder
D = S::Schema::DICTIONARY
def fresh(**o); Sketchup::Model.new(**o); end
def grid_groups(m); m.entities.grep(Sketchup::Group); end

m = fresh
g = S::Grid.default
res = B.build(m, g, nil)
grp = grid_groups(m)
ok('vẽ lần đầu: đúng một nhóm "Lưới trục" ghi kind = grid và phiên bản plugin', grp.size == 1 && grp[0].name == 'Lưới trục' && grp[0].get_attribute(D, 'kind') == 'grid' && grp[0].get_attribute(D, 'plugin_version') == '9.9.9')
ok('một bước hoàn tác: start (có hoàn tác gộp) rồi commit, không abort', m.operations == [[:start, 'VGD Structure · Vẽ lưới trục'], [:commit]])
tag = m.layers['!grid']
ok('tag !grid theo bộ tag mẫu: màu tím (186, 0, 204), nằm trong thư mục ! INFORMATION', tag && tag.color.rgb == [186, 0, 204] && tag.folder && tag.folder.name == '! INFORMATION')
ok('nhóm và đường trục nằm trên tag !grid', grp[0].layer.equal?(tag) && grp[0].entities.grep(Sketchup::Edge).all? { |e| e.layer.equal?(tag) })
ok('nét tag !grid là gạch chấm (chọn "Dash Dot Line"), có ghi chú', tag.line_style && tag.line_style.name == 'Dash Dot Line' && res.style_note.include?('Dash Dot Line'))
edges = grp[0].entities.grep(Sketchup::Edge)
ok('7 đường trục (4 đứng + 3 ngang) trong nhóm', edges.size == 7)
e1 = edges.first
ok('đường trục đầu (trục 1) từ y = -1500 mm đến 8700 mm tại x = 0 (đổi sang inch)', (e1.from.y * 25.4 + 1500).abs < 1e-6 && (e1.to.y * 25.4 - 8700).abs < 1e-6 && e1.from.x.abs < 1e-9)
syms = grp[0].entities.grep(Sketchup::Group)
ok('7 ký hiệu trục, mỗi cái là nhóm con tên "Ký hiệu trục <tên>"', syms.size == 7 && syms.map(&:name).sort == %w[1 2 3 4 A B C].map { |n| "Ký hiệu trục #{n}" }.sort)
s1 = syms.find { |s| s.name == 'Ký hiệu trục 1' }
ok('ký hiệu có vòng tròn 48 cạnh bán kính 500 mm tại (0, -2000)', s1.entities.circles.size == 1 && s1.entities.circles[0][2] == 48 && (s1.entities.circles[0][1] * 25.4 - 500).abs < 1e-6 && (s1.entities.circles[0][0].y * 25.4 + 2000).abs < 1e-6)
label = s1.entities.grep(Sketchup::Group).first
ok('chữ là tên trục, cao 400 mm, tạo phẳng (không đùn), có mặt', label.texts.size == 1 && label.texts[0][1] == '1' && (label.texts[0][2] * 25.4 - 400).abs < 1e-6 && label.texts[0][7] == 0.0 && label.texts[0][5] == true)
ok('chữ được dời về giữa vòng tròn (tâm hộp bao chữ trùng tâm vòng tròn)', (label.bounds.center.x * 25.4).abs < 1e-6 && (label.bounds.center.y * 25.4 + 2000).abs < 1e-6)
ok('lưu dữ liệu lưới vào model (VGD_STRUCT.state) cùng lần vẽ', S::ModelStore.read(m)['grid'] == S::Grid.normalize!(g) && S::ModelStore.read(m)['saved'] == true)
ok('kết quả báo 7 trục, 7 ký hiệu', res.axes == 7 && res.symbols == 7)

# Vẽ lại: thay nhóm cũ, không nhân đôi, giữ một bước hoàn tác
old = grp[0]
g2 = g.merge('x_axes' => S::Grid.axes_from_spacings('5000*2', :number))
B.build(m, g2, 'scale' => 50, 'both_ends' => true)
grp2 = grid_groups(m)
ok('vẽ lại: nhóm cũ bị xóa, chỉ còn một nhóm lưới mới', grp2.size == 1 && !old.valid? && !grp2[0].equal?(old))
ok('vẽ lại với 3 trục đứng + 3 ngang, hai đầu: 6 đường, 12 ký hiệu; tỉ lệ 1:50 bán kính 250', grp2[0].entities.grep(Sketchup::Edge).size == 6 && grp2[0].entities.grep(Sketchup::Group).size == 12 && (grp2[0].entities.grep(Sketchup::Group).first.entities.circles[0][1] * 25.4 - 250).abs < 1e-6)
ok('vẽ lại không tạo thêm tag, vẫn một tag !grid', m.layers.count { |l| l.name == '!grid' } == 1)
ok('mỗi lần vẽ là một thao tác riêng', m.operations.count { |o| o[0] == :start } == 2 && m.operations.count { |o| o[0] == :commit } == 2)
ok('dữ liệu lưu là lưới mới và thiết lập mới', S::ModelStore.read(m).values_at('symbol') == [{'scale' => 50, 'both_ends' => true}])

# Dữ liệu sai: từ chối trước khi đụng model
m2 = fresh
bad = {'lưới sai' => [g.merge('x_axes' => [g['x_axes'][0]]), nil], 'tỉ lệ sai' => [g, {'scale' => 5}], 'tùy chọn sai' => [g, 'x']}
bad.each { |label, (gg, oo)| ok("dữ liệu sai bị từ chối, model không đổi: #{label}", !error_of { B.build(m2, gg, oo) }.nil? && m2.operations.empty? && grid_groups(m2).empty? && m2.layers.to_a.empty?) }

# Lỗi giữa chừng: hủy thao tác
m3 = fresh
$fail_text = true
msg = error_of { B.build(m3, g, nil) }
$fail_text = false
ok('lỗi khi vẽ chữ: hủy thao tác (abort), báo lỗi', msg.to_s.include?('giả lập') && m3.operations.last == [:abort] && !m3.operations.include?([:commit]))
# Nhóm cũ bị khóa: không đụng model
m4 = fresh
B.build(m4, g, nil)
grid_groups(m4).first.lock!
ops = m4.operations.size
ok('nhóm lưới cũ bị khóa: từ chối, không mở thao tác mới, không xóa', error_of { B.build(m4, g, nil) }.to_s.include?('khóa') && m4.operations.size == ops && grid_groups(m4).size == 1)
ok('xóa lưới khi nhóm bị khóa: từ chối', error_of { B.remove(m4) }.to_s.include?('khóa'))

# Xóa lưới
m5 = fresh
ok('xóa khi chưa có lưới: trả false, không mở thao tác', B.remove(m5) == false && m5.operations.empty?)
B.build(m5, g, nil)
ok('xóa lưới: một thao tác, nhóm biến mất, dữ liệu lưới vẫn giữ', B.remove(m5) == true && grid_groups(m5).empty? && m5.operations.last == [:commit] && S::ModelStore.read(m5)['saved'] == true)

# Kiểu nét
none = fresh(styles: ['Solid Line', 'Dotted Line'])
r = B.build(none, g, nil)
ok('model không có nét gạch chấm: giữ nét liền và báo rõ cách xử lý', none.layers['!grid'].line_style.nil? && r.style_note.include?('Không tìm thấy kiểu nét'))
custom = fresh
custom.layers.add('!grid').tap { |l| l.line_style = custom.line_styles.find { |s| s.name == 'Dotted Line' } }
r = B.build(custom, g, nil)
ok('tag !grid đã có nét người dùng đặt: không ghi đè, màu giữ nguyên', custom.layers['!grid'].line_style.name == 'Dotted Line' && r.style_note.include?('Giữ kiểu nét') && custom.layers['!grid'].color.nil?)
solid = fresh
solid.layers.add('!grid').tap { |l| l.line_style = solid.line_styles.find { |s| s.name == 'Solid Line' } }
B.build(solid, g, nil)
ok('tag !grid đang nét liền: đặt nét gạch chấm', solid.layers['!grid'].line_style.name == 'Dash Dot Line')
ok('chọn kiểu nét theo tên: ưu tiên có long, bỏ qua tên không có dash và dot', S::GridTag.pick_style(['Solid', 'Dashes', 'Dash Dot', 'Long Dash Dot']) == 'Long Dash Dot' && S::GridTag.pick_style(['Solid', 'Dash']) .nil? && S::GridTag.pick_style(['Nét gạch chấm']).nil?)

# Lưu và đọc dữ liệu
st = fresh
ok('model chưa có dữ liệu: đọc ra lưới mặc định, saved = false, không ghi gì', S::ModelStore.read(st)['grid'] == S::Grid.default && S::ModelStore.read(st)['saved'] == false && st.operations.empty?)
['không phải json', '{"grid": 5}', 'null', '[]', ('x' * 1_100_000), 123].each { |raw| st.set_attribute(D, 'state', raw); ok("dữ liệu hỏng trong model được bỏ qua, dùng mặc định: #{raw.to_s[0, 18]}", S::ModelStore.read(st)['saved'] == false && S::ModelStore.read(st)['grid'] == S::Grid.default) }
st.set_attribute(D, 'state', JSON.generate('grid' => g.merge('x_axes' => [g['x_axes'][0]]), 'symbol' => {}))
ok('lưới trong model không hợp lệ: dùng mặc định', S::ModelStore.read(st)['saved'] == false)
ok('ghi dữ liệu sai bị từ chối, không ghi', !error_of { S::ModelStore.write(st, g.merge('origin' => 'x'), nil) }.nil?)

# Khớp với bộ tag mẫu của VGD BIM (đọc file của BIM trong repo; bỏ qua nếu plugin đứng riêng, không có repo)
catalog = File.expand_path('../../VGD_BIM/runtime/vgd_bim/config/tag_catalog.json', __dir__)
if File.exist?(catalog)
  cluster = JSON.parse(File.read(catalog, encoding: 'bom|utf-8')).find { |c| c['group'] == S::Schema::GRID_TAG[:folder] }
  ok('bộ tag mẫu của BIM có tag !grid trong cụm ! INFORMATION (đúng tên và thư mục dùng cho lưới)', cluster && cluster['tags'].any? { |t| t['name'] == S::Schema::GRID_TAG[:name] })
end
summary = File.expand_path('../../../docs/reference/5d_auto_tag/assets/default_tags_summary.json', __dir__)
if File.exist?(summary)
  tags = JSON.parse(File.read(summary, encoding: 'bom|utf-8'))['folders'].flat_map { |f| f['tags'] }
  grid = tags.find { |t| t['name'] == '!grid' }
  ok('màu tag !grid khớp bộ tag mẫu (Color(186, 0, 204))', grid && grid['color'] == "Color(#{S::Schema::GRID_TAG[:color].join(', ')}, 1.0)")
end

puts $fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
