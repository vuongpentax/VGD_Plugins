# Sheet của bảng khối lượng (core/table.rb: clean_sheets, trạng thái bảng) và gợi ý nhập kiểu Excel (core/model_settings.rb: remember).
# Chạy: ruby dev/test_sheets.rb
require 'tmpdir'
Dir.mktmpdir do |dir|
  ENV['VGD_BIM_DATA_DIR'] = dir
  module Sketchup; class Group; end; class ComponentInstance; end; class Face; end; end
  module VGD; module BIM; def self.log(_); end; module Data; end; module Scanner; end; module Geometry; end; end; end
  root = File.expand_path('../runtime/vgd_bim', __dir__)
  %w[core/storage core/measure core/settings core/locale core/schema core/tags core/preset core/model_settings core/sheet_lock core/table].each { |f| require File.join(root, f) }
  $fails = 0
  def ok(name, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{name}"; $fails += 1 unless cond; end
  T = VGD::BIM::Table
  MS = VGD::BIM::ModelSettings
  SK = Dir.mktmpdir('vgd_bim_skp_sheets')
  class FakeModel
    attr_accessor :path
    def initialize(path = File.join(SK, "m#{rand(1_000_000)}.skp")); @path = path; end
  end
  keys = T.column_keys
  k1, k2, k3 = keys[1], keys[2], keys[3]

  # ---- Làm sạch sheet: dữ liệu sai ----
  ok('không phải mảng: không có sheet', T.clean_sheets(nil) == [] && T.clean_sheets('x') == [] && T.clean_sheets({}) == [])
  ok('mục không phải Hash bị bỏ', T.clean_sheets([1, 'a', nil, {'name' => 'A'}]).map { |s| s['name'] } == ['A'])
  ok('sheet khóa hợp lệ: giữ lock (chuỗi mã bền)', T.clean_sheets([{'name' => 'K', 'lock' => {'items' => [%w[11 21]]}}]).first['lock'] == {'items' => [%w[11 21]]})
  ok('sheet khóa sai: bỏ lock, sheet vẫn giữ', (k = T.clean_sheets([{'name' => 'K2', 'lock' => {'items' => [['x']]}}]).first) && k['name'] == 'K2' && !k.key?('lock'))
  ok('tên rỗng: đặt Sheet<số thứ tự>', T.clean_sheets([{'name' => '  '}, {}]).map { |s| s['name'] } == %w[Sheet1 Sheet2])
  ok('tên dài quá 40 ký tự bị cắt', T.clean_sheets([{'name' => 'x' * 80}]).first['name'].length == T::SHEET_NAME_MAX)
  ok("tối đa #{T::SHEET_LIMIT} sheet", T.clean_sheets(Array.new(50) { |i| {'name' => "S#{i}"} }).size == T::SHEET_LIMIT)
  s = T.clean_sheets([{'name' => 'A', 'visible' => [k1, 'cot_la', k2, k1], 'order' => [k3, 'xx', k1], 'widths' => {k1 => 120, 'cot_la' => 50, k2 => 'rộng', k3 => Float::NAN}}]).first
  ok('cột lạ bị bỏ khỏi cột hiện và thứ tự, không trùng', s['visible'] == [k1, k2] && s['order'] == [k3, k1])
  ok('độ rộng: chỉ cột có thật và là số hợp lệ', s['widths'] == {k1 => 120})
  ok('sắp xếp hợp lệ giữ, hướng lạ về 1', T.clean_sheets([{'sort' => {'key' => k1, 'dir' => -1}}]).first['sort'] == {'key' => k1, 'dir' => -1} && T.clean_sheets([{'sort' => {'key' => k1, 'dir' => 7}}]).first['sort']['dir'] == 1)
  ok('sắp xếp theo cột lạ hoặc sai kiểu: bỏ', !T.clean_sheets([{'sort' => {'key' => 'la', 'dir' => 1}}]).first.key?('sort') && !T.clean_sheets([{'sort' => 'x'}]).first.key?('sort'))
  ok('nhóm theo, nhóm, tìm kiếm sai kiểu bị bỏ; quá dài bị cắt', (r = T.clean_sheets([{'groupBy' => 5, 'group' => [], 'search' => 3}]).first) && !r.key?('groupBy') && !r.key?('group') && !r.key?('search') &&
     T.clean_sheets([{'search' => 'x' * 500}]).first['search'].length == 200)
  ok('merge chỉ nhận true', T.clean_sheets([{'merge' => 'yes'}]).first['merge'] == false && T.clean_sheets([{'merge' => true}]).first['merge'] == true)
  ok('tag loại trừ hợp lệ giữ, trùng và rỗng bị bỏ', T.clean_sheets([{'exclude_tags' => ['Tường', ' Cửa ', 'Tường', '']}]).first['exclude_tags'] == %w[Tường Cửa])
  ok('tag loại trừ sai (không phải chữ): bỏ mục, sheet vẫn còn', (r = T.clean_sheets([{'name' => 'A', 'exclude_tags' => [1, 2]}]).first) && r['name'] == 'A' && !r.key?('exclude_tags'))
  ok('sheet không khai exclude_tags: không có khóa (dùng loại trừ chung)', !T.clean_sheets([{'name' => 'A'}]).first.key?('exclude_tags'))

  # ---- Trạng thái bảng gồm sheet (lưu trong settings.json cạnh file SketchUp) ----
  m = FakeModel.new
  st = {'preset' => 'Tất cả', 'sheets' => [{'name' => 'Tủ', 'visible' => [k1]}, {'name' => 'Rời', 'visible' => [k2], 'exclude_tags' => ['Tường']}], 'sheet' => 1}
  T.save_view_state(st, m)
  v = T.view_state(m)
  ok('lưu và đọc lại: giữ sheet và sheet đang mở', v['sheets'].map { |x| x['name'] } == %w[Tủ Rời] && v['sheet'] == 1 && v['sheets'][1]['exclude_tags'] == ['Tường'])
  ok('sheet nằm trong settings.json cạnh file SketchUp', JSON.parse(File.read(MS.file(m)))['table_view']['sheets'].size == 2)
  T.save_view_state(st.merge('sheet' => 9), m)
  ok('chỉ số sheet ngoài phạm vi: về 0', T.view_state(m)['sheet'] == 0)
  T.save_view_state(st.merge('sheet' => 'x'), m)
  ok('chỉ số sheet sai kiểu: về 0', T.view_state(m)['sheet'] == 0)
  T.save_view_state({'preset' => 'Tất cả', 'sheets' => [1, 2], 'sheet' => 1}, m)
  ok('không còn sheet hợp lệ: bỏ cả sheets và sheet', !T.view_state(m).key?('sheets') && !T.view_state(m).key?('sheet'))
  T.save_view_state({'preset' => 'Tất cả'}, m)
  ok('trạng thái cũ (chưa có sheet) vẫn đọc được', T.view_state(m)['preset'] == 'Tất cả' && !T.view_state(m).key?('sheets'))
  T.save_view_state(st, m)
  ok('file khác (mới) không có sheet của file này', T.view_state(FakeModel.new) == {})
  other = FakeModel.new
  MS.write(other, 'table_view' => {'preset' => 'Tất cả', 'sheets' => [{'name' => 'Riêng'}]})
  ok('file có trạng thái riêng không bị lẫn sheet của file khác', T.view_state(other)['sheets'].map { |x| x['name'] } == ['Riêng'] && T.view_state(m)['sheets'].size == 2)

  # ---- Gợi ý nhập ----
  a = FakeModel.new
  ok('chưa nhập gì: không có gợi ý', (MS.read(a)['suggest'] || {}) == {})
  ok('nhớ một giá trị', MS.remember(a, 'name', 'Tủ bếp dưới') && MS.read(a)['suggest'] == {'name' => ['Tủ bếp dưới']})
  MS.remember(a, 'name', 'Tủ bếp trên')
  MS.remember(a, 'name', 'tủ bếp DƯỚI')
  ok('mới nhất lên đầu, trùng (không phân biệt hoa thường) chỉ giữ bản mới', MS.read(a)['suggest']['name'] == ['tủ bếp DƯỚI', 'Tủ bếp trên'])
  ok('ô rỗng không được nhớ', MS.remember(a, 'name', '  ') == false)
  ok('cột không phải chữ (giá, trạng thái) không được nhớ', MS.remember(a, 'price', '5') == false && MS.remember(a, 'status', 'x') == false && !MS.read(a)['suggest'].key?('price'))
  ok('cột chữ thêm tay được nhớ', MS.remember(a, 'custom_ghi_chu', 'Giao tuần sau') && MS.read(a)['suggest']['custom_ghi_chu'] == ['Giao tuần sau'])
  ok('giá trị dài quá không được nhớ', MS.remember(a, 'description', 'x' * (MS::SUGGEST_MAX_LENGTH + 1)) == false)
  200.times { |i| MS.remember(a, 'description', "Mô tả #{i}") }
  list = MS.read(a)['suggest']['description']
  ok("tối đa #{MS::SUGGEST_PER_FIELD} gợi ý mỗi cột, giữ cái mới nhất", list.size == MS::SUGGEST_PER_FIELD && list.first == 'Mô tả 199')
  ok('gợi ý lưu riêng từng file', MS.read(FakeModel.new)['suggest'].nil?)
  ok('model không hỗ trợ: không lỗi', MS.remember(nil, 'name', 'A') == false)
  bad = MS.clean_suggest({'name' => ['A', 3, nil, '', 'a'], 'hack' => ['x'], 'price' => ['1'], 5 => ['y'], 'owner' => 'x'})
  ok('dữ liệu gợi ý sai: chỉ giữ cột chữ hợp lệ và chuỗi sạch', bad == {'name' => ['A']})
  ok('dữ liệu gợi ý không phải Hash: rỗng', MS.clean_suggest([]) == {} && MS.clean_suggest(nil) == {})
  puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "CÓ #{$fails} LỖI")
  exit($fails.zero? ? 0 : 1)
end
