# Test logic thuần của VGD Transform: món (tâm, hệ trục), dời tuyệt đối / tương đối, xoay, scale tương đối / tuyệt đối,
# công thức bước biến đổi, ghép công cụ với ô nhập. Không cần SketchUp.
# Chạy: ruby dev/test_transform.rb (từ plugins/VGD_Transform)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e; end
def near(a, b, tol = 1e-6); a.zip(b).all? { |x, y| (x - y).abs < tol }; end
ROOT = File.expand_path('../runtime/vgd_transform', __dir__)
%w[core/units core/items core/steps core/translate core/rotate_scale core/plan].each { |f| require File.join(ROOT, f) }
P = VGD::Transform
IT = P::Items
TR = P::Translate
RS = P::RotateScale
ST = P::Steps
PL = P::Plan
W = IT::WORLD_AXES
Z90 = [[0.0, 1.0, 0.0], [-1.0, 0.0, 0.0], [0.0, 0.0, 1.0]] # trục riêng của món đã xoay 90° quanh Z

# Món mẫu: điểm gốc, kích thước theo trục riêng (mm), trục riêng, tỉ lệ. Hộp bao thế giới tính từ 8 góc.
def make(index, name, origin, size: [1000.0, 1000.0, 1000.0], axes: W, scale: [1.0, 1.0, 1.0], locked: false)
  corners = [0, 1].product([0, 1], [0, 1]).map { |c| (0..2).map { |k| origin[k] + (0..2).sum { |i| c[i] * size[i] * axes[i][k] } } }
  {index: index, name: name, origin: origin, size: size, axes: axes, scale: scale, locked: locked,
   bounds: {min: (0..2).map { |k| corners.map { |p| p[k] }.min }, max: (0..2).map { |k| corners.map { |p| p[k] }.max }}}
end
def deltas(plan); plan[:moves].map { |m| m[:steps][0][:delta] }; end

one = [make(0, 'Tủ A', [1000.0, 2000.0, 300.0])]
pair = [make(0, 'A', [0.0, 0.0, 0.0]), make(1, 'B', [2000.0, 0.0, 0.0])] # hộp bao chung 0..3000 trên X, tâm X = 1500

# ----- Items -----
ok('tâm cả lựa chọn = tâm hộp bao hình (không phải tâm các điểm gốc)', near(IT.selection_center(pair), [1500.0, 500.0, 500.0]))
ok('tâm một món = tâm hộp bao của món', near(IT.selection_center(one), [1500.0, 2500.0, 800.0]))
ok('tâm theo chế độ: item = điểm gốc, world = (0, 0, 0)', IT.pivot_for(one, 'item', one[0]) == one[0][:origin] && IT.pivot_for(one, 'world', one[0]) == [0.0, 0.0, 0.0])
ok('tâm / hệ trục không hợp lệ bị từ chối', error_of { IT.pivot_for(one, 'abc', one[0]) }.message.include?('Tâm') && error_of { IT.frame(one[0], 'abc') }.message.include?('Hệ trục'))
ok('giá trị chung: trục giống nhau giữ số, khác nhau là nil', IT.common(pair, 0.001) { |i| i[:origin] } == [nil, 0.0, 0.0])
ok('chặn món khóa, món không đo được, lựa chọn rỗng', error_of { IT.check([make(0, 'Tủ khóa', [0.0, 0.0, 0.0], locked: true)]) }.message.include?('Tủ khóa') &&
   error_of { IT.check([{index: 0, name: 'Rỗng', origin: nil, locked: false}]) }.message.include?('Không đo được') && error_of { IT.check([]) }.message.include?('Chưa chọn'))

