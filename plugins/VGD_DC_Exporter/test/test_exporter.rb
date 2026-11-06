# Test VGD DC Exporter: xử lý thuộc tính DC (pure) và lớp đọc bằng đối tượng giả lập.
# Chạy: ruby test_exporter.rb
$stdout.sync = true
require 'json'
require 'time'
ROOT = File.expand_path('../VGD_DC_Exporter', __dir__)
module Sketchup
  def self.version; '2024.0'; end
  class Entity; attr_accessor :name, :typename; end
  class Group < Entity; end
  class ComponentInstance < Entity; end
  class Face < Entity; end
end
require File.join(ROOT, 'params.rb')
require File.join(ROOT, 'walker.rb')
$pass = 0; $fail = []
def check(name, cond, extra = nil)
  if cond then $pass += 1 else $fail << "#{name} #{extra}"; puts "FAIL: #{name} #{extra}" end
end
include VGD_DC_Exporter

puts '== 1. Tách tham số, công thức, nhãn, đơn vị =='
s = Params.split('lenx' => 1500.0, '_lenx_formula' => 'Width*2', '_lenx_label' => 'Rộng', '_lenx_units' => 'MILLIMETERS',
                 '_name' => 'Tủ', '_lenx_access' => 'NONE')
check 'lenx là tham số có giá trị', s['parameters']['lenx']['value'] == 1500.0
check 'công thức gắn đúng tham số', s['parameters']['lenx']['formula'] == 'Width*2'
check 'khóa _name vào phần khác', s['other']['_name'] == 'Tủ' && !s['parameters'].key?('name')
check 'nhãn và đơn vị được giữ', s['parameters']['lenx']['label'] == 'Rộng' && s['parameters']['lenx']['units'] == 'MILLIMETERS'

puts '== 2. Ghép mặc định với giá trị instance =='
d = Params.split('lenx' => 600.0, '_lenx_units' => 'INCHES', '_lenx_formula' => 'W', 'mat' => 'gỗ', '_mat_access' => 'LIST')
i = Params.split('lenx' => 900.0)
c = Params.combine(d, i)
check 'instance ghi đè mặc định', c['lenx']['value'] == 900.0 && c['lenx']['definition_value'] == 600.0 && c['lenx']['instance_value'] == 900.0
check 'tham số chỉ có mặc định vẫn có mặt', c['mat']['value'] == 'gỗ' && c['mat']['instance_value'].nil?
check 'đổi mm chỉ khi đơn vị là độ dài', (c['lenx']['value_mm'] - 900.0 * 25.4).abs < 1e-9
check 'chuỗi không đổi mm', !c['mat'].key?('value_mm')
check 'công thức đi cùng kết quả', Params.formulas(c) == [{ 'parameter' => 'lenx', 'formula' => 'W' }]

puts '== 2b. Giải mã tùy chọn DC =='
opt = Params.options('&%u0110%u1EC1u%20khoang=1&C%E1nh%20Ph%u1EE7=0&Ko%20X%E0=3')
check 'tùy chọn giải mã đúng tiếng Việt', opt == [{ 'label' => 'Đều khoang', 'value' => '1' }, { 'label' => 'Cánh Phủ', 'value' => '0' }, { 'label' => 'Ko Xà', 'value' => '3' }], opt.inspect
check 'chuỗi tùy chọn rỗng', Params.options(nil) == []

puts '== 3. Đọc đối tượng: định nghĩa dùng chung chỉ xuất một lần =='
class Dict
  attr_reader :name
  def initialize(name, values); @name = name; @values = values; end
  def each_pair(&block); @values.each_pair(&block); end
end
class Obj
  attr_accessor :persistent_id, :name, :typename, :definition, :transformation, :layer, :material, :bounds, :description, :entities_list
  def initialize(**opts); opts.each { |k, v| instance_variable_set("@#{k}", v); define_singleton_method(k) { instance_variable_get("@#{k}") } unless respond_to?(k) }; end
  def attribute_dictionaries; (@dicts || {}).map { |name, values| Dict.new(name, values) }; end
  def attribute_dictionary(name); (@dicts || {})[name] && Dict.new(name, @dicts[name]); end
  def entities; Ents.new(@entities_list || []); end
  def hidden?; false; end
  def locked?; false; end
