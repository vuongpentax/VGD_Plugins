# Test phần Cài đặt / Hình ảnh của cửa sổ BIM (UI::ImageActions): chụp theo lô, Dừng, lưu cài đặt, nhận ảnh dán / kéo thả.
# SketchUp, hộp thoại và bộ chụp được giả lập. Chạy: ruby dev/test_image_actions.rb
require 'json'
require 'tmpdir'
require 'base64'
require 'fileutils'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_actions')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end

module Sketchup
  class SelectionObserver; end
  class Entity
    attr_reader :persistent_id, :name
    def initialize(pid, name); @persistent_id = pid; @name = name; end
    def valid?; true; end
  end
  def self.active_model; $model; end
end
module UI
  @timers = []
  class << self
    attr_reader :timers, :opened
    def start_timer(_time, _repeat, &block); @timers << block; @timers.size; end
    def stop_timer(_id); end
    def openURL(url); (@opened ||= []) << url; end
    def select_directory(title:, directory:); $picked_dir; end
    def run_timers; (@timers.shift.call) until @timers.empty?; end
  end
end
FakeModel = Struct.new(:guid)
$model = FakeModel.new('MODEL-A')
module VGD; module BIM; def self.log(m); end
  module Data; def self.supported?(e); true; end; end
  module Scanner; end; module Geometry; def self.definition(e); Struct.new(:name).new('Họ'); end; end
  module Tags; GROUPS = [].freeze; end
  module Table
    def self.build(model, scope, deep); {rows: $rows, records: $records}; end
  end
  module UI; end
end; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
%w[core/storage core/settings core/images].each { |f| require File.join(ROOT, f) }
module VGD; module BIM; module UI
  module Capture
    def self.shoot(model, record, settings)
      pid = record[:entity].persistent_id
      raise 'SketchUp không chụp được ảnh.' if pid == 902
      $shot << [pid, settings['capture_mode']]
      Images.write(model, pid, PNG, PNG)
      {pid: pid, stamp: Images.info(model, pid)[:stamp]}
    end
  end
end; end; end
require File.join(ROOT, 'ui/dialog')
PNG = ("\x89PNG\r\n\x1A\n".b + 'anh'.b).freeze
D = VGD::BIM::UI::Dialog
I = VGD::BIM::Images
S = VGD::BIM::Settings

class FakeDialog
  attr_reader :events
  def initialize; @events = []; end
  def execute_script(script); @events << script; end
  def visible?; true; end
end
def events(d, name); d.instance_variable_get(:@dialog).events.map { |s| JSON.parse(s[/receive\(".*?", (.*)\)\z/m, 1]) if s.include?("receive(\"#{name}\"") }.compact; end

def make_dialog(count = 3, has_image: [])
  entities = (1..count).map { |i| Sketchup::Entity.new(900 + i, "Tủ #{i}") }
  $rows = entities.each_with_index.map { |e, i| {index: i, pid: e.persistent_id, name: e.name, has_image: has_image.include?(i), image_stamp: 0} }
  $records = entities.map { |e| {entity: e, path: [e]} }
  $shot = []
  d = D.allocate
  d.instance_variable_set(:@dialog, FakeDialog.new)
  d.instance_variable_set(:@model, $model)
  d.instance_variable_set(:@mode, 'images')
  d.instance_variable_set(:@table_rows, $rows)
  d.instance_variable_set(:@table_records, $records)
  d.instance_variable_set(:@closed, false)
  $outline_hidden = 0
  d.define_singleton_method(:release_preview) { $outline_hidden += 1 }
  d.define_singleton_method(:hide_overlay) { $outline_hidden += 1 }
  d.define_singleton_method(:show_outline) { $outline_shown = true }
  d.define_singleton_method(:check_model!) { nil }
  d
end
def error_of(d); events(d, 'message').map { |m| m['error'] }.compact.last; end

# ---- Chụp theo lô ----
d = make_dialog
d.safely { d.images_capture('indexes' => [0, 2]) }
ok('bấm chụp: chưa chụp ngay, chỉ hẹn từng nhịp', $shot.empty? && UI.timers.size == 1)
ok('bấm chụp: ẩn khung đánh dấu để khỏi lọt vào ảnh', $outline_hidden == 2)
ok('bấm chụp: báo tiến độ 0/2', events(d, 'images_progress').first == {'done' => 0, 'total' => 2})
UI.run_timers
ok('chụp đúng 2 dòng đã chọn, đúng thứ tự, theo cách chụp trong cài đặt', $shot == [[901, 'isolate'], [903, 'isolate']])
ok('báo xong: 2/2 thành công, không lỗi', events(d, 'images_done').last == {'done' => 2, 'total' => 2, 'ok' => 2, 'errors' => [], 'cancelled' => false})
ok('báo ảnh đổi để bảng cập nhật cột Ảnh', events(d, 'images_changed').last['items'].map { |i| i['pid'] } == [901, 903] && events(d, 'images_changed').last['items'].all? { |i| i['has'] })
ok('chế độ bảng: vẽ lại khung đánh dấu sau khi chụp xong', true) # tab Hình ảnh không có khung; kiểm tra riêng bên dưới
ok('xong thì được chụp lần nữa', (d.safely { d.images_capture('indexes' => [0]) }; UI.run_timers; $shot.size == 3 && $shot.last[0] == 901))

