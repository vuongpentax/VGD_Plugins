# encoding: UTF-8
# Kiểm thử: bấm mở nhiều lần chỉ có một hộp thoại.
require 'tmpdir'
require 'fileutils'
$LOAD_PATH.unshift(File.join(__dir__, 'stub'))

build = File.expand_path(ARGV[0])
fake = Dir.mktmpdir('fake_appdata')
ENV['APPDATA'] = fake
FileUtils.mkdir_p(File.join(fake, 'SketchUp/SketchUp 2024/SketchUp/Plugins'))

module UI
  class HtmlDialog
    STYLE_DIALOG = 1
    @@made = []
    attr_reader :fronted
    def self.made; @@made; end
    def initialize(**_o); @@made << self; @visible = false; @fronted = 0; end
    def set_file(_f); end
    def add_action_callback(n, &b); (@cbs ||= {})[n] = b; end
    def cb(n); @cbs[n]; end
    def execute_script(s); (@scripts ||= []) << s; end
    def scripts; @scripts ||= []; end
    def set_on_closed(&b); @closed = b; end
    def show; @visible = true; end
    def visible?; @visible; end
    def bring_to_front; @fronted += 1; end
    def close; @visible = false; @closed.call if @closed; end
  end
end

module UI
  @answer = 6
  def self.answer=(a); @answer = a; end
  def self.open_path=(p); @open_path = p; end
  def self.openpanel(*_a); @open_path; end
  def self.messagebox(*_a); @@asked = (@@asked rescue 0) + 1; @answer; end
  def self.asked; @@asked rescue 0; end
end
IDNO = 7

require File.join(build, 'VGD_PluginManager/main')
PM = VGD::PluginManager

def check(label, cond)
  puts "#{cond ? 'OK  ' : 'FAIL'} #{label}"
  $fail = true unless cond
end

check 'chưa mở thì không có hộp thoại', !PM.dialog_open?
PM.run
check 'mở lần đầu tạo một hộp thoại', UI::HtmlDialog.made.size == 1 && PM.dialog_open?
PM.run
PM.run
check 'bấm thêm không tạo hộp thoại mới, đưa cửa sổ cũ lên trước', UI::HtmlDialog.made.size == 1 && UI::HtmlDialog.made[0].fronted == 2
UI::HtmlDialog.made[0].close
check 'đóng xong thì ghi nhận là đã đóng', !PM.dialog_open?
PM.run
check 'sau khi đóng, bấm mở tạo hộp thoại mới', UI::HtmlDialog.made.size == 2 && PM.dialog_open?
UI::HtmlDialog.made[0].close
check 'đóng cửa sổ cũ không làm mất dấu cửa sổ mới', PM.dialog_open?

# --- Tắt/bật tất cả qua callback ---
plug = File.join(fake, 'SketchUp/SketchUp 2024/SketchUp/Plugins')
%w[p1 p2 TT_Lib2].each { |n| File.write(File.join(plug, "#{n}.rb"), "x\n") }
dlg = UI::HtmlDialog.made.last
dlg.cb('ready').call(nil)
status = -> { PM::Toggle.state['plugins'].map { |x| [x['name'], x['status']] }.to_h }
UI.answer = IDNO
dlg.cb('pm_bulk').call(nil, { action: 'disable', names: %w[p1 p2 TT_Lib2 khong_co] }.to_json)
check 'chọn Không ở hộp xác nhận thì không đổi gì', status.call.values.uniq == ['on'] && UI.asked == 1
UI.answer = IDYES
dlg.cb('pm_bulk').call(nil, { action: 'disable', names: %w[p1 p2 khong_co ../x] }.to_json)
check 'chọn Có thì chỉ tắt đúng các mục hợp lệ được gửi lên', status.call == { 'p1' => 'off', 'p2' => 'off', 'TT_Lib2' => 'on' }
check 'giao diện nhận thông báo đã tắt', dlg.scripts.last.include?('Đã tắt: 2 plugin')
asked = UI.asked
dlg.cb('pm_bulk').call(nil, { action: 'disable', names: %w[p1 p2] }.to_json)
check 'không còn mục nào để tắt thì không hỏi xác nhận', UI.asked == asked && dlg.scripts.last.include?('Không có plugin nào đang bật')
dlg.cb('pm_bulk').call(nil, { action: 'enable', names: %w[p1 p2] }.to_json)
check 'bật tất cả khôi phục', status.call.values.uniq == ['on']
dlg.cb('pm_bulk').call(nil, 'không phải json')
check 'JSON hỏng không làm crash', dlg.scripts.last.include?('Lỗi khi tắt/bật hàng loạt')

# --- Tab Chuyển plugin: danh sách phải hiện (hồi quy beta.16: callback mg_list từng bị xóa nhầm) ---
p22 = File.join(fake, 'SketchUp/SketchUp 2022/SketchUp/Plugins')
FileUtils.mkdir_p(File.join(p22, 'beta_tool'))
File.write(File.join(p22, 'alpha_tool.rb'), "puts 1\n")
File.write(File.join(p22, 'beta_tool.rb'), "puts 2\n")
dlg.cb('mg_list').call(nil, { src: '2022', dst: '2024' }.to_json)
check 'mg_list trả danh sách plugin của bản nguồn', dlg.scripts.last.include?('renderMigrate') && dlg.scripts.last.include?('alpha_tool') && dlg.scripts.last.include?('beta_tool')
dlg.cb('mg_list').call(nil, { src: '2022', dst: '2022' }.to_json)
check 'mg_list báo lỗi khi nguồn trùng đích', !dlg.scripts.last.include?('renderMigrate')
html = File.read(File.join(build, 'VGD_PluginManager/ui/dialog.html'), encoding: 'UTF-8')
called = html.scan(/sketchup\.([a-z_]+)\(/).flatten | html.scan(/send\('([a-z_]+)'/).flatten
missing = called.reject { |c| dlg.cb(c) }
check "mọi lệnh giao diện gọi đều có callback (thiếu: #{missing.join(', ')})", missing.empty?

# --- Mở thư mục ---
opened = []
PM.define_singleton_method(:open_folder) { |dir| opened << dir }
dlg.cb('pm_open_disabled').call(nil)
check 'mở thư mục đã tắt: tạo nếu chưa có và mở đúng thư mục', opened.last == VGD::PluginManager::Toggle.disabled_dir && File.directory?(opened.last)
FileUtils.mkdir_p(PM.plugins_dir(VGD::PluginManager::Toggle.year))
dlg.cb('pm_open_plugins').call(nil)
check 'mở thư mục Plugins của bản đang chạy', opened.last == PM.plugins_dir(VGD::PluginManager::Toggle.year)

loader = File.read(File.join(build, 'VGD_PluginManager.rb'), encoding: 'UTF-8')[/ex\.version\s*=\s*'([^']+)'/, 1]
check "phiên bản trong loader (#{loader}) khớp VERSION (#{PM::VERSION})", loader == PM::VERSION

puts($fail ? 'CÓ LỖI' : 'TẤT CẢ ĐẠT')
exit($fail ? 1 : 0)
