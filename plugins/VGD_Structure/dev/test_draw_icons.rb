# Test icon thanh công cụ vẽ: mỗi công cụ có đủ draw_<khóa>.svg, _16.png (16 px) và _24.png (24 px), đúng kích thước đọc từ header PNG.
# Chạy: ruby dev/test_draw_icons.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
ICONS = File.expand_path('../runtime/vgd_structure/assets/icons', __dir__)
TOOLS = %w[column beam wall door window slab ceiling]
TOOLS.each do |tool|
  svg = File.join(ICONS, "draw_#{tool}.svg")
  ok("#{tool}: có file SVG nguồn và có tiêu đề VGD Structure", File.file?(svg) && File.read(svg, encoding: 'UTF-8').include?('VGD Structure'))
  [16, 24].each do |px|
    file = File.join(ICONS, "draw_#{tool}_#{px}.png")
    ok("#{tool}: PNG #{px} px tồn tại", File.file?(file))
    next unless File.file?(file)
    bytes = File.binread(file, 24)
    w, h = bytes[16, 8].unpack('NN')
    ok("#{tool}: PNG #{px} px đúng kích thước (đọc IHDR: #{w}x#{h})", bytes[1, 3] == 'PNG' && w == px && h == px)
  end
end
LOADER = File.read(File.expand_path('../runtime/vgd_structure/loader.rb', __dir__), encoding: 'UTF-8')
keys = LOADER.scan(/\['(\w+)', '[^']*'\]/).flatten & TOOLS
ok('loader đăng ký đủ 7 nút vẽ, cùng khóa với DRAW_TOOLS của Panel', keys.sort == TOOLS.sort && LOADER.include?('draw_#{tool}_16.png') && LOADER.include?('draw_#{tool}_24.png'))
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
