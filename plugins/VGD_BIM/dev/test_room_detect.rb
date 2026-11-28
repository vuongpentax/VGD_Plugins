# Test dò phòng từ tường (core/room_detect.rb, thuật toán thuần): hình chữ nhật, vách ngăn, tường hai lớp (ruột tường bị bỏ), khe cửa, đầu hở,
# cột đứng một mình (lỗ), tường chéo, dữ liệu sai. Chạy: ruby dev/test_room_detect.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
require File.join(ROOT, 'core/levels')
require File.join(ROOT, 'core/rooms')
require File.join(ROOT, 'core/room_detect')
RD = VGD::BIM::RoomDetect

# Hình chữ nhật 4 đoạn.
def rect(x0, y0, x1, y1)
  [[x0, y0, x1, y0], [x1, y0, x1, y1], [x1, y1, x0, y1], [x0, y1, x0, y0]]
end

# Tường dày: hai đường song song cách nhau t, hai đầu có đoạn ngang (mặt đầu tường), như mặt cắt của một khối tường.
def thick_wall(x0, y0, x1, y1, t)
  horizontal = (y1 - y0).abs < 1e-9
  if horizontal
    [[x0, y0 - t / 2, x1, y0 - t / 2], [x0, y0 + t / 2, x1, y0 + t / 2], [x0, y0 - t / 2, x0, y0 + t / 2], [x1, y0 - t / 2, x1, y0 + t / 2]]
  else
    [[x0 - t / 2, y0, x0 - t / 2, y1], [x0 + t / 2, y0, x0 + t / 2, y1], [x0 - t / 2, y0, x0 + t / 2, y0], [x0 - t / 2, y1, x0 + t / 2, y1]]
  end
end

def area_m2(region); (region[:area] / 1.0e6).round(2); end

# 1. Hình chữ nhật 4 x 3 m
r = RD.detect(rect(0, 0, 4000, 3000))
ok 'hình chữ nhật: một vùng', r[:regions].size == 1 && r[:dropped].empty?
ok 'hình chữ nhật: diện tích 12 m2', area_m2(r[:regions][0]) == 12.0
ok 'hình chữ nhật: bề rộng 3000', (r[:regions][0][:width] - 3000).abs < 1
ok 'hình chữ nhật: tâm đúng', r[:regions][0][:center].zip([2000, 1500]).all? { |a, b| (a - b).abs < 1 }
ok 'hình chữ nhật: viền đúng 4 điểm, qua Rooms.boundary!', r[:regions][0][:boundary].size == 4 && VGD::BIM::Rooms.boundary!(r[:regions][0][:boundary], 'x').size == 4
ok 'hình chữ nhật: không đầu hở', r[:open_ends] == 0

# 2. Đoạn thẳng bị chia nhỏ và đoạn chồng nhau vẫn ra một vùng
split = [[0, 0, 2000, 0], [2000, 0, 4000, 0], [4000, 0, 4000, 3000], [4000, 3000, 0, 3000], [0, 3000, 0, 0], [500, 0, 3500, 0]]
r = RD.detect(split)
ok 'đoạn chia nhỏ + chồng nhau: một vùng 12 m2', r[:regions].size == 1 && area_m2(r[:regions][0]) == 12.0
ok 'đoạn chia nhỏ: viền gọn 4 điểm', r[:regions][0][:boundary].size == 4

# 3. Vách ngăn chia đôi (chạm chữ T): hai phòng
r = RD.detect(rect(0, 0, 6000, 3000) + [[2000, 0, 2000, 3000]])
ok 'vách ngăn: hai vùng', r[:regions].size == 2
ok 'vách ngăn: diện tích 6 + 12', r[:regions].map { |x| area_m2(x) }.sort == [6.0, 12.0]
ok 'vách ngăn: sắp từ trái sang phải', r[:regions][0][:center][0] < r[:regions][1][:center][0]

# 4. Tường dày hai lớp: phòng thật + ruột tường (bị bỏ vì hẹp)
walls = thick_wall(0, 0, 4200, 0, 200) + thick_wall(4000, 0, 4000, 3000, 200) + thick_wall(4200, 3000, 0, 3000, 200) + thick_wall(0, 3000, 0, 0, 200)
r = RD.detect(walls)
ok 'tường dày: có một phòng thật', r[:regions].size == 1
ok 'tường dày: phòng nằm giữa mặt trong của tường', r[:regions][0] && (area_m2(r[:regions][0]) - 3.8 * 2.8).abs < 0.05
ok 'tường dày: ruột tường bị bỏ vì hẹp', r[:dropped].any? { |d| d[:reason].include?('ruột tường') } && r[:dropped].all? { |d| d[:reason].include?('ruột tường') || d[:reason].include?('diện tích quá nhỏ') }

