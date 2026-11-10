require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] ||= Dir.mktmpdir('vgd_bim_dialog') # không ghi vào thư mục dữ liệu thật khi chạy riêng
ROOT = ARGV[0] || File.expand_path('../runtime/vgd_bim', __dir__)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
module Sketchup
  class SelectionObserver; end
  class Group; end; class ComponentInstance < Group; end; class Face; end
  def self.read_default(*); nil; end
  def self.write_default(*); true; end
  def self.active_model; $model; end
end
module VGD; module BIM; def self.log(m); end
  module Data
    def self.supported?(e); e.is_a?(Sketchup::Group); end
    def self.write(entity, values, source); $writes << [entity, values, source]; end
    def self.source(_entity); 'VGD'; end
    # Như Data.transaction thật: một bước hoàn tác cho cả khối
    def self.transaction(model, name = nil); $transactions << name; yield; end
  end
  module Scanner; end
  module Tags
    GROUPS = ['Phần thô'].freeze
    def self.load; [{'name' => 'Trong bộ'}, {'name' => '000 CUA'}]; end
    def self.key(n); n.to_s.downcase; end
    def self.migrate_group(group); group.to_s; end
    # Như Tags.normalize_name / layer_for thật (đã có test riêng trong test_tags.rb)
    def self.normalize_name(n)
      t = n.to_s.strip
      raise ArgumentError, 'Hãy chọn một tag.' if t.empty?
      raise ArgumentError, 'Tên "Untagged" không dùng để gán.' if t.downcase == 'untagged'
      t
    end
    def self.layer_for(model, name); t = normalize_name(name); model.layers.find { |l| l.name == t } || model.layers.add(t); end
  end
  module UI; end
end; end
$transactions = []
$writes = []
require File.join(ROOT, 'core/settings')
require File.join(ROOT, 'core/preset')
require File.join(ROOT, 'core/geometry')
require File.join(ROOT, 'core/view_fit')
require File.join(ROOT, 'core/table')
require File.join(ROOT, 'core/rename')
require File.join(ROOT, 'ui/dialog')
D = VGD::BIM::UI::Dialog

row = {index: 0, entity_type: 'Nhóm', definition: 'Tủ', name: 'Tủ bếp A', description: 'Gỗ sồi',
       lenX: 1200.0, lenY: 600.0, lenZ: 800.0, areaXZ: 0.96, areaXY: 0.72, areaFace: 2.1,
       volume: 0.576, tag: 'Tủ', tag_group: 'Đồ rời', material: 'Gỗ', status: 'new', quantity: 1}
d = D.allocate
d.instance_variable_set(:@table_rows, [row])
d.instance_variable_set(:@table_records, [{path: [], entity: :e}])
d.instance_variable_set(:@outline_field, 'instance')
lbl = ->(f) { d.instance_variable_set(:@outline_field, f); d.outline_label(d.instance_variable_get(:@table_records)[0]) }
ok('ô Tên: chỉ hiện tên', lbl.('instance') == 'Tủ bếp A')
ok('ô Mô tả: chỉ hiện mô tả', lbl.('description') == 'Gỗ sồi')
ok('ô Rộng: có đơn vị mm', lbl.('lenX') == '1200 mm')
ok('ô (X)x(Z): ghép hai cạnh', lbl.('lenXZ') == '1200 x 800 mm')
VGD::BIM::Table.save_view_state('settings' => {'length_unit' => 'cm', 'length_digits' => 1})
ok('đơn vị cm trong preset: nhãn khung đổi theo (120 x 80 cm)', lbl.('lenXZ') == '120 x 80 cm' && lbl.('lenX') == '120 cm' && lbl.('lenXYZ') == '120 x 60 x 80 cm')
VGD::BIM::Table.save_view_state('settings' => {'length_unit' => 'm', 'length_digits' => 2})
ok('đơn vị m, 2 số lẻ: 1.2 x 0.8 m', lbl.('lenXZ') == '1.2 x 0.8 m')
VGD::BIM::Table.save_view_state('settings' => {'length_unit' => 'ft', 'length_digits' => 2})
ok('đơn vị ft: 3.94 x 2.62 ft', lbl.('lenXZ') == '3.94 x 2.62 ft')
VGD::BIM::Table.save_view_state('preset' => 'x')
ok('ô thể tích: m³', lbl.('volume') == '0.576 m³')
ok('ô tình trạng: nhãn tiếng Việt', lbl.('status') == 'Mới')
ok('không chọn ô: hiện cả dòng', lbl.(nil) == 'Tủ bếp A · Gỗ sồi · Mới · Tủ')

# Bấm vùng trống trong SketchUp: bảng giữ nguyên, chỉ bỏ đánh dấu
calls = []
d.define_singleton_method(:emit) { |ev, payload| calls << [ev, payload] }
d.define_singleton_method(:show_outline) { calls << [:outline] }
d.define_singleton_method(:table_build) { calls << [:build] }
d.define_singleton_method(:table_scan_selection!) { calls << [:scan] }
d.define_singleton_method(:highlight_selection) { calls << [:hl] }
d.instance_variable_set(:@table_picks, [:e])
class FakeSel; attr_accessor :items; def initialize; @items = []; end; def to_a; @items; end; end
class FakeModel; attr_reader :selection; def initialize; @selection = FakeSel.new; end; end
$model = FakeModel.new
d.instance_variable_set(:@model, $model)
d.table_selection_changed
ok('bấm vùng trống: không quét lại, không làm mới bảng', calls.none? { |c| c[0] == :build || c[0] == :scan })
ok('bấm vùng trống: bỏ đánh dấu dòng', calls.include?([:emit, 'highlight'] ) || calls.any? { |c| c[0] == 'highlight' && c[1] == {indexes: []} })
ok('bấm vùng trống: xóa đánh dấu chọn', d.instance_variable_get(:@table_picks).nil?)