# ----- Dời tuyệt đối (theo tâm, như 3ds Max) -----
ok('tuyệt đối một món, tâm điểm gốc: chỉ X = 1500, Y và Z giữ', deltas(TR.absolute(one, [1500.0, nil, nil], 'item')) == [[500.0, 0.0, 0.0]])
ok('tuyệt đối nhiều món, tâm điểm gốc: mỗi món tới X = 500 (thẳng hàng)', deltas(TR.absolute(pair, [500.0, nil, nil], 'item')) == [[500.0, 0.0, 0.0], [-1500.0, 0.0, 0.0]])
ok('tuyệt đối, tâm cả lựa chọn: tâm hộp bao (1500) tới X = 0, cả nhóm cùng độ lệch', deltas(TR.absolute(pair, [0.0, nil, nil], 'selection')) == [[-1500.0, 0.0, 0.0], [-1500.0, 0.0, 0.0]])
ok('tuyệt đối, gốc thế giới: dùng tâm cả lựa chọn như selection', deltas(TR.absolute(pair, [0.0, nil, nil], 'world')) == deltas(TR.absolute(pair, [0.0, nil, nil], 'selection')))
ok('tuyệt đối đã đúng chỗ: lỗi "không có gì để làm" (NothingToDo)', error_of { TR.absolute(one, [1000.0, 2000.0, 300.0], 'item') }.is_a?(P::NothingToDo))
ok('tuyệt đối chưa nhập gì: báo hãy nhập', error_of { TR.absolute(one, [nil, nil, nil], 'item') }.message.include?('Hãy nhập'))

# ----- Dời tương đối (World / Local) -----
ok('tương đối thế giới: cùng độ dời (100, 0, -50)', deltas(TR.offset(pair, [100.0, nil, -50.0], 'world')) == [[100.0, 0.0, -50.0]] * 2)
turned = [make(0, 'Tủ xoay', [0.0, 0.0, 0.0], axes: Z90)]
ok('tương đối local: món xoay 90° quanh Z, ΔX riêng 100 = dời Y thế giới 100', near(deltas(TR.offset(turned, [100.0, nil, nil], 'local'))[0], [0.0, 100.0, 0.0]))
ok('tương đối bằng 0: NothingToDo', error_of { TR.offset(one, [0.0, 0.0, 0.0], 'world') }.is_a?(P::NothingToDo))

# ----- Xoay -----
rot = RS.rotate(one, [nil, nil, 90.0], 'world', 'world')
ok('xoay 90° quanh Z, tâm gốc thế giới: (1000, 0, 0) → (0, 1000, 0)', near(ST.apply_steps(rot[:moves][0][:steps], [1000.0, 0.0, 0.0]), [0.0, 1000.0, 0.0]))
ok('xoay quanh điểm gốc của món: điểm gốc đứng yên', near(ST.apply_steps(RS.rotate(one, [nil, nil, 90.0], 'item', 'world')[:moves][0][:steps], one[0][:origin]), one[0][:origin]))
sel = RS.rotate(pair, [nil, nil, 180.0], 'selection', 'world')
ok('xoay 180° quanh tâm hộp bao (1500, 500): A (0,0) → (3000, 1000)', near(ST.apply_steps(sel[:moves][0][:steps], [0.0, 0.0, 0.0]), [3000.0, 1000.0, 0.0]))
ok('xoay local: "quanh X" của món xoay 90° là trục Y thế giới', RS.rotate(turned, [30.0, nil, nil], 'item', 'local')[:moves][0][:steps][0][:axis] == [0.0, 1.0, 0.0])
ok('xoay nhiều trục: thứ tự X, Y, Z', RS.rotate(one, [10.0, 20.0, 30.0], 'world', 'world')[:moves][0][:steps].map { |s| s[:axis] } == W)
ok('xoay: góc 0 là NothingToDo, trống là báo nhập, vượt giới hạn bị từ chối', error_of { RS.rotate(one, [0.0, nil, nil], 'world', 'world') }.is_a?(P::NothingToDo) &&
   error_of { RS.rotate(one, [nil, nil, nil], 'world', 'world') }.message.include?('Hãy nhập') && error_of { RS.rotate(one, [4000.0, nil, nil], 'world', 'world') }.message.include?('vượt giới hạn'))

