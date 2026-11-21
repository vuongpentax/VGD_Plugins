# Xuất / nhập preset kèm định nghĩa cột thêm tay (core/preset.rb, core/custom_columns.rb): máy khác tạo lại đúng cột,
# cột đã có đúng định nghĩa thì dùng lại, tệp cũ không gán nhầm sang cột khác. Chạy: ruby dev/test_preset_custom.rb
require 'json'
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_preset_custom')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
module VGD; module BIM; def self.log(_message); end; end; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
%w[measure storage custom_columns preset].each { |f| require File.join(ROOT, "core/#{f}") }
CC = VGD::BIM::CustomColumns
P = VGD::BIM::Preset
BASE = %w[ordinal instance]
GROUPS = ['Cửa']

def reset_machine!(columns = [], next_id = 1)
  CC.save(columns, next_id)
  VGD::BIM::Storage.write('table_presets', [])
end

# Máy A: có hai cột thêm tay và một preset dùng cả hai
reset_machine!([{'key' => 'custom_1', 'label' => 'Xuất xứ', 'kind' => 'attribute', 'dictionary' => 'Pset', 'attribute' => 'Origin'},
                {'key' => 'custom_2', 'label' => 'Ghi chú', 'kind' => 'text'}], 3)
mine = {'name' => 'Của tôi', 'group' => '', 'columns' => ['ordinal', 'custom_1', 'custom_2'], 'headers' => {'custom_1' => 'Nguồn'}, 'settings' => {}}
exported = P.export([mine], CC.read)
item = exported['presets'][0]
ok('xuất: preset có định nghĩa cột thêm tay đi kèm (khóa, nhãn, kiểu, dictionary, thuộc tính)',
   item['custom'].map { |d| d['key'] } == %w[custom_1 custom_2] && item['custom'][0] == {'key' => 'custom_1', 'label' => 'Xuất xứ', 'kind' => 'attribute', 'dictionary' => 'Pset', 'attribute' => 'Origin'})
ok('xuất: không có cột thêm tay thì không có trường custom (tệp cũ không đổi)', P.exported_preset({'name' => 'x', 'group' => '', 'columns' => BASE, 'headers' => {}, 'settings' => {}}, CC.read).key?('custom') == false)
text_json = JSON.parse(JSON.generate(exported))

# Máy B: chưa có cột nào -> nhập tạo cột mới, khóa đổi theo, tiêu đề đổi theo
reset_machine!
VGD::BIM::CustomColumns.save([], 1)
VGD::BIM::Storage.write('table_presets', [])
obj = VGD::BIM::CustomColumns.adopt_from_preset(JSON.parse(JSON.generate(text_json)))
ok('nhập vào máy chưa có cột: tạo đủ hai cột, khóa mới custom_1 và custom_2', obj[1].map { |c| c['key'] } == %w[custom_1 custom_2] && obj[1][0]['label'] == 'Xuất xứ')
preset_out = obj[0]['presets'][0]
ok('nhập: cột của preset được đổi sang khóa trên máy này, tiêu đề đi theo khóa mới', preset_out['columns'] == %w[ordinal custom_1 custom_2] && preset_out['headers'] == {'custom_1' => 'Nguồn'})

# Máy C: đã có đúng định nghĩa ở khóa khác -> dùng lại, không tạo thêm
reset_machine!([{'key' => 'custom_7', 'label' => 'Xuất xứ', 'kind' => 'attribute', 'dictionary' => 'Pset', 'attribute' => 'Origin'}], 8)
obj = CC.adopt_from_preset(JSON.parse(JSON.generate(text_json)))
ok('máy đã có cột đúng định nghĩa: dùng lại cột đó (custom_7), chỉ thêm cột còn thiếu', obj[0]['presets'][0]['columns'] == %w[ordinal custom_7 custom_8] && obj[1].size == 2)

# Máy D: có custom_1 nhưng là cột khác -> không gán nhầm, tạo cột mới
reset_machine!([{'key' => 'custom_1', 'label' => 'Số lượng khác', 'kind' => 'attribute', 'dictionary' => 'Khac', 'attribute' => 'Qty'}], 2)
obj = CC.adopt_from_preset(JSON.parse(JSON.generate(text_json)))
ok('máy có cùng khóa nhưng khác định nghĩa: không gán nhầm, cột cũ giữ nguyên', obj[1].find { |c| c['key'] == 'custom_1' }['label'] == 'Số lượng khác' && obj[0]['presets'][0]['columns'].include?('custom_2') && !obj[0]['presets'][0]['columns'].include?('custom_1'))

# Tệp cũ không có định nghĩa: khóa cột thêm tay bị bỏ, không gán vào cột khác trên máy
legacy = {'format' => 'VGD_BIM_PRESETS', 'version' => 1, 'presets' => [{'name' => 'Cũ', 'group' => '', 'columns' => ['ordinal', 'custom_1'], 'headers' => {}, 'settings' => {}}]}
reset_machine!([{'key' => 'custom_1', 'label' => 'Khác', 'kind' => 'text'}], 2)
obj = CC.adopt_from_preset(legacy)
ok('tệp cũ không có định nghĩa: bỏ khóa custom_1 của tệp, không gán sang cột khác của máy', obj[0]['presets'][0]['columns'] == ['ordinal'])

# Định nghĩa sai trong tệp: từ chối, không lưu gì
reset_machine!
bad = {'format' => 'VGD_BIM_PRESETS', 'version' => 1, 'presets' => [{'name' => 'Lỗi', 'group' => '', 'columns' => ['custom_1'], 'headers' => {}, 'settings' => {}, 'custom' => [{'key' => 'custom_1', 'label' => '', 'kind' => 'attribute'}]}]}
begin
  CC.adopt_from_preset(bad); ok('định nghĩa cột sai: từ chối', false)
rescue ArgumentError
  ok('định nghĩa cột sai: từ chối, máy không đổi', CC.read.empty?)
end

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
