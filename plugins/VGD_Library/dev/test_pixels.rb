# encoding: UTF-8
# Test giữ hành vi cho Pixels (thuật toán thuần, không cần SketchUp): ruby dev/test_pixels.rb (từ plugins/VGD_Library).
require 'digest'
require File.expand_path('../runtime/vgd_library/pixels', __dir__)
P = VGD::Library::Pixels
$pass = 0; $fail = []
def check(name, cond); cond ? ($pass += 1) : ($fail << name); puts "#{cond ? 'OK  ' : 'FAIL'} #{name}"; end
def digest(obj); Digest::SHA256.hexdigest(Marshal.dump(obj))[0, 16]; end

# Ảnh giả lập xác định: gradient + vân + khối màu có lỗ.
def sample(w, h)
  vals = []
  h.times { |y| w.times { |x| vals.concat([(x * 255 / (w - 1) + (y % 3) * 7) % 256, (y * 255 / (h - 1) + (x % 5) * 3) % 256, (x * y * 11) % 256, 255]) } }
  P::Image.new(w, h, vals)
end
def blocks
  w = h = 12
  vals = Array.new(w * h * 4, 0)
  w.times { |x| h.times { |y| vals[(y * w + x) * 4 + 3] = 255; vals[(y * w + x) * 4, 3] = [255, 255, 255] } }
  (2..9).each { |x| (2..9).each { |y| vals[(y * w + x) * 4, 3] = [200, 30, 30] } }
  (4..6).each { |x| (4..6).each { |y| vals[(y * w + x) * 4, 3] = [255, 255, 255] } }
  P::Image.new(w, h, vals)
end

img = sample(24, 16)
check 'gray', digest(P.gray(img)) == '1a9b9b943ec66f3e'
check 'blur', digest(P.blur(P.gray(img), 24, 16, 3)) == '106b91d4249462cb'
%w[wood stone fabric metal].each do |kind|
  maps = P.auxiliary(img, kind, 2.0)
  check "auxiliary #{kind}", digest(maps.map { |k, v| [k, v.rgba] }) == { 'wood' => 'db5c46436c1b7b53', 'stone' => 'd4cbce50646b68a3', 'fabric' => '623ffe9c09fe02ad', 'metal' => '7f29664ed8283599' }[kind]
end
check 'seam_error', P.seam_error(img).round(6) == 81.166667
check 'seamless', digest(P.seamless(img, 0.5, 0.04).rgba) == '266c74f58c999061'
check 'seamless không flatten/feather', digest(P.seamless(img, 0, 0).rgba) == '0a9b51c2ede739d3'
c = P.contours(blocks, 2, 0.75, true)
check 'contours có nền: ngoài + lỗ', digest(c) == '5005169b0565f795' && c.size >= 2
check 'contours giữ nền', digest(P.contours(blocks, 2, 0.75, false)) == '1e690555e4f5b7d3'
check 'contours nhiều mức', digest(P.contours(img, 4, 1.5, true)) == '1a9151da6c63ddfd'
line = (0..20).map { |i| [i, Math.sin(i / 3.0) * 4] }
check 'simplify_line', digest(P.simplify_line(line, 0.8)) == '450f828a8ead38a4'
ring = (0..15).map { |i| [Math.cos(i * Math::PI / 8) * 10, Math.sin(i * Math::PI / 8) * 10] }
ring << ring.first
check 'simplify_closed', digest(P.simplify_closed(ring, 0.5)) == '99754dae77e5f5b0'
puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "LỖI: #{$fail.join('; ')}"
exit($fail.empty? ? 0 : 1)
