# Test mặt cắt từ HÌNH THẬT trong model: duyệt nhóm / component lồng nhau, cắt mặt, nối đường viền, chiếu cạnh phía sau, nguồn của từng đường viền (phần tử plugin, đối tượng SketchUp thường, hình rời). SketchUp giả lập: chưa xác minh trong SketchUp thật.
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
require_relative 'fake_sketchup'
module UI
  class HtmlDialog
    STYLE_DIALOG = 1
    attr_reader :callbacks, :scripts
    def initialize(**opts); @callbacks = {}; @scripts = []; @visible = false; end
    def set_file(f); end
    def add_action_callback(name, &b); @callbacks[name] = b; end
    def set_on_closed(&b); @on_closed = b; end
    def fire_closed; @on_closed&.call; end
    def execute_script(js); @scripts << js; end
    def show; @visible = true; end
    def visible?; @visible; end
    def bring_to_front; end
    def close; @visible = false; fire_closed; end
  end
  # Hẹn giờ giả lập: giữ lại để test tự "đến giờ" (chạy khối ngay khi gọi fire_timers).
  def self.start_timer(delay, repeat, &block); ($timers ||= []) << [delay, repeat, block]; $timers.size; end
  def self.fire_timers; t = ($timers || []).dup; $timers = []; t.each { |_d, _r, b| b.call }; t.size; end
  def self.messagebox(text, *); IDYES; end
end
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/stair_types core/stair_plan core/stair_place core/layer_list core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/slab_plan core/ceiling_plan core/proposal core/checker core/model_edit core/section_geometry core/sketchup_import core/state core/preview model_sync edit_sync su_scan su_section su_scan model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder stair_builder all_builder su_tools panel].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
MS = S::ModelSync
D = S::Schema::DICTIONARY
ot = S::OpeningTypes.default
def deep(x); Marshal.load(Marshal.dump(x)); end
def error_of; yield; nil; rescue StandardError => e; e.message; end
LV = 'sl_00000001'
def state_with(cols: {'1-A' => {}, '2-B' => {}}, beams: {'x:B:1-2' => {}}, walls: {'x:B:1-2' => {}}, slabs: {'1-2/A-B' => {}}, ceilings: {})
  st = S::State.default
  st['levels'][0]['picks'] = {'columns' => cols, 'beams' => beams, 'walls' => walls, 'openings' => {}, 'slabs' => slabs, 'ceilings' => ceilings}
  S::State.normalize!(st)
end
def evs(dlg); dlg.scripts.map { |s| m = s.match(/receive\((.*?), (\{.*\})\)\z/m); [JSON.parse(m[1]), JSON.parse(m[2])] }; end
def last_ev(dlg, name); evs(dlg).reverse.find { |n, _| n == name }&.last; end
def count_ev(dlg, name); evs(dlg).count { |n, _| n == name }; end
def call(dlg, name, data = nil); dlg.callbacks.fetch(name).call(nil, data.nil? ? '' : JSON.generate(data)); end
kinds_of = ->(model) { model.entities.grep(Sketchup::Group).map { |g| g.get_attribute(D, 'kind') }.sort }

SS = S::SuSection
def pt(x, y, z); Geom::Point3d.new(x.mm, y.mm, z.mm); end
# Hộp trong thực thể `entities`: 6 mặt và 12 cạnh, tọa độ mm trong hệ của thực thể.
def add_box(entities, x0, x1, y0, y1, z0, z1)
  [[[x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0]], [[x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1]],
   [[x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1]], [[x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1]],
   [[x0, y0, z0], [x0, y1, z0], [x0, y1, z1], [x0, y0, z1]], [[x1, y0, z0], [x1, y1, z0], [x1, y1, z1], [x1, y0, z1]]].each { |ring| entities.add_face(ring.map { |p| pt(*p) }) }
  [x0, x1].product([y0, y1]).each { |x, y| entities.add_line(pt(x, y, z0), pt(x, y, z1)) }
  [y0, y1].product([z0, z1]).each { |y, z| entities.add_line(pt(x0, y, z), pt(x1, y, z)) }
  [x0, x1].product([z0, z1]).each { |x, z| entities.add_line(pt(x, y0, z), pt(x, y1, z)) }
end

