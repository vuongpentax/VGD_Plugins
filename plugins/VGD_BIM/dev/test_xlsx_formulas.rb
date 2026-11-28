# Test ô tính toán thành công thức khi xuất Excel (core/xlsx_formulas.rb, nối ở core/xlsx.rb và core/table_report.rb): diện tích, thành tiền,
# khối lượng theo cách tính và theo công thức của tag, hao hụt và tiền vật liệu, dòng nhóm / tổng SUBTOTAL, dữ liệu sai bị từ chối.
# Có LibreOffice (soffice) thì mở file, tính lại và so kết quả với số của plugin; không có thì bỏ qua phần đó. Chạy: ruby dev/test_xlsx_formulas.rb
require 'json'
require 'tmpdir'
require 'zlib'
require 'csv'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_xlsx_formulas')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
module VGD; module BIM; def self.log(_m); end; end; end
require File.join(ROOT, 'core/table_report')
TR = VGD::BIM::TableReport
XF = VGD::BIM::XlsxFormulas

def read_zip(bytes)
  eocd = bytes.rindex([0x06054b50].pack('V'))
  total, _size, pos = bytes.byteslice(eocd + 10, 12).unpack('vVV')
  files = {}
  total.times do
    method, = bytes.byteslice(pos + 10, 2).unpack('v')
    csize, = bytes.byteslice(pos + 20, 4).unpack('V')
    name_len, extra_len, comment_len = bytes.byteslice(pos + 28, 6).unpack('vvv')
    local, = bytes.byteslice(pos + 42, 4).unpack('V')
    name = bytes.byteslice(pos + 46, name_len)
    lname, lextra = bytes.byteslice(local + 26, 4).unpack('vv')
    data = bytes.byteslice(local + 30 + lname + lextra, csize)
    files[name] = method == 8 ? Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(data) : data
    pos += 46 + name_len + extra_len + comment_len
  end
  files
end

col = ->(key, label, type = 'number', si: 1, digits: 2) { {'key' => key, 'label' => label, 'unit' => '', 'type' => type, 'digits' => digits, 'si' => si} }
columns = [col.call('ordinal', '#', 'ordinal', digits: 0), col.call('instance', 'Tên', 'text', digits: 0),
           col.call('lenX', 'Rộng', si: 0.001, digits: 0), col.call('lenY', 'Dài', si: 0.001, digits: 0), col.call('lenZ', 'Cao', si: 0.001, digits: 0),
           col.call('areaXZ', 'Diện tích X*Z'), col.call('price', 'Đơn giá', digits: 0), col.call('quantity', 'Số lượng', digits: 0), col.call('total', 'Thành tiền', digits: 0),
           col.call('calc_qty', 'Khối lượng tính', digits: 3), col.call('calc_unit', 'Đơn vị tính', 'text', digits: 0), col.call('calc_total', 'Thành tiền theo KL', digits: 0),
           col.call('mat_waste', 'Hao hụt %', digits: 1), col.call('mat_price', 'Đơn giá VL', digits: 0), col.call('mat_qty', 'KL có hao hụt', digits: 3), col.call('mat_cost', 'Tiền VL', digits: 0)]
