require 'json'
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_test')
STORE = {}
module Sketchup
  class Group; def initialize(vol); @vol = vol; end; def volume; @vol; end; end
  class ComponentInstance; end
  class Face; end
  def self.read_default(section, key, default = nil); STORE.fetch([section, key], default); end
  def self.write_default(section, key, value); STORE[[section, key]] = value; true; end
end
module VGD; module BIM; def self.log(m); end; module Data; end; module Scanner; end; end; end
require File.expand_path('../runtime/vgd_bim/core/geometry', __dir__) # dùng Geometry.scales thật
ROOT = ARGV[0] || File.expand_path('../runtime/vgd_bim', __dir__)
require File.join(ROOT, 'core/locale')
require File.join(ROOT, 'core/schema')
require File.join(ROOT, 'core/tags')
%w[core/storage core/measure core/schema core/photo_settings core/quantity].each { |f| require File.join(ROOT, f) }
require File.join(ROOT, 'core/table')
T = VGD::BIM::Table
S = VGD::BIM::Schema
def check(label, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{label}"; end
def raises?(msg = nil); yield; false; rescue ArgumentError => e; msg ? e.message.include?(msg) : true; end

keys = T::COLUMN_KEYS
check 'có đủ cột kiểu Auto Info, cột Ảnh, cột Ảnh vị trí, 7 cột mới và 2 cột Mặt trước, 1 cột Ghi chú số đo, 5 cột Khối lượng tính, 2 cột Ảnh phụ (48 cột, không trùng)', keys.size == 48 && keys.uniq.size == keys.size && %w[calc_category calc_method calc_qty calc_unit calc_total].all? { |k| keys.include?(k) }
check 'mọi cột của preset có sẵn đều hợp lệ', T::BUILT_IN_PRESETS.all? { |p| p['columns'].all? { |c| keys.include?(c) } }
check 'preset có sẵn có nhóm hợp lệ', T::BUILT_IN_PRESETS.all? { |p| p['group'].empty? || VGD::BIM::Tags::GROUPS.include?(p['group']) }
check 'có 12 preset có sẵn, 4 preset BIM đứng đầu', T::BUILT_IN_PRESETS.size == 12 && T::BUILT_IN_PRESETS.first(4).map { |p| p['name'] } == ['Tất cả', 'Phần thô', 'Hoàn thiện', 'Đồ rời']
check 'Phần thô, Hoàn thiện, Đồ rời lọc đúng nhóm mới S. STRUCTURAL, A. ARCHITECTURAL, I. INTERIOR (nhóm cũ đã bỏ)', T::BUILT_IN_PRESETS[1..3].map { |p| p['group'] } == ['S. STRUCTURAL', 'A. ARCHITECTURAL', 'I. INTERIOR']
check 'cột giữ đúng thứ tự người dùng sắp xếp khi lưu preset', T.sanitize_preset('name' => 'x', 'group' => '', 'columns' => %w[quantity lenX ordinal])['columns'] == %w[quantity lenX ordinal]
check 'bỏ cột lạ khi lưu preset', T.sanitize_preset('name' => 'x', 'group' => '', 'columns' => %w[lenX abc])['columns'] == %w[lenX]
check 'từ chối preset không có cột', raises? { T.sanitize_preset('name' => 'x', 'group' => '', 'columns' => ['abc']) }
check 'từ chối tên preset rỗng', raises? { T.sanitize_preset('name' => '  ', 'group' => '', 'columns' => %w[lenX]) }
check 'từ chối tên preset quá 40 ký tự', raises? { T.sanitize_preset('name' => 'a' * 41, 'group' => '', 'columns' => %w[lenX]) }
check 'từ chối nhóm preset lạ', raises? { T.sanitize_preset('name' => 'x', 'group' => 'Lạ', 'columns' => %w[lenX]) }
check 'không lưu được preset trùng tên có sẵn', raises?('trùng') { T.save_preset('Phần thô', 'Phần thô', %w[lenX]) }
T.save_preset('Vách kính', 'Hoàn thiện', %w[instance areaFace quantity])
check 'lưu preset riêng rồi đọc lại được', T.custom_presets.map { |p| p['name'] } == ['Vách kính']
check 'danh sách preset có cả preset có sẵn và preset đã lưu', T.presets.size == 13 && T.presets.last['builtin'] == false
T.save_preset('Vách kính', 'Đồ rời', %w[instance quantity])
check 'lưu trùng tên thì ghi đè, không nhân đôi', T.custom_presets.size == 1 && T.custom_presets.first['group'] == 'I. INTERIOR'
T.delete_preset('Vách kính')
check 'xóa preset đã lưu', T.custom_presets.empty?

S_ok = S.normalize('status' => 'existing')
check 'trạng thái Hiện hữu được chấp nhận', S_ok[:status] == 'existing'
check 'trạng thái rỗng được chấp nhận (nghĩa là Mới)', S.normalize('status' => '')[:status] == ''
check 'trạng thái lạ bị từ chối', raises? { S.normalize('status' => 'bogus') }
check 'bộ 5 trạng thái đúng thứ tự', S::STATUSES == %w[new existing reuse temporary removed]
check 'nhãn 5 trạng thái đều có tiếng Việt', T::STATUS_LABELS.values == ['Mới', 'Hiện hữu', 'Dùng lại', 'Tạm thời', 'Loại bỏ']

# Thể tích: 1 ft³ = 1728 in³ = 0.0283168 m³ (nhân hệ số vị trí 1 nếu không phóng to)
identity = Struct.new(:to_a).new([1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0])
scaled2 = Struct.new(:to_a).new([2.0, 0, 0, 0, 0, 2.0, 0, 0, 0, 0, 2.0, 0, 0, 0, 0, 1.0]) # phóng to 2 lần mọi chiều
vol = T.solid_volume(Sketchup::Group.new(1728.0), identity)
check 'thể tích khối 1 ft³ ≈ 0.0283 m³', (vol - 0.0283).abs < 0.0001
check 'khối phóng to 2 lần mọi chiều: thể tích nhân 8 (0.2265 m³)', (T.solid_volume(Sketchup::Group.new(1728.0), scaled2) - 0.2265).abs < 0.0001
check 'khối không kín (âm) để trống thể tích', T.solid_volume(Sketchup::Group.new(-5.0), identity).nil?
check 'component không có thể tích (để trống)', T.solid_volume(Sketchup::ComponentInstance.new, identity).nil?
puts "Done"

# Lưu ra file JSON: tên có dấu và dấu ngoặc kép vẫn đọc lại đúng (lỗi preset biến mất ở beta 2).
T.save_preset('Tủ "bếp" trên', 'Đồ rời', %w[instance quantity])
check 'preset có dấu và ngoặc kép lưu rồi đọc lại đúng', T.custom_presets.map { |p| p['name'] } == ['Tủ "bếp" trên']
check 'preset nằm trong file JSON trên máy', File.exist?(File.join(ENV['VGD_BIM_DATA_DIR'], 'table_presets.json'))
T.delete_preset('Tủ "bếp" trên')
# Trạng thái bảng nằm trong settings.json cạnh file SketchUp (xem ModelSettings): mỗi file một thư mục, không có trạng thái chung trên máy.
SKT = Dir.mktmpdir('vgd_bim_skp_table')
class ViewModel
  attr_reader :path
  def initialize(path = nil); @path = path || ''; end
end
vm = ViewModel.new(File.join(SKT, 'chinh.skp'))
T.save_view_state({'preset' => 'Đồ rời', 'order' => %w[quantity abc lenX], 'visible' => %w[quantity], 'widths' => {'lenX' => 90, 'zzz' => 5}, 'hack' => 1}, vm)
v = T.view_state(vm)
check 'trạng thái bảng lưu và đọc lại, bỏ cột lạ', v['preset'] == 'Đồ rời' && v['order'] == %w[quantity lenX] && v['widths'] == {'lenX' => 90} && !v.key?('hack')
T.save_view_state({'group' => 'Đồ rời'}, vm)
check 'trạng thái bảng cũ lưu nhóm cũ: đọc ra nhóm mới (Đồ rời -> I. INTERIOR); nhóm mới giữ nguyên', T.view_state(vm)['group'] == 'I. INTERIOR' && (T.save_view_state({'group' => 'S. BEAM'}, vm); T.view_state(vm)['group'] == 'S. BEAM')
legacy_file = {'format' => 'VGD_BIM_PRESETS', 'version' => 1, 'presets' => [{'name' => 'Bản xuất cũ', 'group' => 'Thiết bị', 'columns' => %w[instance quantity]}]}
check 'nhập file preset xuất từ bản cũ (nhóm cũ Thiết bị): được nhận và đổi sang Q. EQUIPMENT', T.import_presets(legacy_file).first['group'] == 'Q. EQUIPMENT'
# Độ cao hàng (Ctrl + lăn chuột): số điểm ảnh trong giới hạn; giá trị lạ bị bỏ để không làm hỏng bảng
T.save_view_state({'rowHeight' => 120.4}, vm)
check 'độ cao hàng lưu và đọc lại (làm tròn)', T.view_state(vm)['rowHeight'] == 120
T.save_view_state({'rowHeight' => 99_999}, vm)
check 'độ cao hàng quá lớn bị kẹp về giới hạn trên', T.view_state(vm)['rowHeight'] == T::ROW_HEIGHT_MAX
T.save_view_state({'rowHeight' => 3}, vm)
check 'độ cao hàng quá nhỏ bị kẹp về giới hạn dưới', T.view_state(vm)['rowHeight'] == T::ROW_HEIGHT_MIN
T.save_view_state({'rowHeight' => 'cao', 'preset' => 'x'}, vm)
check 'độ cao hàng không phải số bị bỏ (về mặc định), không lỗi', !T.view_state(vm).key?('rowHeight') && T.view_state(vm)['preset'] == 'x'
T.save_view_state({'rowHeight' => 0}, vm)
check 'độ cao hàng 0 = theo mật độ hàng mặc định (lưu 0)', T.view_state(vm)['rowHeight'] == 0
# Khung bao quanh đối tượng (chỉ 8 góc của hộp, không duyệt mặt của đối tượng nên nhẹ khi chọn nhiều)
class BoxPoint
  attr_reader :x, :y, :z
  def initialize(x, y, z); @x = x; @y = y; @z = z; end
  def transform(shift); BoxPoint.new(@x + shift[0], @y + shift[1], @z + shift[2]); end
  def to_a; [@x, @y, @z]; end
end
class BoxBounds
  def initialize(w, d, h); @w = w; @d = d; @h = h; end
  def empty?; false; end
  # SketchUp: bit 1 = x, bit 2 = y, bit 4 = z (0 = nhỏ nhất, 1 = lớn nhất)
  def corner(i); BoxPoint.new((i & 1).zero? ? 0 : @w, (i & 2).zero? ? 0 : @d, (i & 4).zero? ? 0 : @h); end
end
module VGD::BIM::Geometry
  def self.definition(entity); entity; end
end
class BoxEntity; def bounds; BoxBounds.new(4.0, 3.0, 2.0); end; end
record = {entity: BoxEntity.new, transform: [10.0, 20.0, 30.0]}
edges = T.world_corners(record)
check 'khung bao: 12 cạnh, mỗi cạnh nối hai góc, tính theo vị trí thế giới', edges.size == 24 && edges.each_slice(2).all? { |a, b| (a.to_a.zip(b.to_a).count { |p, q| p != q }) == 1 } && edges.map(&:to_a).flatten.min >= 10.0
tris = T.box_triangles(record)
check 'tô khung: 12 tam giác (36 điểm), không duyệt mặt của đối tượng', tris.size == 36 && !T.respond_to?(:face_triangles)
area = tris.each_slice(3).sum do |a, b, c|
  u = [b.x - a.x, b.y - a.y, b.z - a.z]; v = [c.x - a.x, c.y - a.y, c.z - a.z]
  cross = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
  Math.sqrt(cross.sum { |n| n * n }) / 2.0
end
check 'tô khung: tổng diện tích bằng diện tích 6 mặt của hộp (4x3x2 -> 52)', (area - 52.0).abs < 1e-9
check 'tô khung: mọi điểm là góc của hộp', tris.all? { |pt| [[10.0, 14.0], [20.0, 23.0], [30.0, 32.0]].each_with_index.all? { |pair, i| pair.include?(pt.to_a[i]) } }
box_empty = Class.new { def bounds; Class.new { def empty?; true; end }.new; end }.new
check 'đối tượng rỗng: không có khung và không có tam giác', T.world_corners(entity: box_empty, transform: [0, 0, 0]).empty? && T.box_triangles(entity: box_empty, transform: [0, 0, 0]).empty?
# ---- Cột thêm tay (CustomColumns) trong preset và trạng thái bảng ----
cc = VGD::BIM::CustomColumns
custom_col = cc.add('label' => 'Mã vật tư', 'kind' => 'attribute', 'dictionary' => 'vgd', 'attribute' => 'ma')
check 'cột thêm tay: có trong danh sách cột gửi giao diện, khóa hợp lệ, không lẫn vào cột chuẩn', T.columns.last[:key] == custom_col['key'] && T.column_keys.include?(custom_col['key']) && !T::COLUMN_KEYS.include?(custom_col['key']) && T.columns.size == T::COLUMNS.size + 1
T.save_preset('Có cột tay', '', ['instance', custom_col['key']])
check 'preset lưu được cột thêm tay', T.custom_presets.find { |preset| preset['name'] == 'Có cột tay' }['columns'] == ['instance', custom_col['key']]
T.save_view_state({'order' => ['instance', custom_col['key'], 'khong_co'], 'visible' => [custom_col['key']], 'widths' => {custom_col['key'] => 150, 'khong_co' => 9}, 'headers' => {custom_col['key'] => 'Mã VT'}}, vm)
view = T.view_state(vm)
check 'trạng thái bảng giữ cột thêm tay (thứ tự, hiện, độ rộng, tiêu đề), bỏ khóa lạ', view['order'] == ['instance', custom_col['key']] && view['visible'] == [custom_col['key']] && view['widths'] == {custom_col['key'] => 150} && view['headers'][custom_col['key']] == 'Mã VT'
cc.remove(custom_col['key'])
check 'xóa cột thêm tay: preset và trạng thái bảng tự bỏ khóa đó, không lỗi', T.custom_presets.find { |preset| preset['name'] == 'Có cột tay' }.nil? || !T.custom_presets.find { |preset| preset['name'] == 'Có cột tay' }['columns'].include?(custom_col['key'])
check 'cột VGD ID có trong danh sách cột chuẩn, đứng sau cột Tên', T::COLUMN_KEYS.include?('vgd_id') && T::COLUMN_KEYS.index('vgd_id') == T::COLUMN_KEYS.index('instance') + 2 && T::COLUMN_KEYS.index('code') == T::COLUMN_KEYS.index('instance') + 1
# Trạng thái bảng riêng từng file SketchUp: mỗi file có settings.json riêng, file mới bắt đầu từ mặc định
view_a = ViewModel.new(File.join(SKT, 'a.skp')); view_b = ViewModel.new(File.join(SKT, 'b.skp'))
T.save_view_state({'preset' => 'Đồ rời', 'visible' => %w[instance], 'rowHeight' => 90}, view_a)
T.save_view_state({'preset' => 'Phần thô', 'visible' => %w[quantity], 'rowHeight' => 40}, view_b)
check 'trạng thái bảng: mỗi file giữ riêng (preset, cột hiện, độ cao hàng)', T.view_state(view_a).values_at('preset', 'visible', 'rowHeight') == ['Đồ rời', %w[instance], 90] && T.view_state(view_b).values_at('preset', 'visible', 'rowHeight') == ['Phần thô', %w[quantity], 40]
check 'trạng thái bảng nằm trong settings.json cạnh file SketchUp (a_VGD_BIM)', File.file?(File.join(SKT, 'a_VGD_BIM', 'settings.json')) && JSON.parse(File.read(File.join(SKT, 'a_VGD_BIM', 'settings.json')))['table_view']['preset'] == 'Đồ rời'
check 'file mới (chưa có settings.json) bắt đầu từ mặc định, không theo file dùng gần nhất', T.view_state(ViewModel.new(File.join(SKT, 'moi.skp'))) == {} && T.view_state(nil) == {}
check 'không còn trạng thái chung trên máy (table_view.json)', !File.exist?(File.join(ENV['VGD_BIM_DATA_DIR'], 'table_view.json'))
unsaved_view = ViewModel.new
T.save_view_state({'preset' => 'Đồ rời', 'rowHeight' => 77}, unsaved_view)
check 'file chưa lưu: trạng thái giữ trong phiên (chưa có thư mục), đọc lại được', T.view_state(unsaved_view).values_at('preset', 'rowHeight') == ['Đồ rời', 77]
unsaved_view.instance_variable_set(:@path, File.join(SKT, 'vua_luu.skp'))
check 'lưu file lần đầu: trạng thái trong phiên được ghi ra settings.json cạnh file', T.view_state(unsaved_view)['preset'] == 'Đồ rời' && File.file?(File.join(SKT, 'vua_luu_VGD_BIM', 'settings.json'))
File.write(File.join(SKT, 'a_VGD_BIM', 'settings.json'), JSON.generate('table_view' => {'rowHeight' => 99999, 'preset' => 'x'}))
check 'trạng thái đọc từ settings.json cũng được kiểm tra (cột lạ, độ cao quá lớn)', T.view_state(view_a)['rowHeight'] == T::ROW_HEIGHT_MAX
File.write(File.join(SKT, 'b_VGD_BIM', 'settings.json'), '{ không phải json')
check 'settings.json hỏng: bỏ qua, về mặc định, không lỗi', T.view_state(view_b) == {}
# Tâm đáy X, Y và cao độ đáy Z (mm) lấy từ MỘT lần tính hộp bao của món (base_point), không tính lại cho từng giá trị.
$bb_calls = 0
orig_bb = T.method(:bounding_box)
FakeBox = Struct.new(:min, :max) { def empty?; false; end }
T.define_singleton_method(:bounding_box) { |_rec| $bb_calls += 1; FakeBox.new(BoxPoint.new(10.0, 20.0, 30.0), BoxPoint.new(14.0, 23.0, 32.0)) }
base = T.base_point(record)
check 'cao độ đáy và tâm đáy: đúng mm (tâm X 304,8; tâm Y 546,1; đáy Z 762,0)', base == [304.8, 546.1, 762.0]
check 'cao độ đáy và tâm đáy: chỉ tính hộp bao một lần cho món', $bb_calls == 1
T.define_singleton_method(:bounding_box) { |rec| orig_bb.call(rec) }
puts 'Done'
