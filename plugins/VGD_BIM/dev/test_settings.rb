# Test cài đặt người dùng của VGD_BIM (ngôn ngữ, thư mục ảnh, cỡ ảnh, nền, cách chụp, đơn vị). Chạy: ruby dev/test_settings.rb
require 'json'
require 'tmpdir'
require 'fileutils'
module VGD; module BIM; def self.log(m); end; end; end
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_settings')
require File.expand_path('../runtime/vgd_bim/core/storage.rb', __dir__)
require File.expand_path('../runtime/vgd_bim/core/settings.rb', __dir__)
S = VGD::BIM::Settings
def check(label, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{label}"; end
def raises?(text = nil); yield; false; rescue ArgumentError => e; text ? e.message.downcase.include?(text) : true; end

check 'chưa có file: dùng giá trị mặc định', S.read == S::DEFAULTS
check 'mặc định: tiếng Việt, thư mục ảnh để trống', S::DEFAULTS == {'language' => 'vi', 'image_dir' => '', 'exclude_words' => 'tay nắm, tay nam, handle, knob', 'exclude_tags' => [], 'pinned_tags' => [], 'recent_tags' => []}
check 'thư mục ảnh mặc định nằm trong thư mục dữ liệu của plugin', S.image_dir == File.join(VGD::BIM::Storage.dir, 'images')

saved = S.update('language' => 'en')
check 'lưu ngôn ngữ, đọc lại đúng từ file settings.json', saved['language'] == 'en' && File.exist?(File.join(VGD::BIM::Storage.dir, 'settings.json')) && S.read == saved

custom = File.join(Dir.tmpdir, 'anh_noi_that')
check 'thư mục ảnh tự chọn (đường dẫn tuyệt đối) được nhận', S.update('image_dir' => custom)['image_dir'] == custom && S.image_dir == custom
check 'để trống thư mục ảnh thì quay về mặc định', S.update('image_dir' => '  ')['image_dir'] == '' && S.image_dir == File.join(VGD::BIM::Storage.dir, 'images')

# Dữ liệu sai phải bị từ chối, không ghi
before = S.read
check 'ngôn ngữ lạ bị từ chối', raises?('ngôn ngữ') { S.update('language' => 'fr') }
check 'thư mục ảnh không phải đường dẫn tuyệt đối bị từ chối', raises?('thư mục') { S.update('image_dir' => 'anh/noi/that') }
check 'thư mục ảnh có ký tự điều khiển bị từ chối', raises?('thư mục') { S.update('image_dir' => "#{custom}\0x") }
check 'thư mục ảnh quá dài bị từ chối', raises?('thư mục') { S.update('image_dir' => File.join(Dir.tmpdir, 'a' * 400)) }
check 'tên cài đặt lạ bị bỏ qua, không ghi vào file', !S.update('hack' => 1).key?('hack') && !JSON.parse(File.read(File.join(VGD::BIM::Storage.dir, 'settings.json'))).key?('hack')
check 'giá trị sai không làm đổi cài đặt đang có', S.read == S.read.merge(before) && S.read['language'] == 'en'

# File hỏng hoặc có giá trị sai (sửa tay) thì rơi về mặc định từng mục, không báo lỗi
File.write(File.join(VGD::BIM::Storage.dir, 'settings.json'), JSON.generate('language' => 'xx', 'image_dir' => custom, 'length_unit' => 'cm'))
read = S.read
check 'file có giá trị sai: mục sai về mặc định, mục đúng giữ, mục cũ (đã chuyển sang preset) bị bỏ', read == {'language' => 'vi', 'image_dir' => custom, 'exclude_words' => S::DEFAULTS['exclude_words'], 'exclude_tags' => [], 'pinned_tags' => [], 'recent_tags' => []}
File.write(File.join(VGD::BIM::Storage.dir, 'settings.json'), '{không phải json')
check 'file hỏng: dùng mặc định', S.read == S::DEFAULTS
File.write(File.join(VGD::BIM::Storage.dir, 'settings.json'), '[1,2]')
check 'file không phải đối tượng JSON: dùng mặc định', S.read == S::DEFAULTS

# ---- Tag ghim và tag gần đây (tab Soạn tag > Trong model) ----
File.delete(File.join(VGD::BIM::Storage.dir, 'settings.json')) if File.exist?(File.join(VGD::BIM::Storage.dir, 'settings.json'))
check 'tag ghim và tag gần đây mặc định rỗng', S.read['pinned_tags'] == [] && S.read['recent_tags'] == []
S.touch_recent('A. WALL'); S.touch_recent('A. DOOR'); S.touch_recent('a. wall')
check 'tag gần đây: mới nhất đứng đầu, không trùng (không phân biệt hoa thường), giữ tên viết lần gán mới nhất', S.read['recent_tags'] == ['a. wall', 'A. DOOR']
10.times { |i| S.touch_recent("T#{i}") }
check 'tag gần đây: tối đa 8 tag, tag cũ nhất bị bỏ', S.read['recent_tags'].size == 8 && S.read['recent_tags'].first == 'T9' && !S.read['recent_tags'].include?('A. DOOR')
before = S.read['recent_tags']
S.touch_recent('   ')
check 'tag gần đây: tên rỗng bị bỏ qua', S.read['recent_tags'] == before
check 'ghim tag: thêm vào danh sách, ghim lại không trùng', S.set_pinned('A. WALL', true) == ['A. WALL'] && S.set_pinned('a. wall', true) == ['a. wall'] && S.read['pinned_tags'] == ['a. wall']
S.set_pinned('S. BEAM', true)
check 'ghim nhiều tag giữ thứ tự ghim', S.read['pinned_tags'] == ['a. wall', 'S. BEAM']
check 'bỏ ghim: chỉ bỏ đúng tag đó', S.set_pinned('A. WALL', false) == ['S. BEAM']
check 'ghim tag tên rỗng bị từ chối', raises?('chọn') { S.set_pinned('', true) }
check 'ghi tay danh sách ghim sai kiểu bị từ chối', raises? { S.update('pinned_tags' => 'A. WALL') } && raises? { S.update('pinned_tags' => [1]) }
File.write(File.join(VGD::BIM::Storage.dir, 'settings.json'), JSON.generate('pinned_tags' => 'hỏng', 'recent_tags' => (1..20).map { |i| "t#{i}" }))
check 'file sửa tay: danh sách ghim sai về rỗng, danh sách gần đây quá dài bị cắt còn 8', S.read['pinned_tags'] == [] && S.read['recent_tags'].size == 8
