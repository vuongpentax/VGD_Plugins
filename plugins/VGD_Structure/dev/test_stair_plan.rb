# Test kế hoạch cầu thang thẳng một vế (core/stair_plan.rb) và loại cầu thang (core/stair_types.rb): số bậc theo cao tầng, bản bậc tối thiểu,
# bậc đỉnh đúng cao tầng, lan can hai bên và cột, dữ liệu sai bị từ chối. Logic thuần, không cần SketchUp. Chạy: ruby dev/test_stair_plan.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
module VGD; module Structure; end; end
require_relative '../runtime/vgd_structure/core/stair_types'
require_relative '../runtime/vgd_structure/core/stair_plan'
ST = VGD::Structure::StairTypes
SP = VGD::Structure::StairPlan
TYPE = ST.default[0]   # 1000 mm, bậc tối đa 175, bản tối thiểu 260, lan can 900

ok('loại mặc định hợp lệ và chuẩn hóa giữ nguyên số', ST.normalize!(ST.default) == ST.default)
ok('loại: bề rộng vế ngoài khoảng 600..2000 bị từ chối', !error_of { ST.normalize!([TYPE.merge('width' => 300)]) }.nil?)
ok('loại: tên trùng (không phân biệt hoa thường) bị từ chối', !error_of { ST.normalize!([TYPE, TYPE.merge('id' => 'sj_00000002', 'name' => 'cầu thang 1000')]) }.nil?)
ok('loại: mã sai kiểu bị từ chối', !error_of { ST.normalize!([TYPE.merge('id' => 'x')]) }.nil?)

# Vế dài 6000 mm theo trục X, từ (0,0) lên (6000,0); cao tầng 3600 mm.
p = SP.plan([0, 0], [6000, 0], TYPE, 0, 3600)
ok('số bậc = ceil(3600 / 175) = 21, cao bậc 171,43 (đều, không vượt mức tối đa)', p[:count] == 21 && (p[:riser] - 3600.0 / 21).abs < 0.01 && p[:riser] <= TYPE['riser'])
ok('bản bậc = 6000 / 21 = 285,7 mm (không nhỏ hơn 260)', (p[:tread] - 6000.0 / 21).abs < 0.1)
ok('có đúng 21 bậc, mỗi bậc là 4 đỉnh', p[:steps].size == 21 && p[:steps].all? { |s| s[:poly].size == 4 })
ok('bậc thấp nhất: đáy ở cao độ tầng dưới (0), mặt bậc = cao bậc (làm tròn 0,1 mm)', p[:steps][0][:z0] == 0.0 && (p[:steps][0][:z1] - p[:riser]).abs <= 0.1)
ok('bậc cao nhất: mặt bậc đúng bằng cao tầng 3600', (p[:steps].last[:z1] - 3600.0).abs < 0.01)
ok('bậc có bề rộng vế 1000 mm (nằm lệch ±500 quanh đường tâm)', p[:steps][5][:poly].map { |x, y| y }.minmax == [-500.0, 500.0])
ok('khung chân cầu thang: 4 đỉnh, dài 6000 và rộng 1000', p[:footprint].size == 4 && p[:footprint].map(&:first).minmax == [0.0, 6000.0] && p[:footprint].map(&:last).minmax == [-500.0, 500.0])

# Lan can hai bên: tay vịn cao 900 mm trên mặt bậc; bên trái có y dương (phía trái a -> b).
hr = p[:rails].select { |r| r[:kind] == 'handrail' }
ok('có đúng 2 tay vịn (trái, phải)', hr.size == 2 && hr.map { |r| r[:side] }.sort == %w[left right])
left = hr.find { |r| r[:side] == 'left' }
ok('tay vịn bên trái nằm ở y = +500 (phía trái của hướng đi)', left[:from][1] == 500.0 && left[:to][1] == 500.0)
ok('tay vịn đầu dưới: cao = mặt bậc đầu (riser) + 900; đầu trên: cao = 3600 + 900', (left[:from][2] - (p[:riser] + 900)).abs < 0.05 && (left[:to][2] - 4500).abs < 0.01)
posts = p[:rails].select { |r| r[:kind] == 'post' && r[:side] == 'left' }
ok('cột lan can mỗi 1000 mm: 7 cột (0, 1000, ... 6000) và cột đầu đứng từ mặt bậc lên 900', posts.size == 7 && (posts.last[:to][2] - posts.last[:from][2] - 900).abs < 0.01)
ok('chỉ một bên khi chọn sides = [left]: không có tay vịn bên phải', SP.plan([0, 0], [6000, 0], TYPE, 0, 3600, %w[left])[:rails].none? { |r| r[:side] == 'right' })
ok('không chọn lan can: không có chi tiết lan can', SP.plan([0, 0], [6000, 0], TYPE, 0, 3600, [])[:rails].empty?)

# Cầu thang chéo: hướng theo a -> b, số bậc và bản bậc không đổi theo phương
d = 6000.0 / Math.sqrt(2)
q = SP.plan([0, 0], [d, d], TYPE, 0, 3600)
ok('vế chéo 45 độ dài 6000 mm: cùng số bậc 21 và chiều dài 6000 (sai số 0,1 mm)', q[:count] == 21 && (q[:run] - 6000.0).abs <= 0.1)

