# Test đọc phần tử do VGD Structure dựng (core/structure_source.rb) và việc dùng số liệu đó trong bảng khối lượng: khối lượng đúng theo kích thước plugin ghi
# (không đoán từ khối bao), cách tính theo loại khi thiếu tag, tầng của plugin hiện khi món chưa gán tầng BIM, nhóm chứa và lưới trục không thành dòng,
# chọn nhóm chứa thì lấy phần tử bên trong; BIM đăng ký cung cấp `vgd_id` cho cầu nối. Chạy: ruby dev/test_structure_source.rb
require 'json'
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] ||= Dir.mktmpdir('vgd_bim_structure')
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end

module Sketchup
  class Group
    attr_accessor :name, :children, :transformation, :layer, :locked, :material
    def initialize(n, kids = []); @name = n; @children = kids; @transformation = Tr.new; @locked = false; @attrs = {}; end
    def valid?; true; end
    def locked?; @locked; end
    def entities; @children; end
    def entityID; object_id; end
    def persistent_id; object_id; end
    def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; self; end
    def get_attribute(dict, key, default = nil); (@attrs[dict] || {}).fetch(key, default); end
  end
  class ComponentInstance < Group; end
  class Face; end
  def self.read_default(*); nil; end
  def self.write_default(*); true; end
end
class Tr
  def *(_o); self; end
  def xaxis; Vec.new; end; def yaxis; Vec.new; end; def zaxis; Vec.new; end
  def to_a; [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0]; end
  class Vec; def length; 1.0; end; end
end
module VGD; module BIM
  VERSION = 'test'
  def self.log(_m); end
  module Data
    def self.supported?(e); e.is_a?(Sketchup::Group); end
    def self.read(_e); {status: '', description: ''}; end
  end
  module Scanner
    def self.walk(entities, transform, path, ancestors, material, locked, faces: true, &block)
      entities.each do |e|
        cur = path + [e]
        block.call(entity: e, transform: transform, path: cur, material: nil, locked: false)
        walk(e.entities, transform, cur, ancestors, material, locked, faces: faces, &block)
      end
    end
  end
  module Geometry
    # Khối bao giả lập của một tường chạy theo trục Y: lenX = bề dày (200) chứ không phải chiều dài, đúng cái bẫy mà số liệu của plugin sửa.
    def self.dimensions(e, _t, measure: nil); e.get_attribute('test', 'bbox') || {width: 1000.0, depth: 500.0, height: 2000.0}; end
    def self.definition(e); Defn.new(e); end
    def self.path_transform(_path); Tr.new; end # không có group đang mở: đơn vị
    def self.face_area(*); 0.0; end
    class Defn; def initialize(e); @e = e; end; def name; @e.name; end; def entities; @e.entities; end; def bounds; Box.new; end; def count_instances; 1; end; end
    class Box; def empty?; true; end; end
  end
  module Tags
    def self.load; []; end
    def self.key(n); n.to_s.downcase; end
    GROUPS = ['Phần thô'].freeze
  end
end; end
%w[core/storage core/measure core/schema core/photo_settings core/quantity].each { |f| require File.join(ROOT, f) }
require File.join(ROOT, 'core/table')
require File.join(ROOT, 'core/bridge')
require File.join(ROOT, 'core/vgd_id')
require File.join(ROOT, 'core/bridge_provider')
SS = VGD::BIM::StructureSource
Q = VGD::BIM::Quantity

def element(kind, dims, ref: 'sl_00000001:x', level: 'Tầng 1', type: 'T', bbox: nil)
  g = Sketchup::ComponentInstance.new("#{kind} #{ref}")
  g.set_attribute('VGD_BIM_SOURCE', 'plugin', 'vgd_structure').set_attribute('VGD_BIM_SOURCE', 'kind', kind).set_attribute('VGD_BIM_SOURCE', 'ref', ref)
  g.set_attribute('VGD_STRUCT', 'level', 'sl_00000001').set_attribute('VGD_STRUCT', 'level_name', level).set_attribute('VGD_STRUCT', 'type', type)
  g.set_attribute('VGD_STRUCT', 'dims', JSON.generate(dims))
  g.set_attribute('test', 'bbox', bbox) if bbox
  g
