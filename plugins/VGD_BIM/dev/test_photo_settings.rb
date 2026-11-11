# Test thông số ảnh riêng của từng món (core/photo_settings.rb): kiểm tra dữ liệu, lưu / đọc / xóa trong dictionary của đối tượng, ghép vào thiết lập
# của preset khi chụp. SketchUp giả lập đơn giản. Chạy: ruby dev/test_photo_settings.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
require File.join(ROOT, 'core/preset')
require File.join(ROOT, 'core/photo_settings')
P = VGD::BIM::PhotoSettings

class FakeEntity
  attr_reader :attrs
  def initialize(locked = false); @attrs = {}; @locked = locked; end
  def locked?; @locked; end
  def get_attribute(dict, key, default = nil); @attrs.dig(dict, key) || default; end
  def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; end
  def delete_attribute(dict, key); (@attrs[dict] || {}).delete(key); end
end

# ---- Kiểm tra dữ liệu (dữ liệu sai viết trước) ----
ok('không phải Hash: bị từ chối', error_of { P.sanitize!('x', :full) }.to_s.include?('không hợp lệ'))
ok('khóa lạ bị từ chối', error_of { P.sanitize!({'hack' => 1}, :full) }.to_s.include?('hack'))
ok('góc nhìn lạ bị từ chối', error_of { P.sanitize!({'view' => 'top'}, :full) }.to_s.include?('Góc nhìn'))
ok('bên Iso lạ bị từ chối', error_of { P.sanitize!({'side' => 'up'}, :full) }.to_s.include?('Iso'))
ok('góc lệch ngoài -90..90 bị từ chối, góc cao ngoài -30..80 bị từ chối', error_of { P.sanitize!({'yaw' => 91}, :full) }.to_s.include?('Góc lệch') && error_of { P.sanitize!({'pitch' => 81}, :full) }.to_s.include?('Góc cao'))
ok('lề ngoài 0..100 bị từ chối', error_of { P.sanitize!({'margin' => 101}, :full) }.to_s.include?('Lề'))
ok('góc không phải số bị từ chối', error_of { P.sanitize!({'yaw' => 'abc'}, :full) } && error_of { P.sanitize!({'pitch' => 1.5}, :full) })
ok('vùng nhìn chỉ có cho ảnh vị trí (ảnh chính từ chối), ngoài 1..20 bị từ chối', error_of { P.sanitize!({'scale' => 4}, :full) }.to_s.include?('scale') && error_of { P.sanitize!({'scale' => 21}, :location) }.to_s.include?('Vùng nhìn') && error_of { P.sanitize!({'scale' => 0}, :location) }.to_s.include?('Vùng nhìn'))
# ---- Dữ liệu đúng ----
ok('hợp lệ: giữ đúng, số ở dạng chữ được nhận, giá trị rỗng / nil nghĩa là theo preset (bỏ)', P.sanitize!({'view' => 'front', 'side' => 'left', 'yaw' => '-20', 'pitch' => 15, 'margin' => '', 'x' => nil}.reject { |k, _| k == 'x' }, :full) == {'view' => 'front', 'side' => 'left', 'yaw' => -20, 'pitch' => 15})
ok('ảnh vị trí nhận thêm vùng nhìn', P.sanitize!({'scale' => '1', 'margin' => 0}, :location) == {'scale' => 1, 'margin' => 0})
ok('khóa dạng ký hiệu được nhận như chữ', P.sanitize!({view: 'current'}, :full) == {'view' => 'current'})
ok('tất cả rỗng: không có thông số riêng', P.sanitize!({'view' => '', 'yaw' => nil}, :full) == {})

