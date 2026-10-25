# Test PanelModel (lõi thuần Ruby): kích thước, thể tích, chồng lấn, kiểm tra đầu vào.
# Chạy: ruby test_panel_model.rb <đường dẫn runtime/VGD_Cabinet_Draw>
dir = ARGV[0] or abort('Cần đường dẫn thư mục runtime/VGD_Cabinet_Draw')
load File.join(dir, 'panel_model.rb')
PM = VGD_Cabinet_Draw::PanelModel

$pass = 0
$fail = []
def check(name)
  ok = begin
    yield ? true : false
  rescue StandardError => e
    puts "  [ngoại lệ] #{name}: #{e.class}: #{e.message}"
    false
  end
  if ok
    $pass += 1
  else
    $fail << name
    puts "  [KHÔNG ĐẠT] #{name}"
  end
end

def raises_msg(re)
  yield
  false
rescue ArgumentError => e
  e.message =~ re ? true : (puts("    thông báo thực tế: #{e.message}") || false)
end

def close?(a, b, tol = 1e-6)
  (a - b).abs <= tol
end

# Điểm (px,py) nằm trong đa giác 2D (ray casting)
def in_poly?(px, py, poly)
  inside = false
  j = poly.length - 1
  poly.each_index do |i|
    xi, yi = poly[i]
    xj, yj = poly[j]
    if ((yi > py) != (yj > py)) && (px < (xj - xi) * (py - yi) / (yj - yi) + xi)
      inside = !inside
    end
    j = i
  end
  inside
end

def in_part?(part, x, y, z)
  b = part.bounds
  return false unless x >= b[0] && x < b[3] && y >= b[1] && y < b[4] && z >= b[2] && z < b[5]
  idx = { x: 0, y: 1, z: 2 }[part.axis]
  coords = [x, y, z]
  base = part.points.first[idx]
  return false unless coords[idx] >= base && coords[idx] < base + part.distance
  other = [0, 1, 2] - [idx]
  poly = part.points.map { |pt| [pt[other[0]], pt[other[1]]] }
  in_poly?(coords[other[0]], coords[other[1]], poly)
end

# Lấy mẫu lưới: đếm điểm thuộc >1 tấm (chồng lấn) và tổng thể tích ước lượng
def sample(result, step)
  nx = (result.width / step).floor
  ny = (result.depth / step).floor
  nz = (result.height / step).floor
  overlap = 0
  groove_overlap = 0
  inside = 0
  nx.times do |i|
    x = (i + 0.5) * step
    ny.times do |j|
      y = (j + 0.5) * step
      nz.times do |k|
        z = (k + 0.5) * step
        hit = result.parts.select { |pt| in_part?(pt, x, y, z) }
        n = hit.length
        # Hậu kích thước thật ngậm vào rãnh của tấm có grooved: được phép chồng (chỉ giữa hậu và tấm đó).
        ok_pair = n == 2 && hit.any? { |pt| pt.role == 'back' } && hit.any? { |pt| pt.grooved }
        overlap += 1 if n > 1 && !ok_pair
        groove_overlap += 1 if ok_pair
        inside += 1 if n >= 1
      end
    end
  end
  [overlap, inside * step**3, groove_overlap * step**3]
end

def part(result, role)
  result.parts.find { |p| p.role == role }
end

t = 17.5
puts "== 1. Mặc định 600x560x720 (hậu ngậm rãnh kín) =="
r = PM.compute(600, 560, 720, {})
check('đủ 5 tấm') { r.parts.map(&:role) == %w[side_left side_right bottom top back] }
check('hông trái cao suốt, sâu suốt') { b = part(r, 'side_left').bounds; b == [0.0, 0.0, 0.0, t, 560.0, 720.0] }
check('hông phải ở sát mép phải') { b = part(r, 'side_right').bounds; b == [600 - t, 0.0, 0.0, 600.0, 560.0, 720.0] }
check('đáy nằm giữa hai hông') { b = part(r, 'bottom').bounds; b == [t, 0.0, 0.0, 600 - t, 560.0, t] }
check('nóc nằm giữa hai hông') { b = part(r, 'top').bounds; b == [t, 0.0, 720 - t, 600 - t, 560.0, 720.0] }
back = part(r, 'back')
check('hậu rộng hơn khoảng lọt lòng đúng 2 lần độ ngậm rãnh') do
  b = back.bounds
  close?(b[3] - b[0], 565 + 2 * 8.75) && close?(b[5] - b[2], 685 + 2 * 8.75)
