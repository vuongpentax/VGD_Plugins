# Test lưới trục (core/grid.rb) và kế hoạch ký hiệu trục (core/axis_symbol.rb): dữ liệu sai bị từ chối, tên trục, giao điểm / nhịp / ô,
# quy ước cột biên - cột góc, kích thước ký hiệu theo tỉ lệ. Chạy: ruby dev/test_grid.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
require File.join(ROOT, 'core/grid')
require File.join(ROOT, 'core/axis_symbol')
G = VGD::Structure::Grid
S = VGD::Structure::AxisSymbol

ok('tên chữ bỏ I và O: A..H, J..N, P..Z (24 chữ)', G.default_names(:letter, 24) == %w[A B C D E F G H J K L M N P Q R S T U V W X Y Z])
ok('hết 24 chữ thì AA, AB...', G.default_names(:letter, 26).last(2) == %w[AA AB])
ok('tên số 1..n', G.default_names(:number, 3) == %w[1 2 3])
ok('số trục ngoài 2..60 hoặc kiểu lạ bị từ chối', [1, 61, '3', nil].all? { |n| !error_of { G.default_names(:number, n) }.nil? } && !error_of { G.default_names(:roman, 3) }.nil?)

axes = G.axes_from_spacings('4200, 3600*2, 3000', :number)
ok('nhịp "4200, 3600*2, 3000" -> 5 trục, vị trí cộng dồn từ 0', axes.map { |a| a['offset'] } == [0.0, 4200.0, 7800.0, 11400.0, 14400.0] && axes.map { |a| a['name'] } == %w[1 2 3 4 5])
ok('nhịp lẻ dùng dấu chấm, x hoặc × như dấu nhân: "3600.5x2 1200×3"', G.parse_spacings('3600.5x2 1200×3') == [3600.5, 3600.5, 1200.0, 1200.0, 1200.0])
ok('dấu phẩy là dấu ngăn cách, không phải dấu thập phân: "3600,5" bị từ chối vì nhịp 5 quá nhỏ', !error_of { G.parse_spacings('3600,5') }.nil?)
bad_spacing = ['', '   ', 'abc', '4200*', '*3', '50', '4200*100', '-300', nil, 5, ('4200 ' * 60)]
bad_spacing.each { |t| ok("nhịp sai bị từ chối: #{t.inspect[0, 20]}", !error_of { G.parse_spacings(t) }.nil?) }

g = G.default
ok('lưới mặc định: 4 trục đứng 1-4, 3 trục ngang A-C, gốc 0,0', g['x_axes'].size == 4 && g['y_axes'].map { |a| a['name'] } == %w[A B C] && g['origin'] == [0.0, 0.0])
ok('khung bao: 0,0 đến 12600 x 7200', G.bounds(g) == [0.0, 0.0, 12_600.0, 7200.0])
ok('gốc lưới dời khung bao', G.bounds(G.normalize!(g.merge('origin' => [1000, -500]))) == [1000.0, -500.0, 13_600.0, 6700.0])

