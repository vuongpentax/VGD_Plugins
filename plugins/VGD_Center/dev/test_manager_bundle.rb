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

require_relative '../VGD_Center/main'
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
check 'zip hợp lệ: đọc và giải nén được mọi mục, CRC đúng', files.size == 5
check 'có đủ file plugin và tệp mô tả gói', files.keys.sort == %w[cool_tool.rb cool_tool/data.bin cool_tool/lib/sub/x.rb single.rb vgd_bundle_manifest.json]
check 'nội dung tiếng Việt giữ nguyên', files['cool_tool.rb'].force_encoding('UTF-8') == tool_rb
check 'file nhị phân giữ nguyên từng byte', files['cool_tool/data.bin'] == data_bin
manifest = JSON.parse(files['vgd_bundle_manifest.json'])
check 'tệp mô tả ghi đúng công cụ, phiên bản và danh sách plugin', manifest['tool'] == 'VGD Center' && manifest['tool_version'] == VGD::Center::VERSION && manifest['source_version'] == '2022'
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

FileUtils.rm_f([out, "#{out2}.rbz"])
puts($fail ? 'CÓ LỖI' : 'TẤT CẢ ĐẠT')
exit($fail ? 1 : 0)
