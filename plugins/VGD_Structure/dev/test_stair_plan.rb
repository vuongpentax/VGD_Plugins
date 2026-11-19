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
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
