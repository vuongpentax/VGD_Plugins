require 'json'
module VGD; module BIM; def self.log(m); end; module Data; end; end; end
require ARGV[0] || File.expand_path('../runtime/vgd_bim_lite/core/tags.rb', __dir__)
T = VGD::BIM::Tags
def check(label, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{label}"; end
def raises?(msg = nil); yield; false; rescue ArgumentError => e; msg ? e.message.include?(msg) : true; end
set = [{'name'=>'Cột bê tông','group'=>'Phần thô'},{'name'=>'Sơn 2 lớp','group'=>'Hoàn thiện'},{'name'=>'Cửa','group'=>'Hoàn thiện'}]
csv = T.to_csv(set)
check 'CSV có BOM UTF-8 ở đầu', csv.start_with?("﻿")
check 'CSV dùng dấu chấm phẩy và đúng hai cột', csv.start_with?("﻿Tên tag;Nhóm\r\n") && csv.include?('Cột bê tông;Phần thô')
check 'CSV xuất rồi nhập lại giống hệt', T.from_csv(csv) == set
check 'nhập CSV dùng dấu phẩy được', T.from_csv("Tên tag,Nhóm\nTrần,Hoàn thiện\n").first == {'name'=>'Trần','group'=>'Hoàn thiện'}
check 'file cũ còn cột Đơn vị vẫn nhập được (bỏ qua đơn vị)', T.from_csv("Tên tag;Nhóm;Đơn vị\nTrần;Hoàn thiện;m²\n").first == {'name'=>'Trần','group'=>'Hoàn thiện'}
check 'nhập CSV có BOM (file lưu từ Excel)', T.from_csv("﻿Tên tag;Nhóm\nGạch;Hoàn thiện").size == 1
check 'ô trống nhóm thành Khác', T.from_csv("Tên tag;Nhóm\nGhi chú;\n").first == {'name'=>'Ghi chú','group'=>'Khác'}
check 'bỏ dòng trống', T.from_csv("Tên tag;Nhóm\n;\nTrần;Hoàn thiện\n").size == 1
check 'báo đúng số dòng khi nhóm sai', raises?('Dòng 3') { T.from_csv("Tên tag;Nhóm\nTrần;Hoàn thiện\nSàn;Lạ\n") }
check 'báo lỗi khi thiếu cột Tên tag', raises?('Thiếu cột') { T.from_csv("Nhóm\nHoàn thiện\n") }
check 'báo lỗi khi file là Excel .xlsx (zip)', raises?('.xlsx') { T.from_csv("PK\x03\x04binary") }
check 'chặn ô công thức khi xuất (thêm nháy đơn)', T.escape_cell('=SUM(A1)') == "'=SUM(A1)" && T.escape_cell('Cửa') == 'Cửa'
check 'bỏ nháy đơn khi nhập lại', T.from_csv("Tên tag;Nhóm\n'=Lạ;Khác\n").first['name'] == '=Lạ'
check 'trùng tên trong file bị báo', raises? { T.from_csv("Tên tag;Nhóm\nTrần;Khác\ntrần;Khác\n") }
json = T.to_json(set)
check 'JSON có định dạng và phiên bản 2', JSON.parse(json)['format'] == 'VGD_BIM_TAGS' && JSON.parse(json)['version'] == 2
check 'JSON không ghi đơn vị', JSON.parse(json)['tags'].all? { |t| !t.key?('unit') }
check 'JSON xuất rồi nhập lại giống hệt', T.from_json(json) == set
check 'JSON dạng mảng thuần cũng nhập được', T.from_json(JSON.generate(set)) == set
check 'JSON sai định dạng báo lỗi', raises?('không đúng định dạng') { T.from_json('{not json') }
check 'JSON rỗng báo lỗi', raises?('không có tag') { T.from_json('{"tags": []}') }
current = [{'name'=>'Trần','group'=>'Hoàn thiện'},{'name'=>'Cửa','group'=>'Hoàn thiện'}]
incoming = [{'name'=>'cửa','group'=>'Hoàn thiện'},{'name'=>'Cột','group'=>'Phần thô'}]
merged = T.merge(current, incoming)
check 'gộp: tag trùng tên (khác hoa thường) lấy từ file, tag khác giữ nguyên', merged.map { |t| t['name'] } == ['Trần','cửa','Cột']
