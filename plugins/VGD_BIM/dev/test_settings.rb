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
check 'mặc định: tiếng Việt, thư mục ảnh để trống', S::DEFAULTS == {'language' => 'vi', 'image_dir' => '', 'exclude_words' => 'tay nắm, tay nam, handle, knob'}
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
check 'file có giá trị sai: mục sai về mặc định, mục đúng giữ, mục cũ (đã chuyển sang preset) bị bỏ', read == {'language' => 'vi', 'image_dir' => custom, 'exclude_words' => S::DEFAULTS['exclude_words']}
File.write(File.join(VGD::BIM::Storage.dir, 'settings.json'), '{không phải json')
check 'file hỏng: dùng mặc định', S.read == S::DEFAULTS
File.write(File.join(VGD::BIM::Storage.dir, 'settings.json'), '[1,2]')
check 'file không phải đối tượng JSON: dùng mặc định', S.read == S::DEFAULTS
