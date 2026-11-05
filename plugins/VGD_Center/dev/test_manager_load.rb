# encoding: UTF-8
# Test VGD Center (chạy: ruby dev/test_manager_load.rb): nút "Nạp ngay" của tab Quản lý.
# Plugin bật lại sau khi SketchUp đã khởi động được nạp vào phiên đang chạy, không cần khởi động lại.
require 'tmpdir'
require 'fileutils'
$LOAD_PATH.unshift(File.join(__dir__, 'stub'))

fake = Dir.mktmpdir('fake_appdata')
ENV['APPDATA'] = fake
plug = File.join(fake, 'SketchUp/SketchUp 2024/SketchUp/Plugins')
off = File.join(plug, 'VGD_Center/data/disabled')
FileUtils.mkdir_p(plug)
FileUtils.mkdir_p(off)
$ran = []
# Có sẵn lúc SketchUp khởi động: coi như đã chạy trong phiên này
File.write(File.join(plug, 'started.rb'), "$ran << 'started'\n")
# Đã tắt từ trước khi khởi động: chưa từng chạy trong phiên này
File.write(File.join(off, 'was_off.rb'), "$ran << 'was_off'\n")

require_relative '../VGD_Center/main'
M = VGD::Center::Manager::Toggle

def check(label, cond, detail = nil)
  puts "#{cond ? 'OK  ' : 'FAIL'} #{label}#{detail && !cond ? " — #{detail}" : ''}"
  $fail = true unless cond
end
pending = -> { M.state['plugins'].select { |p| p['pending'] }.map { |p| p['name'] }.sort }

# Plugin cài/chép vào Plugins sau khi SketchUp đã khởi động
File.write(File.join(plug, 'late_a.rb'), "$ran << 'late_a'\n")
File.write(File.join(plug, 'TT_Lib_late.rb'), "$ran << 'TT_Lib_late'\n")
File.write(File.join(plug, 'bad_raise.rb'), "raise 'boom'\n")
File.write(File.join(plug, 'bad_syntax.rb'), "def (\n")
FileUtils.mkdir_p(File.join(plug, 'dir_only'))
File.write(File.join(plug, 'dir_only/x.rb'), "$ran << 'dir_only'\n")
File.write(File.join(plug, 'external.rb'), "$ran << 'external'\n")
Kernel.require(File.join(plug, 'external'))   # như Extension Manager cài và nạp ngay
$ran.clear

check 'chờ nạp: chỉ plugin chưa chạy và có file nạp',
      pending.call == %w[TT_Lib_late bad_raise bad_syntax late_a], pending.call.inspect
check 'plugin có lúc khởi động không chờ nạp', !pending.call.include?('started')
check 'plugin đã nạp bằng require (Extension Manager) không chờ nạp', !pending.call.include?('external')
check 'thư mục không có file nạp không chờ nạp', !pending.call.include?('dir_only')
check 'plugin đang tắt không chờ nạp', M.state['plugins'].find { |p| p['name'] == 'was_off' }['pending'] == false

check 'load_targets bỏ tên lạ, đã chạy, đang tắt, thoát đường dẫn',
      M.load_targets(%w[late_a started was_off ../x nonexist dir_only external late_a]) == %w[late_a]

r = M.load_now(%w[started external])
check 'plugin đã chạy sẵn: không nạp lại', r[:already].sort == %w[external started] && r[:loaded].empty? && $ran.empty?, r.inspect

r = M.load_now(%w[late_a TT_Lib_late])
check 'nạp thành công', r[:loaded].sort == %w[TT_Lib_late late_a] && r[:errors].empty?, r.inspect
check 'thư viện nền được nạp trước', $ran == %w[TT_Lib_late late_a], $ran.inspect
check 'sau khi nạp: hết chờ nạp', !pending.call.include?('late_a') && !pending.call.include?('TT_Lib_late')
$ran.clear
r = M.load_now(%w[late_a])
check 'nạp lần hai: báo đã chạy, không chạy lại mã', r[:already] == %w[late_a] && $ran.empty?, r.inspect

r = M.load_now(%w[bad_raise bad_syntax late_a])
check 'plugin lỗi: gom lỗi theo tên, không ném ngoại lệ', r[:errors].size == 2 && r[:errors].any? { |e| e.start_with?('bad_raise: ') && e.include?('boom') } &&
      r[:errors].any? { |e| e.start_with?('bad_syntax: ') }, r.inspect
check 'plugin lỗi vẫn chờ nạp (thử lại được), không đánh dấu đã chạy', pending.call == %w[bad_raise bad_syntax]

r = M.load_now(%w[dir_only was_off nonexist])
check 'không có file nạp / đang tắt / không tồn tại: bỏ qua', r[:skipped].sort == %w[dir_only nonexist was_off] && r[:loaded].empty?, r.inspect

# Bật plugin đã tắt từ trước khi khởi động, rồi nạp ngay
res = M.change(%w[was_off], 'enable')
check 'bật was_off', res[:changed] == %w[was_off]
check 'was_off bật xong thì chờ nạp', pending.call.include?('was_off')
r = M.load_now(%w[was_off])
check 'nạp was_off', r[:loaded] == %w[was_off] && $ran.include?('was_off'), r.inspect

# Tắt rồi bật lại plugin đã nạp trong phiên: vẫn đang chạy trong bộ nhớ, không nạp lại
$ran.clear
M.change(%w[was_off started], 'disable')
M.change(%w[was_off started], 'enable')
check 'tắt rồi bật lại plugin đã chạy: không chờ nạp', !pending.call.include?('was_off') && !pending.call.include?('started')

# Hộp xác nhận
txt = M.load_confirm_text(%w[late_a TT_Lib_late])
check 'hộp xác nhận nêu số lượng, tên, thư viện nền và cách dừng', txt.include?('2 plugin') && txt.include?('late_a') && txt.include?('TT_Lib_late') && txt.downcase.include?('khởi động lại')
check 'hộp xác nhận chỉ hiện một lần mỗi phiên', M.warned_load? == false && (M.warned_load!; M.warned_load?) == true

# Tóm tắt
s = M.load_summary(loaded: %w[a], already: %w[b], skipped: %w[c], errors: ['d: boom'])
check 'tóm tắt có đủ phần', s.include?('b') && s.include?('c') && s.include?('d: boom') && s.include?('Đã nạp')

puts($fail ? 'CÓ LỖI' : 'TẤT CẢ ĐẠT')
exit($fail ? 1 : 0)
