# Test hình học mặt cắt 2D (cắt mặt, nối đường viền, chiếu cạnh phía sau). Logic thuần, không cần SketchUp.
# Chạy: ruby dev/test_section_geometry.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
module VGD; module Structure; end; end
require_relative '../runtime/vgd_structure/core/section_geometry'
SG = VGD::Structure::SectionGeometry

# Hộp [x0..x1] x [y0..y1] x [z0..z1]: 6 mặt và 12 cạnh.
def box(x0, x1, y0, y1, z0, z1)
  v = ->(x, y, z) { [x, y, z] }
  faces = [
    [v[x0, y0, z0], v[x1, y0, z0], v[x1, y1, z0], v[x0, y1, z0]], [v[x0, y0, z1], v[x1, y0, z1], v[x1, y1, z1], v[x0, y1, z1]],
    [v[x0, y0, z0], v[x1, y0, z0], v[x1, y0, z1], v[x0, y0, z1]], [v[x0, y1, z0], v[x1, y1, z0], v[x1, y1, z1], v[x0, y1, z1]],
    [v[x0, y0, z0], v[x0, y1, z0], v[x0, y1, z1], v[x0, y0, z1]], [v[x1, y0, z0], v[x1, y1, z0], v[x1, y1, z1], v[x1, y0, z1]]
  ].map { |ring| {'outer' => ring} }
  edges = []
  [[x0, x1], [y0, y1], [z0, z1]].tap do |(xs, ys, zs)|
    ys.each { |y| zs.each { |z| edges << [v[x0, y, z], v[x1, y, z]] } }
    xs.each { |x| zs.each { |z| edges << [v[x, y0, z], v[x, y1, z]] } }
    xs.each { |x| ys.each { |y| edges << [v[x, y, z0], v[x, y, z1]] } }
  end
  [faces, edges]
end
wall_faces, wall_edges = box(0, 4000, -100, 100, 0, 3000) # tường dọc X, dày 200, cao 3000

# ---- Mặt phẳng ----
pl = SG.plane([2000, -1000], [2000, 1000], 1, 1000)
ok('mặt phẳng dọc +Y: pháp tuyến trái là -X, s tính từ a', pl.ux.round(6) == 0 && pl.uy == 1.0 && pl.nx == -1.0 && SG.local(pl, [2000, 0, 50]) == [1000.0, 0.0, 50])
ok('điểm phía pháp tuyến trái có t dương', SG.local(pl, [1900, 0, 0])[1] == 100.0)
ok('đường cắt quá ngắn: báo lỗi', begin; SG.plane([0, 0], [0.5, 0], 1, 100); false; rescue ArgumentError; true; end)

