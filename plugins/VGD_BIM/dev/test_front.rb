# Test logic chọn mặt trước (core/front.rb): bằng chứng tường, chi tiết hình học, độ tin cậy, lưu / đọc ở định nghĩa, đổi hướng.
# Dữ liệu đo (mặt, khoảng thoáng) được dựng giả; phần đo thật bằng raytest trong SketchUp (FrontProbe) chưa kiểm được ngoài SketchUp.
# Chạy: ruby dev/test_front.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
module VGD; module BIM; def self.log(_m); end; end; end
require File.join(ROOT, 'core/front')
F = VGD::BIM::Front

SIZE = [1200.0, 600.0, 2000.0].freeze # rộng X, sâu Y, cao Z (mm)
# Mặt hướng ra phía dir, nằm sát mép khung bao theo hướng đó (đếm là chi tiết của mặt đó).
def face_at(dir, offset_from_edge: 5.0, area: 1000.0)
  vx, vy = F::VECTORS[dir]
  c = [SIZE[0] / 2, SIZE[1] / 2, 1000.0]
  c[0] = vx > 0 ? SIZE[0] - offset_from_edge : offset_from_edge if vx != 0
  c[1] = vy > 0 ? SIZE[1] - offset_from_edge : offset_from_edge if vy != 0
  {n: [vx, vy, 0.0], c: c, a: area}
end
def faces_for(counts); counts.flat_map { |dir, n| Array.new(n) { face_at(dir) } }; end
FREE_ALL = {'+x' => 3000.0, '-x' => 3000.0, '+y' => 3000.0, '-y' => 3000.0}.freeze

# ---- Hướng và đổi hướng ----
ok('hướng đối diện', F.opposite('+x') == '-x' && F.opposite('-y') == '+y')
ok('quay 90° ngược chiều kim đồng hồ đủ vòng 4 lần về chỗ cũ', F::DIRECTIONS.all? { |d| x = d; 4.times { x = F.turn(x) }; x == d } && F.turn('+x') == '+y' && F.turn('+y') == '-x')
ok('hợp lệ: chỉ bốn hướng ngang', F.valid?('+y') && !F.valid?('+z') && !F.valid?(nil) && !F.valid?('x'))
# Món xoay 90° quanh Z: trục X cục bộ = +Y thế giới, trục Y cục bộ = -X thế giới
xaxis = [0.0, 1.0, 0.0]; yaxis = [-1.0, 0.0, 0.0]
ok('hướng thế giới +Y ứng với +x cục bộ của món đã xoay 90°', F.local_direction([0.0, 1.0, 0.0], xaxis, yaxis) == '+x')
ok('hướng thế giới -X ứng với +y cục bộ', F.local_direction([-1.0, 0.0, 0.0], xaxis, yaxis) == '+y')
ok('vector thế giới của +y cục bộ khớp ngược lại', F.world_vector('+y', xaxis, yaxis) == [-1.0, 0.0, 0.0])
ok('trục có tỉ lệ (scale) vẫn đúng hướng', F.local_direction([0.0, 5.0, 0.0], [0.0, 3.0, 0.0], [-3.0, 0.0, 0.0]) == '+x')
ok('vector thẳng đứng (không có thành phần ngang) thì không có hướng', F.local_direction([0.0, 0.0, 1.0], [1.0, 0.0, 0.0], [0.0, 1.0, 0.0]).nil?)

