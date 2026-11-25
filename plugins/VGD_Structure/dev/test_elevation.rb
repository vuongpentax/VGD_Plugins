# Test mặt đứng từ HÌNH THẬT trong model (SuSection.elevation) và callback elevation_build của cửa sổ: không cắt, không giới hạn độ sâu,
# bỏ vật ẩn, nguồn của từng mặt (phần tử plugin, đối tượng SketchUp thường), hướng không hợp lệ bị từ chối. SketchUp giả lập: chưa xác minh trong SketchUp thật.
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
  def self.start_timer(delay, repeat, &block); ($timers ||= []) << [delay, repeat, block]; $timers.size; end
  def self.fire_timers; t = ($timers || []).dup; $timers = []; t.each { |_d, _r, b| b.call }; t.size; end
  def self.messagebox(text, *); IDYES; end
end
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/stair_types core/stair_plan core/stair_place core/layer_list core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/room_plan core/slab_plan core/ceiling_plan core/proposal core/checker core/model_edit core/section_geometry core/elevation_geometry core/sketchup_import core/state core/preview model_sync edit_sync su_scan su_section model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder stair_builder all_builder su_tools panel].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
D = S::Schema::DICTIONARY
SS = S::SuSection
EG = S::ElevationGeometry
def pt(x, y, z); Geom::Point3d.new(x.mm, y.mm, z.mm); end
def call(dlg, name, data = nil); dlg.callbacks.fetch(name).call(nil, data.nil? ? '' : JSON.generate(data)); end
def last_ev(dlg, name)
  dlg.scripts.map { |s| m = s.match(/receive\((.*?), (\{.*\})\)\z/m); [JSON.parse(m[1]), JSON.parse(m[2])] }.reverse.find { |n, _| n == name }&.last
end
def count_ev(dlg, name); dlg.scripts.count { |s| s.include?("receive(\"#{name}\"") }; end
# Hộp [x0..x1] x [y0..y1] x [z0..z1] trong thực thể: 6 mặt.
def add_box(entities, x0, x1, y0, y1, z0, z1)
  [[[x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0]], [[x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1]],
   [[x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1]], [[x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1]],
   [[x0, y0, z0], [x0, y1, z0], [x0, y1, z1], [x0, y0, z1]], [[x1, y0, z0], [x1, y1, z0], [x1, y1, z1], [x1, y0, z1]]].each { |ring| entities.add_face(ring.map { |p| pt(*p) }) }
end

$model = Sketchup::Model.new
# Tường do plugin dựng: nhóm chứa kind 'walls' > thể hiện có VGD_BIM_SOURCE; hộp 0..4000 x -100..100 x 0..3000.
defn = Sketchup::ComponentDefinition.new('tuong')
add_box(defn.entities, 0, 4000, -100, 100, 0, 3000)
container = $model.entities.add_group
container.set_attribute(D, 'kind', 'walls')
wall = container.entities.add_instance(defn, Geom::Transformation.new)
wall.set_attribute('VGD_BIM_SOURCE', 'plugin', 'vgd_structure'); wall.set_attribute('VGD_BIM_SOURCE', 'kind', 'wall'); wall.set_attribute('VGD_BIM_SOURCE', 'ref', 'sl_00000001:x:B:1-2')
# Cột SketchUp thường ở (3000, 1000), 300 x 300 x 3000, tag S. COLUMN.
cdef = Sketchup::ComponentDefinition.new('cot')
add_box(cdef.entities, -150, 150, -150, 150, 0, 3000)
col = $model.entities.add_instance(cdef, Geom::Transformation.new(Geom::Vector3d.new(3000.mm, 1000.mm, 0)))
col.layer = $model.layers.add('S. COLUMN')
# Khối bị ẩn ở (-2000, 0): không được đưa vào mặt đứng.
hdef = Sketchup::ComponentDefinition.new('an')
add_box(hdef.entities, 0, 500, 0, 500, 0, 3000)
hidden = $model.entities.add_instance(hdef, Geom::Transformation.new(Geom::Vector3d.new(-2000.mm, 0, 0)))
hidden.define_singleton_method(:hidden?) { true }
# Khối rất xa (cách 500 m): mặt đứng không lọc theo tầm nhìn nên phải có.
fdef = Sketchup::ComponentDefinition.new('xa')
add_box(fdef.entities, 0, 100, 0, 100, 0, 100)
fdef.fake_bounds = Sketchup::FakeBounds.new(100.mm, 100.mm, 100.mm, Geom::Point3d.new(50.mm, 50.mm, 50.mm))
$model.entities.add_instance(fdef, Geom::Transformation.new(Geom::Vector3d.new(500_000.mm, 0, 0)))

