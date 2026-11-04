# encoding: UTF-8
# Test VGD Center (chạy: ruby dev/test_manager_toggle.rb). Bật/tắt plugin, bộ plugin, nhật ký, vị trí dữ liệu.
require 'tmpdir'
require 'fileutils'
$LOAD_PATH.unshift(File.join(__dir__, 'stub'))

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
# VGD Center phải được bảo vệ, kể cả khi tên khác hoa thường
File.write(File.join(plug, 'VGD_Center.rb'), "center\n")
FileUtils.mkdir_p(File.join(plug, 'VGD_Center'))
File.write(File.join(plug, 'vgd_center.rb'), "center lower\n")

require_relative '../VGD_Center/main'
M = VGD::Center::Manager::Toggle

def check(label, cond)
  puts "#{cond ? 'OK  ' : 'FAIL'} #{label}"
  $fail = true unless cond
end

names = ->(s) { s['plugins'].map { |p| [p['name'], p['status']] }.to_h }

s = M.state
check 'liệt kê đúng, bỏ qua mục hệ thống/chính nó/ẩn', names.(s) == { 'alpha' => 'on', 'beta' => 'on', 'gamma' => 'on' }
check 'alpha gồm 2 mục (rb + thư mục)', s['plugins'].first['items'] == 2
r = M.change(%w[VGD_Center vgd_center VGD_Center.rb VGD_PluginManager], 'disable')
check 'không tắt được VGD Center (cả tên viết thường) hay Plugin Manager', r[:changed].empty? && r[:skipped].size == 4 &&
  File.exist?(File.join(plug, 'VGD_Center.rb')) && File.directory?(File.join(plug, 'VGD_Center')) && File.exist?(File.join(plug, 'vgd_center.rb'))
check 'VGD Center không nằm trong danh sách bật/tắt', (names.(M.state).keys.map(&:downcase) & %w[vgd_center vgd_center.rb]).empty?
check 'bulk_targets không bao giờ chọn VGD Center', M.bulk_targets(%w[VGD_Center vgd_center alpha], 'disable') == ['alpha']

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
check 'file hỏng không làm crash, có ghi log', M.read_sets_file(bad)[1].include?('manager.log') && File.read(VGD::Center::Manager::Log.path, encoding: 'UTF-8').include?('Không đọc được file bộ plugin')
M.delete_set('Render'); M.delete_set('Vẽ'); M.delete_set('ok')
check 'xuất khi chưa có bộ', M.export_sets(out).include?('Chưa có')

# Nhật ký
log = VGD::Center::Manager::Log
File.write(log.path, 'x' * (log::MAX_BYTES + 1))
log.write('thử xoay vòng')
check 'log xoay vòng khi quá lớn', File.exist?("#{log.path}.1") && File.size(log.path) < 1000
ENV['APPDATA'] = '/proc/khong_ghi_duoc'
check 'log không ném lỗi khi không ghi được', log.write('x') == false

ENV['APPDATA'] = fake
# Vị trí lưu trữ nằm trong thư mục của Center
check 'dữ liệu nằm trong Plugins/VGD_Center/data', M.root_dir == File.join(plug, 'VGD_Center', 'data')
check 'thư mục plugin tắt nằm trong data của Center', M.disabled_dir == File.join(plug, 'VGD_Center', 'data', 'disabled')
File.write(File.join(plug, 'VGD_PluginManager.rb'), "loader\n")
File.write(File.join(plug, 'vgd_plugin_migrator.rb'), "old loader\n")
FileUtils.mkdir_p(File.join(plug, 'vgd_plugin_migrator'))
check 'Plugin Manager cũ (tên mới và tên cũ) không hiện trong danh sách', (names.(M.state).keys & %w[VGD_PluginManager vgd_plugin_migrator]).empty?
check 'không có dữ liệu cũ thì không làm gì', M.migrate_old_data.nil? && M.migration_message(nil).nil?

# --- Chuyển dữ liệu từ Plugin Manager cũ (Plugins/VGD_PluginManager/data) vào VGD_Center/data ---
reset = -> { FileUtils.rm_rf(M.root_dir); FileUtils.rm_rf(File.join(plug, 'VGD_PluginManager')); FileUtils.rm_rf(M.old_roots[1]) }
reset.call
old_pm = M.old_roots[0]
FileUtils.mkdir_p(File.join(old_pm, 'disabled/oldtool/lib'))
File.write(File.join(old_pm, 'disabled/oldtool.rb'), "old\n")
File.write(File.join(old_pm, 'disabled/oldtool/lib/x.rb'), "x\n")
File.write(File.join(old_pm, 'sets.json'), '{"Cu":["oldtool"]}')
File.write(File.join(plug, 'VGD_PluginManager.rb'), "loader\n")
File.write(File.join(plug, 'VGD_PluginManager', 'main.rb'), "plugin code\n")
report = M.migrate_old_data
check 'chuyển dữ liệu từ Plugin Manager cũ: đủ mục, không giữ lại mục nào', report && report[:moved].sort == %w[oldtool oldtool.rb sets.json] && report[:kept].empty?
check 'dữ liệu đã nằm ở VGD_Center/data, nội dung nguyên vẹn', File.read(File.join(M.disabled_dir, 'oldtool.rb')) == "old\n" && File.read(File.join(M.disabled_dir, 'oldtool/lib/x.rb')) == "x\n" && M.load_sets == { 'Cu' => ['oldtool'] }
check 'thư mục dữ liệu cũ đã được dọn', !File.exist?(old_pm)
check 'mã của Plugin Manager cũ (còn cài) không bị đụng', File.read(File.join(plug, 'VGD_PluginManager', 'main.rb')) == "plugin code\n" && File.exist?(File.join(plug, 'VGD_PluginManager.rb'))
check 'plugin đã chuyển hiện là đã tắt trong danh sách', names.(M.state)['oldtool'] == 'off'
check 'báo cáo biết Plugin Manager cũ còn cài', report[:old_pm]
msg = M.migration_message(report)
check 'thông báo nêu số mục, nơi mới và nhắc gỡ Plugin Manager cũ', msg.include?('Đã chuyển dữ liệu bật/tắt cũ (3 mục)') && msg.include?(M.root_dir) && msg.include?('cũ vẫn đang cài')
check 'chạy lại không làm gì', M.migrate_old_data.nil?
check 'bật lại plugin đã chuyển hoạt động bình thường', M.change(['oldtool'], 'enable')[:changed] == ['oldtool'] && File.exist?(File.join(plug, 'oldtool/lib/x.rb'))
FileUtils.rm_rf(File.join(plug, 'oldtool')); FileUtils.rm_f(File.join(plug, 'oldtool.rb'))

