# Test công thức khối lượng theo tag (core/formula.rb và phần nối vào core/quantity.rb): đọc công thức, tính theo số đo của dòng, báo lỗi rõ,
# lưu ghi đè theo tag kèm đơn vị, đơn vị của dòng và thành tiền theo vật liệu. Chạy: ruby dev/test_formula.rb
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] ||= Dir.mktmpdir('vgd_bim_formula')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
%w[core/locale core/schema core/storage core/measure core/formula core/structure_source core/quantity core/material_library].each { |f| require File.join(ROOT, f) }
F = VGD::BIM::Formula
Q = VGD::BIM::Quantity

values = {w: 1.2, d: 0.6, h: 2.0, area: 2.4, volume: 1.44}
calc = ->(text) { F.evaluate(F.parse!(text), values) }

# 1. Đọc và tính
ok 'chu vi (Rộng + Sâu) x 2 = 3,6', calc.call('(Rộng + Sâu) x 2') == [3.6, nil]
ok 'không dấu, chữ hoa thường: (rong + SAU) * 2', calc.call('(rong + SAU) * 2') == [3.6, nil]
ok 'dấu × và x dính số: Rộng x2', calc.call('Rộng x2') == [2.4, nil] && calc.call('Rộng × 2') == [2.4, nil]
ok 'tên hai chữ: Diện tích, Thể tích', calc.call('Diện tích + Thể tích') == [3.84, nil]
ok 'dấu phẩy thập phân: Diện tích * 1,05', calc.call('Diện tích * 1,05') == [2.52, nil]
ok 'nhân chia trước cộng trừ', calc.call('1 + 2 * 3') == [7.0, nil] && calc.call('(1 + 2) * 3') == [9.0, nil]
ok 'chia từ trái sang phải: 8 / 2 / 2 = 2', calc.call('8 / 2 / 2') == [2.0, nil]
ok 'số âm đầu công thức: -Cao + 3', calc.call('-Cao + 3') == [1.0, nil]
ok 'tên tiếng Anh: (width + depth) * height', calc.call('(width + depth) * height') == [3.6, nil]
ok 'chia cho 0: không ra số, có ghi chú', calc.call('Rộng / 0') == [nil, 'công thức chia cho 0'] && calc.call('Rộng / (Cao - 2)') == [nil, 'công thức chia cho 0']
ok 'thiếu số đo: không ra số, nói rõ thiếu gì', F.evaluate(F.parse!('Thể tích * 2'), values.merge(volume: nil)) == [nil, 'thiếu số đo Thể tích']
ok 'biến có trong công thức', F.variables(F.parse!('(Rộng + Sâu) x Cao')).sort == %i[d h w]

# 2. Công thức sai bị từ chối, lời báo dễ hiểu
bad = ->(text, part) { error_of { F.parse!(text) }.to_s.include?(part) }
ok 'trống', bad.call('  ', 'Hãy nhập công thức') && bad.call(nil, 'Hãy nhập công thức')
ok 'quá dài', bad.call('1+' * 101 + '1', 'tối đa 200')
ok 'số đo lạ', bad.call('Rộng + Dài', 'Không biết số đo "dai"')
ok 'ký tự lạ (lũy thừa, chuỗi, mã Ruby)', bad.call('Rộng ^ 2', 'không dùng được') && bad.call('`ls`', 'không dùng được') && bad.call('system("x")', 'Không biết số đo') && bad.call('"a"', 'không dùng được')
ok 'thiếu ngoặc đóng', bad.call('2 * (Rộng + Cao', 'thiếu dấu ngoặc đóng')
ok 'ngoặc đóng thừa', bad.call('Rộng + Cao)', 'sai ở')
ok 'phép tính thiếu số', bad.call('Rộng +', 'chưa xong') && bad.call('* Rộng', 'sai ở')
ok 'hai số đo liền nhau không có phép tính', bad.call('Rộng Cao', 'sai ở')
ok 'ngoặc lồng quá sâu', bad.call('(' * 25 + '1' + ')' * 25, 'quá sâu')
ok 'số sai', bad.call('1.2.3', 'sai ở')

