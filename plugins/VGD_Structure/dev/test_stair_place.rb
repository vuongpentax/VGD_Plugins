# Test đặt cầu thang và kiểm tra không đâm vào cột, dầm, tường (core/stair_place.rb). Logic thuần, không cần SketchUp. Chạy: ruby dev/test_stair_place.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
%w[schema grid axis_symbol geometry column_types beam_types wall_types opening_types layer_list levels column_plan beam_plan wall_joins wall_plan opening_plan plates slab_plan ceiling_plan stair_types stair_plan stair_place state].each { |f| require File.join(ROOT, 'core', f) }
S = VGD::Structure
L = S::Levels
GRID = S::Grid.default
TYPES = S::ColumnTypes.default
BT = S::BeamTypes.default
WT = S::WallTypes.default
OT = S::OpeningTypes.default
ST = S::StairTypes.default
TYPE = ST[0]

# Tầng 1 (dưới) và Tầng 2 (trên, cao 3600). Tầng 1 có tường trên trục B từ 1 đến 2 (y = 3600, x 0..4200).
def build(lower_picks)
  levels = L.default
  levels[0]['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => {}, 'slabs' => {}, 'ceilings' => {}, 'openings' => {}, 'stairs' => {}}.merge(lower_picks)
  levels[1]['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => {}, 'slabs' => {}, 'ceilings' => {}, 'openings' => {}, 'stairs' => {}}
  L.normalize!(levels, GRID, TYPES, BT, WT, OT).first
end
def stair(a, b, id = 'st_00000001')
  {id => {'type' => TYPE['id'], 'free' => {'a' => a, 'b' => b}}}
end
def plan_of(levels, stair_types = ST)
  S::StairPlace.plan(GRID, TYPES, BT, WT, stair_types, levels, 'sl_00000001', OT)
end

lv = build('stairs' => stair([6000, 300], [6000, 5800]))
r = plan_of(lv)
ok('cầu thang ở xa mọi tường, cột, dầm: không có va chạm, không có cảnh báo', r[:items].size == 1 && r[:items][0][:conflicts].empty? && r[:issues].empty?)
it = r[:items][0]
ok('mục cầu thang: chân 4 đỉnh, cao độ đáy tầng 1 (mặt sàn kết cấu -50) và đỉnh tầng 2 (3550)', it[:polygon].size == 4 && it[:z0] == -50.0 && it[:z1] == 3550.0)
ok('mục cầu thang có kế hoạch bậc (21 bậc)', it[:plan][:count] == 21 && it[:plan][:steps].size == 21)

lv = build('walls' => {'x:B:1-2' => {}}, 'stairs' => stair([500, 300], [500, 5800]))
r = plan_of(lv)
ok('cầu thang cắt qua tường trục B (y = 3600): báo đâm vào “tường x:B:1-2” và không được dựng', r[:items][0][:conflicts] == ['tường x:B:1-2'] && r[:issues].any? { |m| m.include?('đâm vào') && m.include?('tường x:B:1-2') })

lv = build('columns' => {'1-B' => {}}, 'stairs' => stair([0, 300], [0, 5800]))
r = plan_of(lv)
ok('cầu thang đi qua cột 1-B (0, 3600): báo đâm vào “cột 1-B”', r[:items][0][:conflicts].include?('cột 1-B'))

# Dầm trục B ở cao độ 3150..3550: chỉ đâm vào khi bậc đi tới đó (cuối vế). Vế từ y -1800 lên 3700 đi tới dầm ở đoạn cao.
lv = build('beams' => {'x:B:1-2' => {}}, 'stairs' => stair([500, -1800], [500, 3700]))
r = plan_of(lv)
ok('cầu thang đi tới dầm trục B ở đoạn cuối vế (bậc cao quá 3150): báo đâm vào “dầm x:B:1-2”', r[:items][0][:conflicts].include?('dầm x:B:1-2'))
lv = build('beams' => {'x:B:1-2' => {}}, 'stairs' => stair([500, 300], [500, 5800]))
r = plan_of(lv)
ok('cầu thang đi qua dưới dầm ở đoạn thấp (bậc chưa tới cao độ đáy dầm): KHÔNG báo đâm', r[:items][0][:conflicts].empty?)

lv = build('stairs' => stair([500, 300], [500, 500]))
r = plan_of(lv)
ok('cầu thang quá ngắn (vế dưới 600 mm, không đủ bậc): không tạo mục, báo lỗi rõ', r[:items].empty? && r[:issues].any? { |m| m.include?('st_00000001') && m.include?('quá ngắn') })

lv = build('stairs' => {})
lv[1]['picks']['stairs'] = stair([6000, 300], [6000, 5800])
ok('tầng trên cùng không có cầu thang đi lên: báo lỗi', !error_of { S::StairPlace.plan(GRID, TYPES, BT, WT, ST, lv, 'sl_00000002', OT) }.nil?)

lv = build('stairs' => {})
ok('không có cầu thang: kết quả rỗng, không lỗi', plan_of(lv)[:items].empty? && plan_of(lv)[:issues].empty?)

# Cầu thang cắt tường nhưng nằm ngoài vùng cao độ (tường tầng dưới chỉ đến đáy sàn tầng trên): tường phải chạm vùng cao độ của bậc để tính va chạm
ob = S::StairPlace.obstacles_of(GRID, TYPES, BT, WT, lv, 'sl_00000001', OT)
ok('vật cản tầng 1 không có gì khi chưa chọn cột, dầm, tường', ob.empty?)

puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
