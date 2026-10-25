# Test minitoolbar tròn (beta.20): bố cục, hit-test, click, công cụ VGD Chọn, chuột phải trong công cụ Cánh.
# Chạy: ruby test_minibar.rb [thư mục runtime]
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
V::ContextMenu.confirm_answer = true
def mk_box(w, d, h)
  g = Sketchup.active_model.entities.add_group; g.name = 'Box'
  f = g.entities.add_face([[0, 0, 0], [w.mm, 0, 0], [w.mm, d.mm, 0], [0, d.mm, 0]])
  f.reverse! if f.normal.z < 0
  f.pushpull(h.mm); g
end
def new_cabinet(type = 'standard', w = 800, d = 560, h = 800)
  Sketchup.reset_model!
  opts = { 'front_normal' => [0, -1, 0], 'cabinet_type' => type }.merge(V::Schema::TYPE_PRESETS[type] || {})
  cab = V::Geometry.cabinet_from_box(mk_box(w, d, h), opts)
  Sketchup.active_model.selection.clear
  cab
end
view = Sketchup.active_model.active_view
Bar = V::MiniBar::Bar
def run_item(label, hit) { label: label, run: -> { hit << label } } end

# --- 1. Bố cục ---
hit = []
items = %w[A B C D E F].map { |l| run_item(l, hit) }
bar = Bar.new(items, 500, 400, 1000, 800, ) rescue Bar.new(items, 500, 400)
bar.fit_to(1000, 800)
check '6 nút → 6 nút trên vòng', bar.buttons.length == 6
check 'nút đầu ở đúng phía trên tâm', (bar.buttons.first[:x] - bar.cx).abs < 1e-6 && bar.buttons.first[:y] < bar.cy
check 'mọi nút cách tâm đúng bán kính vòng trong', bar.buttons.all? { |b| (Math.hypot(b[:x] - bar.cx, b[:y] - bar.cy) - V::MiniBar::BASE).abs < 1e-6 }
check 'các nút không chồng nhau', bar.buttons.combination(2).all? { |a, b| Math.hypot(a[:x] - b[:x], a[:y] - b[:y]) >= 2 * V::MiniBar::RADIUS }
many = Bar.new((1..14).map { |i| run_item("N#{i}", hit) }, 500, 400)
many.fit_to(1000, 800)
check '14 nút tràn sang vòng 2 và không chồng nhau', many.buttons.length == 14 && many.buttons.combination(2).all? { |a, b| Math.hypot(a[:x] - b[:x], a[:y] - b[:y]) >= 2 * V::MiniBar::RADIUS - 0.5 }
corner = Bar.new(items, 5, 5, '')
corner.fit_to(1000, 800)
check 'chuột phải sát góc: thanh nút được dời vào trong viewport', corner.buttons.all? { |b| b[:x] - b[:r] >= 0 && b[:y] - b[:r] >= 0 }, corner.buttons.map { |b| [b[:x].round, b[:y].round] }.inspect
check 'bỏ vạch ngăn', Bar.new([{ separator: true }, run_item('X', hit)], 300, 300).items.length == 1