row = ->(cells, calc) { {'kind' => 'row', 'pid' => nil, 'cells' => cells, 'calc' => calc} }
rows = [
  {'kind' => 'group', 'cells' => [nil, 'Nhóm A · 2', nil, nil, nil, 2.4, nil, 2, 100, nil, nil, 240, nil, nil, nil, 25.2]},
  row.call([1, 'Tường', 1200, 600, 2000, 2.4, 100, 1, 100, 2.4, 'm²', 240, 5, 10, 2.52, 25.2], {'method' => 'area', 'unit' => 'm2', 'mat_ok' => true, 'mat_unit_ok' => true}),
  row.call([2, 'Len', 1200, 600, 2000, 2.4, nil, 1, nil, 3.6, 'm', nil, nil, nil, nil, nil], {'method' => 'formula', 'formula' => 'ROUNDUP((Rộng + Sâu) x 2; 1)', 'unit' => 'm'}),
  {'kind' => 'group', 'cells' => [nil, 'Nhóm B · 2', nil, nil, nil, 0.5, nil, 2, nil, nil, nil, nil, nil, nil, nil, nil]},
  row.call([3, 'Cột', 400, 400, 3000, 1.2, nil, 1, nil, 0.48, 'm³', nil, nil, nil, nil, nil], {'method' => 'volume', 'unit' => 'm3', 'struct_volume' => 0.48}),
  row.call([4, 'Con', 100, 100, 100, 0.01, nil, 1, nil, 1, 'cái', nil, nil, nil, nil, nil], {'method' => 'count', 'unit' => 'pcs', 'counted' => false}),
  {'kind' => 'total', 'cells' => [nil, 'Tổng cộng · 3', nil, nil, nil, 3.6, nil, 3, 100, nil, nil, 240, nil, nil, nil, 25.2]}
]
payload = {'title' => 'Bảng', 'preset' => 'Tất cả', 'decimal_separator' => ',', 'columns' => columns, 'rows' => rows}
report = TR.build(payload, 'm.skp', ->(*) { nil })

# 1. Kiểm tra dữ liệu: khóa / hệ số / dữ liệu tính sai bị từ chối
bad = ->(change) { error_of { TR.build(change.call(JSON.parse(JSON.generate(payload))), 'm.skp', ->(*) { nil }) }.to_s.include?('không hợp lệ') }
ok 'khóa cột lạ (ký tự đặc biệt) bị từ chối', bad.call(->(p) { p['columns'][2]['key'] = 'A1+B1'; p })
ok 'hệ số đổi đơn vị âm / không phải số bị từ chối', bad.call(->(p) { p['columns'][2]['si'] = -1; p }) && bad.call(->(p) { p['columns'][2]['si'] = 'x'; p })
ok 'cách tính lạ bị từ chối', bad.call(->(p) { p['rows'][1]['calc']['method'] = 'eval'; p })
ok 'đơn vị lạ bị từ chối', bad.call(->(p) { p['rows'][1]['calc']['unit'] = 'm"&HYPERLINK('; p })
ok 'số đo chính xác không phải số bị từ chối', bad.call(->(p) { p['rows'][4]['calc']['struct_volume'] = '1+1'; p })
ok 'không gửi khóa / dữ liệu tính: vẫn xuất như cũ', TR.build({'title' => 'x', 'columns' => [{'label' => 'A', 'type' => 'number'}], 'rows' => [{'kind' => 'row', 'cells' => [1]}]}, 'm', ->(*) { nil })[:rows][0][:calc].nil?

