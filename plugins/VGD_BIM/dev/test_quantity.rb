# Test suy ra hạng mục / cách tính / khối lượng tính từ tag và nhóm tag (core/quantity.rb): ưu tiên dữ liệu trong món, rồi ghi đè theo tag,
# từ khóa của tên tag, nhóm tag, mặc định; khối lượng theo cách tính; lưu ghi đè theo tag; giá trị ghi vào món (chỉ mục còn trống). Chạy: ruby dev/test_quantity.rb
require 'json'
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_quantity')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
module VGD; module BIM; def self.log(_message); end; end; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
%w[storage measure schema quantity].each { |f| require File.join(ROOT, "core/#{f}") }
Q = VGD::BIM::Quantity

# ---- Cách tính mặc định ----
ok('nhóm A. ARCHITECTURAL: theo diện tích, hạng mục kiến trúc', Q.resolve('A. WALL', 'A. ARCHITECTURAL', {}, {}).values_at(:category, :method, :source) == ['architecture', 'area', 'keyword'])
ok('từ khóa trong tên tag thắng nhóm: cửa, cửa sổ tính theo cái; lan can theo mét dài; cột dầm theo thể tích', Q.resolve('A. DOOR', 'A. ARCHITECTURAL', {}, {})[:method] == 'count' && Q.resolve('A. WINDOW', 'A. ARCHITECTURAL', {}, {})[:method] == 'count' && Q.resolve('A. RAILING', 'A. ARCHITECTURAL', {}, {})[:method] == 'length' && Q.resolve('S. COLUMN', 'S. STRUCTURAL', {}, {})[:method] == 'volume' && Q.resolve('X. beam', '', {}, {})[:method] == 'volume')
ok('từ khóa không phân biệt hoa thường và dấu, chỉ khớp nguyên từ (không khớp "doorway" hay "outdoor")', Q.resolve('A. Cửa Đi (DOOR)', 'A. ARCHITECTURAL', {}, {})[:method] == 'count' && Q.resolve('L. OUTDOOR', 'L. LANDSCAPE', {}, {})[:source] == 'group' && Q.resolve('A. DOORWAY', 'A. ARCHITECTURAL', {}, {})[:source] == 'group')
ok('theo nhóm khi tên tag không có từ khóa: nội thất theo cái, thiết bị điện theo cái, kết cấu theo thể tích, cảnh quan theo diện tích', ['I. INTERIOR', 'E. ELECTRICAL', 'Q. EQUIPMENT', 'P. PLUMBING'].all? { |g| Q.resolve('X', g, {}, {}).values_at(:method, :source) == ['count', 'group'] } && Q.resolve('X', 'S. STRUCTURAL', {}, {})[:method] == 'volume' && Q.resolve('X', 'L. LANDSCAPE', {}, {})[:method] == 'area')
ok('nhóm thông tin / cơ bản / tham chiếu: không tính', ['! INFORMATION', '# BASIC', '@ STATUS', '@ REFERENCES', '1. CONTEXT', '3. BUILDING STORIES'].all? { |g| Q.resolve('X', g, {}, {})[:method] == 'none' })
ok('chưa có tag: theo cái, nguồn mặc định, hạng mục khác', Q.resolve('', 'Chưa phân loại', {}, {}).values_at(:category, :method, :source) == ['other', 'count', 'default'])
# ---- Ưu tiên ----
ok('ghi đè theo tag thắng từ khóa và nhóm', Q.resolve('A. WALL', 'A. ARCHITECTURAL', {}, {Q.key('A. WALL') => 'length'}).values_at(:method, :source) == ['length', 'tag'])
ok('ghi đè theo tag không phân biệt hoa thường và dấu', Q.resolve('a. wall', 'A. ARCHITECTURAL', {}, {Q.key('A. WALL') => 'volume'})[:method] == 'volume')
ok('dữ liệu trong món thắng ghi đè theo tag: cách tính, hạng mục', Q.resolve('A. WALL', 'A. ARCHITECTURAL', {quantity_method: 'count', category: 'finish', include_boq: true}, {Q.key('A. WALL') => 'length'}).values_at(:category, :method, :source) == ['finish', 'count', 'item'])
ok('món có dữ liệu nhưng chưa nhập cách tính: vẫn suy ra từ tag, hạng mục lấy từ món nếu có', Q.resolve('A. DOOR', 'A. ARCHITECTURAL', {quantity_method: '', category: 'furniture', include_boq: true}, {}).values_at(:category, :method, :source) == ['furniture', 'count', 'keyword'])
ok('cách tính cũ: assembly tính theo cái, manual không tự tính, đơn vị lạ bỏ qua', Q.resolve('X', 'I. INTERIOR', {quantity_method: 'assembly'}, {})[:method] == 'count' && Q.resolve('X', 'I. INTERIOR', {quantity_method: 'manual'}, {})[:method] == 'none' && Q.resolve('X', 'S. STRUCTURAL', {quantity_method: 'zzz'}, {})[:method] == 'volume')
ok('món đã đặt không đưa vào BOQ: không tính, nguồn món', Q.resolve('A. DOOR', 'A. ARCHITECTURAL', {include_boq: false}, {}).values_at(:method, :source) == ['none', 'item'])
ok('ghi đè theo tag bị hỏng (giá trị lạ) bị bỏ qua', Q.resolve('A. WALL', 'A. ARCHITECTURAL', {}, {Q.key('A. WALL') => 'zzz'})[:source] == 'keyword')
# ---- Khối lượng tính ----
row = {lenX: 1200.0, lenY: 600.0, lenZ: 2400.0, areaXZ: 2.88, volume: 1.234, price: 1_500_000.0}
ok('theo cái: 1; theo diện tích: Rộng x Cao (m²); theo mét dài: Rộng (m); theo thể tích: khối (m³)', Q.amount('count', row) == [1.0, nil] && Q.amount('area', row) == [2.88, nil] && Q.amount('length', row) == [1.2, nil] && Q.amount('volume', row) == [1.234, nil])
ok('không tính: không có số lượng', Q.amount('none', row) == [nil, nil])
ok('thể tích: khối không kín (không có thể tích khối) thì ước tính theo khung bao và ghi chú', Q.amount('volume', row.merge(volume: nil)) == [1.728, 'ước tính theo khối bao'])
ok('thiếu số đo: không có số lượng', Q.amount('area', {}) == [nil, nil] && Q.amount('length', {lenX: nil}) == [nil, nil])
fields = Q.row_fields(row, 'A. DOOR', 'A. ARCHITECTURAL', {}, {})
ok('dòng: gồm hạng mục, cách tính, nguồn, khối lượng; thành tiền = đơn giá x khối lượng', fields.values_at(:calc_category, :calc_method, :calc_source, :calc_qty, :calc_total) == ['architecture', 'count', 'keyword', 1.0, 1_500_000.0])
fields = Q.row_fields(row, 'A. WALL', 'A. ARCHITECTURAL', {}, {})
ok('dòng theo diện tích: thành tiền theo m² (đơn giá x 2,88)', fields[:calc_method] == 'area' && fields[:calc_qty] == 2.88 && (fields[:calc_total] - 4_320_000.0).abs < 1e-6)
ok('dòng không có đơn giá hoặc không tính: thành tiền trống', Q.row_fields(row.merge(price: nil), 'A. WALL', 'A. ARCHITECTURAL', {}, {})[:calc_total].nil? && Q.row_fields(row, 'A. WALL', 'A. ARCHITECTURAL', {include_boq: false}, {}).values_at(:calc_qty, :calc_total) == [nil, nil])
ok('dòng ghi chú ước tính thể tích', Q.row_fields(row.merge(volume: nil), 'S. COLUMN', 'S. STRUCTURAL', {}, {})[:calc_note] == 'ước tính theo khối bao')
# ---- Lưu ghi đè theo tag ----
ok('chưa có ghi đè: rỗng', Q.overrides == {})
Q.set_override('A. WALL', 'length')
Q.set_override('I. Tủ Bếp', 'count')
ok('đặt ghi đè theo tag: lưu, đọc lại đúng (khóa chuẩn hóa)', Q.overrides == {Q.key('A. WALL') => 'length', Q.key('I. Tủ Bếp') => 'count'})
Q.set_override('a. wall', '')
ok('giá trị rỗng: bỏ ghi đè của tag đó (không phân biệt hoa thường)', Q.overrides == {Q.key('I. Tủ Bếp') => 'count'})
ok('cách tính lạ bị từ chối, tag rỗng bị từ chối, không đổi dữ liệu', error_of { Q.set_override('A. WALL', 'zzz') }.to_s.include?('Cách tính') && error_of { Q.set_override('', 'area') }.to_s.include?('tag') && Q.overrides.size == 1)
File.write(File.join(ENV['VGD_BIM_DATA_DIR'], 'tag_quantity.json'), '{"tags":{"a. wall":"zzz","ok":"area","bad":5}}')
ok('file hỏng một phần: chỉ giữ mục hợp lệ', Q.overrides == {'ok' => 'area'})
File.write(File.join(ENV['VGD_BIM_DATA_DIR'], 'tag_quantity.json'), 'không phải json {')
ok('file không phải JSON: coi như chưa có ghi đè, không lỗi', Q.overrides == {})
# ---- Giá trị ghi vào món (chỉ mục còn trống) ----
d = {category: 'furniture', method: 'count', source: 'group'}
ok('món chưa có dữ liệu: ghi hạng mục, cách tính, đơn vị', Q.commit_values({}, false, d) == {category: 'furniture', quantity_method: 'count', unit: 'pcs'})
ok('món đã có hạng mục: không ghi đè, vẫn bổ sung mục trống', Q.commit_values({category: 'finish', quantity_method: '', unit: ''}, true, d) == {quantity_method: 'count', unit: 'pcs'})
ok('món đã có đủ: không có gì để ghi', Q.commit_values({category: 'finish', quantity_method: 'area', unit: 'm2'}, true, d) == {})
ok('theo diện tích / mét dài / thể tích: đơn vị m2 / m / m3', Q.commit_values({}, false, {category: 'architecture', method: 'area'})[:unit] == 'm2' && Q.commit_values({}, false, {category: 'architecture', method: 'length'})[:unit] == 'm' && Q.commit_values({}, false, {category: 'architecture', method: 'volume'})[:unit] == 'm3')
ok('không tính: món chưa có dữ liệu thì ghi đưa vào BOQ = Không, món đã có dữ liệu thì không đổi', Q.commit_values({}, false, {category: 'other', method: 'none'}) == {category: 'other', include_boq: false} && Q.commit_values({category: 'other'}, true, {category: 'other', method: 'none'}) == {})

puts($fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
