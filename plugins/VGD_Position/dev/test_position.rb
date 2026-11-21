# Test logic thuần của VGD Position (core/position.rb): đọc ô nhập mm, tính độ dời, chặn món khóa / không đo được.
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

# Một món: điểm gốc tới đúng X, Y, Z đã nhập; trục để trống thì giữ nguyên
one = [{index: 0, name: 'Tủ A', origin: [1000.0, 2000.0, 300.0], locked: false}]
plan = P.plan(one, {'x' => '1500', 'y' => '', 'z' => nil})
ok('một món: chỉ X có số thì dời X tới 1500, Y và Z giữ nguyên', plan[:moves] == [{index: 0, delta: [500.0, 0.0, 0.0]}])
ok('một món: đã đúng vị trí thì báo không cần dời', error_of { P.plan(one, {'x' => '1000', 'y' => '2000', 'z' => '300'}) }.to_s.include?('không cần dời'))

# Nhiều món: cả nhóm dời cùng độ lệch; độ lệch tính từ điểm gốc của món đầu tiên trong lựa chọn
many = [
  {index: 0, name: 'Tủ A', origin: [0.0, 0.0, 0.0], locked: false},
  {index: 1, name: 'Tủ B', origin: [500.0, 0.0, 0.0], locked: false},
]
plan = P.plan(many, {'x' => '100', 'y' => '', 'z' => '-50'})
ok('nhiều món: cùng độ lệch (100, 0, -50) cho mọi món, tính từ món đầu tiên', plan[:moves] == [{index: 0, delta: [100.0, 0.0, -50.0]}, {index: 1, delta: [100.0, 0.0, -50.0]}])
plan = P.plan(many, {'x' => '600', 'y' => '', 'z' => ''})
ok('nhiều món: X = 600 đưa điểm gốc món đầu tiên tới 600, món thứ hai cùng lệch 600', plan[:moves].map { |m| m[:delta][0] } == [600.0, 600.0])

# Chặn: món khóa, món không đo được vị trí, món đầu đã đúng chỗ
locked = [
  {index: 0, name: 'Tủ A', origin: [0.0, 0.0, 0.0], locked: false},
  {index: 1, name: 'Tủ khóa', origin: [0.0, 0.0, 0.0], locked: true},
]
ok('có món khóa trong lựa chọn: không dời gì, báo tên món khóa', (err = error_of { P.plan(locked, {'x' => '10'}) }).to_s.include?('Tủ khóa') && err.include?('khóa'))
ok('một món đang khóa: không dời, báo khóa', error_of { P.plan([locked[1]], {'x' => '10'}) }.to_s.include?('khóa'))
ok('món không đo được vị trí: không dời, báo lỗi', error_of { P.plan([{index: 0, name: 'Rỗng', origin: nil, locked: false}], {'x' => '10'}) }.to_s.include?('Không đo được'))
ok('món đầu tiên đã ở vị trí đó: không dời, báo không cần dời', error_of { P.plan(many, {'x' => '0', 'y' => '0', 'z' => '0'}) }.to_s.include?('không cần dời'))

# Sai dữ liệu: chưa nhập số nào, chưa chọn món
ok('chưa nhập tọa độ nào: báo lỗi, không dời', error_of { P.plan(many, {'x' => '', 'y' => '', 'z' => ''}) }.to_s.include?('Hãy nhập'))
ok('chưa chọn món nào: báo lỗi', error_of { P.plan([], {'x' => '1'}) }.to_s.include?('Chưa chọn'))
ok('chế độ không còn: chỉ nhận ô X, Y, Z', P.method(:plan).arity == 2)
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
