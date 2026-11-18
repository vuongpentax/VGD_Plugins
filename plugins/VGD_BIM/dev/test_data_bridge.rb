# Test cầu nối dữ liệu (core/data_bridge.rb): đọc CSV / Excel, chọn dòng tiêu đề, gợi ý ánh xạ cột, lập kế hoạch thay đổi (khớp VGD ID / Mã,
# trùng, khóa, ô trống = không đổi, kiểm tra giá trị), và nhập lại file Excel do chính BIM xuất. Chạy: ruby dev/test_data_bridge.rb
require 'tmpdir'
require 'json'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_bridge')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
module VGD; module BIM; def self.log(_m); end; end; end
require File.join(ROOT, 'core/table_report')
require File.join(ROOT, 'core/xlsx')
require File.join(ROOT, 'core/data_bridge')
B = VGD::BIM::DataBridge
FIELDS = B.fields([{'key' => 'custom_1', 'label' => 'Ghi chú thi công', 'kind' => 'text'}, {'key' => 'custom_2', 'label' => 'X', 'kind' => 'attribute'}])
ok('trường nhập: 6 cố định + chỉ cột chữ tự thêm', FIELDS.map { |f| f[:key] } == %w[name description owner url size price custom_1])

dir = Dir.mktmpdir('bridge_files')
csv = File.join(dir, 'a.csv')
File.write(csv, "﻿VGD ID;Tên;Mô tả;Đơn giá;Quy cách;Ghi chú thi công\nvgd-aaa;Tủ bếp;Tủ dưới;1250000;600x700;Làm lại\nVGD-BBB;;Bàn đảo;abc;;\nvgd-zzz;Lạ;x;1;;\nvgd-aaa;Trùng;;;;\n")
file = B.read_file(csv)
ok('CSV dấu chấm phẩy + BOM: đọc đúng tiêu đề và dòng', file[:headers] == ['VGD ID', 'Tên', 'Mô tả', 'Đơn giá', 'Quy cách', 'Ghi chú thi công'] && file[:rows].size == 4 && file[:header_row] == 1)
sug = B.suggest(file[:headers], FIELDS)
ok('gợi ý: khớp theo VGD ID, cột nào ghi trường nào theo tên cột (kể cả cột tự thêm)', sug[:match_by] == 'vgd_id' && sug[:match_column] == 'VGD ID' && sug[:mapping] == {'Tên' => 'name', 'Mô tả' => 'description', 'Đơn giá' => 'price', 'Quy cách' => 'size', 'Ghi chú thi công' => 'custom_1'})

targets = [
  {index: 0, ids: {'vgd_id' => 'VGD-AAA', 'code' => 'T01'}, name: 'Cũ', locked: false, current: {'name' => 'Cũ', 'description' => 'Tủ dưới', 'price' => 1_250_000.0, 'size' => '', 'custom_1' => ''}},
  {index: 1, ids: {'vgd_id' => 'vgd-bbb', 'code' => 'T02'}, name: 'Bàn', locked: false, current: {'name' => 'Bàn', 'description' => '', 'price' => nil, 'size' => '', 'custom_1' => ''}},
  {index: 2, ids: {'vgd_id' => 'VGD-CCC', 'code' => 'T02'}, name: 'Bàn 2', locked: true, current: {'name' => 'Bàn 2', 'description' => '', 'price' => nil, 'size' => '', 'custom_1' => ''}}
]
opts = {'match_by' => 'vgd_id', 'match_column' => 'VGD ID', 'mapping' => sug[:mapping]}
plan = B.plan(file, opts, targets, FIELDS)
r = plan[:rows]
ok('VGD ID lặp trong file: cả hai dòng bị bỏ, báo trùng trong file', r[0][:status] == 'file_duplicate' && r[3][:status] == 'file_duplicate')
ok('ID không có trong bảng: không khớp', r[2][:status] == 'unmatched')
ok('ô trống = không đổi; giá trị sai (đơn giá "abc") báo lỗi riêng từng ô, ô còn lại vẫn nhập được', r[1][:status] == 'ok' && r[1][:changes].map { |c| [c[:field], c[:error] ? 'err' : c[:new]] } == [['description', 'Bàn đảo'], ['price', 'err']])
ok('đếm: ok 1, không khớp 1, trùng file 2, giá trị 1, lỗi 1', plan[:counts].values_at(:ok, :unmatched, :file_duplicate, :changes, :errors) == [1, 1, 2, 1, 1])

