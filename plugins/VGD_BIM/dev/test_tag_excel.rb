# Test đọc file Excel (.xlsx) và nhập tag từ Excel: bộ đọc zip / XML (core/xlsx_reader.rb), ánh xạ cột (core/tag_excel.rb).
# File thử được dựng bằng bộ ghi zip của plugin; chưa thử với file do Excel thật tạo. Chạy: ruby dev/test_tag_excel.rb
require 'zlib'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
module VGD; module BIM; def self.log(_m); end; end; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
%w[measure tag_tree tags xlsx_reader xlsx tag_excel].each { |f| require File.join(ROOT, "core/#{f}") }
R = VGD::BIM::XlsxReader
E = VGD::BIM::TagExcel
Z = VGD::BIM::Xlsx::Zip

def esc(text); text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;'); end
def col_letter(i); i < 26 ? (i + 65).chr : col_letter(i / 26 - 1) + (i % 26 + 65).chr; end
# Dựng .xlsx kiểu Excel: chữ dùng chung (sharedStrings) hoặc chữ nội tuyến; ô số khi giá trị là Numeric.
def make_xlsx(rows, shared: true, sheet_file: 'sheet1.xml', extra: {})
  strings = []
  body = rows.each_with_index.map do |row, r|
    cells = row.each_with_index.map do |value, c|
      next nil if value.nil?
      ref = "#{col_letter(c)}#{r + 1}"
      if value.is_a?(Numeric) then %(<c r="#{ref}"><v>#{value}</v></c>)
      elsif value == true || value == false then %(<c r="#{ref}" t="b"><v>#{value ? 1 : 0}</v></c>)
      elsif shared
        strings << value unless strings.include?(value)
        %(<c r="#{ref}" t="s"><v>#{strings.index(value)}</v></c>)
      else %(<c r="#{ref}" t="inlineStr"><is><t>#{esc(value)}</t></is></c>)
      end
    end.compact.join
    %(<row r="#{r + 1}">#{cells}</row>)
  end.join
  zip = Z.new
  zip.add('xl/workbook.xml', %(<workbook xmlns:r="x"><sheets><sheet name="Tags" sheetId="1" r:id="rId1"/></sheets></workbook>))
  zip.add('xl/_rels/workbook.xml.rels', %(<Relationships><Relationship Id="rId1" Type="worksheet" Target="worksheets/#{sheet_file}"/></Relationships>))
  zip.add("xl/worksheets/#{sheet_file}", %(<worksheet><sheetData>#{body}</sheetData></worksheet>))
  zip.add('xl/sharedStrings.xml', %(<sst>#{strings.map { |s| "<si><t>#{esc(s)}</t></si>" }.join}</sst>)) if shared
  extra.each { |name, data| zip.add(name, data) }
  zip.to_s
end

# ---- Bộ đọc .xlsx ----
rows = [['Name', 'Color', 'Dashes'], ['A. WALL', 'Color(255, 0, 0, 255)', 'Dash'], ['A. DOOR', nil, 'Default'], ['Giá & "tiền" <x>', 42, 3.0]]
got = R.read(make_xlsx(rows))
ok('đọc chữ dùng chung (sharedStrings), ô trống thành "", số nguyên bỏ .0, ký tự đặc biệt giải mã đúng', got == [['Name', 'Color', 'Dashes'], ['A. WALL', 'Color(255, 0, 0, 255)', 'Dash'], ['A. DOOR', '', 'Default'], ['Giá & "tiền" <x>', '42', '3']])
ok('đọc chữ nội tuyến (inlineStr) như file do plugin xuất', R.read(make_xlsx(rows, shared: false)) == got)
ok('ô bị bỏ cách cột (thiếu B) vẫn đúng cột nhờ địa chỉ ô', R.read(make_xlsx([['a', nil, 'c']])) == [['a', '', 'c']])
ok('ô đúng / sai (boolean)', R.read(make_xlsx([[true, false]])) == [['TRUE', 'FALSE']])
ok('trang tính đầu tiên theo workbook.xml và quan hệ, không cứng sheet1.xml', R.read(make_xlsx([['x']], sheet_file: 'sheet7.xml')) == [['x']])
rich = Z.new
rich.add('xl/workbook.xml', '<workbook/>')
rich.add('xl/worksheets/sheet1.xml', '<worksheet><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="str"><v>a &amp; b</v></c><c r="C1" t="s"><v>1</v></c></row></sheetData></worksheet>')
rich.add('xl/sharedStrings.xml', '<sst><si><r><t xml:space="preserve">Xin </t></r><r><t>chào</t></r><rPh><t>PHIEN AM</t></rPh></si><si><t>&#x4E2D;&#25991;</t></si></sst>')
ok('chữ nhiều đoạn được nối, bỏ phần phiên âm; công thức dạng chữ; mã ký tự số; không có workbook.xml.rels thì dùng sheet1.xml', R.read(rich.to_s) == [['Xin chào', 'a & b', '中文']])
ok('dòng cuối trống bị bỏ', R.read(make_xlsx([['a'], [nil], [nil]])) == [['a']])
ok('file không phải zip: báo lỗi tiếng Việt', error_of { R.read('khong phai file excel') }.to_s.include?('không phải Excel'))
ok('zip nhưng không có workbook.xml: báo lỗi', error_of { z = Z.new; z.add('a.txt', 'x'); R.read(z.to_s) }.to_s.include?('không phải Excel'))
ok('file quá lớn: từ chối', error_of { R.read('x' * (R::MAX_FILE_BYTES + 1)) }.to_s.include?('quá lớn'))
bomb = Z.new
bomb.add('xl/workbook.xml', '<workbook/>')
bomb.add('xl/worksheets/sheet1.xml', "<sheetData>#{'0' * (R::MAX_PART_BYTES + 10)}</sheetData>")
ok('phần giải nén quá lớn (file nén bom): từ chối, không nạp hết vào bộ nhớ', error_of { R.read(bomb.to_s) }.to_s.include?('quá lớn'))
many = make_xlsx(Array.new(R::MAX_ROWS + 1) { |i| ["t#{i}"] })
ok('quá nhiều dòng: từ chối', error_of { R.read(many) }.to_s.include?('quá nhiều dòng'))
wide = make_xlsx([Array.new(R::MAX_COLUMNS + 5) { |i| "c#{i}" }])
ok('quá nhiều cột: bỏ phần cột thừa, không lỗi', R.read(wide).first.size == R::MAX_COLUMNS)
broken = make_xlsx([['a']])
ok('file bị cắt cụt (mất thư mục zip): báo lỗi tiếng Việt, không treo', error_of { R.read(broken.byteslice(0, broken.bytesize / 2)) }.to_s.match?(/[À-ỹ]/))
corrupt = make_xlsx([['a']])
corrupt_eocd = corrupt.rindex([0x06054b50].pack('V'))
corrupt[corrupt.byteslice(corrupt_eocd + 16, 4).unpack1('V') + 0, 4] = "\x00\x00\x00\x00"
ok('thư mục zip sai chữ ký: báo lỗi tiếng Việt', error_of { R.read(corrupt) }.to_s.match?(/[À-ỹ]/))
long_cell = R.read(make_xlsx([['x' * 2000]])).first.first
ok('ô quá dài bị cắt', long_cell.size == R::MAX_CELL_CHARS)
enc = make_xlsx([['a']])
enc_bytes = enc.dup
eocd = enc_bytes.rindex([0x06054b50].pack('V'))
start = enc_bytes.byteslice(eocd + 16, 4).unpack1('V')
enc_bytes[start + 8, 2] = [1].pack('v')
ok('file có mã hóa: báo rõ chưa đọc được', error_of { R.read(enc_bytes) }.to_s.include?('mã hóa'))

# ---- Ánh xạ cột sang tag ----
sheet = [['Tag list', '', ''], ['Name', 'Color', 'Dashes'], ['<A. ARCHITECTURAL>', '', ''], ['A. WALL', 'Color(255, 0, 0, 255)', 'Dash'], ['A. DOOR', 'rgb(0, 128, 255)', 'Default'],
         ['<S. STRUCTURAL>', '', ''], ['S. BEAM', '#00FF88', 'Dot'], ['Tag không thư mục', '10,20,30', ''], ['', '', '']]
parsed = E.parse(sheet)
ok('tìm dòng tiêu đề sau dòng tiêu đề chung; dòng <...> là thư mục cho các tag bên dưới (kiểu Auto Tag)', parsed[:tags].map { |t| [t['name'], t['folder']] } == [['A. WALL', 'A. ARCHITECTURAL'], ['A. DOOR', 'A. ARCHITECTURAL'], ['S. BEAM', 'S. STRUCTURAL'], ['Tag không thư mục', 'S. STRUCTURAL']])
ok('màu: Color(r,g,b,a), rgb(), #hex, r,g,b đều ra #rrggbb', parsed[:tags].map { |t| t['color'] } == [[255, 0, 0], [0, 128, 255], [0, 255, 136], [10, 20, 30]].map { |c| VGD::BIM::TagTree.hex_color(c) })
ok('kiểu nét: giữ chữ, Default coi như không đặt', parsed[:tags].map { |t| t['style'] } == ['Dash', '', 'Dot', ''])
folder_col = E.parse([['Tên tag', 'Thư mục', 'Màu'], ['A. WALL', 'A. ARCHITECTURAL', '#ff0000'], ['Cột X', '', 'xanh']])
ok('cột Thư mục / Màu theo tên tiếng Việt; màu không đọc được thì bỏ màu và báo', folder_col[:tags].map { |t| [t['name'], t['folder'], t['color']] } == [['A. WALL', 'A. ARCHITECTURAL', '#ff0000'], ['Cột X', '', nil]] && folder_col[:warnings].any? { |w| w.include?('màu "xanh"') })
messy = E.parse([['name'], ['A. WALL'], ['a. wall'], ['Untagged'], ['x' * 61], [''], ['B. OK']])
ok('trùng (không phân biệt hoa thường), Untagged, tên quá dài bị bỏ kèm cảnh báo; dòng trống bỏ im lặng', messy[:tags].map { |t| t['name'] } == ['A. WALL', 'B. OK'] && messy[:warnings].size == 3)
ok('không có dòng tiêu đề / không có tag / không có dữ liệu: báo lỗi', error_of { E.parse([['a', 'b']]) }.to_s.include?('tiêu đề') && error_of { E.parse([['Name']]) }.to_s.include?('không có tag') && error_of { E.parse([]) }.to_s.include?('không có dữ liệu'))
ok('quá nhiều tag: từ chối', error_of { E.parse([['Name']] + Array.new(E::MAX_ROWS + 1) { |i| ["T#{i}"] }) }.to_s.include?('Quá nhiều'))
ok('parse_color: dạng sai bị từ chối', [nil, 'đỏ', '300,0,0', '1,2', 'rgb(1,2,3,4,5)', '#12345'].all? { |bad| E.parse_color(bad.to_s).nil? } && E.parse_color('Color(0.0, 255.0, 128.0, 255)') == [0, 255, 128])
ok('style_key: bỏ hoa thường, khoảng trắng và chữ line', E.style_key('Dash Line') == E.style_key('dash') && E.style_key('Long Dash') == 'longdash' && E.style_key('Solid Line') == 'solid')
styles = ['Solid Line', 'Dotted Line', 'Dashed Line', 'Dash Dot Line']
ok('match_style: khớp đúng, khớp gần (Dash -> Dashed Line, Dot -> Dotted Line), không khớp thì nil', E.match_style('Solid Line', styles) == 'Solid Line' && E.match_style('solid', styles) == 'Solid Line' && E.match_style('Dash', styles) == 'Dashed Line' && E.match_style('Dot', styles) == 'Dotted Line' && E.match_style('Dash Dot', styles) == 'Dash Dot Line' && E.match_style('Zigzag', styles).nil? && E.match_style('', styles).nil? && E.match_style('Do', styles).nil?)
clean = E.sanitize([{'name' => '  A.  WALL ', 'color' => '#FF0000', 'style' => ' Dash ', 'folder' => ' A. ARCHITECTURAL '}, {'name' => 'B', 'color' => nil}])
ok('sanitize: gọn khoảng trắng, màu về #rrggbb thường, tag không có màu giữ nil', clean == [{'name' => 'A. WALL', 'color' => '#ff0000', 'style' => 'Dash', 'folder' => 'A. ARCHITECTURAL'}, {'name' => 'B', 'color' => nil, 'style' => '', 'folder' => ''}])
bad = {'không phải mảng' => 'x', 'phần tử sai' => [1], 'tên rỗng' => [{'name' => ''}], 'Untagged' => [{'name' => 'untagged'}], 'tên dài' => [{'name' => 'x' * 61}], 'trùng' => [{'name' => 'a'}, {'name' => 'A'}], 'màu sai' => [{'name' => 'a', 'color' => 'đỏ'}], 'kiểu nét dài' => [{'name' => 'a', 'style' => 'x' * 61}], 'thư mục dài' => [{'name' => 'a', 'folder' => 'x' * 61}], 'ký tự điều khiển' => [{'name' => "a\u0001b"}]}
ok('sanitize: dữ liệu sai bị từ chối (mọi trường hợp)', bad.all? { |_label, value| error_of { E.sanitize(value) } })
roundtrip = VGD::BIM::Xlsx.build(columns: [{label: 'Name', unit: '', type: 'text', digits: 0}, {label: 'Color', unit: '', type: 'text', digits: 0}], rows: [{kind: 'row', pid: nil, cells: ['Tag X', '#123456'], image: nil, images: {}}], title: 'T', meta: 'M', labels: {}, separator: ',', images: {})
back = E.parse(R.read(roundtrip))
ok('đọc lại được file do plugin tự xuất (chữ nội tuyến, có dòng tiêu đề chung và ghi chú phía trên)', back[:tags] == [{'name' => 'Tag X', 'color' => '#123456', 'style' => '', 'folder' => ''}])

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
