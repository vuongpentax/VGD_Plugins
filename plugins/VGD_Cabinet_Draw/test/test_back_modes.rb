# Test kiểu hậu (beta.38): âm 4 cạnh, âm 2 hông, lùa trên, lùa đáy, phủ, không hậu.
# Chạy: ruby test_back_modes.rb <đường dẫn runtime/VGD_Cabinet_Draw>
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

# So khớp hộp bao [x0, y0, z0, x1, y1, z1] với giá trị mong đợi.
def same_box?(bounds, expected)
  bounds.zip(expected).all? { |a, b| close?(a, b) }
end

def part(result, role)
  result.parts.find { |p| p.role == role } || result.trim.find { |p| p.role == role }
end

def bounds_of(result, role)
  part(result, role).bounds
end

# Mặc định 600 x 560 x 720: ván 17.5, hậu 6, ngậm rãnh 8.75, lớp che sau 10.
# Vì vậy: mép sau thùng d = 560, mặt trước hậu yg0 = 544, mép sau rãnh yg1 = 550.
# Lòng: x 17.5..582.5, z 17.5..702.5.
def build(mode, extra = {}, height = 720)
  PM.compute(600, 560, height, { 'back_mode' => mode }.merge(extra))
end

puts '== 1. Danh sách kiểu hậu =='
check('có đủ sáu kiểu hậu') { PM::BACK_MODES.sort == %w[groove groove_sides lua_bottom lua_top none overlay].sort }
check('mỗi kiểu được ghi lại đúng trong thông số đã chuẩn hóa') do
  PM::BACK_MODES.all? { |mode| build(mode).resolved['back_mode'] == mode }
end
check('kiểu lạ vẫn bị từ chối') { raises_msg(/Kiểu hậu/) { build('lua_xyz') } }

puts '== 2. Âm 4 cạnh (giữ như cũ) =='
r = build('groove')
check('hậu chạy vào rãnh cả bốn phía') { same_box?(bounds_of(r, 'back'), [8.75, 544, 8.75, 591.25, 550, 711.25]) }
check('đáy và nóc sâu tới mép sau thùng') { bounds_of(r, 'bottom')[4] == 560.0 && bounds_of(r, 'top')[4] == 560.0 }
check('hông, đáy, nóc đều được đánh dấu khoét rãnh') do
  %w[side_left side_right bottom top].all? { |role| part(r, role).grooved }
end

puts '== 3. Âm 2 hông =='
r = build('groove_sides')
check('hậu chạy suốt từ đáy tới nóc, rộng vào rãnh hông') { same_box?(bounds_of(r, 'back'), [8.75, 544, 0, 591.25, 550, 720]) }
check('nóc và đáy lùi vào: mép sau sát mặt trước hậu (544)') { bounds_of(r, 'top')[4] == 544.0 && bounds_of(r, 'bottom')[4] == 544.0 }
check('hông được khoét rãnh, nóc và đáy không khoét') do
  part(r, 'side_left').grooved && part(r, 'side_right').grooved && !part(r, 'top').grooved && !part(r, 'bottom').grooved
end

puts '== 4. Lùa trên =='
r = build('lua_top')
check('nóc lùi vào: mép sau 544, không khoét rãnh') { bounds_of(r, 'top')[4] == 544.0 && !part(r, 'top').grooved }
check('đáy giữ mép sau 560 và có rãnh (hậu tựa vào rãnh đáy)') { bounds_of(r, 'bottom')[4] == 560.0 && part(r, 'bottom').grooved }
check('hậu chạy từ rãnh đáy lên tới mép ngoài nóc') { same_box?(bounds_of(r, 'back'), [8.75, 544, 8.75, 591.25, 550, 720]) }

puts '== 5. Lùa đáy =='
r = build('lua_bottom')
check('đáy lùi vào: mép sau 544, không khoét rãnh') { bounds_of(r, 'bottom')[4] == 544.0 && !part(r, 'bottom').grooved }
check('nóc giữ mép sau 560 và có rãnh (hậu tựa vào rãnh nóc)') { bounds_of(r, 'top')[4] == 560.0 && part(r, 'top').grooved }
check('hậu chạy từ mép ngoài đáy (z = 0) tới rãnh nóc') { same_box?(bounds_of(r, 'back'), [8.75, 544, 0, 591.25, 550, 711.25]) }

puts '== 6. Phủ và không hậu =='
r = build('overlay')
check('phủ: hậu nằm sau, đầy đủ bề rộng và cao') { same_box?(bounds_of(r, 'back'), [0, 554, 0, 600, 560, 720]) }
check('phủ: không khoét rãnh') { %w[side_left side_right bottom top].none? { |role| part(r, role).grooved } }
r = build('none')
check('không hậu: không có tấm hậu') { part(r, 'back').nil? }

puts '== 7. Ván chân sau khi có chân cao 100 =='
# Chân cao 100 nên thân tủ nâng lên: tổng cao 820 cho thân 720.
check('âm 2 hông: ván chân sau lùi vào trước hậu (y 526.5..544)') do
  b = bounds_of(build('groove_sides', { 'leg_height' => 100 }, 820), 'toe_kick_back')
  close?(b[1], 526.5) && close?(b[4], 544.0)
end
check('lùa đáy: ván chân sau lùi vào trước hậu (y 526.5..544)') do
  b = bounds_of(build('lua_bottom', { 'leg_height' => 100 }, 820), 'toe_kick_back')
  close?(b[1], 526.5) && close?(b[4], 544.0)
end
check('lùa đáy: hậu chạy xuống sát đáy chân (z từ 100)') do
  close?(bounds_of(build('lua_bottom', { 'leg_height' => 100 }, 820), 'back')[2], 100.0)
end
check('âm 4 cạnh: ván chân sau giữ nguyên vị trí cũ (y 542.5..560)') do
  b = bounds_of(build('groove', { 'leg_height' => 100 }, 820), 'toe_kick_back')
  close?(b[1], 542.5) && close?(b[4], 560.0)
end
check('lùa trên: ván chân sau giữ nguyên vị trí cũ (y 542.5..560)') do
  b = bounds_of(build('lua_top', { 'leg_height' => 100 }, 820), 'toe_kick_back')
  close?(b[1], 542.5) && close?(b[4], 560.0)
end

puts '== 8. Kiểm tra chiều sâu theo tấm lùi vào =='
check('lùa đáy: đáy lùa tới 540 mm thì quá sát, báo lỗi chiều sâu') do
  raises_msg(/Chiều sâu/) { build('lua_bottom', 'panels' => { 'bottom' => { 'front_offset' => 540 } }) }
end
check('âm 4 cạnh: cùng độ lùi đáy 540 mm vẫn hợp lệ (đáy sâu tới 560)') do
  build('groove', 'panels' => { 'bottom' => { 'front_offset' => 540 } })
  true
end

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.size}"
exit($fail.empty? ? 0 : 1)
