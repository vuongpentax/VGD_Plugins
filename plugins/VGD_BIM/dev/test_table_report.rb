# Test xuất bảng khối lượng ra Excel (.xlsx có ảnh) và trang báo cáo in PDF: kiểm tra dữ liệu giao diện gửi lên, cấu trúc file zip / XML,
# ô số và chữ, ảnh trong ô, liên kết, nhóm và dòng tổng, trang HTML. Chạy: ruby dev/test_table_report.rb
# Chỉ kiểm tra bằng mô phỏng và bộ đọc zip / XML tự viết; chưa mở bằng Excel thật.
require 'json'
require 'tmpdir'
require 'zlib'
require 'rexml/document'
require 'fileutils'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_report')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
module VGD; module BIM; def self.log(_m); end; end; end
require File.join(ROOT, 'core/table_report')
TR = VGD::BIM::TableReport

# PNG hợp lệ w x h (một màu)
def png(width, height)
  chunk = ->(type, data) { [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N') }
  raw = (0...height).map { "\x00".b + "\x20\x80\xC0".b * width }.join
  "\x89PNG\r\n\x1A\n".b + chunk.call('IHDR', [width, height, 8, 2, 0, 0, 0].pack('NNCCCCC')) + chunk.call('IDAT', Zlib::Deflate.deflate(raw)) + chunk.call('IEND', ''.b)
end

# Đọc file zip: kiểm tra CRC và kích thước từng tệp, trả về {tên => nội dung}
def read_zip(bytes)
  eocd = bytes.rindex([0x06054b50].pack('V'))
  total, dir_size, dir_start = bytes.byteslice(eocd + 10, 12).unpack('vVV')
  pos = dir_start
  files = {}
  total.times do
    sig, _v1, _v2, _flag, method, _t, _d, crc, csize, size, name_len, extra_len, comment_len, _disk, _int, _ext, offset = bytes.byteslice(pos, 46).unpack('VvvvvvvVVVvvvvvVV')
    raise 'sai chữ ký thư mục zip' unless sig == 0x02014b50
    name = bytes.byteslice(pos + 46, name_len).force_encoding('UTF-8')
    lname_len, lextra_len = bytes.byteslice(offset + 26, 4).unpack('vv')
    body = bytes.byteslice(offset + 30 + lname_len + lextra_len, csize)
    data = method == 8 ? Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(body) : body
    raise "sai CRC hoặc dung lượng: #{name}" unless Zlib.crc32(data) == crc && data.bytesize == size
    files[name] = data
    pos += 46 + name_len + extra_len + comment_len
  end
  files
end

NS = {'m' => 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}.freeze
def xml(text); REXML::Document.new(text.dup.force_encoding('UTF-8')); end
def cell_value(doc, ref)
  node = REXML::XPath.first(doc, "//m:c[@r='#{ref}']", NS)
  return nil unless node
  inline = REXML::XPath.first(node, 'm:is/m:t', NS)
  return inline.text.to_s if inline
  value = REXML::XPath.first(node, 'm:v', NS)
  value && value.text.to_f
end

COLUMNS = [
  {'label' => 'STT', 'unit' => '', 'type' => 'ordinal', 'digits' => 0},
  {'label' => 'Ảnh', 'unit' => '', 'type' => 'image', 'digits' => 0},
  {'label' => 'Tên', 'unit' => '', 'type' => 'text', 'digits' => 0},
  {'label' => 'Rộng (X) mm', 'unit' => 'mm', 'type' => 'number', 'digits' => 0},
  {'label' => 'Diện tích m²', 'unit' => 'm²', 'type' => 'number', 'digits' => 2},
  {'label' => 'Link', 'unit' => '', 'type' => 'link', 'digits' => 0},
  {'label' => 'Đơn giá', 'unit' => 'VND', 'type' => 'number', 'digits' => 0}
].freeze
ROWS = [
  {'kind' => 'group', 'cells' => [nil, nil, 'Tủ · 2', nil, 3.5, nil, nil]},
  {'kind' => 'row', 'pid' => 900, 'cells' => [1, nil, 'Tủ <bếp> & "A"', 1200, 1.2345, 'https://vgd.vn/tu?a=1&b=2', 2_500_000]},
  {'kind' => 'row', 'pid' => 901, 'cells' => [2, nil, '=SUM(A1:A9)', 900.5, 2.2655, 'javascript:alert(1)', nil]},
  {'kind' => 'row', 'pid' => 902, 'cells' => [3, nil, "Dòng\u0001 không ảnh", nil, nil, '', nil]},
  {'kind' => 'total', 'cells' => [nil, nil, 'Tổng cộng · 3 đối tượng', nil, 3.5, nil, nil]}
].freeze
LABELS = {'model' => 'Mô hình', 'preset' => 'Preset', 'date' => 'Ngày', 'print' => 'In / Lưu PDF'}.freeze
def payload(**over)
  {'title' => 'Bảng khối lượng', 'preset' => 'Nội thất', 'decimal_separator' => ',', 'labels' => LABELS, 'columns' => COLUMNS, 'rows' => ROWS}.merge(over.transform_keys(&:to_s))
end
IMAGES = {900 => png(128, 96), 901 => png(64, 128)}.freeze
FINDER = ->(pid) { IMAGES[pid] }
def build(over = {}, finder = FINDER)
  TR.build(payload(**over), 'Nhà mẫu', finder)
end
def error_of(&block)
  block.call
  nil
rescue ArgumentError => e
  e.message
end

# ---- Kiểm tra dữ liệu giao diện gửi lên ----
report = build
ok('dựng báo cáo: 7 cột, 5 dòng, tiêu đề và dòng ghi chú có model, preset, ngày', report[:columns].size == 7 && report[:rows].size == 5 && report[:meta].start_with?('Mô hình: Nhà mẫu  ·  Preset: Nội thất  ·  Ngày: ') && report[:meta].include?('Ngày: '))
ok('ảnh: chỉ nạp ảnh của dòng có ảnh PNG hợp lệ, kèm kích thước đọc từ file', report[:images].keys.sort == [900, 901] && report[:images][900][:width] == 128 && report[:images][900][:height] == 96 && report[:rows][2][:image] && report[:rows][3][:image].nil?)
ok('không có cột Ảnh: không nạp ảnh nào', build('columns' => COLUMNS.reject { |c| c['type'] == 'image' }.map(&:dup), 'rows' => ROWS.map { |r| r.merge('cells' => r['cells'].reject.with_index { |_, i| i == 1 }) })[:images].empty?)
ok('file ảnh không phải PNG hoặc kích thước vô lý bị bỏ qua, không làm hỏng báo cáo', build({}, ->(pid) { pid == 900 ? 'GIF89a....' : "\x89PNG\r\n\x1A\n".b + [13].pack('N') + 'IHDR'.b + [0, 5].pack('NN') })[:images].empty?)
ok('ảnh quá lớn bị bỏ qua', build({}, ->(_pid) { png(8, 8) + ('x' * (VGD::BIM::Images::MAX_BYTES + 1)) })[:images].empty?)
bad = {
  'không phải bảng' => nil,
  'cột rỗng' => {'columns' => []},
  'quá 60 cột' => {'columns' => Array.new(61) { COLUMNS[2] }, 'rows' => [{'kind' => 'row', 'cells' => Array.new(61, 'a')}]},
  'kiểu cột lạ' => {'columns' => [COLUMNS[2].merge('type' => 'formula')], 'rows' => [{'kind' => 'row', 'cells' => ['a']}]},
  'số lẻ 7' => {'columns' => [COLUMNS[3].merge('digits' => 7)], 'rows' => [{'kind' => 'row', 'cells' => [1]}]},
  'số lẻ là chữ' => {'columns' => [COLUMNS[3].merge('digits' => '2')], 'rows' => [{'kind' => 'row', 'cells' => [1]}]},
  'số ô khác số cột' => {'rows' => [{'kind' => 'row', 'cells' => [1]}]},
  'loại dòng lạ' => {'rows' => ROWS.map { |r| r.merge('kind' => 'evil') }},
  'ô là đối tượng' => {'rows' => [ROWS[1].merge('cells' => ROWS[1]['cells'].dup.tap { |c| c[2] = {'x' => 1} })]},
  'ô là số vô hạn' => {'rows' => [ROWS[1].merge('cells' => ROWS[1]['cells'].dup.tap { |c| c[3] = Float::INFINITY })]},
  'ô chữ quá dài' => {'rows' => [ROWS[1].merge('cells' => ROWS[1]['cells'].dup.tap { |c| c[2] = 'a' * 2001 })]},
  'mã đối tượng không hợp lệ' => {'rows' => [ROWS[1].merge('pid' => 'abc')]},
  'mã đối tượng âm' => {'rows' => [ROWS[1].merge('pid' => -4)]},
  'quá 50.000 dòng' => {'rows' => Array.new(50_001) { ROWS[3] }},
  'tiêu đề quá dài' => {'title' => 'a' * 201}
}
bad.each do |name, over|
  message = begin
    over.nil? ? error_of { TR.build('chuỗi', 'M', FINDER) } : error_of { build(over) }
  end
  ok("dữ liệu sai bị từ chối: #{name}", !message.nil?)
end
ok('bảng chỉ có nhóm / tổng, không có dòng dữ liệu: báo lỗi tiếng Việt', error_of { build('rows' => [ROWS[0], ROWS[4]]) }.to_s.include?('chưa có dòng'))
ok('mã đối tượng dạng chữ số được nhận như số', build('rows' => [ROWS[1].merge('pid' => '900')])[:rows][0][:pid] == 900)

# ---- File .xlsx ----
Dir.mktmpdir do |dir|
  path = File.join(dir, 'bang.xlsx')
  VGD::BIM::Xlsx.write(path, report)
  bytes = File.binread(path)
  ok('file bắt đầu bằng chữ ký zip', bytes.byteslice(0, 4) == "PK\x03\x04".b)
  files = read_zip(bytes)
  ok('đủ các phần bắt buộc của .xlsx', %w[[Content_Types].xml _rels/.rels xl/workbook.xml xl/_rels/workbook.xml.rels xl/styles.xml xl/worksheets/sheet1.xml xl/worksheets/_rels/sheet1.xml.rels xl/drawings/drawing1.xml xl/drawings/_rels/drawing1.xml.rels xl/media/image1.png xl/media/image2.png].all? { |n| files.key?(n) })
  well_formed = files.select { |n, _| n.end_with?('.xml', '.rels') }.all? { |n, d| begin; xml(d); true; rescue StandardError; puts "XML hỏng: #{n}"; false; end }
  ok('mọi tệp XML đều hợp lệ (đọc được bằng bộ phân tích XML)', well_formed)
  ok('ảnh nhúng nguyên vẹn (đúng byte với file PNG gốc)', files['xl/media/image1.png'] == IMAGES[900] && files['xl/media/image2.png'] == IMAGES[901])
  types = xml(files['[Content_Types].xml'])
  overrides = REXML::XPath.match(types, '//Override').map { |o| o.attributes['PartName'] }
  ok('khai báo loại nội dung cho mọi phần có thật', overrides.all? { |part| files.key?(part.sub(%r{\A/}, '')) } && overrides.include?('/xl/drawings/drawing1.xml'))
  rels_ok = %w[_rels/.rels xl/_rels/workbook.xml.rels xl/worksheets/_rels/sheet1.xml.rels xl/drawings/_rels/drawing1.xml.rels].all? do |rel|
    base = File.dirname(File.dirname(rel))
    REXML::XPath.match(xml(files[rel]), '//Relationship').all? { |r| r.attributes['TargetMode'] == 'External' || files.key?(File.expand_path(r.attributes['Target'], "/#{base == '.' ? '' : base}").sub(%r{\A/}, '')) }
  end
  ok('mọi quan hệ (rels) trỏ tới phần có thật trong file', rels_ok)
  sheet = xml(files['xl/worksheets/sheet1.xml'])
  ok('tiêu đề và ghi chú ở hai hàng đầu', cell_value(sheet, 'A1') == 'Bảng khối lượng' && cell_value(sheet, 'A2').start_with?('Mô hình: Nhà mẫu'))
  ok('hàng tiêu đề cột (hàng 4) và hàng đơn vị (hàng 5)', (0..6).map { |i| cell_value(sheet, "#{('A'.ord + i).chr}4") } == COLUMNS.map { |c| c['label'] } && cell_value(sheet, 'D5') == 'mm' && cell_value(sheet, 'G5') == 'VND')
  ok('dòng nhóm (hàng 6): nhãn và tổng là số', cell_value(sheet, 'C6') == 'Tủ · 2' && cell_value(sheet, 'E6') == 3.5)
  ok('dòng dữ liệu: số lưu dạng số, chữ lưu dạng chữ', cell_value(sheet, 'A7') == 1.0 && cell_value(sheet, 'D7') == 1200.0 && (cell_value(sheet, 'E7') - 1.2345).abs < 1e-9 && cell_value(sheet, 'G7') == 2_500_000.0 && cell_value(sheet, 'D8') == 900.5)
  ok('chữ chứa < > & " được mã hóa, ký tự điều khiển bị bỏ', cell_value(sheet, 'C7') == 'Tủ <bếp> & "A"' && cell_value(sheet, 'C9') == 'Dòng không ảnh')
  ok('chữ bắt đầu bằng = là văn bản, không thành công thức', cell_value(sheet, 'C8') == '=SUM(A1:A9)' && REXML::XPath.match(sheet, '//m:f', NS).empty?)
  ok('ô không có giá trị để trống (không ghi số 0)', cell_value(sheet, 'D9').nil? && cell_value(sheet, 'G8').nil?)
  ok('dòng tổng ở cuối', cell_value(sheet, 'C10') == 'Tổng cộng · 3 đối tượng' && cell_value(sheet, 'E10') == 3.5)
  links = REXML::XPath.match(sheet, '//m:hyperlink', NS)
  rels = REXML::XPath.match(xml(files['xl/worksheets/_rels/sheet1.xml.rels']), '//Relationship')
  ok('liên kết: chỉ http / https được tạo (javascript: chỉ là chữ), địa chỉ nằm trong rels', links.size == 1 && links[0].attributes['ref'] == 'F7' && rels.any? { |r| r.attributes['Target'] == 'https://vgd.vn/tu?a=1&b=2' && r.attributes['TargetMode'] == 'External' })
  drawing = xml(files['xl/drawings/drawing1.xml'])
  anchors = REXML::XPath.match(drawing, '//xdr:oneCellAnchor', 'xdr' => 'http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing')
  ok('ảnh đặt trong ô cột Ảnh (cột B) ở đúng hai dòng có ảnh', anchors.map { |a| [REXML::XPath.first(a, 'xdr:from/xdr:col', 'xdr' => 'http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing').text.to_i, REXML::XPath.first(a, 'xdr:from/xdr:row', 'xdr' => 'http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing').text.to_i] } == [[1, 6], [1, 7]])
  sizes = anchors.map { |a| ext = REXML::XPath.first(a, 'xdr:ext', 'xdr' => 'http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing'); [ext.attributes['cx'].to_i / 9525, ext.attributes['cy'].to_i / 9525] }
  ok('ảnh giữ tỉ lệ và nằm trong khung ô (không méo, không tràn)', sizes[0] == [128, 96] && sizes[1] == [53, 106] && sizes.all? { |w, h| w <= 136 && h <= 106 })
  rows = REXML::XPath.match(sheet, '//m:row', NS).to_h { |r| [r.attributes['r'].to_i, r.attributes['ht']] }
  ok('hàng có ảnh cao 84pt, hàng không ảnh (dữ liệu) vẫn cao bằng nhau để bảng đều', rows[7] == '84' && rows[8] == '84' && rows[9] == '84' && rows[4].nil?)
  pane = REXML::XPath.first(sheet, '//m:pane', NS)
  ok('cố định hàng tiêu đề và hàng đơn vị khi cuộn', pane.attributes['ySplit'] == '5' && pane.attributes['state'] == 'frozen')
  styles = xml(files['xl/styles.xml'])
  formats = REXML::XPath.match(styles, '//m:numFmt', NS).map { |f| f.attributes['formatCode'] }
  ok('định dạng số: nghìn có dấu phân cách, số lẻ theo cột (0 và 2)', formats.sort == ['#,##0', '#,##0.00'])
  workbook = files['xl/workbook.xml'].force_encoding('UTF-8')
  ok('tên sheet theo tiêu đề; hàng tiêu đề lặp lại khi in', workbook.include?('name="Bảng khối lượng"') && workbook.include?('!$4:$5'))
  big_png = png(512, 512)
  large = read_zip(VGD::BIM::Xlsx.build(build({}, ->(pid) { pid == 900 ? big_png : nil })))
  big_ext = REXML::XPath.first(xml(large['xl/drawings/drawing1.xml']), '//xdr:ext', 'xdr' => 'http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing')
  ok('ảnh 512 x 512: nhúng đủ độ phân giải gốc, chỉ hiển thị thu nhỏ vừa ô (106 x 106)', large['xl/media/image1.png'] == big_png && [big_ext.attributes['cx'].to_i / 9525, big_ext.attributes['cy'].to_i / 9525] == [106, 106])
  tmp_dup = build('rows' => [ROWS[1], ROWS[1], ROWS[1]])
  dup_files = read_zip(VGD::BIM::Xlsx.build(tmp_dup))
  ok('cùng một ảnh dùng cho nhiều dòng: chỉ nhúng một lần', dup_files.keys.grep(%r{\Axl/media/}).size == 1 && REXML::XPath.match(xml(dup_files['xl/drawings/drawing1.xml']), '//xdr:oneCellAnchor', 'xdr' => 'http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing').size == 3)
  no_image = build({}, ->(_pid) { nil })
  plain = read_zip(VGD::BIM::Xlsx.build(no_image))
  ok('không có ảnh nào: không tạo phần ảnh, file vẫn hợp lệ', plain.keys.none? { |n| n.include?('drawing') || n.include?('media') } && plain['[Content_Types].xml'].include?('Override') && !plain['xl/worksheets/sheet1.xml'].include?('<drawing'))
  ok('không có cột đơn vị: không có hàng đơn vị, hàng dữ liệu bắt đầu ngay sau tiêu đề', begin
    cols = COLUMNS.map { |c| c.merge('unit' => '') }
    data = read_zip(VGD::BIM::Xlsx.build(build('columns' => cols)))
    sheet2 = xml(data['xl/worksheets/sheet1.xml'])
    cell_value(sheet2, 'C5') == 'Tủ · 2' && REXML::XPath.first(sheet2, '//m:pane', NS).attributes['ySplit'] == '4'
  end)
  wide = Array.new(60) { |i| {'label' => "Cột #{i}", 'unit' => '', 'type' => 'text', 'digits' => 0} }
  many = read_zip(VGD::BIM::Xlsx.build(TR.build({'title' => 'T', 'columns' => wide, 'rows' => [{'kind' => 'row', 'cells' => Array.new(60) { |i| "v#{i}" }}]}, 'M', FINDER)))
  many_sheet = xml(many['xl/worksheets/sheet1.xml'])
  ok('60 cột: tên ô hết bảng chữ cái (AA, BH...) đúng', cell_value(many_sheet, 'AA4') == 'Cột 26' && cell_value(many_sheet, 'BH4') == 'Cột 59' && VGD::BIM::Xlsx.column_letter(0) == 'A' && VGD::BIM::Xlsx.column_letter(25) == 'Z' && VGD::BIM::Xlsx.column_letter(26) == 'AA' && VGD::BIM::Xlsx.column_letter(701) == 'ZZ' && VGD::BIM::Xlsx.column_letter(702) == 'AAA')
  big = TR.build(payload('rows' => Array.new(5000) { |i| ROWS[1].merge('pid' => 900 + i % 2, 'cells' => ROWS[1]['cells'].dup.tap { |c| c[0] = i + 1 }) }), 'M', FINDER)
  started = Time.now
  big_zip = read_zip(VGD::BIM::Xlsx.build(big))
  ok("5.000 dòng có ảnh: tạo trong #{(Time.now - started).round(1)}s, ảnh nhúng 2 lần", Time.now - started < 20 && big_zip.keys.grep(%r{\Axl/media/}).size == 2)
end

# ---- Trang báo cáo in PDF ----
html = TR.html(report)
ok('HTML: tiêu đề, bảng, ảnh nhúng base64, nút In, tự mở hộp in', html.include?('<h1>Bảng khối lượng</h1>') && html.scan('data:image/png;base64,').size == 2 && html.include?('window.print()') && html.include?('size:A4 landscape'))
ok('HTML: ảnh hiển thị tối đa 28 x 22 mm nhưng giữ nguyên dữ liệu ảnh', html.include?('max-width:28mm;max-height:22mm') && html.include?([IMAGES[900]].pack('m0')))
ok('HTML: dòng tiêu đề lặp mỗi trang, dòng không bị cắt đôi', html.include?('thead{display:table-header-group}') && html.include?('page-break-inside:avoid'))
ok('HTML: số theo dấu thập phân của preset và nhóm hàng nghìn (1.200 | 1,23 | 2.500.000)', html.include?('<td class="num">1.200</td>') && html.include?('<td class="num">1,23</td>') && html.include?('<td class="num">2.500.000</td>'))
ok('HTML: làm tròn nửa lên như bảng trên màn hình (900,5 thành 901) và không còn ký tự điều khiển', html.include?('<td class="num">901</td>') && !html.match?(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/))
ok('HTML: dấu chấm thì nghìn là dấu phẩy', TR.html(build('decimal_separator' => '.')).include?('<td class="num">2,500,000</td>') && TR.html(build('decimal_separator' => '.')).include?('<td class="num">1.23</td>'))
ok('HTML: số thứ tự không nhóm hàng nghìn, căn giữa', TR.html(build('rows' => [ROWS[1].merge('cells' => ROWS[1]['cells'].dup.tap { |c| c[0] = 1234 })])).include?('<td class="ord">1234</td>'))
ok('HTML: ô số rỗng để trống, đơn vị dưới tiêu đề cột', html.include?('<th>Rộng (X) mm<span class="unit">mm</span></th>') && !html.include?('<td class="num">0</td>'))
ok('HTML: chữ bị mã hóa, không chèn được thẻ', html.include?('Tủ &lt;bếp&gt; &amp; &quot;A&quot;') && !html.include?('<bếp>'))
inject = TR.html(build('title' => '</title><script>alert(1)</script>', 'rows' => [ROWS[1].merge('cells' => ROWS[1]['cells'].dup.tap { |c| c[2] = '<img src=x onerror=alert(1)>' })]))
ok('HTML: tiêu đề và ô chứa mã HTML đều bị vô hiệu', !inject.include?('<script>alert(1)') && !inject.include?('<img src=x') && inject.include?('&lt;img src=x onerror=alert(1)&gt;'))
ok('HTML: chỉ link http / https mới bấm được, link javascript: chỉ hiện chữ', html.include?('<a href="https://vgd.vn/tu?a=1&amp;b=2">') && !html.include?('href="javascript:'))
ok('HTML: dòng nhóm và dòng tổng có class riêng', html.include?('<tr class="group">') && html.include?('<tr class="total">'))
ok('định dạng số: âm, làm tròn, nhóm nghìn', TR.format_number(-1234567.891, 2, ',') == '-1.234.567,89' && TR.format_number(1234.5, 1, '.') == '1,234.5')
ok('định dạng số: số nhỏ không bị chèn dấu nghìn', TR.format_number(999, 0, '.') == '999' && TR.format_number(1000, 0, '.') == '1,000' && TR.format_number(-12, 1, ',') == '-12,0')
Dir.mktmpdir do |dir|
  old = File.join(dir, "#{TR::PREFIX}20200101_000000.html")
  other = File.join(dir, 'khac.html')
  File.write(old, 'x'); File.write(other, 'x')
  File.utime(Time.now - 3 * 24 * 3600, Time.now - 3 * 24 * 3600, old); File.utime(Time.now - 3 * 24 * 3600, Time.now - 3 * 24 * 3600, other)
  path = TR.write_html(report, dir)
  ok('ghi trang HTML: dọn trang báo cáo cũ của plugin, không đụng file khác', File.file?(path) && !File.exist?(old) && File.exist?(other) && File.read(path, encoding: 'UTF-8').start_with?('<!doctype html>'))
end
ok('địa chỉ file:/// mã hóa khoảng trắng và tiếng Việt, giữ ổ đĩa Windows', TR.file_url('C:\\Users\\Nguyễn Văn A\\AppData\\Local\\Temp\\b.html') == 'file:///C:/Users/Nguy%E1%BB%85n%20V%C4%83n%20A/AppData/Local/Temp/b.html' && TR.file_url('/tmp/a b.html') == 'file:///tmp/a%20b.html')

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