# Đang chụp thì không cho chụp chồng
d = make_dialog
d.safely { d.images_capture('indexes' => [0, 1]) }
d.safely { d.images_capture('indexes' => [2]) }
ok('đang chụp: lần bấm thứ hai bị từ chối', error_of(d).to_s.include?('Đang chụp'))
UI.run_timers

# Lỗi một đối tượng không làm dừng cả lô
d = make_dialog(4)
$records[1] = {entity: Sketchup::Entity.new(902, 'Tủ lỗi'), path: []}
d.safely { d.images_capture({}) }
UI.run_timers
done = events(d, 'images_done').last
ok('không nói indexes: chụp mọi dòng trong bảng', $shot.map(&:first) == [901, 903, 904])
ok('một đối tượng lỗi: các đối tượng khác vẫn chụp, lỗi được báo kèm tên', done['ok'] == 3 && done['total'] == 4 && done['errors'].size == 1 && done['errors'][0].start_with?('Tủ lỗi:'))

# Nút Dừng
d = make_dialog(4)
d.safely { d.images_capture('indexes' => [0, 1, 2, 3]) }
UI.timers.shift.call # chụp xong 1 đối tượng
d.safely { d.instance_variable_get(:@dialog); d.instance_variable_get(:@capture)[:cancel] = true }
UI.run_timers
ok('bấm Dừng: dừng sau đối tượng đang chụp, báo đã dừng', $shot.size == 1 && events(d, 'images_done').last['cancelled'] == true && events(d, 'images_done').last['ok'] == 1)
ok('sau khi dừng không còn trạng thái đang chụp', d.instance_variable_get(:@capture).nil?)

# Đóng cửa sổ giữa chừng
d = make_dialog(3)
d.safely { d.images_capture('indexes' => [0, 1, 2]) }
d.instance_variable_set(:@closed, true)
UI.run_timers
ok('đóng cửa sổ giữa chừng: dừng chụp, không gửi gì về cửa sổ đã đóng', $shot.empty? && events(d, 'images_done').empty? && d.instance_variable_get(:@capture).nil?)

# Đổi sang model khác giữa lúc đang chụp: dừng, không chụp tiếp bằng model cũ
d = make_dialog(3)
d.safely { d.images_capture('indexes' => [0, 1, 2]) }
UI.timers.shift.call # chụp xong đối tượng đầu
$model = FakeModel.new('MODEL-B')
UI.run_timers
done = events(d, 'images_done').last
ok('đổi model giữa chừng: dừng ngay, chỉ chụp đối tượng đã chụp trước đó', $shot.size == 1 && done['done'] == 1 && done['ok'] == 1 && done['errors'].size == 1 && done['errors'][0].include?('Mô hình đã thay đổi'))
ok('đổi model giữa chừng: không còn trạng thái đang chụp', d.instance_variable_get(:@capture).nil?)
$model = FakeModel.new('MODEL-A')

# Chỉ chụp dòng chưa có ảnh, giới hạn lô, dữ liệu sai
d = make_dialog(3, has_image: [1])
d.safely { d.images_capture('only_missing' => true) }
UI.run_timers
ok('chỉ chụp dòng chưa có ảnh', $shot.map(&:first) == [901, 903])
d = make_dialog(2, has_image: [0, 1])
d.safely { d.images_capture('only_missing' => true) }
ok('mọi dòng đã có ảnh: báo không có gì để chụp', error_of(d).to_s.include?('Không có đối tượng'))
d = make_dialog(D::MAX_CAPTURE_BATCH + 1)
d.safely { d.images_capture({}) }
ok("quá #{D::MAX_CAPTURE_BATCH} đối tượng một lần bị từ chối", error_of(d).to_s.include?('tối đa') && UI.timers.empty?)
d = make_dialog
d.safely { d.images_capture('indexes' => [99]) }
ok('dòng không có trong bảng bị từ chối', error_of(d).to_s.include?('Bảng đã cũ') && UI.timers.empty?)
d = make_dialog
d.safely { d.images_capture('indexes' => []) }
ok('không chọn dòng nào bị từ chối', error_of(d).to_s.include?('ít nhất một dòng'))

# Chọn / bỏ chọn khi đang chụp không làm bảng đọc lại
d = make_dialog
d.safely { d.images_capture('indexes' => [0]) }
d.instance_variable_set(:@selection_timer, nil)
timers_before = UI.timers.size
d.selection_changed
ok('đang chụp: sự kiện chọn đối tượng bị bỏ qua', UI.timers.size == timers_before)
UI.run_timers

