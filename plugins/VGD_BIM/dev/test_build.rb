require 'json'
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] ||= Dir.mktmpdir('vgd_bim_build')
# Kiểm tra Table.build: chế độ mặc định (chỉ đối tượng đang chọn) và chế độ chọn sâu.
ROOT = ARGV[0] || File.expand_path('../runtime/vgd_bim', __dir__)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end

module Sketchup
  class Group; attr_accessor :name, :children, :transformation, :layer, :locked; def initialize(n, kids = []); @name = n; @children = kids; @transformation = Tr.new; @locked = false; end; def valid?; true; end; def locked?; @locked; end; def volume; 1.0; end; def entityID; object_id; end; def material; nil; end; def entities; @children; end; end
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
  def self.log(m); end
  module Data
    def self.supported?(e); e.is_a?(Sketchup::Group); end
    def self.read(_e); {status: '', description: ''}; end
  end
  module Scanner
    # Mô phỏng Scanner.walk đệ quy: gọi block cho mọi group lồng bên trong.
    def self.walk(entities, transform, path, ancestors, material, locked, faces: true, &block)
      entities.each do |e|
        cur = path + [e]
        block.call(entity: e, transform: transform, path: cur, material: nil, locked: false)
        walk(e.entities, transform, cur, ancestors, material, locked, faces: faces, &block)
      end
    end
  end
  module Geometry
    def self.dimensions(_e, _t, measure: nil); {width: 1000.0, depth: 500.0, height: 2000.0}; end
    def self.definition(e); Defn.new(e); end
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

class Model; attr_accessor :active_path; def edit_transform; Tr.new; end; end
inner = Sketchup::Group.new('Con')
top = Sketchup::Group.new('Cha', [inner])
other = Sketchup::Group.new('Khác')
m = Model.new; m.active_path = []

shallow = VGD::BIM::Table.build(m, [top, other], false)[:rows]
ok('mặc định: đọc đúng 2 đối tượng được chọn', shallow.size == 2)
ok('mặc định: không đọc đối tượng con lồng bên trong', shallow.none? { |r| r[:name] == 'Con' })
ok('mặc định: dòng có kích thước đúng (mm)', shallow[0][:lenX] == 1000.0 && shallow[0][:lenZ] == 2000.0)
ok('mặc định: không có cha trong danh sách (parents rỗng)', shallow.all? { |r| r[:parents].empty? })

deep = VGD::BIM::Table.build(m, [top, other], true)[:rows]
ok('chọn sâu: đọc cả 3 đối tượng (kể cả con lồng)', deep.size == 3)
ok('chọn sâu: con lồng có cha trong bảng', deep.find { |r| r[:name] == 'Con' }[:parents] == [deep.find { |r| r[:name] == 'Cha' }[:index]])

# Dòng cha (dùng để nhóm theo cha) và các cột sửa được bằng nhấp đúp
ok('dòng cha: đối tượng ở cấp gốc không có cha', shallow.all? { |r| r[:parent] == '' })
ok('dòng cha: đối tượng con lồng có tên của cha', deep.find { |r| r[:name] == 'Con' }[:parent] == 'Cha')
ctx = Sketchup::Group.new('Tủ bếp')
m2 = Model.new; m2.active_path = [ctx]
in_ctx = VGD::BIM::Table.build(m2, [Sketchup::Group.new('Cánh')], false)[:rows]
ok('dòng cha: đang mở sửa một group thì cha là group đó', in_ctx[0][:parent] == 'Tủ bếp')
unnamed = Sketchup::Group.new('')
m3 = Model.new; m3.active_path = [unnamed]
ok('dòng cha: cha chưa đặt tên thì lấy tên định nghĩa (cũng rỗng ở stub này)', VGD::BIM::Table.build(m3, [Sketchup::Group.new('X')], false)[:rows][0][:parent] == '')
# Tag loại trừ: dòng gắn tag bị tick không vào bảng, món con nằm trong nó cũng không
Lay = Struct.new(:name)
FakeMeasure = Struct.new(:tags) { def extent(_definition); nil; end }
wall = Sketchup::Group.new('Tường'); wall.layer = Lay.new('Tường')
wall_kid = Sketchup::Group.new('Gạch ốp')
wall.children << wall_kid
sofa_part = Sketchup::Group.new('Tay vịn'); sofa = Sketchup::Group.new('Sofa', [sofa_part]); sofa.layer = Lay.new('Nội thất')
plain = Sketchup::Group.new('Không tag')
ctx_none = FakeMeasure.new([])
ctx_wall = FakeMeasure.new(['tuong'])
built = VGD::BIM::Table.build(m, [wall, sofa, plain], false, measure: ctx_wall)
ok('tag loại trừ: dòng gắn tag bị tick không có trong bảng, hai dòng còn lại giữ nguyên thứ tự', built[:rows].map { |r| r[:name] } == %w[Sofa Không\ tag] && built[:hidden] == 1)
ok('tag loại trừ: chỉ số dòng và danh sách records khớp nhau sau khi lọc', built[:rows].map { |r| r[:index] } == [0, 1] && built[:records].map { |r| r[:entity] } == [sofa, plain])
built = VGD::BIM::Table.build(m, [wall, sofa, plain], true, measure: ctx_wall)
ok('chọn sâu: món con nằm trong nhóm bị loại cũng không vào bảng (Gạch ốp), món con của nhóm khác vẫn còn', built[:rows].map { |r| r[:name] } == %w[Sofa Tay\ vịn Không\ tag] && built[:hidden] == 2)
ok('chọn sâu: cha-con còn lại vẫn nối đúng sau khi lọc', built[:rows].find { |r| r[:name] == 'Tay vịn' }[:parents] == [built[:rows].find { |r| r[:name] == 'Sofa' }[:index]])
built = VGD::BIM::Table.build(m, [wall, sofa, plain], false, measure: ctx_none)
ok('không tick tag nào: không ẩn dòng nào', built[:rows].size == 3 && built[:hidden] == 0)
ok('không truyền measure (báo cáo khác): không ẩn dòng nào', VGD::BIM::Table.build(m, [wall, sofa, plain], false)[:rows].size == 3 && VGD::BIM::Table.build(m, [wall], false)[:hidden] == 0)
only_wall = VGD::BIM::Table.build(m, [wall], false, measure: ctx_wall)
ok('chọn toàn tag loại trừ: bảng rỗng nhưng vẫn báo đã ẩn 1', only_wall[:rows].empty? && only_wall[:hidden] == 1)
open_wall = Model.new; open_wall.active_path = [wall]
ok('đang mở sửa một group gắn tag loại trừ: các món bên trong vẫn vào bảng (chỉ xét tag của chính các đối tượng được đọc)', VGD::BIM::Table.build(open_wall, [wall_kid], false, measure: ctx_wall)[:rows].size == 1)