end
check('hậu cách mép sau 10 mm, dày 6') do
  b = back.bounds
  close?(b[1], 560 - 10 - 6) && close?(b[4], 560 - 10)
end
exp_side = t * 560 * 720 - 8.75 * 6 * 720
check('hông là khối đặc sạch (không khoét rãnh)') { close?(part(r, 'side_left').volume, t * 560 * 720, 1e-3) }
check('đáy là khối đặc sạch (không khoét rãnh)') { close?(part(r, 'bottom').volume, t * 560 * 565, 1e-3) }
check('hông/đáy/nóc đều có 4 đỉnh trên mặt cắt (hình chữ nhật)') { %w[side_left side_right bottom top].all? { |role| part(r, role).points.length == 4 } }
check('vẫn đánh dấu tấm có rãnh theo thiết kế (grooved)') { part(r, 'side_left').grooved && part(r, 'bottom').grooved }
check('hậu 6 mm') { close?(back.volume, 6 * 582.5 * 702.5, 1e-3) }

puts "== 2. Không chồng lấn và đủ thể tích (lấy mẫu lưới) =="
VARIANTS = {
  'mặc định' => [{}, 120, 100, 120],
  'hậu phủ' => [{ 'back_mode' => 'overlay' }, 120, 100, 120],
  'không hậu' => [{ 'back_mode' => 'none' }, 120, 100, 120],
  'rãnh hở (lớp che 0)' => [{ 'back_lip' => 0 }, 120, 100, 120],
  'nóc trùm trái' => [{ 'panels' => { 'top' => { 'cover_left' => true } } }, 120, 100, 120],
  'nóc trùm cả hai hông' => [{ 'panels' => { 'top' => { 'cover_left' => true, 'cover_right' => true } } }, 120, 100, 120],
  'đáy trùm phải' => [{ 'panels' => { 'bottom' => { 'cover_right' => true } } }, 120, 100, 120],
  'nóc và đáy cùng trùm' => [{ 'panels' => { 'top' => { 'cover_left' => true, 'cover_right' => true }, 'bottom' => { 'cover_left' => true, 'cover_right' => true } } }, 120, 100, 120],
  'tắt đáy' => [{ 'panels' => { 'bottom' => { 'enabled' => false } } }, 120, 100, 120],
  'tắt hông phải' => [{ 'panels' => { 'side_right' => { 'enabled' => false } } }, 120, 100, 120],
  'hông dày 25, nóc dày 30' => [{ 'panels' => { 'side_left' => { 'thickness' => 25 }, 'top' => { 'thickness' => 30 } } }, 140, 100, 140],
  'lùi mặt trước 20 (nóc)' => [{ 'panels' => { 'top' => { 'front_offset' => 20 } } }, 120, 100, 120],
  'hậu dày 9, ngậm 5' => [{ 'back_thickness' => 9, 'back_groove_depth' => 5 }, 120, 100, 120]
}.freeze
VARIANTS.each do |name, (settings, w, d, h)|
  res = PM.compute(w, d, h, settings)
  overlap, volume, groove_volume = sample(res, 1.25)
  sum = res.parts.sum(&:volume) - groove_volume
  check("#{name}: không có tấm nào chồng lên nhau (điểm chồng: #{overlap})") { overlap.zero? }
  check("#{name}: thể tích lưới ≈ tổng thể tích tấm (#{volume.round} vs #{sum.round})") { (volume - sum).abs / sum < 0.02 }
  check("#{name}: mọi tấm nằm trong hộp #{w}x#{d}x#{h}") do
    res.parts.all? { |p| b = p.bounds; b[0] >= -1e-9 && b[1] >= -1e-9 && b[2] >= -1e-9 && b[3] <= w + 1e-9 && b[4] <= d + 1e-9 && b[5] <= h + 1e-9 }
  end
end

puts "== 3. Quan hệ tấm cụ thể =="
r = PM.compute(600, 560, 720, 'panels' => { 'top' => { 'cover_left' => true } })
check('nóc trùm trái: nóc bắt đầu từ x=0') { part(r, 'top').bounds[0] == 0.0 }
check('nóc trùm trái: hông trái ngắn đi bằng dày nóc') { close?(part(r, 'side_left').bounds[5], 720 - t) }
check('nóc trùm trái: hông phải vẫn cao suốt') { part(r, 'side_right').bounds[5] == 720.0 }
check('nóc trùm trái: nóc không khoét rãnh') { part(r, 'top').grooved == false }
r = PM.compute(600, 560, 720, 'panels' => { 'bottom' => { 'enabled' => false } })
check('tắt đáy: không có tấm đáy') { part(r, 'bottom').nil? }
check('tắt đáy: hông vẫn chạy tới z=0') { part(r, 'side_left').bounds[2] == 0.0 }
check('tắt đáy: hậu bắt đầu từ z=0') { part(r, 'back').bounds[2] == 0.0 }
r = PM.compute(600, 560, 720, 'back_mode' => 'overlay')
check('hậu phủ: hậu phủ kín cả mặt sau 600x720') do
  b = part(r, 'back').bounds
  b[0] == 0.0 && b[3] == 600.0 && b[2] == 0.0 && b[5] == 720.0 && close?(b[1], 554) && b[4] == 560.0