# ---- Chọn mặt trước ----
r = F.analyze(faces: faces_for('+y' => 12, '-y' => 1, '+x' => 1, '-x' => 1), size: SIZE, free: FREE_ALL.merge('-y' => 40.0))
ok('tủ sát tường phía -y, chi tiết nhiều ở +y: mặt trước +y, tin cậy cao', r[:dir] == '+y' && r[:confidence] == 'high')
r = F.analyze(faces: faces_for('+y' => 12, '-y' => 1, '+x' => 1, '-x' => 1), size: SIZE, free: FREE_ALL.merge('-y' => 40.0, '+y' => 100.0))
ok('mặt đối diện chỉ thoáng hơn mức tối thiểu 400 mm thì không kết luận bằng tường', r[:notes].none? { |n| n.include?('sát tường') })
r = F.analyze(faces: faces_for('+x' => 2, '-x' => 2), size: SIZE, free: FREE_ALL.merge('-x' => 60.0))
ok('chỉ có bằng chứng tường (hình học yếu): mặt trước theo tường, tin cậy trung bình', r[:dir] == '+x' && r[:confidence] == 'medium' && r[:notes].any? { |n| n.include?('sát tường') })
r = F.analyze(faces: faces_for('-x' => 12, '+x' => 1), size: SIZE, free: FREE_ALL)
ok('đồ ở giữa: hình học mạnh (12 so với 1) chọn -x, tin cậy trung bình (không có tường xác nhận)', r[:dir] == '-x' && r[:confidence] == 'medium')
r = F.analyze(faces: faces_for('+y' => 6, '-y' => 4), size: SIZE, free: FREE_ALL)
ok('hình học yếu (6 so với 4, đúng ngưỡng 1,5 lần): chọn nhưng chỉ tin cậy thấp', r[:dir] == '+y' && r[:confidence] == 'low')
r = F.analyze(faces: faces_for('+y' => 5, '-y' => 4), size: SIZE, free: FREE_ALL)
ok('hai mặt gần bằng nhau: không chọn, cần duyệt', r[:dir].nil? && r[:confidence] == 'low' && r[:notes].any? { |n| n.include?('duyệt') })
r = F.analyze(faces: faces_for('-y' => 12, '+y' => 1), size: SIZE, free: FREE_ALL.merge('-y' => 3000.0, '+y' => 50.0))
ok('tường sát +y, hình học nhiều chi tiết ở -y: trùng nhau ra -y, tin cậy cao', r[:dir] == '-y' && r[:confidence] == 'high')
r = F.analyze(faces: faces_for('+y' => 12, '-y' => 1), size: SIZE, free: FREE_ALL.merge('+y' => 50.0))
ok('mâu thuẫn: tường nói -y, hình học nói +y: chọn theo tường, tin cậy thấp kèm ghi chú duyệt', r[:dir] == '-y' && r[:confidence] == 'low' && r[:notes].any? { |n| n.include?('cần duyệt') })
corner = FREE_ALL.merge('-y' => 30.0, '-x' => 40.0)
r = F.analyze(faces: faces_for('+x' => 14, '+y' => 2, '-y' => 1, '-x' => 1), size: SIZE, free: corner)
ok('góc tường (sát -y và -x): chỉ xét +x, +y; hình học mạnh chọn +x, tin cậy cao', r[:dir] == '+x' && r[:confidence] == 'high' && r[:notes].any? { |n| n.include?('góc tường') })
r = F.analyze(faces: faces_for('-x' => 14, '+y' => 2), size: SIZE, free: corner)
ok('góc tường: mặt nhiều chi tiết nằm ở phía tường (-x) thì bị loại, không chọn sai về tường', r[:dir] != '-x')
between = FREE_ALL.merge('-y' => 20.0, '+y' => 30.0)
r = F.analyze(faces: faces_for('+x' => 12, '-x' => 1), size: SIZE, free: between)
ok('kẹp giữa hai tường đối diện: bỏ bằng chứng tường, dùng hình học', r[:dir] == '+x' && r[:notes].any? { |n| n.include?('kẹp giữa') })
r = F.analyze(faces: faces_for('+y' => 12, '-y' => 1), size: SIZE, free: nil)
ok('không đo được tia (free nil): vẫn dùng hình học', r[:dir] == '+y' && r[:confidence] == 'medium')
r = F.analyze(faces: [], size: SIZE, free: FREE_ALL)
ok('không có mặt nào và không có tường: chưa chọn, tin cậy thấp', r[:dir].nil? && r[:confidence] == 'low')
r = F.analyze(faces: faces_for('+y' => 12), size: SIZE, free: FREE_ALL, upright: false)
ok('món không đứng thẳng: không chọn, ghi lý do', r[:dir].nil? && r[:notes].any? { |n| n.include?('không đứng thẳng') })
slanted = Array.new(10) { {n: [0.7071, 0.7071, 0.0], c: [1195.0, 595.0, 1000.0], a: 1000.0} } # mặt chéo 45°
r = F.analyze(faces: faces_for('+y' => 3) + slanted, size: SIZE, free: FREE_ALL.merge('-y' => 30.0))
ok('món lệch góc (đa số mặt đứng không song song trục): luôn tin cậy thấp và ghi chú', r[:confidence] == 'low' && r[:aligned] < F::ALIGNED_MIN && r[:notes].any? { |n| n.include?('lệch góc') })
r = F.analyze(faces: faces_for('+y' => 12, '-y' => 1), size: SIZE, free: FREE_ALL.merge('-y' => 40.0), mirrored: true)
ok('món lật gương hoặc component động: không bao giờ tin cậy cao', r[:confidence] == 'low' && F.analyze(faces: faces_for('+y' => 12, '-y' => 1), size: SIZE, free: FREE_ALL.merge('-y' => 40.0), dynamic: true)[:confidence] == 'low')
r = F.analyze(faces: [face_at('+y', offset_from_edge: 400.0)] * 10, size: SIZE, free: FREE_ALL)
ok('mặt nằm sâu bên trong (ngoài lớp ngoài cùng) không tính là chi tiết của mặt đó', r[:detail]['+y'] == 0)
ok('mặt nghiêng hơn 31° so với hướng ra không tính', F.detail_counts([{n: [0.0, 0.8, 0.6], c: [600.0, 595.0, 1000.0], a: 100.0}], SIZE)['+y'] == 0)