end
class Ents
  def initialize(list); @list = list; end
  def each(&block); @list.each(&block); end
end
Tr = Struct.new(:matrix) do
  def to_a; matrix; end
  def origin; Pt.new(*matrix[12..14]); end
  def xaxis; Vec.new(1, 0, 0); end
  def yaxis; Vec.new(0, 1, 0); end
  def zaxis; Vec.new(0, 0, 1); end
end
Pt = Struct.new(:x, :y, :z) { def to_a; [x, y, z]; end }
Vec = Struct.new(:x, :y, :z) do
  def length; 1.0; end
  def cross(o); Vec.new(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x); end
  def dot(o); x * o.x + y * o.y + z * o.z; end
end
Box = Struct.new(:min, :max) do
  def empty?; false; end
  def width; max.x - min.x; end
  def height; max.y - min.y; end
  def depth; max.z - min.z; end
end
mat = Struct.new(:name).new('Gỗ sồi')
shared = Obj.new(persistent_id: 7, name: 'Hông', description: '', typename: 'ComponentDefinition',
                 bounds: Box.new(Pt.new(0, 0, 0), Pt.new(0.7, 17.5 / 25.4, 2.0)),
                 entities_list: [], layer: Struct.new(:name).new('0'))
shared.define_singleton_method(:entities) { Ents.new([]) }
dict_def = { 'lenx' => 600.0, '_lenx_formula' => 'W', '_lenx_units' => 'MILLIMETERS' }
defn = Obj.new(persistent_id: 1, name: 'Tủ', description: 'tủ bếp', typename: 'ComponentDefinition',
               bounds: Box.new(Pt.new(0, 0, 0), Pt.new(1, 1, 1)), layer: Struct.new(:name).new('0'))
defn.instance_variable_set(:@dicts, { 'dynamic_attributes' => dict_def })
defn.define_singleton_method(:entities) { Ents.new([]) }
inst = lambda do |pid, width|
  o = Obj.new(persistent_id: pid, name: "Tủ #{pid}", typename: 'ComponentInstance', definition: defn, material: mat,
              layer: Struct.new(:name).new('VGD'), transformation: Tr.new([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, pid * 10.0, 0, 0, 1]),
              bounds: Box.new(Pt.new(0, 0, 0), Pt.new(1, 1, 1)))
  o.instance_variable_set(:@dicts, { 'dynamic_attributes' => { 'lenx' => width }, 'VGD_Cabinet_Draw' => { 'params_json' => JSON.generate('width_mm' => width * 25.4) } })
  o
end
model = Struct.new(:title, :options).new('Thử', { 'UnitsOptions' => { 'LengthUnit' => 4 } })
walker = Walker.new
snap = walker.build(model, [inst.call(2, 900.0), inst.call(3, 700.0)])
check 'hai instance chung một định nghĩa: chỉ một định nghĩa xuất ra', snap['definitions'].length == 1, snap['definitions'].keys.inspect
check 'hai instance giữ giá trị riêng', snap['roots'].map { |r| r['dc_parameters']['lenx']['value'] } == [900.0, 700.0]
check 'công thức của định nghĩa xuất qua instance', snap['roots'][0]['dc_formulas'] == [{ 'parameter' => 'lenx', 'formula' => 'W' }]
check 'thuộc tính VGD *_json được đọc thành dữ liệu', snap['roots'][0]['attribute_dictionaries']['VGD_Cabinet_Draw']['values']['params']['width_mm'].round(3) == (900.0 * 25.4).round(3)
check 'vị trí và tên xuất đúng', snap['roots'][1]['origin_parent_mm'] == [30.0 * 25.4, 0.0, 0.0] && snap['roots'][1]['instance_name'] == 'Tủ 3'
check 'JSON hợp lệ khi ghi ra', JSON.parse(JSON.pretty_generate(snap))['schema'] == 'vgd.dc_snapshot'
check 'không có cảnh báo khi dữ liệu bình thường', snap['warnings'].empty?, snap['warnings'].inspect

puts "\n== Kết quả test_exporter: Đạt: #{$pass}   Không đạt: #{$fail.length} =="
$fail.each { |x| puts "  - #{x}" }
