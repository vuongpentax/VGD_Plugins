# Test logic thuần của VGD Transform: dời (tuyệt đối, tương đối), xoay và scale theo trục thế giới, tâm xoay / scale,
# ghép công cụ với ô nhập (core/plan.rb), mô tả xem trước. Không cần SketchUp.
# Chạy: ruby dev/test_transform.rb (từ plugins/VGD_Transform)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
def near(a, b, tol = 1e-6); a.zip(b).all? { |x, y| (x - y).abs < tol }; end
ROOT = File.expand_path('../runtime/vgd_transform', __dir__)
%w[core/units core/translate core/steps core/rotate_scale core/plan].each { |f| require File.join(ROOT, f) }
P = VGD::Transform
TR = P::Translate
RS = P::RotateScale
ST = P::Steps
PL = P::Plan

one = [{index: 0, name: 'Tủ A', origin: [1000.0, 2000.0, 300.0], locked: false}]
many = [
  {index: 0, name: 'Tủ A', origin: [0.0, 0.0, 0.0], locked: false},
  {index: 1, name: 'Tủ B', origin: [1000.0, 0.0, 0.0], locked: false},
]

# Tuyệt đối: điểm gốc món đầu tiên tới đúng tọa độ; trục nil giữ nguyên
ok('tuyệt đối một món: chỉ X có số thì dời X tới 1500, Y và Z giữ nguyên', TR.absolute(one, [1500.0, nil, nil])[:moves] == [{index: 0, steps: [{kind: 'translate', delta: [500.0, 0.0, 0.0]}]}])
ok('tuyệt đối: đã đúng vị trí thì báo không cần dời', error_of { TR.absolute(one, [1000.0, 2000.0, 300.0]) }.to_s.include?('không cần dời'))
ok('tuyệt đối nhiều món: độ lệch tính từ món đầu, mọi món cùng độ lệch', TR.absolute(many, [600.0, nil, nil])[:moves].map { |m| m[:steps][0][:delta] } == [[600.0, 0.0, 0.0], [600.0, 0.0, 0.0]])

# Tương đối: mỗi món dời cùng độ dời; ô trống là 0
ok('tương đối: cùng độ dời (100, 0, -50) cho mọi món', TR.offset(many, [100.0, nil, -50.0])[:moves].map { |m| m[:steps][0][:delta] } == [[100.0, 0.0, -50.0], [100.0, 0.0, -50.0]])
ok('tương đối: độ dời bằng 0 thì báo không cần dời', error_of { TR.offset(many, [0.0, 0.0, 0.0]) }.to_s.include?('không cần dời'))

# Chặn: món khóa, không đo được vị trí, chưa chọn món
locked = [{index: 0, name: 'Tủ A', origin: [0.0, 0.0, 0.0], locked: false}, {index: 1, name: 'Tủ khóa', origin: [0.0, 0.0, 0.0], locked: true}]
ok('có món khóa trong lựa chọn: không dời gì, báo tên món khóa', (err = error_of { TR.absolute(locked, [10.0, nil, nil]) }).to_s.include?('Tủ khóa') && err.include?('khóa'))
ok('món không đo được vị trí: báo lỗi', error_of { TR.offset([{index: 0, name: 'Rỗng', origin: nil, locked: false}], [10.0, nil, nil]) }.to_s.include?('Không đo được'))
ok('chưa chọn món nào: báo lỗi', error_of { TR.absolute([], [1.0, nil, nil]) }.to_s.include?('Chưa chọn'))
ok('chưa nhập gì: báo lỗi', error_of { TR.offset(many, [nil, nil, nil]) }.to_s.include?('Hãy nhập'))

# Xoay: quanh trục thế giới, quanh tâm chọn được
rot_world = RS.rotate(one, [nil, nil, 90.0], 'world')
ok('xoay 90° quanh Z, tâm gốc thế giới: điểm (1000, 0, 0) → (0, 1000, 0)', near(ST.apply_steps(rot_world[:moves][0][:steps], [1000.0, 0.0, 0.0]), [0.0, 1000.0, 0.0]))
ok('xoay quanh điểm gốc của món: điểm gốc món đứng yên', near(ST.apply_steps(RS.rotate(one, [nil, nil, 90.0], 'item')[:moves][0][:steps], one[0][:origin]), one[0][:origin]))
rot_sel = RS.rotate(many, [nil, nil, 180.0], 'selection')
ok('xoay 180° quanh Z, tâm cả lựa chọn (500, 0, 0): hai món đổi chỗ', near(ST.apply_steps(rot_sel[:moves][0][:steps], many[0][:origin]), [1000.0, 0.0, 0.0]) && near(ST.apply_steps(rot_sel[:moves][1][:steps], many[1][:origin]), [0.0, 0.0, 0.0]))
ok('xoay nhiều trục: áp dụng theo thứ tự X rồi Y rồi Z (3 bước)', RS.rotate(one, [90.0, 90.0, 90.0], 'world')[:moves][0][:steps].map { |s| s[:axis].index(1.0) } == [0, 1, 2])
ok('xoay: góc bằng 0 hoặc trống ở mọi trục: báo lỗi', error_of { RS.rotate(one, [nil, 0.0, nil], 'world') }.to_s.include?('ít nhất một góc'))
ok('xoay: góc vượt ±3600° bị từ chối', error_of { RS.rotate(one, [4000.0, nil, nil], 'world') }.to_s.include?('vượt giới hạn'))
ok('tâm xoay không hợp lệ bị từ chối', error_of { RS.rotate(one, [nil, nil, 90.0], 'abc') }.to_s.include?('Tâm xoay'))

