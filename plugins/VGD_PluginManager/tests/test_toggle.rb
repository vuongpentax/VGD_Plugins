# encoding: UTF-8
require 'tmpdir'
require 'fileutils'
$LOAD_PATH.unshift(File.join(__dir__, 'stub'))

build = File.expand_path(ARGV[0])
fake = Dir.mktmpdir('fake_appdata')
ENV['APPDATA'] = fake
ENV['TEMP'] = Dir.tmpdir
plug = File.join(fake, 'SketchUp/SketchUp 2024/SketchUp/Plugins')
FileUtils.mkdir_p(File.join(plug, 'alpha/lib'))
File.write(File.join(plug, 'alpha.rb'), "a\n")
File.write(File.join(plug, 'alpha/lib/x.rb'), "x\n")
File.write(File.join(plug, 'beta.rbe'), "b\n")
File.write(File.join(plug, 'gamma.rb'), "g\n")
File.write(File.join(plug, 'su_sandbox.rb'), "skip\n")
File.write(File.join(plug, 'VGD_PluginManager.rb'), "self\n")
File.write(File.join(plug, '.hidden'), "h\n")

require File.join(build, 'VGD_PluginManager/main')
M = VGD::PluginManager::Toggle

def check(label, cond)
  puts "#{cond ? 'OK  ' : 'FAIL'} #{label}"
  $fail = true unless cond
end

names = ->(s) { s['plugins'].map { |p| [p['name'], p['status']] }.to_h }

s = M.state
check 'liệt kê đúng, bỏ qua mục hệ thống/chính nó/ẩn', names.(s) == { 'alpha' => 'on', 'beta' => 'on', 'gamma' => 'on' }
check 'alpha gồm 2 mục (rb + thư mục)', s['plugins'].first['items'] == 2

r = M.change(%w[alpha beta ../evil nonexist], 'disable')
check 'tắt alpha, beta', r[:changed].sort == %w[alpha beta]
check 'tên lạ/path traversal bị bỏ qua', r[:skipped].sort == %w[../evil nonexist]
check 'file thật đã chuyển đi', !File.exist?(File.join(plug, 'alpha.rb')) && !File.exist?(File.join(plug, 'alpha'))
check 'file nằm trong thư mục tắt', File.exist?(File.join(M.disabled_dir, 'alpha/lib/x.rb')) && File.exist?(File.join(M.disabled_dir, 'beta.rbe'))
check 'trạng thái sau khi tắt', names.(M.state) == { 'alpha' => 'off', 'beta' => 'off', 'gamma' => 'on' }
check 'không tắt lần hai', M.change(['alpha'], 'disable')[:skipped] == ['alpha']

# Bật lại
r = M.change(['alpha'], 'enable')
check 'bật lại alpha', r[:changed] == ['alpha'] && File.read(File.join(plug, 'alpha/lib/x.rb')) == "x\n"

# Trùng tên: beta đang tắt, tạo beta mới trong Plugins
File.write(File.join(plug, 'beta.rb'), "new\n")
check 'phát hiện trùng tên', names.(M.state)['beta'] == 'conflict'
r = M.change(['beta'], 'enable')
check 'không ghi đè khi trùng', r[:errors].size == 1 && File.read(File.join(M.disabled_dir, 'beta.rbe')) == "b\n"
FileUtils.rm_f(File.join(plug, 'beta.rb'))

# Hoàn tác khi lỗi giữa chừng: alpha có 2 mục, chặn mục thứ hai bằng file đã tồn tại ở đích
FileUtils.mkdir_p(M.disabled_dir)
File.write(File.join(M.disabled_dir, 'alpha'), 'chan')   # đích của thư mục 'alpha' bị chiếm
r = M.change(['alpha'], 'disable')
check 'lỗi giữa chừng được báo', r[:errors].size == 1 || r[:skipped].empty? == false
check 'hoàn tác: alpha.rb và thư mục vẫn ở Plugins', File.exist?(File.join(plug, 'alpha.rb')) && File.directory?(File.join(plug, 'alpha'))
FileUtils.rm_f(File.join(M.disabled_dir, 'alpha'))

