# Test các cột mới của bảng khối lượng: Hãng, Link, Cỡ, Đơn giá, Thành tiền, Lớp IFC, Diện tích chiếu.
# SketchUp giả lập. Chạy: ruby dev/test_columns.rb
require 'json'
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_columns')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def raises?(text = nil); yield; false; rescue ArgumentError => e; text ? e.message.downcase.include?(text) : true; end

class Vec3
  attr_reader :x, :y, :z
  def initialize(x, y, z); @x = x; @y = y; @z = z; end
  def transform(_t); self; end
  def length; Math.sqrt(x * x + y * y + z * z); end
end
class Identity; def xaxis; Struct.new(:length).new(1.0); end; alias yaxis xaxis; alias zaxis xaxis; def to_a; [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0]; end; def *(_o); self; end; end
module Sketchup
  class Face
    def initialize(area_in2, normal); @area = area_in2; @normal = normal; end
    def area(_t = nil); @area; end
    attr_reader :normal
  end
  class AttrDict; def initialize(h); @h = h; end; def each_pair(&b); @h.each_pair(&b); end; end
  class Group
    attr_accessor :name, :locked, :faces, :manifold, :schema
    attr_reader :deleted
    def initialize(name = 'G', faces = [], manifold = false); @name = name; @faces = faces; @manifold = manifold; @locked = false; @attrs = {}; @deleted = []; @transformation = Identity.new; end
    attr_reader :transformation
    def entityID; object_id; end
    def valid?; true; end
    def locked?; @locked; end
    def manifold?; @manifold; end
    def layer; nil; end
    def material; nil; end
    def volume; -1.0; end
    def get_attribute(dict, key, default = nil); (@attrs[dict] || {}).fetch(key, default); end
    def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; end
    def delete_attribute(dict, key); @deleted << [dict, key]; (@attrs[dict] || {}).delete(key); end
    def entities; @faces; end
  end
  class ComponentInstance < Group; end
  def self.read_default(*); nil; end
  def self.write_default(*); true; end
end
module VGD; module BIM
  def self.log(m); end
  module Data
    def self.supported?(e); e.is_a?(Sketchup::Group); end
    def self.read(e); {status: '', description: '', manufacturer: e.get_attribute('VGD_BIM', 'manufacturer', '')}; end
  end
  module Scanner; end
  module Tags; GROUPS = [].freeze; def self.load; []; end; def self.key(n); n.to_s.downcase; end; end
  module Geometry
    INCH_MM = 25.4
    def self.dimensions(_e, _t, measure: nil); {width: 1000.0, depth: 500.0, height: 2000.0}; end
    def self.definition(e); Defn.new(e); end
    class Defn
      def initialize(e); @e = e; end
      def name; @e.name; end
      def entities; @e.faces; end
      def bounds; Box.new; end
      def count_instances; 1; end
      def attribute_dictionary(name); @e.schema && name == 'AppliedSchemaTypes' ? Sketchup::AttrDict.new(@e.schema) : nil; end
      def get_attribute(d, k, df = nil); @e.get_attribute(d, k, df); end
      def set_attribute(d, k, v); @e.set_attribute(d, k, v); end
      def delete_attribute(d, k); @e.delete_attribute(d, k); end
    end
    class Box; def empty?; true; end; end
  end
end; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
# Dùng face_area / projected_area thật của geometry.rb; thay phần còn lại bằng bản giả ở trên.
real = File.read(File.join(ROOT, 'core/geometry.rb'), encoding: 'UTF-8')
fa = real[/def self\.face_area.*?\n      end\n/m] + real[/def self\.projected_area.*?\n      end\n/m].to_s
VGD::BIM::Geometry.module_eval(fa)
%w[core/schema core/preset core/table].each { |f| require File.join(ROOT, f) }
T = VGD::BIM::Table
X = T::Extras
class Model; def edit_transform; Identity.new; end; def active_path; []; end; def guid; 'M'; end; end
model = Model.new
UP = Vec3.new(0, 0, 1); DOWN = Vec3.new(0, 0, -1); SIDE = Vec3.new(1, 0, 0)

