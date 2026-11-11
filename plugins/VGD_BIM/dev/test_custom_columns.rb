# Test cột thêm tay của Bảng khối lượng (core/custom_columns.rb): kiểm tra dữ liệu giao diện, lưu / đọc trên máy, đọc giá trị
# thuộc tính tùy chọn / thuộc tính động / cột tự nhập từ đối tượng, ghi cột tự nhập. SketchUp giả lập đơn giản. Chạy: ruby dev/test_custom_columns.rb
require 'json'
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_custom')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
module VGD; module BIM; def self.log(_message); end; end; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
%w[storage custom_columns].each { |f| require File.join(ROOT, "core/#{f}") }
CC = VGD::BIM::CustomColumns

class FakeAttrs
  attr_reader :attrs
  def initialize; @attrs = {}; end
  def get_attribute(dict, key, default = nil); @attrs.dig(dict, key).nil? ? default : @attrs[dict][key]; end
  def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; end
  def delete_attribute(dict, key = nil); key ? @attrs[dict]&.delete(key) : @attrs.delete(dict); end
end
class FakeInstance < FakeAttrs
  attr_accessor :definition
  attr_writer :locked
  def initialize(definition = nil); super(); @definition = definition; @locked = false; end
  def locked?; @locked; end
end

# ---- Dữ liệu giao diện gửi lên sai: bị từ chối ----
good = {'label' => 'Mã vật tư', 'kind' => 'attribute', 'dictionary' => 'vgd', 'attribute' => 'ma_vat_tu'}
ok('không phải bảng băm: từ chối', error_of { CC.sanitize!('x') }.to_s.include?('không hợp lệ'))
ok('thiếu tên cột: từ chối', error_of { CC.sanitize!(good.merge('label' => '  ')) }.to_s.include?('tên cột'))
ok('tên cột quá dài: từ chối', error_of { CC.sanitize!(good.merge('label' => 'a' * (CC::MAX_LABEL + 1))) }.to_s.include?('tên cột'))
ok('kiểu lạ: từ chối', error_of { CC.sanitize!(good.merge('kind' => 'formula')) }.to_s.include?('kiểu cột'))
ok('thuộc tính tùy chọn thiếu dictionary: từ chối', error_of { CC.sanitize!(good.merge('dictionary' => '')) }.to_s.include?('dictionary'))
ok('thuộc tính tùy chọn thiếu tên thuộc tính: từ chối', error_of { CC.sanitize!(good.merge('attribute' => '')) }.to_s.include?('thuộc tính'))
ok('tên dictionary quá dài: từ chối', error_of { CC.sanitize!(good.merge('dictionary' => 'd' * (CC::MAX_NAME + 1))) }.to_s.include?('dictionary'))
ok('ký tự điều khiển trong tên thuộc tính: từ chối', error_of { CC.sanitize!(good.merge('attribute' => "a\u0001b")) }.to_s.include?('thuộc tính'))
ok('thuộc tính động thiếu tên: từ chối', error_of { CC.sanitize!('label' => 'X', 'kind' => 'dynamic', 'attribute' => ' ') }.to_s.include?('thuộc tính'))
ok('nhãn không phải chữ: từ chối', error_of { CC.sanitize!(good.merge('label' => 12)) }.to_s.include?('tên cột'))

# ---- Chuẩn hóa ----
clean = CC.sanitize!(good.merge('label' => '  Mã vật tư  ', 'dictionary' => ' vgd ', 'extra' => 'bỏ'))
ok('chuẩn hóa: cắt khoảng trắng, bỏ khóa thừa', clean == {'label' => 'Mã vật tư', 'kind' => 'attribute', 'dictionary' => 'vgd', 'attribute' => 'ma_vat_tu'})
dyn = CC.sanitize!('label' => 'Giá DC', 'kind' => 'dynamic', 'attribute' => ' Price ')
ok('thuộc tính động: dictionary cố định dynamic_attributes, tên thuộc tính viết thường', dyn == {'label' => 'Giá DC', 'kind' => 'dynamic', 'dictionary' => 'dynamic_attributes', 'attribute' => 'price'})
free = CC.sanitize!('label' => 'Ghi chú thi công', 'kind' => 'text', 'dictionary' => 'bỏ', 'attribute' => 'bỏ')
ok('cột tự nhập: không cần dictionary / thuộc tính, lưu trong VGD_BIM_TABLE', free == {'label' => 'Ghi chú thi công', 'kind' => 'text'})