# --- 2. Hit-test, click, nhóm con ---
hit.clear
b0 = bar.buttons[2]
check 'hit-test đúng nút', bar.button_at(b0[:x], b0[:y])[:item][:label] == 'C'
check 'ngoài nút: không trúng', bar.button_at(b0[:x] + 200, b0[:y] + 200).nil?
check 'click nút chạy lệnh', bar.click(b0[:x], b0[:y]) == :run && hit == ['C']
check 'click ngoài: đóng', bar.click(10, 10) == :close
group = { label: 'Nhóm', items: [run_item('c1', hit), run_item('c2', hit), run_item('c3', hit)] }
gbar = Bar.new([group, run_item('Z', hit)], 500, 400)
gbar.fit_to(1000, 800)
gb = gbar.buttons.find { |b| b[:item][:label] == 'Nhóm' }
check 'click nhóm: mở vòng con', gbar.click(gb[:x], gb[:y]) == :expand && gbar.buttons.count { |b| b[:level] == 1 } == 3
kids = gbar.buttons.select { |b| b[:level] == 1 }
check 'nút con nằm vòng ngoài và không chồng nhau', kids.all? { |k| Math.hypot(k[:x] - gbar.cx, k[:y] - gbar.cy) > V::MiniBar::BASE + 20 } && kids.combination(2).all? { |a, b| Math.hypot(a[:x] - b[:x], a[:y] - b[:y]) >= 2 * V::MiniBar::RADIUS - 0.5 }
hit.clear
gbar.click(kids[1][:x], kids[1][:y])
check 'click nút con chạy đúng lệnh', hit == ['c2'], hit.inspect
gbar2 = Bar.new([group], 500, 400); gbar2.fit_to(1000, 800)
g2 = gbar2.buttons.first
gbar2.click(g2[:x], g2[:y]); gbar2.click(g2[:x], g2[:y])
check 'bấm nhóm lần hai: gập lại', gbar2.buttons.none? { |b| b[:level] == 1 }
dis = Bar.new([{ label: 'Tắt', run: -> { hit << 'tắt' }, enabled: false }], 300, 300); dis.fit_to(1000, 800)
hit.clear; dis.click(dis.buttons[0][:x], dis.buttons[0][:y])
check 'nút bị khóa không chạy', hit.empty?
errbar = Bar.new([{ label: 'Lỗi', run: -> { raise 'hỏng' } }], 300, 300); errbar.fit_to(1000, 800)
UI.msgs.clear
errbar.click(errbar.buttons[0][:x], errbar.buttons[0][:y])
check 'lệnh lỗi: báo hộp thoại, không làm sập', UI.msgs.last.to_s.include?('hỏng')

# --- 3. Vẽ ---
view.drawn = []
bar.draw(view)
check 'vẽ ra đa giác + viền + chữ', view.drawn.count { |k, _| k == :draw2d } >= 2 * 7 && view.drawn.any? { |k, _| k == :text }
check 'nhãn rút gọn', V::MiniBar.short_label('Đổi loại tủ') == 'Loại' && V::MiniBar.short_label('Một cái tên rất dài') == 'Một'

