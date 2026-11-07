# Test lưu ảnh món đồ của VGD_BIM (đường dẫn, kiểm tra PNG, ghi/xóa, nhận ảnh dán hoặc kéo thả). Chạy: ruby dev/test_images.rb
require 'json'
require 'tmpdir'
require 'fileutils'
require 'base64'
module VGD; module BIM; def self.log(m); end; end; end
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_images')
%w[storage settings images].each { |f| require File.expand_path("../runtime/vgd_bim/core/#{f}.rb", __dir__) }
I = VGD::BIM::Images
S = VGD::BIM::Settings
def check(label, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{label}"; end
def raises?(text = nil); yield; false; rescue ArgumentError => e; text ? e.message.downcase.include?(text) : true; end
Model = Struct.new(:guid)
model = Model.new('3F2A-91C0-aa11')
PNG = ("\x89PNG\r\n\x1A\n".b + 'noi dung anh'.b).freeze

check 'ảnh nằm trong thư mục ảnh / mã model / mã đối tượng', I.path(model, 123) == File.join(S.image_dir, '3F2A-91C0-aa11', '123.png')
check 'ảnh nhỏ (thumbnail) có đuôi riêng', I.path(model, 123, :thumb) == File.join(S.image_dir, '3F2A-91C0-aa11', '123_t.png')
check 'mã model có ký tự lạ được làm sạch, không thoát khỏi thư mục ảnh', I.dir(Model.new('../../x/y')).start_with?(S.image_dir) && !I.dir(Model.new('../../x/y')).include?('..')
check 'model chưa có mã dùng thư mục chung "model"', I.dir(Model.new(nil)) == File.join(S.image_dir, 'model') && I.dir(Model.new('')) == File.join(S.image_dir, 'model')
check 'mã đối tượng phải là số nguyên dương', raises?('mã đối tượng') { I.path(model, '1/../x') } && raises?('mã đối tượng') { I.path(model, 0) } && raises?('mã đối tượng') { I.path(model, nil) }
check 'đổi thư mục ảnh trong cài đặt thì đường dẫn đổi theo', (S.update('image_dir' => File.join(Dir.tmpdir, 'anh_khac')); I.path(model, 5).start_with?(File.join(Dir.tmpdir, 'anh_khac'))) && (S.update('image_dir' => ''); true)

check 'info nhận sẵn thư mục để bảng lớn không phải tính lại cho từng dòng', I.info(model, 7, '/khong/co/thu/muc') == {has: false, stamp: 0}
check 'chưa có ảnh: info báo không có', I.info(model, 7) == {has: false, stamp: 0}
I.write(model, 7, PNG, PNG)
info = I.info(model, 7)
check 'ghi ảnh: có file chính và file nhỏ, info báo có ảnh', File.binread(I.path(model, 7)) == PNG && File.binread(I.path(model, 7, :thumb)) == PNG && info[:has] && info[:stamp] > 0
check 'không để lại file tạm sau khi ghi', Dir[File.join(I.dir(model), '*')].all? { |f| f.end_with?('7.png', '7_t.png') }
I.write(model, 7, PNG + 'moi'.b, PNG)
check 'ghi đè ảnh cũ', File.binread(I.path(model, 7)).end_with?('moi')
check 'data URL để hiện ảnh trong cửa sổ', I.data_url(I.path(model, 7, :thumb)).start_with?('data:image/png;base64,') && Base64.strict_decode64(I.data_url(I.path(model, 7, :thumb)).split(',', 2).last) == PNG
check 'ảnh không tồn tại: data URL là nil', I.data_url(I.path(model, 99)).nil?
I.delete(model, 7)
check 'xóa ảnh: mất cả file chính và file nhỏ', !File.exist?(I.path(model, 7)) && !File.exist?(I.path(model, 7, :thumb)) && I.info(model, 7)[:has] == false
check 'xóa ảnh chưa có: không lỗi', (I.delete(model, 7); true)

# Dữ liệu ảnh dán / kéo thả từ giao diện
check 'nhận base64 PNG hợp lệ', I.decode_png(Base64.strict_encode64(PNG)) == PNG
check 'nhận cả data URL', I.decode_png("data:image/png;base64,#{Base64.strict_encode64(PNG)}") == PNG
check 'từ chối dữ liệu không phải PNG (ví dụ JPEG, mã độc)', raises?('png') { I.decode_png(Base64.strict_encode64("\xFF\xD8\xFF\xE0jpeg".b)) } && raises?('png') { I.decode_png(Base64.strict_encode64('<script>alert(1)</script>')) }
check 'từ chối base64 hỏng', raises?('ảnh') { I.decode_png('@@@không phải base64') }
check 'từ chối ảnh quá lớn', raises?('quá lớn') { I.decode_png(Base64.strict_encode64("\x89PNG\r\n\x1A\n".b + ('x' * (I::MAX_BYTES + 1)))) }
check 'từ chối dữ liệu rỗng', raises?('ảnh') { I.decode_png('') } && raises?('ảnh') { I.decode_png(nil) }
check 'ghi từ chối dữ liệu không phải PNG và không để lại file', raises?('png') { I.write(model, 8, 'abc', PNG) } && !File.exist?(I.path(model, 8))
check 'ghi từ chối ảnh nhỏ không phải PNG', raises?('png') { I.write(model, 8, PNG, 'abc') } && !File.exist?(I.path(model, 8))

# Chụp bằng SketchUp: ghi vào file tạm rồi mới đổi tên, chụp hỏng thì ảnh cũ còn nguyên
I.write(model, 9, PNG, PNG)
tmp = I.temp_path(model, 9, :full)
check 'đường dẫn tạm khác đường dẫn chính và vẫn có đuôi .png (SketchUp yêu cầu)', tmp != I.path(model, 9) && tmp.end_with?('.png') && File.dirname(tmp) == I.dir(model)
check 'commit khi file tạm chưa được tạo thì báo lỗi và giữ ảnh cũ', raises?('không tạo được') { I.commit(model, 9, :full) } && File.binread(I.path(model, 9)) == PNG
File.binwrite(tmp, PNG + 'moi'.b)
I.commit(model, 9, :full)
check 'commit đổi file tạm thành ảnh chính', File.binread(I.path(model, 9)).end_with?('moi') && !File.exist?(tmp)
File.binwrite(I.temp_path(model, 9, :thumb), 'khong phai png')
check 'commit từ chối file tạm không phải PNG, giữ ảnh cũ, dọn file tạm', raises?('png') { I.commit(model, 9, :thumb) } && File.binread(I.path(model, 9, :thumb)) == PNG && !File.exist?(I.temp_path(model, 9, :thumb))
