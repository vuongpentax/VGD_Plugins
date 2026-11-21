# Test sàn LỌT LÒNG trong tường tầng dưới (SlabPlan lùi theo mặt trong của tường, như dầm và cột). Logic thuần, không cần SketchUp.
# Chạy: ruby dev/test_slab_walls.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
%w[schema grid axis_symbol geometry column_types beam_types wall_types opening_types stair_types stair_plan stair_place layer_list levels column_plan beam_plan wall_joins wall_plan opening_plan plates slab_plan ceiling_plan state].each { |f| require File.join(ROOT, 'core', f) }
S = VGD::Structure
L = S::Levels
grid = S::Grid.default
types = S::ColumnTypes.default
bt = S::BeamTypes.default
wt = S::WallTypes.default
ot = S::OpeningTypes.default
cols = S::Grid.intersections(grid).each_with_object({}) { |i, h| h[i[:ref]] = {} }

# Tầng 1 (dưới) có tường trên trục B từ 1 đến 2; tầng 2 có sàn ô 1-2/A-B (0..4200 x 0..3600).
lower_walls = {'x:B:1-2' => {}}
levels = L.default
levels[0]['picks'] = {'columns' => cols, 'beams' => {}, 'walls' => lower_walls, 'openings' => {}, 'slabs' => {}, 'ceilings' => {}}
levels[1]['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => {}, 'openings' => {}, 'slabs' => {'1-2/A-B' => {}}, 'ceilings' => {}}
levels = L.normalize!(levels, grid, types, bt, wt, ot).first

def slab_cell(levels, grid, types, bt, wt, ot, ref = '1-2/A-B')
  S::SlabPlan.plan(grid, levels, 'sl_00000002', types, bt, wt, ot)[:items].find { |i| i[:ref] == ref }
end

wall = S::WallPlan.plan(grid, types, bt, wt, levels, 'sl_00000001', ot)[:items].find { |w| w[:ref] == 'x:B:1-2' }
s = slab_cell(levels, grid, types, bt, wt, ot)
ok('tường có trên tầng dưới: mép trên sàn lùi tới MẶT TRONG tường (min y của tường), không lấn vào tường', wall && s[:max][1] == wall[:min][1] && s[:max][1] < 3600.0)
ok('sàn vẫn phủ trọn hai cạnh còn lại (trái, phải, dưới không có tường): x 0..4200, y từ 0', s[:min] == [0.0, 0.0] && s[:max][0] == 4200.0)
ok('sàn không chồng tường: đỉnh sàn không vượt mặt trong của tường', s[:polygon].all? { |x, y| y <= wall[:min][1] + 1e-6 || y == 0 })

# Không có tường tầng dưới: sàn phủ như cũ (mép trên tại tâm trục B = 3600)
plain = L.normalize!(levels.map { |l| l.dup }.tap { |a| a[0] = a[0].merge('picks' => a[0]['picks'].merge('walls' => {})) }, grid, types, bt, wt, ot).first
ok('không có tường tầng dưới: sàn không lùi theo tường (mép trên = 3600)', slab_cell(plain, grid, types, bt, wt, ot)[:max][1] == 3600.0)

# Không truyền loại tường (kế hoạch cũ, gọi 5 tham số): không lùi theo tường, không lỗi.
legacy = S::SlabPlan.plan(grid, levels, 'sl_00000002', types, bt)[:items].find { |i| i[:ref] == '1-2/A-B' }
ok('gọi không có loại tường (dữ liệu / test cũ): kết quả như trước, không lỗi', legacy[:max][1] == 3600.0)

# Hai nguồn trên cùng một cạnh (dầm và tường): lấy phía SÂU VÀO trong ô nhất.
shallow = {min: [0.0, 3400.0], max: [4200.0, 3500.0]}
deep = {min: [0.0, 3300.0], max: [4200.0, 3500.0]}
pick = S::Plates.recess_edges({xa: 1, xb: 2, ya: 'A', yb: 'B'}, {'x:B:1-2' => shallow}, {'x:B:1-2' => deep})
ok('dầm và tường cùng cạnh: giữ mục sâu hơn vào trong ô (mép dưới của hộp thấp hơn = sâu hơn ở cạnh trên)', pick[:top] == deep)