# ---- Hãng, Link, Cỡ, Đơn giá, Thành tiền ----
g = Sketchup::Group.new('Tủ')
g.set_attribute('VGD_BIM', 'manufacturer', 'Hafele')
X.write(g, 'url', 'https://example.com/tu')
X.write(g, 'size', '1200x600')
X.write(g, 'price', '2500000')
row = T.build(model, [g])[:rows].first
ok('Hãng lấy từ trường manufacturer của dữ liệu VGD', row[:owner] == 'Hafele')
ok('Link, Cỡ, Đơn giá đọc từ dictionary riêng của bảng', row[:url] == 'https://example.com/tu' && row[:size] == '1200x600' && row[:price] == 2_500_000.0)
ok('Thành tiền = đơn giá x số lượng', row[:total] == 2_500_000.0 && row[:quantity] == 1)
bare = T.build(model, [Sketchup::Group.new('Trống')])[:rows].first
ok('đối tượng chưa nhập: hãng, link, cỡ rỗng; đơn giá và thành tiền để trống (không phải 0)', bare[:owner] == '' && bare[:url] == '' && bare[:size] == '' && bare[:price].nil? && bare[:total].nil?)
ok('dữ liệu bảng không đụng vào dictionary dữ liệu VGD (không thêm trường vào schema)', g.get_attribute('VGD_BIM', 'price').nil? && g.get_attribute('VGD_BIM_TABLE', 'price') == 2_500_000.0)