# ---- Lưu / đọc ở định nghĩa ----
class FakeDefinition
  def initialize; @attrs = {}; end
  def get_attribute(dict, key, default = nil); @attrs.dig(dict, key) || default; end
  def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; end
  def delete_attribute(dict, key); @attrs[dict]&.delete(key); end
end
d = FakeDefinition.new
ok('chưa lưu: đọc ra rỗng', F.read(d)[:dir].nil? && F.state_label(F.read(d)) == '')
F.write(d, '+y', source: 'auto', confidence: 'medium', note: 'sát tường phía -y')
info = F.read(d)
ok('ghi rồi đọc lại đủ hướng, nguồn, độ tin cậy, ghi chú', info == {dir: '+y', source: 'auto', confidence: 'medium', note: 'sát tường phía -y'} && F.state_label(info) == 'Tự động · trung bình' && F.label('+y') == '+Y')
F.write(d, '-x')
ok('thủ công mặc định tin cậy cao, nhãn "Thủ công", xóa ghi chú cũ', F.read(d)[:source] == 'manual' && F.read(d)[:confidence] == 'high' && F.state_label(F.read(d)) == 'Thủ công' && F.read(d)[:note] == '')
ok('tự động tin cậy thấp: nhãn "Cần duyệt"', (F.write(d, '+x', source: 'auto', confidence: 'low'); F.state_label(F.read(d)) == 'Cần duyệt'))
[['z', 'manual', 'high'], ['+x', 'xx', 'high'], ['+x', 'manual', 'tốt']].each do |dir, src, conf|
  before = F.read(d)
  err = begin; F.write(d, dir, source: src, confidence: conf); nil; rescue ArgumentError => e; e.message; end
  ok("giá trị sai bị từ chối, không đổi dữ liệu cũ: #{dir} #{src} #{conf}", err && F.read(d) == before)
end
F.write(d, '+y', note: 'x' * 500)
ok('ghi chú quá dài bị cắt 300 ký tự', F.read(d)[:note].length == 300)
d.set_attribute(F::DICTIONARY, 'front', 'rác'); d.set_attribute(F::DICTIONARY, 'front_confidence', 'lạ'); d.set_attribute(F::DICTIONARY, 'front_source', 'lạ')
ok('file sửa tay giá trị rác: hướng không hợp lệ coi như chưa có', F.read(d)[:dir].nil?)
d.set_attribute(F::DICTIONARY, 'front', '-y')
ok('nguồn và độ tin cậy rác nhưng hướng đúng: coi là thủ công, thấp (an toàn, buộc duyệt)', F.read(d)[:dir] == '-y' && F.read(d)[:source] == 'manual' && F.read(d)[:confidence] == 'low')
F.clear(d)
ok('xóa sạch mọi khóa', F.read(d)[:dir].nil? && d.get_attribute(F::DICTIONARY, 'front_source').nil?)
ok('đọc từ đối tượng không có get_attribute: rỗng, không lỗi', F.read(Object.new)[:dir].nil?)

puts $fails.zero? ? 'Done' : "#{$fails} lỗi"
exit($fails.zero? ? 0 : 1)