# --- 4. Công cụ VGD Chọn ---
check 'có nút VGD Chọn trên thanh công cụ', V.instance_variable_get(:@toolbar) && true
cab = new_cabinet('base')
view.fake_path = [cab]
tool = V::Tools::PickTool.new
tool.activate
check 'công cụ đang hoạt động', tool.active?
check 'vgd_tool_active? nhận PickTool', (V.instance_variable_set(:@active_tool, tool); V.vgd_tool_active?)
menu = Object.new
r = tool.getMenu(menu, 0, 400, 300, view)
check 'chuột phải lên tủ: trả false (không hiện menu thường)', r == false
check 'chọn tủ', Sketchup.active_model.selection.length == 1 && Sketchup.active_model.selection.first == cab
check 'mở thanh nút', tool.bar && tool.bar.items.map { |i| i[:label] }.include?('Đổi loại tủ')
check 'thanh nút bếp dưới có Chia nhanh', tool.bar.items.map { |i| i[:label] }.include?('Chia nhanh')
check 'tiêu đề là loại tủ', tool.bar.title == 'Tủ bếp dưới', tool.bar.title
# chạy lệnh qua thanh nút: Chia nhanh ▸ 2 cánh
chia = tool.bar.buttons.find { |b| b[:item][:label] == 'Chia nhanh' }
tool.onLButtonDown(0, chia[:x], chia[:y], view)
two = tool.bar.buttons.find { |b| b[:level] == 1 && b[:item][:label] == '2 cánh' }
check 'mở nhóm Chia nhanh thấy "2 cánh"', !two.nil?
tool.onLButtonDown(0, two[:x], two[:y], view)
check 'bấm "2 cánh" tạo 2 cánh', V::Operations.doors_of(cab).length == 2
check 'chạy xong thì thanh nút đóng', tool.bar.nil?
# chuột phải lên cánh
door = V::Operations.doors_of(cab).first
view.fake_path = [cab, door]
tool.getMenu(menu, 0, 400, 300, view)
check 'chuột phải lên cánh: menu cánh', tool.bar && tool.bar.items.map { |i| i[:label] }.include?('Bản lề') && !tool.bar.items.map { |i| i[:label] }.include?('Đổi loại tủ')
check 'chọn đúng cánh', Sketchup.active_model.selection.first == door
tool.onCancel(0, view)
check 'Esc lần 1 chỉ đóng thanh nút', tool.bar.nil? && tool.active?
# chuột phải ra ngoài tủ
view.fake_path = []
check 'chuột phải ngoài tủ: để menu thường hiện', tool.getMenu(menu, 0, 50, 50, view) == true && tool.bar.nil?
# di chuột cập nhật hover
view.fake_path = [cab]; tool.getMenu(menu, 0, 400, 300, view)
btn = tool.bar.buttons.first
tool.onMouseMove(0, btn[:x], btn[:y], view)
check 'rê chuột tô sáng nút', tool.bar.hover_label == btn[:item][:label]
view.drawn = []; tool.draw(view)
check 'công cụ vẽ thanh nút', !view.drawn.empty?
tool.onLButtonDown(0, 5, 790, view)
check 'click ngoài thanh nút: đóng', tool.bar.nil?
tool.deactivate(view)
check 'tắt công cụ', !tool.active?
V.instance_variable_set(:@active_tool, nil)

# --- 5. Chuột phải trong công cụ Cánh → thanh nút (Loại mở của vùng) ---
cab = new_cabinet('base')
Sketchup.active_model.selection.add(cab)
dt = V::Tools.build('door', {}); dt.activate
check 'công cụ Cánh có nhận mixin thanh nút', dt.class.ancestors.include?(V::MiniBar::ToolMenu)
check 'mixin đứng TRƯỚC PresetHud (nhận click trước HUD)', dt.class.ancestors.index(V::MiniBar::ToolMenu) < dt.class.ancestors.index(V::PresetHud)
res = dt.getMenu(Object.new, 0, 420, 320, view)
bar = dt.instance_variable_get(:@mb_bar)
check 'chuột phải trong công cụ Cánh: thanh nút + không hiện menu thường', res == false && bar
check 'có Loại mở của vùng / Chọn tất cả / Setting', %w[Loại\ mở\ của\ vùng Chọn\ tất\ cả\ vùng Mở\ bảng\ Setting].all? { |l| bar.items.map { |i| i[:label] }.include?(l) }
layout = dt.instance_variable_get(:@layout)
layout.split_even(layout.ids.first, 'vertical', 2)
dt.instance_variable_set(:@selected, [layout.ids.first])
dt.onMouseMove(0, 100, 100, view) # đang mở thanh nút: hover vùng bị khóa
loai = bar.buttons.find { |b| b[:item][:label] == 'Loại mở của vùng' }
dt.onLButtonDown(0, loai[:x], loai[:y], view)
trai = bar.buttons.find { |b| b[:level] == 1 && b[:item][:label] == 'Bản lề trái' }
dt.onLButtonDown(0, trai[:x], trai[:y], view)
check 'đặt loại mở cho vùng đang chọn qua thanh nút', layout.find(layout.ids.first)['opening_type'] == 'left', layout.regions.inspect
check 'thanh nút đóng sau khi chạy', dt.instance_variable_get(:@mb_bar).nil?
# Esc đóng thanh nút trước, không thoát công cụ
dt.getMenu(Object.new, 0, 420, 320, view)
dt.onCancel(0, view)
check 'Esc đóng thanh nút, công cụ vẫn chạy', dt.instance_variable_get(:@mb_bar).nil? && dt.active?
# công cụ Setting: chuột phải khi chưa có menu → vẫn có thanh nút với mục Setting
pt = V::Tools.build('panel', {}); pt.activate
pt.getMenu(Object.new, 0, 300, 300, view)
check 'công cụ Đợt/vách: thanh nút chỉ có Setting', pt.instance_variable_get(:@mb_bar).items.map { |i| i[:label] } == ['Mở bảng Setting']