ints = G.intersections(g)
ok('4 x 3 = 12 giao điểm', ints.size == 12)
by = ints.each_with_object({}) { |i, h| h[i[:ref]] = i[:placement] }
ok('giao điểm: góc ở 4 góc, biên ở rìa, giữa ở trong (1-A góc, 2-A biên, 2-B giữa, 4-C góc, 1-B biên)', by['1-A'] == 'corner' && by['4-C'] == 'corner' && by['1-C'] == 'corner' && by['4-A'] == 'corner' && by['2-A'] == 'edge' && by['1-B'] == 'edge' && by['2-B'] == 'middle' && by['3-B'] == 'middle')
ok('đếm: 4 góc, 6 biên (2+2+1+1), 2 giữa', by.values.count('corner') == 4 && by.values.count('edge') == 6 && by.values.count('middle') == 2)
spans = G.spans(g)
ok('nhịp: 3 nhịp x 3 trục ngang + 2 nhịp x 4 trục đứng = 17', spans.size == 17 && spans.count { |s| s[:dir] == 'x' } == 9 && spans.count { |s| s[:dir] == 'y' } == 8)
ok('mã nhịp x:A:1-2 dài 4200, nằm trên trục biên', spans.find { |s| s[:ref] == 'x:A:1-2' }.then { |s| s[:length] == 4200.0 && s[:placement] == 'edge' && s[:from] == [0.0, 0.0] && s[:to] == [4200.0, 0.0] })
ok('nhịp trên trục giữa (x:B:2-3, y:2:A-B) là inner, y:1:A-B là edge', spans.find { |s| s[:ref] == 'x:B:2-3' }[:placement] == 'inner' && spans.find { |s| s[:ref] == 'y:2:A-B' }[:placement] == 'inner' && spans.find { |s| s[:ref] == 'y:1:A-B' }[:placement] == 'edge')
cells = G.cells(g)
ok('ô: 3 x 2 = 6, ô 1-2/A-B rộng 4200 sâu 3600', cells.size == 6 && cells.first.values_at(:ref, :width, :depth, :min, :max) == ['1-2/A-B', 4200.0, 3600.0, [0.0, 0.0], [4200.0, 3600.0]])
ok('mã giao điểm, nhịp, ô không trùng nhau', [ints.map { |i| i[:ref] }, spans.map { |s| s[:ref] }, cells.map { |c| c[:ref] }].all? { |l| l.uniq.size == l.size })

bad = {
  'không phải bảng băm' => 'x', 'thiếu trục đứng' => g.reject { |k, _| k == 'x_axes' }, 'một trục đứng' => g.merge('x_axes' => [g['x_axes'][0]]),
  'quá 60 trục' => g.merge('y_axes' => (0..60).map { |i| {'name' => "Y#{i}", 'offset' => i * 1000} }),
  'tên rỗng' => g.merge('x_axes' => [{'name' => ' ', 'offset' => 0}, {'name' => '2', 'offset' => 4200}]),
  'tên quá 4 ký tự' => g.merge('x_axes' => [{'name' => 'ABCDE', 'offset' => 0}, {'name' => '2', 'offset' => 4200}]),
  'tên có ký tự điều khiển' => g.merge('x_axes' => [{'name' => "1\n", 'offset' => 0}, {'name' => '2', 'offset' => 4200}].map { |a| a.merge('name' => a['name'].include?("\n") ? "A\u0001" : a['name']) }),
  'tên không phải chuỗi' => g.merge('x_axes' => [{'name' => 1, 'offset' => 0}, {'name' => '2', 'offset' => 4200}]),
  'tên trùng trong phương' => g.merge('x_axes' => [{'name' => '1', 'offset' => 0}, {'name' => '1', 'offset' => 4200}]),
  'tên trùng giữa hai phương, không phân biệt hoa thường' => g.merge('x_axes' => [{'name' => 'a', 'offset' => 0}, {'name' => '2', 'offset' => 4200}]),
  'vị trí không tăng' => g.merge('x_axes' => [{'name' => '1', 'offset' => 4200}, {'name' => '2', 'offset' => 4200}]),
  'nhịp dưới 100 mm' => g.merge('x_axes' => [{'name' => '1', 'offset' => 0}, {'name' => '2', 'offset' => 99}]),
  'vị trí là chuỗi' => g.merge('x_axes' => [{'name' => '1', 'offset' => 0}, {'name' => '2', 'offset' => '4200'}]),
  'vị trí NaN' => g.merge('x_axes' => [{'name' => '1', 'offset' => 0}, {'name' => '2', 'offset' => Float::NAN}]),
  'vị trí vô cực' => g.merge('x_axes' => [{'name' => '1', 'offset' => 0}, {'name' => '2', 'offset' => Float::INFINITY}]),
  'vị trí quá lớn' => g.merge('x_axes' => [{'name' => '1', 'offset' => 0}, {'name' => '2', 'offset' => 2_000_000}]),
  'gốc một số' => g.merge('origin' => [1]), 'gốc là chuỗi' => g.merge('origin' => %w[0 0]), 'gốc quá lớn' => g.merge('origin' => [2_000_000, 0]),
  'trục không phải bảng băm' => g.merge('y_axes' => [1, 2])
}
bad.each { |label, raw| ok("lưới sai bị từ chối: #{label}", !error_of { G.normalize!(raw) }.nil?) }
ok('lưới đúng được làm sạch (cắt khoảng trắng tên, làm tròn 0,1), không đổi dữ liệu vào', (n = G.normalize!(g.merge('x_axes' => [{'name' => ' 1 ', 'offset' => 0}, {'name' => '2', 'offset' => 4200.04}]))) && n['x_axes'][0]['name'] == '1' && n['x_axes'][1]['offset'] == 4200.0 && g['x_axes'].size == 4)
ok('thiếu gốc thì mặc định 0,0', G.normalize!(g.reject { |k, _| k == 'origin' })['origin'] == [0.0, 0.0])

