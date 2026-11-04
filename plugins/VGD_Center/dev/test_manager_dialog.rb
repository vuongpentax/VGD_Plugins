# encoding: UTF-8
# Test VGD Center (chạy: ruby dev/test_manager_dialog.rb): các lệnh mgr_* của tab Quản lý, nối với giao diện manager.js.
require 'tmpdir'
require 'fileutils'
require 'json'
$LOAD_PATH.unshift(File.join(__dir__, 'stub'))

fake = Dir.mktmpdir('fake_appdata')
ENV['APPDATA'] = fake
plug24 = File.join(fake, 'SketchUp/SketchUp 2024/SketchUp/Plugins')
plug22 = File.join(fake, 'SketchUp/SketchUp 2022/SketchUp/Plugins')
FileUtils.mkdir_p(plug24)
FileUtils.mkdir_p(plug22)

require 'sketchup.rb'   # nạp stub trước để các hàm giả bên dưới ghi đè lên stub, không bị ghi đè ngược

module UI
  # Hộp thoại giả: ghi lại lệnh đã đăng ký và các script Ruby gửi sang giao diện
  class HtmlDialog
    def initialize(**_options); @callbacks = {}; @scripts = []; end
    def add_action_callback(name, &block); @callbacks[name] = block; end
    def callback(name); @callbacks[name]; end
    def callback_names; @callbacks.keys; end
    def execute_script(script); @scripts << script; end
    attr_reader :scripts
  end
  def self.asked; @asked || 0; end
  def self.reply_to_confirm(answer); @answer = answer; end
  def self.messagebox(*_args); @asked = asked + 1; @answer || IDYES; end
end

require_relative '../VGD_Center/main'
CENTER = VGD::Center
MGR = VGD::Center::Manager

def check(label, cond)
  puts "#{cond ? 'OK  ' : 'FAIL'} #{label}"
  $fail = true unless cond
end

dlg = UI::HtmlDialog.new
CENTER.register_callbacks(dlg)        # đường thật: Center đăng ký cả lệnh của tab Quản lý
last = -> { dlg.scripts.last.to_s }
status = -> { MGR::Toggle.state['plugins'].map { |x| [x['name'], x['status']] }.to_h }