end
check('hậu phủ: hông kết thúc trước hậu') { close?(part(r, 'side_left').bounds[4], 554) }
check('hậu phủ: không có rãnh nào') { r.parts.none?(&:grooved) }
r = PM.compute(600, 560, 720, 'back_mode' => 'none')
check('không hậu: 4 tấm') { r.parts.length == 4 }
check('không hậu: hông sâu đủ 560') { part(r, 'side_left').bounds[4] == 560.0 }
r = PM.compute(600, 560, 720, 'back_lip' => 0)
check('rãnh hở: hậu sát mép sau, vẫn khoét hông') { b = part(r, 'back').bounds; close?(b[4], 560) && part(r, 'side_left').grooved }
r = PM.compute(600, 560, 720, 'panels' => { 'side_left' => { 'front_offset' => 20 } })
check('lùi mặt trước 20 cho hông trái') { part(r, 'side_left').bounds[1] == 20.0 && part(r, 'side_right').bounds[1] == 0.0 }
r = PM.compute(600, 560, 720, 'panels' => { 'back' => { 'thickness' => 9 } })
check('dày hậu riêng 9 mm') { close?(part(r, 'back').thickness, 9) }
r = PM.compute('600', '560', '720', 'board_thickness' => '18')
check('nhận chuỗi số và dày ván 18') { close?(part(r, 'side_left').thickness, 18) }
r = PM.compute(600, 560, 720, 'panels' => { 'top' => { 'thickness' => '' } })
check('dày để trống dùng mặc định') { close?(part(r, 'top').thickness, 17.5) }
r = PM.compute(600, 560, 720, {})
check('export có đủ 5 tấm và cờ cover') { e = r.resolved; e['panels'].keys.sort == PM::ROLES.sort && e['panels']['top']['cover_left'] == false }
check('box_faces trả 6 mặt 4 điểm') { PM.box_faces(r.parts.first.bounds).length == 6 && PM.box_faces(r.parts.first.bounds).all? { |f| f.length == 4 } }

puts "== 4. Kiểm tra đầu vào =="
check('rộng quá nhỏ so với dày hông') { raises_msg(/quá hẹp/) { PM.compute(30, 560, 720, {}) } }
check('cao quá nhỏ') { raises_msg(/quá thấp/) { PM.compute(600, 560, 30, {}) } }
check('sâu quá nhỏ (không hậu)') { raises_msg(/Chiều sâu/) { PM.compute(600, 8, 720, 'back_mode' => 'none') } }
check('sâu quá nhỏ (hậu rãnh) bị từ chối') { raises_msg(/Chiều sâu|Rãnh hậu/) { PM.compute(600, 12, 720, {}) } }
check('rãnh sâu hơn dày ván') { raises_msg(/Độ ngậm rãnh/) { PM.compute(600, 560, 720, 'back_groove_depth' => 16) } }
check('kiểu hậu lạ') { raises_msg(/Kiểu hậu/) { PM.compute(600, 560, 720, 'back_mode' => 'xyz') } }
check('dày ván chữ') { raises_msg(/phải là một số/) { PM.compute(600, 560, 720, 'board_thickness' => 'abc') } }
check('dày ván quá lớn') { raises_msg(/khoảng/) { PM.compute(600, 560, 720, 'board_thickness' => 500) } }
check('vượt 10 m') { raises_msg(/không vượt quá 10000/) { PM.compute(10_001, 560, 720, {}) } }
check('rộng bằng chữ') { raises_msg(/Rộng phải là một số/) { PM.compute('abc', 560, 720, {}) } }
check('lớp che sau rãnh quá lớn so với chiều sâu') { raises_msg(/Rãnh hậu nằm quá sát/) { PM.compute(600, 40, 720, 'back_lip' => 38) } }
check('lùi mặt trước quá sâu') { raises_msg(/Chiều sâu/) { PM.compute(600, 100, 720, 'back_mode' => 'none', 'panels' => { 'top' => { 'front_offset' => 95 } }) } }
check('ngậm rãnh 0 thì không khoét rãnh') do
  r = PM.compute(600, 560, 720, 'back_groove_depth' => 0)
  r.parts.none?(&:grooved) && close?(part(r, 'back').bounds[3] - part(r, 'back').bounds[0], 565)