south = SS.elevation($model, EG.view!('south'))
srcs = south[:polys].map { |p| p[:src] }
ok('mặt đứng Nam có mặt tường (plugin) với nguồn loại wall, tầng, mã', srcs.any? { |s| s && s[:kind] == 'wall' && s[:level] == 'sl_00000001' && s[:ref] == 'x:B:1-2' })
ok('mặt đứng Nam có cột SketchUp thường với nguồn suobj mã thực thể và tag', srcs.any? { |s| s && s[:kind] == 'suobj' && s[:ref] == col.entityID.to_s && s[:tag] == 'S. COLUMN' })
ok('không cắt: mặt tường phía gần (y = -100) được tô sau cùng, nằm ở s 0..4000', south[:polys].last[:src][:kind] == 'wall' && south[:polys].last[:pts].map(&:first).minmax == [0.0, 4000.0])
ok('khối rất xa vẫn được đọc (không lọc theo tầm nhìn): có mặt nguồn geom / suobj ở s = 500000', south[:polys].any? { |p| p[:pts].any? { |s, _| s >= 499_000 } })
ok('khối bị ẩn không có mặt nào ở s từ -2000 đến -1500', south[:polys].none? { |p| p[:pts].any? { |s, _| s <= -1500 && s >= -2000 } })
ok('kết quả có khung (bounds) và không bị cắt bớt', south[:bounds].is_a?(Hash) && !south[:truncated])
north = SS.elevation($model, EG.view!('north'))
walls_north = north[:polys].select { |p| p[:src] && p[:src][:kind] == 'wall' }
ok('mặt đứng Bắc: mặt gần của tường là mặt y = +100 (nằm ở s -4000..0)', walls_north.last[:pts].map(&:first).minmax == [-4000.0, 0.0] && walls_north.last[:depth] < walls_north.first[:depth])
ok('mặt đứng Bắc: cột (y = 1000) nằm gần người xem hơn tường nên được tô sau tường', north[:polys].last[:src][:kind] == 'suobj')

# ---- Quá nhiều mặt: giữ các mặt GẦN nhất, báo cắt bớt ----
many = Sketchup::Model.new
mdef = many.entities
# Mặt i nằm ở y = 10 i (độ sâu nhìn từ Nam = y): mặt xa nhất (i lớn nhất) phải bị bỏ.
(S::SuSection::MAX_POLYS + 1).times { |i| mdef.add_face([pt(0, i * 10, 0), pt(5, i * 10, 0), pt(5, i * 10, 5), pt(0, i * 10, 5)]) }
big = SS.elevation(many, EG.view!('south'))
ok('quá MAX_POLYS mặt: chỉ gửi MAX_POLYS mặt và báo cắt bớt', big[:polys].size == S::SuSection::MAX_POLYS && big[:truncated])
ok('giữ các mặt gần nhất: mặt xa nhất (y = 400000) bị bỏ, mặt sâu nhất còn lại là y = 399990', big[:polys].map { |p| p[:depth] }.max == 399_990.0)

# ---- Callback elevation_build ----
panel = S::Panel.new; dlg = panel.instance_variable_get(:@dialog); panel.show; call(dlg, 'ready')
call(dlg, 'elevation_build', {'dir' => 'east'})
ev = last_ev(dlg, 'elevation_view')
ok('elevation_build: gửi elevation_view kèm hướng, mặt đã sắp, khung', ev && ev['dir'] == 'east' && ev['polys'].is_a?(Array) && !ev['polys'].empty? && ev['bounds'].is_a?(Hash))
ok('mặt đã sắp xa đến gần: độ sâu giảm dần', ev['polys'].each_cons(2).all? { |a, b| a['depth'] >= b['depth'] })
n = count_ev(dlg, 'elevation_view')
call(dlg, 'elevation_build', {'dir' => 'up'})
ok('hướng không hợp lệ: không gửi kết quả mới (báo lỗi qua hộp thoại, không làm hỏng cửa sổ)', count_ev(dlg, 'elevation_view') == n)

puts $fails.zero? ? "\nTất cả PASS" : "\n#{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
