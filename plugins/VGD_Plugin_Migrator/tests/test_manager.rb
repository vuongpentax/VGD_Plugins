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
File.write(File.join(plug, 'vgd_plugin_migrator.rb'), "self\n")
File.write(File.join(plug, '.hidden'), "h\n")

require File.join(build, 'vgd_plugin_migrator/main')
M = VGD::PluginMigrator::Manager

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

puts M.summary({ changed: ['a'], skipped: [], errors: [] }, 'disable')
puts($fail ? 'CÓ LỖI' : 'TẤT CẢ ĐẠT')
exit($fail ? 1 : 0)
