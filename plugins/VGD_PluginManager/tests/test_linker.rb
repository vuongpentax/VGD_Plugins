# encoding: UTF-8
# Kiểm thử việc gộp loader (.rb) với thư mục/file đi kèm khác tên.
require 'tmpdir'
require 'fileutils'
$LOAD_PATH.unshift(File.join(__dir__, 'stub'))

build = File.expand_path(ARGV[0])
fake = Dir.mktmpdir('fake_appdata')
ENV['APPDATA'] = fake
ENV['TEMP'] = Dir.tmpdir
plug = File.join(fake, 'SketchUp/SketchUp 2024/SketchUp/Plugins')
FileUtils.mkdir_p(plug)
require File.join(build, 'VGD_PluginManager/main')
PM = VGD::PluginManager
T = PM::Toggle
L = PM::Linker

def check(label, cond)
  puts "#{cond ? 'OK  ' : 'FAIL'} #{label}"
  $fail = true unless cond
end

def rb(dir, name, body = "# loader\n")
  File.write(File.join(dir, name), body)
end

def folder(dir, name)
  FileUtils.mkdir_p(File.join(dir, name, 'lib'))
  File.write(File.join(dir, name, 'lib', 'main.rb'), "x\n")
end

# 1. Loader khác tên thư mục: SketchupExtension.new('X', 'JHS/main')
rb(plug, '_jhs01_powerbar.rb', "ex = SketchupExtension.new('JHS Power Bar', 'JHS/main')\nSketchup.register_extension(ex, true)\n")
folder(plug, 'JHS')
# 2. File mã hóa không đọc được, loader nhắc bằng require 'fixSolid'
rb(plug, 'fixSolid_loader.rb', "require 'fixSolid'\n")
File.binwrite(File.join(plug, 'fixSolid.rbe'), "\x00\x01encrypted\xFF".b)
# 3. Cặp cùng tên như bình thường
rb(plug, 'abc.rb', "require File.join(File.dirname(__FILE__), 'abc', 'main')\n")
folder(plug, 'abc')
# 4. Thư viện nền (tên chứa lib) chỉ một loader nhắc: không gộp
rb(plug, 'tt_tool.rb', "require 'TT_Lib2/core.rb'\nTT::Lib.compatible?\n")
folder(plug, 'TT_Lib2')
# 5. Thư mục dùng chung bởi hai loader: không gộp
rb(plug, 'curic_a.rb', "require 'curic_shared/base'\n")
rb(plug, 'curic_b.rb', "Sketchup.require 'curic_shared/other'\n")
folder(plug, 'curic_shared')
# 6. Hai plugin độc lập, loader này nhắc tên plugin kia: không gộp
rb(plug, 'plugin_a.rb', "# cần plugin_b: require 'plugin_b/api'\n")
rb(plug, 'plugin_b.rb', "x = 1\n")
folder(plug, 'plugin_b')
# 7. Khác hoa thường và đường dẫn kiểu Windows
rb(plug, 'caseplug.rb', "require 'CaseData\\\\main'\n")
folder(plug, 'casedata')
# 8. Loader nhắc cái không tồn tại, tự nhắc chính mình
rb(plug, 'ghost.rb', "require 'ghost'\nrequire 'khong_ton_tai/x'\n")
# 9. Loader có byte lỗi UTF-8 và file quá lớn
rb(plug, 'bad_bytes.rb', "\xFF\xFE\xC3(\nrequire 'badfolder/x'\n".b)
folder(plug, 'badfolder')
rb(plug, 'huge.rb', "# " + ('a' * (L::MAX_READ + 1000)) + "\nrequire 'hugefolder/x'\n")
folder(plug, 'hugefolder')
# 10. Thư mục mồ côi không ai nhắc, file hệ thống bị bỏ qua
folder(plug, 'orphan_dir')
rb(plug, 'su_sandbox.rb')
folder(plug, 'VGD_PluginManager')

g = L.group(plug, PM::SKIP_NAMES + PM::SELF_NAMES)
names = g.keys.sort
check 'loader khác tên thư mục được gộp (JHS vào _jhs01_powerbar)', g['_jhs01_powerbar'][:items] == %w[JHS _jhs01_powerbar.rb] && g['_jhs01_powerbar'][:members] == %w[_jhs01_powerbar JHS] && !g.key?('JHS')
check 'file mã hóa .rbe được gộp vào loader nhắc tới nó', g['fixSolid_loader'][:items] == %w[fixSolid.rbe fixSolid_loader.rb] && !g.key?('fixSolid')
check 'cặp cùng tên vẫn là một plugin', g['abc'][:items] == %w[abc abc.rb] && g['abc'][:members] == ['abc']
check 'thư viện nền (tên chứa lib) đứng riêng dù chỉ một loader nhắc', g.key?('TT_Lib2') && g['tt_tool'][:items] == ['tt_tool.rb']
check 'thư mục dùng chung bởi hai loader đứng riêng', g.key?('curic_shared') && g['curic_a'][:items] == ['curic_a.rb'] && g['curic_b'][:items] == ['curic_b.rb']
check 'hai plugin độc lập nhắc tên nhau không bị gộp', g.key?('plugin_b') && g['plugin_a'][:items] == ['plugin_a.rb'] && g['plugin_b'][:items] == %w[plugin_b plugin_b.rb]
check 'khác hoa thường và đường dẫn kiểu Windows vẫn khớp', g['caseplug'][:items] == %w[casedata caseplug.rb] && !g.key?('casedata')
check 'loader nhắc mục không tồn tại hoặc chính nó thì không gộp gì', g['ghost'][:items] == ['ghost.rb']
check 'loader có byte lỗi UTF-8 không làm crash và vẫn gộp phần đọc được', g['bad_bytes'][:items].include?('badfolder')
check 'đọc giới hạn dung lượng: tham chiếu sau 100 KB bị bỏ qua', g.key?('hugefolder') && g['huge'][:items] == ['huge.rb']
check 'thư mục không ai nhắc đứng riêng', g.key?('orphan_dir')
check 'mục hệ thống và chính plugin này bị bỏ qua', !g.key?('su_sandbox') && !g.key?('VGD_PluginManager')
check 'items và members đã sắp xếp', g.values.all? { |x| x[:items] == x[:items].sort }