# ---- Ảnh dán / kéo thả ----
d = make_dialog
png64 = Base64.strict_encode64(PNG)
d.safely { d.image_set('pid' => 901, 'full' => png64, 'thumb' => png64) }
ok('dán ảnh cho đối tượng trong bảng: lưu cả ảnh chính và ảnh nhỏ', File.binread(I.path($model, 901)) == PNG && File.binread(I.path($model, 901, :thumb)) == PNG)
ok('dán ảnh: báo ảnh đổi', events(d, 'images_changed').last['items'] == [{'pid' => 901, 'has' => true, 'stamp' => I.info($model, 901)[:stamp]}])
d.safely { d.image_set('pid' => 5555, 'full' => png64, 'thumb' => png64) }
ok('dán ảnh cho mã không có trong bảng bị từ chối, không ghi file', error_of(d).to_s.include?('không còn trong bảng') && !File.exist?(I.path($model, 5555)))
d.safely { d.image_set('pid' => 902, 'full' => Base64.strict_encode64('<script>x</script>'), 'thumb' => png64) }
ok('dán dữ liệu không phải PNG bị từ chối, không ghi file', error_of(d).to_s.include?('PNG') && !File.exist?(I.path($model, 902)))
d.safely { d.image_set('pid' => '901; rm -rf', 'full' => png64, 'thumb' => png64) }
ok('mã đối tượng có ký tự lạ bị từ chối', error_of(d).to_s.include?('Mã đối tượng'))
d.safely { d.image_delete(901) }
ok('xóa ảnh: mất file và báo ảnh đổi', !File.exist?(I.path($model, 901)) && events(d, 'images_changed').last['items'] == [{'pid' => 901, 'has' => false, 'stamp' => 0}])
d.safely { d.image_delete(5555) }
ok('xóa ảnh của mã không có trong bảng bị từ chối', error_of(d).to_s.include?('không còn trong bảng'))

# ---- Ảnh nhỏ / ảnh lớn gửi về giao diện ----
FileUtils.rm_rf(I.dir($model))
d = make_dialog
I.write($model, 901, PNG, PNG)
d.safely { d.image_thumbs([901, 902, 903]) }
thumbs = events(d, 'thumbs').last['items']
ok('xin ảnh nhỏ: chỉ trả đối tượng có ảnh, dạng data URL', thumbs.keys == ['901'] && thumbs['901'].start_with?('data:image/png;base64,'))
d.safely { d.image_thumbs([901, 7777]) }
ok('xin ảnh nhỏ của mã không có trong bảng: bỏ qua, không đọc file, không báo lỗi', events(d, 'thumbs').last['items'].keys == ['901'] && error_of(d).nil?)
many = make_dialog(D::MAX_THUMB_REQUEST + 5)
$records.each { |r| I.write($model, r[:entity].persistent_id, PNG, PNG) }
many.safely { many.image_thumbs($records.map { |r| r[:entity].persistent_id }) }
ok("mỗi lần chỉ trả tối đa #{D::MAX_THUMB_REQUEST} ảnh nhỏ", events(many, 'thumbs').last['items'].size == D::MAX_THUMB_REQUEST)
d.safely { d.image_full(901) }
ok('xin ảnh lớn: trả data URL của đúng đối tượng', events(d, 'image_full').last['url'].start_with?('data:image/png;base64,') && events(d, 'image_full').last['pid'] == 901)

# ---- Cài đặt ----
d = make_dialog
refreshed = 0
d.define_singleton_method(:refresh) { refreshed += 1 }
d.safely { d.settings_save('length_unit' => 'cm', 'image_size' => 1024) }
ok('lưu cài đặt: ghi vào settings.json và gửi lại cho giao diện', S.read['length_unit'] == 'cm' && S.read['image_size'] == 1024 && events(d, 'settings').last['settings']['length_unit'] == 'cm' && refreshed == 0)
d.safely { d.settings_save('language' => 'en') }
ok('đổi ngôn ngữ: vẽ lại toàn bộ cửa sổ (gửi lại từ điển)', refreshed == 1 && S.read['language'] == 'en')
d.safely { d.settings_save('language' => 'fr') }
ok('cài đặt sai bị từ chối, giữ nguyên giá trị cũ', error_of(d).to_s.include?('Ngôn ngữ không hợp lệ') && S.read['language'] == 'en')
d.safely { d.settings_save('language' => 'vi', 'image_dir' => 'khong/tuyet/doi') }
ok('một mục sai làm cả lần lưu bị từ chối (không lưu nửa chừng)', S.read['language'] == 'en')
$picked_dir = File.join(Dir.tmpdir, 'anh_chon')
d.safely { d.settings_pick_dir }
ok('chọn thư mục ảnh bằng hộp chọn: lưu và báo lại', S.read['image_dir'] == $picked_dir && events(d, 'settings').last['dir'] == $picked_dir)
$picked_dir = nil
d.safely { d.settings_pick_dir }
ok('hủy hộp chọn thư mục: giữ nguyên', S.read['image_dir'] == File.join(Dir.tmpdir, 'anh_chon'))
d.safely { d.images_open_dir }
ok('mở thư mục ảnh: tạo thư mục nếu chưa có rồi mở', File.directory?(S.image_dir) && UI.opened.last.start_with?('file:///'))

puts $fails.zero? ? 'Done' : "#{$fails} lỗi"
exit($fails.zero? ? 0 : 1)
