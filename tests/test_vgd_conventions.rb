# encoding: UTF-8
# Kiểm tra quy ước chung của các plugin VGD (đọc mã, không cần SketchUp). Chạy từ gốc repo:
#   ruby tests/test_vgd_conventions.rb
ROOT = File.expand_path('..', __dir__)
SKIP_DIRS = %w[/dev/ /test/ /cabinet_dev/ /outputs/ /node_modules/ /claude_v6_reference/].freeze
rubies = Dir.glob(File.join(ROOT, 'plugins', '**', '*.rb')).reject { |f| SKIP_DIRS.any? { |d| f.include?(d) } }
$fails = []
def check(name, ok, detail = nil)
  puts "#{ok ? 'OK  ' : 'FAIL'} #{name}"
  $fails << "#{name} #{detail}" unless ok
end

# 1. Chỉ ::VGD.menu được tạo menu VGD; không plugin nào tự gọi add_submenu('VGD').
direct = rubies.select { |f| File.read(f, encoding: 'UTF-8').lines.any? { |l| l =~ /add_submenu\('VGD'\)/ && l !~ /@extensions_menu \|\|=/ } }
check "không plugin nào tự tạo menu 'VGD' (dùng ::VGD.menu)", direct.empty?, direct.map { |f| f.sub(ROOT + '/', '') }.inspect

# 2. Loader: tên extension 'VGD Tên' (có dấu cách), file loader và thư mục viết thường.
loaders = rubies.select { |f| File.read(f, encoding: 'UTF-8') =~ /register_extension/ }
check 'tìm thấy loader của các plugin', loaders.size >= 11, loaders.size
loaders.each do |f|
  src = File.read(f, encoding: 'UTF-8')
  rel = f.sub(ROOT + '/', '')
  name = src[/SketchupExtension\.new\(\s*'([^']+)'/, 1]
  check "#{rel}: tên extension 'VGD Tên'", name.to_s.match?(/\AVGD [A-Z][A-Za-z ]*\z/), name.inspect
  check "#{rel}: tên file loader viết thường", File.basename(f) == File.basename(f).downcase
  target = src[/'(vgd_[a-z_]+)(?:\/|')/, 1]
  check "#{rel}: thư mục nạp viết thường vgd_*", !target.nil?, 'không thấy đường dẫn vgd_xxx/'
end

# 3. Toolbar: tên rút gọn 'VGD XXX' (3 chữ in hoa).
toolbars = rubies.flat_map { |f| File.read(f, encoding: 'UTF-8').scan(/Toolbar\.new\('([^']+)'\)/).flatten.map { |n| [f, n] } }
toolbars.each { |f, n| check "toolbar '#{n}' (#{File.basename(f)}): dạng VGD + 3 chữ in hoa", n.match?(/\AVGD [A-Z]{3}\z/) }

puts $fails.empty? ? 'TẤT CẢ ĐẠT' : "CÓ #{$fails.size} LỖI"
exit($fails.empty? ? 0 : 1)
