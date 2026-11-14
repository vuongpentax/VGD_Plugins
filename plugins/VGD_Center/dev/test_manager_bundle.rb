# encoding: UTF-8
# Test VGD Center (chạy: ruby dev/test_manager_bundle.rb): xuất gói .rbz tổng và đọc lại từng file để so nội dung.
require 'tmpdir'
require 'fileutils'
require 'json'
require 'zlib'
$LOAD_PATH.unshift(File.join(__dir__, 'stub'))

fake = Dir.mktmpdir('fake_appdata')
ENV['APPDATA'] = fake
plug = File.join(fake, 'SketchUp/SketchUp 2022/SketchUp/Plugins')
FileUtils.mkdir_p(File.join(plug, 'cool_tool/lib/sub'))
tool_rb = "puts 'tool'\n# tiếng Việt\n" * 200
data_bin = (0..255).to_a.pack('C*') * 40
File.write(File.join(plug, 'cool_tool.rb'), tool_rb)
File.write(File.join(plug, 'cool_tool/lib/sub/x.rb'), "x=1\n" * 50)
File.binwrite(File.join(plug, 'cool_tool/data.bin'), data_bin)
File.write(File.join(plug, 'single.rb'), "puts 1\n")
File.write(File.join(plug, 'su_sandbox.rb'), "skip\n")
File.write(File.join(plug, 'VGD_Center.rb'), "center\n")
FileUtils.mkdir_p(File.join(plug, 'VGD_Center'))
File.write(File.join(plug, 'VGD_Center/main.rb'), "center main\n")
FileUtils.mkdir_p(File.join(fake, 'SketchUp/SketchUp 2024/SketchUp/Plugins'))

require_relative '../vgd_center/main'
MGR = VGD::Center::Manager

def check(label, cond)
  puts "#{cond ? 'OK  ' : 'FAIL'} #{label}"
  $fail = true unless cond
end

# Đọc zip độc lập với Center: duyệt thư mục trung tâm, giải nén từng mục, kiểm CRC
def unzip(path)
  bytes = File.binread(path)
  eocd = bytes.rindex("PK\x05\x06".b)
  _sig, _d, _cd, _n, total, _size, offset = bytes.byteslice(eocd, 22).unpack('VvvvvVV')
  out = {}
  pos = offset
  total.times do
    f = bytes.byteslice(pos, 46).unpack('VvvvvvvVVVvvvvvVV')
    method, crc, csize, usize, nlen, xlen, clen, local = f[4], f[7], f[8], f[9], f[10], f[11], f[12], f[16]
    name = bytes.byteslice(pos + 46, nlen).force_encoding('UTF-8')
    lh = bytes.byteslice(local, 30).unpack('VvvvvvVVVvv')
    start = local + 30 + lh[9] + lh[10]
    raw = bytes.byteslice(start, csize)
    data = method == 8 ? Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(raw) : raw
    raise "CRC sai: #{name}" unless Zlib.crc32(data) == crc && data.bytesize == usize
    out[name] = data
    pos += 46 + nlen + xlen + clen
  end
  out
end

out = File.join(Dir.tmpdir, "test_bundle_#{$$}.rbz")
FileUtils.rm_f(out)
check 'nhận ra hai bản SketchUp', MGR.installed_versions == %w[2022 2024]
check 'danh sách plugin không có mục hệ thống và VGD Center', MGR.list_plugins('2022').map { |p| p[:name] } == %w[cool_tool single]

r = MGR.build_bundle('2022', %w[cool_tool single VGD_Center su_sandbox], out)
check 'xuất gói thành công, đúng đường dẫn', r[:error].nil? && r[:path] == out && File.exist?(out)
check 'đếm đúng số file plugin (4), VGD Center và mục hệ thống không vào gói', r[:count] == 4
files = unzip(out)
check 'zip hợp lệ: đọc và giải nén được mọi mục, CRC đúng', files.size == 4
check 'chỉ có file của plugin, không thêm tệp nào khác vào Plugins máy đích', files.keys.sort == %w[cool_tool.rb cool_tool/data.bin cool_tool/lib/sub/x.rb single.rb]
check 'nội dung tiếng Việt giữ nguyên', files['cool_tool.rb'].force_encoding('UTF-8') == tool_rb
check 'file nhị phân giữ nguyên từng byte', files['cool_tool/data.bin'] == data_bin
check 'VGD Center tuyệt đối không có trong gói', files.keys.none? { |n| n.downcase.start_with?('vgd_center') }
check 'Center chấp nhận cấu trúc zip (đọc được bằng read_archive_entries, tên an toàn)', VGD::Center.read_archive_entries(out).map { |e| e[:path] }.sort == files.keys.sort

# Tên file đầu ra
out2 = File.join(Dir.tmpdir, "test_bundle_noext_#{$$}")
r2 = MGR.build_bundle('2022', %w[single], out2)
check 'tự thêm đuôi .rbz nếu thiếu', r2[:path] == "#{out2}.rbz" && File.exist?("#{out2}.rbz")
check 'không chọn plugin nào thì báo lỗi', MGR.build_bundle('2022', [], out)[:error].to_s.include?('Không có file')
check 'chọn tên không có thì báo lỗi, không tạo gói rỗng', MGR.build_bundle('2022', %w[khong_co], File.join(Dir.tmpdir, "x_#{$$}.rbz"))[:error].to_s.include?('Không có file')