# Chọn lại đối tượng sau đó: phải quét lại và làm mới bảng
calls.clear
ent = Sketchup::Group.allocate; def ent.valid?; true; end
$model.selection.items = [ent]
d.table_selection_changed
ok('chọn lại đối tượng: quét và làm mới bảng', calls.any? { |c| c[0] == :build } && calls.any? { |c| c[0] == :scan })

# Khung đánh dấu bằng lớp phủ (SketchUp 2023+): đăng ký một lần, dùng lại, ẩn khi bỏ chọn, gỡ khi đóng; lỗi thì quay về công cụ cũ
class FakeOverlay
  attr_reader :shown, :hidden
  def initialize; @shown = []; @hidden = 0; end
  def show_shapes(points, **options); @shown << [points, options]; end
  def hide_shapes; @hidden += 1; end
  def enabled=(value); @enabled = value; end
end
VGD::BIM::UI.const_set(:BoundsOverlay, FakeOverlay)
class FakeOverlays
  attr_reader :added, :removed
  attr_accessor :fail
  def initialize; @added = []; @removed = []; end
  def add(overlay); raise 'không thêm được lớp phủ' if @fail; @added << overlay; overlay; end
  def remove(overlay); @removed << overlay; end
end
class FakeView; attr_reader :invalidated; def initialize; @invalidated = 0; end; def invalidate; @invalidated += 1; end; end
class FakeModelWithOverlays
  attr_reader :overlays, :active_view
  def initialize; @overlays = FakeOverlays.new; @active_view = FakeView.new; end
end
om = FakeModelWithOverlays.new
od = D.allocate
od.instance_variable_set(:@model, om)
od.instance_variable_set(:@isolated, [])
ok('có lớp phủ: dùng lớp phủ thay vì công cụ', od.overlay_available?)
ok('hiện khung bằng lớp phủ: trả về true', od.show_overlay([[0, 0, 0]], 'Tủ', [0, 0, 0], [], -> { true }, -> {}) == true)
od.show_overlay([[1, 1, 1]], 'Tủ 2', [1, 1, 1], [], -> { true }, -> {})
ok('lớp phủ chỉ đăng ký một lần, lần sau dùng lại', om.overlays.added.size == 1 && om.overlays.added[0].shown.size == 2)
ok('vẽ lại viewport sau khi đặt khung', om.active_view.invalidated >= 2)
od.release_preview
ok('bỏ chọn: lớp phủ ẩn đi nhưng vẫn đăng ký', om.overlays.added[0].hidden == 1 && om.overlays.removed.empty?)
od.cleanup_table_view
ok('đóng cửa sổ: gỡ lớp phủ khỏi model', om.overlays.removed == om.overlays.added)
fm = FakeModelWithOverlays.new
fm.overlays.fail = true
fd = D.allocate
fd.instance_variable_set(:@model, fm)
fd.instance_variable_set(:@isolated, [])
ok('lớp phủ lỗi: trả về false để dùng công cụ cũ', fd.show_overlay([[0, 0, 0]], 'Tủ', [0, 0, 0], [], -> { true }, -> {}) == false)
ok('lớp phủ đã lỗi thì không thử lại', !fd.overlay_available?)

# Đổi tên hàng loạt: xem trước, áp dụng trong một bước hoàn tác, bỏ qua đối tượng khóa, từ chối khi đối tượng không còn
class RenameEnt
  attr_accessor :name
  def initialize(name, locked = false, valid = true); @name = name; @locked = locked; @valid = valid; end
  def locked?; @locked; end
  def valid?; @valid; end
