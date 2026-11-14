# encoding: UTF-8
# Test VGD Center (chạy: ruby dev/test_manager_i18n.rb): tiếng Anh của tab Quản lý.
# Kiểm bảng dịch Ruby, bảng dịch JS, chữ tĩnh trong dialog.html, và ngôn ngữ đi từ giao diện sang thông báo của Ruby.
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

require 'sketchup.rb'
module UI
  class HtmlDialog
    def initialize(**_options); @callbacks = {}; @scripts = []; end
    def add_action_callback(name, &block); @callbacks[name] = block; end
    def callback(name); @callbacks[name]; end
    def execute_script(script); @scripts << script; end
    attr_reader :scripts
  end
  def self.boxes; @boxes ||= []; end
  def self.panel_titles; @panel_titles ||= []; end
  def self.messagebox(text, *_args); boxes << text; IDYES; end
  def self.savepanel(title, *_args); panel_titles << title; $stub_save_path; end
  def self.openpanel(title, *_args); panel_titles << title; $stub_open_path; end
end

require_relative '../vgd_center/main'
CENTER = VGD::Center
MGR = VGD::Center::Manager
ROOT = File.join(__dir__, '..', 'vgd_center')
VIET = /[À-ỹ]/

def check(label, cond, detail = nil)
  puts "#{cond ? 'OK  ' : 'FAIL'} #{label}#{detail && !cond ? " — #{detail}" : ''}"
  $fail = true unless cond
end

# ---------- A. Bảng dịch Ruby (manager/text.rb) ----------
messages = MGR::Text::MESSAGES
check 'mỗi thông báo Ruby có đủ tiếng Việt và tiếng Anh', messages.all? { |_k, v| v.keys.sort == %i[en vi] && v.values.none? { |s| s.strip.empty? } }
holes = ->(s) { s.scan(/%\{(\w+)\}/).flatten.sort }
bad = messages.reject { |_k, v| holes.call(v[:vi]) == holes.call(v[:en]) }.keys
check "chỗ điền %{...} giống nhau giữa hai ngôn ngữ (lệch: #{bad.join(', ')})", bad.empty?
bad = messages.select { |_k, v| v[:en] =~ VIET }.keys
check "tiếng Anh của Ruby không còn chữ tiếng Việt (lỗi: #{bad.join(', ')})", bad.empty?
bad = messages.reject { |_k, v| v[:vi] =~ VIET || v[:vi] =~ /\A[A-Za-z0-9 .\/%{}()]+\z/ }.keys
check "tiếng Việt của Ruby có chữ tiếng Việt (nghi chưa dịch: #{bad.join(', ')})", bad.empty?
ok = messages.all? do |key, v|
  vars = holes.call(v[:vi]).map { |h| [h.to_sym, '1'] }.to_h
  %w[vi en].all? { |l| MGR.lang = l; MGR.t(key, vars).is_a?(String) }
end
check 'mọi thông báo điền được giá trị ở cả hai ngôn ngữ (không thiếu biến)', ok
MGR.lang = 'en'; check 'đặt ngôn ngữ en', MGR.lang == 'en'
MGR.lang = 'fr'; check 'ngôn ngữ lạ thì dùng tiếng Việt', MGR.lang == 'vi'
MGR.lang = nil;  check 'không có ngôn ngữ thì dùng tiếng Việt', MGR.lang == 'vi'