end
def container(kind, kids); g = Sketchup::Group.new("nhóm #{kind}", kids); g.set_attribute('VGD_STRUCT', 'kind', kind); g; end

# Nhận diện
col = element('column', {'w' => 300, 'd' => 300, 'height' => 3480})
ok('nhận ra phần tử của VGD Structure theo VGD_BIM_SOURCE (plugin và kind)', SS.element?(col) && !SS.element?(Sketchup::ComponentInstance.new('x')) && !SS.element?(Object.new))
other = Sketchup::ComponentInstance.new('y'); other.set_attribute('VGD_BIM_SOURCE', 'plugin', 'plugin_khac').set_attribute('VGD_BIM_SOURCE', 'kind', 'column')
room = Sketchup::ComponentInstance.new('r'); room.set_attribute('VGD_BIM_SOURCE', 'plugin', 'vgd_structure').set_attribute('VGD_BIM_SOURCE', 'kind', 'room')
ok('plugin khác hoặc loại không thuộc VGD Structure thì không phải phần tử (không đọc nhầm khối phòng)', !SS.element?(other) && !SS.element?(room))
ok('nhóm chứa (columns, beams, walls, slabs, ceilings) và lưới trục (grid) là container; phần tử thì không', %w[columns beams walls slabs ceilings grid].all? { |k| SS.container?(container(k, [])) } && !SS.container?(col) && !SS.container?(Sketchup::Group.new('g')))

