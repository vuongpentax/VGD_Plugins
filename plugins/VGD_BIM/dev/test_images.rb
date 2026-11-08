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
check 'chỉ còn ảnh gốc, không có ảnh nhỏ (thumbnail)', I::KINDS.keys == [:full] && !I.respond_to?(:thumb_path)
check 'mã model có ký tự lạ được làm sạch, không thoát khỏi thư mục ảnh', I.dir(Model.new('../../x/y')).start_with?(S.image_dir) && !I.dir(Model.new('../../x/y')).include?('..')
check 'model chưa có mã dùng thư mục chung "model"', I.dir(Model.new(nil)) == File.join(S.image_dir, 'model') && I.dir(Model.new('')) == File.join(S.image_dir, 'model')
check 'mã đối tượng phải là số nguyên dương', raises?('mã đối tượng') { I.path(model, '1/../x') } && raises?('mã đối tượng') { I.path(model, 0) } && raises?('mã đối tượng') { I.path(model, nil) }
check 'đổi thư mục ảnh trong cài đặt thì đường dẫn đổi theo', (S.update('image_dir' => File.join(Dir.tmpdir, 'anh_khac')); I.path(model, 5).start_with?(File.join(Dir.tmpdir, 'anh_khac'))) && (S.update('image_dir' => ''); true)

# Mã model cố định: model.guid của SketchUp đổi mỗi lần mở file nên không dùng làm tên thư mục; mã lưu trong file SketchUp
class AttrModel
  attr_reader :guid, :ops, :attrs
  def initialize(guid, attrs = {}); @guid = guid; @attrs = attrs; @ops = []; end
  def get_attribute(dict, key, default = nil); (@attrs[dict] || {}).fetch(key, default); end
  def set_attribute(dict, key, value); raise 'không ghi được' if @fail; (@attrs[dict] ||= {})[key] = value; end
  def start_operation(*args); @ops << [:start, args]; true; end
  def commit_operation; @ops << :commit; end
  def abort_operation; @ops << :abort; end
  def fail_writes; @fail = true; end