# --- 6. Nút bật/tắt VGD Chọn + nhấp đúp dự phòng + getMenu đúng 5 tham số ---
check 'getMenu của PickTool khai báo đúng 5 tham số', V::Tools::PickTool.instance_method(:getMenu).arity == 5
check 'getMenu của mixin thanh nút khai báo đúng 5 tham số', V::MiniBar::ToolMenu.instance_method(:getMenu).arity == 5
pick_cmd = V.instance_variable_get(:@toolbar).nil? ? nil : nil
cab = new_cabinet('standard')
check 'chưa bật: VGD Chọn không sáng', !V.pick_active?
V.toggle_pick
check 'bấm nút lần 1: bật VGD Chọn', V.pick_active?
V.toggle_pick
check 'bấm nút lần 2: tắt VGD Chọn', !V.pick_active?
V.toggle_pick
t = V.instance_variable_get(:@active_tool)
view.fake_path = [cab]
t.onLButtonDoubleClick(0, 300, 300, view)
check 'nhấp đúp trái lên tủ: mở thanh nút (dự phòng)', t.bar && t.bar.items.map { |i| i[:label] }.include?('Đổi loại tủ')
t.onCancel(0, view)
view.drawn = []
cb = Bar.new([{ label: 'Xà treo', run: -> {}, checked: true }], 300, 300); cb.fit_to(1000, 800); cb.draw(view)
check 'nút đang bật có dấu ✓', view.drawn.any? { |k, a| k == :text && a[1].to_s.include?('✓') }
t.deactivate(view); V.instance_variable_set(:@active_tool, nil)

# --- 7. Chế độ VGD Chọn luôn sáng; Space (công cụ Chọn) quay về VGD Chọn ---
cab = new_cabinet('standard'); view.fake_path = [cab]
V.instance_variable_set(:@pick_mode, false)
check 'ban đầu chế độ chọn tắt', !V.pick_active?
V.toggle_pick
check 'bấm nút: chế độ bật + đang chạy VGD Chọn', V.pick_active? && V.pick_tool_running?
check 'đã gắn bộ quan sát công cụ', Sketchup.active_model.tools.observers.length == 1
# người dùng bấm Space → SketchUp chọn công cụ Chọn
Sketchup.active_model.select_tool(nil)
Sketchup.active_model.tools.observers.each { |o| o.onActiveToolChanged(Sketchup.active_model.tools, 'SelectionTool', 21022) }
check 'Space: quay về VGD Chọn, nút vẫn sáng', V.pick_active? && V.pick_tool_running?
# công cụ khác (Move 21048) thì không can thiệp
Sketchup.active_model.select_tool(nil)
Sketchup.active_model.tools.observers.each { |o| o.onActiveToolChanged(Sketchup.active_model.tools, 'MoveTool', 21048) }
check 'công cụ khác: không ép quay về', !V.pick_tool_running?
check 'nhưng nút vẫn sáng (chế độ còn bật)', V.pick_active?
# bấm nút lần nữa: tắt hẳn
V.toggle_pick
V.toggle_pick if !V.pick_active?
V.toggle_pick
check 'bấm nút khi đang bật: tắt hẳn', !V.pick_active?
Sketchup.active_model.tools.observers.each { |o| o.onActiveToolChanged(Sketchup.active_model.tools, 'SelectionTool', 21022) }
check 'tắt rồi thì Space không ép về nữa', !V.pick_tool_running?

