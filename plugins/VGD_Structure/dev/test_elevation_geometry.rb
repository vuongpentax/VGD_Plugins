# Test hình học mặt đứng 2D (chiếu mặt, sắp xa đến gần, bốn hướng, mặt suy biến, lỗ). Logic thuần, không cần SketchUp.
# Chạy: ruby dev/test_elevation_geometry.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
module VGD; module Structure; end; end
require_relative '../runtime/vgd_structure/core/elevation_geometry'
EG = VGD::Structure::ElevationGeometry

# Mặt phẳng đứng [x0..x1] (y cố định) hoặc [y0..y1] (x cố định), cao z0..z1, dùng cho hộp.
def rect_y(y, x0, x1, z0, z1, src = nil); {'outer' => [[x0, y, z0], [x1, y, z0], [x1, y, z1], [x0, y, z1]], 'loops' => [], src: src}; end
def rect_x(x, y0, y1, z0, z1, src = nil); {'outer' => [[x, y0, z0], [x, y1, z0], [x, y1, z1], [x, y0, z1]], 'loops' => [], src: src}; end

# Hộp 1000 (x) x 500 (y) x 3000 (z) gồm mặt trước (y = 0), mặt sau (y = 500), hai mặt bên (x = 0, x = 1000).
front = rect_y(0, 0, 1000, 0, 3000, 'front')
back = rect_y(500, 0, 1000, 0, 3000, 'back')
side0 = rect_x(0, 0, 500, 0, 3000, 'side0')
side1 = rect_x(1000, 0, 500, 0, 3000, 'side1')
faces = [front, back, side0, side1]

south = EG.project(EG.view!('south'), faces)
ok('nhìn từ Nam: ngang = x, cao = z, khung 0..1000 x 0..3000', south[:bounds] == {s0: 0.0, s1: 1000.0, z0: 0.0, z1: 3000.0})
ok('nhìn từ Nam: mặt xa (y = 500) được tô trước, mặt gần (y = 0) tô sau cùng', south[:polys].last[:src] == 'front' && south[:polys].first[:depth] > south[:polys].last[:depth])
ok('các mặt sắp theo độ sâu giảm dần (xa đến gần)', south[:polys].each_cons(2).all? { |a, b| a[:depth] >= b[:depth] })
ok('mỗi mặt mang nguồn của nó (hai mặt bên nhìn thẳng cạnh không có mặt nên không có nguồn)', south[:polys].map { |p| p[:src] }.sort == %w[back front])

north = EG.project(EG.view!('north'), faces)
ok('nhìn từ Bắc: ngang = -x (khung -1000..0), mặt gần là mặt y = 500', north[:bounds][:s0] == -1000.0 && north[:bounds][:s1] == 0.0 && north[:polys].last[:src] == 'back')

west = EG.project(EG.view!('west'), faces)
ok('nhìn từ Tây: ngang = -y (khung -500..0), mặt gần là mặt bên x = 0', west[:bounds][:s0] == -500.0 && west[:bounds][:s1] == 0.0 && west[:polys].last[:src] == 'side0')

east = EG.project(EG.view!('east'), faces)
ok('nhìn từ Đông: ngang = y (khung 0..500), mặt gần là mặt bên x = 1000', east[:bounds][:s0] == 0.0 && east[:bounds][:s1] == 500.0 && east[:polys].last[:src] == 'side1')

# Mặt đứng nhìn thẳng cạnh (diện tích 0) bị bỏ: mặt bên x = 0 khi nhìn từ Nam chỉ là đường thẳng.
ok('mặt bên nhìn thẳng cạnh (diện tích 0) không thành đa giác', south[:polys].none? { |p| p[:src] == 'side0' || p[:src] == 'side1' })

# Mặt có lỗ: lỗ được giữ nguyên tọa độ (s, z).
holed = {'outer' => [[0, 0, 0], [1000, 0, 0], [1000, 0, 3000], [0, 0, 3000]], 'loops' => [[[300, 0, 1000], [700, 0, 1000], [700, 0, 2000], [300, 0, 2000]]], src: 'wall'}
hp = EG.project(EG.view!('south'), [holed])[:polys].first
ok('mặt có lỗ: giữ một vòng lỗ với đúng tọa độ', hp[:holes].size == 1 && hp[:holes][0] == [[300.0, 1000.0], [700.0, 1000.0], [700.0, 2000.0], [300.0, 2000.0]])

ok('không có mặt nào: đa giác rỗng, khung nil', EG.project(EG.view!('south'), [])[:bounds].nil? && EG.project(EG.view!('south'), [])[:polys].empty?)

ok('hướng lạ: báo lỗi rõ', (begin; EG.view!('up'); false; rescue ArgumentError => e; e.message.include?('không hợp lệ'); end))
ok('tên hướng nhận cả dạng Symbol', EG.view!(:south) == EG.view!('south'))

# Tọa độ làm tròn 0.1 mm, không lộ số thừa.
r = EG.project(EG.view!('south'), [rect_y(0.04, 0.02, 1000.06, 0.01, 3000.04, 'x')])[:polys].first
ok('tọa độ làm tròn một chữ số thập phân', r[:pts] == [[0.0, 0.0], [1000.1, 0.0], [1000.1, 3000.0], [0.0, 3000.0]])

# Mặt phẳng độ sâu (cho che khuất theo từng điểm ảnh ở giao diện): d = a * s + b * z + c đúng tại mọi đỉnh, kể cả mặt xiên.
slant = {'outer' => [[0, 1000, 0], [4000, 5000, 0], [4000, 5000, 3000], [0, 1000, 3000]], 'loops' => [], src: {kind: 'wall'}}
pl = EG.project(EG.view!('south'), [slant])[:polys].first
a, b, c = pl[:plane]
ok('mặt xiên 45° nhìn từ Nam: độ sâu tăng theo s (a = 1), không đổi theo z, đúng tại mọi đỉnh', (a - 1).abs < 1e-6 && b.abs < 1e-6 && slant['outer'].all? { |x, y, z| (a * x + b * z + c - y).abs < 1e-3 })
flat = EG.project(EG.view!('east'), [{'outer' => [[5000, 0, 0], [5000, 3000, 0], [5000, 3000, 2000], [5000, 0, 2000]], 'loops' => [], src: {kind: 'wall'}}])[:polys].first
ok('mặt song song mặt nhìn: độ sâu là hằng số', flat[:plane][0].abs < 1e-9 && flat[:plane][1].abs < 1e-9 && (flat[:plane][2] + 5000).abs < 1e-3)
roof = {'outer' => [[0, 0, 3000], [6000, 0, 3000], [6000, 3000, 4732], [0, 3000, 4732]], 'loops' => [], src: {kind: 'roof'}}
rp = EG.project(EG.view!('south'), [roof])[:polys].first
ok('mặt mái nghiêng nhìn từ Nam: độ sâu tăng theo cao độ', rp[:plane][1] > 0 && roof['outer'].all? { |x, y, z| (rp[:plane][0] * x + rp[:plane][1] * z + rp[:plane][2] - y).abs < 1e-2 })

puts $fails.zero? ? "\nTất cả PASS" : "\n#{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