# ----- Scale tương đối -----
ok('scale ×2 đều quanh gốc thế giới: (1000, 2000, 300) → (2000, 4000, 600)', near(ST.apply_steps(RS.scale(one, [2.0, 2.0, 2.0], 'world', 'world')[:moves][0][:steps], one[0][:origin]), [2000.0, 4000.0, 600.0]))
ok('scale quanh điểm gốc món: điểm gốc đứng yên', near(ST.apply_steps(RS.scale(one, [2.0, 2.0, 2.0], 'item', 'world')[:moves][0][:steps], one[0][:origin]), one[0][:origin]))
local_scale = RS.scale(turned, [2.0, nil, nil], 'item', 'local')[:moves][0][:steps]
ok('scale local: món xoay 90°, ×2 theo X riêng = kéo dài theo Y thế giới', near(ST.apply_steps(local_scale, [0.0, 100.0, 0.0]), [0.0, 200.0, 0.0]) && near(ST.apply_steps(local_scale, [-100.0, 0.0, 0.0]), [-100.0, 0.0, 0.0]))
wide = [make(0, 'Tủ', [0.0, 0.0, 0.0], size: [1000.0, 500.0, 200.0], axes: Z90)]
ok('kích thước đích hệ world đo hộp bao thế giới: X thế giới 500 → 1000 là ×2', RS.scale(wide, [{length: 1000.0}, nil, nil], 'world', 'world')[:moves][0][:steps][0][:factors] == [2.0, 1.0, 1.0])
ok('kích thước đích hệ local đo theo trục riêng: X riêng 1000 → 1500 là ×1.5', RS.scale(wide, [{length: 1500.0}, nil, nil], 'item', 'local')[:moves][0][:steps][0][:factors] == [1.5, 1.0, 1.0])
two = [make(0, 'A', [0.0, 0.0, 0.0]), make(1, 'B', [2000.0, 0.0, 0.0], size: [500.0, 1000.0, 1000.0])]
ok('kích thước đích riêng cho từng món: A giữ 1, B ×2', RS.scale(two, [{length: 1000.0}, nil, nil], 'item', 'world')[:moves].map { |m| m[:steps][0][:factors][0] } == [1.0, 2.0])
ok('scale: hệ số 0 / âm / quá lớn bị từ chối; hệ số 1 là NothingToDo', error_of { RS.scale(one, [0.0, 1.0, 1.0], 'world', 'world') }.message.include?('0,001') &&
   error_of { RS.scale(one, [1001.0, 1.0, 1.0], 'world', 'world') }.message.include?('0,001') && error_of { RS.scale(one, [1.0, 1.0, 1.0], 'world', 'world') }.is_a?(P::NothingToDo))
ok('kích thước đích trên món kích thước 0: báo lỗi', error_of { RS.scale([make(0, 'Phẳng', [0.0, 0.0, 0.0], size: [0.0, 1.0, 1.0])], [{length: 10.0}, nil, nil], 'world', 'world') }.message.include?('Không đo được kích thước'))

# ----- Scale tuyệt đối (local, so với definition) -----
big = [make(0, 'Tủ to', [0.0, 0.0, 0.0], scale: [2.0, 1.0, 1.0])]
ok('scale tuyệt đối: tỉ lệ X đang 2, đặt 1 thì hệ số 0.5 theo trục riêng', RS.absolute_scale(big, [1.0, nil, nil], 'item')[:moves][0][:steps][0][:factors] == [0.5, 1.0, 1.0])
ok('scale tuyệt đối dùng trục riêng của món', RS.absolute_scale([make(0, 'X', [0.0, 0.0, 0.0], axes: Z90, scale: [2.0, 1.0, 1.0])], [1.0, nil, nil], 'item')[:moves][0][:steps][0][:axes] == Z90)
ok('scale tuyệt đối đã đúng tỉ lệ: NothingToDo; chưa nhập: báo nhập', error_of { RS.absolute_scale(big, [2.0, 1.0, 1.0], 'item') }.is_a?(P::NothingToDo) && error_of { RS.absolute_scale(big, [nil, nil, nil], 'item') }.message.include?('Hãy nhập'))

# ----- Công thức scale theo trục bất kỳ -----
ok('scale_point trục thế giới giống công thức cũ', near(ST.scale_point([300.0, 200.0, 100.0], [100.0, 0.0, 0.0], [2.0, 3.0, 0.5], W), [500.0, 600.0, 50.0]))