# Cảnh báo tương thích Ruby cũ/mới
File.write(File.join(plug, 'old_style.rb'), "x = File.exists?('a')\ny = 1.taint\n")
warns = MGR.scan_compat('2022', %w[old_style single])
check 'cảnh báo cú pháp Ruby 2.7 dễ lỗi trên 3.2, chỉ cho mục đã chọn', warns.size == 2 && warns.all? { |w| w.start_with?('old_style:') }

# ---------- Chuyển plugin an toàn: không chép dở, kiểm tra sau khi chép, cảnh báo plugin theo phiên bản Ruby ----------
plug24 = File.join(fake, 'SketchUp/SketchUp 2024/SketchUp/Plugins')
def make_plugin(dir, name, files = {})
  File.write(File.join(dir, "#{name}.rb"), "puts '#{name}'\n")
  files.each { |rel, body| path = File.join(dir, name, rel); FileUtils.mkdir_p(File.dirname(path)); File.write(path, body) }
end
make_plugin(plug, 'two_part', 'core.rb' => 'core', 'lib/deep/a.rb' => 'a')
FileUtils.mkdir_p(File.join(plug24, 'two_part'))
File.write(File.join(plug24, 'two_part/old.rb'), 'old')
r = MGR.copy_plugins('2022', '2024', %w[two_part], false)
check 'không ghi đè: đích đã có thư mục thì bỏ qua cả plugin, không chép riêng loader', r[:done].empty? && r[:skipped].sort == %w[two_part two_part.rb] && !File.exist?(File.join(plug24, 'two_part.rb'))
check 'không ghi đè: thư mục đích giữ nguyên', File.read(File.join(plug24, 'two_part/old.rb')) == 'old' && !File.exist?(File.join(plug24, 'two_part/core.rb'))
FileUtils.rm_rf(File.join(plug24, 'two_part'))
File.write(File.join(plug24, 'two_part.rb'), "puts 'cu'\n")
r = MGR.copy_plugins('2022', '2024', %w[two_part], false)
check 'không ghi đè: đích đã có loader thì cũng bỏ qua cả plugin', r[:done].empty? && r[:skipped].sort == %w[two_part two_part.rb] && !File.exist?(File.join(plug24, 'two_part/core.rb'))
r = MGR.copy_plugins('2022', '2024', %w[two_part], true)
check 'ghi đè: chép đủ cả loader và thư mục', r[:done].sort == %w[two_part two_part.rb] && r[:failed].empty? && File.exist?(File.join(plug24, 'two_part/lib/deep/a.rb')) && File.read(File.join(plug24, 'two_part.rb')).include?('two_part')

# Chép dở (thiếu file hoặc sai dung lượng) phải bị phát hiện, không được báo là đã chép
original_cp_r = FileUtils.method(:cp_r)
FileUtils.define_singleton_method(:cp_r) do |from, to, **opts|
  original_cp_r.call(from, to, **opts)
  File.delete(File.join(to, 'lib/deep/a.rb')) if File.directory?(to) && File.basename(to) == 'two_part' && $drop_file
  File.write(File.join(to, 'core.rb'), 'x') if File.directory?(to) && File.basename(to) == 'two_part' && $shrink_file
end
$drop_file = true
r = MGR.copy_plugins('2022', '2024', %w[two_part], true)
check 'chép thiếu file: báo lỗi nói rõ số file thiếu và tên file, không tính là đã chép', r[:done] == %w[two_part.rb] && r[:failed].size == 1 && r[:failed][0].start_with?('two_part:') && r[:failed][0].include?('lib/deep/a.rb')
$drop_file = false
$shrink_file = true
r = MGR.copy_plugins('2022', '2024', %w[two_part], true)
check 'chép sai dung lượng: bị phát hiện', r[:done] == %w[two_part.rb] && r[:failed].size == 1 && r[:failed][0].include?('core.rb')
$shrink_file = false
FileUtils.define_singleton_method(:cp_r, original_cp_r)
r = MGR.copy_plugins('2022', '2024', %w[two_part], true)
check 'chép đủ thì không báo lỗi', r[:done].sort == %w[two_part two_part.rb] && r[:failed].empty?

# Plugin gắn với phiên bản Ruby: cảnh báo khi chuyển sang bản SketchUp khác
make_plugin(plug, 'enc_tool', 'main.rbe' => 'bin')
make_plugin(plug, 're_tool', 'rubyencoder_helper/load.rb' => 'x')
make_plugin(plug, 'bin_tool', 'ext/native.so' => 'b', 'ext/native.dll' => 'b')
make_plugin(plug, 'plain_tool', 'lib/a.rb' => 'a')
warns = MGR.scan_compat('2022', %w[enc_tool re_tool bin_tool plain_tool])
check 'cảnh báo file mã hóa .rbe', warns.any? { |w| w.start_with?('enc_tool:') && w.include?('.rbe') }
check 'cảnh báo RubyEncoder', warns.any? { |w| w.start_with?('re_tool:') && w.include?('RubyEncoder') }
check 'cảnh báo thư viện nhị phân, mỗi plugin một lần', warns.count { |w| w.start_with?('bin_tool:') } == 1 && warns.any? { |w| w.start_with?('bin_tool:') && w.include?('.so') }
check 'plugin thường không bị cảnh báo', warns.none? { |w| w.start_with?('plain_tool:') }
check 'nội dung cảnh báo tiếng Anh có đủ', MGR::Text::MESSAGES.values_at(:risky_encrypted, :risky_rubyencoder, :risky_binary).all? { |m| m && m[:vi] && m[:en] }

FileUtils.rm_f([out, "#{out2}.rbz"])
puts($fail ? 'CÓ LỖI' : 'TẤT CẢ ĐẠT')
exit($fail ? 1 : 0)