# Ngữ cảnh lúc quét: bấm một dòng con làm SketchUp mở sâu vào group cha (active_path đổi), nhưng phạm vi quét vẫn là đối tượng ở cấp gốc.
# Dựng lại bảng phải dùng ngữ cảnh lúc quét, không dùng ngữ cảnh đang mở (nếu không đường dẫn và vị trí thế giới của dòng bị sai).
scan_root = Sketchup::Group.new('Gốc')
scan_kid = Sketchup::Group.new('Con'); scan_root.children << scan_kid
deep_ctx = Model.new; deep_ctx.active_path = [Sketchup::Group.new('Đang mở 1'), Sketchup::Group.new('Đang mở 2')]
root_marker = Tr.new
rebuilt = VGD::BIM::Table.build(deep_ctx, [scan_root], true, context: {path: [], transform: root_marker})[:records]
ok('dựng lại với ngữ cảnh lúc quét: đường dẫn bắt đầu từ gốc, không dính group đang mở', rebuilt.map { |r| r[:path].size } == [1, 2] && rebuilt[1][:path] == [scan_root, scan_kid])
ok('dựng không truyền ngữ cảnh: vẫn lấy ngữ cảnh đang mở như cũ', VGD::BIM::Table.build(deep_ctx, [scan_root], false)[:records][0][:path].size == 3)
opened_ctx = Sketchup::Group.new('Tủ đang mở')
in_ctx = VGD::BIM::Table.build(deep_ctx, [scan_kid], false, context: {path: [opened_ctx], transform: root_marker})[:records]
ok('dựng với ngữ cảnh là một group đang mở lúc quét: đường dẫn nối đúng group đó', in_ctx[0][:path] == [opened_ctx, scan_kid])
hid = VGD::BIM::Table.build(deep_ctx, [scan_root], false, measure: FakeMeasure.new(['x']), context: {path: [], transform: root_marker})
ok('lọc tag loại trừ không xét các group trong ngữ cảnh', hid[:hidden] == 0 && hid[:rows].size == 1)

editable = VGD::BIM::Table::COLUMNS.select { |c| c[:editable] }.map { |c| [c[:key], c[:editable]] }
ok('cột sửa được: tên, mô tả, tag, vật liệu, tình trạng, hãng, link, cỡ, đơn giá, cách tính (theo tag)', editable == [%w[instance name], %w[code code], %w[description description], %w[tag tag], %w[material material], %w[status status], %w[owner owner], %w[url url], %w[size size], %w[price price], %w[calc_method calc_method]])

# Khối lượng tính suy ra từ tag (Quantity): tính ảo trong dòng, không đụng vào món
calc_door = Sketchup::Group.new('Cửa'); calc_door.layer = Struct.new(:name).new('A. DOOR')
calc_wall = Sketchup::Group.new('Tường'); calc_wall.layer = Struct.new(:name).new('A. WALL')
calc_plain = Sketchup::Group.new('Trơn')
calc_rows = VGD::BIM::Table.build(m, [calc_door, calc_wall, calc_plain], false)[:rows]
ok('dòng có tag cửa: tính theo cái (1), nguồn từ khóa tên tag', calc_rows[0].values_at(:calc_method, :calc_qty, :calc_source) == ['count', 1.0, 'keyword'])
ok('dòng có tag tường: tính theo diện tích Rộng x Cao (1000 x 2000 mm = 2 m²)', calc_rows[1].values_at(:calc_method, :calc_qty, :calc_category) == ['area', 2.0, 'other'])
ok('dòng chưa có tag: theo cái, nguồn mặc định', calc_rows[2].values_at(:calc_method, :calc_qty, :calc_source) == ['count', 1.0, 'default'])
ok('dòng chưa có đơn giá: thành tiền theo khối lượng tính để trống', calc_rows.all? { |r| r[:calc_total].nil? })
File.write(File.join(ENV['VGD_BIM_DATA_DIR'], 'tag_quantity.json'), JSON.generate('tags' => {VGD::BIM::Quantity.key('A. WALL') => 'length'}))
calc_rows = VGD::BIM::Table.build(m, [calc_door, calc_wall], false)[:rows]
ok('ghi đè theo tag đọc từ file: tường theo mét dài (Rộng 1 m)', calc_rows[1].values_at(:calc_method, :calc_qty, :calc_source) == ['length', 1.0, 'tag'] && calc_rows[0][:calc_method] == 'count')
File.delete(File.join(ENV['VGD_BIM_DATA_DIR'], 'tag_quantity.json'))

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