end
RBox = Struct.new(:min) { def empty?; false; end }
RPoint = Struct.new(:x, :y, :z)
VGD::BIM::Table.define_singleton_method(:bounding_box) { |record| record[:box] }
ents = [RenameEnt.new('Cũ A'), RenameEnt.new('Cũ B', true), RenameEnt.new('Cũ C')]
recs = ents.each_with_index.map { |e, i| {entity: e, path: [e], locked: false, box: RBox.new(RPoint.new(i * 10.0, 0.0, 0.0))} }
rows = ents.each_with_index.map { |e, i| {index: i, name: e.name, definition: 'Họ', tag: 'Tủ', tag_group: 'Đồ rời'} }
rd = D.allocate
rd.instance_variable_set(:@model, $model)
rd.instance_variable_set(:@table_rows, rows)
rd.instance_variable_set(:@table_records, recs)
rcalls = []
rd.define_singleton_method(:emit) { |ev, payload| rcalls << [ev, payload] }
rd.define_singleton_method(:table_build) { rcalls << [:build] }
rd.define_singleton_method(:show_outline) { rcalls << [:outline] }
rd.rename_preview({'template' => 'Tủ-{số}', 'pad' => 0})
plan = rcalls.last[1]
ok('xem trước: gửi kế hoạch về giao diện', rcalls.last[0] == 'rename_preview' && plan[:rows].map { |r| r[:new] } == ['Tủ-1', 'Cũ B', 'Tủ-2'])
ok('xem trước: không sửa tên nào', ents.map(&:name) == ['Cũ A', 'Cũ B', 'Cũ C'] && $transactions.empty?)
ok('xem trước: đối tượng khóa được báo', plan[:rows][1][:status] == 'locked' && plan[:counts][:locked] == 1)
rcalls.clear
rd.rename_apply({'template' => 'Tủ-{số}', 'pad' => 0})
ok('áp dụng: đổi tên các đối tượng không khóa', ents.map(&:name) == ['Tủ-1', 'Cũ B', 'Tủ-2'])
ok('áp dụng: chỉ một bước hoàn tác cho cả đợt', $transactions == ['VGD_BIM · Đổi tên hàng loạt'])
ok('áp dụng: bảng đọc lại và báo kết quả', rcalls.any? { |c| c[0] == :build } && rcalls.any? { |c| c[0] == 'message' && c[1][:text].include?('2') })
rcalls.clear
$transactions.clear
bad = ->(payload) { begin; rd.rename_apply(payload); nil; rescue StandardError => e; e.message; end }
ok('áp dụng khi không có gì để đổi: báo lỗi, không mở bước hoàn tác', bad.call({'template' => '{tên}'}).to_s.match?(/[À-ỹ]/) && $transactions.empty?)
ents[0].instance_variable_set(:@valid, false)
ok('áp dụng khi đối tượng không còn: báo lỗi, không đổi gì', bad.call({'template' => 'Mới-{số}'}).to_s.include?('không còn') && $transactions.empty? && ents[2].name == 'Tủ-2')
ok('áp dụng với dữ liệu sai: báo lỗi tiếng Việt', bad.call({'order' => 'lạ'}).to_s.include?('Thứ tự'))

# Chọn nhiều dòng trong bảng (Shift / Ctrl như Excel): SketchUp chọn theo, đổi tên chỉ áp cho các dòng đã chọn
class PickSel
  attr_reader :items
  def initialize; @items = []; end
  def clear; @items.clear; end
  def add(*entities); @items.concat(entities.flatten); end
  def to_a; @items.dup; end
end
# Camera giả: chỉ có phần API được dùng (direction / up / perspective? / fov / fov_is_height? / set / height=)
class PickCamera
  attr_reader :set_args, :height
  def direction; Geom::Vector3d.new(0, 1, 0); end
  def up; Geom::Vector3d.new(0, 0, 1); end
  def perspective?; true; end
  def fov; 35.0; end
  def fov_is_height?; false; end
  def set(eye, target, up); @set_args = [eye.to_a, target.to_a, up.to_a]; end
  def height=(value); @height = value; end
end
class PickView
  attr_reader :camera, :assigned
  def initialize; @camera = PickCamera.new; end
  def vpwidth; 1000; end
  def vpheight; 500; end
  def camera=(value); @assigned = value; end
  def invalidate; end
  def zoom(*); raise 'View#zoom không được dùng để thu phóng tới món trong bảng'; end
end
class PickModel
  attr_reader :selection, :active_view
  attr_accessor :active_path
  def initialize; @selection = PickSel.new; @active_view = PickView.new; @active_path = []; end
end
# Hộp bao thế giới để thu phóng (mô phỏng phần API dùng: BoundingBox#add / empty?, Point3d#transform, định nghĩa có bounds.corner(i))
module Geom
  class BoundingBox
    attr_reader :points
    def initialize; @points = []; end
    def add(point); @points << point; end
    def empty?; @points.empty?; end
    def min; WPoint.new(*%i[x y z].map { |axis| @points.map(&axis).min }); end
    def max; WPoint.new(*%i[x y z].map { |axis| @points.map(&axis).max }); end
  end
  class Point3d; attr_reader :to_a; def initialize(*xyz); @to_a = xyz.map(&:to_f); end; end
  class Vector3d < Point3d; end
  # Biến đổi chỉ gồm tịnh tiến (đủ để kiểm tra việc nhân biến đổi của các group cha)
  class Transformation
    attr_reader :shift
    def initialize(shift = [0.0, 0.0, 0.0]); @shift = shift.map(&:to_f); end
    def *(other); Transformation.new(@shift.zip(other.shift).map { |a, b| a + b }); end
    def to_a; [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, *@shift, 1.0]; end
  end
end
WPoint = Struct.new(:x, :y, :z) { def transform(shift); WPoint.new(x + shift[0], y + shift[1], z + shift[2]); end; def to_a; [x, y, z]; end }
class WLocalBounds; def empty?; false; end; def corner(i); WPoint.new(i & 1, (i >> 1) & 1, (i >> 2) & 1); end; end
WDefinition = Struct.new(:bounds)
WEntities = Struct.new(:parent)
# Đối tượng chọn phải là Sketchup::Group để Data.supported? nhận
class PickEnt < Sketchup::Group
  attr_accessor :name
  def entities; WEntities.new(WDefinition.new(WLocalBounds.new)); end
  def initialize(name); @name = name; end
  def valid?; true; end
  def locked?; false; end