sources = Dir.glob(File.join(ROOT, 'manager', '*.rb')).reject { |f| f.end_with?('text.rb') }.map { |f| File.read(f, encoding: 'UTF-8') }.join("\n")
used = sources.scan(/(?:\bt\(|guard\.call\()?:(\w+)/).flatten.uniq
called = sources.scan(/\bt\(:(\w+)/).flatten.uniq
check "mọi t(:khóa) trong mã đều có trong bảng dịch (thiếu: #{(called - messages.keys.map(&:to_s)).join(', ')})", (called - messages.keys.map(&:to_s)).empty?
unused = messages.keys.map(&:to_s).reject { |k| sources.include?(":#{k}") }
check "không có thông báo thừa chưa dùng (thừa: #{unused.join(', ')})", unused.empty?

# ---------- B. Bảng dịch JS (manager/manager.js) ----------
js = File.read(File.join(ROOT, 'manager', 'manager.js'), encoding: 'UTF-8')
block = js[/var I18N = \{\s*vi: \{(.*?)\n    \},\s*en: \{(.*?)\n    \}\s*\};/m, 0]
check 'tìm thấy bảng I18N trong manager.js', !block.nil?
vi_block, en_block = js.match(/var I18N = \{\s*vi: \{(.*?)\n    \},\s*en: \{(.*?)\n    \}\s*\};/m).captures
pairs = ->(s) { s.scan(/(\w+): '((?:[^'\\]|\\.)*)'/).to_h }
jvi = pairs.call(vi_block)
jen = pairs.call(en_block)
check "bảng JS: hai ngôn ngữ có cùng khóa (lệch: #{((jvi.keys - jen.keys) + (jen.keys - jvi.keys)).join(', ')})", jvi.keys.sort == jen.keys.sort && !jvi.empty?
jholes = ->(s) { s.scan(/\{(\w+)\}/).flatten.sort }
bad = jvi.keys.reject { |k| jholes.call(jvi[k]) == jholes.call(jen[k].to_s) }
check "bảng JS: chỗ điền {...} giống nhau (lệch: #{bad.join(', ')})", bad.empty?
bad = jen.select { |_k, v| v =~ VIET }.keys
check "bảng JS: tiếng Anh không còn chữ tiếng Việt (lỗi: #{bad.join(', ')})", bad.empty?
rest = js.sub(block.to_s, '')
unused = jvi.keys.reject { |k| rest.include?("'#{k}'") || rest.include?("'#{k.sub(/_shown\z/, '')}'") }
check "bảng JS: không có khóa thừa (thừa: #{unused.join(', ')})", unused.empty?
used = rest.scan(/\bt\('(\w+)'/).flatten.uniq
check "bảng JS: mọi t('khóa') đều có trong bảng (thiếu: #{(used - jvi.keys).join(', ')})", (used - jvi.keys).empty?
check 'manager.js gửi lang kèm mọi lệnh và có setLanguage', js.include?("var data = { lang: lang };") && js.include?('setLanguage: setLanguage')

# ---------- C. Chữ tĩnh trong dialog.html ----------
html = File.read(File.join(ROOT, 'dialog.html'), encoding: 'UTF-8')
english = html[/const englishText = \{(.*?)\n      \};/m, 1].to_s.scan(/'((?:[^'\\]|\\.)*)':'((?:[^'\\]|\\.)*)'/).to_h
check 'đọc được bảng englishText của Center', english.size > 50
page = html[/<section class="page" id="page-manager".*?\n        <\/section>\n\n/m].to_s
static = page.gsub(%r{<(\w+)\b[^>]*data-no-translate[^>]*>.*?</\1>}m, '')
texts = static.scan(/>([^<>]+)</).flatten.map(&:strip).reject(&:empty?).uniq
missing = texts.reject { |t| english.key?(t) }
check "mọi chữ tĩnh của trang Quản lý đều có tiếng Anh (thiếu: #{missing.join(' | ')})", missing.empty? && !texts.empty?
check 'bản dịch trang Quản lý không còn chữ tiếng Việt', texts.none? { |t| english[t] =~ VIET }
dynamic_ids = %w[mgrList mgrSets mgrMlist mgrOut mgrBulkOff mgrBulkOn mgrGo mgrCountOn mgrCountOff mgrCountSets mgrYear mgrMCount]
check 'các phần tử do JS ghi chữ đều được loại khỏi bộ dịch chữ tĩnh (data-no-translate)',
      dynamic_ids.all? { |id| page =~ /id="#{id}"[^>]*data-no-translate/ && js.include?("'#{id}'") }
check 'bộ dịch chữ tĩnh của Center bỏ qua phần tử data-no-translate', html.include?("closest('[data-no-translate],")
check 'Center báo ngôn ngữ cho tab Quản lý khi đổi ngôn ngữ', html.include?('window.VGDManager.setLanguage(activeLanguage)')
overview = ['Cài plugin VGD còn thiếu, cập nhật bản đã cài và quản lý mọi plugin ngay trong SketchUp.',
            'Cài đặt và cập nhật plugin VGD, đồng thời bật/tắt, chuyển và đóng gói mọi plugin trong SketchUp. VGD Center tải gói, xác minh và cài đặt giúp bạn.',
            'Quản lý mọi plugin', 'Quản lý plugin']
check 'chữ mới của Tổng quan đều có tiếng Anh', overview.all? { |t| english[t] && english[t] !~ VIET && html.include?(t) }
check 'Tổng quan có nút mở thẳng tab Quản lý', html.include?('<button class="btn" data-page="manager">')
check 'tên nút/tab tiếng Anh khớp với thông báo của Ruby',
      MGR::Text::MESSAGES[:confirm_disable_tail][:en].include?('"Enable all"') && jen['bulk_on'].start_with?('Enable all') &&
      MGR::Text::MESSAGES[:bundle_next][:en].include?("\"#{english['Xuất các bộ ra file']}\"") &&
      MGR::Text::MESSAGES[:bundle_next][:en].include?("#{english['Bật/tắt']} tab")
check 'tên nút/tab tiếng Việt khớp với thông báo của Ruby',
      MGR::Text::MESSAGES[:confirm_disable_tail][:vi].include?('"Bật tất cả"') && jvi['bulk_on'].start_with?('Bật tất cả') &&
      MGR::Text::MESSAGES[:bundle_next][:vi].include?('"Xuất các bộ ra file"') && MGR::Text::MESSAGES[:bundle_next][:vi].include?('tab Bật/tắt')

# ---------- D. Ngôn ngữ đi từ giao diện sang thông báo của Ruby ----------
dlg = UI::HtmlDialog.new
CENTER.register_callbacks(dlg)
last = -> { dlg.scripts.last.to_s }
%w[p1 p2 TT_Lib2].each { |n| File.write(File.join(plug24, "#{n}.rb"), "x\n") }
File.write(File.join(plug22, 'alpha.rb'), "puts 1\n")

dlg.callback('mgr_bulk').call(nil, { lang: 'en', action: 'enable', names: %w[p1] }.to_json)
check 'en: không có plugin tắt để bật', last.call.include?('There are no disabled plugins to enable.')
dlg.callback('mgr_bulk').call(nil, { action: 'enable', names: %w[p1] }.to_json)
check 'không gửi lang: tiếng Việt', last.call.include?('Không có plugin nào đang tắt để bật.')
dlg.callback('mgr_bulk').call(nil, { lang: 'fr', action: 'enable', names: %w[p1] }.to_json)
check 'lang lạ: tiếng Việt', last.call.include?('Không có plugin nào đang tắt để bật.')

UI.boxes.clear
dlg.callback('mgr_bulk').call(nil, { lang: 'en', action: 'disable', names: %w[p1 TT_Lib2] }.to_json)
check 'en: hộp xác nhận bằng tiếng Anh, nêu thư viện nền và nút bật lại', UI.boxes.last.to_s.include?('Disable 2 plugin(s)') && UI.boxes.last.to_s.include?('TT_Lib2') && UI.boxes.last.to_s.include?('"Enable all"') && UI.boxes.last.to_s !~ VIET, UI.boxes.last.inspect
check 'en: kết quả sau khi tắt bằng tiếng Anh', last.call.include?('Disabled: 2 plugin(s).') && last.call.include?('Restart SketchUp for the change to take effect.')
dlg.callback('mgr_bulk').call(nil, { lang: 'en', action: 'enable', names: %w[p1 TT_Lib2] }.to_json)
check 'en: hộp xác nhận bật bằng tiếng Anh', UI.boxes.last.to_s.include?('Enable 2 plugin(s)?') && last.call.include?('Enabled: 2 plugin(s).')

dlg.callback('mgr_change').call(nil, { lang: 'en', names: [], action: 'disable' }.to_json)
check 'en: chưa chọn plugin nào', last.call.include?('Select at least one plugin.')
dlg.callback('mgr_change').call(nil, { lang: 'en', names: %w[VGD_Center nope], action: 'disable' }.to_json)
check 'en: báo mục bị bỏ qua', last.call.include?('Skipped (already in that state or not found): 2.')

dlg.callback('mgr_save_set').call(nil, { lang: 'en', name: ' ', names: %w[p1] }.to_json)
check 'en: bộ cần có tên', last.call.include?('Enter a name for the plugin set.')
dlg.callback('mgr_save_set').call(nil, { lang: 'en', name: 'Render', names: %w[p1 p2] }.to_json)
check 'en: lưu bộ', last.call.include?('Saved set \"Render\" with 2 plugin(s).')
dlg.callback('mgr_apply_set').call(nil, { lang: 'en', name: 'khong_co', action: 'disable' }.to_json)
check 'en: không tìm thấy bộ', last.call.include?('Set not found.')
dlg.callback('mgr_delete_set').call(nil, { lang: 'en', name: 'Render' }.to_json)
check 'en: xóa bộ', last.call.include?('Deleted set \"Render\" (the plugins are not affected).')

dlg.callback('mgr_export_sets').call(nil, { lang: 'en' }.to_json)
check 'en: chưa có bộ để xuất', last.call.include?('There are no plugin sets to export.')
MGR::Toggle.save_set('Render', %w[p1])
$stub_save_path = File.join(fake, 'sets_en')
UI.panel_titles.clear
dlg.callback('mgr_export_sets').call(nil, { lang: 'en' }.to_json)
check 'en: hộp lưu file và kết quả xuất bộ bằng tiếng Anh', UI.panel_titles.last == 'Save plugin sets' && last.call.include?('Exported 1 plugin set(s) to:')
$stub_open_path = File.join(fake, 'sets_en.json')
MGR::Toggle.save_set('Render', %w[p2])
dlg.callback('mgr_import_sets').call(nil, { lang: 'en' }.to_json)
check 'en: hộp chọn file và hộp hỏi trùng tên bằng tiếng Anh', UI.panel_titles.last == 'Choose a plugin-set file (.json)' && UI.boxes.last.to_s.include?('1 set(s) have the same name: Render.') && UI.boxes.last.to_s !~ VIET
check 'en: kết quả nhập bộ bằng tiếng Anh', last.call.include?('Imported: 0 new set(s), 1 overwritten.')
File.write(File.join(fake, 'bad.json'), '{"x":1}')
$stub_open_path = File.join(fake, 'bad.json')
dlg.callback('mgr_import_sets').call(nil, { lang: 'en' }.to_json)
check 'en: file sai định dạng', last.call.include?('The file is not a VGD plugin-set file.')
dlg.callback('mgr_import_sets').call(nil, { lang: 'vi' }.to_json)
check 'vi: file sai định dạng vẫn tiếng Việt', last.call.include?('File không đúng định dạng bộ plugin của VGD.')

dlg.callback('mgr_list').call(nil, { lang: 'en', src: '2022', dst: '2022' }.to_json)
check 'en: nguồn trùng đích', last.call.include?('The source and destination versions must be different.')
dlg.callback('mgr_list').call(nil, { lang: 'en', src: '2022', dst: '1999' }.to_json)
check 'en: phiên bản lạ', last.call.include?('Choose a source and a destination version.')
dlg.callback('mgr_migrate').call(nil, { lang: 'en', src: '2022', dst: '2024', plugins: %w[alpha], overwrite: false }.to_json)
check 'en: kết quả chuyển plugin bằng tiếng Anh', last.call.include?('Copied: 1 item(s).') && last.call.include?('Backup of the destination folder:') && last.call.include?('Close SketchUp and reopen version 2024 to apply the change.')
dlg.callback('mgr_migrate').call(nil, { lang: 'en', src: '2022', dst: '2024', plugins: 5 }.to_json)
check 'en: lỗi bất ngờ có tên lỗi bằng tiếng Anh và chỉ dẫn xem nhật ký', last.call.include?('Error migrating plugins:') && last.call.include?('Error details were written to:') && last.call.include?('manager.log')
check 'nhật ký lỗi vẫn ghi tiếng Việt (dành cho người hỗ trợ)', File.exist?(MGR::Log.path)

$stub_save_path = File.join(fake, 'bundle_en')
UI.panel_titles.clear
dlg.callback('mgr_export_bundle').call(nil, { lang: 'en', src: '2022', dst: '2024', plugins: [] }.to_json)
check 'en: chưa chọn plugin để xuất gói', last.call.include?('Tick at least one plugin to export a package.')
dlg.callback('mgr_export_bundle').call(nil, { lang: 'en', src: '2022', dst: '2024', plugins: %w[alpha] }.to_json)
check 'en: hộp lưu gói và kết quả xuất gói bằng tiếng Anh', UI.panel_titles.last == 'Save the bundle .rbz' && last.call.include?('Exported package:') &&
  last.call.include?('Plugin files in the package: 1') && last.call.include?('On the new computer:') && last.call.scan(VIET).empty?

CENTER.instance_variable_set(:@busy, true)
dlg.callback('mgr_change').call(nil, { lang: 'en', names: %w[p1], action: 'disable' }.to_json)
check 'en: thông báo Center đang bận bằng tiếng Anh', last.call.include?('VGD Center is installing or removing plugins.')
CENTER.instance_variable_set(:@busy, false)

dlg.callback('mgr_open_plugins').call(nil, { lang: 'en' }.to_json)
FileUtils.rm_rf(plug24)
dlg.callback('mgr_open_plugins').call(nil, { lang: 'en' }.to_json)
check 'en: không thấy thư mục Plugins', last.call.include?('Plugins folder not found:')

puts($fail ? 'CÓ LỖI' : 'TẤT CẢ ĐẠT')
exit($fail ? 1 : 0)