# ---- Kiểm tra khi ghi ----
w = Sketchup::Group.new('W')
%w[http://a.vn https://a.vn/x?y=1&z=2#f].each { |u| ok("link hợp lệ: #{u}", (X.write(w, 'url', u); w.get_attribute('VGD_BIM_TABLE', 'url') == u)) }
["javascript:alert(1)", 'ftp://a.vn', 'a.vn', 'https://', 'https://a b.vn', "https://a.vn/\nx", 'file:///C:/x', "https://a.vn/#{'x' * 600}", 'HTTPS://a.vn'].each do |bad|
  ok("link bị từ chối: #{bad[0, 30].inspect}", bad == 'HTTPS://a.vn' ? (X.write(w, 'url', bad); true) : raises?('link') { X.write(w, 'url', bad) })
end
X.write(w, 'url', '')
ok('link rỗng: xóa khỏi dictionary', w.deleted.include?(['VGD_BIM_TABLE', 'url']) && w.get_attribute('VGD_BIM_TABLE', 'url').nil?)
ok('cỡ quá 100 ký tự bị từ chối, ký tự điều khiển bị bỏ', raises?('cỡ') { X.write(w, 'size', 'x' * 101) } && (X.write(w, 'size', "1200\x00x\n600"); w.get_attribute('VGD_BIM_TABLE', 'size') == '1200x600'))
{'1250000' => 1_250_000.0, ' 7 ' => 7.0, '12,5' => 12.5, '12.5' => 12.5, '0' => 0.0}.each do |input, expected|
  ok("đơn giá hợp lệ: #{input.inspect} -> #{expected}", (X.write(w, 'price', input); w.get_attribute('VGD_BIM_TABLE', 'price') == expected))
end
['1.250.000', '-5', 'abc', '1e9', '12,5,5', '1000000000001', '$5', '5 000'].each { |bad| ok("đơn giá bị từ chối: #{bad.inspect}", raises?('đơn giá') { X.write(w, 'price', bad) }) }
X.write(w, 'price', '')
ok('đơn giá rỗng: xóa', w.get_attribute('VGD_BIM_TABLE', 'price').nil?)
ok('trường lạ bị từ chối', raises?('không sửa') { X.write(w, 'zzz', 'x') })
locked = Sketchup::Group.new('Khóa'); locked.locked = true
ok('đối tượng khóa không ghi được', raises?('khóa') { X.write(locked, 'size', 'a') } && locked.get_attribute('VGD_BIM_TABLE', 'size').nil?)

# ---- Lớp IFC ----
ifc = Sketchup::Group.new('Tường'); ifc.schema = {'IFC 2x3' => 'IfcWall'}
ok('Lớp IFC lấy từ phân loại có sẵn của đối tượng', T.build(model, [ifc])[:rows].first[:ifc] == 'IfcWall')
two = Sketchup::Group.new('Hai'); two.schema = {'Khác' => '', 'IFC 4' => 'IfcDoor'}
ok('nhiều bảng phân loại: lấy mục đầu tiên có giá trị', T.build(model, [two])[:rows].first[:ifc] == 'IfcDoor')
ok('chưa phân loại IFC: để trống', bare[:ifc] == '')

# ---- Diện tích chiếu ----
IN2 = 25.4**2 / 1_000_000.0 # 1 in² = ? m²
one_m2 = 1_000_000.0 / 25.4**2
box = Sketchup::Group.new('Hộp', [Sketchup::Face.new(one_m2, UP), Sketchup::Face.new(one_m2, DOWN), Sketchup::Face.new(2 * one_m2, SIDE), Sketchup::Face.new(2 * one_m2, SIDE)], true)
plane = Sketchup::Group.new('Sàn', [Sketchup::Face.new(2 * one_m2, UP), Sketchup::Face.new(one_m2, SIDE)], false)
off = T.build(model, [box, plane])[:rows]
ok('mặc định không tính diện tích chiếu (để trống cho nhanh)', off.all? { |r| r[:areaProjected].nil? })
on = T.build(model, [box, plane], false, projected: true)[:rows]
ok('khối kín: mặt trên và mặt dưới cùng chiếu xuống, chia đôi nên đúng bằng diện tích sàn (1 m²)', (on[0][:areaProjected] - 1.0).abs < 0.001)
ok('mặt phẳng hở: tính hết mặt hướng lên, mặt đứng không tính (2 m²)', (on[1][:areaProjected] - 2.0).abs < 0.001)
tilt = Sketchup::Group.new('Dốc', [Sketchup::Face.new(one_m2, Vec3.new(0, 0.6, 0.8))], false)
ok('mặt nghiêng: diện tích nhân cosin góc nghiêng (0,8)', (T.build(model, [tilt], false, projected: true)[:rows].first[:areaProjected] - 0.8).abs < 0.001)
empty = Sketchup::Group.new('Rỗng', [], false)
ok('đối tượng không có mặt: diện tích chiếu bằng 0', T.build(model, [empty], false, projected: true)[:rows].first[:areaProjected] == 0.0)

# Mặt trước: đọc từ định nghĩa vào dòng của bảng
fronted = Sketchup::Group.new('Tủ mặt trước')
blank_row = T.build(model, [fronted])[:rows].first
ok('chưa có mặt trước: các cột Mặt trước và Độ tin cậy để trống', blank_row[:front] == '' && blank_row[:front_state] == '' && blank_row[:front_note] == '')
VGD::BIM::Front.write(VGD::BIM::Geometry.definition(fronted), '+y', source: 'auto', confidence: 'low', note: 'chưa đủ bằng chứng')
row = T.build(model, [fronted])[:rows].first
ok('có mặt trước tự động tin cậy thấp: hiện +Y, Cần duyệt, kèm ghi chú và độ tin cậy', row[:front] == '+Y' && row[:front_state] == 'Cần duyệt' && row[:front_note] == 'chưa đủ bằng chứng' && row[:front_conf] == 'low')
VGD::BIM::Front.write(VGD::BIM::Geometry.definition(fronted), '-x')
ok('đặt tay: hiện -X, Thủ công', T.build(model, [fronted])[:rows].first.values_at(:front, :front_state) == ['-X', 'Thủ công'])
ok('hai cột Mặt trước nằm trong danh sách cột của bảng, là cột chữ', %w[front front_state].all? { |k| T::COLUMNS.any? { |c| c[:key] == k && c[:kind] == 'text' } })

# Ghi chú số đo (bỏ tay nắm theo từ khóa): lấy từ bộ đo thân của bảng
fake_measure = Class.new { def extent(_definition); {size: [1.0, 1.0, 1.0], note: 'Bỏ 1 phần theo từ khóa (Tay nam)'}; end }.new
ok('có đo thân: dòng bảng mang ghi chú số đo', T.build(model, [Sketchup::Group.new('Tủ có tay nắm')], measure: fake_measure)[:rows].first[:measure_note] == 'Bỏ 1 phần theo từ khóa (Tay nam)')
ok('không đo thân (measure nil): ghi chú số đo rỗng', T.build(model, [Sketchup::Group.new('Tủ thường')])[:rows].first[:measure_note] == '')
none = Class.new { def extent(_definition); nil; end }.new
ok('đo thân nhưng không có gì bị bỏ (extent nil): ghi chú rỗng', T.build(model, [Sketchup::Group.new('Tủ sạch')], measure: none)[:rows].first[:measure_note] == '')

puts $fails.zero? ? 'Done' : "#{$fails} lỗi"
exit($fails.zero? ? 0 : 1)
