# Test đơn vị và ô nhập (core/units.rb): số có đơn vị, số theo đơn vị của file, dấu phẩy, giới hạn, ô scale.
# Không cần SketchUp. Chạy: ruby dev/test_units.rb (từ plugins/VGD_Transform)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_transform', __dir__)
require File.join(ROOT, 'core/units')
U = VGD::Transform::Units

# Đơn vị file: chỉ số của SketchUp (LengthUnit): 0 in, 1 ft, 2 mm, 3 cm, 4 m
ok('chỉ số đơn vị của SketchUp: 2 là mm, 4 là m', U.unit_of_model(2) == 'mm' && U.unit_of_model(4) == 'm' && U.unit_of_model(0) == 'in')
ok('chỉ số đơn vị lạ thì dùng mm', U.unit_of_model(99) == 'mm' && U.unit_of_model(nil) == 'mm')

# Số không có đơn vị: hiểu theo đơn vị của file
ok('file mm: "1200" là 1200 mm', U.parse_length('1200', 'mm') == 1200.0)
ok('file m: "1,5" là 1,5 m = 1500 mm', U.parse_length('1,5', 'm') == 1500.0)
ok('file mm: "1m" là 1000 mm (gõ đơn vị thì dùng đơn vị đã gõ)', U.parse_length('1m', 'mm') == 1000.0)
ok('file m: "250mm" là 250 mm', U.parse_length('250mm', 'm') == 250.0)
ok('có khoảng trắng giữa số và đơn vị: "2 cm" là 20 mm', U.parse_length('2 cm', 'mm') == 20.0)
ok('đơn vị không phân biệt hoa thường: "1M" là 1000 mm', U.parse_length('1M', 'mm') == 1000.0)
ok('inch và feet: 1in = 25.4 mm, 1ft = 304.8 mm', (U.parse_length('1in', 'mm') - 25.4).abs < 1e-9 && (U.parse_length('1ft', 'mm') - 304.8).abs < 1e-9)
ok('trống thì là nil (không nhập)', U.parse_length('', 'mm').nil? && U.parse_length(nil, 'mm').nil?)
ok('chữ, số mũ, đơn vị lạ bị từ chối', %w[abc 1e3 12a --5 NaN 5km 5yd].all? { |t| error_of { U.parse_length(t, 'mm') } })
ok('vượt giới hạn ±1 km bị từ chối (cả khi gõ đơn vị)', error_of { U.parse_length('1000001', 'mm') }.to_s.include?('vượt giới hạn') && error_of { U.parse_length('2000m', 'mm') }.to_s.include?('vượt giới hạn'))

# Số không đơn vị (góc, hệ số)
ok('số thường: "15", "-2,5", ".5"', U.parse_number('15') == 15.0 && U.parse_number('-2,5') == -2.5 && U.parse_number('.5') == 0.5)
ok('số thường: trống là nil, chữ bị từ chối', U.parse_number('').nil? && error_of { U.parse_number('x') }.to_s.include?('không phải số'))

# Ô scale: số không đơn vị là hệ số; số có đơn vị là kích thước đích
ok('ô scale: "1.5" và "1,5" là hệ số', U.parse_scale('1.5') == 1.5 && U.parse_scale('1,5') == 1.5)
ok('ô scale: "1000mm" là kích thước đích 1000 mm', U.parse_scale('1000mm') == {length: 1000.0})
ok('ô scale: "1m" là kích thước đích 1000 mm (không phụ thuộc đơn vị file)', U.parse_scale('1m') == {length: 1000.0})
ok('ô scale: trống là nil', U.parse_scale('') .nil?)
ok('ô scale: kích thước đích 0 hoặc âm bị từ chối', error_of { U.parse_scale('0m') }.to_s.include?('lớn hơn 0') && error_of { U.parse_scale('-1m') }.to_s.include?('lớn hơn 0'))
ok('ô scale: vượt giới hạn và đơn vị lạ bị từ chối', error_of { U.parse_scale('2000m') }.to_s.include?('vượt giới hạn') && error_of { U.parse_scale('2km') }.to_s.include?('không phải số'))
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