# Số liệu
ok('cột 300 x 300 cao 3480: thể tích 0,3132 m³, diện tích mặt bằng 0,09 m², cao 3,48 m', SS.row_fields(col).values_at(:struct_volume, :struct_area, :struct_length) == [0.3132, 0.09, 3.48])
beam = element('beam', {'w' => 200, 'h' => 400, 'length' => 3900}, ref: 'sl_00000001:x:B:2-3')
ok('dầm 200 x 400 dài 3900: thể tích 0,312 m³, dài 3,9 m', SS.row_fields(beam).values_at(:struct_volume, :struct_length) == [0.312, 3.9])
wall = element('wall', {'thickness' => 200, 'height' => 3480, 'length' => 3150, 'under_beam' => false}, bbox: {width: 200.0, depth: 3150.0, height: 3480.0})
ok('tường dày 200 cao 3480 dài 3150 (không lỗ): diện tích mặt 10,962 m², thể tích 2,1924 m³, dài 3,15 m', SS.row_fields(wall).values_at(:struct_area, :struct_volume, :struct_length) == [10.962, 2.1924, 3.15])
holed = element('wall', {'thickness' => 200, 'height' => 3480, 'length' => 3900, 'under_beam' => false, 'openings' => 2, 'openings_area' => 3.33})
ok('tường có lỗ cửa 3,33 m²: diện tích trừ lỗ (13,572 - 3,33 = 10,242 m²), thể tích trừ lỗ (2,0484 m³)', SS.row_fields(holed).values_at(:struct_area, :struct_volume) == [10.242, 2.0484])
ok('lỗ cửa lớn hơn cả tường hoặc giá trị hỏng: bỏ qua phần trừ, không âm', SS.row_fields(element('wall', {'thickness' => 200, 'height' => 1000, 'length' => 1000, 'openings_area' => 99})).values_at(:struct_area) == [1.0] && SS.row_fields(element('wall', {'thickness' => 200, 'height' => 1000, 'length' => 1000, 'openings_area' => -5})).values_at(:struct_area) == [1.0] && SS.row_fields(element('wall', {'thickness' => 200, 'height' => 1000, 'length' => 1000, 'openings_area' => 'x'})).values_at(:struct_area) == [1.0])
door = element('door', {'w' => 900, 'h' => 2100, 'sill' => 0, 'thickness' => 200, 'wall' => 'x:B:2-3'}, ref: 'sl_00000001:op_00000001')
win = element('window', {'w' => 1200, 'h' => 1200, 'sill' => 900, 'thickness' => 200, 'wall' => 'x:B:2-3'})
ok('cửa đi 900 x 2100: diện tích lỗ 1,89 m², rộng 0,9 m, đếm theo cái; cửa sổ 1,2 x 1,2: 1,44 m²', SS.row_fields(door).values_at(:struct_kind, :struct_area, :struct_length) == ['door', 1.89, 0.9] && SS.row_fields(win).values_at(:struct_kind, :struct_area) == ['window', 1.44] && SS.default_method('door') == 'count' && SS.default_method('window') == 'count')
slab = element('slab', {'thickness' => 120, 'area' => 15.12, 'z_top' => 0})
ok('sàn dày 120, diện tích 15,12 m²: thể tích 1,8144 m³', SS.row_fields(slab).values_at(:struct_area, :struct_volume) == [15.12, 1.8144])
ceil = element('ceiling', {'thickness' => 9, 'area' => 14.0})
ok('trần dày 9, diện tích 14 m²: thể tích 0,126 m³', SS.row_fields(ceil).values_at(:struct_area, :struct_volume) == [14.0, 0.126])
f = SS.row_fields(wall)
ok('thêm tầng, mã vị trí, loại của plugin vào dòng', f[:struct_kind] == 'wall' && f[:struct_level] == 'Tầng 1' && f[:struct_level_id] == 'sl_00000001' && f[:struct_type] == 'T' && f[:struct_ref] == 'sl_00000001:x')
bad = {'thiếu' => {}, 'âm' => {'w' => -1, 'd' => 300, 'height' => 100}, 'không phải số' => {'w' => '300', 'd' => 300, 'height' => 3000}, 'quá lớn' => {'w' => 1e12, 'd' => 300, 'height' => 100}}
bad.each { |label, d| ok("kích thước hỏng bị bỏ (không có số liệu, không văng): #{label}", SS.row_fields(element('column', d)).values_at(:struct_volume).compact.empty?) }
broken = element('column', {}); broken.set_attribute('VGD_STRUCT', 'dims', '{không phải json')
ok('dims hỏng JSON hoặc không phải chuỗi: bỏ qua, không văng', SS.row_fields(broken)[:struct_volume].nil? && (broken.set_attribute('VGD_STRUCT', 'dims', 5); SS.row_fields(broken)[:struct_volume].nil?))
ok('đối tượng không phải phần tử: không thêm trường nào', SS.row_fields(Sketchup::Group.new('g')) == {})

