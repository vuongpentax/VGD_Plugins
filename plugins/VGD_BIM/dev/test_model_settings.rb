# Cài đặt riêng từng file SketchUp (core/model_settings.rb): lưu ở settings.json trong thư mục cạnh file SketchUp (bep.skp -> bep_VGD_BIM),
# file mới bắt đầu từ mặc định, file chưa lưu giữ trong phiên rồi ghi ra khi lưu; chuyển dữ liệu cũ (core/legacy_migration.rb).
# Chạy: ruby dev/test_model_settings.rb
require 'tmpdir'
require 'json'
require 'fileutils'
Dir.mktmpdir do |dir|
  ENV['VGD_BIM_DATA_DIR'] = File.join(dir, 'may')
  module VGD; module BIM; def self.log(_); end; end; end
  %w[storage measure settings model_settings images legacy_migration].each { |f| require File.expand_path("../runtime/vgd_bim/core/#{f}", __dir__) }
  $fails = 0
  def ok(name, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{name}"; $fails += 1 unless cond; end
  MS = VGD::BIM::ModelSettings
  S = VGD::BIM::Settings
  LM = VGD::BIM::LegacyMigration
  I = VGD::BIM::Images
  SK = File.join(dir, 'skp')
  FileUtils.mkdir_p(SK)
  # Model giả: path (file SketchUp), thuộc tính (dictionary) và thao tác trong suốt như SketchUp
  class FakeModel
    attr_accessor :path
    attr_reader :ops, :attrs, :guid
    def initialize(path = '', guid = 'GUID-A'); @path = path; @attrs = {}; @ops = []; @guid = guid; end
    def get_attribute(d, k, default = nil); @attrs.dig(d, k) || default; end
    def set_attribute(d, k, v); (@attrs[d] ||= {})[k] = v; end
    def delete_attribute(d, k); (@attrs[d] || {}).delete(k); end
    def start_operation(*); @ops << :start; end
    def commit_operation; @ops << :commit; end
    def abort_operation; @ops << :abort; end
  end
  def raises?(text = nil); yield; false; rescue ArgumentError => e; text ? e.message.downcase.include?(text.downcase) : true; end
  def saved(name); FakeModel.new(File.join(SK, "#{name}.skp")); end

  # ---- Vị trí thư mục ----
  a = saved('bep')
  ok('thư mục nằm cạnh file SketchUp, tên theo file + _VGD_BIM', MS.folder(a) == File.join(SK, 'bep_VGD_BIM') && MS.file(a) == File.join(SK, 'bep_VGD_BIM', 'settings.json'))
  ok('file chưa lưu / model không hỗ trợ: không có thư mục', MS.folder(FakeModel.new('')).nil? && MS.folder(nil).nil? && MS.folder(Object.new).nil? && !MS.saved?(FakeModel.new('')) && MS.saved?(a))
  ok('tên file có dấu, khoảng trắng và nhiều dấu chấm vẫn đúng', MS.folder(FakeModel.new(File.join(SK, 'Phòng khách v2.final.skp'))) == File.join(SK, 'Phòng khách v2.final_VGD_BIM'))

  # ---- File mới: mặc định, không lấy cài đặt chung ----
  S.update('exclude_tags' => ['ChungCu'], 'exclude_words' => 'tu khoa chung', 'image_dir' => 'C:\\Anh\\Chung') # cài đặt chung kiểu cũ (còn nằm trên máy)
  ok('chưa có settings.json: đọc ra rỗng', MS.read(a) == {})
  ok('file mới: tag và từ khóa loại trừ về mặc định, không lấy cài đặt chung đã lưu trên máy', MS.effective(a)['exclude_tags'] == [] && MS.effective(a)['exclude_words'] == S::DEFAULTS['exclude_words'])
  ok('cài đặt gửi giao diện không có thư mục ảnh tự chọn', !MS.effective(a).key?('image_dir') && MS.image_dir(a) == MS.folder(a) && MS.image_dir(FakeModel.new('')).nil?)
  ok('ngôn ngữ và tag ghim vẫn là cài đặt chung của máy', MS.effective(a)['language'] == S.read['language'] && MS.effective(a).key?('pinned_tags'))
  ok('model không hỗ trợ (nil): không lỗi', MS.read(nil) == {} && MS.write(nil, 'exclude_tags' => ['A']) == false)

  # ---- Ghi vào settings.json ----
  ok('chưa ghi gì: chưa có thư mục nào', !File.exist?(MS.folder(a)))
  MS.write(a, 'exclude_tags' => ['Handle'], 'exclude_words' => 'knob', 'table_view' => {'visible' => %w[instance], 'rowHeight' => 80})
  json = JSON.parse(File.read(MS.file(a)))
  ok('ghi cài đặt: tạo thư mục và settings.json cạnh file, có số phiên bản định dạng', json['schema'] == 1 && json['exclude_tags'] == ['Handle'] && json['exclude_words'] == 'knob' && json['table_view']['rowHeight'] == 80)
  ok('đọc lại đúng (cột, tag loại trừ)', MS.read(a)['table_view'] == {'visible' => %w[instance], 'rowHeight' => 80} && MS.effective(a)['exclude_tags'] == ['Handle'])
  ok('không ghi gì vào file SketchUp (không thao tác, không thuộc tính)', a.ops.empty? && a.attrs.empty?)
  before = File.mtime(MS.file(a))
  sleep 0.05
  MS.write(a, 'exclude_tags' => ['Handle'])
  ok('không đổi gì thì không ghi lại file', File.mtime(MS.file(a)) == before)
  ok('không để lại file tạm', Dir.children(MS.folder(a)).none? { |n| n.end_with?('.tmp') })
  ok('mục khác của file giữ nguyên khi ghi một mục', (MS.write(a, 'exclude_words' => 'moi'); MS.read(a)['exclude_tags'] == ['Handle'] && MS.read(a)['table_view']['rowHeight'] == 80))

  # ---- Hai file không lẫn nhau, cài đặt chung đổi không ảnh hưởng ----
  b = saved('phong')
  MS.write(b, 'exclude_tags' => ['Door'])
  S.update('exclude_tags' => ['DoiSau'])
  ok('mỗi file giữ tag loại trừ riêng', MS.effective(a)['exclude_tags'] == ['Handle'] && MS.effective(b)['exclude_tags'] == ['Door'])
  ok('file khác chưa có cài đặt: vẫn mặc định (không theo file A, B hay cài đặt chung)', MS.effective(saved('chua_co'))['exclude_tags'] == [])

  # ---- Gửi sang máy khác: chép thư mục kèm file SketchUp ----
  elsewhere = File.join(dir, 'may_khac'); FileUtils.mkdir_p(elsewhere)
  FileUtils.cp_r(File.join(SK, 'bep_VGD_BIM'), File.join(elsewhere, 'bep_VGD_BIM'))
  received = FakeModel.new(File.join(elsewhere, 'bep.skp'), 'GUID-KHAC')
  ok('chép thư mục sang máy khác (đường dẫn khác): vẫn đủ cột và tag loại trừ', MS.effective(received)['exclude_tags'] == ['Handle'] && MS.read(received)['table_view']['rowHeight'] == 80)
  lonely = FakeModel.new(File.join(elsewhere, 'phong.skp'))
  ok('chỉ gửi file SketchUp, thiếu thư mục: về mặc định, không lỗi', MS.effective(lonely)['exclude_tags'] == [] && MS.read(lonely) == {})

  # ---- Dữ liệu sai ----
  ok('tag loại trừ sai kiểu: từ chối, không ghi', raises?('tag') { MS.write(a, 'exclude_tags' => 'x') } && MS.read(a)['exclude_tags'] == ['Handle'])
  ok('trạng thái bảng không phải Hash: từ chối', raises?('Trạng thái') { MS.write(a, 'table_view' => 'x') })
  ok('patch không phải Hash: từ chối', raises?('Cài đặt') { MS.write(a, []) })
  ok('mục lạ trong patch bị bỏ qua (không ghi ngôn ngữ, thư mục ảnh vào file)', (MS.write(a, 'language' => 'en', 'image_dir' => 'C:\\X'); json = File.read(MS.file(a)); !json.include?('language') && !json.include?('image_dir')))
  File.write(MS.file(a), '{hỏng')
  ok('settings.json hỏng: coi như chưa có, không lỗi', MS.read(a) == {} && MS.effective(a)['exclude_tags'] == [])
  File.write(MS.file(a), JSON.generate('image_dir' => 'abc', 'exclude_tags' => ['T'], 'table_view' => 5, 'suggest' => {'name' => ['A'], 'hack' => ['x']}))
  ok('mục sai bị bỏ, mục đúng giữ (image_dir cũ bị bỏ)', MS.read(a) == {'exclude_tags' => ['T'], 'suggest' => {'name' => ['A']}})
  File.write(MS.file(a), '[1, 2]')
  ok('settings.json không phải Hash: coi như chưa có', MS.read(a) == {})

  # ---- File chưa lưu: giữ trong phiên, ghi ra khi lưu ----
  fresh = FakeModel.new('')
  MS.write(fresh, 'exclude_tags' => ['Rem'], 'table_view' => {'rowHeight' => 60})
  ok('file chưa lưu: ghi được nhưng chưa tạo thư mục nào', MS.effective(fresh)['exclude_tags'] == ['Rem'] && MS.read(fresh)['table_view'] == {'rowHeight' => 60})
  ok('file chưa lưu khác nhau không lẫn nhau', MS.effective(FakeModel.new(''))['exclude_tags'] == [])
  fresh.path = File.join(SK, 'vua_luu.skp')
  ok('lưu file lần đầu rồi dùng lại: cài đặt trong phiên được ghi ra settings.json cạnh file', MS.read(fresh)['exclude_tags'] == ['Rem'] && File.file?(File.join(SK, 'vua_luu_VGD_BIM', 'settings.json')))
  ok('sau khi ghi ra: không còn giữ trong phiên (đọc từ file)', (File.write(MS.file(fresh), JSON.generate('exclude_tags' => ['SuaTay'])); MS.read(fresh)['exclude_tags'] == ['SuaTay']))
  fresh2 = FakeModel.new('')
  MS.write(fresh2, 'exclude_tags' => ['Mất'])
  fresh2.path = File.join(SK, 'phong') + '.skp'
  ok('lưu vào chỗ đã có settings.json của file khác cùng tên: ưu tiên file có sẵn, không đè', MS.read(fresh2)['exclude_tags'] == ['Door'])

  # ---- Gợi ý nhập ----
  g = saved('goi_y')
  ok('nhớ giá trị đã nhập và ghi vào settings.json', MS.remember(g, 'name', 'Tủ bếp dưới') && JSON.parse(File.read(MS.file(g)))['suggest'] == {'name' => ['Tủ bếp dưới']})
  MS.remember(g, 'name', 'Tủ bếp trên'); MS.remember(g, 'name', 'tủ bếp DƯỚI')
  ok('mới nhất lên đầu, trùng chỉ giữ bản mới', MS.read(g)['suggest']['name'] == ['tủ bếp DƯỚI', 'Tủ bếp trên'])
  ok('ô rỗng, cột số, giá trị dài không được nhớ', MS.remember(g, 'name', ' ') == false && MS.remember(g, 'price', '5') == false && MS.remember(g, 'description', 'x' * 121) == false)

  # ---- Chuyển dữ liệu cũ (cài đặt trong file SketchUp + ảnh ở thư mục chung) ----
  old_images = File.join(dir, 'anh_chung'); FileUtils.mkdir_p(File.join(old_images, 'MODEL-ID-CU-0001'))
  File.binwrite(File.join(old_images, 'MODEL-ID-CU-0001', '5.png'), "\x89PNG\r\n\x1A\n".b + 'a'.b)
  File.binwrite(File.join(old_images, 'MODEL-ID-CU-0001', '5_loc.png'), "\x89PNG\r\n\x1A\n".b + 'b'.b)
  File.binwrite(File.join(old_images, 'MODEL-ID-CU-0001', '.preview_5.png'), 'tam')
  legacy = FakeModel.new(File.join(SK, 'cu.skp'))
  legacy.set_attribute('VGD_BIM_MODEL', 'model_id', 'MODEL-ID-CU-0001')
  legacy.set_attribute('VGD_BIM_MODEL', 'settings', JSON.generate('image_dir' => old_images, 'exclude_tags' => ['Cu'], 'exclude_words' => 'tay nam', 'table_view' => {'visible' => %w[tag]}))
  plan = LM.plan(legacy)
  ok('file cũ đã lưu: có kế hoạch chuyển (cài đặt trong SKP và ảnh ở thư mục ảnh riêng của file)', plan && plan[:folder] == File.join(SK, 'cu_VGD_BIM') && plan[:images] == [File.join(old_images, 'MODEL-ID-CU-0001')] && plan[:settings]['exclude_tags'] == ['Cu'])
  ok('chưa đồng ý thì chưa đụng gì: chưa có thư mục, dữ liệu cũ còn nguyên', !File.exist?(plan[:folder]) && legacy.get_attribute('VGD_BIM_MODEL', 'settings') != nil)
  result = LM.run(legacy, plan)
  ok('chuyển: sao chép ảnh (bỏ file nháp), tạo settings.json từ cài đặt cũ', result[:images] == 2 && File.file?(File.join(plan[:folder], 'MODEL-ID-CU-0001', '5.png')) && File.file?(File.join(plan[:folder], 'MODEL-ID-CU-0001', '5_loc.png')) && !File.exist?(File.join(plan[:folder], 'MODEL-ID-CU-0001', '.preview_5.png')) && MS.read(legacy)['exclude_tags'] == ['Cu'] && MS.read(legacy)['table_view'] == {'visible' => %w[tag]})
  ok('chuyển xong: ảnh cũ trong thư mục chung KHÔNG bị xóa', File.file?(File.join(old_images, 'MODEL-ID-CU-0001', '5.png')))
  ok('chuyển xong: cài đặt cũ trong file SketchUp được gỡ (một thao tác trong suốt), ảnh đọc được từ thư mục mới', legacy.get_attribute('VGD_BIM_MODEL', 'settings').nil? && legacy.get_attribute('VGD_BIM_MODEL', 'model_id') == 'MODEL-ID-CU-0001' && legacy.ops == [:start, :commit] && I.info(legacy, 5)[:has])
  ok('chuyển xong rồi thì không hỏi lại', LM.plan(legacy).nil?)
  ok('file chưa lưu: không có kế hoạch chuyển', LM.plan(FakeModel.new('')).nil?)
  ok('file không có dữ liệu cũ: không có kế hoạch', LM.plan(saved('sach')).nil?)
  only_settings = saved('chi_cai_dat')
  only_settings.set_attribute('VGD_BIM_MODEL', 'settings', JSON.generate('exclude_tags' => ['Y']))
  p2 = LM.plan(only_settings)
  ok('chỉ có cài đặt cũ (không ảnh): vẫn chuyển được, settings.json được tạo', p2 && LM.run(only_settings, p2)[:images] == 0 && MS.read(only_settings)['exclude_tags'] == ['Y'])
  empty_old = saved('rong')
  empty_old.set_attribute('VGD_BIM_MODEL', 'settings', '{hỏng')
  ok('cài đặt cũ hỏng và không có ảnh: không có gì để chuyển', LM.plan(empty_old).nil?)
  puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
  exit($fails.zero? ? 0 : 1)
end