solo = B.table([['Mã đối tượng', 'Tên', 'Đơn giá', 'Liên kết'], ['t01', 'Tủ mới', '1250000', 'https://vgd.vn/a'], ['T02', '', '9', 'ftp://x'], ['', 'Không mã', '', '']])
p2 = B.plan(solo, {'match_by' => 'code', 'match_column' => 'Mã đối tượng', 'mapping' => {'Tên' => 'name', 'Đơn giá' => 'price', 'Liên kết' => 'url'}}, targets, FIELDS)
ok('khớp Mã đối tượng: đổi tên và đơn giá bằng giá trị cũ không tính là thay đổi; link https nhận', p2[:rows][0][:status] == 'ok' && p2[:rows][0][:changes].map { |c| c[:field] } == %w[name url])
ok('Mã trùng giữa hai món: không đoán, báo mơ hồ và bỏ qua', p2[:rows][1][:status] == 'ambiguous' && p2[:rows][1][:count] == 2)
ok('dòng không có mã: bỏ qua (blank)', p2[:rows][2][:status] == 'blank')
locked = B.plan(B.table([['VGD ID', 'Tên'], ['VGD-CCC', 'Mới']]), {'match_by' => 'vgd_id', 'match_column' => 'VGD ID', 'mapping' => {'Tên' => 'name'}}, targets, FIELDS)
ok('món bị khóa: không đổi, trạng thái locked', locked[:rows][0][:status] == 'locked')
gap = B.table([['VGD ID', 'Tên'], ['', ''], ['vgd-aaa', 'N']])
ok('số dòng báo đúng dòng gốc dù có dòng trống chen giữa', gap[:numbers] == [3] && gap[:header_row] == 1)
ok('đơn giá 1250000.0 bằng 1250000 (không thành thay đổi giả)', B.same?('price', 1_250_000.0, B.clean('price', '1250000')))

bad = {'khóa khớp sai' => opts.merge('match_by' => 'name'), 'cột khớp không có' => opts.merge('match_column' => 'Z'), 'không chọn cột nhập' => opts.merge('mapping' => {}),
       'cột không có trong file' => opts.merge('mapping' => {'Q' => 'name'}), 'trường lạ' => opts.merge('mapping' => {'Tên' => 'tag'}),
       'ghi vào cột khớp' => opts.merge('mapping' => {'VGD ID' => 'name'}), 'hai cột cùng trường' => opts.merge('mapping' => {'Tên' => 'name', 'Mô tả' => 'name'})}
bad.each { |label, o| ok("tùy chọn sai bị từ chối: #{label}", !error_of { B.plan(file, o, targets, FIELDS) }.nil?) }

ok('trường mô tả quá dài bị lỗi ô, không nhập', B.plan(B.table([['VGD ID', 'Mô tả'], ['vgd-aaa', 'x' * 1001]]), {'match_by' => 'vgd_id', 'match_column' => 'VGD ID', 'mapping' => {'Mô tả' => 'description'}}, targets, FIELDS)[:rows][0][:changes][0][:error].to_s.include?('1000'))
bad_files = {'không có dữ liệu' => "VGD ID,Tên\n", 'tiêu đề trùng' => "VGD ID,Tên,Tên\nx,y,z\n"}
bad_files.each { |label, text| path = File.join(dir, 'b.csv'); File.write(path, text); ok("file sai bị từ chối: #{label}", !error_of { B.read_file(path) }.nil?) }
File.write(File.join(dir, 'c.txt'), 'x')
ok('đuôi file lạ bị từ chối', error_of { B.read_file(File.join(dir, 'c.txt')) }.to_s.include?('Excel'))
ok('file không tồn tại bị từ chối', !error_of { B.read_file(File.join(dir, 'none.csv')) }.nil?)

# Nhập lại file Excel do chính BIM xuất (có dòng tiêu đề và ghi chú phía trên hàng tiêu đề cột)
cols = [{'label' => 'STT', 'unit' => '', 'type' => 'ordinal', 'digits' => 0}, {'label' => 'VGD ID', 'unit' => '', 'type' => 'text', 'digits' => 0},
        {'label' => 'Tên', 'unit' => '', 'type' => 'text', 'digits' => 0}, {'label' => 'Đơn giá', 'unit' => 'VND', 'type' => 'number', 'digits' => 0}]
rows = [{'kind' => 'row', 'cells' => [1, 'vgd-aaa', 'Tủ đổi tên', 2_000_000]}, {'kind' => 'row', 'cells' => [2, 'vgd-bbb', 'Bàn', nil]}, {'kind' => 'total', 'cells' => [nil, nil, 'Tổng', 2_000_000]}]
report = VGD::BIM::TableReport.build({'title' => 'Bảng', 'preset' => 'P', 'decimal_separator' => ',', 'labels' => {'model' => 'Mô hình', 'preset' => 'Preset', 'date' => 'Ngày', 'print' => 'In'}, 'columns' => cols, 'rows' => rows}, 'M', ->(_p) { nil })
xlsx = File.join(dir, 'export.xlsx')
File.binwrite(xlsx, VGD::BIM::Xlsx.build(report))
exported = B.read_file(xlsx)
ok('Excel do BIM xuất: tìm đúng dòng tiêu đề (bỏ dòng tiêu đề và ghi chú phía trên), có cột VGD ID', exported[:headers].include?('VGD ID') && exported[:header_row] > 1 && exported[:headers].first(4).include?('Tên'))
es = B.suggest(exported[:headers], FIELDS)
ep = B.plan(exported, {'match_by' => es[:match_by], 'match_column' => es[:match_column], 'mapping' => es[:mapping]}, targets, FIELDS)
ok('nhập lại file xuất: dòng tổng không khớp (bỏ qua), tên và đơn giá món đầu được đề xuất, số dòng đúng số dòng Excel', ep[:rows].find { |r| r[:status] == 'ok' }[:changes].map { |c| c[:field] } == %w[name price] && ep[:rows].find { |r| r[:key] == 'vgd-aaa' }[:row] == exported[:header_row] + 2 && ep[:rows].last[:status] == 'blank')

puts($fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
