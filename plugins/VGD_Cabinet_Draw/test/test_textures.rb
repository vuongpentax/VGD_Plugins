# Test vân vật liệu và thông báo (beta.40): tự cập nhật tủ có vân không lỗi; sửa tủ giữ vật liệu ván;
# lỗi tự cập nhật chỉ báo MỘT lần và không thử lại đến khi kéo Scale tiếp. Chạy: ruby test_textures.rb [thư mục runtime]
$stdout.sync = true
src = File.read(File.join(__dir__, 'test_build.rb'), encoding: 'UTF-8')
# Dùng lại phần khởi tạo + hàm phụ của test_build (cab, part, bb, ...).
eval(src.split("puts '== 1.").first, binding, File.join(__dir__, 'test_build.rb'))

def dims(c); d = V::ModelData.params(c); [d['width_mm'], d['depth_mm'], d['height_mm']]; end
def scale_root(c, sx, sy = 1.0, sz = 1.0)
  c.transformation = Geom::Transformation.scaling(sx, sy, sz) * c.transformation
end
def auto_run(c)
  reselect(c)
  V::AutoStretch.after_commit(Sketchup.active_model)
end
def textured(name)
  m = Sketchup.active_model.materials.add(name)
  m.texture = Sketchup::Texture.new(24.0, 12.0, 512, 256)
  m
end
def auto_msgs; UI.msgs.select { |m| m.include?('Tự cập nhật tủ') }; end

puts '== 1. Tự cập nhật tủ có vân: không lỗi, vân giữ nguyên trên ván =='
UI.msgs.clear
c = cab
mat = textured('Gỗ sồi')
part(c, 'Hông Phải').material = mat
scale_root(c, 1.25)
auto_run(c)
check 'tủ hết trạng thái Scale và rộng 1000', V::Rebuild.scale_of(c).nil? && dims(c)[0] == 1000.0, dims(c).inspect
check 'không có hộp thoại lỗi', auto_msgs.empty?, UI.msgs.inspect
check 'ván có vân vẫn giữ vật liệu sau co giãn', part(c, 'Hông Phải').material.equal?(mat)

puts '== 2. Sửa tủ (hông chạm đất): ván dựng lại vẫn giữ vật liệu =='
c = cab
mat = textured('Gỗ óc chó')
part(c, 'Hông Trái').material = mat
part(c, 'Nóc').material = mat
settings = V::Rebuild.settings_of(c).merge('sides_to_floor' => true, 'leg_height' => 100.0)
V::Rebuild.run(c, settings, V::Rebuild.dimensions_of(c))
check 'hông chạm đất: hông trái dựng lại và vẫn có vật liệu', part(c, 'Hông Trái').material.equal?(mat)
check 'hông chạm đất: nóc dựng lại vẫn có vật liệu', part(c, 'Nóc').material.equal?(mat)
check 'mặt vân được đặt lại theo kích thước thật', part(c, 'Hông Trái').definition.entities.grep(Sketchup::Face).any? { |f| !f.positioned.empty? }

puts '== 3. Lỗi tự cập nhật: một hộp thoại, không thử lại đến khi kéo tiếp =='
UI.msgs.clear
c = cab
original = V::Rebuild.method(:stretch)
V::Rebuild.define_singleton_method(:stretch) { |_root| raise 'Lỗi giả lập' }
scale_root(c, 1.25)
auto_run(c)
check 'lần đầu: đúng một hộp thoại lỗi', auto_msgs.length == 1, auto_msgs.length
auto_run(c)
check 'không kéo tiếp thì không báo lại', auto_msgs.length == 1, auto_msgs.length
scale_root(c, 1.1)
auto_run(c)
check 'kéo tiếp thì thử lại và báo lại (một lần)', auto_msgs.length == 2, auto_msgs.length
V::Rebuild.singleton_class.send(:remove_method, :stretch)
check 'khôi phục hàm gốc', V::Rebuild.method(:stretch).owner != V::Rebuild.singleton_class

puts '== 4. Gốc trục của từng ván nằm ở góc của ván, trục không xoay (theo trục tủ / thế giới) =='
c = cab
[['Nóc', 'top'], ['Hông Phải', 'side'], ['Đáy', 'bottom']].each do |name, label|
  g = part(c, name)
  t = g.transformation.to_a
  corner = bb(g) # [x0,y0,z0,...] mm trong hệ cha
  check "#{label}: gốc trục đặt ở góc của ván", (t[12].to_mm - corner[0]).abs < 0.01 && (t[13].to_mm - corner[1]).abs < 0.01 && (t[14].to_mm - corner[2]).abs < 0.01, [t[12].to_mm, t[13].to_mm, t[14].to_mm, corner].inspect
  check "#{label}: hình học của ván nằm trong hệ riêng (từ gốc 0)", g.definition.bounds.min.to_a.all? { |v| v.to_mm.abs < 0.01 }
  check "#{label}: trục không xoay so với tủ", [t[0], t[1], t[2], t[4], t[5], t[6], t[8], t[9], t[10]] == [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]
end

puts '== 5. Sau scale: gốc ván vẫn ở góc ván, hộp định nghĩa đúng, không bị coi là chỉnh tay =='
c = cab
scale_root(c, 1.25)
auto_run(c)
hong = part(c, 'Hông Phải')
t = hong.transformation.to_a
hb = bb(hong)
check 'scale: gốc ván trùng góc hộp thế giới của ván', near(t[12].to_mm, hb[0], 0.01) && near(t[13].to_mm, hb[1], 0.01) && near(t[14].to_mm, hb[2], 0.01), [t[12].to_mm, hb[0]].inspect
check 'scale: hộp định nghĩa vẫn bắt đầu từ 0', hong.definition.bounds.min.to_a.all? { |v| v.to_mm.abs < 0.01 }
check 'scale: ván không bị coi là chỉnh tay', V::Geometry.hand_edited?(hong) != true
check 'scale: hông phải dời tới 1000 mm', near(hb[3], 1000.0, 0.01), hb.inspect

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.size}"
exit($fail.empty? ? 0 : 1)
