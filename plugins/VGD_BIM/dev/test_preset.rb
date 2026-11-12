# Test preset của bảng khối lượng: thiết lập theo preset (đơn vị, số lẻ, ảnh), tiêu đề cột tự đặt, preset có sẵn,
# nhập / xuất JSON (kể cả định dạng của plugin tham khảo), chuyển preset cũ. Chạy: ruby dev/test_preset.rb
require 'json'
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_preset')
module Sketchup; class Group; end; class ComponentInstance; end; class Face; end; end
module VGD; module BIM; def self.log(m); end; module Data; end; module Scanner; end; module Geometry; end; end; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
%w[core/locale core/schema core/storage core/measure core/tags core/preset core/photo_settings core/quantity core/table].each { |f| require File.join(ROOT, f) }
P = VGD::BIM::Preset
T = VGD::BIM::Table
def check(label, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{label}"; end
def raises?(text = nil); yield; false; rescue ArgumentError => e; text ? e.message.downcase.include?(text) : true; end
keys = T::COLUMN_KEYS
G = VGD::BIM::Tags::GROUPS

# ---- Thiết lập theo preset ----
d = P::DEFAULT_SETTINGS
check 'mặc định: mm 0 số lẻ, m² 2, m³ 3, dấu phẩy, VND, ảnh 512x512, góc iso, kiểu màu, nền trong suốt', d.values_at('length_unit', 'length_digits', 'area_unit', 'area_digits', 'volume_unit', 'volume_digits', 'decimal_separator', 'currency', 'image_width', 'image_height', 'image_view', 'image_style', 'image_background') == ['mm', 0, 'm2', 2, 'm3', 3, ',', 'VND', 512, 512, 'isometric', 'color', 'transparent']
check 'thiết lập hợp lệ được giữ nguyên', P.settings!('length_unit' => 'ft', 'length_digits' => 3, 'area_unit' => 'ft2', 'volume_unit' => 'cm3', 'decimal_separator' => '.', 'currency' => 'USD', 'image_width' => 1024, 'image_height' => 768, 'image_view' => 'front', 'image_style' => 'current', 'image_background' => 'white').values_at('length_unit', 'length_digits', 'area_unit', 'volume_unit', 'decimal_separator', 'currency', 'image_width', 'image_height', 'image_view', 'image_style', 'image_background') == ['ft', 3, 'ft2', 'cm3', '.', 'USD', 1024, 768, 'front', 'current', 'white']
check 'thiếu mục thì lấy mặc định', P.settings!('length_unit' => 'cm')['area_unit'] == 'm2' && P.settings!({}) == d
%w[length_unit area_unit volume_unit decimal_separator currency image_view image_style image_background].each do |k|
  check "#{k} lạ bị từ chối", raises? { P.settings!(k => 'zzz') }
end
check 'số lẻ ngoài 0..4 bị từ chối', raises?('số lẻ') { P.settings!('length_digits' => 9) } && raises?('số lẻ') { P.settings!('area_digits' => -1) } && raises?('số lẻ') { P.settings!('volume_digits' => 'nhiều') }
check 'lề ảnh mặc định 20%, nhận 0..100, giá trị ngoài khoảng hoặc không phải số bị từ chối', d['image_margin'] == 20 && P.settings!('image_margin' => 0)['image_margin'] == 0 && P.settings!('image_margin' => '35')['image_margin'] == 35 && raises?('lề') { P.settings!('image_margin' => 101) } && raises?('lề') { P.settings!('image_margin' => -1) } && raises?('lề') { P.settings!('image_margin' => 'abc') }
check 'lề ảnh: bản dễ tính (file cũ không có mục này, giá trị sai) về mặc định 20', P.settings('length_unit' => 'cm')['image_margin'] == 20 && P.settings('image_margin' => 500)['image_margin'] == 20
check 'vùng nhìn ảnh vị trí mặc định gấp 4, nhận 1..20, ngoài khoảng hoặc không phải số bị từ chối', d['image_location_scale'] == 4 && P.settings!('image_location_scale' => 2)['image_location_scale'] == 2 && P.settings!('image_location_scale' => '20')['image_location_scale'] == 20 && P.settings!('image_location_scale' => 1)['image_location_scale'] == 1 && raises?('vùng nhìn') { P.settings!('image_location_scale' => 0) } && raises?('vùng nhìn') { P.settings!('image_location_scale' => 21) } && raises?('vùng nhìn') { P.settings!('image_location_scale' => 'x') } && P.settings('image_location_scale' => 99)['image_location_scale'] == 4
%w[loc_view loc_style loc_background].each { |k| check "#{k} lạ bị từ chối", raises? { P.settings!(k => 'zzz') } }
check 'ảnh vị trí: mặc định giống ảnh chính (512x512, kiểu màu, nền trong suốt, lề 20) và góc nhìn Iso, không lệch, không nâng góc', d.values_at('loc_width', 'loc_height', 'loc_view', 'loc_style', 'loc_background', 'loc_margin', 'loc_yaw', 'loc_pitch') == [512, 512, 'isometric', 'color', 'transparent', 20, 0, 0] && d.values_at('image_yaw', 'image_pitch') == [0, 0]
check 'ảnh vị trí: thiết lập riêng hợp lệ được giữ nguyên', (r = P.settings!('loc_width' => 1024, 'loc_height' => 768, 'loc_view' => 'front', 'loc_style' => 'current', 'loc_background' => 'white', 'loc_margin' => 35, 'loc_yaw' => -20, 'loc_pitch' => 15); r.values_at('loc_width', 'loc_height', 'loc_view', 'loc_style', 'loc_background', 'loc_margin', 'loc_yaw', 'loc_pitch') == [1024, 768, 'front', 'current', 'white', 35, -20, 15])
check 'ảnh vị trí: cỡ ngoài 128..4096 và lề ngoài 0..100 bị từ chối', raises?('cỡ ảnh') { P.settings!('loc_width' => 10) } && raises?('cỡ ảnh') { P.settings!('loc_height' => 5000) } && raises?('lề') { P.settings!('loc_margin' => 101) } && raises?('lề') { P.settings!('loc_margin' => -1) }
check 'góc lệch trái / phải: nhận -90..90, ngoài khoảng hoặc không phải số bị từ chối (cả ảnh chính và ảnh vị trí)', %w[image_yaw loc_yaw].all? { |k| P.settings!(k => -90)[k] == -90 && P.settings!(k => '90')[k] == 90 && P.settings!(k => 0)[k] == 0 && raises?('góc lệch') { P.settings!(k => 91) } && raises?('góc lệch') { P.settings!(k => -91) } && raises?('góc lệch') { P.settings!(k => 'x') } }
check 'góc cao: nhận -30..80, ngoài khoảng hoặc không phải số bị từ chối (cả ảnh chính và ảnh vị trí)', %w[image_pitch loc_pitch].all? { |k| P.settings!(k => -30)[k] == -30 && P.settings!(k => 80)[k] == 80 && raises?('góc cao') { P.settings!(k => 81) } && raises?('góc cao') { P.settings!(k => -31) } && raises?('góc cao') { P.settings!(k => 1.5) } }
check 'preset cũ chưa có thiết lập ảnh vị trí: lấy theo ảnh chính để ảnh vị trí không đổi kích thước (bản chặt và dễ tính)', [P.settings!('image_width' => 1024, 'image_height' => 768, 'image_style' => 'current', 'image_background' => 'white', 'image_margin' => 40), P.settings('image_width' => 1024, 'image_height' => 768, 'image_style' => 'current', 'image_background' => 'white', 'image_margin' => 40)].all? { |r| r.values_at('loc_width', 'loc_height', 'loc_style', 'loc_background', 'loc_margin', 'loc_view') == [1024, 768, 'current', 'white', 40, 'isometric'] }
check 'đã có thiết lập ảnh vị trí thì không bị ghi đè bởi ảnh chính', P.settings!('image_width' => 1024, 'loc_width' => 640)['loc_width'] == 640
check 'bản dễ tính: góc ảnh vị trí sai về 0', P.settings('loc_yaw' => 500, 'loc_pitch' => 'abc').values_at('loc_yaw', 'loc_pitch') == [0, 0]
check 'cỡ ảnh ngoài 128..4096 bị từ chối', raises?('cỡ ảnh') { P.settings!('image_width' => 50) } && raises?('cỡ ảnh') { P.settings!('image_height' => 9999) }
check 'thiết lập không phải Hash bị từ chối', raises? { P.settings!('x') } && raises? { P.settings!(nil) }
check 'bản dễ tính: mục sai về mặc định, mục đúng giữ, mục lạ bỏ', P.settings('length_unit' => 'cm', 'area_unit' => 'zzz', 'hack' => 1, 'image_width' => 'abc') == d.merge('length_unit' => 'cm')
check 'bản dễ tính: không phải Hash thì dùng mặc định', P.settings(nil) == d && P.settings([1]) == d

# ---- Tiêu đề cột tự đặt ----
check 'tiêu đề: giữ cột hợp lệ, cắt khoảng trắng', P.headers!({'definition' => '  Mã phòng  ', 'instance' => 'Tên phòng'}, keys) == {'definition' => 'Mã phòng', 'instance' => 'Tên phòng'}
check 'tiêu đề: bỏ cột lạ và tiêu đề rỗng (rỗng nghĩa là dùng tên gốc)', P.headers!({'zzz' => 'x', 'material' => '   '}, keys) == {}
check 'tiêu đề quá 60 ký tự bị từ chối', raises?('tiêu đề') { P.headers!({'definition' => 'a' * 61}, keys) }
check 'tiêu đề không phải chữ bị từ chối', raises?('tiêu đề') { P.headers!({'definition' => 5}, keys) }
check 'tiêu đề: ký tự điều khiển bị bỏ', P.headers!({'definition' => "Mã\u0000\n phòng"}, keys) == {'definition' => 'Mã phòng'}
check 'bản dễ tính: tiêu đề sai bị bỏ, không báo lỗi', P.headers({'definition' => 5, 'instance' => 'Tên'}, keys) == {'instance' => 'Tên'} && P.headers(nil, keys) == {}

# ---- Preset có sẵn ----
names = T::BUILT_IN_PRESETS.map { |p| p['name'] }
check '11 preset có sẵn: 4 của BIM rồi 7 từ JSON, tên không trùng', names == ['Tất cả', 'Phần thô', 'Hoàn thiện', 'Đồ rời', 'Mặc định', 'Phòng & Khu vực', 'Cửa & Cửa sổ', 'Nội thất', 'Thiết bị & Phụ kiện', 'Chiếu sáng', 'Vật liệu'] && names.uniq.size == 11
check 'mọi preset có sẵn hợp lệ: cột, tiêu đề, thiết lập, nhóm', T::BUILT_IN_PRESETS.all? { |p| T.sanitize_preset(p) && (p['headers'] || {}).keys.all? { |k| keys.include?(k) } && P.settings!(p['settings']) == p['settings'] }
check 'mọi preset có sẵn có đủ thiết lập (không thiếu mục)', T::BUILT_IN_PRESETS.all? { |p| p['settings'].keys.sort == d.keys.sort }
check 'tiêu đề của preset có sẵn chỉ nói về cột đang hiện', T::BUILT_IN_PRESETS.all? { |p| (p['headers'] || {}).keys.all? { |k| p['columns'].include?(k) } }
rooms = T::BUILT_IN_PRESETS.find { |p| p['name'] == 'Phòng & Khu vực' }
check 'Phòng & Khu vực: có diện tích chiếu, mã phòng, tên phòng, m và ảnh theo khung nhìn hiện tại', rooms['columns'].include?('areaProjected') && rooms['headers']['areaProjected'] == 'Diện tích phòng' && rooms['headers']['definition'] == 'Mã phòng' && rooms['settings'].values_at('length_unit', 'length_digits', 'image_view', 'image_width') == ['m', 2, 'current', 256]
furniture = T::BUILT_IN_PRESETS.find { |p| p['name'] == 'Nội thất' }
check 'Nội thất: mm, cột kích thước RxSxC, hãng, số lượng; ảnh iso', furniture['columns'] == %w[ordinal image definition instance description lenXYZ owner quantity] && furniture['settings'].values_at('length_unit', 'length_digits', 'image_view') == ['mm', 0, 'isometric']
check 'Cửa & Cửa sổ: ảnh chính diện, diện tích RxC', T::BUILT_IN_PRESETS.find { |p| p['name'] == 'Cửa & Cửa sổ' }['settings']['image_view'] == 'front'
check '4 preset BIM cũ giữ nguyên cột và nhóm', T::BUILT_IN_PRESETS[1]['group'] == 'S. STRUCTURAL' && T::BUILT_IN_PRESETS[0]['columns'] == %w[ordinal image entity definition instance description material tag status quantity]

# ---- Cột mới ----
%w[areaProjected ifc owner url size price total].each { |k| check "có cột #{k}", keys.include?(k) }
check 'có 40 cột, không trùng', keys.size == 40 && keys.uniq.size == 40
check 'cột sửa được: owner, url, size, price', %w[owner url size price].all? { |k| T::COLUMNS.find { |c| c[:key] == k }[:editable] == k }
check 'cột tính tổng: diện tích chiếu và thành tiền', %w[areaProjected total].all? { |k| T::COLUMNS.find { |c| c[:key] == k }[:kind] == 'sum' }

# ---- Lưu và đọc preset tự tạo ----
T.save_preset('Của tôi', 'Đồ rời', %w[ordinal image instance price], {'instance' => 'Tên'}, {'length_unit' => 'cm', 'currency' => 'USD'})
mine = T.custom_presets.find { |p| p['name'] == 'Của tôi' }
check 'lưu preset kèm tiêu đề và thiết lập, đọc lại đúng', mine['headers'] == {'instance' => 'Tên'} && mine['settings']['length_unit'] == 'cm' && mine['settings']['currency'] == 'USD' && mine['settings']['image_width'] == 512
T.save_preset('Chỉ cột', '', %w[ordinal instance])
only = T.custom_presets.find { |p| p['name'] == 'Chỉ cột' }
check 'lưu preset chỉ có cột (cách gọi cũ): thiết lập lấy mặc định, tiêu đề rỗng', only['settings'] == d && only['headers'] == {}
check 'lưu preset với thiết lập sai bị từ chối, không ghi', raises?('đơn vị') { T.save_preset('Hỏng', '', %w[instance], {}, {'length_unit' => 'km'}) } && T.custom_presets.none? { |p| p['name'] == 'Hỏng' }
check 'lưu preset với tiêu đề sai bị từ chối', raises? { T.save_preset('Hỏng 2', '', %w[instance], {'instance' => 'a' * 99}, {}) }
File.write(File.join(VGD::BIM::Storage.dir, 'table_presets.json'), JSON.generate([{'name' => 'Cũ', 'group' => 'Phần thô', 'columns' => %w[ordinal instance lenX]}, {'name' => 'Mặc định', 'group' => '', 'columns' => %w[instance]}]))
old = T.custom_presets
check 'preset cũ (chỉ có cột) vẫn đọc được, thêm thiết lập mặc định', old.first['name'] == 'Cũ' && old.first['settings'] == d && old.first['headers'] == {} && old.first['group'] == 'S. STRUCTURAL'
check 'preset tự tạo trùng tên preset có sẵn thì ẩn đi (không hiện hai preset cùng tên)', old.map { |p| p['name'] } == ['Cũ'] && T.presets.map { |p| p['name'] }.count('Mặc định') == 1

# ---- Trạng thái bảng ----
T.save_view_state('preset' => 'Cũ', 'order' => %w[instance lenX], 'visible' => %w[instance], 'headers' => {'instance' => 'Tên', 'zzz' => 'x'}, 'settings' => {'length_unit' => 'm', 'area_unit' => 'zzz'})
st = T.view_state
check 'lưu trạng thái bảng kèm tiêu đề và thiết lập (mục sai bị bỏ, không báo lỗi)', st['headers'] == {'instance' => 'Tên'} && st['settings']['length_unit'] == 'm' && st['settings']['area_unit'] == 'm2'
check 'trạng thái cũ không có thiết lập: đọc ra không có mục settings để giao diện lấy từ preset', (T.save_view_state('preset' => 'Cũ'); !T.view_state.key?('settings') && !T.view_state.key?('headers'))

# ---- Nhập preset từ định dạng của plugin tham khảo ----
ref = {
  'Phong' => {'columns' => {'ordinal' => true, 'image' => true, 'definition' => true, 'instance' => true, 'lenX' => true, 'areaProjected' => true, 'dynamic' => true, 'description' => false, 'tag' => false},
              'language' => 'en-US', 'currency' => 'USD',
              'headers' => {'definition' => 'Room Code', 'instance' => false, 'areaProjected' => 'Room Area', 'material' => false},
              'order' => %w[id ordinal image entity definition instance description lenX lenY lenZ areaProjected dynamic tag],
              'sortColumn' => 'lenY', 'sortOrder' => '1',
              'settings' => {'roundLength' => 2, 'formatLength' => 1, 'roundArea' => 2, 'formatArea' => 1, 'roundVolume' => 2, 'formatVolume' => 1, 'decimalSeparator' => '.', 'imageHeight' => 256, 'imageWidth' => 256, 'imageView' => 'Isometric view', 'imageStyle' => 'Color style'}},
  'Nhieu' => {'columns' => {'instance' => true}, 'settings' => {'formatLength' => 1000, 'roundLength' => 0, 'imageView' => 'Top view', 'imageStyle' => 'Wireframe', 'decimalSeparator' => ';', 'imageWidth' => 99999}},
  'Rong' => {'columns' => {'instance' => false}},
  'Hong' => 'không phải đối tượng'
}
got = P.import(ref, keys, G)
phong = got.find { |p| p['name'] == 'Phong' }
check 'nhập: chỉ lấy cột đang bật và biết, giữ thứ tự theo "order", bỏ cột lạ (id, dynamic)', phong['columns'] == %w[ordinal image definition instance lenX areaProjected]
check 'nhập: tiêu đề tự đặt được giữ, "false" nghĩa là dùng tên gốc', phong['headers'] == {'definition' => 'Room Code', 'areaProjected' => 'Room Area'}
check 'nhập: đơn vị theo hệ số (1 là m, 1000 là mm), số lẻ, dấu thập phân, tiền tệ', phong['settings'].values_at('length_unit', 'length_digits', 'area_unit', 'area_digits', 'volume_unit', 'volume_digits', 'decimal_separator', 'currency') == ['m', 2, 'm2', 2, 'm3', 2, '.', 'USD']
check 'nhập: kích thước ảnh, góc nhìn, kiểu hiển thị', phong['settings'].values_at('image_width', 'image_height', 'image_view', 'image_style') == [256, 256, 'isometric', 'color']
nhieu = got.find { |p| p['name'] == 'Nhieu' }
check 'nhập: giá trị không hiểu được thì về mặc định, không báo lỗi (góc Top, kiểu Wireframe, dấu ;, ảnh quá lớn)', nhieu['settings'].values_at('length_unit', 'length_digits', 'image_view', 'image_style', 'decimal_separator', 'image_width') == ['mm', 0, 'current', 'current', ',', 512]
check 'nhập: thứ tự cột theo "order" của file, cột bật mà không có trong order xếp sau', P.import({'X' => {'columns' => {'ordinal' => true, 'definition' => true, 'instance' => true, 'tag' => true}, 'order' => %w[instance definition ordinal]}}, keys, G).first['columns'] == %w[instance definition ordinal tag]
check 'nhập: bỏ preset không có cột nào bật và mục không phải đối tượng', got.map { |p| p['name'] } == %w[Phong Nhieu]
check 'nhập: không đọc sắp xếp của plugin tham khảo (không rõ chiều)', !phong.key?('sort')
check 'nhập: tên trùng preset có sẵn thì thêm "(nhập)"', P.import({'Mặc định' => {'columns' => {'instance' => true}}}, keys, G).first['name'] == 'Mặc định (nhập)'
check 'nhập: tên quá dài bị cắt còn 40 ký tự', P.import({('a' * 60) => {'columns' => {'instance' => true}}}, keys, G).first['name'].length == 40
check 'nhập: không phải đối tượng JSON bị từ chối', raises?('preset') { P.import([1, 2], keys, G) } && raises?('preset') { P.import('x', keys, G) }
check 'nhập: file không có preset hợp lệ nào bị từ chối', raises?('không có preset') { P.import({'A' => {'columns' => {}}}, keys, G) }
check 'nhập: quá 100 preset bị từ chối', raises?('quá nhiều') { P.import((1..101).to_h { |i| ["P#{i}", {'columns' => {'instance' => true}}] }, keys, G) }

# ---- Xuất và nhập định dạng riêng ----
exported = P.export(T.custom_presets + [mine])
check 'xuất: có định dạng và phiên bản', exported['format'] == 'VGD_BIM_PRESETS' && exported['version'] == 1 && exported['presets'].is_a?(Array)
back = P.import(JSON.parse(JSON.generate(exported)), keys, G)
check 'xuất rồi nhập lại giống hệt (cột, tiêu đề, thiết lập)', back.find { |p| p['name'] == 'Của tôi' } == mine
check 'nhập định dạng riêng kiểm tra lại từng preset (cột lạ bị bỏ, thiết lập sai bị từ chối)', P.import({'format' => 'VGD_BIM_PRESETS', 'version' => 1, 'presets' => [{'name' => 'X', 'group' => '', 'columns' => %w[instance zzz]}]}, keys, G).first['columns'] == %w[instance] && raises? { P.import({'format' => 'VGD_BIM_PRESETS', 'version' => 1, 'presets' => [{'name' => 'X', 'group' => '', 'columns' => %w[instance], 'settings' => {'length_unit' => 'km'}}]}, keys, G) }
check 'nhập định dạng riêng: phiên bản lạ bị từ chối', raises?('phiên bản') { P.import({'format' => 'VGD_BIM_PRESETS', 'version' => 99, 'presets' => []}, keys, G) }