$model = Sketchup::Model.new
# Phần tử do plugin dựng: nhóm chứa (kind 'walls') > thể hiện có VGD_BIM_SOURCE, định nghĩa là hộp tường dày 200 dọc X, đặt tại (0, 0).
defn = Sketchup::ComponentDefinition.new('tuong')
add_box(defn.entities, 0, 4000, -100, 100, 0, 3000)
container = $model.entities.add_group
container.set_attribute(S::Schema::DICTIONARY, 'kind', 'walls')
wall = container.entities.add_instance(defn, Geom::Transformation.new(Geom::Vector3d.new(0, 0, 0)))
wall.set_attribute('VGD_BIM_SOURCE', 'plugin', 'vgd_structure'); wall.set_attribute('VGD_BIM_SOURCE', 'kind', 'wall'); wall.set_attribute('VGD_BIM_SOURCE', 'ref', 'sl_00000001:x:B:1-2')
wall.layer = $model.layers.add('A. WALL')
# Đối tượng SketchUp thường (cột) cách tường 1000 mm, có tag S. COLUMN, đặt bằng phép dời (3000, 1000).
cdef = Sketchup::ComponentDefinition.new('cot')
add_box(cdef.entities, -150, 150, -150, 150, 0, 3000)
col = $model.entities.add_instance(cdef, Geom::Transformation.new(Geom::Vector3d.new(3000.mm, 1000.mm, 0)))
col.layer = $model.layers.add('S. COLUMN')

pl = {'a' => [2000, -1000], 'b' => [2000, 1000], 'dir' => 1, 'depth' => 1500}
r = SS.build($model, pl)
ok('mặt cắt qua tường tại x = 2000: có đường viền khép kín của tường', r[:cut].size == 1 && r[:cut][0][:closed] && r[:cut][0][:pts].size == 4)
src = r[:cut][0][:src]
ok('đường viền mang nguồn là phần tử plugin: loại wall, tầng, mã', src[:kind] == 'wall' && src[:level] == 'sl_00000001' && src[:ref] == 'x:B:1-2' && src[:tag] == 'A. WALL')
ok('đúng kích thước: s 900..1100 (dày 200), z 0..3000', r[:cut][0][:pts].map(&:first).minmax == [900.0, 1100.0] && r[:cut][0][:pts].map(&:last).minmax == [0.0, 3000.0])
ok('chiều dài đường cắt 2000', r[:length] == 2000.0 && !r[:truncated])
r2 = SS.build($model, {'a' => [3000, -500], 'b' => [3000, 1500], 'dir' => 1, 'depth' => 500})
col_cut = r2[:cut].find { |c| c[:src][:kind] == 'suobj' }
ok('cắt qua cột SketchUp thường (phép dời 3000, 1000): có đường viền, nguồn suobj mang id SketchUp và tag', col_cut && col_cut[:closed] && col_cut[:src][:ref] == col.entityID.to_s && col_cut[:src][:tag] == 'S. COLUMN')
ok('cột cắt đúng chỗ: s = (y - (-500)) từ 1350 đến 1650 (cột 300 quanh y = 1000), z 0..3000', col_cut[:pts].map(&:first).minmax == [1350.0, 1650.0] && col_cut[:pts].map(&:last).minmax == [0.0, 3000.0])
ok('cắt ngoài mọi vật (x = 9000): không có đường viền', SS.build($model, {'a' => [9000, -500], 'b' => [9000, 1500], 'dir' => 1, 'depth' => 100})[:cut].empty?)
# Chỉ phần nằm trong ĐOẠN đường cắt vẽ trên mặt bằng mới bị cắt (và được hatch): vật trên phần kéo dài của đường cắt thì không.
short = SS.build($model, {'a' => [2000, -1000], 'b' => [2000, -500], 'dir' => 1, 'depth' => 100})
ok('đường cắt dừng trước tường (đoạn y -1000..-500, tường ở y -100..100): tường không bị cắt dù nằm trên phần kéo dài', short[:cut].empty?)
half = SS.build($model, {'a' => [2000, -1000], 'b' => [2000, 0], 'dir' => 1, 'depth' => 100})
ok('đường cắt dừng giữa tường (tới y = 0): chỉ phần tường trong đoạn bị cắt, s 900..1000', half[:cut].size == 1 && half[:cut][0][:pts].map(&:first).minmax == [900.0, 1000.0])
back = SS.build($model, {'a' => [-500, -1000], 'b' => [-500, 1000], 'dir' => -1, 'depth' => 1000})
ok('nhìn từ x = -500 về +X tầm 1000: thấy cạnh đầu tường, không có đường cắt', back[:cut].empty? && back[:beyond].size >= 4)
none = SS.build($model, {'a' => [-500, -1000], 'b' => [-500, 1000], 'dir' => 1, 'depth' => 1000})
ok('nhìn ngược chiều: không thấy gì', none[:cut].empty? && none[:beyond].empty?)
ok('tầm nhìn 100 từ x = -500 về +X: cạnh đầu tường ở x = 0 (cách 500) nằm ngoài tầm nhìn nên không thấy', SS.build($model, {'a' => [-500, -1000], 'b' => [-500, 1000], 'dir' => -1, 'depth' => 100})[:beyond].empty?)
ok('đường cắt quá ngắn: báo lỗi dữ liệu', begin; SS.build($model, {'a' => [0, 0], 'b' => [0.2, 0], 'dir' => 1, 'depth' => 100}); false; rescue ArgumentError; true; end)
# Phép xoay: cột xoay 90 độ quanh gốc của nó
col.transformation.instance_variable_set(:@angle, Math::PI / 2)
rr = SS.build($model, {'a' => [3000, -500], 'b' => [3000, 1500], 'dir' => 1, 'depth' => 500})
ok('cột xoay 90 độ (vuông 300 nên không đổi hình bao): vẫn cắt ra đường viền cùng kích thước', (c = rr[:cut].find { |x| x[:src][:kind] == 'suobj' }) && c[:pts].map(&:first).minmax == [1350.0, 1650.0])
# Ẩn
col.define_singleton_method(:hidden?) { true }
ok('đối tượng bị ẩn: không đưa vào mặt cắt', SS.build($model, {'a' => [3000, -500], 'b' => [3000, 1500], 'dir' => 1, 'depth' => 500})[:cut].none? { |c| c[:src][:kind] == 'suobj' })
# Hình rời ở cấp cao nhất
$model.entities.add_face([pt(4800, 0, 0), pt(5200, 0, 0), pt(5200, 0, 1000), pt(4800, 0, 1000)])
lo = SS.build($model, {'a' => [5000, -500], 'b' => [5000, 500], 'dir' => 1, 'depth' => 100})
ok('hình rời (mặt đứng không thuộc nhóm nào): có nguồn chung kind geom, đường cắt hở (một mặt không khép kín)', lo[:cut].size == 1 && lo[:cut][0][:src][:kind] == 'geom' && lo[:cut][0][:closed] == false && lo[:cut][0][:pts].map(&:last).minmax == [0.0, 1000.0])

