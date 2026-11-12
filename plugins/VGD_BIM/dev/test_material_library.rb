# Test thư viện vật liệu (core/material_library.rb): kiểm tra dữ liệu sai, id ổn định, lưu / đọc trên máy, nối với vật liệu SketchUp theo tên,
# khối lượng có hao hụt và thành tiền theo vật liệu (chỉ khi cùng đơn vị). Chạy: ruby dev/test_material_library.rb
require 'json'
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_matlib')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
module VGD; module BIM; def self.log(_m); end; end; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
%w[storage measure schema quantity material_library].each { |f| require File.join(ROOT, "core/#{f}") }
ML = VGD::BIM::MaterialLibrary

mfc = {'code' => 'MFC01', 'name' => 'MFC Oak', 'manufacturer' => 'An Cường', 'product' => 'MFC 18', 'thickness' => 18, 'unit' => 'm2', 'price' => 285_000, 'waste' => 5, 'spec' => '18mm, E1', 'sketchup_material' => 'Gỗ sồi'}

# ---- Dữ liệu sai ----
ok('không phải mảng / mục sai kiểu: từ chối', error_of { ML.sanitize!('x') }.to_s.include?('không hợp lệ') && error_of { ML.sanitize!([1]) }.to_s.include?('không hợp lệ'))
ok('quá nhiều vật liệu: từ chối', error_of { ML.sanitize!(Array.new(ML::MAX_ITEMS + 1) { |i| mfc.merge('code' => "M#{i}", 'name' => "V#{i}", 'sketchup_material' => "S#{i}") }) }.to_s.include?('tối đa'))
ok('tên vật liệu rỗng / quá dài / điều khiển / sai kiểu: từ chối', ['', ' ', 'a' * (ML::MAX_NAME + 1), "a\u0001", 5].all? { |n| error_of { ML.sanitize!([mfc.merge('name' => n)]) }.to_s.include?('tên vật liệu') })
ok('mã vật liệu quá dài / điều khiển: từ chối; mã trùng (không phân biệt hoa thường): từ chối; mã rỗng được', error_of { ML.sanitize!([mfc.merge('code' => 'a' * 31)]) }.to_s.include?('mã vật liệu') && error_of { ML.sanitize!([mfc, mfc.merge('name' => 'B', 'code' => 'mfc01', 'sketchup_material' => 'X')]) }.to_s.include?('trùng') && ML.sanitize!([mfc.merge('code' => ''), mfc.merge('name' => 'B', 'code' => '', 'sketchup_material' => 'X')]).size == 2)
ok('liên kết vật liệu SketchUp trùng nhau (khác hoa thường / dấu): từ chối', error_of { ML.sanitize!([mfc, mfc.merge('name' => 'B', 'code' => 'B', 'sketchup_material' => 'go soi')]) }.to_s.include?('trùng'))
ok('đơn vị lạ: từ chối', error_of { ML.sanitize!([mfc.merge('unit' => 'kg2')]) }.to_s.include?('đơn vị'))
ok('đơn giá sai (âm, chữ, vô cực, quá lớn): từ chối; rỗng được', [-1, '5', Float::INFINITY, 1e13].all? { |v| error_of { ML.sanitize!([mfc.merge('price' => v)]) }.to_s.include?('đơn giá') } && ML.sanitize!([mfc.merge('price' => nil)]).first['price'].nil?)
ok('độ dày sai (âm, quá lớn, chữ): từ chối; rỗng được', [-1, 2000, 'x'].all? { |v| error_of { ML.sanitize!([mfc.merge('thickness' => v)]) }.to_s.include?('độ dày') } && ML.sanitize!([mfc.merge('thickness' => nil)]).first['thickness'].nil?)
ok('hao hụt sai (âm, trên 100, chữ): từ chối; thiếu thì 0', [-1, 101, 'x'].all? { |v| error_of { ML.sanitize!([mfc.merge('waste' => v)]) }.to_s.include?('hao hụt') } && ML.sanitize!([mfc.reject { |k, _| k == 'waste' }]).first['waste'] == 0.0)
ok('hãng / sản phẩm / quy cách quá dài hoặc có ký tự điều khiển: từ chối', error_of { ML.sanitize!([mfc.merge('manufacturer' => 'a' * 81)]) }.to_s.include?('hãng') && error_of { ML.sanitize!([mfc.merge('spec' => "a\u0001")]) }.to_s.include?('quy cách') && error_of { ML.sanitize!([mfc.merge('product' => 'a' * 81)]) }.to_s.include?('sản phẩm'))
ok('id lạ: từ chối', error_of { ML.sanitize!([mfc.merge('id' => 'zz')]) }.to_s.include?('không hợp lệ'))