end
ORIGINAL_MODEL = $model
pm = PickModel.new
$model = pm
parent = RenameEnt.new('Cha')
other_parent = RenameEnt.new('Cha khác')
pents = [PickEnt.new('P0'), PickEnt.new('P1'), PickEnt.new('P2'), PickEnt.new('P3')]
precs = [
  {entity: pents[0], path: [parent, pents[0]], locked: false, transform: [500.0 + 0, 20.0, 0.0], box: RBox.new(RPoint.new(0.0, 0.0, 0.0))},
  {entity: pents[1], path: [parent, pents[1]], locked: false, transform: [500.0 + 1, 20.0, 0.0], box: RBox.new(RPoint.new(1.0, 0.0, 0.0))},
  {entity: pents[2], path: [parent, pents[2]], locked: false, transform: [500.0 + 2, 20.0, 0.0], box: RBox.new(RPoint.new(2.0, 0.0, 0.0))},
  {entity: pents[3], path: [other_parent, pents[3]], locked: false, transform: [500.0 + 3, 20.0, 0.0], box: RBox.new(RPoint.new(3.0, 0.0, 0.0))}
]
prows = pents.each_with_index.map { |e, i| {index: i, name: e.name, definition: 'Họ', tag: '', tag_group: ''} }
pd = D.allocate
pd.instance_variable_set(:@model, pm)
pd.instance_variable_set(:@table_rows, prows)
pd.instance_variable_set(:@table_records, precs)
pd.instance_variable_set(:@table_options, {zoom: true, isolate: false, deep: false})
pd.instance_variable_set(:@isolated, [])
pcalls = []
pd.define_singleton_method(:emit) { |ev, payload| pcalls << [ev, payload] }
pd.define_singleton_method(:show_outline) { pcalls << [:outline] }
pd.define_singleton_method(:table_build) { pcalls << [:build] }
pd.define_singleton_method(:table_scan_selection!) { pcalls << [:scan] }
pd.table_select({'indexes' => [0, 2], 'field' => 'instance'})
ok('chọn nhiều dòng cùng cấp: SketchUp chọn đúng các đối tượng đó', pm.selection.to_a == [pents[0], pents[2]] && pm.active_path == [parent])
ok('chọn nhiều dòng: nhớ các dòng đã chọn trong bảng', pd.instance_variable_get(:@picked_entities) == [pents[0], pents[2]])
ok('chọn nhiều dòng: bỏ qua ô đã bấm (không có khung tên theo ô)', pd.instance_variable_get(:@outline_field).nil?)
cam = pm.active_view.camera
eye, target, up = cam.set_args
ok('chọn nhiều dòng: camera nhìn vào tâm hộp bao thế giới của các đối tượng đã chọn (501,5; 20,5; 0,5), không phải tọa độ cục bộ gần gốc',
   target == [501.5, 20.5, 0.5] && up == [0.0, 0.0, 1.0] && pm.active_view.assigned.equal?(cam))
ok('chọn nhiều dòng: mắt lùi sau tâm theo hướng nhìn cũ (cùng x, z với tâm, y nhỏ hơn)', eye[0] == 501.5 && eye[2] == 0.5 && eye[1] < 20.5)
# Ngữ cảnh lúc quét được nhớ: bấm dòng con làm active_path đổi, nhưng dựng lại bảng vẫn dùng ngữ cảnh lúc quét
parent.define_singleton_method(:transformation) { Geom::Transformation.new([5, 0, 0]) }
other_parent.define_singleton_method(:transformation) { Geom::Transformation.new([7, 0, 0]) }
pm.define_singleton_method(:edit_transform) { Geom::Transformation.new([5, 0, 0]) }
pm.active_path = [parent]
pcalls.clear
D.instance_method(:table_scan_selection!).bind(pd).call # bản thật (pd đã thay bằng bản giả ở trên)
pm.active_path = [other_parent, parent]
ctx_saved = pd.scan_context
ok('quét ghi nhớ ngữ cảnh (group đang mở và biến đổi) tại thời điểm quét', ctx_saved && ctx_saved[:path] == [parent] && ctx_saved[:transform].to_a == Geom::Transformation.new([5, 0, 0]).to_a && pcalls.none? { |c| c[0] == 'message' })
# Model#edit_transform báo sai (ví dụ đơn vị trong khi group cha đã dời 5): dùng tích biến đổi của các group trong active_path và báo một lần
pm.define_singleton_method(:edit_transform) { Geom::Transformation.new }
pm.active_path = [other_parent, parent]
D.instance_method(:table_scan_selection!).bind(pd).call
mismatch_ctx = pd.instance_variable_get(:@table_context)
ok('edit_transform khác tích biến đổi của group đang mở: dùng tích (7 + 5 = 12), không dùng edit_transform', mismatch_ctx[:transform].to_a[12, 3] == [12.0, 0.0, 0.0] && mismatch_ctx[:path] == [other_parent, parent])
ok('edit_transform khác tích: có báo cho người dùng một lần', pcalls.count { |c| c[0] == 'message' && c[1][:text].to_s.include?('Lưu ý') } == 1)
D.instance_method(:table_scan_selection!).bind(pd).call
ok('quét lại cùng ngữ cảnh: không báo lặp', pcalls.count { |c| c[0] == 'message' && c[1][:text].to_s.include?('Lưu ý') } == 1)
pm.define_singleton_method(:edit_transform) { Geom::Transformation.new }
pm.active_path = []
D.instance_method(:table_scan_selection!).bind(pd).call
ok('không mở group nào: giữ edit_transform của SketchUp (đơn vị)', pd.instance_variable_get(:@table_context)[:transform].to_a == Geom::Transformation.new.to_a)
pm.define_singleton_method(:edit_transform) { Geom::Transformation.new([5, 0, 0]) }
pm.active_path = [parent]
D.instance_method(:table_scan_selection!).bind(pd).call # lại ngữ cảnh [parent] như trước đoạn kiểm tra trên
pm.active_path = [other_parent, parent]
ok('đổi ngữ cảnh đang mở sau đó (mở sâu vào dòng con): dựng bảng vẫn dùng ngữ cảnh đã nhớ', pd.scan_context[:path] == [parent])
parent.instance_variable_set(:@valid, false)
ok('group của ngữ cảnh đã nhớ không còn tồn tại: không dùng (để Table.build lấy ngữ cảnh đang mở)', pd.scan_context.nil?)
parent.instance_variable_set(:@valid, true)
pm.active_path = [parent]
pd.instance_variable_set(:@table_picks, [pents[0], pents[2]]) # quét thật đã xóa lựa chọn nhớ; trả lại như trước đoạn này
pd.instance_variable_set(:@picked_entities, [pents[0], pents[2]])