end

# --- Chân cao, ván chân, phào trần ---
check('mặc định thuần mô hình: không chân, không phào') do
  r = PM.compute(600, 560, 2000, {})
  r.trim.empty? && close?(r.opening[:z0], 17.5) && close?(r.opening[:z1], 1982.5)
end
check('chân 40 + phào 20: thân tủ nâng lên và thấp đi') do
  r = PM.compute(600, 560, 2000, 'leg_height' => 40, 'ceiling_strip_height' => 20)
  bottom = part(r, 'bottom'); top = part(r, 'top')
  close?(bottom.bounds[2], 40) && close?(top.bounds[5], 1980) && close?(r.height, 2000)
end
check('chân + phào: khoang trong dời đúng') do
  r = PM.compute(600, 560, 2000, 'leg_height' => 40, 'ceiling_strip_height' => 20)
  close?(r.opening[:z0], 57.5) && close?(r.opening[:z1], 1962.5)
end
check('ván chân đúng vị trí, kích thước') do
  r = PM.compute(600, 560, 2000, 'leg_height' => 40, 'toe_kick_setback' => 50)
  k = r.trim.find { |t| t.role == 'toe_kick' }
  k && close?(k.bounds[2], 0) && close?(k.bounds[5], 40) && close?(k.bounds[1], 50) && close?(k.bounds[4], 67.5) && close?(k.bounds[0], 0) && close?(k.bounds[3], 600)
end
check('phào trần đúng vị trí, kích thước') do
  r = PM.compute(600, 560, 2000, 'ceiling_strip_height' => 20)
  k = r.trim.find { |t| t.role == 'cornice' }
  k && close?(k.bounds[2], 1980) && close?(k.bounds[5], 2000) && close?(k.bounds[1], 0) && close?(k.bounds[4], 17.5)
end
check('tắt ván chân vẫn chừa hở chân') do
  r = PM.compute(600, 560, 2000, 'leg_height' => 40, 'toe_kick_enabled' => false)
  r.trim.none? { |t| t.role == 'toe_kick' } && close?(part(r, 'bottom').bounds[2], 40)
end
check('tắt phào vẫn chừa hở trần') do
  r = PM.compute(600, 560, 2000, 'ceiling_strip_height' => 20, 'cornice_enabled' => false)
  r.trim.empty? && close?(part(r, 'top').bounds[5], 1980)
end
check('chân + phào dày riêng') do
  r = PM.compute(600, 560, 2000, 'leg_height' => 40, 'ceiling_strip_height' => 30, 'toe_kick_thickness' => 12, 'cornice_thickness' => 25)
  k = r.trim.find { |t| t.role == 'toe_kick' }; c = r.trim.find { |t| t.role == 'cornice' }
  close?(k.bounds[4] - k.bounds[1], 12) && close?(c.bounds[4] - c.bounds[1], 25)
end
check('không tấm nào chồng lên ván chân/phào theo trục Z') do
  r = PM.compute(600, 560, 2000, 'leg_height' => 40, 'ceiling_strip_height' => 20)
  r.parts.all? { |pt| pt.bounds[2] >= 40 - 1e-9 && pt.bounds[5] <= 1980 + 1e-9 }
end
check('thân tủ cao đúng = tổng - chân - phào') do
  r = PM.compute(600, 560, 2000, 'leg_height' => 100, 'ceiling_strip_height' => 50)
  part(r, 'side_left').distance == 1850.0
end
check('chân quá cao so với box') { raises_msg(/quá thấp/) { PM.compute(600, 560, 100, 'leg_height' => 80, 'ceiling_strip_height' => 20) } }
check('chân âm') { raises_msg(/Chân cao/) { PM.compute(600, 560, 2000, 'leg_height' => -5) } }
check('chân chữ') { raises_msg(/phải là một số/) { PM.compute(600, 560, 2000, 'leg_height' => 'abc') } }
check('ván chân lùi quá sâu') { raises_msg(/Ván chân/) { PM.compute(600, 100, 2000, 'leg_height' => 40, 'toe_kick_setback' => 95) } }
check('phào lùi quá sâu') { raises_msg(/Phào trần/) { PM.compute(600, 100, 2000, 'ceiling_strip_height' => 20, 'cornice_setback' => 95) } }
check('export có thông số chân/phào') do
  e = PM.compute(600, 560, 2000, 'leg_height' => 40, 'ceiling_strip_height' => 20).resolved
  e['leg_height'] == 40.0 && e['ceiling_strip_height'] == 20.0 && e['toe_kick_enabled'] == true
