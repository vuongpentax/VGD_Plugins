ROOT = ARGV[0] || File.expand_path('../runtime/vgd_bim_lite', __dir__)
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
  module Data; def self.supported?(e); e.is_a?(Sketchup::Group); end; end
  module Scanner; end; module Geometry; end
  module Tags; GROUPS = ['Phần thô'].freeze; def self.load; []; end; def self.key(n); n.to_s.downcase; end; end
  module UI; end
end; end
require File.join(ROOT, 'core/table')
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
d.instance_variable_set(:@table_pick, :e)
class FakeSel; attr_accessor :items; def initialize; @items = []; end; def to_a; @items; end; end
class FakeModel; attr_reader :selection; def initialize; @selection = FakeSel.new; end; end
$model = FakeModel.new
d.instance_variable_set(:@model, $model)
d.table_selection_changed
ok('bấm vùng trống: không quét lại, không làm mới bảng', calls.none? { |c| c[0] == :build || c[0] == :scan })
ok('bấm vùng trống: bỏ đánh dấu dòng', calls.include?([:emit, 'highlight'] ) || calls.any? { |c| c[0] == 'highlight' && c[1] == {index: nil} })
ok('bấm vùng trống: xóa đánh dấu chọn', d.instance_variable_get(:@table_pick).nil?)

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

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