# ----- Ghép công cụ với ô nhập -----
build = ->(items, payload, unit = 'mm') { PL.build(items, payload, unit) }
ok('Plan move_abs: "1,5" trong file m là 1500 mm, tâm điểm gốc', deltas(build.(one, {'tool' => 'move_abs', 'values' => {'x' => '1,5'}, 'pivot' => 'item'}, 'm')) == [[500.0, 0.0, 0.0]])
ok('Plan move_abs: "2m" trong file mm; thiếu tâm thì mặc định điểm gốc', deltas(build.(one, {'tool' => 'move_abs', 'values' => {'x' => '2m'}})) == [[1000.0, 0.0, 0.0]])
ok('Plan move_off local: ΔX 100 trên món xoay 90° là Y thế giới', near(deltas(build.(turned, {'tool' => 'move_off', 'values' => {'x' => '100'}, 'coord' => 'local'}))[0], [0.0, 100.0, 0.0]))
ok('Plan rotate: ô Z = 90, tâm và hệ trục truyền đúng', (st = build.(one, {'tool' => 'rotate', 'values' => {'z' => '90'}, 'pivot' => 'world', 'coord' => 'world'})[:moves][0][:steps]).size == 1 && st[0][:pivot] == [0.0, 0.0, 0.0])
ok('Plan scale đều: hệ số chung; đơn vị bị từ chối', build.(one, {'tool' => 'scale', 'uniform' => true, 'values' => {'x' => '1.5'}})[:moves][0][:steps][0][:factors] == [1.5, 1.5, 1.5] &&
   error_of { build.(one, {'tool' => 'scale', 'uniform' => true, 'values' => {'x' => '1000mm'}}) }.message.include?('Không đều'))
ok('Plan scale không đều: "2000mm" là kích thước đích, món 1000 mm thành ×2', build.(one, {'tool' => 'scale', 'uniform' => false, 'values' => {'x' => '2000mm'}, 'pivot' => 'world'})[:moves][0][:steps][0][:factors] == [2.0, 1.0, 1.0])
ok('Plan scale_abs: tỉ lệ đích theo ô', build.(big, {'tool' => 'scale_abs', 'values' => {'x' => '1'}})[:moves][0][:steps][0][:factors] == [0.5, 1.0, 1.0])
ok('Plan: công cụ / tâm / hệ trục lạ bị từ chối', error_of { build.(one, {'tool' => 'xoay'}) }.message.include?('Công cụ') &&
   error_of { build.(one, {'tool' => 'move_abs', 'values' => {'x' => '1'}, 'pivot' => 'abc'}) }.message.include?('Tâm') &&
   error_of { build.(one, {'tool' => 'move_off', 'values' => {'x' => '1'}, 'coord' => 'abc'}) }.message.include?('Hệ trục'))
ok('Plan: ô sai định dạng báo lỗi rõ', error_of { build.(one, {'tool' => 'move_off', 'values' => {'x' => 'abc'}}) }.message.include?('không phải số'))

# ----- Xoay tuyệt đối: góc X, Y, Z hiện tại của món (xoay X, rồi Y, rồi Z quanh trục thế giới); gõ 0 là quay về hướng gốc (trục song song trục thế giới) -----
def spin(axes, steps)
  flat = steps.map { |step| step.merge(pivot: [0.0, 0.0, 0.0]) }
  axes.map { |vector| ST.apply_steps(flat, vector) }