# --- 8. VGD Chọn chọn đối tượng như công cụ Chọn thường ---
pk = V::Tools::PickTool.new; pk.activate
sel = Sketchup.active_model.selection; sel.clear
other = Sketchup.active_model.entities.add_group; other.name = 'Khác'
view.fake_path = [cab]
pk.onLButtonDown(0, 10, 10, view); pk.onLButtonUp(0, 10, 10, view)
check 'click chọn tủ', sel.to_a == [cab]
view.fake_path = [other]
pk.onLButtonDown(V::Keys.respond_to?(:shift?) ? CONSTRAIN_MODIFIER_MASK : 8, 20, 20, view); pk.onLButtonUp(CONSTRAIN_MODIFIER_MASK, 20, 20, view)
check 'Shift+click thêm', sel.length == 2
pk.onLButtonDown(0, 20, 20, view); pk.onLButtonUp(CONSTRAIN_MODIFIER_MASK, 20, 20, view)
check 'Shift+click lần nữa bớt đi', sel.length == 1
view.fake_path = []
pk.onLButtonDown(0, 30, 30, view); pk.onLButtonUp(0, 30, 30, view)
check 'click chỗ trống bỏ chọn', sel.length == 0
# kéo > 5px là kéo khung: không chọn theo click
view.fake_path = [cab]
pk.onLButtonDown(0, 10, 10, view); pk.onMouseMove(0, 60, 60, view); pk.draw(view); pk.onLButtonUp(0, 60, 60, view)
check 'kéo khung không làm hỏng công cụ', true
pk.deactivate(view)

# --- 9. Vật không phải VGD: chọn như SketchUp rồi TRẢ công cụ cho Chọn của SketchUp ---
Sketchup.active_model.active_path = nil
V.instance_variable_set(:@pick_native, false)
pd = V::Tools::PickTool.new
Sketchup.active_model.select_tool(pd)
outside = Sketchup.active_model.entities.add_group; outside.name = 'Model khác'
view.fake_path = [outside]
pd.onLButtonDown(0, 30, 30, view); pd.onLButtonUp(0, 30, 30, view)
check 'vật khác: chọn đối tượng như SketchUp', Sketchup.active_model.selection.to_a == [outside]
check 'vật khác: trả công cụ về Chọn của SketchUp', Sketchup.active_model.tool.nil? && V.pick_native?
check 'vật khác: không tự vào group (để SketchUp làm)', Sketchup.active_model.active_path.nil?

# --- 10. Tủ VGD: vẫn do VGD Chọn xử lý; nhấp đúp mở thanh nút ---
V.instance_variable_set(:@pick_native, false)
Sketchup.active_model.select_tool(pd)
view.fake_path = [cab]
pd.onLButtonDown(0, 300, 300, view); pd.onLButtonUp(0, 300, 300, view)
check 'tủ VGD: giữ công cụ VGD Chọn', Sketchup.active_model.tool.equal?(pd) && !V.pick_native?
pd.onLButtonDoubleClick(0, 300, 300, view)
check 'tủ VGD: nhấp đúp mở thanh nút', !pd.bar.nil?
pd.onCancel(0, view)
Sketchup.active_model.select_tool(nil)

# --- 11. Chọn tủ VGD bằng công cụ SketchUp (đã trả quyền) thì VGD Chọn quay lại ---
V.instance_variable_set(:@pick_mode, true)
V.instance_variable_set(:@pick_native, true)
sel = Sketchup.active_model.selection; sel.clear; sel.add(outside)
V.pick_selection_changed(sel)
check 'chọn group thường: vẫn ở Chọn SketchUp', V.pick_native?
sel.clear; sel.add(cab)
V.pick_selection_changed(sel)
check 'chọn tủ VGD: VGD Chọn quay lại', !V.pick_native? && V.pick_tool_running?
V.instance_variable_set(:@pick_mode, false)
Sketchup.active_model.select_tool(nil)
Sketchup.active_model.active_path = nil

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.size}"
exit($fail.empty? ? 0 : 1)