# 2b. Hàm Excel: tính như Excel, báo lỗi số đối số, dịch sang công thức Excel
ok 'dấu = đầu như Excel được bỏ qua', calc.call('=Rộng*2') == [2.4, nil]
ok 'ROUND(2,675; 2) làm tròn nửa lên như Excel', calc.call('ROUND(2,675; 2)') == [2.68, nil] && calc.call('ROUND(-2,5; 0)') == [-3.0, nil]
ok 'ROUNDUP / ROUNDDOWN không bị sai số dấu phẩy động', calc.call('ROUNDUP(1.1 * 10; 0)') == [11.0, nil] && calc.call('ROUNDUP(Rộng / 0,5; 0)') == [3.0, nil] && calc.call('ROUNDDOWN(-1,99; 0)') == [-1.0, nil]
ok 'ROUND số chữ số âm (làm tròn hàng chục)', calc.call('ROUND(1234; -2)') == [1200.0, nil]
ok 'CEILING theo bội số', calc.call('CEILING(Rộng; 0,5)') == [1.5, nil] && calc.call('CEILING(-2,5; 1)') == [-2.0, nil] && calc.call('CEILING(Rộng; 0)') == [0.0, nil]
ok 'CEILING số dương với bội số âm: không xác định (như #NUM! của Excel)', calc.call('CEILING(Rộng; -1)')[0].nil?
ok 'MIN / MAX nhiều đối số', calc.call('MAX(Rộng; Sâu; Cao)') == [2.0, nil] && calc.call('MIN(Rộng, Sâu)') == [0.6, nil]
ok 'IF với so sánh, chỉ tính nhánh được chọn', calc.call('IF(Rộng > 1; Rộng * 2; Rộng / 0)') == [2.4, nil] && calc.call('IF(Rộng <= 1; 1; 0)') == [0.0, nil] && calc.call('IF(Cao = 2; 5)') == [5.0, nil] && calc.call('IF(Cao <> 2; 5)') == [0.0, nil]
ok 'so sánh đứng riêng ra 1 / 0', calc.call('(Rộng >= 1,2) + 1') == [2.0, nil]
ok 'ABS, SQRT, PI', calc.call('ABS(Sâu - Rộng)') == [0.6, nil] && calc.call('SQRT(Diện tích * 6)') == [3.7947, nil] && calc.call('PI() * 2') == [6.2832, nil]
ok 'SQRT số âm: không xác định', calc.call('SQRT(-1)') == [nil, 'SQRT: căn bậc hai của số âm']
ok 'tên hàm không phân biệt hoa thường', calc.call('roundup(Rộng; 0)') == [2.0, nil]
ok 'sai số đối số: nói rõ cần bao nhiêu và dùng ;', bad.call('ROUND(Rộng)', 'ROUND cần 2 đối số') && bad.call('ROUND(1,5)', 'ROUND cần 2 đối số') && bad.call('PI(1)', 'PI cần 0 đối số')
ok 'thiếu ngoặc sau tên hàm', bad.call('ROUND Rộng', 'cần dấu ngoặc') && bad.call('MAX(Rộng; Cao', 'thiếu dấu ngoặc đóng')
ok 'dấu ; ngoài hàm', bad.call('Rộng; Cao', 'ngăn các đối số')
ok 'hàm lạ vẫn bị từ chối', bad.call('SUM(Rộng)', 'Không biết số đo "sum"') && bad.call('INDIRECT("A1")', 'Không biết số đo')
ok 'hai số đo liền nhau: báo đúng tên', bad.call('Rộng Cao', 'sai ở "Cao"')
refs = {w: 'C5*0.001', d: 'D5*0.001', h: 'E5*0.001', area: 'F5', volume: 'G5'}
xl = ->(text) { F.to_excel(F.parse!(text), refs) }
ok 'dịch sang Excel: số đo thành ô của dòng', xl.call('(Rộng + Sâu) x 2') == '(((C5*0.001)+(D5*0.001))*2)'
ok 'dịch sang Excel: hàm, dấu phẩy chuẩn, số thập phân dấu chấm', xl.call('ROUNDUP(Rộng / 0,6; 0)') == 'ROUNDUP(((C5*0.001)/0.6),0)'
ok 'dịch sang Excel: so sánh thành 1 / 0, IF giữ nguyên', xl.call('IF(Cao > 2; Diện tích; 0)') == 'IF((((E5*0.001)>2)*1),(F5),0)'
ok 'dịch sang Excel: số âm, PI, số rất nhỏ', xl.call('-Thể tích * PI() + 0,00001') == '(((-(G5))*PI())+1E-05)'

