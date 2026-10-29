# Test theme viewport (beta.62): màu HUD theo token VGD sáng/tối, font Manrope→Segoe UI, đồng bộ từ dialog, không còn màu teal cũ.
# Chạy: ruby test_theme.rb [thư mục runtime]
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
def rgb(color) color.a.first(3) end

T = V::Theme
# 1. Token đúng theo quy tắc VGD_UI_DESIGN_SYSTEM.md
T.mode = :dark
check('dark surface', rgb(T.color(:surface)) == [0x1E, 0x1E, 0x1E])
check('dark text', rgb(T.color(:text)) == [0xE2, 0xE8, 0xF0])
check('accent chung', rgb(T.color(:accent)) == [0xB4, 0x89, 0x63])
check('dark accent_strong', rgb(T.color(:accent_strong)) == [0xC8, 0xA9, 0x8A])
check('dark danger', rgb(T.color(:danger)) == [0xE7, 0x9C, 0x91])
T.mode = :light
check('light surface', rgb(T.color(:surface)) == [0xFF, 0xFF, 0xFF])
check('light text', rgb(T.color(:text)) == [0x22, 0x22, 0x22])
check('light accent_strong', rgb(T.color(:accent_strong)) == [0x8E, 0x6B, 0x4C])
check('light danger', rgb(T.color(:danger)) == [0xA7, 0x3D, 0x36])
check('alpha tùy chọn', T.color(:surface, 215).a.last == 215)
check('role lạ báo lỗi', (T.color(:khong_co) rescue :err) == :err)

# 2. Lưu / đọc chế độ
T.mode = :dark
check('lưu chế độ', Sketchup.read_default(T::SECTION, T::KEY) == 'dark')
T.mode = 'light'
check('nhận chuỗi light', T.mode == :light)
T.mode = 'rác'
check('giá trị lạ bị bỏ qua', T.mode == :light)
check('mặc định khi chưa có', (T.reset!; T.mode) == :light)

# 3. Font
Dir.mktmpdir do |dir|
  check('không có Manrope → Segoe UI', T.font_name(dir) == 'Segoe UI')
  File.write(File.join(dir, 'Manrope-VariableFont_wght.ttf'), 'x')
  check('có Manrope → Manrope', T.font_name(dir) == 'Manrope')
end

# 4. draw_text: dùng font; nếu SketchUp không nhận :font thì tự bỏ và vẫn vẽ
class FontView
  attr_reader :calls
  def initialize(accept); @accept = accept; @calls = []; end
  def draw_text(point, text, options = {})
    raise ArgumentError, 'invalid option font' if options.key?(:font) && !@accept
    @calls << options
  end
end
T.reset!
view = FontView.new(true)
T.draw_text(view, [0, 0], 'a', size: 10, bold: true, color: T.color(:text))
check('có font trong tuỳ chọn', view.calls.last[:font] && view.calls.last[:size] == 10 && view.calls.last[:bold])
T.reset!
view = FontView.new(false)
T.draw_text(view, [0, 0], 'a', size: 10, color: T.color(:text))
T.draw_text(view, [0, 0], 'b', size: 10, color: T.color(:text))
check('API không nhận font → vẫn vẽ cả hai chữ', view.calls.length == 2)
check('API không nhận font → không gửi font', view.calls.none? { |c| c.key?(:font) })

# 5. HUD và thanh mini dùng token, không còn teal cũ (33,77,90)
T.mode = :dark
view = Sketchup.active_model.active_view
view.drawn = []
module Probe; end
hud = Object.new.extend(V::PresetHud)
check('hud_ink theo theme tối', rgb(hud.hud_ink) == [0xE2, 0xE8, 0xF0])
T.mode = :light
check('hud_ink theo theme sáng', rgb(hud.hud_ink) == [0x22, 0x22, 0x22])
src = Dir[File.join(RT, '*.rb')].reject { |f| f.end_with?('theme.rb') }
old = src.select { |f| File.read(f, encoding: "UTF-8").match?(/Color\.new\(\s*33,\s*77,\s*90/) }
check('hết teal cũ (33,77,90)', old.empty?, old.map { |f| File.basename(f) }.inspect)
old2 = src.select { |f| File.read(f, encoding: "UTF-8").match?(/Color\.new\(\s*(40, 160, 190|30, 140, 170|232, 131, 36|235, 120, 0)/) }
check('hết xanh/cam cũ của HUD và preview', old2.empty?, old2.map { |f| File.basename(f) }.inspect)

# 6. Dialog: không còn màu cứng, báo theme cho Ruby, dialog.rb nhận callback
html = File.read(File.join(RT, 'dialog.html'), encoding: "UTF-8")
check('dialog hết #b45309', !html.match?(/#b45309/i))
check('dialog báo theme cho Ruby', html.include?("sketchup.theme"))
check('dialog.rb nhận callback theme', File.read(File.join(RT, 'dialog.rb'), encoding: "UTF-8").include?("add_action_callback('theme')"))

puts "== #{$pass} pass, #{$fail.length} fail =="
exit($fail.empty? ? 0 : 1)