pcalls.clear
pd.table_selection_changed
ok('SketchUp báo đã chọn đúng các đối tượng bảng vừa chọn: không quét lại, không đổi bảng, không đổi đánh dấu dòng',
   pcalls.none? { |c| c[0] == :build || c[0] == :scan || c[0] == 'highlight' } && pcalls.any? { |c| c[0] == :outline })
pd.table_select({'indexes' => [1, 3]})
ok('chọn các dòng ở cấp lồng khác nhau: SketchUp chỉ chọn dòng cuối, bảng vẫn nhớ cả hai dòng', pm.selection.to_a == [pents[3]] && pd.instance_variable_get(:@picked_entities) == [pents[1], pents[3]])
ok('chọn các dòng ở cấp lồng khác nhau: có báo cho người dùng', pcalls.any? { |c| c[0] == 'message' && c[1][:text].to_s.include?('cấp') })
pm.selection.clear
pm.selection.add(pents[1])
pd.instance_variable_set(:@table_picks, [pents[3]])
pcalls.clear
pd.table_selection_changed
ok('chọn đối tượng khác ngoài bảng trong SketchUp: quét lại và làm mới bảng', pcalls.any? { |c| c[0] == :scan } && pcalls.any? { |c| c[0] == :build })
bad_select = ->(payload) { begin; pd.table_select(payload); nil; rescue StandardError => e; e.message; end }
ok('chọn dòng không có trong bảng: báo bảng đã cũ', bad_select.call({'indexes' => [9]}).to_s.include?('cũ'))
ok('không có dòng nào được gửi lên: báo lỗi tiếng Việt', bad_select.call({'indexes' => []}).to_s.match?(/[À-ỹ]/))
ok('chỉ số không phải số: báo lỗi', bad_select.call({'indexes' => ['x']}).to_s.match?(/[À-ỹ]/))

$model = ORIGINAL_MODEL

# Đổi tên chỉ cho các dòng đã chọn trong bảng
$transactions.clear
rd.define_singleton_method(:table_build) { }
rd.instance_variable_get(:@table_records).each_with_index { |r, i| r[:entity].name = "Cũ #{('A'.ord + i).chr}" }
rd.instance_variable_set(:@table_rows, rd.instance_variable_get(:@table_records).each_with_index.map { |r, i| {index: i, name: r[:entity].name, definition: 'Họ', tag: 'Tủ', tag_group: 'Đồ rời'} })
ents[1].instance_variable_set(:@locked, false)
ents[0].instance_variable_set(:@valid, true)
rcalls.clear
rd.rename_preview({'template' => 'Chọn-{số}', 'pad' => 0, 'indexes' => [2, 0]})
scoped = rcalls.last[1]
ok('đổi tên theo dòng đã chọn: chỉ các dòng đó vào kế hoạch', scoped[:rows].map { |r| r[:index] } == [0, 2])
ok('đổi tên theo dòng đã chọn: số thứ tự chỉ tính trong các dòng đã chọn', scoped[:rows].map { |r| r[:new] } == %w[Chọn-1 Chọn-2])
rd.rename_apply({'template' => 'Chọn-{số}', 'pad' => 0, 'indexes' => [2, 0]})
ok('đổi tên theo dòng đã chọn: dòng không chọn giữ nguyên tên', ents.map(&:name) == ['Chọn-1', 'Cũ B', 'Chọn-2'])
rcalls.clear
rd.rename_preview({'template' => 'Tất-{số}', 'pad' => 0})
ok('không chọn dòng nào: áp cho mọi dòng trong bảng', rcalls.last[1][:rows].map { |r| r[:index] } == [0, 1, 2])
bad_rename = ->(payload) { begin; rd.rename_preview(payload); nil; rescue StandardError => e; e.message; end }
ok('đổi tên: chỉ số dòng không có trong bảng bị từ chối', bad_rename.call({'indexes' => [7]}).to_s.match?(/[À-ỹ]/))
ok('đổi tên: chỉ số không phải số bị từ chối', bad_rename.call({'indexes' => ['a']}).to_s.match?(/[À-ỹ]/))

# Sửa ô bằng nhấp đúp: tên, mô tả, tình trạng, tag, vật liệu; áp cho nhiều dòng một lúc, một bước hoàn tác
class EditLayer; attr_reader :name; def initialize(name); @name = name; end; end
class EditLayers < Array
  def add(name); layer = EditLayer.new(name); push(layer); layer; end