end

# --- Hông chạm đất / đụng trần ---
FL = { 'leg_height' => 40, 'ceiling_strip_height' => 20 }
check('hông chạm đất: hông trái từ z=0') { r = PM.compute(600, 560, 2000, FL.merge('sides_to_floor' => true)); close?(part(r, 'side_left').bounds[2], 0) && close?(part(r, 'bottom').bounds[2], 40) }
check('hông đụng trần: hông phải tới z=2000') { r = PM.compute(600, 560, 2000, FL.merge('sides_to_ceiling' => true)); close?(part(r, 'side_right').bounds[5], 2000) && close?(part(r, 'top').bounds[5], 1980) }
check('hông dài đúng: sàn tới trần = 2000') { r = PM.compute(600, 560, 2000, FL.merge('sides_to_floor' => true, 'sides_to_ceiling' => true)); close?(part(r, 'side_left').distance, 2000) }
check('không bật cờ: hông giữ trong thân') { r = PM.compute(600, 560, 2000, FL); close?(part(r, 'side_left').bounds[2], 40) && close?(part(r, 'side_left').bounds[5], 1980) }
check('ván chân giữa hai hông khi chạm đất') { r = PM.compute(600, 560, 2000, FL.merge('sides_to_floor' => true)); k = r.trim.find { |t| t.role == 'toe_kick' }; close?(k.bounds[0], 17.5) && close?(k.bounds[3], 582.5) }
check('ván chân suốt bề rộng khi không chạm đất') { r = PM.compute(600, 560, 2000, FL); k = r.trim.find { |t| t.role == 'toe_kick' }; close?(k.bounds[0], 0) && close?(k.bounds[3], 600) }
check('phào giữa hai hông khi đụng trần') { r = PM.compute(600, 560, 2000, FL.merge('sides_to_ceiling' => true)); k = r.trim.find { |t| t.role == 'cornice' }; close?(k.bounds[0], 17.5) && close?(k.bounds[3], 582.5) }
check('phào suốt bề rộng khi không đụng trần') { r = PM.compute(600, 560, 2000, FL); k = r.trim.find { |t| t.role == 'cornice' }; close?(k.bounds[0], 0) && close?(k.bounds[3], 600) }
check('hông trái tắt: ván chân vẫn tới mép trái') { r = PM.compute(600, 560, 2000, FL.merge('sides_to_floor' => true, 'panels' => { 'side_left' => { 'enabled' => false } })); k = r.trim.find { |t| t.role == 'toe_kick' }; close?(k.bounds[0], 0) && close?(k.bounds[3], 582.5) }
check('đáy trùm hông: hông không kéo xuống sàn phía đó') { r = PM.compute(600, 560, 2000, FL.merge('sides_to_floor' => true, 'panels' => { 'bottom' => { 'cover_left' => true } })); close?(part(r, 'side_left').bounds[2], 57.5) && close?(part(r, 'side_right').bounds[2], 0) }
check('nóc trùm hông: hông không kéo lên trần phía đó') { r = PM.compute(600, 560, 2000, FL.merge('sides_to_ceiling' => true, 'panels' => { 'top' => { 'cover_right' => true } })); close?(part(r, 'side_right').bounds[5], 1962.5) && close?(part(r, 'side_left').bounds[5], 2000) }
check('chạm đất nhưng chân = 0: không đổi gì') { r = PM.compute(600, 560, 2000, 'sides_to_floor' => true); close?(part(r, 'side_left').bounds[2], 0) && r.trim.empty? }
check('hông kéo dài không chồng lên khoang trong') { r = PM.compute(600, 560, 2000, FL.merge('sides_to_floor' => true, 'sides_to_ceiling' => true)); r.opening[:x0] == 17.5 && close?(r.opening[:z0], 57.5) }
check('export có cờ hông') { e = PM.compute(600, 560, 2000, FL.merge('sides_to_floor' => true)).resolved; e['sides_to_floor'] == true && e['sides_to_ceiling'] == false }

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.size}"
$fail.each { |f| puts "  - #{f}" }
exit($fail.empty? ? 0 : 1)