# Lỗi: vế quá ngắn, cao quá thấp, bản bậc quá nhỏ, điểm sai, phía lan can sai
ok('vế dưới 600 mm: từ chối', !error_of { SP.plan([0, 0], [400, 0], TYPE, 0, 3600) }.nil?)
ok('cao dưới 120 mm: từ chối (không phải cầu thang)', !error_of { SP.plan([0, 0], [6000, 0], TYPE, 0, 100) }.nil?)
ok('bản bậc dưới mức tối thiểu (vế 4000 cho 21 bậc = 190 mm): từ chối', !error_of { SP.plan([0, 0], [4000, 0], TYPE, 0, 3600) }.nil?)
ok('điểm không phải số: từ chối', !error_of { SP.plan(['x', 0], [6000, 0], TYPE, 0, 3600) }.nil?)
ok('phía lan can không hợp lệ: từ chối', !error_of { SP.plan([0, 0], [6000, 0], TYPE, 0, 3600, %w[top]) }.nil?)
# ---- Chữ L và chữ U có chiếu nghỉ ----
L = SP.plan([0, 0], [2500, 4000], TYPE, 0, 3600, [], shape: 'L', mid: [3000, 0])
ok('L: 21 bậc chia 11 (vế 1) + 10 (vế 2), có đúng 1 chiếu nghỉ, tổng 22 khối', L[:count] == 21 && L[:steps].size == 22 && L[:steps].count { |x| x[:landing] } == 1)
land = L[:steps].find { |x| x[:landing] }
ok('L: chiếu nghỉ vuông (cạnh 1000) đặt sau vế 1 (x 3000..4000, y -500..500), mặt trên đúng cao 11 bậc', land[:poly].map(&:first).minmax == [3000.0, 4000.0] && land[:poly].map(&:last).minmax == [-500.0, 500.0] && (land[:z1] - 11 * L[:riser]).abs < 0.2)
ok('L: vế 2 rẽ về phía trái (y dương), dài 3500 (4000 - 500), tới đỉnh 3600', L[:run2] == 3500.0 && L[:footprint].map(&:last).max == 4000.0)
top = L[:steps].max_by { |x| x[:z1] }
ok('L: bậc cao nhất (cuối vế 2) đỉnh đúng 3600 mm và nằm trong x 3000..4000', (top[:z1] - 3600).abs < 0.2 && top[:poly].map(&:first).min >= 2999.0)
ok('L: bản bậc hai vế đều không nhỏ hơn 260 (vế 1: 272,7; vế 2: 350)', L[:tread] >= 260.0)
Lr = SP.plan([0, 0], [2500, -4000], TYPE, 0, 3600, [], shape: 'L', mid: [3000, 0])
ok('L: điểm cuối phía phải (y âm) thì vế 2 rẽ về phía phải', Lr[:footprint].map(&:last).min <= -4000.0 + 500.0 + 1.0)
U = SP.plan([0, 0], [1500, 2000], TYPE, 0, 3600, [], shape: 'U', mid: [3000, 0])
ok('U: vế 2 song song vế 1 ngược chiều, cùng 11 bậc (vế 1) và 10 bậc (vế 2), có chiếu nghỉ', U[:count] == 21 && U[:steps].count { |x| x[:landing] } == 1 && U[:run2] == 3000.0)
ok('U: mặt bằng là hình chữ nhật x 0..4000, y -500..1500 (hai vế cạnh nhau, không khe)', U[:footprint].map(&:first).minmax == [0.0, 4000.0] && U[:footprint].map(&:last).minmax == [-500.0, 1500.0] && U[:footprint].size == 4)
u2 = U[:steps].select { |x| !x[:landing] && x[:poly].map(&:last).min >= 499.0 }
ok('U: các bậc của vế 2 nằm trong x 0..3000, y 500..1500 (phía rẽ)', u2.size == 10 && u2.all? { |x| x[:poly].map(&:first).min >= -1.0 && x[:poly].map(&:first).max <= 3001.0 })
ok('U: bậc vế 2 cao dần từ chiếu nghỉ (11 bậc đã có) lên 3600', (u2.map { |x| x[:z1] }.max - 3600).abs < 0.2)
ok('L/U thiếu đầu chiếu nghỉ: báo lỗi', !error_of { SP.plan([0, 0], [2500, 4000], TYPE, 0, 3600, [], shape: 'L') }.nil?)
ok('L: vế 1 quá ngắn (mid 400 mm): báo lỗi', !error_of { SP.plan([0, 0], [2500, 4000], TYPE, 0, 3600, [], shape: 'L', mid: [400, 0]) }.nil?)
ok('L: điểm cuối thẳng hàng vế 1 (không rẽ được): báo lỗi', !error_of { SP.plan([0, 0], [6000, 50], TYPE, 0, 3600, [], shape: 'L', mid: [3000, 0]) }.nil?)
ok('chữ L: cao quá thấp chỉ 1 bậc (không đủ 2 bậc để rẽ): báo lỗi', !error_of { SP.plan([0, 0], [2500, 4000], TYPE, 0, 150, [], shape: 'L', mid: [3000, 0]) }.nil?)
ok('dạng không hợp lệ: báo lỗi', !error_of { SP.plan([0, 0], [6000, 0], TYPE, 0, 3600, [], shape: 'Z') }.nil?)
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