# ---- Nối giao diện (manager.js) với Ruby ----
js = File.read(File.join(__dir__, '..', 'VGD_Center', 'manager', 'manager.js'), encoding: 'UTF-8')
html = File.read(File.join(__dir__, '..', 'VGD_Center', 'dialog.html'), encoding: 'UTF-8')
rb = File.read(File.join(__dir__, '..', 'VGD_Center', 'manager', 'callbacks.rb'), encoding: 'UTF-8')
js_calls = js.scan(/call\('(mgr_[a-z_]+)'/).flatten.uniq
missing = js_calls.reject { |name| dlg.callback(name) }
check "mọi lệnh manager.js gọi đều có callback Ruby (thiếu: #{missing.join(', ')})", missing.empty?
unused = dlg.callback_names.select { |n| n.start_with?('mgr_') } - js_calls
check "mọi callback mgr_* đều được giao diện dùng (thừa: #{unused.join(', ')})", unused.empty?
exported = js[/window\.VGDManager = \{(.*?)\};/m, 1].to_s.scan(/(\w+):/).flatten
ruby_calls = rb.scan(/js\.call\('(\w+)'/).flatten.uniq
check "mọi hàm Ruby gọi sang giao diện đều có trong window.VGDManager (thiếu: #{(ruby_calls - exported).join(', ')})", (ruby_calls - exported).empty?
check 'dialog.html nạp manager.css và manager.js', html.include?('manager/manager.css') && html.include?('manager/manager.js')
check 'dialog.html có mục điều hướng và trang Quản lý', html.include?('data-page="manager"') && html.include?('id="page-manager"')
check 'mở tab Quản lý gọi VGDManager.open()', html.include?("name === 'manager' && window.VGDManager")
check 'lệnh của Center vẫn còn (không bị tab Quản lý ghi đè)', %w[center_ready install_plugin uninstall_plugin open_guide].all? { |n| dlg.callback(n) }

# ---- Mở tab ----
%w[p1 p2 TT_Lib2 VGD_Center].each { |n| File.write(File.join(plug24, "#{n}.rb"), "x\n") }
dlg.callback('mgr_ready').call(nil)
check 'mở tab: gửi danh sách plugin và các bản SketchUp', dlg.scripts.any? { |s| s.include?('renderToggle') && s.include?('"p1"') } && dlg.scripts.any? { |s| s.include?('initMigrate') && s.include?('2022') }
check 'danh sách gửi sang giao diện không có VGD Center', dlg.scripts.select { |s| s.include?('renderToggle') }.none? { |s| s.include?('"name":"VGD_Center"') }
check 'số phiên bản Center có trong dữ liệu', dlg.scripts.any? { |s| s.include?(CENTER::VERSION) }

# ---- Tắt/bật tất cả qua callback ----
UI.reply_to_confirm(IDNO)
dlg.callback('mgr_bulk').call(nil, { action: 'disable', names: %w[p1 p2 TT_Lib2 khong_co] }.to_json)
check 'chọn Không ở hộp xác nhận thì không đổi gì', status.call.values.uniq == ['on'] && UI.asked == 1
UI.reply_to_confirm(IDYES)
dlg.callback('mgr_bulk').call(nil, { action: 'disable', names: %w[p1 p2 khong_co ../x VGD_Center vgd_center] }.to_json)
check 'chọn Có thì chỉ tắt đúng mục hợp lệ; VGD Center và tên lạ bị bỏ qua', status.call == { 'p1' => 'off', 'p2' => 'off', 'TT_Lib2' => 'on' } && File.exist?(File.join(plug24, 'VGD_Center.rb'))
check 'giao diện nhận thông báo đã tắt', last.call.include?('Đã tắt: 2 plugin')
asked = UI.asked
dlg.callback('mgr_bulk').call(nil, { action: 'disable', names: %w[p1 p2] }.to_json)
check 'không còn mục nào để tắt thì không hỏi xác nhận', UI.asked == asked && last.call.include?('Không có plugin nào đang bật')
dlg.callback('mgr_bulk').call(nil, { action: 'enable', names: %w[p1 p2] }.to_json)
check 'bật tất cả khôi phục', status.call.values.uniq == ['on']
dlg.callback('mgr_bulk').call(nil, 'không phải json')
check 'JSON hỏng không làm crash, báo lỗi trong giao diện', last.call.include?('Lỗi khi tắt/bật hàng loạt')

# ---- Một plugin, bộ plugin ----
dlg.callback('mgr_change').call(nil, { names: %w[p1], action: 'disable' }.to_json)
check 'mgr_change tắt một plugin', status.call['p1'] == 'off'
dlg.callback('mgr_change').call(nil, { names: %w[VGD_Center], action: 'disable' }.to_json)
check 'mgr_change không tắt được VGD Center', File.exist?(File.join(plug24, 'VGD_Center.rb')) && last.call.include?('Bỏ qua')
dlg.callback('mgr_change').call(nil, { names: %w[p1], action: 'enable' }.to_json)
dlg.callback('mgr_save_set').call(nil, { name: 'Bộ thử', names: %w[p1 p2] }.to_json)
check 'lưu bộ plugin', last.call.include?('Đã lưu bộ') && MGR::Toggle.load_sets['Bộ thử'] == %w[p1 p2]
dlg.callback('mgr_apply_set').call(nil, { name: 'Bộ thử', action: 'disable' }.to_json)
check 'tắt cả bộ', status.call['p1'] == 'off' && status.call['p2'] == 'off'
dlg.callback('mgr_apply_set').call(nil, { name: 'Bộ thử', action: 'enable' }.to_json)
dlg.callback('mgr_delete_set').call(nil, { name: 'Bộ thử' }.to_json)
check 'xóa bộ', MGR::Toggle.load_sets.empty?

# ---- Chặn thao tác khi Center đang cài plugin ----
CENTER.instance_variable_set(:@busy, true)
before = status.call
dlg.callback('mgr_change').call(nil, { names: %w[p1], action: 'disable' }.to_json)
check 'Center đang bận: không bật/tắt, báo người dùng', status.call == before && last.call.include?('đang cài hoặc gỡ')
dlg.callback('mgr_bulk').call(nil, { action: 'disable', names: %w[p1 p2] }.to_json)
check 'Center đang bận: tắt hàng loạt không hỏi xác nhận, không đổi gì', status.call == before && last.call.include?('đang cài hoặc gỡ')
dlg.callback('mgr_migrate').call(nil, { src: '2024', dst: '2022', plugins: %w[p1], overwrite: false }.to_json)
check 'Center đang bận: không chuyển plugin', !File.exist?(File.join(plug22, 'p1.rb')) && last.call.include?('đang cài hoặc gỡ')
CENTER.instance_variable_set(:@busy, false)
dlg.callback('mgr_change').call(nil, { names: %w[p1], action: 'disable' }.to_json)
check 'hết bận thì thao tác lại bình thường', status.call['p1'] == 'off'
dlg.callback('mgr_change').call(nil, { names: %w[p1], action: 'enable' }.to_json)

# ---- Chuyển plugin ----
FileUtils.mkdir_p(File.join(plug22, 'beta_tool'))
File.write(File.join(plug22, 'alpha_tool.rb'), "puts 1\n")
File.write(File.join(plug22, 'beta_tool.rb'), "puts 2\n")
File.write(File.join(plug22, 'VGD_Center.rb'), "center 2022\n")
dlg.callback('mgr_list').call(nil, { src: '2022', dst: '2024' }.to_json)
check 'mgr_list trả danh sách plugin của bản nguồn (không có VGD Center)', last.call.include?('renderMigrate') && last.call.include?('alpha_tool') && last.call.include?('beta_tool') && !last.call.include?('VGD_Center')
dlg.callback('mgr_list').call(nil, { src: '2022', dst: '2022' }.to_json)
check 'mgr_list báo lỗi khi nguồn trùng đích', !last.call.include?('renderMigrate') && last.call.include?('khác nhau')
dlg.callback('mgr_list').call(nil, { src: '../x', dst: '2024' }.to_json)
check 'mgr_list từ chối phiên bản lạ (chống tên thư mục lạ)', !last.call.include?('renderMigrate') && last.call.include?('chọn')
dlg.callback('mgr_migrate').call(nil, { src: '2022', dst: '2024', plugins: %w[alpha_tool beta_tool VGD_Center], overwrite: false }.to_json)
check 'chuyển plugin: chép đúng mục, không chép VGD Center', File.exist?(File.join(plug24, 'alpha_tool.rb')) && File.directory?(File.join(plug24, 'beta_tool')) &&
  File.read(File.join(plug24, 'VGD_Center.rb')) == "x\n"
check 'chuyển plugin: có sao lưu thư mục đích và nhắc mở lại SketchUp', last.call.include?('Sao lưu') && last.call.include?('mở lại bản 2024')

# ---- Mở thư mục ----
opened = []
MGR.define_singleton_method(:open_folder) { |dir| opened << dir }
dlg.callback('mgr_open_disabled').call(nil)
check 'mở thư mục đã tắt: tạo nếu chưa có và mở đúng thư mục', opened.last == MGR::Toggle.disabled_dir && File.directory?(opened.last)
dlg.callback('mgr_open_plugins').call(nil)
check 'mở thư mục Plugins của bản đang chạy', opened.last == MGR.plugins_dir(MGR::Toggle.year)

# ---- Xuất/nhập bộ plugin qua hộp chọn file ----
dlg.callback('mgr_export_sets').call(nil)
check 'xuất bộ khi chưa có bộ nào', last.call.include?('Chưa có bộ')
MGR::Toggle.save_set('Render', %w[p1 p2])
$stub_save_path = File.join(fake, 'sets_out')
dlg.callback('mgr_export_sets').call(nil)
check 'xuất bộ ra file', File.exist?(File.join(fake, 'sets_out.json')) && last.call.include?('Đã xuất 1 bộ')
MGR::Toggle.delete_set('Render')
$stub_open_path = File.join(fake, 'sets_out.json')
dlg.callback('mgr_import_sets').call(nil)
check 'nhập bộ từ file', MGR::Toggle.load_sets['Render'] == %w[p1 p2]

# ---- Dữ liệu nằm trong VGD_Center/data; dữ liệu cũ được chuyển về ----
check 'dữ liệu nằm ở Plugins/VGD_Center/data', MGR::Toggle.root_dir == File.join(plug24, 'VGD_Center', 'data')
check 'tệp bộ plugin giữ định dạng cũ (Plugin Manager cũ đọc được)', JSON.parse(File.read(File.join(fake, 'sets_out.json')))['format'] == 'vgd_plugin_sets'
old_dir = MGR::Toggle.old_roots[0]
toggle_msg = -> { dlg.scripts.reverse.find { |s| s.include?('renderToggle') }.to_s }  # tin trạng thái mới nhất (sau đó Ruby còn gửi initMigrate)
FileUtils.mkdir_p(File.join(old_dir, 'disabled'))
File.write(File.join(old_dir, 'disabled', 'mig.rb'), "m\n")
MGR.migrate_on_start
check 'lúc khởi động: chuyển dữ liệu cũ ngay, chưa cần mở tab', File.exist?(File.join(MGR::Toggle.disabled_dir, 'mig.rb')) && !File.exist?(old_dir)
dlg.callback('mgr_ready').call(nil, { lang: 'en' }.to_json)
check 'mở tab lần đầu: báo đã chuyển lúc khởi động, đúng ngôn ngữ', toggle_msg.call.include?('Moved the old enable/disable data (1 item(s))') && toggle_msg.call.include?('VGD_Center')
check 'plugin đã chuyển hiện trong danh sách đã tắt', toggle_msg.call.include?('"name":"mig"') && toggle_msg.call.include?('"status":"off"')
dlg.callback('mgr_ready').call(nil, {}.to_json)
check 'thông báo chuyển dữ liệu chỉ hiện một lần', !toggle_msg.call.include?('Đã chuyển') && !toggle_msg.call.include?('Moved the old')
FileUtils.mkdir_p(File.join(old_dir, 'disabled'))
File.write(File.join(old_dir, 'disabled', 'late.rb'), "l\n")
dlg.callback('mgr_ready').call(nil, { lang: 'vi' }.to_json)
check 'dữ liệu cũ xuất hiện sau đó: mở tab cũng chuyển và báo bằng tiếng Việt', File.exist?(File.join(MGR::Toggle.disabled_dir, 'late.rb')) && toggle_msg.call.include?('Đã chuyển dữ liệu bật/tắt cũ (1 mục)')
FileUtils.mkdir_p(File.join(old_dir, 'disabled'))
FileUtils.mkdir_p(File.join(MGR::Toggle.disabled_dir))
File.write(File.join(old_dir, 'disabled', 'late.rb'), "OTHER\n")
dlg.callback('mgr_ready').call(nil, { lang: 'en' }.to_json)
check 'trùng tên: báo mục chưa chuyển, không ghi đè', toggle_msg.call.include?('could not be moved') && File.read(File.join(MGR::Toggle.disabled_dir, 'late.rb')) == "l\n"
MGR.migrate_on_start
check 'migrate_on_start không ném lỗi và giữ báo cáo cho lần mở tab', MGR.take_startup_report.is_a?(Hash) && MGR.take_startup_report.nil?

puts($fail ? 'CÓ LỖI' : 'TẤT CẢ ĐẠT')
exit($fail ? 1 : 0)
