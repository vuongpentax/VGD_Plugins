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
  module Data
    def self.supported?(e); e.is_a?(Sketchup::Group); end
    # Như Data.transaction thật: một bước hoàn tác cho cả khối
    def self.transaction(model, name = nil); $transactions << name; yield; end
  end
  module Scanner; end; module Geometry; INCH_MM = 25.4; end
  module Tags; GROUPS = ['Phần thô'].freeze; def self.load; []; end; def self.key(n); n.to_s.downcase; end; end
  module UI; end
end; end
$transactions = []
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
class PickView; attr_reader :zoomed; def zoom(target); @zoomed = target; end; end
class PickModel
  attr_reader :selection, :active_view
  attr_accessor :active_path
  def initialize; @selection = PickSel.new; @active_view = PickView.new; @active_path = []; end
end
# Đối tượng chọn phải là Sketchup::Group để Data.supported? nhận
class PickEnt < Sketchup::Group
  attr_accessor :name
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
  {entity: pents[0], path: [parent, pents[0]], locked: false, box: RBox.new(RPoint.new(0.0, 0.0, 0.0))},
  {entity: pents[1], path: [parent, pents[1]], locked: false, box: RBox.new(RPoint.new(1.0, 0.0, 0.0))},
  {entity: pents[2], path: [parent, pents[2]], locked: false, box: RBox.new(RPoint.new(2.0, 0.0, 0.0))},
  {entity: pents[3], path: [other_parent, pents[3]], locked: false, box: RBox.new(RPoint.new(3.0, 0.0, 0.0))}
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
ok('chọn nhiều dòng: thu phóng tới các đối tượng đã chọn', pm.active_view.zoomed == [pents[0], pents[2]])
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

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