# ---- Lưu / đọc trên máy ----
ok('chưa có cột nào: danh sách rỗng', CC.read == [] && CC.keys == [] && CC.columns == [])
first = CC.add(good)
ok('thêm cột: khóa custom_1, lưu lại đọc được', first['key'] == 'custom_1' && CC.read.map { |c| c['key'] } == ['custom_1'] && CC.keys == ['custom_1'])
second = CC.add(free)
ok('thêm cột tiếp: khóa custom_2', second['key'] == 'custom_2' && CC.keys == %w[custom_1 custom_2])
ok('find theo khóa', CC.find('custom_2')['kind'] == 'text' && CC.find('custom_9').nil? && CC.find(nil).nil?)
CC.remove('custom_1')
third = CC.add(dyn)
ok('xóa cột rồi thêm: khóa KHÔNG dùng lại số đã xóa (dữ liệu cột tự nhập cũ còn trong món không hiện lại ở cột mới)', CC.keys.sort == %w[custom_2 custom_3] && third['key'] == 'custom_3')
ok('xóa khóa không có: không lỗi, không đổi', (CC.remove('custom_77'); CC.keys.sort == %w[custom_2 custom_3]))
ok('xóa khóa sai kiểu: từ chối', error_of { CC.remove('name') }.to_s.include?('không hợp lệ'))
ok('cột cho giao diện: key, label, kind text, custom, editable chỉ cột tự nhập', CC.columns.find { |c| c[:key] == 'custom_2' } == {key: 'custom_2', label: 'Ghi chú thi công', kind: 'text', custom: true, source: 'text', editable: 'custom_2'} && CC.columns.find { |c| c[:key] == 'custom_3' }[:editable].nil?)
CC.keys.each { |k| CC.remove(k) }
CC.add(good) while CC.keys.size < CC::MAX_COLUMNS
ok("tối đa #{CC::MAX_COLUMNS} cột", error_of { CC.add(good) }.to_s.include?('tối đa'))
File.write(File.join(ENV['VGD_BIM_DATA_DIR'], 'custom_columns.json'), '{"next":2,"columns":[{"key":"custom_1","label":"A","kind":"attribute","dictionary":"d","attribute":"a"},{"key":"x","label":"hỏng"},{"key":"custom_1","label":"trùng khóa","kind":"text"},5,{"key":"custom_2","label":"","kind":"text"}]}')
ok('file lưu bị sửa tay: bỏ mục hỏng / trùng khóa, giữ mục đúng', CC.read.map { |c| c['key'] } == ['custom_1'])
File.write(File.join(ENV['VGD_BIM_DATA_DIR'], 'custom_columns.json'), '{"next":1,"columns":[{"key":"custom_5","label":"A","kind":"text"}]}')
ok('file lưu sửa tay: số đếm khóa không nhỏ hơn khóa đã có (khóa mới không trùng)', CC.add(good)['key'] == 'custom_6')
File.write(File.join(ENV['VGD_BIM_DATA_DIR'], 'custom_columns.json'), '[1,2]')
ok('file lưu sai dạng: coi như chưa có cột nào', CC.read == [])
File.write(File.join(ENV['VGD_BIM_DATA_DIR'], 'custom_columns.json'), 'không phải json')
ok('file lưu hỏng hẳn: coi như chưa có cột nào', CC.read == [])
File.delete(File.join(ENV['VGD_BIM_DATA_DIR'], 'custom_columns.json'))

