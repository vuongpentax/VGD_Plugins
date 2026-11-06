require 'json'
module VGD; module BIM; def self.log(m); end; module Data; end; end; end
require ARGV[0] || File.expand_path('../runtime/vgd_bim_lite/core/tags.rb', __dir__)
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
