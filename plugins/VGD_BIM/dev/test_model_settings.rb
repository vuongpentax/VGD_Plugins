# Cài đặt riêng từng file SketchUp (core/model_settings.rb): thư mục ảnh, loại trừ số đo, trạng thái bảng không lẫn giữa các file.
# Chạy: ruby dev/test_model_settings.rb
require 'tmpdir'
Dir.mktmpdir do |dir|
  ENV['VGD_BIM_DATA_DIR'] = dir
  require_relative '../runtime/vgd_bim/core/storage'
  require_relative '../runtime/vgd_bim/core/measure'
  require_relative '../runtime/vgd_bim/core/model_settings'
  $fails = 0
  def ok(name, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{name}"; $fails += 1 unless cond; end
  MS = VGD::BIM::ModelSettings
  S = VGD::BIM::Settings
  class FakeModel
    attr_reader :ops, :attrs
    def initialize; @attrs = {}; @ops = []; end
    def get_attribute(d, k, default = nil); @attrs.dig(d, k) || default; end
    def set_attribute(d, k, v); (@attrs[d] ||= {})[k] = v; end
    def start_operation(*); @ops << :start; end
    def commit_operation; @ops << :commit; end
    def abort_operation; @ops << :abort; end
  end
  def raises?(&b); b.call; nil; rescue ArgumentError => e; e.message; end
  a = FakeModel.new
  b = FakeModel.new
  default_dir = S.image_dir
  ok('chưa có cài đặt riêng: đọc ra rỗng, thư mục ảnh theo cài đặt chung', MS.read(a) == {} && MS.image_dir(a) == default_dir)
  ok('model không hỗ trợ (nil): không lỗi', MS.read(nil) == {} && MS.write(nil, 'image_dir' => 'C:\\X') == false && MS.image_dir(nil) == default_dir)

  MS.write(a, 'image_dir' => 'C:\\Anh\\FileA', 'exclude_tags' => ['Handle'])
  S.update('image_dir' => 'C:\\Anh\\FileMoi', 'exclude_tags' => ['Other'], 'exclude_words' => 'knob')
  ok('file A giữ thư mục ảnh và tag loại trừ riêng dù cài đặt chung đã đổi', MS.image_dir(a) == 'C:\\Anh\\FileA' && MS.effective(a)['exclude_tags'] == ['Handle'])
  ok('mục file A chưa đặt thì theo cài đặt chung', MS.effective(a)['exclude_words'] == 'knob')
  ok('file B (chưa đặt gì) theo cài đặt chung mới', MS.image_dir(b) == 'C:\\Anh\\FileMoi' && MS.effective(b)['exclude_tags'] == ['Other'])
  ok('ghi một thao tác trong suốt', a.ops == [:start, :commit])
  MS.write(a, 'image_dir' => 'C:\\Anh\\FileA')
  ok('không đổi gì thì không mở thao tác', a.ops == [:start, :commit])
  ok('thư mục ảnh không phải đường dẫn đầy đủ: từ chối, không ghi', raises? { MS.write(a, 'image_dir' => 'anh') }.to_s.include?('đầy đủ') && MS.image_dir(a) == 'C:\\Anh\\FileA')
  ok('trạng thái bảng không phải Hash: từ chối', raises? { MS.write(a, 'table_view' => 'x') }.to_s.include?('Trạng thái'))
  ok('patch không phải Hash: từ chối', raises? { MS.write(a, []) }.to_s.include?('Cài đặt'))
  ok('mục lạ trong patch bị bỏ qua (không ghi ngôn ngữ vào file)', (MS.write(a, 'language' => 'en'); !MS.read(a).key?('language') && !a.attrs['VGD_BIM_MODEL']['settings'].include?('language')))
  MS.write(a, 'table_view' => {'visible' => %w[instance], 'rowHeight' => 80})
  ok('trạng thái bảng lưu riêng từng file', MS.read(a)['table_view'] == {'visible' => %w[instance], 'rowHeight' => 80} && MS.read(b)['table_view'].nil?)
  MS.write(a, 'image_dir' => '')
  ok('thư mục ảnh rỗng: coi như bỏ, quay về cài đặt chung', !MS.read(a).key?('image_dir') && MS.image_dir(a) == 'C:\\Anh\\FileMoi' && MS.read(a)['table_view'])

  a.set_attribute('VGD_BIM_MODEL', 'settings', '{hỏng')
  ok('dữ liệu hỏng: coi như chưa có', MS.read(a) == {})
  a.set_attribute('VGD_BIM_MODEL', 'settings', JSON.generate('image_dir' => 'abc', 'exclude_tags' => ['T'], 'table_view' => 5))
  ok('mục sai bị bỏ, mục đúng giữ', MS.read(a) == {'exclude_tags' => ['T']})

  # pin: đóng băng cài đặt chung hiện tại vào file chưa có riêng
  c = FakeModel.new
  S.update('image_dir' => 'C:\\Anh\\Chung1', 'exclude_words' => 'tay nam', 'exclude_tags' => [])
  MS.pin(c, {'visible' => %w[description]})
  S.update('image_dir' => 'C:\\Anh\\Chung2', 'exclude_words' => 'khac', 'exclude_tags' => ['X'])
  ok('pin: file C giữ cài đặt lúc mở dù cài đặt chung đổi sau đó', MS.image_dir(c) == 'C:\\Anh\\Chung1' && MS.effective(c)['exclude_words'] == 'tay nam' && MS.effective(c)['exclude_tags'] == [] && MS.read(c)['table_view'] == {'visible' => %w[description]})
  ops = c.ops.size
  MS.pin(c, {'visible' => %w[tag]})
  ok('pin lần hai: file đã có đủ thì không đụng gì', c.ops.size == ops && MS.read(c)['table_view'] == {'visible' => %w[description]})
  puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
  exit($fails.zero? ? 0 : 1)
end