# ---- Phép biến đổi lồng nhau và loại bỏ vật ở xa ----
nested_group = $model.entities.add_group
nested_group.transform!(Geom::Transformation.new(Geom::Vector3d.new(1000.mm, 0, 0)))
nested_inst = nested_group.entities.add_instance(defn, Geom::Transformation.new(Geom::Vector3d.new(500.mm, 0, 0)))
nested_inst.layer = $model.layers.add('S. BEAM')
rn = SS.build($model, {'a' => [5000, -500], 'b' => [5000, 500], 'dir' => 1, 'depth' => 100})
ok('đối tượng lồng: nhóm dời 1000 + thể hiện dời 500 (tường dài 4000) nằm ở x = 1500..5500; cắt tại x = 5000 có đúng một đường viền suobj (nguồn là nhóm cấp cao nhất)', (sc = rn[:cut].select { |c| c[:src][:kind] == 'suobj' }).size == 1 && sc[0][:closed] && sc[0][:src][:ref] == nested_group.entityID.to_s)
faces_before = SS.build($model, {'a' => [2000, -1000], 'b' => [2000, 1000], 'dir' => 1, 'depth' => 1500})[:faces]
far_defn = Sketchup::ComponentDefinition.new('xa'); add_box(far_defn.entities, 0, 100, 0, 100, 0, 100); far_defn.fake_bounds = Sketchup::FakeBounds.new(100.mm, 100.mm, 100.mm, Geom::Point3d.new(50.mm, 50.mm, 50.mm))
far = $model.entities.add_instance(far_defn, Geom::Transformation.new(Geom::Vector3d.new(500_000.mm, 500_000.mm, 0)))
ok('vật ở rất xa vùng cắt và tầm nhìn: không được đọc (số mặt không tăng)', SS.build($model, {'a' => [2000, -1000], 'b' => [2000, 1000], 'dir' => 1, 'depth' => 1500})[:faces] == faces_before)
near_defn = Sketchup::ComponentDefinition.new('gan'); add_box(near_defn.entities, 0, 100, 0, 100, 0, 100); near_defn.fake_bounds = Sketchup::FakeBounds.new(100.mm, 100.mm, 100.mm, Geom::Point3d.new(50.mm, 50.mm, 50.mm))
$model.entities.add_instance(near_defn, Geom::Transformation.new(Geom::Vector3d.new(2000.mm, 200.mm, 0)))
ok('vật gần trong tầm nhìn: được đọc (số mặt tăng thêm 6)', SS.build($model, {'a' => [2000, -1000], 'b' => [2000, 1000], 'dir' => 1, 'depth' => 1500})[:faces] == faces_before + 6)

