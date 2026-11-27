# Test icon thanh công cụ vẽ (bộ icon VGD, SVG): mỗi công cụ có draw_<khóa>.svg đúng quy tắc shared/VGD_ICON_SYSTEM_RULES.md
# (viewBox 24, nét 1.8, đầu nét và góc nối bo tròn, không nền, màu nét #292B2D và điểm nhấn #B48963) và loader trỏ tới đúng file.
# Chạy: ruby dev/test_draw_icons.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
ICONS = File.expand_path('../runtime/vgd_structure/assets/icons', __dir__)
TOOLS = %w[column beam wall door window slab ceiling stair footing]
LOADER = File.read(File.expand_path('../runtime/vgd_structure/loader.rb', __dir__), encoding: 'UTF-8')
TOOLS.each do |tool|
  file = File.join(ICONS, "draw_#{tool}.svg")
  ok("#{tool}: có file SVG", File.file?(file))
  next unless File.file?(file)
  svg = File.read(file, encoding: 'UTF-8')
  ok("#{tool}: viewBox 0 0 24 24 và kích thước 24", svg.include?('viewBox="0 0 24 24"') && svg.include?('width="24"') && svg.include?('height="24"'))
  ok("#{tool}: nét 1.8, đầu nét và góc nối bo tròn", svg.scan('stroke-width="1.8"').size >= 2 && svg.scan('stroke-linecap="round"').size >= 2 && svg.scan('stroke-linejoin="round"').size >= 2)
  fills = svg.scan(/fill="([^"]*)"/).flatten.uniq
  ok("#{tool}: không nền (không có hình chữ nhật phủ viewBox); fill chỉ là none hoặc màu nhấn tô nhạt", !svg.match?(/<rect[^>]*width="24"/) && fills.all? { |f| f == 'none' || f == '#B48963' })
  ok("#{tool}: chỉ dùng hai màu của bộ icon (nét chính #292B2D, điểm nhấn #B48963)", svg.scan(/stroke="(#[0-9A-Fa-f]{6})"/).flatten.uniq.sort.all? { |c| %w[#292B2D #B48963].include?(c) })
end
ok('loader dùng SVG cho cả hai cỡ (không còn PNG)', LOADER.include?("draw_\#{tool}.svg") && !LOADER.include?('.png'))
keys = LOADER.scan(/\['(\w+)', '[^']*'\]/).flatten & TOOLS
ok('loader đăng ký đủ 9 nút vẽ, cùng khóa với bộ icon', keys.sort == TOOLS.sort)
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