# 2. Công thức của từng ô
sheet = XF::Sheet.new(report[:columns])
data = report[:rows]
f1 = XF.row_formulas(sheet, data[1][:calc], 6)
ok 'diện tích X*Z = Rộng x Cao (đổi mm ra m)', f1[5] == 'IF(COUNT(C6,E6)=2,C6*0.001*E6*0.001,"")'
ok 'thành tiền = đơn giá x số lượng', f1[8] == 'IF(COUNT(G6)=0,"",G6*H6)'
ok 'khối lượng theo diện tích tham chiếu ô diện tích', f1[9] == 'IF(COUNT(F6)=1,F6,"")'
ok 'thành tiền theo khối lượng', f1[11] == 'IF(COUNT(G6,J6)=2,G6*J6,"")'
ok 'khối lượng có hao hụt', f1[14] == 'IF(COUNT(J6)=0,"",J6*(1+N(M6)/100))'
ok 'tiền vật liệu', f1[15] == 'IF(COUNT(O6,N6)=2,O6*N6,"")'
f2 = XF.row_formulas(sheet, data[2][:calc], 7)
ok 'công thức của tag dịch sang Excel với ô của dòng', f2[9] == 'IF(COUNT(C7,D7)=2,ROUNDUP((((C7*0.001)+(D7*0.001))*2),1),"")'
ok 'không có vật liệu: không có công thức hao hụt / tiền vật liệu', !f2.key?(14) && !f2.key?(15)
f3 = XF.row_formulas(sheet, data[4][:calc], 9)
ok 'thể tích chính xác của VGD Structure: giữ số, không công thức', !f3.key?(9)
ok 'theo cái: giữ số 1', !XF.row_formulas(sheet, data[5][:calc], 10).key?(9)
ok 'thiếu cột gốc (không có Rộng): không dựng công thức', !XF.row_formulas(XF::Sheet.new(report[:columns].reject { |c| c[:key] == 'lenX' }), data[1][:calc], 6).key?(4)
ok 'công thức tag sai: giữ số', !XF.row_formulas(sheet, data[2][:calc].merge(formula: 'Rộng ^ 2'), 7).key?(9)
ok 'hệ số khác 1 cho cột kết quả (diện tích hiện cm²)', XF.row_formulas(XF::Sheet.new(report[:columns].map { |c| c[:key] == 'areaXZ' ? c.merge(si: 0.0001) : c }), data[1][:calc], 6)[5] == 'IF(COUNT(C6,E6)=2,(C6*0.001*E6*0.001)/0.0001,"")'
ok 'Diện tích trong công thức dùng số chính xác khi có', XF.calc_formula(sheet, data[2][:calc].merge(formula: 'Diện tích x 2', struct_area: 5.5), 7) == '((5.5)*2)'
ok 'Thể tích trong công thức: khối bao khi không có thể tích', XF.calc_formula(sheet, data[2][:calc].merge(formula: 'Thể tích'), 7) == 'IF(COUNT(C7,D7,E7)=3,(C7*0.001*D7*0.001*E7*0.001),"")'
ok 'chạy tổng: khoảng liên tiếp', XF.runs([5, 6, 7, 9, 11, 12]) == [[5, 7], [9, 9], [11, 12]]

# 3. File Excel: ô có <f>, giữ số đã tính, tính lại khi mở
dir = Dir.mktmpdir('vgd_xlsx_formulas')
path = File.join(dir, 'bang.xlsx')
VGD::BIM::Xlsx.write(path, report)
files = read_zip(File.binread(path))
xml = files['xl/worksheets/sheet1.xml'].force_encoding('UTF-8')
first = 6 # tiêu đề 1, ghi chú 2, trống 3, đầu cột 4 + 1 (META_ROW = 2, header = 4, dữ liệu từ 5)
cell = ->(ref) { xml[%r{<c r="#{ref}"[^>/]*(?:/>|>(.*?)</c>)}, 1].to_s }
data_start = xml[/<c r="B(\d+)"[^>]*t="inlineStr"><is><t xml:space="preserve">Nhóm A/, 1].to_i
ok 'tìm được dòng nhóm đầu', data_start.positive?
g = data_start
r1 = g + 1
ok 'ô diện tích của dòng món là công thức kèm số đã tính', cell.call("F#{r1}") == "<f>IF(COUNT(C#{r1},E#{r1})=2,C#{r1}*0.001*E#{r1}*0.001,&quot;&quot;)</f><v>2.4</v>"
ok 'ô nhóm: SUBTOTAL các dòng của nhóm', cell.call("F#{g}").start_with?("<f>SUBTOTAL(9,F#{g + 1}:F#{g + 2})</f>")
ok 'ô nhóm B: bỏ dòng con không được cộng', cell.call("H#{g + 3}").start_with?("<f>SUBTOTAL(9,H#{g + 4})</f>")
ok 'ô tổng: SUBTOTAL các dòng được cộng, nhiều khoảng', cell.call("I#{g + 6}").start_with?("<f>SUBTOTAL(9,I#{g + 1}:I#{g + 2},I#{g + 4})</f>")
ok 'khối lượng tính của nhóm khác đơn vị: không cộng; nhóm cùng đơn vị: SUBTOTAL', !cell.call("J#{g}").include?('<f>') && cell.call("J#{g + 3}").start_with?("<f>SUBTOTAL(9,J#{g + 4})</f>")
ok 'ô chữ không bao giờ là công thức', !cell.call("K#{r1}").include?('<f>') && !cell.call("B#{r1}").include?('<f>')
ok 'workbook bắt Excel tính lại khi mở', files['xl/workbook.xml'].include?('<calcPr calcId="191029" fullCalcOnLoad="1"/>')

