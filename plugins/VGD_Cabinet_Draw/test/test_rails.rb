# Test xà trước/sau (beta.39): nằm/đứng, kép/đơn, xà thay đáy (xà trên của tủ quá khổ).
# Chạy: ruby test_rails.rb <đường dẫn runtime/VGD_Cabinet_Draw>
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

def close?(a, b)
  (a - b).abs <= 1e-6
end

def part(result, role)
  result.parts.find { |p| p.role == role } || result.trim.find { |p| p.role == role }
end

def bounds_of(result, role)
  part(result, role).bounds
end

# Hộp bao [x0, y0, z0, x1, y1, z1] khớp với mong đợi (mm).
def same_box?(bounds, expected)
  bounds.zip(expected).all? { |a, b| close?(a, b) }
end

# Tủ bếp dưới 600 x 560 x 820 với chân 100: thân cao 720, lòng hậu mặc định (yg0 = 544, rt = 17.5, rw = 100).
def base(extra = {})
  PM.compute(600, 560, 820, { 'cabinet_type' => 'base', 'leg_height' => 100 }.merge(extra))
end

puts '== 1. Mặc định tủ bếp dưới: xà trước nằm, xà sau đứng (như bản cũ) =='
r = base
check('xà trước nằm: x giữa hai hông, y 0..100, z 802.5..820 (sát mép trên)') { same_box?(bounds_of(r, 'rail_front'), [17.5, 0, 802.5, 582.5, 100, 820]) }
check('xà sau đứng: y 526.5..544, z 720..820') { same_box?(bounds_of(r, 'rail_back'), [17.5, 526.5, 720, 582.5, 544, 820]) }
check('tủ bếp dưới: không có nóc, vẫn có đáy') { part(r, 'top').nil? && !part(r, 'bottom').nil? }

puts '== 2. Xà trước đơn/kép, xà sau luôn một bản =='
r = base
check('xà sau luôn có (một bản, không kép)') { !part(r, 'rail_back').nil? }
check('xà trước mặc định đơn: bản dày rt (17.5)') { close?(bounds_of(r, 'rail_front')[5] - bounds_of(r, 'rail_front')[2], 17.5) }
r = base('rail_front_double' => true)
check('xà trước kép nằm: bản dày 2 × 17.5 = 35, sát mép trên') { same_box?(bounds_of(r, 'rail_front'), [17.5, 0, 785, 582.5, 100, 820]) }
r = base('rail_front_double' => true, 'rail_front_orient' => 'upright')
check('xà trước kép đứng: hai bản ghép sâu 35 mm ở mép trước') { same_box?(bounds_of(r, 'rail_front'), [17.5, 0, 720, 582.5, 35, 820]) }

puts '== 3. Đổi hướng =='
r = base('rail_front_orient' => 'upright')
check('xà trước đứng: bản thẳng đứng ở mép trước (y 0..17.5, z 720..820)') { same_box?(bounds_of(r, 'rail_front'), [17.5, 0, 720, 582.5, 17.5, 820]) }
r = base('rail_back_orient' => 'flat')
check('xà sau nằm: y 444..544, z 802.5..820') { same_box?(bounds_of(r, 'rail_back'), [17.5, 444, 802.5, 582.5, 544, 820]) }

puts '== 4. Xà thay đáy (tủ trên của tủ quá khổ) =='
r = PM.compute(600, 560, 500, 'cabinet_type' => 'standard', 'bottom_mode' => 'rails', 'leg_height' => 0)
check('đáy thay bằng xà: không còn tấm Đáy') { part(r, 'bottom').nil? }
check('xà trước đáy nằm sát đáy: z 0..17.5, y 0..100') { same_box?(bounds_of(r, 'rail_front_bottom'), [17.5, 0, 0, 582.5, 100, 17.5]) }
check('xà sau đáy đứng: y 526.5..544, z 0..100') { same_box?(bounds_of(r, 'rail_back_bottom'), [17.5, 526.5, 0, 582.5, 544, 100]) }
check('tủ trên có nóc nguyên tấm') { !part(r, 'top').nil? && part(r, 'top').role == 'top' }
check('xà đáy chỉ có khi đáy thay bằng xà') { PM.compute(600, 560, 500, 'cabinet_type' => 'standard').parts.none? { |p| p.role.end_with?('_bottom') } }

puts '== 5. Tủ bếp dưới có cả nóc-xà và đáy-xà =='
r = base('bottom_mode' => 'rails')
check('có xà nóc và xà đáy cùng lúc (khác vai trò)') { !part(r, 'rail_front').nil? && !part(r, 'rail_front_bottom').nil? }

puts '== 6. Kiểm tra đầu vào =='
check('xà quá sâu (nằm + nằm 300 mm trên 544 mm) báo lỗi') do
  raises_msg(/Bản xà/) { base('top_rail_width' => 300, 'rail_back_orient' => 'flat', 'rail_back_width' => 300) }
end
check('hướng xà lạ báo lỗi') { raises_msg(/Hướng xà trước/) { base('rail_front_orient' => 'nghieng') } }
check('hướng xà sau lạ báo lỗi') { raises_msg(/Hướng xà sau/) { base('rail_back_orient' => 'xien') } }

puts '== 7. Thông số được lưu để dựng lại =='
resolved = base('bottom_mode' => 'rails', 'rail_back_orient' => 'flat', 'rail_back_width' => 80).resolved
check('lưu đủ khóa xà') do
  resolved['bottom_mode'] == 'rails' && resolved['rail_back_orient'] == 'flat' && resolved['rail_back_width'] == 80.0 &&
    resolved['rail_front_orient'] == 'flat' && resolved['rail_front_double'] == false
end
check('mặc định (không khai báo): xà trước nằm đơn, xà sau đứng, không xà đáy') do
  rs = base.resolved
  rs['rail_front_orient'] == 'flat' && rs['rail_back_orient'] == 'upright' && rs['rail_front_double'] == false && rs['bottom_mode'] == 'full'
end

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.size}"
exit($fail.empty? ? 0 : 1)