# Khối lượng trong bảng
bad_wall = {lenX: 200.0, lenY: 3150.0, lenZ: 3480.0, areaXZ: 0.696}
ok('tường chạy theo Y: khối bao cho diện tích sai (0,696 m²) nhưng số liệu plugin cho đúng 10,962 m²', Q.amount('area', bad_wall) == [0.696, 'ước tính theo khối bao'] && Q.amount('area', bad_wall.merge(struct_area: 10.962)) == [10.962, nil])
ok('theo mét dài: ưu tiên chiều dài của plugin; theo thể tích: thể tích chính xác (không ghi chú ước tính)', Q.amount('length', bad_wall.merge(struct_length: 3.15)) == [3.15, nil] && Q.amount('volume', {lenX: 200.0, lenY: 3150.0, lenZ: 3480.0, struct_volume: 2.1924}) == [2.1924, nil])
ok('không có số liệu của plugin: giữ cách tính cũ (đúng như trước)', Q.amount('length', {lenX: 1200.0}) == [1.2, nil] && Q.amount('volume', {volume: 1.5}) == [1.5, nil])
tagged = Q.row_fields(bad_wall.merge(struct_kind: 'wall', struct_area: 10.962), 'A. WALL', 'A. ARCHITECTURAL', {}, {})
ok('tường có tag A. WALL: cách tính theo tag (diện tích), khối lượng dùng số liệu plugin 10,962 m²', tagged[:calc_method] == 'area' && tagged[:calc_qty] == 10.962 && tagged[:calc_source] == 'keyword')
untagged = Q.row_fields(bad_wall.merge(struct_kind: 'wall', struct_area: 10.962), '', 'Chưa phân loại', {}, {})
ok('tường mất tag: vẫn tính theo diện tích (cách tính theo loại), nguồn structure', untagged[:calc_method] == 'area' && untagged[:calc_qty] == 10.962 && untagged[:calc_source] == 'structure')
ok('cách tính theo loại: cột / dầm / sàn theo thể tích, trần theo diện tích', %w[column beam slab].all? { |k| SS.default_method(k) == 'volume' } && SS.default_method('ceiling') == 'area' && SS.default_method('xyz').nil?)
ok('món thường không có tag vẫn theo cái (không bị ảnh hưởng)', Q.row_fields({lenX: 1.0}, '', 'Chưa phân loại', {}, {})[:calc_method] == 'count')
ok('người dùng đặt cách tính riêng theo tag vẫn thắng cách tính theo loại', Q.row_fields(bad_wall.merge(struct_kind: 'wall', struct_area: 10.962), 'X', 'Chưa phân loại', {}, {Q.key('X') => 'count'})[:calc_method] == 'count')

# Bảng
m = Class.new { def active_path; []; end; def edit_transform; Tr.new; end }.new
cols_group = container('columns', [col, element('column', {'w' => 400, 'd' => 400, 'height' => 3000}, ref: 'sl_00000001:2-B')])
grid = container('grid', [Sketchup::Group.new('Ký hiệu trục 1')])
shallow = VGD::BIM::Table.build(m, [cols_group], false)[:rows]
ok('chọn nhóm chứa cột (không chọn sâu): các cột bên trong là dòng, nhóm chứa không thành dòng', shallow.size == 2 && shallow.none? { |r| r[:name].to_s.start_with?('nhóm') })
ok('dòng có số liệu của plugin và tầng của plugin (món chưa gán tầng BIM)', shallow[0][:struct_volume] == 0.3132 && shallow[0][:level] == 'Tầng 1' && shallow[1][:struct_volume] == 0.48 && shallow[0][:level_id] == '')
deep = VGD::BIM::Table.build(m, [cols_group, grid], true)[:rows]
ok('chọn sâu: nhóm chứa, lưới trục và ký hiệu bên trong lưới đều bị loại, chỉ còn 2 cột', deep.size == 2 && deep.all? { |r| r[:struct_kind] == 'column' })
only_grid = VGD::BIM::Table.build(m, [grid], false)[:rows]
ok('chọn riêng nhóm lưới trục (không sâu): không có dòng nào', only_grid.empty?)
ok('dòng bảng lấy khối lượng tính từ số liệu plugin (cột theo thể tích 0,3132 m³ vì tag mặc định, nguồn structure)', shallow[0][:calc_method] == 'volume' && shallow[0][:calc_qty] == 0.3132 && shallow[0][:calc_source] == 'structure')

# Cầu nối
prov = VGD::Bridge.provider_for('vgd_id')
ok('VGD_BIM đăng ký cung cấp vgd_id trong danh bạ cầu nối', prov && prov[:id] == 'vgd_bim' && prov[:info][:commands].key?('generate'))
ok('lệnh generate trả VGD ID hợp lệ, mỗi lần khác nhau', (a = VGD::Bridge.call('vgd_id', 'generate')) && VGD::BIM::VgdId.valid?(a) && a != VGD::Bridge.call('vgd_id', 'generate'))
VGD::BIM::BridgeProvider.register
ok('đăng ký lại (tải lại code) không nhân đôi', VGD::Bridge.providers.keys.count('vgd_bim') == 1)
puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