check 'list_plugins (dùng cho Chuyển plugin) cũng gộp', PM.list_plugins('2024').find { |p| p[:name] == '_jhs01_powerbar' }[:items] == %w[JHS _jhs01_powerbar.rb]
st = T.state['plugins'].find { |p| p['name'] == '_jhs01_powerbar' }
check 'state báo plugin gộp có 2 mục và danh sách thành phần', st['items'] == 2 && st['members'] == %w[_jhs01_powerbar JHS] && st['status'] == 'on'

entry_count = (Dir.children(plug) - PM::SKIP_NAMES - PM::SELF_NAMES).size

# --- Bật/tắt một lần cả hai nửa ---
r = T.change(%w[_jhs01_powerbar fixSolid_loader], 'disable')
check 'tắt plugin gộp: chuyển cả loader và thư mục', r[:errors].empty? && r[:changed].sort == %w[_jhs01_powerbar fixSolid_loader] &&
  !File.exist?(File.join(plug, '_jhs01_powerbar.rb')) && !File.exist?(File.join(plug, 'JHS')) && !File.exist?(File.join(plug, 'fixSolid.rbe')) &&
  File.exist?(File.join(T.disabled_dir, 'JHS/lib/main.rb')) && File.exist?(File.join(T.disabled_dir, '_jhs01_powerbar.rb')) && File.exist?(File.join(T.disabled_dir, 'fixSolid.rbe'))
s2 = T.state['plugins'].map { |p| [p['name'], p['status']] }.to_h
check 'sau khi tắt: trạng thái tắt, không có mục trùng tên hay mồ côi (JHS không hiện riêng)', s2['_jhs01_powerbar'] == 'off' && s2['fixSolid_loader'] == 'off' && !s2.key?('JHS') && !s2.key?('fixSolid') && !s2.values.include?('conflict')
st2 = T.state['plugins'].find { |p| p['name'] == '_jhs01_powerbar' }
check 'trong thư mục cất vẫn gộp đúng', st2['items'] == 2 && st2['members'] == %w[_jhs01_powerbar JHS]
r = T.change(%w[_jhs01_powerbar fixSolid_loader], 'enable')
check 'bật lại: trả cả hai nửa về Plugins', r[:errors].empty? && File.exist?(File.join(plug, 'JHS/lib/main.rb')) && File.exist?(File.join(plug, '_jhs01_powerbar.rb')) && File.exist?(File.join(plug, 'fixSolid.rbe'))

# --- Tắt tất cả không để lại nửa nào ---
all_on = T.state['plugins'].select { |p| p['status'] == 'on' }.map { |p| p['name'] }
T.change(T.bulk_targets(all_on, 'disable'), 'disable')
left = (Dir.children(plug) - PM::SKIP_NAMES - PM::SELF_NAMES).reject { |e| e.start_with?('.') }
check 'Tắt tất cả: trong Plugins không còn file hay thư mục nào của plugin (không sót nửa nào)', left.empty?
T.change(T.bulk_targets(all_on, 'enable'), 'enable')
check 'Bật tất cả: khôi phục đủ', (Dir.children(plug) - PM::SKIP_NAMES - PM::SELF_NAMES).size == entry_count && T.state['plugins'].none? { |p| p['status'] == 'conflict' }

# --- Trạng thái cũ: chỉ loader nằm trong thư mục cất, thư mục còn ở Plugins ---
FileUtils.mkdir_p(T.disabled_dir)
FileUtils.mv(File.join(plug, '_jhs01_powerbar.rb'), File.join(T.disabled_dir, '_jhs01_powerbar.rb'))
s3 = T.state['plugins'].map { |p| [p['name'], p['status']] }.to_h
check 'trạng thái dở dang cũ (chỉ loader bị dời) hiện đúng: loader tắt, thư mục JHS đứng riêng đang bật', s3['_jhs01_powerbar'] == 'off' && s3['JHS'] == 'on'

puts($fail ? 'CÓ LỖI' : 'TẤT CẢ ĐẠT')
exit($fail ? 1 : 0)