# ---- Chuẩn hóa / lưu ----
clean = ML.sanitize!([mfc, mfc.merge('name' => 'Sơn', 'code' => 'PN01', 'unit' => 'm2', 'price' => 45_000.456, 'sketchup_material' => 'Sơn trắng', 'thickness' => nil)])
ok('chuẩn hóa: có id mt_xxxxxxxx khác nhau, giữ thứ tự, giá làm tròn 2 chữ số lẻ', clean.map { |i| i['id'] }.uniq.size == 2 && clean.all? { |i| i['id'].match?(/\Amt_[0-9a-f]{8}\z/) } && clean[1]['price'] == 45_000.46 && clean[0]['name'] == 'MFC Oak')
ok('chuẩn hóa lại giữ id; khóa thừa bị bỏ', ML.sanitize!(clean).map { |i| i['id'] } == clean.map { |i| i['id'] } && !ML.sanitize!([mfc.merge('x' => 1)]).first.key?('x'))
ok('chưa có thư viện: rỗng', ML.read == [])
ML.write(clean)
ok('ghi / đọc trên máy', ML.read.map { |i| i['code'] } == %w[MFC01 PN01])
File.write(File.join(ENV['VGD_BIM_DATA_DIR'], 'material_library.json'), 'hỏng')
ok('file hỏng: coi như chưa có thư viện', ML.read == [])
File.write(File.join(ENV['VGD_BIM_DATA_DIR'], 'material_library.json'), '{"items":[{"name":"","unit":"m2"},{"name":"A","unit":"m2","sketchup_material":"a"}]}')
ok('file sửa tay có mục sai: bỏ mục sai, giữ mục đúng', ML.read.map { |i| i['name'] } == ['A'])
ML.write(clean)

# ---- Nối với vật liệu SketchUp ----
ok('tìm theo tên vật liệu SketchUp (không phân biệt hoa thường và dấu)', ML.find(clean, 'gỗ sồi')['code'] == 'MFC01' && ML.find(clean, 'GO SOI')['code'] == 'MFC01' && ML.find(clean, 'Sơn trắng')['code'] == 'PN01' && ML.find(clean, 'Không có').nil? && ML.find(clean, '').nil? && ML.find(clean, nil).nil?)

# ---- Khối lượng có hao hụt và thành tiền ----
entry = clean[0]
r = ML.cost(entry, 'area', 10.0)
ok('diện tích 10 m2 + hao hụt 5% = 10,5 m2; thành tiền = 10,5 x 285.000', r[:qty] == 10.5 && r[:cost] == 2_992_500.0 && r[:note].nil?)
r = ML.cost(entry, 'count', 3)
ok('cách tính theo cái, vật liệu tính m2: không có thành tiền, ghi chú đơn vị khác nhau; khối lượng vẫn có hao hụt', r[:qty] == 3.15 && r[:cost].nil? && r[:note].include?('khác'))
ok('không có khối lượng (nil) hoặc cách tính none: rỗng', ML.cost(entry, 'area', nil) == {qty: nil, cost: nil, note: nil} && ML.cost(entry, 'none', 5.0) == {qty: nil, cost: nil, note: nil})
ok('vật liệu chưa có đơn giá: có khối lượng hao hụt, không có thành tiền, ghi chú chưa có đơn giá', (r = ML.cost(clean[0].merge('price' => nil), 'area', 2.0); r[:qty] == 2.1 && r[:cost].nil? && r[:note].include?('đơn giá')))
ok('không có mục thư viện: kết quả rỗng', ML.cost(nil, 'area', 5.0) == {qty: nil, cost: nil, note: nil})

puts($fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