# 4. Có LibreOffice: mở file, tính lại, so với số của plugin
soffice = ENV['PATH'].split(File::PATH_SEPARATOR).map { |d| File.join(d, 'soffice') }.find { |f| File.executable?(f) }
if soffice
  # bỏ số đã lưu để chắc chắn LibreOffice tự tính từ công thức
  stripped = File.join(dir, 'tinh_lai.xlsx')
  # bỏ số đã lưu ở mọi ô tính toán (LibreOffice không chạy lại công thức có số lưu sẵn khi mở file .xlsx; Excel thì tính lại nhờ fullCalcOnLoad)
  strip = ->(list) { list.map { |r| r.merge(cells: r[:cells].each_with_index.map { |v, i| r[:kind] == 'row' ? ([5, 8, 9, 11, 14, 15].include?(i) ? nil : v) : (v.is_a?(Numeric) ? nil : v) }) } }
  report_no_cache = report.merge(rows: strip.call(report[:rows]), sheets: report[:sheets].map { |sh| sh.merge(rows: strip.call(sh[:rows])) })
  VGD::BIM::Xlsx.write(stripped, report_no_cache)
  system(soffice, '--headless', '--convert-to', 'csv:Text - txt - csv (StarCalc):44,34,76,1,,0,false,true,false,false', '--outdir', dir, stripped, out: File::NULL, err: File::NULL)
  csv_path = File.join(dir, 'tinh_lai.csv')
  if File.exist?(csv_path)
    table = CSV.read(csv_path)
    find = ->(name) { table.find { |line| line[1].to_s.start_with?(name) } }
    num = ->(line, i) { line && line[i].to_s.tr(',', '').to_f }
    wall = find.call('Tường')
    trim = find.call('Len')
    total = find.call('Tổng cộng')
    ok 'LibreOffice: diện tích 2,4; thành tiền 100; khối lượng 2,4; tiền theo KL 240', [5, 8, 9, 11].map { |i| num.call(wall, i) } == [2.4, 100.0, 2.4, 240.0]
    ok 'LibreOffice: hao hụt 5% ra 2,52; tiền vật liệu 25,2', (num.call(wall, 14) - 2.52).abs < 1e-9 && (num.call(wall, 15) - 25.2).abs < 1e-9
    ok 'LibreOffice: công thức tag ROUNDUP((1,2 + 0,6) x 2; 1) = 3,6', (num.call(trim, 9) - 3.6).abs < 1e-9
    ok 'LibreOffice: dòng không có đơn giá thì thành tiền để trống', trim[8].to_s.strip.empty?
    ok 'LibreOffice: tổng diện tích bỏ dòng con (2,4 + 2,4 + 1,2 = 6), số lượng 3 (tính từ công thức)', (num.call(total, 5) - 6.0).abs < 1e-9 && num.call(total, 7) == 3.0
    group_a = find.call('Nhóm A')
    ok 'LibreOffice: tổng nhóm A tính lại (diện tích 4,8; tiền 100; tiền theo KL 240)', (num.call(group_a, 5) - 4.8).abs < 1e-9 && num.call(group_a, 8) == 100.0 && num.call(group_a, 11) == 240.0
  else
    puts 'BỎ QUA  LibreOffice không đổi được file (không kiểm tính lại)'
  end
else
  puts 'BỎ QUA  không có LibreOffice: không kiểm kết quả tính lại'
end

puts($fails.zero? ? 'ALL PASS' : "#{$fails} FAIL")
exit($fails.zero? ? 0 : 1)