# ---- Định nghĩa mặt cắt của tầng (Levels.sections!) ----
LV2 = S::Levels
good = {'sc_00000001' => {'name' => 'A-A', 'a' => [0, 0], 'b' => [4000, 0], 'dir' => -1, 'depth' => 3000}}
out = LV2.sections!(good, 'Tầng 1')
ok('mặt cắt hợp lệ: giữ tên, hai đầu, phía nhìn, tầm nhìn', out['sc_00000001'] == {'name' => 'A-A', 'a' => [0.0, 0.0], 'b' => [4000.0, 0.0], 'dir' => -1, 'depth' => 3000.0})
ok('thiếu dir / depth: mặc định dir 1, tầm nhìn 6000', LV2.sections!({'sc_00000002' => {'name' => 'B', 'a' => [0, 0], 'b' => [0, 500]}}, 'Tầng 1')['sc_00000002'].values_at('dir', 'depth') == [1, 6000.0])
ok('nil hoặc rỗng: {}', LV2.sections!(nil, 'T') == {} && LV2.sections!({}, 'T') == {})
bad = ->(sec, id = 'sc_00000003') { begin; LV2.sections!({id => sec}, 'Tầng 1'); nil; rescue S::Levels::Error => e; e.message; end }
ok('mã sai kiểu, tên rỗng / quá dài / điều khiển: từ chối', bad.call({'name' => 'x', 'a' => [0, 0], 'b' => [500, 0]}, 'sc_xx').to_s.include?('mã') && ['', 'x' * 31, "a\nb"].all? { |n| bad.call({'name' => n, 'a' => [0, 0], 'b' => [500, 0]}).to_s.include?('tên') })
ok('điểm sai (không phải [x, y] số) hoặc ngắn hơn 100 mm: từ chối', bad.call({'name' => 'x', 'a' => [0], 'b' => [500, 0]}).to_s.include?('điểm a') && bad.call({'name' => 'x', 'a' => [0, 0], 'b' => ['x', 0]}).to_s.include?('điểm b') && bad.call({'name' => 'x', 'a' => [0, 0], 'b' => [50, 0]}).to_s.include?('ngắn hơn'))
ok('phía nhìn khác 1 / -1 và tầm nhìn ngoài khoảng: từ chối', bad.call({'name' => 'x', 'a' => [0, 0], 'b' => [500, 0], 'dir' => 2}).to_s.include?('phía nhìn') && bad.call({'name' => 'x', 'a' => [0, 0], 'b' => [500, 0], 'depth' => 50}).to_s.include?('tầm nhìn') && bad.call({'name' => 'x', 'a' => [0, 0], 'b' => [500, 0], 'depth' => 'x'}).to_s.include?('tầm nhìn'))
ok('tên trùng (không phân biệt hoa thường): từ chối', (begin; LV2.sections!({'sc_00000004' => {'name' => 'Ab', 'a' => [0, 0], 'b' => [500, 0]}, 'sc_00000005' => {'name' => 'aB', 'a' => [0, 0], 'b' => [500, 0]}}, 'T'); nil; rescue S::Levels::Error => e; e.message; end).to_s.include?('trùng'))
ok('quá 30 mặt cắt: từ chối', (begin; LV2.sections!((1..31).to_h { |i| [format('sc_%08x', i), {'name' => "m#{i}", 'a' => [0, 0], 'b' => [500, 0]}] }, 'T'); nil; rescue S::Levels::Error => e; e.message; end).to_s.include?('quá nhiều'))
stx = S::State.default; stx['levels'][0]['sections'] = good
nx = S::State.normalize!(stx)
ok('State.normalize! giữ mặt cắt của tầng; tầng không có thì không có khóa', nx['levels'][0]['sections'].keys == ['sc_00000001'] && !nx['levels'][1].key?('sections'))

# ---- Callback section_build ----
panel = S::Panel.new; dlg = panel.instance_variable_get(:@dialog); panel.show; call(dlg, 'ready')
call(dlg, 'section_build', {'id' => 'sc_00000001', 'section' => {'name' => 'A-A', 'a' => [2000, -1000], 'b' => [2000, 1000], 'dir' => 1, 'depth' => 1500}})
ev = last_ev(dlg, 'section_view')
ok('section_build: gửi section_view có id, tên, chiều dài, đường viền kèm nguồn, cạnh phía sau', ev && ev['id'] == 'sc_00000001' && ev['name'] == 'A-A' && ev['length'] == 2000.0 && ev['cut'].size >= 1 && ev['cut'][0]['src']['kind'] == 'wall' && ev['beyond'].is_a?(Array))
call(dlg, 'section_build', {'id' => 'x', 'section' => {'name' => 'A', 'a' => [0, 0], 'b' => [10, 0]}})
ok('đường cắt quá ngắn: báo lỗi, không gửi section_view mới', last_ev(dlg, 'message')['error'] && count_ev(dlg, 'section_view') == 1)
call(dlg, 'section_build', {'id' => 'x', 'section' => 'rác'})
ok('dữ liệu mặt cắt sai kiểu: báo lỗi', last_ev(dlg, 'message')['error'] && count_ev(dlg, 'section_view') == 1)

puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
