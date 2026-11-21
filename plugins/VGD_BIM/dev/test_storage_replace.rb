# Ghi file thay thế an toàn (core/storage.rb: Storage.replace_file): file cũ không mất khi đổi tên file tạm lỗi; sau thành công không còn file .bak.
# Chạy: ruby dev/test_storage_replace.rb
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] ||= Dir.mktmpdir('vgd_bim_replace')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
require File.join(ROOT, 'core/storage')
S = VGD::BIM::Storage
dir = Dir.mktmpdir('vgd_replace')
final = File.join(dir, 'a.json')
temp = "#{final}.tmp"

File.write(final, 'cũ')
File.write(temp, 'mới')
S.replace_file(temp, final)
ok('thay file cũ bằng file mới', File.read(final) == 'mới' && !File.exist?(temp))
ok('thành công: không còn file .bak', !File.exist?("#{final}.bak"))

File.write(final, 'cũ lần hai')
begin
  S.replace_file(File.join(dir, 'không_có.tmp'), final) # file tạm không tồn tại: đổi tên lỗi
  failed = false
rescue SystemCallError
  failed = true
end
ok('đổi tên lỗi: báo lỗi', failed)
ok('đổi tên lỗi: file cũ còn nguyên, không mất', File.read(final) == 'cũ lần hai' && !File.exist?("#{final}.bak"))

File.delete(final)
File.write("#{final}.bak", 'bản sao lần trước')
File.write(temp, 'mới sau khi phục hồi')
S.replace_file(temp, final)
ok('còn .bak mà file chính đã mất (lần trước dở): khôi phục rồi thay bình thường', File.read(final) == 'mới sau khi phục hồi' && !File.exist?("#{final}.bak"))

File.write(final, 'chưa có bản tạm')
ok('không có file cũ: đổi tên thẳng', (begin; S.replace_file(File.join(dir, 'x.tmp'), File.join(dir, 'moi.json')); false; rescue SystemCallError; true; end))
puts $fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