# Scale: đều và không đều, quanh tâm chọn được
sc_uniform = RS.scale(one, [2.0, 2.0, 2.0], 'world')
ok('scale đều ×2 quanh gốc thế giới: (1000, 2000, 300) → (2000, 4000, 600)', near(ST.apply_steps(sc_uniform[:moves][0][:steps], one[0][:origin]), [2000.0, 4000.0, 600.0]))
ok('scale quanh điểm gốc của món: điểm gốc đứng yên', near(ST.apply_steps(RS.scale(one, [2.0, 2.0, 2.0], 'item')[:moves][0][:steps], one[0][:origin]), one[0][:origin]))
ok('scale không đều [2, 1, 0.5] quanh gốc: (1000, 1000, 1000) → (2000, 1000, 500)', near(ST.apply_steps(RS.scale(one, [2.0, 1.0, 0.5], 'world')[:moves][0][:steps], [1000.0, 1000.0, 1000.0]), [2000.0, 1000.0, 500.0]))
ok('scale ×2 quanh tâm cả lựa chọn (500, 0, 0): món (1000, 0, 0) → (1500, 0, 0)', near(ST.apply_steps(RS.scale(many, [2.0, 2.0, 2.0], 'selection')[:moves][1][:steps], many[1][:origin]), [1500.0, 0.0, 0.0]))
ok('scale: hệ số 0 hoặc âm bị từ chối', error_of { RS.scale(one, [0.0, 1.0, 1.0], 'world') }.to_s.include?('0,001') && error_of { RS.scale(one, [-2.0, 1.0, 1.0], 'world') }.to_s.include?('0,001'))
ok('scale: hệ số 1 ở mọi trục bị báo không đổi', error_of { RS.scale(one, [1.0, 1.0, 1.0], 'world') }.to_s.include?('không đổi'))
ok('scale: hệ số quá lớn bị từ chối', error_of { RS.scale(one, [1001.0, 1.0, 1.0], 'world') }.to_s.include?('0,001'))

# Ghép công cụ với ô nhập (đơn vị của file)
ok('Plan move_abs: "1,5" trong file m là 1500 mm, từ x=1000 nên dời 500 mm', PL.build(one, {'tool' => 'move_abs', 'values' => {'x' => '1,5', 'y' => '', 'z' => ''}}, 'm')[:moves][0][:steps][0][:delta] == [500.0, 0.0, 0.0])
ok('Plan move_abs: "2m" trong file mm là 2000 mm, từ x=1000 nên dời 1000 mm', PL.build(one, {'tool' => 'move_abs', 'values' => {'x' => '2m', 'y' => '', 'z' => ''}}, 'mm')[:moves][0][:steps][0][:delta] == [1000.0, 0.0, 0.0])
ok('Plan move_off: "250" trong file mm là dời 250 mm theo X', PL.build(one, {'tool' => 'move_off', 'values' => {'x' => '250', 'y' => '', 'z' => ''}}, 'mm')[:moves][0][:steps][0][:delta] == [250.0, 0.0, 0.0])
ok('Plan rotate: ô Z = 90, tâm gốc thế giới', (steps = PL.build(one, {'tool' => 'rotate', 'values' => {'x' => '', 'y' => '', 'z' => '90'}, 'pivot' => 'world'}, 'mm')[:moves][0][:steps]).size == 1 && steps[0][:degrees] == 90.0)
ok('Plan scale đều: ô X = 2 là hệ số chung cho ba trục', PL.build(one, {'tool' => 'scale', 'uniform' => true, 'values' => {'x' => '2', 'y' => '9', 'z' => '9'}, 'pivot' => 'world'}, 'mm')[:moves][0][:steps][0][:factors] == [2.0, 2.0, 2.0])
ok('Plan scale không đều: ô trống là 1, ô 3 là 3', PL.build(one, {'tool' => 'scale', 'uniform' => false, 'values' => {'x' => '2', 'y' => '', 'z' => '3'}, 'pivot' => 'world'}, 'mm')[:moves][0][:steps][0][:factors] == [2.0, 1.0, 3.0])
ok('Plan scale đều: ô trống báo lỗi', error_of { PL.build(one, {'tool' => 'scale', 'uniform' => true, 'values' => {'x' => ''}, 'pivot' => 'world'}, 'mm') }.to_s.include?('hệ số'))
ok('Plan: công cụ lạ bị từ chối', error_of { PL.build(one, {'tool' => 'xoay', 'values' => {}}, 'mm') }.to_s.include?('Công cụ'))
ok('Plan: ô sai định dạng báo lỗi rõ', error_of { PL.build(one, {'tool' => 'move_off', 'values' => {'x' => 'abc'}}, 'mm') }.to_s.include?('không phải số'))

# Mô tả xem trước: theo đơn vị của file
desc = PL.describe(one[0], TR.absolute(one, [1500.0, nil, nil])[:moves][0][:steps], 'm')
ok('mô tả: dời ΔX 0.5 m và điểm gốc mới 1.5 m (file m)', desc.include?('ΔX 0.5 m') && desc.include?('(1.5 m, 2 m, 0.3 m)'))
ok('mô tả: xoay và scale ghi rõ số', PL.describe(one[0], rot_world[:moves][0][:steps], 'mm').include?('xoay 90° quanh Z') && PL.describe(one[0], sc_uniform[:moves][0][:steps], 'mm').include?('scale ×2'))

puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