# 3. Ghi đè theo tag bằng công thức (lưu trên máy) và dòng của bảng
Q.set_override('A. SKIRTING', 'formula', formula: '(Rộng + Sâu) x 2', unit: 'm')
own = Q.overrides[Q.key('A. SKIRTING')]
ok 'lưu công thức kèm đơn vị theo tag', own == {'method' => 'formula', 'formula' => '(Rộng + Sâu) x 2', 'unit' => 'm'}
row = {lenX: 1200.0, lenY: 600.0, lenZ: 2000.0, areaXZ: 2.4, volume: 1.44, price: 50_000}
fields = Q.row_fields(row, 'A. SKIRTING', 'A. ARCHITECTURAL', {}, Q.overrides)
ok 'dòng theo công thức: khối lượng 3,6 m, đơn vị m, nguồn tag, ghi công thức', fields[:calc_method] == 'formula' && fields[:calc_qty] == 3.6 && fields[:calc_unit] == 'm' && fields[:calc_source] == 'tag' && fields[:calc_formula] == '(Rộng + Sâu) x 2'
ok 'thành tiền theo khối lượng công thức', fields[:calc_total] == 180_000.0
plain = Q.row_fields(row, 'A. WALL', 'A. ARCHITECTURAL', {}, Q.overrides)
ok 'cách tính có sẵn: đơn vị theo cách tính, không có công thức', plain[:calc_unit] == 'm2' && plain[:calc_formula].nil?
missing = Q.row_fields(row.merge(lenY: nil), 'A. SKIRTING', 'A. ARCHITECTURAL', {}, Q.overrides)
ok 'thiếu số đo: không ra khối lượng, ghi chú lý do', missing[:calc_qty].nil? && missing[:calc_note] == 'thiếu số đo Sâu'
ok 'dữ liệu trong món vẫn thắng công thức của tag', Q.row_fields(row, 'A. SKIRTING', 'A. ARCHITECTURAL', {quantity_method: 'count'}, Q.overrides)[:calc_method] == 'count'
ok 'công thức sai bị từ chối, không lưu', error_of { Q.set_override('A. X', 'formula', formula: 'Rộng ^ 2', unit: 'm') }.to_s.include?('không dùng được') && !Q.overrides.key?(Q.key('A. X'))
ok 'đơn vị sai bị từ chối', error_of { Q.set_override('A. X', 'formula', formula: 'Rộng', unit: 'tấn') }.to_s.include?('Đơn vị') && error_of { Q.set_override('A. X', 'formula', formula: 'Rộng', unit: 'none') }.to_s.include?('Đơn vị')
Q.set_override('A. SKIRTING', 'length')
ok 'đổi lại cách tính thường thay công thức', Q.overrides[Q.key('A. SKIRTING')] == 'length'
Q.set_override('A. SKIRTING', '')
ok 'bỏ ghi đè', !Q.overrides.key?(Q.key('A. SKIRTING'))
VGD::BIM::Storage.write('tag_quantity', {'tags' => {'a' => {'method' => 'formula', 'formula' => 'Rộng ^', 'unit' => 'm'}, 'b' => {'method' => 'formula', 'formula' => 'Cao', 'unit' => 'xx'}, 'c' => 'area'}})
ok 'file hỏng: bỏ công thức sai, giữ mục đúng', Q.overrides == {'c' => 'area'}

# 4. Ghi cách tính vào món và thành tiền theo vật liệu
ok 'ghi vào món: công thức không ghi cách tính (schema không có), chỉ đơn vị', Q.commit_values({}, false, {category: 'finish', method: 'formula', unit: 'm'}) == {category: 'finish', unit: 'm'}
entry = {'unit' => 'm', 'price' => 10_000, 'waste' => 0}
ok 'vật liệu cùng đơn vị với công thức: ra thành tiền', VGD::BIM::MaterialLibrary.cost(entry, 'formula', 3.6, unit: 'm')[:cost] == 36_000.0
ok 'vật liệu khác đơn vị: không ra tiền, có ghi chú', VGD::BIM::MaterialLibrary.cost(entry.merge('unit' => 'm2'), 'formula', 3.6, unit: 'm')[:note].to_s.include?('khác đơn vị')
ok 'cách tính thường vẫn như cũ', VGD::BIM::MaterialLibrary.cost(entry.merge('unit' => 'm2'), 'area', 2.0)[:cost] == 20_000.0

puts($fails.zero? ? 'ALL PASS' : "#{$fails} FAIL")
exit($fails.zero? ? 0 : 1)