end
saved_attrs = {'VGD_BIM_MODEL' => {'model_id' => 'aaaabbbb-cccc-dddd-eeee-ffff00001111'}}
first_open = AttrModel.new('GUID-LAN-1', saved_attrs)
second_open = AttrModel.new('GUID-LAN-2-KHAC', saved_attrs)
check 'đã có mã cố định trong file: thư mục theo mã đó, không theo guid', I.dir(first_open) == File.join(S.image_dir, 'aaaabbbb-cccc-dddd-eeee-ffff00001111')
check 'mở lại file (guid đổi, mã trong file giữ nguyên): vẫn đúng thư mục ảnh cũ', I.dir(second_open) == I.dir(first_open)
check 'ensure_model_id khi đã có mã: không tạo thao tác nào, trả về mã cũ', I.ensure_model_id(first_open) == 'aaaabbbb-cccc-dddd-eeee-ffff00001111' && first_open.ops.empty?
fresh = AttrModel.new('GUID-MOI')
id = I.ensure_model_id(fresh)
check 'model chưa có mã: tạo mã mới đúng dạng, ghi vào file SketchUp', id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/) && fresh.attrs['VGD_BIM_MODEL']['model_id'] == id && I.dir(fresh).end_with?(id)
check 'ghi mã là một thao tác trong suốt (gộp vào bước hoàn tác trước), có commit', fresh.ops == [[:start, ['VGD_BIM · Mã model', true, false, true]], :commit]
check 'gọi lần hai: không tạo mã khác, không thêm thao tác', I.ensure_model_id(fresh) == id && fresh.ops.size == 2
legacy = AttrModel.new('GUID-CU-CUA-PHIEN-NAY')
FileUtils.mkdir_p(File.join(S.image_dir, 'GUID-CU-CUA-PHIEN-NAY'))
File.binwrite(File.join(S.image_dir, 'GUID-CU-CUA-PHIEN-NAY', '5.png'), PNG)
new_id = I.ensure_model_id(legacy)
check 'ảnh đã chụp trong phiên này (thư mục theo guid) được chuyển sang thư mục theo mã mới', File.binread(File.join(S.image_dir, new_id, '5.png')) == PNG && !File.exist?(File.join(S.image_dir, 'GUID-CU-CUA-PHIEN-NAY')) && I.info(legacy, 5)[:has]
both = AttrModel.new('GUID-HAI-NOI')
FileUtils.mkdir_p(File.join(S.image_dir, 'GUID-HAI-NOI'))
File.binwrite(File.join(S.image_dir, 'GUID-HAI-NOI', '1.png'), PNG)
SecureRandom.singleton_class.send(:alias_method, :orig_uuid, :uuid)
SecureRandom.define_singleton_method(:uuid) { '11111111-2222-3333-4444-555555555555' }
FileUtils.mkdir_p(File.join(S.image_dir, '11111111-2222-3333-4444-555555555555'))
I.ensure_model_id(both)
SecureRandom.singleton_class.send(:alias_method, :uuid, :orig_uuid)
check 'thư mục mã mới đã có sẵn: không đè, thư mục guid cũ giữ nguyên', File.exist?(File.join(S.image_dir, 'GUID-HAI-NOI', '1.png'))
bad = AttrModel.new('GUID-X', {'VGD_BIM_MODEL' => {'model_id' => '../../etc'}})
check 'mã sai dạng trong file (sửa tay): bị bỏ qua, không thoát khỏi thư mục ảnh', I.dir(bad).start_with?(S.image_dir) && !I.dir(bad).include?('..') && I.dir(bad).end_with?('GUID-X')
fixed = I.ensure_model_id(bad)
check 'mã sai dạng: được thay bằng mã đúng', fixed.match?(/\A[0-9a-f-]{36}\z/) && bad.attrs['VGD_BIM_MODEL']['model_id'] == fixed
broken = AttrModel.new('GUID-LOI'); broken.fail_writes
check 'không ghi được vào file SketchUp: hủy thao tác, không báo lỗi, quay về dùng guid', I.ensure_model_id(broken).nil? && broken.ops.last == :abort && I.dir(broken).end_with?('GUID-LOI')
check 'model không có API thuộc tính: ensure_model_id trả nil và dùng guid như cũ', I.ensure_model_id(Model.new('G')).nil? && I.dir(Model.new('G')).end_with?('G')

check 'info nhận sẵn thư mục để bảng lớn không phải tính lại cho từng dòng', I.info(model, 7, '/khong/co/thu/muc') == {has: false, stamp: 0}
check 'chưa có ảnh: info báo không có', I.info(model, 7) == {has: false, stamp: 0}
I.write(model, 7, PNG)
info = I.info(model, 7)
check 'ghi ảnh: chỉ có file ảnh gốc (không tạo ảnh nhỏ), info báo có ảnh', File.binread(I.path(model, 7)) == PNG && info[:has] && info[:stamp] > 0 && Dir[File.join(I.dir(model), '*')].map { |f| File.basename(f) } == ['7.png']
I.write(model, 7, PNG + 'moi'.b)
check 'ghi đè ảnh cũ', File.binread(I.path(model, 7)).end_with?('moi')
check 'data URL để hiện ảnh trong cửa sổ (dự phòng khi không nạp được bằng đường dẫn file)', I.data_url(I.path(model, 7)).start_with?('data:image/png;base64,') && Base64.strict_decode64(I.data_url(I.path(model, 7)).split(',', 2).last).end_with?('moi')
url = I.file_url(model, 7, 12345)
check 'đường dẫn file để hiện ảnh trực tiếp: file:/// + đường dẫn đã mã hóa + mốc thời gian để làm mới', url.start_with?('file:///') && url.end_with?('/7.png?v=12345') && !url.include?(' ') && !url.include?('\\')
S.update('image_dir' => File.join(Dir.tmpdir, 'anh nội thất'))
special = I.file_url(model, 7, 1)
S.update('image_dir' => '')
check 'đường dẫn file: khoảng trắng và dấu tiếng Việt được mã hóa (anh%20n%E1%BB%99i%20th%E1%BA%A5t)', special.include?('/anh%20n%E1%BB%99i%20th%E1%BA%A5t/') && special.ascii_only?
check 'đường dẫn file: mốc thời gian phải là số nguyên', raises?('invalid') { I.file_url(model, 7, 'x; alert(1)') } || (begin; I.file_url(model, 7, 'x'); false; rescue ArgumentError; true; end)
FileUtils.mkdir_p(I.dir(model))
File.binwrite(File.join(I.dir(model), '7_t.png'), PNG) # ảnh nhỏ cũ của các bản beta trước
check 'ảnh không tồn tại: data URL là nil', I.data_url(I.path(model, 99)).nil?
I.delete(model, 7)
check 'xóa ảnh: mất file chính và dọn luôn ảnh nhỏ cũ của bản trước', !File.exist?(I.path(model, 7)) && !File.exist?(File.join(I.dir(model), '7_t.png')) && I.info(model, 7)[:has] == false
check 'xóa ảnh chưa có: không lỗi', (I.delete(model, 7); true)