# 5. Hai lớp tường tách rời (hai hình chữ nhật lồng nhau, không dính): vành giữa bị bỏ nhờ độ dày
r = RD.detect(rect(0, 0, 4200, 3200) + rect(200, 200, 4000, 3000))
ok 'hai lớp lồng nhau: chỉ phòng bên trong', r[:regions].size == 1 && (area_m2(r[:regions][0]) - 3.8 * 2.8).abs < 0.01
ok 'hai lớp lồng nhau: vành bị bỏ', r[:dropped].size == 1 && r[:dropped][0][:reason].include?('ruột tường')
ok 'ngưỡng nhỏ hơn thì vành thành phòng', RD.detect(rect(0, 0, 4200, 3200) + rect(200, 200, 4000, 3000), min_width: 100)[:regions].size == 2

# 6. Đầu hở: phòng không kín không thành vùng
open_room = [[0, 0, 4000, 0], [4000, 0, 4000, 3000], [4000, 3000, 1500, 3000], [0, 3000, 0, 0]]
r = RD.detect(open_room)
ok 'phòng hở một khe: không có vùng', r[:regions].empty? && r[:dropped].empty?
ok 'phòng hở: báo 2 đầu hở', r[:open_ends] == 2
# tường thừa nhô ra ngoài phòng kín: bỏ đầu cụt, phòng vẫn ra
r = RD.detect(rect(0, 0, 4000, 3000) + [[4000, 1000, 5500, 1000]])
ok 'tường thừa nhô ra: phòng vẫn ra', r[:regions].size == 1 && area_m2(r[:regions][0]) == 12.0
ok 'tường thừa nhô ra: báo 1 đầu hở', r[:open_ends] == 1
# tường thừa nhô vào trong phòng
r = RD.detect(rect(0, 0, 4000, 3000) + [[0, 1500, 1200, 1500]])
ok 'tường nhô vào trong: phòng vẫn ra và viền không bị khoét', r[:regions].size == 1 && area_m2(r[:regions][0]) == 12.0

# 7. Khe cửa nhỏ nối hai phòng: gộp thành một vùng (cách xử lý D2: hạ độ cao cắt xuống trên cửa)
two = rect(0, 0, 8000, 3000) + [[4000, 0, 4000, 1000], [4000, 2000, 4000, 3000]]
r = RD.detect(two)
ok 'khe cửa ở vách: hai phòng gộp thành một vùng', r[:regions].size == 1 && area_m2(r[:regions][0]) == 24.0
ok 'khe cửa ở vách: 2 đầu cụt được báo', r[:open_ends] == 2
# vách liền: hai phòng
r = RD.detect(rect(0, 0, 8000, 3000) + [[4000, 0, 4000, 3000]])
ok 'vách liền: hai phòng', r[:regions].size == 2

# 8. Cột đứng một mình trong phòng: thành lỗ
r = RD.detect(rect(0, 0, 4000, 3000) + rect(1800, 1300, 2200, 1700))
ok 'cột trong phòng: một vùng (cột không thành phòng)', r[:regions].size == 1 && r[:dropped].size == 1
ok 'cột trong phòng: vùng có đúng một lỗ', r[:regions][0][:holes].size == 1
ok 'cột trong phòng: diện tích đã trừ lỗ', area_m2(r[:regions][0]) == 11.84
ok 'cột trong phòng: Rooms.holes! nhận lỗ', VGD::BIM::Rooms.holes!(r[:regions][0][:holes], r[:regions][0][:boundary], 'x').size == 1
ok 'cột 400 x 400 nhỏ: bị bỏ khỏi vùng, nêu lý do', r[:dropped][0][:reason].include?('diện tích quá nhỏ') || r[:dropped][0][:reason].include?('ruột tường')

# 9. Tường chéo (hình thang / tam giác)
r = RD.detect([[0, 0, 4000, 0], [4000, 0, 0, 3000], [0, 3000, 0, 0]])
ok 'tam giác: một vùng 6 m2', r[:regions].size == 1 && area_m2(r[:regions][0]) == 6.0
ok 'tam giác: bề rộng là đường cao nhỏ nhất (2400)', (r[:regions][0][:width] - 2400).abs < 1