end
class EditMat; attr_reader :display_name; def initialize(name); @display_name = name; end; end
class EditEnt < Sketchup::Group
  attr_accessor :name, :layer, :material
  def initialize(name, locked = false); @name = name; @locked = locked; end
  def valid?; true; end
  def locked?; @locked; end
  def attrs; @attrs ||= {}; end
  def set_attribute(dict, key, value); (attrs[dict] ||= {})[key] = value; end
  def delete_attribute(dict, key); (attrs[dict] || {}).delete(key); end
end
class EditModel
  attr_reader :layers, :materials
  def initialize
    @layers = EditLayers.new([EditLayer.new('Untagged'), EditLayer.new('000 CUA'), EditLayer.new('000 TUONG')])
    @materials = [EditMat.new('Gỗ sồi'), EditMat.new('Sơn trắng')]
  end
end
em = EditModel.new
$model = em
eents = [EditEnt.new('E0'), EditEnt.new('E1', true), EditEnt.new('E2')]
erecs = eents.map { |e| {entity: e, path: [e], locked: false} }
erows = eents.each_with_index.map { |e, i| {index: i, name: e.name, definition: 'Họ', tag: '', tag_group: ''} }
ed = D.allocate
ed.instance_variable_set(:@model, em)
ed.instance_variable_set(:@table_rows, erows)
ed.instance_variable_set(:@table_records, erecs)
ecalls = []
ed.define_singleton_method(:emit) { |ev, payload| ecalls << [ev, payload] }
ed.define_singleton_method(:table_build) { ecalls << [:build] }
ed.define_singleton_method(:show_outline) { ecalls << [:outline] }
choices = ed.table_choices
ok('danh sách chọn tag: tag của model và bộ tag, bỏ Untagged, không trùng, sắp theo tên', choices[:tags] == ['000 CUA', '000 TUONG', 'Trong bộ'])
ok('danh sách chọn vật liệu: tên vật liệu của model, sắp theo tên', choices[:materials] == ['Gỗ sồi', 'Sơn trắng'])
$transactions.clear
ed.table_edit({'indexes' => [0, 1, 2], 'field' => 'name', 'value' => '  Cửa  '})
ok('sửa tên nhiều dòng: đổi các đối tượng không khóa, bỏ qua đối tượng khóa', eents.map(&:name) == ['Cửa', 'E1', 'Cửa'])
ok('sửa nhiều dòng: một bước hoàn tác', $transactions == ['VGD_BIM · Sửa bảng'])
ok('sửa nhiều dòng: bảng đọc lại và báo kết quả có số đối tượng bị khóa', ecalls.any? { |c| c[0] == :build } && ecalls.any? { |c| c[0] == 'message' && c[1][:text].include?('2') && c[1][:text].include?('khóa') })
ed.table_edit({'indexes' => [0, 2], 'field' => 'tag', 'value' => '000 CUA'})
ok('đổi tag sang tag có sẵn: dùng đúng tag đó', eents[0].layer.name == '000 CUA' && eents[2].layer.equal?(em.layers[1]))
ed.table_edit({'indexes' => [0], 'field' => 'tag', 'value' => 'A. DOOR'})
ok('đổi tag sang tag chưa có: tạo tag mới trong model', eents[0].layer.name == 'A. DOOR' && em.layers.map(&:name).include?('A. DOOR'))
ed.table_edit({'indexes' => [0], 'field' => 'tag', 'value' => ''})
ok('xóa tag: về Untagged', eents[0].layer.equal?(em.layers[0]))
ed.table_edit({'indexes' => [0, 2], 'field' => 'material', 'value' => 'Gỗ sồi'})
ok('đổi vật liệu: gán đúng vật liệu của model', eents[0].material.equal?(em.materials[0]) && eents[2].material.equal?(em.materials[0]))
ed.table_edit({'indexes' => [0], 'field' => 'material', 'value' => ''})
ok('bỏ vật liệu: về không vật liệu', eents[0].material.nil?)
$writes.clear
ed.table_edit({'indexes' => [0, 2], 'field' => 'status', 'value' => 'existing'})
ok('đổi tình trạng: ghi vào dữ liệu VGD của từng đối tượng', $writes.map { |w| [w[0], w[1]] } == [[eents[0], {status: 'existing'}], [eents[2], {status: 'existing'}]])
$writes.clear
ed.table_edit({'index' => 0, 'field' => 'description', 'value' => 'Cửa đi'})
ok('còn nhận gửi một dòng bằng index (cách cũ)', $writes.map { |w| w[1] } == [{description: 'Cửa đi'}])
bad_edit = ->(payload) { begin; ed.table_edit(payload); nil; rescue StandardError => e; e.message; end }
ok('vật liệu không có trong model: báo lỗi, không đổi gì', bad_edit.call({'indexes' => [0], 'field' => 'material', 'value' => 'Không có'}).to_s.include?('Vật liệu') && eents[0].material.nil?)
ok('ô không sửa được: báo lỗi tiếng Việt', bad_edit.call({'indexes' => [0], 'field' => 'lenX', 'value' => '5'}).to_s.match?(/[À-ỹ]/))
ok('tên tag không hợp lệ: báo lỗi', bad_edit.call({'indexes' => [0], 'field' => 'tag', 'value' => 'untagged'}).to_s.include?('Untagged'))
ok('chỉ có đối tượng khóa: báo lỗi, không mở bước hoàn tác', (($transactions.clear) && bad_edit.call({'indexes' => [1], 'field' => 'name', 'value' => 'Z'}).to_s.include?('khóa')) && $transactions.empty?)
ok('không gửi dòng nào: báo lỗi', bad_edit.call({'indexes' => [], 'field' => 'name', 'value' => 'Z'}).to_s.match?(/[À-ỹ]/))
# Cột mới sửa được: Hãng ghi vào dữ liệu VGD, Link / Cỡ / Đơn giá ghi vào dictionary riêng của bảng
$writes.clear
ed.table_edit({'indexes' => [0, 2], 'field' => 'owner', 'value' => 'Hafele'})
ok('sửa Hãng: ghi vào trường manufacturer của dữ liệu VGD', $writes.map { |w| w[1] } == [{manufacturer: 'Hafele'}, {manufacturer: 'Hafele'}])
$writes.clear
ed.table_edit({'indexes' => [0, 2], 'field' => 'url', 'value' => 'https://vgd.vn/tu'})
ed.table_edit({'indexes' => [0], 'field' => 'size', 'value' => '1200x600'})
ed.table_edit({'indexes' => [0, 2], 'field' => 'price', 'value' => '1500000'})
ok('sửa Link / Cỡ / Đơn giá: ghi vào dictionary riêng, không đụng dữ liệu VGD', $writes.empty? && eents[0].attrs['VGD_BIM_TABLE'] == {'url' => 'https://vgd.vn/tu', 'size' => '1200x600', 'price' => 1_500_000.0} && eents[2].attrs['VGD_BIM_TABLE'] == {'url' => 'https://vgd.vn/tu', 'price' => 1_500_000.0})
ok('đối tượng khóa không bị ghi Link / Đơn giá', eents[1].attrs.empty?)
ok('Link sai bị từ chối, đối tượng không đổi', bad_edit.call({'indexes' => [0], 'field' => 'url', 'value' => 'javascript:alert(1)'}).to_s.include?('Link') && eents[0].attrs['VGD_BIM_TABLE']['url'] == 'https://vgd.vn/tu')
ok('Đơn giá sai bị từ chối, đối tượng không đổi', bad_edit.call({'indexes' => [0], 'field' => 'price', 'value' => '1.500.000'}).to_s.include?('Đơn giá') && eents[0].attrs['VGD_BIM_TABLE']['price'] == 1_500_000.0)
ed.table_edit({'indexes' => [0], 'field' => 'price', 'value' => ''})
ok('xóa Đơn giá: bỏ khỏi dictionary', !eents[0].attrs['VGD_BIM_TABLE'].key?('price'))