# Dữ liệu ảnh dán / kéo thả từ giao diện
check 'nhận base64 PNG hợp lệ', I.decode_png(Base64.strict_encode64(PNG)) == PNG
check 'nhận cả data URL', I.decode_png("data:image/png;base64,#{Base64.strict_encode64(PNG)}") == PNG
check 'từ chối dữ liệu không phải PNG (ví dụ JPEG, mã độc)', raises?('png') { I.decode_png(Base64.strict_encode64("\xFF\xD8\xFF\xE0jpeg".b)) } && raises?('png') { I.decode_png(Base64.strict_encode64('<script>alert(1)</script>')) }
check 'từ chối base64 hỏng', raises?('ảnh') { I.decode_png('@@@không phải base64') }
check 'từ chối ảnh quá lớn', raises?('quá lớn') { I.decode_png(Base64.strict_encode64("\x89PNG\r\n\x1A\n".b + ('x' * (I::MAX_BYTES + 1)))) }
check 'từ chối dữ liệu rỗng', raises?('ảnh') { I.decode_png('') } && raises?('ảnh') { I.decode_png(nil) }
check 'ghi từ chối dữ liệu không phải PNG và không để lại file', raises?('png') { I.write(model, 8, 'abc') } && !File.exist?(I.path(model, 8))

# Chụp bằng SketchUp: ghi vào file tạm rồi mới đổi tên, chụp hỏng thì ảnh cũ còn nguyên
I.write(model, 9, PNG)
tmp = I.temp_path(model, 9)
check 'đường dẫn tạm khác đường dẫn chính và vẫn có đuôi .png (SketchUp yêu cầu)', tmp != I.path(model, 9) && tmp.end_with?('.png') && File.dirname(tmp) == I.dir(model)
check 'commit khi file tạm chưa được tạo thì báo lỗi và giữ ảnh cũ', raises?('không tạo được') { I.commit(model, 9) } && File.binread(I.path(model, 9)) == PNG
File.binwrite(tmp, PNG + 'moi'.b)
I.commit(model, 9)
check 'commit đổi file tạm thành ảnh chính', File.binread(I.path(model, 9)).end_with?('moi') && !File.exist?(tmp)
File.binwrite(I.temp_path(model, 9), 'khong phai png')
check 'commit từ chối file tạm không phải PNG, giữ ảnh cũ, dọn file tạm', raises?('png') { I.commit(model, 9) } && File.binread(I.path(model, 9)).end_with?('moi') && !File.exist?(I.temp_path(model, 9))