# 10. Hành lang hẹp vẫn ra khi bề rộng đủ, bị bỏ khi dưới ngưỡng
corridor = rect(0, 0, 10_000, 1000)
ok 'hành lang 1000: được giữ', RD.detect(corridor)[:regions].size == 1
ok 'hành lang 300: bị bỏ do hẹp', RD.detect(rect(0, 0, 10_000, 300))[:regions].empty? && RD.detect(rect(0, 0, 10_000, 300))[:dropped].size == 1
ok 'hành lang 300 nhưng ngưỡng 250: được giữ', RD.detect(rect(0, 0, 10_000, 300), min_width: 250)[:regions].size == 1

# 11. Sai số nhỏ giữa các đầu tường (0,4 mm) vẫn khép kín
r = RD.detect([[0, 0, 4000, 0], [4000.4, 0.3, 4000, 3000], [4000.2, 3000, 0, 3000], [0.0, 3000.4, 0, 0.2]])
ok 'sai số dưới 1 mm: vẫn khép kín', r[:regions].size == 1
# hở 5 mm: không khép
r = RD.detect([[0, 0, 4000, 0], [4000, 5, 4000, 3000], [4000, 3000, 0, 3000], [0, 3000, 0, 0]])
ok 'hở 5 mm: không khép kín, báo đầu hở', r[:regions].empty? && r[:open_ends] == 2

# 12. Hai phòng chung đỉnh (chạm góc): hai vùng riêng, không lỗi
r = RD.detect(rect(0, 0, 3000, 3000) + rect(3000, 3000, 6000, 6000))
ok 'hai phòng chạm góc: hai vùng', r[:regions].size == 2

# 13. Dữ liệu sai
ok 'không phải mảng bị từ chối', error_of { RD.detect('x') }.to_s.include?('không hợp lệ')
ok 'đoạn thiếu số bị từ chối', error_of { RD.detect([[0, 0, 1]]) }.to_s.include?('không hợp lệ')
ok 'NaN bị từ chối', error_of { RD.detect([[0, 0, Float::NAN, 1]]) }.to_s.include?('không hợp lệ')
ok 'ngưỡng 0 bị từ chối', error_of { RD.detect(rect(0, 0, 1000, 1000), min_width: 0) }.to_s.include?('lớn hơn 0')
ok 'trống: không vùng, không lỗi', RD.detect([]) == {regions: [], dropped: [], open_ends: 0, segments: 0}
ok 'đoạn quá ngắn bị bỏ', RD.detect([[0, 0, 0.2, 0]])[:segments] == 0
ok 'quá nhiều đoạn bị từ chối', error_of { RD.detect(Array.new(RD::MAX_SEGMENTS + 1) { |i| [i * 10, 0, i * 10 + 5, 0] }) }.to_s.include?('quá nhiều')

# 14. Căn phòng nhiều tầng tường: lưới 3 x 2 phòng
grid = rect(0, 0, 9000, 6000) + [[3000, 0, 3000, 6000], [6000, 0, 6000, 6000], [0, 3000, 9000, 3000]]
r = RD.detect(grid)
ok 'lưới 3 x 2: sáu phòng', r[:regions].size == 6 && r[:regions].all? { |x| area_m2(x) == 9.0 }

# 15. Dấu nhận dạng và loại vùng bị bỏ
a = RD.detect(rect(0, 0, 4000, 3000) + [[2000, 0, 2000, 3000]])
b = RD.detect(rect(0, 0, 4000, 3000) + [[2000.3, 0, 2000.3, 3000]])
ok 'dấu nhận dạng ổn định khi dò lại', RD.detect(rect(0, 0, 4000, 3000) + [[2000, 0, 2000, 3000]])[:regions].map { |x| x[:sig] } == a[:regions].map { |x| x[:sig] }
ok 'dấu nhận dạng chịu được sai số 0,3 mm', a[:regions].map { |x| x[:sig] } == b[:regions].map { |x| x[:sig] }
ok 'hai vùng có dấu khác nhau', a[:regions].map { |x| x[:sig] }.uniq.size == 2
r = RD.detect(rect(0, 0, 10_000, 300))
ok 'vùng bị bỏ có loại :thin', r[:dropped][0][:kind] == :thin
ok 'vùng quá nhỏ có loại :small', RD.detect(rect(0, 0, 400, 400))[:dropped][0][:kind] == :small
# lỗ quá sát viền: Rooms.holes! từ chối nên vùng bị loại với lý do rõ, không làm hỏng cả đợt
r = RD.detect(rect(0, 0, 4000, 3000) + rect(0, 1000, 400, 1400))
ok 'cột dính tường: không ra vùng lỗi', r[:regions].all? { |x| (VGD::BIM::Rooms.holes!(x[:holes], x[:boundary], 'x'); true) }

puts($fails.zero? ? 'ALL PASS' : "#{$fails} FAIL")
exit($fails.zero? ? 0 : 1)