# Thay thế hàng loạt chữ trong Tên / Mô tả / Hãng / Cỡ
rrows = eents.each_with_index.map { |e, i| {index: i, name: ['Tủ cũ', 'Tủ cũ', 'Bàn'][i], description: ['Gỗ TỦ', '', 'x'][i], owner: '', size: ['', '', ''][i]} }
ed.instance_variable_set(:@table_rows, rrows)
$writes.clear
$transactions.clear
eents.each { |e| e.name = rrows[eents.index(e)][:name] }
ed.table_replace({'find' => 'tủ', 'replace' => 'Cửa', 'fields' => %w[name description]})
ok('thay thế: không phân biệt hoa thường, đổi tên và mô tả, bỏ qua đối tượng khóa', eents.map(&:name) == ['Cửa cũ', 'Tủ cũ', 'Bàn'] && $writes.map { |w| w[1] } == [{description: 'Gỗ Cửa'}])
ok('thay thế: cả đợt là một bước hoàn tác', $transactions == ['VGD_BIM · Thay thế'])
ok('thay thế: báo số ô đã đổi', ecalls.any? { |c| c[0] == 'message' && c[1][:text].include?('Đã thay') && c[1][:text].include?('2') })
$writes.clear
eents[0].name = 'Tủ'; eents[2].name = 'Tủ'; rrows[0][:name] = 'Tủ'; rrows[2][:name] = 'Tủ'
ed.table_replace({'find' => 'Tủ', 'replace' => 'a\\0b$1', 'fields' => %w[name], 'indexes' => [2]})
ok('thay thế: chuỗi thay được hiểu nguyên văn (không phải mẫu biểu thức), chỉ áp cho dòng gửi lên', eents[2].name == 'a\\0b$1' && eents[0].name == 'Tủ')
rrows[2][:name] = 'Bàn'
bad_replace = ->(payload) { begin; ed.table_replace(payload); nil; rescue StandardError => e; e.message; end }
ok('thay thế: chữ cần tìm rỗng bị từ chối', bad_replace.call({'find' => '', 'replace' => 'x', 'fields' => %w[name]}).to_s.include?('chữ cần tìm'))
ok('thay thế: chữ cần tìm quá dài bị từ chối', bad_replace.call({'find' => 'a' * 201, 'replace' => 'x', 'fields' => %w[name]}).to_s.include?('quá dài'))
ok('thay thế: cột không cho phép bị từ chối (chỉ Tên, Mô tả, Xuất xứ, Quy cách)', bad_replace.call({'find' => 'a', 'replace' => 'x', 'fields' => %w[tag]}).to_s.include?('cột'))
ok('thay thế: không có ô nào khớp thì báo, không mở bước hoàn tác', (($transactions.clear) && bad_replace.call({'find' => 'zzzz', 'replace' => 'x', 'fields' => %w[name]}).to_s.include?('Không có ô nào')) && $transactions.empty?)