# Thư mục Plugin Manager chỉ còn dữ liệu (đã gỡ plugin): dọn luôn cả thư mục rỗng
reset.call
FileUtils.mkdir_p(File.join(old_pm, 'disabled'))
File.write(File.join(old_pm, 'disabled/solo.rb'), "solo\n")
FileUtils.rm_f(File.join(plug, 'VGD_PluginManager.rb'))
report = M.migrate_old_data
check 'Plugin Manager đã gỡ: dữ liệu chuyển hết và thư mục rỗng được dọn', report[:moved] == ['solo.rb'] && !report[:old_pm] && !File.exist?(File.join(plug, 'VGD_PluginManager')) && File.exist?(File.join(M.disabled_dir, 'solo.rb'))
check 'không nhắc gỡ Plugin Manager khi nó đã gỡ', !M.migration_message(report).include?('cũ vẫn đang cài')

# Trùng tên: không ghi đè, mục trùng ở lại chỗ cũ, các mục khác vẫn chuyển
reset.call
FileUtils.mkdir_p(File.join(old_pm, 'disabled'))
FileUtils.mkdir_p(M.disabled_dir)
File.write(File.join(old_pm, 'disabled/same.rb'), "OLD same\n")
File.write(File.join(old_pm, 'disabled/other.rb'), "other\n")
File.write(File.join(M.disabled_dir, 'same.rb'), "NEW same\n")
report = M.migrate_old_data
check 'trùng tên: chuyển mục khác, giữ lại mục trùng', report[:moved] == ['other.rb'] && report[:kept] == [File.join(old_pm, 'disabled/same.rb')]
check 'trùng tên: không ghi đè bản mới, bản cũ còn nguyên chỗ cũ', File.read(File.join(M.disabled_dir, 'same.rb')) == "NEW same\n" && File.read(File.join(old_pm, 'disabled/same.rb')) == "OLD same\n"
check 'trùng tên: thông báo nêu mục chưa chuyển', M.migration_message(report).include?('chưa chuyển được') && M.migration_message(report).include?('same.rb')
check 'trùng tên: lần chạy sau vẫn báo mục còn lại, không mất gì', M.migrate_old_data[:kept].size == 1

# Bộ plugin: gộp, bộ cùng tên ở chỗ mới được ưu tiên
reset.call
FileUtils.mkdir_p(old_pm)
File.write(File.join(old_pm, 'sets.json'), '{"Cu":["old"],"B":["b"]}')
FileUtils.mkdir_p(M.root_dir)
File.write(M.sets_file, '{"A":["a"],"Cu":["new"]}')
report = M.migrate_old_data
check 'gộp bộ plugin: bộ ở chỗ mới được ưu tiên, bộ mới của file cũ được thêm', report[:moved] == ['sets.json'] && M.load_sets == { 'A' => ['a'], 'B' => ['b'], 'Cu' => ['new'] } && !File.exist?(File.join(old_pm, 'sets.json'))
reset.call
FileUtils.mkdir_p(old_pm)
File.write(File.join(old_pm, 'sets.json'), 'không phải json')
report = M.migrate_old_data
check 'file bộ plugin cũ bị hỏng: giữ nguyên chỗ cũ, không mất', report[:kept].size == 1 && File.read(File.join(old_pm, 'sets.json'), encoding: 'UTF-8') == 'không phải json' && report[:moved].empty?

# Vị trí cũ của beta.3 (ngoài thư mục Plugins)
reset.call
legacy = M.old_roots[1]
FileUtils.mkdir_p(File.join(legacy, 'disabled'))
File.write(File.join(legacy, 'disabled', 'leg.rb'), "leg\n")
File.write(File.join(legacy, 'sets.json'), '{"Cu":["leg"]}')
report = M.migrate_old_data
check 'chuyển dữ liệu từ vị trí beta.3 (ngoài Plugins)', report[:moved].sort == %w[leg.rb sets.json] && File.exist?(File.join(M.disabled_dir, 'leg.rb')) && M.load_sets == { 'Cu' => ['leg'] } && !File.exist?(legacy)
reset.call
FileUtils.mkdir_p(M.disabled_dir)
M.delete_set('Cu')

# Cảnh báo đường dẫn không ghi được
FileUtils.mkdir_p(old_pm)
File.write(File.join(old_pm, 'sets.json'), '{"X":["x"]}')
ENV['APPDATA'] = '/proc/khong_ghi_duoc'
check 'mở tab khi không đọc được thư mục: không ném lỗi ra ngoài (migrate_on_start chỉ ghi log)', M.migration_message(nil).nil?
ENV['APPDATA'] = fake
reset.call
FileUtils.mkdir_p(M.disabled_dir)

# Kiểm tra phiên bản do giao diện gửi lên (chống tên thư mục lạ)
PMgr = VGD::Center::Manager
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