# Bộ plugin
check 'lưu bộ', M.save_set('Render', %w[alpha gamma nope]).include?('2 plugin')
check 'bộ rỗng bị từ chối', M.save_set('X', ['nope']).include?('ít nhất')
check 'tên rỗng bị từ chối', M.save_set('  ', ['alpha']).include?('tên')
s = M.state
check 'bộ hiện trong state', s['sets'].size == 1 && s['sets'][0]['count'] == 2
r = M.change(M.load_sets['Render'], 'disable')
check 'tắt cả bộ', r[:changed].sort == %w[alpha gamma]
r = M.change(M.load_sets['Render'], 'enable')
check 'bật cả bộ', r[:changed].sort == %w[alpha gamma]
check 'xóa bộ', M.delete_set('Render').include?('Đã xóa') && M.load_sets.empty?
check 'xóa bộ không tồn tại', M.delete_set('zzz').include?('Không tìm thấy')

# Xuất/nhập bộ plugin
M.save_set('Render', %w[alpha gamma])
M.save_set('Vẽ', %w[alpha])
out = File.join(Dir.tmpdir, "sets_#{$$}")
msg = M.export_sets(out)
check 'xuất bộ ra file .json', msg.include?('2 bộ') && File.exist?("#{out}.json")
sets, err = M.read_sets_file("#{out}.json")
check 'đọc lại đúng nội dung (có tiếng Việt)', err.nil? && sets == { 'Render' => %w[alpha gamma], 'Vẽ' => %w[alpha] }
M.delete_set('Render')
check 'nhập bộ mới, giữ bộ trùng', M.import_sets(sets, false).include?('1 bộ mới') && M.load_sets['Vẽ'] == %w[alpha]
M.save_set('Vẽ', %w[gamma])
check 'trùng tên + không ghi đè thì bỏ qua', M.import_sets(sets, false).include?('Bỏ qua 2') && M.load_sets['Vẽ'] == %w[gamma]
check 'trùng tên + ghi đè', M.import_sets(sets, true).include?('2 bộ ghi đè') && M.load_sets['Vẽ'] == %w[alpha]
bad = File.join(Dir.tmpdir, "bad_#{$$}.json")
File.write(bad, '{"hello":1}')
check 'file sai định dạng bị từ chối', M.read_sets_file(bad)[1].include?('không đúng định dạng')
File.write(bad, '{"format":"vgd_plugin_sets","sets":{"ok":["a",5,null,""],"x":"str","  ":["a"],"y":[1]}}')
check 'dữ liệu sai kiểu bị lọc', M.read_sets_file(bad)[0] == { 'ok' => ['a'] }
File.write(bad, 'không phải json')
check 'file hỏng không làm crash, có ghi log', M.read_sets_file(bad)[1].include?('migrator.log') && File.read(VGD::PluginManager::Log.path, encoding: 'UTF-8').include?('Không đọc được file bộ plugin')
M.delete_set('Render'); M.delete_set('Vẽ'); M.delete_set('ok')
check 'xuất khi chưa có bộ', M.export_sets(out).include?('Chưa có')

# Nhật ký
log = VGD::PluginManager::Log
File.write(log.path, 'x' * (log::MAX_BYTES + 1))
log.write('thử xoay vòng')
check 'log xoay vòng khi quá lớn', File.exist?("#{log.path}.1") && File.size(log.path) < 1000
ENV['APPDATA'] = '/proc/khong_ghi_duoc'
check 'log không ném lỗi khi không ghi được', log.write('x') == false

ENV['APPDATA'] = fake
# Vị trí lưu trữ mới nằm trong thư mục Plugins
check 'dữ liệu nằm trong Plugins/VGD_PluginManager/data', M.root_dir == File.join(plug, 'VGD_PluginManager', 'data')
check 'thư mục plugin tắt nằm trong data', M.disabled_dir.start_with?(File.join(plug, 'VGD_PluginManager'))
FileUtils.mkdir_p(File.join(plug, 'VGD_PluginManager/data/disabled'))
File.write(File.join(plug, 'VGD_PluginManager.rb'), "loader\n")
File.write(File.join(plug, 'vgd_plugin_migrator.rb'), "old loader\n")
FileUtils.mkdir_p(File.join(plug, 'vgd_plugin_migrator'))
check 'plugin này (tên mới và tên cũ) không hiện trong danh sách', (names.(M.state).keys & %w[VGD_PluginManager vgd_plugin_migrator]).empty?