# ---- Lưu / đọc / xóa ----
e = FakeEntity.new
ok('chưa lưu gì: rỗng', P.read(e, :full) == {} && P.read(e, :location) == {})
saved = P.write(e, :full, {'view' => 'front', 'yaw' => 20})
ok('ghi ảnh chính: trả về thông số sạch, lưu JSON trong dictionary VGD_BIM_TABLE', saved == {'view' => 'front', 'yaw' => 20} && JSON.parse(e.attrs['VGD_BIM_TABLE']['photo_full']) == {'view' => 'front', 'yaw' => 20})
ok('đọc lại đúng, ảnh vị trí độc lập với ảnh chính', P.read(e, :full) == {'view' => 'front', 'yaw' => 20} && P.read(e, :location) == {})
P.write(e, :location, {'view' => 'current', 'scale' => 8})
ok('ghi ảnh vị trí: lưu ở khóa riêng, không đụng ảnh chính', P.read(e, :location) == {'view' => 'current', 'scale' => 8} && P.read(e, :full) == {'view' => 'front', 'yaw' => 20})
ok('ghi dữ liệu sai: lỗi và dữ liệu cũ còn nguyên', error_of { P.write(e, :full, {'yaw' => 500}) } && P.read(e, :full) == {'view' => 'front', 'yaw' => 20})
P.write(e, :full, {})
ok('ghi rỗng: xóa thông số riêng của ảnh chính, ảnh vị trí còn', P.read(e, :full) == {} && !e.attrs['VGD_BIM_TABLE'].key?('photo_full') && P.read(e, :location) == {'view' => 'current', 'scale' => 8})
ok('đối tượng khóa: không ghi được, báo rõ', error_of { P.write(FakeEntity.new(true), :full, {'view' => 'front'}) }.to_s.include?('khóa'))
e.set_attribute('VGD_BIM_TABLE', 'photo_full', 'không phải json')
ok('dữ liệu lưu bị hỏng: coi như chưa có, không lỗi', P.read(e, :full) == {})
e.set_attribute('VGD_BIM_TABLE', 'photo_full', '{"yaw":999}')
ok('dữ liệu lưu có giá trị sai: coi như chưa có', P.read(e, :full) == {})
ok('đối tượng không có API thuộc tính: rỗng, không lỗi', P.read(Object.new, :full) == {})

# ---- Ghép vào thiết lập của preset khi chụp ----
base = VGD::BIM::Preset::DEFAULT_SETTINGS
out, side = P.apply(base, {'view' => 'front', 'side' => 'left', 'yaw' => 20, 'pitch' => 10, 'margin' => 35}, :full)
ok('ảnh chính: ghi đè góc nhìn, góc lệch, góc cao, lề của ảnh chính; không đụng mục ảnh vị trí; không sửa thiết lập gốc', out['image_view'] == 'front' && out['image_yaw'] == 20 && out['image_pitch'] == 10 && out['image_margin'] == 35 && out['loc_view'] == base['loc_view'] && out['loc_margin'] == base['loc_margin'] && base['image_view'] == 'isometric' && side == 'left')
out, side = P.apply(base, {'view' => 'front', 'yaw' => -15, 'margin' => 0, 'scale' => 6}, :location)
ok('ảnh vị trí: ghi đè mục loc_* và vùng nhìn; không đụng mục ảnh chính; không có bên Iso thì trả nil', out['loc_view'] == 'front' && out['loc_yaw'] == -15 && out['loc_margin'] == 0 && out['image_location_scale'] == 6 && out['image_view'] == base['image_view'] && out['image_yaw'] == 0 && side.nil?)
out, side = P.apply(base, {'view' => 'front', 'side' => 'left', 'yaw' => 20}, :full, force_view: true)
ok('bấm nút chụp một lần (ép góc nhìn): bỏ qua góc nhìn và bên Iso riêng của món, các thông số khác vẫn áp', out['image_view'] == base['image_view'] && out['image_yaw'] == 20 && side.nil?)
out, side = P.apply(base, {}, :full)
ok('không có thông số riêng: giữ nguyên thiết lập của preset', out == base && side.nil?)
ok('apply với thông số rỗng không đổi bản gốc', out.equal?(base) == false)

puts($fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
