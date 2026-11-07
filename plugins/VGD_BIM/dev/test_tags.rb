require 'json'
module VGD; module BIM; def self.log(m); end; module Data; end; end; end
require ARGV[0] || File.expand_path('../runtime/vgd_bim/core/tags.rb', __dir__)
T = VGD::BIM::Tags
def check(label, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{label}"; end
def raises?; yield; false; rescue ArgumentError; true; end
check 'key bỏ khoảng trắng thừa và không phân biệt hoa thường', T.key('  Tường   100 ') == 'tường 100' && T.key('TƯỜNG 100') == 'tường 100'
check 'bộ mẫu mặc định hợp lệ', T.validate(T::DEFAULT_SET).size == T::DEFAULT_SET.size
check 'bộ mẫu mặc định không còn đơn vị', T::DEFAULT_SET.none? { |t| t.key?('unit') }
check 'từ chối tên trùng khác hoa thường', raises? { T.validate([{'name'=>'Sơn 1 lớp','group'=>'Hoàn thiện'},{'name'=>'sơn 1  lớp','group'=>'Hoàn thiện'}]) }
check 'từ chối tên rỗng', raises? { T.validate([{'name'=>'  ','group'=>'Khác'}]) }
check 'từ chối tên quá 60 ký tự', raises? { T.validate([{'name'=>'a'*61,'group'=>'Khác'}]) }
check 'từ chối nhóm lạ', raises? { T.validate([{'name'=>'X','group'=>'Lạ'}]) }
check 'từ chối tên Untagged', raises? { T.validate([{'name'=>'Untagged','group'=>'Khác'}]) }
check 'làm sạch tên khi lưu (bỏ khoảng trắng thừa)', T.validate([{'name'=>' Cột  bê tông ','group'=>'Phần thô'}]).first['name'] == 'Cột bê tông'
check 'bỏ trường đơn vị cũ khi lưu', T.validate([{'name'=>'Cột','group'=>'Phần thô','unit'=>'m3'}]).first == {'name'=>'Cột','group'=>'Phần thô'}
check 'từ chối danh sách không phải mảng', raises? { T.validate({'name'=>'X'}) }

# Gán tag vào đối tượng: tên chuẩn hóa, tìm hoặc tạo tag trong model, bỏ qua đối tượng khóa
module VGD; module BIM; module Data; def self.transaction(_model, _name = nil); yield; end; end; end; end
class TLayer; attr_reader :name; def initialize(name); @name = name; end; def visible?; true; end; end
class TLayers
  def initialize(names); @items = names.map { |n| TLayer.new(n) }; end
  def to_a; @items.dup; end
  def add(name); layer = TLayer.new(name); @items << layer; layer; end
end
class TModel; attr_reader :layers; def initialize(names); @layers = TLayers.new(names); end; end
class TEnt
  attr_accessor :layer
  def initialize(locked = false); @locked = locked; end
  def valid?; true; end
  def locked?; @locked; end
end
check 'chuẩn hóa tên tag: bỏ khoảng trắng thừa', T.normalize_name('  000   CUA ') == '000 CUA'
check 'chuẩn hóa tên tag: từ chối tên rỗng', raises? { T.normalize_name('  ') }
check 'chuẩn hóa tên tag: từ chối Untagged', raises? { T.normalize_name('untagged') }
tm = TModel.new(['Untagged', '000 CUA'])
check 'tìm tag có sẵn không phân biệt hoa thường, không tạo thêm', T.layer_for(tm, '000 cua').name == '000 CUA' && tm.layers.to_a.size == 2
check 'tag chưa có: tạo mới trong model', T.layer_for(tm, 'A. DOOR').name == 'A. DOOR' && tm.layers.to_a.size == 3
ents = [TEnt.new, TEnt.new(true), TEnt.new]
result = T.assign(tm, ents, '000 CUA')
check 'gán tag: đếm đối tượng đã gán và đối tượng khóa', result[:count] == 2 && result[:locked] == 1
check 'gán tag: đối tượng không khóa nhận đúng tag, đối tượng khóa giữ nguyên', ents[0].layer.name == '000 CUA' && ents[2].layer.name == '000 CUA' && ents[1].layer.nil?