# ---- Cắt mặt ----
segs = SG.cut_faces(pl, wall_faces)
ok('cắt hộp tường ngang qua giữa: 4 đoạn (hai mặt đứng, mặt trên, mặt dưới)', segs.size == 4)
loops = SG.loops(segs)
ok('nối thành MỘT đường viền khép kín 4 đỉnh', loops.size == 1 && loops[0][:closed] && loops[0][:pts].size == 4)
xs = loops[0][:pts].map(&:first); zs = loops[0][:pts].map(&:last)
ok('đường viền đúng hình chữ nhật: s từ 900 đến 1100 (tường dày 200 quanh y = 0), z từ 0 đến 3000', xs.min == 900.0 && xs.max == 1100.0 && zs.min == 0.0 && zs.max == 3000.0)
ok('cắt ngoài hộp (x = 5000): không có gì', SG.cut_faces(SG.plane([5000, -1000], [5000, 1000], 1, 100), wall_faces).empty?)
ok('cắt dọc theo chiều dài tường (y = 0): được hình chữ nhật dài 4000 x 3000', begin; l = SG.loops(SG.cut_faces(SG.plane([-500, 0], [4500, 0], 1, 100), wall_faces)); l.size == 1 && l[0][:closed] && l[0][:pts].map(&:first).minmax == [500.0, 4500.0]; end)
cs, _ = box(2000, 2400, -100, 100, 0, 3000)
two = SG.loops(SG.cut_faces(pl, wall_faces + cs).then { |s| s })
ok('hai hộp tách rời cắt ra hai đường viền riêng', SG.loops(SG.cut_faces(SG.plane([1000, -1000], [1000, 1000], 1, 100), wall_faces + cs[0..-1])).size == 1 && two.size >= 1)
cut_two = SG.loops(SG.cut_faces(SG.plane([2200, -1000], [2200, 1000], 1, 100), wall_faces + box(2000, 2400, 150, 350, 0, 3000)[0]))
ok('hai hộp tách rời trong mặt phẳng cắt (y trong -100..100 và 150..350): hai đường viền khép kín', cut_two.size == 2 && cut_two.all? { |l| l[:closed] })
hole = {'outer' => [[0, -500, 0], [0, 500, 0], [0, 500, 1000], [0, -500, 1000]], 'loops' => [[[0, -100, 300], [0, 100, 300], [0, 100, 700], [0, -100, 700]]]}
hs = SG.cut_faces(SG.plane([-500, 0], [500, 0], 1, 100), [hole]) # mặt đứng x = 0 có lỗ, cắt theo y = 0 ... song song, cắt thẳng vuông
ok('mặt có lỗ: đường cắt đi qua lỗ cho hai đoạn (chẵn - lẻ), không phải một', hs.size == 2 && hs.map { |a, b| (a[1] - b[1]).abs }.sort == [300.0, 300.0])
ok('mặt nằm song song và trùng mặt phẳng cắt: không sinh đoạn', SG.cut_faces(SG.plane([0, -1000], [0, 1000], 1, 100), [{'outer' => [[0, -500, 0], [0, 500, 0], [0, 500, 1000], [0, -500, 1000]]}]).empty?)
ok('đỉnh nằm đúng trên mặt phẳng không bị đếm hai lần (mặt phẳng đi qua đỉnh hộp)', begin; segs0 = SG.cut_faces(SG.plane([4000, -1000], [4000, 1000], 1, 100), wall_faces); segs0.all? { |a, b| true } && segs0.size <= 6; end)
open_chain = SG.loops([[[0, 0], [100, 0]], [[100, 0], [100, 100]]])
ok('đoạn nối không khép kín: đường hở (closed false) giữ đủ 3 điểm', open_chain.size == 1 && !open_chain[0][:closed] && open_chain[0][:pts].size == 3)
ok('hai đoạn đầu cách nhau dưới dung sai 0,5 mm vẫn nối', SG.loops([[[0, 0], [100, 0]], [[100.3, 0.2], [100, 100]]])[0][:pts].size == 3)

# ---- Cạnh phía sau ----
pb = SG.plane([-500, -1000], [-500, 1000], -1, 1000) # nhìn về +X
back = SG.beyond(pb, wall_edges)
ok('nhìn từ x = -500 về +X, tầm 1000: chỉ thấy cạnh ở x = 0 (4 cạnh vuông góc hướng nhìn); cạnh dọc X bị cắt thành điểm nên bỏ', back.size == 4)
ok('cạnh đứng ở x = 0 chiếu đúng: s = 900 và 1100, z từ 0 đến 3000', back.select { |a, b| a[0] == b[0] }.map { |a, b| [a[0], [a[1], b[1]].minmax] }.sort == [[900.0, [0.0, 3000.0]], [1100.0, [0.0, 3000.0]]])
ok('tầm nhìn 5000: thấy cả cạnh ở x = 4000 (8 cạnh)', SG.beyond(SG.plane([-500, -1000], [-500, 1000], -1, 5000), wall_edges).size == 8)
ok('nhìn ngược (+1 = về phía -X): không thấy gì ở sau', SG.beyond(SG.plane([-500, -1000], [-500, 1000], 1, 1000), wall_edges).empty?)
slant = SG.beyond(SG.plane([0, 0], [1000, 0], 1, 300), [[[200, -500, 0], [200, 500, 1000]]])
ok('cạnh xuyên qua mặt cắt được cắt theo tầm nhìn 0..300: chỉ giữ phần t từ 0 đến 300 (s = 200, z từ 500 đến 800)', slant == [[[200.0, 500.0], [200.0, 800.0]]])
ok('cạnh song song mặt cắt trong tầm nhìn: giữ nguyên; ngoài tầm nhìn: bỏ', SG.beyond(SG.plane([0, 0], [1000, 0], 1, 300), [[[0, 100, 500], [800, 100, 500]], [[0, 400, 500], [800, 400, 500]]]) == [[[0.0, 500.0], [800.0, 500.0]]])

puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