# Ký hiệu trục
o = S.options!(nil)
ok('tùy chọn mặc định: tỉ lệ 1:100, một đầu', o == {'scale' => 100, 'both_ends' => false})
['x', 5.5, 9, 1001, nil.to_s, -1].each { |s| ok("tỉ lệ sai bị từ chối: #{s.inspect}", !error_of { S.options!('scale' => s) }.nil?) }
ok('ký hiệu hai đầu phải là true / false', !error_of { S.options!('both_ends' => 'yes') }.nil? && !error_of { S.options!('x') }.nil?)
plan = S.plan(g, nil)
ok('7 trục (4 đứng + 3 ngang), mỗi trục một vòng tròn', plan.size == 7 && plan.all? { |a| a[:bubbles].size == 1 })
a1 = plan.find { |a| a[:name] == '1' }
ok('tỉ lệ 1:100: vòng tròn đường kính 1000 (bán kính 500), chữ cao 400', a1[:bubbles][0][:radius] == 500.0 && a1[:text_height] == 400.0)
ok('trục đứng 1: đường từ y = -1500 đến 8700, vòng tròn ở đầu dưới, tâm cách mép lưới 1500 + 500', a1[:line] == [[0.0, -1500.0], [0.0, 8700.0]] && a1[:bubbles][0][:center] == [0.0, -2000.0])
aA = plan.find { |a| a[:name] == 'A' }
ok('trục ngang A: đường từ x = -1500 đến 14100, vòng tròn ở đầu trái', aA[:line] == [[-1500.0, 0.0], [14_100.0, 0.0]] && aA[:bubbles][0][:center] == [-2000.0, 0.0])
ok('mép vòng tròn chạm đầu đường trục', (a1[:bubbles][0][:center][1] + 500.0 - a1[:line][0][1]).abs < 1e-9)
both = S.plan(g, 'both_ends' => true, 'scale' => 50)
ok('hai đầu, tỉ lệ 1:50: hai vòng tròn bán kính 250, vòng thứ hai ở đầu kia', both.all? { |a| a[:bubbles].size == 2 && a[:bubbles].all? { |b| b[:radius] == 250.0 } } && both.find { |a| a[:name] == '1' }[:bubbles][1][:center] == [0.0, 7200.0 + 750.0 + 250.0])
ok('tên 3 ký tự thì chữ nhỏ hơn để lọt vòng tròn', S.text_height('AAA', 1000.0) < S.text_height('A', 1000.0))
ok('gốc lưới dời toàn bộ ký hiệu', S.plan(G.normalize!(g.merge('origin' => [100, 200])), nil).find { |a| a[:name] == '1' }[:bubbles][0][:center] == [100.0, 200.0 - 2000.0])

puts $fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
