# Test logic thuần của VGD Position (core/position.rb): đọc ô nhập mm, tính độ dời, bỏ món khóa / không đo được.
# Không cần SketchUp. Chạy: ruby dev/test_position.rb (từ plugins/VGD_Position)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_position', __dir__)
require File.join(ROOT, 'core/position')
P = VGD::Position

ok('ô nhập: số nguyên và số thập phân (dấu chấm hoặc phẩy)', P.parse_mm('1200') == 1200.0 && P.parse_mm('1200,5') == 1200.5 && P.parse_mm(' -3.25 ') == -3.25)
ok('ô nhập: trống thì là nil (giữ nguyên trục đó)', P.parse_mm('') .nil? && P.parse_mm(nil).nil?)
ok('ô nhập: chữ, ký hiệu lạ, số mũ bị từ chối', %w[abc 1e3 12a --5 NaN].all? { |t| error_of { P.parse_mm(t) }.to_s.include?('không phải số') })
ok('ô nhập: vượt giới hạn bị từ chối', error_of { P.parse_mm('1000001') }.to_s.include?('vượt giới hạn'))

# Chế độ tuyệt đối (một món): trục để trống giữ nguyên, trục có số thì dời tới đúng số đó
one = [{index: 0, name: 'Tủ A', origin: [1000.0, 2000.0, 300.0], locked: false}]
plan = P.plan(one, 'absolute', {'x' => '1500', 'y' => '', 'z' => nil})
ok('tuyệt đối: chỉ trục X có số thì dời X tới 1500, Y và Z giữ nguyên', plan[:moves] == [{index: 0, delta: [500.0, 0.0, 0.0]}] && plan[:skipped].empty?)
ok('tuyệt đối: đã đúng vị trí thì không có món nào cần dời', (error_of { P.plan(one, 'absolute', {'x' => '1000', 'y' => '2000', 'z' => '300'}) }).to_s.include?('Không có món nào cần dời'))
ok('tuyệt đối: nhiều món bị từ chối (chỉ dùng khi chọn đúng một món)', error_of { P.plan([one[0], one[0].merge(index: 1)], 'absolute', {'x' => '1'}) }.to_s.include?('đúng một món'))

# Chế độ tương đối (nhiều món): cùng độ dời cho mọi món; trục để trống là 0
many = [
  {index: 0, name: 'Tủ A', origin: [0.0, 0.0, 0.0], locked: false},
  {index: 1, name: 'Tủ B', origin: [500.0, 0.0, 0.0], locked: false},
]
plan = P.plan(many, 'relative', {'x' => '100', 'y' => '', 'z' => '-50'})
ok('tương đối: cùng độ dời (100, 0, -50) cho mọi món', plan[:moves].map { |m| m[:delta] } == [[100.0, 0.0, -50.0], [100.0, 0.0, -50.0]])

# Món khóa và món không đo được vị trí: bỏ qua có lý do, không làm hỏng cả lần dời
mixed = [
  {index: 0, name: 'Tủ A', origin: [0.0, 0.0, 0.0], locked: false},
  {index: 1, name: 'Tủ khóa', origin: [0.0, 0.0, 0.0], locked: true},
  {index: 2, name: 'Rỗng', origin: nil, locked: false},
]
plan = P.plan(mixed, 'relative', {'x' => '10'})
ok('món khóa và món không đo được: bỏ qua, ghi lý do', plan[:moves].map { |m| m[:index] } == [0] && plan[:skipped].map { |s| [s[:index], s[:reason]] } == [[1, 'đang khóa'], [2, 'không đo được vị trí']])

# Sai dữ liệu: chưa nhập số nào thì báo rõ
ok('chưa nhập tọa độ nào: báo lỗi, không dời', error_of { P.plan(many, 'relative', {'x' => '', 'y' => '', 'z' => ''}) }.to_s.include?('Hãy nhập'))
ok('chế độ lạ bị từ chối', error_of { P.plan(many, 'xoay', {'x' => '1'}) }.to_s.include?('Chế độ'))
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