# Chuyển dữ liệu từ vị trí cũ (ngoài Plugins) sang vị trí mới
FileUtils.rm_rf(M.root_dir)
FileUtils.mkdir_p(File.join(M.legacy_root_dir, 'disabled'))
File.write(File.join(M.legacy_root_dir, 'disabled', 'old.rb'), "old\n")
File.write(File.join(M.legacy_root_dir, 'sets.json'), '{"Cu":["old"]}')
check 'chuyển dữ liệu cũ vào vị trí mới', M.migrate_legacy.to_s.include?('Đã chuyển') &&
  File.exist?(File.join(M.disabled_dir, 'old.rb')) && M.load_sets == { 'Cu' => ['old'] } && !File.exist?(M.legacy_root_dir)
check 'chạy lại không làm gì', M.migrate_legacy.nil?
FileUtils.mkdir_p(File.join(M.legacy_root_dir, 'disabled'))
check 'không ghi đè khi vị trí mới đã có dữ liệu', M.migrate_legacy.nil? && File.directory?(M.legacy_root_dir)
FileUtils.rm_rf(M.legacy_root_dir)
FileUtils.rm_rf(M.disabled_dir); FileUtils.mkdir_p(M.disabled_dir)
M.delete_set('Cu')

# Kiểm tra phiên bản do giao diện gửi lên (chống tên thư mục lạ)
PMgr = VGD::PluginManager
FileUtils.mkdir_p(File.join(fake, 'SketchUp/SketchUp 2022/SketchUp/Plugins'))
check 'phiên bản hợp lệ', PMgr.check_versions('2022', '2024').nil?
check 'trùng nhau bị từ chối', PMgr.check_versions('2024', '2024').include?('khác nhau')
check 'phiên bản lạ/path traversal bị từ chối', PMgr.check_versions('../x', '2024').include?('chọn')

# Tắt/bật hàng loạt
%w[bulk_a bulk_b TT_Lib2 Fredo6_!LibFredo6 5d_library VGD_Dim].each { |n| File.write(File.join(plug, "#{n}.rb"), "x\n") }
all_on = M.state['plugins'].select { |x| x['status'] == 'on' }.map { |x| x['name'] }
check 'bulk_targets tắt: chỉ lấy mục đang bật, bỏ tên lạ và trùng', M.bulk_targets(all_on + %w[nonexist ../x bulk_a], 'disable').sort == all_on.sort
check 'bulk_targets bật: không có gì khi chưa tắt', M.bulk_targets(all_on, 'enable').empty?
check 'nhận ra thư viện nền theo tên', M.library_like(%w[bulk_a TT_Lib2 Fredo6_!LibFredo6 5d_library VGD_Dim]) == %w[TT_Lib2 Fredo6_!LibFredo6 5d_library]
txt = M.bulk_confirm_text(%w[bulk_a TT_Lib2 5d_library], 'disable')
check 'hộp xác nhận tắt nêu số lượng, thư viện nền và cách bật lại', txt.include?('Tắt 3 plugin') && txt.include?('TT_Lib2') && txt.include?('5d_library') && txt.include?('Bật tất cả')
many = (1..9).map { |i| "lib#{i}" }
check 'nhiều thư viện nền thì rút gọn', M.bulk_confirm_text(many, 'disable').include?('và 3 mục khác')
check 'không có thư viện nền thì không cảnh báo thư viện', !M.bulk_confirm_text(%w[bulk_a], 'disable').include?('thư viện nền')
check 'hộp xác nhận bật', M.bulk_confirm_text(%w[bulk_a bulk_b], 'enable').include?('Bật 2 plugin')
r = M.change(M.bulk_targets(all_on, 'disable'), 'disable')
check 'tắt tất cả: mọi mục đang bật đã tắt, không lỗi', r[:errors].empty? && r[:changed].sort == all_on.sort && M.state['plugins'].none? { |x| x['status'] == 'on' }
check 'sau khi tắt: bulk_targets bật lấy đủ mục', M.bulk_targets(all_on, 'enable').sort == all_on.sort
r = M.change(M.bulk_targets(all_on, 'enable'), 'enable')
check 'bật tất cả: khôi phục đủ, không lỗi', r[:errors].empty? && M.state['plugins'].all? { |x| x['status'] == 'on' }

puts M.summary({ changed: ['a'], skipped: [], errors: [] }, 'disable')
puts($fail ? 'CÓ LỖI' : 'TẤT CẢ ĐẠT')
exit($fail ? 1 : 0)
