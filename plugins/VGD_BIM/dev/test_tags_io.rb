require 'json'
module VGD; module BIM; def self.log(m); end; module Data; end; end; end
require ARGV[0] || File.expand_path('../runtime/vgd_bim/core/tags.rb', __dir__)
T = VGD::BIM::Tags
def check(label, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{label}"; end
def raises?(msg = nil); yield; false; rescue ArgumentError => e; msg ? e.message.include?(msg) : true; end
set = [{'name'=>'Cột bê tông','group'=>'S. STRUCTURAL'},{'name'=>'Sơn 2 lớp','group'=>'A. ARCHITECTURAL'},{'name'=>'Cửa','group'=>'A. ARCHITECTURAL'}]
csv = T.to_csv(set)
check 'CSV có BOM UTF-8 ở đầu', csv.start_with?("﻿")
check 'CSV dùng dấu chấm phẩy và đúng hai cột', csv.start_with?("﻿Tên tag;Nhóm\r\n") && csv.include?('Cột bê tông;S. STRUCTURAL')
check 'CSV xuất rồi nhập lại giống hệt', T.from_csv(csv) == set
check 'nhập CSV dùng dấu phẩy được', T.from_csv("Tên tag,Nhóm\nTrần,A. ARCHITECTURAL\n").first == {'name'=>'Trần','group'=>'A. ARCHITECTURAL'}
check 'file cũ còn cột Đơn vị vẫn nhập được (bỏ qua đơn vị)', T.from_csv("Tên tag;Nhóm;Đơn vị\nTrần;A. ARCHITECTURAL;m²\n").first == {'name'=>'Trần','group'=>'A. ARCHITECTURAL'}
check 'nhập CSV có BOM (file lưu từ Excel)', T.from_csv("﻿Tên tag;Nhóm\nGạch;Hoàn thiện").size == 1
check 'ô trống nhóm thành # BASIC (cụm cơ bản của Auto Tag)', T.from_csv("Tên tag;Nhóm\nGhi chú;\n").first == {'name'=>'Ghi chú','group'=>'# BASIC'}
check 'file CSV cũ dùng nhóm cũ vẫn nhập được và đổi sang nhóm mới', T.from_csv("Tên tag;Nhóm\nCột;Phần thô\nGhế;Đồ rời\n").map { |t| t['group'] } == ['S. STRUCTURAL', 'I. INTERIOR']
check 'bỏ dòng trống', T.from_csv("Tên tag;Nhóm\n;\nTrần;A. ARCHITECTURAL\n").size == 1
check 'báo đúng số dòng khi nhóm sai', raises?('Dòng 3') { T.from_csv("Tên tag;Nhóm\nTrần;A. ARCHITECTURAL\nSàn;Lạ\n") }
check 'báo lỗi khi thiếu cột Tên tag', raises?('Thiếu cột') { T.from_csv("Nhóm\nHoàn thiện\n") }
check 'báo lỗi khi file là Excel .xlsx (zip)', raises?('.xlsx') { T.from_csv("PK\x03\x04binary") }
check 'chặn ô công thức khi xuất (thêm nháy đơn)', T.escape_cell('=SUM(A1)') == "'=SUM(A1)" && T.escape_cell('Cửa') == 'Cửa'
check 'bỏ nháy đơn khi nhập lại', T.from_csv("Tên tag;Nhóm\n'=Lạ;# BASIC\n").first['name'] == '=Lạ'
check 'trùng tên trong file bị báo', raises? { T.from_csv("Tên tag;Nhóm\nTrần;# BASIC\ntrần;# BASIC\n") }
json = T.to_json(set)
check 'JSON có định dạng và phiên bản 2', JSON.parse(json)['format'] == 'VGD_BIM_TAGS' && JSON.parse(json)['version'] == 2
check 'JSON không ghi đơn vị', JSON.parse(json)['tags'].all? { |t| !t.key?('unit') }
check 'JSON xuất rồi nhập lại giống hệt', T.from_json(json) == set
check 'JSON dạng mảng thuần cũng nhập được', T.from_json(JSON.generate(set)) == set
check 'JSON sai định dạng báo lỗi', raises?('không đúng định dạng') { T.from_json('{not json') }
check 'JSON rỗng báo lỗi', raises?('không có tag') { T.from_json('{"tags": []}') }
current = [{'name'=>'Trần','group'=>'A. ARCHITECTURAL'},{'name'=>'Cửa','group'=>'A. ARCHITECTURAL'}]
incoming = [{'name'=>'cửa','group'=>'A. ARCHITECTURAL'},{'name'=>'Cột','group'=>'S. STRUCTURAL'}]
merged = T.merge(current, incoming)
check 'gộp: tag trùng tên (khác hoa thường) lấy từ file, tag khác giữ nguyên', merged.map { |t| t['name'] } == ['Trần','cửa','Cột']
