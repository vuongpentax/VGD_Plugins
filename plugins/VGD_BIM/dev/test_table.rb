require 'json'
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_test')
STORE = {}
module Sketchup
  class Group; def initialize(vol); @vol = vol; end; def volume; @vol; end; end
  class ComponentInstance; end
  class Face; end
  def self.read_default(section, key, default = nil); STORE.fetch([section, key], default); end
  def self.write_default(section, key, value); STORE[[section, key]] = value; true; end
end
module VGD; module BIM; def self.log(m); end; module Data; end; module Scanner; end; module Geometry; end; end; end
ROOT = ARGV[0] || File.expand_path('../runtime/vgd_bim_lite', __dir__)
require File.join(ROOT, 'core/locale')
require File.join(ROOT, 'core/schema')
require File.join(ROOT, 'core/tags')
require File.join(ROOT, 'core/table')
T = VGD::BIM::Table
S = VGD::BIM::Schema
def check(label, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{label}"; end
def raises?(msg = nil); yield; false; rescue ArgumentError => e; msg ? e.message.include?(msg) : true; end

keys = T::COLUMN_KEYS
check 'có đủ cột kiểu Auto Info (20 cột, không trùng)', keys.size == 20 && keys.uniq.size == keys.size
check 'mọi cột của preset có sẵn đều hợp lệ', T::BUILT_IN_PRESETS.all? { |p| p['columns'].all? { |c| keys.include?(c) } }
check 'preset có sẵn có nhóm hợp lệ', T::BUILT_IN_PRESETS.all? { |p| p['group'].empty? || VGD::BIM::Tags::GROUPS.include?(p['group']) }
check 'preset có đủ: Tất cả, Phần thô, Hoàn thiện, Đồ rời', T::BUILT_IN_PRESETS.map { |p| p['name'] } == ['Tất cả', 'Phần thô', 'Hoàn thiện', 'Đồ rời']
check 'Phần thô lọc đúng nhóm Phần thô', T::BUILT_IN_PRESETS[1]['group'] == 'Phần thô'
check 'cột giữ đúng thứ tự người dùng sắp xếp khi lưu preset', T.sanitize_preset('name' => 'x', 'group' => '', 'columns' => %w[quantity lenX ordinal])['columns'] == %w[quantity lenX ordinal]
check 'bỏ cột lạ khi lưu preset', T.sanitize_preset('name' => 'x', 'group' => '', 'columns' => %w[lenX abc])['columns'] == %w[lenX]
check 'từ chối preset không có cột', raises? { T.sanitize_preset('name' => 'x', 'group' => '', 'columns' => ['abc']) }
check 'từ chối tên preset rỗng', raises? { T.sanitize_preset('name' => '  ', 'group' => '', 'columns' => %w[lenX]) }
check 'từ chối tên preset quá 40 ký tự', raises? { T.sanitize_preset('name' => 'a' * 41, 'group' => '', 'columns' => %w[lenX]) }
check 'từ chối nhóm preset lạ', raises? { T.sanitize_preset('name' => 'x', 'group' => 'Lạ', 'columns' => %w[lenX]) }
check 'không lưu được preset trùng tên có sẵn', raises?('trùng') { T.save_preset('Phần thô', 'Phần thô', %w[lenX]) }
T.save_preset('Vách kính', 'Hoàn thiện', %w[instance areaFace quantity])
check 'lưu preset riêng rồi đọc lại được', T.custom_presets.map { |p| p['name'] } == ['Vách kính']
check 'danh sách preset có cả preset có sẵn và preset đã lưu', T.presets.size == 5 && T.presets.last['builtin'] == false
T.save_preset('Vách kính', 'Đồ rời', %w[instance quantity])
check 'lưu trùng tên thì ghi đè, không nhân đôi', T.custom_presets.size == 1 && T.custom_presets.first['group'] == 'Đồ rời'
T.delete_preset('Vách kính')
check 'xóa preset đã lưu', T.custom_presets.empty?

S_ok = S.normalize('status' => 'existing')
check 'trạng thái Hiện hữu được chấp nhận', S_ok[:status] == 'existing'
check 'trạng thái rỗng được chấp nhận (nghĩa là Mới)', S.normalize('status' => '')[:status] == ''
check 'trạng thái lạ bị từ chối', raises? { S.normalize('status' => 'bogus') }
check 'bộ 5 trạng thái đúng thứ tự', S::STATUSES == %w[new existing reuse temporary removed]
check 'nhãn 5 trạng thái đều có tiếng Việt', T::STATUS_LABELS.values == ['Mới', 'Hiện hữu', 'Dùng lại', 'Tạm thời', 'Loại bỏ']

# Thể tích: 1 ft³ = 1728 in³ = 0.0283168 m³ (nhân hệ số vị trí 1 nếu không phóng to)
identity = Struct.new(:xaxis, :yaxis, :zaxis).new(Struct.new(:length).new(1.0), Struct.new(:length).new(1.0), Struct.new(:length).new(1.0))
vol = T.solid_volume(Sketchup::Group.new(1728.0), identity)
check 'thể tích khối 1 ft³ ≈ 0.0283 m³', (vol - 0.0283).abs < 0.0001
check 'khối không kín (âm) để trống thể tích', T.solid_volume(Sketchup::Group.new(-5.0), identity).nil?
check 'component không có thể tích (để trống)', T.solid_volume(Sketchup::ComponentInstance.new, identity).nil?
puts "Done"

# Lưu ra file JSON: tên có dấu và dấu ngoặc kép vẫn đọc lại đúng (lỗi preset biến mất ở beta 2).
T.save_preset('Tủ "bếp" trên', 'Đồ rời', %w[instance quantity])
check 'preset có dấu và ngoặc kép lưu rồi đọc lại đúng', T.custom_presets.map { |p| p['name'] } == ['Tủ "bếp" trên']
check 'preset nằm trong file JSON trên máy', File.exist?(File.join(ENV['VGD_BIM_DATA_DIR'], 'table_presets.json'))
T.delete_preset('Tủ "bếp" trên')
T.save_view_state('preset' => 'Đồ rời', 'order' => %w[quantity abc lenX], 'visible' => %w[quantity], 'widths' => {'lenX' => 90, 'zzz' => 5}, 'hack' => 1)
v = T.view_state
check 'trạng thái bảng lưu và đọc lại, bỏ cột lạ', v['preset'] == 'Đồ rời' && v['order'] == %w[quantity lenX] && v['widths'] == {'lenX' => 90} && !v.key?('hack')
puts 'Done'