end
def axes_after(item, plan); spin(item[:axes], plan[:moves][0][:steps]); end
def same_axes?(a, b, tol = 1e-6); a.zip(b).all? { |u, v| near(u, v, tol) }; end
ok('góc hiện tại: món chưa xoay là 0, 0, 0', near(IT.euler_degrees(W), [0.0, 0.0, 0.0]))
ok('góc hiện tại: món xoay 90° quanh Z là 0, 0, 90', near(IT.euler_degrees(Z90), [0.0, 0.0, 90.0], 1e-6))
spun_axes = spin(W, RS.rotate(one, [30.0, 20.0, 40.0], 'world', 'world')[:moves][0][:steps])
ok('góc hiện tại: xoay (30, 20, 40) bằng công cụ Xoay rồi đọc lại ra đúng (30, 20, 40)', near(IT.euler_degrees(spun_axes), [30.0, 20.0, 40.0], 1e-6))
ok('góc hiện tại ở gimbal lock (quay 90° quanh Y) vẫn ra phép xoay đúng khi dựng lại', (g = IT.euler_degrees(spin(W, [{kind: 'rotate', pivot: [0.0, 0.0, 0.0], axis: [0.0, 1.0, 0.0], degrees: 90.0}]))) && g[1].round(6) == 90.0)
turned_item = make(0, 'Món xoay', [1000.0, 2000.0, 300.0], axes: spun_axes)
back = RS.absolute_rotate([turned_item], [0.0, 0.0, 0.0], 'item')
ok('xoay tuyệt đối 0, 0, 0: món đã xoay (30, 20, 40) trở về hướng gốc', same_axes?(axes_after(turned_item, back), W))
ok('xoay tuyệt đối quanh gốc món: điểm gốc đứng yên', near(ST.apply_steps(back[:moves][0][:steps], turned_item[:origin]), turned_item[:origin]))
only_z = RS.absolute_rotate([make(0, 'X30', [0.0, 0.0, 0.0], axes: spin(W, RS.rotate(one, [30.0, nil, nil], 'world', 'world')[:moves][0][:steps]))], [nil, nil, 45.0], 'item')
ok('xoay tuyệt đối chỉ ô Z: góc X, Y giữ nguyên, Z đổi thành 45', near(IT.euler_degrees(axes_after(make(0, 'X30', [0.0, 0.0, 0.0], axes: spin(W, RS.rotate(one, [30.0, nil, nil], 'world', 'world')[:moves][0][:steps])), only_z)), [30.0, 0.0, 45.0], 1e-6))
z180 = [[-1.0, 0.0, 0.0], [0.0, -1.0, 0.0], [0.0, 0.0, 1.0]]
ok('xoay tuyệt đối 0 cho món đang quay 180° (trường hợp đặc biệt của trục xoay)', same_axes?(axes_after(make(0, 'Z180', [0.0, 0.0, 0.0], axes: z180), RS.absolute_rotate([make(0, 'Z180', [0.0, 0.0, 0.0], axes: z180)], [0.0, 0.0, 0.0], 'item')), W))
mixed = [make(0, 'A', [0.0, 0.0, 0.0], axes: Z90), make(1, 'B', [2000.0, 0.0, 0.0], axes: spun_axes), make(2, 'C', [4000.0, 0.0, 0.0])]
mixed_plan = RS.absolute_rotate(mixed, [0.0, 0.0, 0.0], 'item')
ok('nhiều món đang quay khác nhau: mỗi món về hướng gốc của riêng nó, món đã đúng hướng không có bước nào', mixed.each_with_index.all? { |it, i| same_axes?(spin(it[:axes], mixed_plan[:moves][i][:steps]), W) } && mixed_plan[:moves][2][:steps].empty?)
ok('xoay tuyệt đối khi mọi món đã đúng hướng: NothingToDo', error_of { RS.absolute_rotate([make(0, 'A', [0.0, 0.0, 0.0])], [0.0, 0.0, 0.0], 'item') }.is_a?(P::NothingToDo))
ok('xoay tuyệt đối: để trống mọi ô báo nhập, vượt giới hạn bị từ chối', error_of { RS.absolute_rotate(one, [nil, nil, nil], 'item') }.message.include?('Hãy nhập') && error_of { RS.absolute_rotate(one, [4000.0, nil, nil], 'item') }.message.include?('vượt giới hạn'))
ok('ghép công cụ: rotate_abs đọc ô đã sửa (ô trống giữ), tâm theo lựa chọn', PL.build([turned_item], {'tool' => 'rotate_abs', 'values' => {'x' => '0', 'y' => '0', 'z' => '0'}, 'pivot' => 'item'}, 'mm')[:moves][0][:steps].size.positive? &&
   same_axes?(axes_after(turned_item, PL.build([turned_item], {'tool' => 'rotate_abs', 'values' => {'x' => '0', 'y' => '0', 'z' => '0'}, 'pivot' => 'item'}, 'mm')), W))

puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