# ---- Đọc giá trị ----
definition = FakeAttrs.new
instance = FakeInstance.new(definition)
defs = [CC.sanitize!(good).merge('key' => 'custom_1'), CC.sanitize!(dyn).merge('key' => 'custom_2'), CC.sanitize!(free).merge('key' => 'custom_3')]
ok('chưa có giá trị: ô trống', CC.values(instance, defs) == {'custom_1' => '', 'custom_2' => '', 'custom_3' => ''})
instance.set_attribute('vgd', 'ma_vat_tu', 'MV-01')
definition.set_attribute('dynamic_attributes', 'price', 125.5)
instance.set_attribute('VGD_BIM_TABLE', 'custom_3', 'Lắp sau')
ok('đọc đủ ba kiểu: thuộc tính tùy chọn (trên món), thuộc tính động (ở định nghĩa), cột tự nhập', CC.values(instance, defs) == {'custom_1' => 'MV-01', 'custom_2' => '125.5', 'custom_3' => 'Lắp sau'})
instance.set_attribute('dynamic_attributes', 'price', 99.0)
ok('món có giá trị riêng thì thắng định nghĩa; số nguyên bỏ phần .0', CC.values(instance, defs)['custom_2'] == '99')
definition.set_attribute('vgd', 'ma_vat_tu', 'MV-DEF')
instance.delete_attribute('vgd', 'ma_vat_tu')
ok('món không có thì lấy ở định nghĩa', CC.values(instance, defs)['custom_1'] == 'MV-DEF')
instance.set_attribute('vgd', 'ma_vat_tu', true)
ok('giá trị đúng / sai hiện chữ Có / Không', CC.values(instance, defs)['custom_1'] == 'Có')
instance.set_attribute('vgd', 'ma_vat_tu', 'x' * 900)
ok('giá trị dài bị cắt', CC.values(instance, defs)['custom_1'].length == CC::MAX_VALUE)
instance.set_attribute('vgd', 'ma_vat_tu', 1.23456789)
ok('số lẻ làm tròn 4 chữ số', CC.values(instance, defs)['custom_1'] == '1.2346')
group = FakeAttrs.new # Group không có định nghĩa riêng cho thuộc tính: vẫn đọc được
ok('đối tượng không có định nghĩa: chỉ đọc trên món, không lỗi', CC.values(group, defs) == {'custom_1' => '', 'custom_2' => '', 'custom_3' => ''})
ok('không có cột nào: kết quả rỗng', CC.values(instance, []) == {})

# ---- Ghi cột tự nhập ----
CC.add(free)
key = CC.keys.first
text_key = CC.add(free)['key']
CC.write(instance, text_key, '  Giao tuần sau  ')
ok('ghi cột tự nhập: lưu trong VGD_BIM_TABLE, cắt khoảng trắng', instance.get_attribute('VGD_BIM_TABLE', text_key) == 'Giao tuần sau')
CC.write(instance, text_key, '')
ok('ghi giá trị rỗng: xóa', instance.get_attribute('VGD_BIM_TABLE', text_key).nil?)
ok('giá trị quá dài: từ chối', error_of { CC.write(instance, text_key, 'a' * (CC::MAX_VALUE + 1)) }.to_s.include?('tối đa'))
instance.locked = true
ok('đối tượng khóa: từ chối', error_of { CC.write(instance, text_key, 'x') }.to_s.include?('khóa'))
instance.locked = false
attr_key = (CC.read.find { |c| c['kind'] != 'text' } || CC.add(good))['key']
ok('cột thuộc tính tùy chọn / động chỉ đọc: không ghi được', error_of { CC.write(instance, attr_key, 'x') }.to_s.include?('không sửa'))
ok('khóa không có trong danh sách: không ghi được', error_of { CC.write(instance, 'custom_99', 'x') }.to_s.include?('không sửa'))
ok('khóa sai kiểu: không ghi được', error_of { CC.write(instance, 'name', 'x') }.to_s.include?('không sửa'))
ok('giá trị có ký tự điều khiển được làm sạch', (CC.write(instance, text_key, "a\u0001b\n"); instance.get_attribute('VGD_BIM_TABLE', text_key) == 'ab'))

puts($fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
