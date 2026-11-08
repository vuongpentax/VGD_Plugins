# Test tính camera thu phóng tới một hộp bao (core/view_fit.rb, toán thuần). Chạy: ruby dev/test_view_fit.rb
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
require File.join(ROOT, 'core/view_fit')
V = VGD::BIM::ViewFit
def near(a, b, eps = 1e-6); a.zip(b).all? { |x, y| (x - y).abs <= eps }; end

# Hộp 100 x 40 x 60 inch tại (1000, 2000, 300): tâm (1050, 2020, 330), nửa đường chéo = sqrt(50² + 20² + 30²)
min = [1000.0, 2000.0, 300.0]
max = [1100.0, 2040.0, 360.0]
radius = Math.sqrt(50.0**2 + 20.0**2 + 30.0**2)
dir = [0.0, 1.0, 0.0]
r = V.camera(min, max, direction: dir, up: [0.0, 0.0, 1.0], perspective: true, fov: 35.0, fov_is_height: false, aspect: 2.0)
ok('nhìn vào tâm hộp bao (tọa độ thế giới, không phải gốc)', near(r[:target], [1050.0, 2020.0, 330.0]))
ok('mắt nằm lùi về sau tâm theo hướng nhìn hiện tại, giữ nguyên hướng nhìn và hướng lên', r[:eye][0] == 1050.0 && r[:eye][2] == 330.0 && r[:eye][1] < 2020.0 && r[:up] == [0.0, 0.0, 1.0] && r[:height].nil?)
half = Math.atan(Math.tan(35.0 * Math::PI / 360.0) / 2.0) # fov 35° là chiều ngang; cửa sổ rộng gấp đôi cao nên góc dọc nhỏ hơn
distance = 2020.0 - r[:eye][1]
ok('phối cảnh: khoảng cách đủ để cả hình cầu bao hộp lọt trong góc nhìn hẹp hơn (có chừa lề)', distance * Math.sin(half) >= radius && distance * Math.sin(half) <= radius * 1.2)
r2 = V.camera(min, max, direction: dir, up: [0.0, 0.0, 1.0], perspective: true, fov: 35.0, fov_is_height: true, aspect: 2.0)
ok('fov tính theo chiều cao: dùng góc dọc 35° làm góc hẹp hơn (xa hơn trường hợp 35° chiều ngang)', (2020.0 - r2[:eye][1]) < distance + 1e-9 && (2020.0 - r2[:eye][1]) > 0)
narrow = V.camera(min, max, direction: dir, up: [0.0, 0.0, 1.0], perspective: true, fov: 35.0, fov_is_height: true, aspect: 0.5)
ok('cửa sổ cao hẹp (aspect 0,5): góc ngang là góc hẹp nên mắt phải lùi xa hơn', (2020.0 - narrow[:eye][1]) > (2020.0 - r2[:eye][1]))
par = V.camera(min, max, direction: [1.0, 0.0, 0.0], up: [0.0, 0.0, 1.0], perspective: false, fov: 35.0, fov_is_height: false, aspect: 2.0)
ok('song song: đặt chiều cao khung nhìn đủ phủ đường kính (cửa sổ rộng nên lấy theo chiều cao)', par[:height] && par[:height] >= 2 * radius && par[:height] <= 2 * radius * 1.2)
par_tall = V.camera(min, max, direction: [1.0, 0.0, 0.0], up: [0.0, 0.0, 1.0], perspective: false, fov: 35.0, fov_is_height: false, aspect: 0.5)
ok('song song, cửa sổ cao hẹp: chiều cao tăng gấp đôi để chiều ngang cũng phủ đủ', near([par_tall[:height]], [par[:height] * 2.0], 1e-6))
ok('song song: mắt vẫn lùi sau tâm theo hướng nhìn để không cắt mất hình', par[:eye][0] < 1050.0 && par[:eye][1] == 2020.0)
point = V.camera([5.0, 5.0, 5.0], [5.0, 5.0, 5.0], direction: dir, up: [0.0, 0.0, 1.0], perspective: true, fov: 35.0, fov_is_height: false, aspect: 1.0)
ok('hộp bao suy biến (một điểm): vẫn có khoảng cách dương, không chia cho 0', point[:eye][1] < 5.0 && point[:eye].all? { |v| v.finite? })
slanted = V.camera(min, max, direction: [3.0, 4.0, 0.0], up: [0.0, 0.0, 1.0], perspective: true, fov: 35.0, fov_is_height: false, aspect: 1.0)
back = near(slanted[:target].zip(slanted[:eye]).map { |t, e| t - e }.then { |v| n = Math.sqrt(v.sum { |x| x * x }); v.map { |x| x / n } }, [0.6, 0.8, 0.0])
ok('hướng nhìn không chuẩn hóa vẫn được chuẩn hóa: từ mắt tới tâm đúng hướng (0,6; 0,8; 0)', back)
puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