# Mở link: chỉ http / https
opened = []
Object.const_set(:UI, Module.new) unless defined?(::UI)
::UI.define_singleton_method(:openURL) { |url| opened << url }
ok('mở link hợp lệ bằng trình duyệt', (ed.open_url('https://vgd.vn/tu'); opened == ['https://vgd.vn/tu']))
ok('không mở link lạ (javascript:, file:, rỗng)', ['javascript:alert(1)', 'file:///C:/x', '', 'vgd.vn'].all? { |u| bad = (ed.open_url(u) rescue :error); true } && opened == ['https://vgd.vn/tu'])

# Công tắc Diện tích chiếu: bật thì đọc lại bảng
ed.instance_variable_set(:@table_options, {zoom: true, isolate: false, deep: false, projected: false})
ed.instance_variable_set(:@isolated, [])
ecalls.clear
ed.table_option({'projected' => true})
ok('bật Diện tích chiếu: lưu tuỳ chọn và đọc lại bảng', ed.instance_variable_get(:@table_options)[:projected] == true && ecalls.any? { |c| c[0] == :build })
# Preset: lưu kèm tiêu đề và thiết lập, nhập / xuất file JSON qua hộp chọn file
Object.const_set(:UI, Module.new) unless defined?(::UI)
$picked = nil
::UI.define_singleton_method(:openpanel) { |*_args| $picked }
::UI.define_singleton_method(:savepanel) { |*_args| $picked }
ecalls.clear
ed.table_preset({'action' => 'save', 'name' => 'Của tôi', 'group' => '', 'columns' => %w[ordinal instance price], 'headers' => {'price' => 'Giá'}, 'settings' => {'length_unit' => 'cm'}, 'silent' => true})
mine = VGD::BIM::Table.custom_presets.find { |p| p['name'] == 'Của tôi' }
ok('lưu preset: kèm tiêu đề và thiết lập, gửi lại danh sách preset', mine && mine['headers'] == {'price' => 'Giá'} && mine['settings']['length_unit'] == 'cm' && ecalls.any? { |c| c[0] == 'presets' && c[1].any? { |p| p['name'] == 'Của tôi' && p['builtin'] == false } })
ok('lưu preset thiết lập sai: báo lỗi, không lưu', bad_edit.call(nil) || (begin; ed.table_preset({'action' => 'save', 'name' => 'Hỏng', 'group' => '', 'columns' => %w[instance], 'settings' => {'length_unit' => 'km'}}); false; rescue ArgumentError; true; end) && VGD::BIM::Table.custom_presets.none? { |p| p['name'] == 'Hỏng' })
export_path = File.join(Dir.mktmpdir('vgd_bim_export'), 'presets.json')
$picked = export_path
ed.table_preset({'action' => 'export'})
exported = JSON.parse(File.read(export_path, encoding: 'UTF-8'))
ok('xuất preset: ghi file JSON định dạng riêng có preset tự tạo', exported['format'] == 'VGD_BIM_PRESETS' && exported['presets'].any? { |p| p['name'] == 'Của tôi' })
$picked = nil
ecalls.clear
ed.table_preset({'action' => 'export'})
ok('hủy hộp lưu file: không ghi, không báo lỗi', ecalls.none? { |c| c[0] == 'message' })
VGD::BIM::Table.delete_preset('Của tôi')
$picked = export_path
ed.table_preset({'action' => 'import'})
ok('nhập preset từ file vừa xuất: có lại preset và gửi danh sách mới', VGD::BIM::Table.custom_presets.any? { |p| p['name'] == 'Của tôi' } && ecalls.any? { |c| c[0] == 'message' && c[1][:text].include?('Đã nhập 1') })
ref_path = File.join(File.dirname(export_path), 'ref.json')
File.write(ref_path, JSON.generate('Phong' => {'columns' => {'instance' => true, 'lenX' => true}, 'settings' => {'formatLength' => 1, 'roundLength' => 2}}))
$picked = ref_path
ed.table_preset({'action' => 'import'})
ok('nhập preset định dạng của plugin tham khảo', VGD::BIM::Table.custom_presets.find { |p| p['name'] == 'Phong' }&.dig('settings', 'length_unit') == 'm')
File.write(ref_path, 'không phải json {')
bad_import = begin; ed.table_preset({'action' => 'import'}); nil; rescue StandardError => e; e.message; end
ok('nhập file không phải JSON: báo lỗi tiếng Việt, không đổi preset', bad_import.to_s.include?('JSON') && VGD::BIM::Table.custom_presets.size == 2)
File.write(ref_path, 'x' * (VGD::BIM::UI::Dialog::MAX_PRESET_FILE + 1))
big_import = begin; ed.table_preset({'action' => 'import'}); nil; rescue StandardError => e; e.message; end
ok('nhập file quá lớn: từ chối trước khi đọc', big_import.to_s.include?('quá lớn'))
VGD::BIM::Table.delete_preset('Phong'); VGD::BIM::Table.delete_preset('Của tôi')
ok('xuất khi chưa có preset tự tạo: báo lỗi rõ', (begin; ed.table_preset({'action' => 'export'}); false; rescue ArgumentError => e; e.message.include?('Chưa có preset'); end))
$model = ORIGINAL_MODEL

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
