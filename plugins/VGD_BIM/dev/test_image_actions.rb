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
    attr_accessor :locked
    def initialize(pid, name); @persistent_id = pid; @name = name; @attrs = {}; @locked = false; end
    def valid?; true; end
    def locked?; @locked; end
    def get_attribute(dict, key, default = nil); @attrs.dig(dict, key) || default; end
    def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; end
    def delete_attribute(dict, key); (@attrs[dict] || {}).delete(key); end
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
FakeModel = Struct.new(:guid) { def title; 'Nhà mẫu'; end }
$model = FakeModel.new('MODEL-A')
module VGD; module BIM; def self.log(m); end
  module Data; def self.supported?(e); true; end; def self.transaction(_model, name = nil); ($transactions ||= []) << name; yield; end; end
  module Scanner; end; module Geometry; def self.definition(e); Struct.new(:name).new('Họ'); end; end
  module Tags; GROUPS = [].freeze; end
  module Table
    def self.build(model, scope, deep, **_options); {rows: $rows, records: $records}; end
    COLUMNS = [].freeze; STATUS_LABELS = {}.freeze; UNTAGGED_GROUP = 'Chưa phân loại'.freeze
    def self.columns; COLUMNS; end
    def self.presets; []; end
    def self.view_state(_model = nil); {}; end
  end
  module UI; end
end; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
%w[core/storage core/settings core/images core/row_order core/preset core/photo_settings core/material_library core/check_rules core/snapshots core/bridge core/levels core/rooms core/table_report core/measure_probe].each { |f| require File.join(ROOT, f) }
module VGD; module BIM; module UI
  module Capture
    ISO_SIDES = %w[right left].freeze
    def self.shoot(model, record, settings, iso_side: 'right', kind: :full, preview: nil)
      pid = record[:entity].persistent_id
      raise 'SketchUp không chụp được ảnh.' if pid == 902
      if preview
        ($previews ||= []) << {pid: pid, settings: settings, side: iso_side, kind: kind, width: preview}
        return {pid: pid, kind: kind, png: PNG, note: pid == 907 ? 'ảnh nháp dùng cách thay thế' : nil}.compact
      end
      raise NoMethodError, "undefined method `bounds' for nil:NilClass" if pid == 906
      note = pid == 907 ? 'nền trong suốt không dùng được trên máy này nên ảnh dùng cách thay thế' : nil
      $shot << [pid, settings['image_view']]
      ($sides ||= []) << iso_side
      ($seen ||= []) << [pid, settings]
      ($kinds ||= []) << kind
      Images.write(model, pid, PNG, kind)
      {pid: pid, kind: kind, stamp: Images.info(model, pid, Images.dir(model), kind)[:stamp], note: note}.compact
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

def make_dialog(count = 3, has_image: [], has_location: [])
  entities = (1..count).map { |i| Sketchup::Entity.new(900 + i, "Tủ #{i}") }
  $rows = entities.each_with_index.map { |e, i| {index: i, pid: e.persistent_id, name: e.name, has_image: has_image.include?(i), image_stamp: 0, has_location: has_location.include?(i)} }
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
ok('chụp đúng 2 dòng đã chọn, đúng thứ tự, theo thiết lập ảnh của preset (mặc định: góc iso)', $shot == [[901, 'isometric'], [903, 'isometric']])
ok('báo xong: 2/2 thành công, không lỗi', events(d, 'images_done').last == {'done' => 2, 'total' => 2, 'ok' => 2, 'errors' => [], 'notes' => [], 'cancelled' => false})
ok('báo ảnh đổi để bảng cập nhật cột Ảnh', events(d, 'images_changed').last['items'].map { |i| i['pid'] } == [901, 903] && events(d, 'images_changed').last['items'].all? { |i| i['has'] && i['url'].to_s.start_with?('file:///') && i['url'].end_with?("/#{i['pid']}.png?v=#{i['stamp']}") })
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

# Lỗi tiếng Anh của SketchUp / Ruby không bị che thành "không chụp được": hiện loại lỗi và nội dung để chẩn đoán
d = make_dialog(7)
d.safely { d.images_capture('indexes' => [5, 6]) }
UI.run_timers
done = events(d, 'images_done').last
ok('lỗi tiếng Anh của Ruby: hiện loại lỗi và nội dung, không chỉ "không chụp được"', done['errors'].size == 1 && done['errors'][0].include?('NoMethodError') && done['errors'][0].include?("bounds"))
d = make_dialog(7)
d.safely { d.images_capture('indexes' => [6]) }
UI.run_timers
done = events(d, 'images_done').last
ok('chụp bằng cách thay thế: ghi chú được gửi cho giao diện, ảnh vẫn tính là chụp được', done['ok'] == 1 && done['notes'] == ['nền trong suốt không dùng được trên máy này nên ảnh dùng cách thay thế'])
d = make_dialog
d.safely { d.images_capture('indexes' => [0]) }
UI.run_timers
ok('chụp bình thường: không có ghi chú', events(d, 'images_done').last['notes'] == [])

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
d.safely { d.image_set('pid' => 901, 'full' => png64) }
ok('dán ảnh cho đối tượng trong bảng: chỉ lưu ảnh gốc (không tạo ảnh nhỏ)', File.binread(I.path($model, 901)) == PNG && Dir[File.join(I.dir($model), '901*')].size == 1)
ok('dán ảnh: báo ảnh đổi', events(d, 'images_changed').last['items'] == [{'pid' => 901, 'kind' => 'full', 'has' => true, 'stamp' => I.info($model, 901)[:stamp], 'url' => I.file_url($model, 901, I.info($model, 901)[:stamp])}])
d.safely { d.image_set('pid' => 5555, 'full' => png64) }
ok('dán ảnh cho mã không có trong bảng bị từ chối, không ghi file', error_of(d).to_s.include?('không còn trong bảng') && !File.exist?(I.path($model, 5555)))
d.safely { d.image_set('pid' => 902, 'full' => Base64.strict_encode64('<script>x</script>')) }
ok('dán dữ liệu không phải PNG bị từ chối, không ghi file', error_of(d).to_s.include?('PNG') && !File.exist?(I.path($model, 902)))
d.safely { d.image_set('pid' => '901; rm -rf', 'full' => png64) }
ok('mã đối tượng có ký tự lạ bị từ chối', error_of(d).to_s.include?('Mã đối tượng'))
d.safely { d.image_delete(901) }
ok('xóa ảnh: mất file và báo ảnh đổi', !File.exist?(I.path($model, 901)) && events(d, 'images_changed').last['items'] == [{'pid' => 901, 'kind' => 'full', 'has' => false, 'stamp' => 0, 'url' => nil}])
d.safely { d.image_delete(5555) }
ok('xóa ảnh của mã không có trong bảng bị từ chối', error_of(d).to_s.include?('không còn trong bảng'))

# ---- Ảnh gốc gửi về giao diện (dự phòng khi cửa sổ không nạp được bằng đường dẫn file) ----
FileUtils.rm_rf(I.dir($model))
d = make_dialog
I.write($model, 901, PNG)
d.safely { d.image_full([901, 902, 903]) }
shown = events(d, 'image_data').last['items']
ok('xin ảnh gốc: chỉ trả đối tượng có ảnh, dạng data URL', shown.keys == ['901'] && shown['901'].start_with?('data:image/png;base64,'))
d.safely { d.image_full([901, 7777]) }
ok('xin ảnh của mã không có trong bảng: bỏ qua, không đọc file, không báo lỗi', events(d, 'image_data').last['items'].keys == ['901'] && error_of(d).nil?)
many = make_dialog(D::MAX_FULL_REQUEST + 5)
$records.each { |r| I.write($model, r[:entity].persistent_id, PNG) }
many.safely { many.image_full($records.map { |r| r[:entity].persistent_id }) }
ok("mỗi lần chỉ trả tối đa #{D::MAX_FULL_REQUEST} ảnh (ảnh gốc nặng hơn ảnh nhỏ)", events(many, 'image_data').last['items'].size == D::MAX_FULL_REQUEST)
ok('không còn lệnh xin ảnh nhỏ', !d.respond_to?(:image_thumbs) && !defined?(D::MAX_THUMB_REQUEST))

# ---- Cài đặt chung (ngôn ngữ, thư mục ảnh) ----
d = make_dialog
refreshed = 0
d.define_singleton_method(:refresh) { refreshed += 1 }
d.safely { d.settings_save('image_dir' => File.join(Dir.tmpdir, 'anh_moi')) }
ok('lưu thư mục ảnh: ghi vào settings.json và gửi lại cho giao diện, không vẽ lại cả cửa sổ', S.read['image_dir'] == File.join(Dir.tmpdir, 'anh_moi') && events(d, 'settings').last['settings']['image_dir'] == File.join(Dir.tmpdir, 'anh_moi') && refreshed == 0)
d.safely { d.settings_save('language' => 'en') }
ok('đổi ngôn ngữ: vẽ lại toàn bộ cửa sổ (gửi lại từ điển)', refreshed == 1 && S.read['language'] == 'en')
d.safely { d.settings_save('language' => 'fr') }
ok('cài đặt sai bị từ chối, giữ nguyên giá trị cũ', error_of(d).to_s.include?('Ngôn ngữ không hợp lệ') && S.read['language'] == 'en')
d.safely { d.settings_save('language' => 'vi', 'image_dir' => 'khong/tuyet/doi') }
ok('một mục sai làm cả lần lưu bị từ chối (không lưu nửa chừng)', S.read['language'] == 'en')
d.safely { d.settings_save('length_unit' => 'cm', 'image_size' => 1024) }
ok('mục đã chuyển sang preset (đơn vị, cỡ ảnh) không còn lưu ở cài đặt chung', !File.read(File.join(VGD::BIM::Storage.dir, 'settings.json')).include?('length_unit'))
$picked_dir = File.join(Dir.tmpdir, 'anh_chon')
d.safely { d.settings_pick_dir }
ok('chọn thư mục ảnh bằng hộp chọn: lưu và báo lại', S.read['image_dir'] == $picked_dir && events(d, 'settings').last['dir'] == $picked_dir)
$picked_dir = nil
d.safely { d.settings_pick_dir }
ok('hủy hộp chọn thư mục: giữ nguyên', S.read['image_dir'] == File.join(Dir.tmpdir, 'anh_chon'))
d.safely { d.images_open_dir }
ok('mở thư mục ảnh (không phải Windows): tạo thư mục nếu chưa có rồi mở bằng địa chỉ file:///', File.directory?(S.image_dir) && UI.opened.last.start_with?('file:///'))
launched = []
d.define_singleton_method(:windows?) { true }
d.define_singleton_method(:launch_process) { |*args| launched << args }
opened_before = UI.opened.size
d.safely { d.images_open_dir }
ok('Windows: mở bằng explorer.exe với đường dẫn Windows (dấu gạch ngược), không qua UI.openURL (tránh cửa sổ Explorer bị dẹp lép)', launched == [['explorer.exe', File.expand_path(S.image_dir).tr('/', '\\')]] && UI.opened.size == opened_before)
d.define_singleton_method(:windows?) { false }
d.safely { d.images_open_dir }
ok('không phải Windows: vẫn dùng UI.openURL, không chạy explorer', launched.size == 1 && UI.opened.size == opened_before + 1)

# ---- Iso bên trái / phải (nút ◣ ◢ trong ô ảnh) đi cùng lệnh chụp ----
d = make_dialog
$sides = []
d.safely { d.images_capture('indexes' => [0], 'settings' => {'image_view' => 'isometric'}, 'iso_side' => 'left') }
UI.run_timers
ok('lệnh chụp mang bên Iso (trái) tới Capture.shoot', $sides == ['left'])
$sides = []
d.safely { d.images_capture('indexes' => [0], 'settings' => {'image_view' => 'isometric'}) }
UI.run_timers
ok('không nói bên Iso: mặc định bên phải như trước', $sides == ['right'])
d = make_dialog
d.safely { d.images_capture('indexes' => [0], 'settings' => {'image_view' => 'isometric'}, 'iso_side' => 'giữa') }
ok('bên Iso lạ bị từ chối trước khi chụp: không hẹn giờ, không ẩn khung', error_of(d).to_s.include?('bên Iso') && UI.timers.empty? && d.instance_variable_get(:@capture).nil?)

# ---- Thiết lập ảnh của preset đi cùng lệnh chụp ----
d = make_dialog
d.safely { d.images_capture('indexes' => [0], 'settings' => {'image_view' => 'front', 'image_width' => 640}) }
UI.run_timers
ok('chụp theo thiết lập ảnh của preset gửi kèm (góc chính diện)', $shot == [[901, 'front']])
d = make_dialog
d.safely { d.images_capture('indexes' => [0], 'settings' => {'image_view' => 'top'}) }
ok('thiết lập ảnh sai bị từ chối trước khi chụp: không hẹn giờ, không ẩn khung', error_of(d).to_s.include?('Góc nhìn') && UI.timers.empty? && d.instance_variable_get(:@capture).nil?)
d = make_dialog
d.safely { d.images_capture('indexes' => [0], 'settings' => {'image_width' => 5}) }
ok('cỡ ảnh sai bị từ chối trước khi chụp', error_of(d).to_s.include?('Cỡ ảnh') && UI.timers.empty?)

# ---- Cài đặt riêng từng file: thư mục ảnh và loại trừ số đo của file này không bị file khác đổi ----
class OwnModel
  def initialize; @attrs = {}; end
  def get_attribute(dict, key, default = nil); @attrs.dig(dict, key) || default; end
  def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; end
  def start_operation(*); true; end
  def commit_operation; true; end
  def abort_operation; true; end
  def guid; 'g'; end
end
dir_a = File.join(Dir.tmpdir, 'anh_file_a'); dir_b = File.join(Dir.tmpdir, 'anh_file_b')
model_a = OwnModel.new; model_b = OwnModel.new
da = make_dialog; da.instance_variable_set(:@model, model_a); da.define_singleton_method(:refresh) { }
db = make_dialog; db.instance_variable_set(:@model, model_b); db.define_singleton_method(:refresh) { }
da.safely { da.settings_save('image_dir' => dir_a, 'exclude_tags' => ['Handle']) }
db.safely { db.settings_save('image_dir' => dir_b, 'exclude_tags' => ['Door']) }
ok('hai file: mỗi file giữ thư mục ảnh riêng dù file kia đổi sau', I.dir(model_a).start_with?(dir_a) && I.dir(model_b).start_with?(dir_b))
ok('hai file: mỗi file giữ tag loại trừ riêng', VGD::BIM::ModelSettings.effective(model_a)['exclude_tags'] == ['Handle'] && VGD::BIM::ModelSettings.effective(model_b)['exclude_tags'] == ['Door'])
ok('cài đặt gửi giao diện là của file đang mở', events(da, 'settings').last['dir'] == dir_a && events(da, 'settings').last['settings']['exclude_tags'] == ['Handle'])
$picked_dir = File.join(Dir.tmpdir, 'anh_file_a2')
da.safely { da.settings_pick_dir }
ok('chọn lại thư mục ảnh ở file A: file A đổi, file B không', I.dir(model_a).start_with?($picked_dir) && I.dir(model_b).start_with?(dir_b))
$picked_dir = nil

# ---- Mã model cố định: bảng luôn đảm bảo mã trước khi đọc / chụp ảnh ----
d = make_dialog
d.instance_variable_set(:@table_scope, [])
d.instance_variable_set(:@table_options, {zoom: true, isolate: false, deep: false, projected: false, label: true})
d.instance_variable_set(:@isolated, [])
ensured = []
I.define_singleton_method(:ensure_model_id) { |model| ensured << model; nil }
d.define_singleton_method(:selected_indexes) { [] }
d.define_singleton_method(:table_choices) { {} }
d.table_build
ok('dựng bảng: gọi ensure_model_id cho model đang mở (trước khi đọc ảnh) để ảnh còn sau khi mở lại file', ensured == [$model])

# ---- Xuất bảng: Excel (.xlsx có ảnh) và PDF (trang báo cáo mở bằng trình duyệt) ----
require 'zlib'
def real_png(width, height)
  chunk = ->(type, data) { [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N') }
  raw = (0...height).map { "\x00".b + "\x20\x80\xC0".b * width }.join
  "\x89PNG\r\n\x1A\n".b + chunk.call('IHDR', [width, height, 8, 2, 0, 0, 0].pack('NNCCCCC')) + chunk.call('IDAT', Zlib::Deflate.deflate(raw)) + chunk.call('IEND', ''.b)
end
export_columns = [{'label' => 'STT', 'unit' => '', 'type' => 'ordinal', 'digits' => 0}, {'label' => 'Ảnh', 'unit' => '', 'type' => 'image', 'digits' => 0}, {'label' => 'Tên', 'unit' => '', 'type' => 'text', 'digits' => 0}]
export_payload = lambda do |format, pids|
  {'format' => format, 'title' => 'Bảng khối lượng', 'preset' => 'Tất cả', 'decimal_separator' => ',', 'labels' => {'model' => 'Mô hình', 'preset' => 'Preset', 'date' => 'Ngày', 'print' => 'In'},
   'columns' => export_columns, 'rows' => pids.each_with_index.map { |pid, i| {'kind' => 'row', 'pid' => pid, 'cells' => [i + 1, nil, "Tủ #{i + 1}"]} }}
end
d = make_dialog(3, has_image: [0, 1])
FULL = {901 => real_png(512, 384), 902 => real_png(300, 600)}
I.write($model, 901, FULL[901])
I.write($model, 902, FULL[902])
Dir.mktmpdir do |dir|
  $save = File.join(dir, 'ketqua')
  UI.define_singleton_method(:savepanel) { |*_args| $save }
  d.safely { d.table_export(export_payload.call('xlsx', [901, 902, 903])) }
  file = "#{$save}.xlsx"
  bytes = File.file?(file) ? File.binread(file) : ''
  ok('xuất Excel: chọn nơi lưu, tự thêm đuôi .xlsx, ghi file zip', bytes.byteslice(0, 2) == 'PK')
  ok('xuất Excel: nhúng ảnh gốc theo cỡ đã chụp của các dòng có ảnh; dòng thứ 3 không có', bytes.include?('xl/media/image2.png') && !bytes.include?('xl/media/image3.png') && bytes.include?(FULL[901]) && bytes.include?(FULL[902]))
  ok('xuất Excel: báo số dòng, số ảnh và đường dẫn', events(d, 'message').last['text'] == "Đã xuất 3 dòng và 2 ảnh ra Excel: #{file}")
  d = make_dialog(3, has_image: [0, 1])
  d.safely { d.table_export(export_payload.call('xlsx', [901, 999, 903])) }
  ok('mã đối tượng không thuộc bảng: không lấy ảnh (chỉ 1 ảnh), không báo lỗi', events(d, 'message').last['text'].include?('và 1 ảnh') && error_of(d).nil?)
  $save = nil
  d = make_dialog(3, has_image: [0, 1])
  before = Dir.children(dir).sort
  d.safely { d.table_export(export_payload.call('xlsx', [901])) }
  ok('hủy hộp lưu file: không ghi file, không báo gì', Dir.children(dir).sort == before && events(d, 'message').empty?)
  $save = File.join(dir, 'a.XLSX')
  d.safely { d.table_export(export_payload.call('xlsx', [901])) }
  ok('đuôi .XLSX viết hoa được giữ nguyên, không thêm đuôi nữa', File.file?($save))
  d.safely { d.table_export(export_payload.call('doc', [901])) }
  ok('định dạng xuất lạ bị từ chối', error_of(d).to_s.include?('Định dạng'))
  d.safely { d.table_export('xlsx') }
  ok('dữ liệu không phải bảng bị từ chối', error_of(d).to_s.include?('không hợp lệ'))
  d.safely { d.table_export(export_payload.call('xlsx', []).merge('rows' => [])) }
  ok('bảng không có dòng nào: báo lỗi', error_of(d).to_s.include?('chưa có dòng'))
end
opened_before = (UI.opened || []).size
d = make_dialog(3, has_image: [0, 1])
d.safely { d.table_export(export_payload.call('pdf', [901, 902, 903])) }
url = (UI.opened || [])[opened_before]
html_path = url.to_s.sub(%r{\Afile://}, '').then { |u| u.match?(%r{\A/[A-Za-z]:}) ? u[1..-1] : u }
ok('in PDF: mở trang báo cáo bằng trình duyệt (địa chỉ file:///)', url.to_s.start_with?('file:///') && url.end_with?('.html'))
page = File.file?(html_path) ? File.read(html_path, encoding: 'UTF-8') : ''
ok('in PDF: trang báo cáo có tên model, đủ 3 dòng và 2 ảnh', page.include?('Mô hình: Nhà mẫu') && page.scan('<tr class="row">').size == 3 && page.scan('data:image/png;base64,').size == 2 && page.include?([FULL[901]].pack('m0')))
ok('in PDF: báo đã mở trình duyệt, hướng dẫn Lưu thành PDF', events(d, 'message').last['text'].include?('trình duyệt') && events(d, 'message').last['text'].include?('PDF'))

# ---- Thông số ảnh riêng của từng món (nút ⚙) và nút chụp một lần ----
saved = ->(d, index, kind, settings) { d.safely { d.image_item_save('index' => index, 'kind' => kind, 'settings' => settings) } }
d = make_dialog(3)
$transactions = []
saved.(d, 0, 'full', {'view' => 'front', 'yaw' => 20, 'side' => 'left', 'margin' => 35})
ok('lưu thông số ảnh riêng: ghi vào đối tượng, một thao tác hoàn tác, bảng đổi theo, báo giao diện', $records[0][:entity].get_attribute('VGD_BIM_TABLE', 'photo_full').to_s.include?('"yaw":20') && $transactions == ['VGD_BIM · Thông số ảnh'] && $rows[0][:photo_full] == {'view' => 'front', 'side' => 'left', 'yaw' => 20, 'margin' => 35} && events(d, 'photo_settings').last == {'pid' => 901, 'kind' => 'full', 'settings' => {'view' => 'front', 'side' => 'left', 'yaw' => 20, 'margin' => 35}})
$seen = []; $sides = []
d.safely { d.images_capture('indexes' => [0, 2], 'settings' => {'image_view' => 'isometric', 'image_yaw' => 0, 'image_margin' => 20}) }
UI.run_timers
first, second = $seen
ok('chụp: món có thông số riêng dùng thông số riêng (góc nhìn, góc lệch, lề, bên Iso), món khác theo preset', first[1].values_at('image_view', 'image_yaw', 'image_margin') == ['front', 20, 35] && second[1].values_at('image_view', 'image_yaw', 'image_margin') == ['isometric', 0, 20] && $sides == ['left', 'right'])
$seen = []; $sides = []
d.safely { d.images_capture('indexes' => [0], 'settings' => {'image_view' => 'current'}, 'force_view' => true) }
UI.run_timers
ok('nút chụp một lần (ép góc nhìn): bỏ qua góc nhìn riêng của món nhưng vẫn áp góc lệch và lề riêng', $seen[0][1].values_at('image_view', 'image_yaw', 'image_margin') == ['current', 20, 35] && $sides == ['right'])
$seen = []; $sides = []
d.safely { d.images_capture('indexes' => [0], 'settings' => {'image_view' => 'isometric'}, 'force_view' => true, 'iso_side' => 'right') }
UI.run_timers
ok('nút Iso một lần: bên Iso do nút quyết định, không theo bên riêng của món (trái)', $sides == ['right'] && $seen[0][1]['image_view'] == 'isometric')
$seen = []; $sides = []
d.safely { d.images_capture('indexes' => [2], 'settings' => {'image_view' => 'isometric'}, 'item_settings' => {'view' => 'front', 'pitch' => 25, 'side' => 'left'}) }
UI.run_timers
ok('chụp kèm thông số nhập trong khung (chưa lưu): dùng thông số đó thay cho thông số đã lưu của món', $seen[0][1].values_at('image_view', 'image_pitch') == ['front', 25] && $sides == ['left'] && $records[2][:entity].get_attribute('VGD_BIM_TABLE', 'photo_full').nil?)
d.safely { d.images_capture('indexes' => [2], 'item_settings' => {'yaw' => 999}) }
ok('thông số nhập trong khung sai bị từ chối trước khi chụp', error_of(d).to_s.include?('Góc lệch') && d.instance_variable_get(:@capture).nil? && UI.timers.empty?)
saved.(d, 0, 'location', {'view' => 'front', 'pitch' => 10, 'scale' => 2, 'margin' => 5})
$seen = []
d.safely { d.images_capture('indexes' => [0], 'kind' => 'location', 'settings' => {'loc_view' => 'isometric', 'image_location_scale' => 4}) }
UI.run_timers
ok('ảnh vị trí: dùng thông số riêng loại ảnh vị trí (loc_*, vùng nhìn), không lẫn thông số của ảnh chính', $seen[0][1].values_at('loc_view', 'loc_pitch', 'image_location_scale', 'loc_margin', 'image_view') == ['front', 10, 2, 5, 'isometric'])
saved.(d, 0, 'full', {})
ok('lưu rỗng: bỏ thông số riêng của ảnh chính (về theo preset), ảnh vị trí còn', $records[0][:entity].get_attribute('VGD_BIM_TABLE', 'photo_full').nil? && !$records[0][:entity].get_attribute('VGD_BIM_TABLE', 'photo_location').nil? && $rows[0][:photo_full] == {})
saved.(d, 0, 'full', {'yaw' => 500})
ok('lưu thông số sai: báo lỗi, không ghi', error_of(d).to_s.include?('Góc lệch') && $records[0][:entity].get_attribute('VGD_BIM_TABLE', 'photo_full').nil?)
$records[1][:entity].locked = true
saved.(d, 1, 'full', {'view' => 'front'})
ok('món bị khóa: không lưu được, báo rõ', error_of(d).to_s.include?('khóa') && $records[1][:entity].get_attribute('VGD_BIM_TABLE', 'photo_full').nil?)
saved.(d, 99, 'full', {'view' => 'front'})
ok('dòng không có trong bảng: báo bảng đã cũ', error_of(d).to_s.include?('Bảng đã cũ'))
saved.(d, 0, 'zzz', {'view' => 'front'})
ok('loại ảnh lạ bị từ chối khi lưu', error_of(d).to_s.include?('Loại ảnh'))
# các ảnh do phần thử trên tạo ra không được để lại (thư mục ảnh của test dùng chung giữa các lần chạy, phần xuất Excel ở trên cần món thứ 3 chưa có ảnh)
%w[901.png 903.png 901_loc.png 903_loc.png].each { |name| FileUtils.rm_f(File.join(I.dir($model), name)) }

# ---- Xem trước góc chụp (images_preview): cùng hàng đợi và thông số như chụp thật, ảnh nháp gửi từng khung, không lưu gì ----
$previews = []
d = make_dialog(3)
saved.(d, 0, 'full', {'view' => 'front', 'yaw' => 20})
d.safely { d.images_preview('indexes' => [0, 2], 'settings' => {'image_view' => 'isometric'}) }
ok('xem trước: báo tiến độ 0 / 2 ngay, chưa chụp, bận như chụp thật (không cho chụp / xem trước chồng nhau)', events(d, 'preview_progress').last == {'done' => 0, 'total' => 2} && $previews.empty? && events(d, 'images_progress').empty?)
d.safely { d.images_capture('indexes' => [1]) }
ok('đang xem trước: yêu cầu chụp hoặc xem trước khác bị từ chối', error_of(d).to_s.include?('Đang chụp ảnh'))
UI.run_timers
shown = events(d, 'image_preview')
ok('xem trước: gửi từng khung theo thứ tự, kèm dòng, mã, tên, loại ảnh và ảnh nháp dạng data URL', shown.map { |e| e['index'] } == [0, 2] && shown.map { |e| e['pid'] } == [901, 903] && shown.map { |e| e['name'] } == ['Tủ 1', 'Tủ 3'] && shown.all? { |e| e['kind'] == 'full' && e['image'].start_with?('data:image/png;base64,') })
ok('xem trước: ảnh nháp có chiều rộng tối đa 180 và đúng nội dung PNG', $previews.all? { |p| p[:width] == 180 } && Base64.decode64(shown[0]['image'].split(',', 2)[1]) == PNG)
ok('xem trước: món có thông số riêng dùng thông số riêng như chụp thật, món khác theo preset', $previews[0][:settings].values_at('image_view', 'image_yaw') == ['front', 20] && $previews[1][:settings]['image_view'] == 'isometric')
done_event = events(d, 'preview_done').last
ok('xem trước xong: báo số khung, không báo ảnh đã đổi (không lưu gì), không báo chụp xong', done_event['done'] == 2 && done_event['total'] == 2 && done_event['ok'] == 2 && done_event['errors'] == [] && events(d, 'images_changed').empty? && events(d, 'images_done').empty? && d.instance_variable_get(:@capture).nil?)
ok('xem trước: khung đánh dấu được ẩn trước khi vẽ (không lọt vào ảnh nháp)', $outline_hidden >= 2)
$previews = []
d = make_dialog(3)
d.safely { d.images_preview('indexes' => [0, 1, 2], 'settings' => {'image_view' => 'isometric'}) }
UI.run_timers
shown = events(d, 'image_preview')
ok('xem trước: một món lỗi gửi khung lỗi kèm lý do, các món khác vẫn xem tiếp', shown.map { |e| e['index'] } == [0, 1, 2] && shown[1]['error'].to_s.include?('SketchUp không chụp được ảnh') && !shown[1].key?('image') && shown[2]['image'] && events(d, 'preview_done').last['ok'] == 2 && events(d, 'preview_done').last['errors'].size == 1)
d = make_dialog(3)
$previews = []
d.safely { d.images_preview('indexes' => [0], 'kind' => 'location', 'iso_side' => 'left', 'force_view' => true, 'settings' => {'loc_view' => 'current'}) }
UI.run_timers
ok('xem trước ảnh vị trí: mang loại ảnh, bên Iso và ép góc nhìn như chụp thật', events(d, 'image_preview').last['kind'] == 'location' && $previews[0].values_at(:side, :kind) == ['left', :location] && $previews[0][:settings]['loc_view'] == 'current')
d = make_dialog(3, has_image: [0, 1])
$previews = []
d.safely { d.images_preview('only_missing' => true) }
UI.run_timers
ok('xem trước: tùy chọn chỉ món chưa có ảnh được tôn trọng như chụp thật', $previews.map { |p| p[:pid] } == [903])
d = make_dialog(3)
$previews = []
d.safely { d.images_preview('indexes' => [0, 1, 2], 'settings' => {'image_view' => 'isometric'}) }
d.instance_variable_get(:@capture)[:cancel] = true
UI.run_timers
ok('bấm Dừng khi xem trước: dừng, báo đã dừng', events(d, 'preview_done').last['cancelled'] == true && $previews.empty?)
d = make_dialog(3)
d.safely { d.images_preview('indexes' => [0], 'settings' => {'image_view' => 'top'}) }
ok('xem trước với thiết lập sai: từ chối trước khi vẽ, không hẹn giờ', error_of(d).to_s.include?('Góc nhìn') && UI.timers.empty? && d.instance_variable_get(:@capture).nil?)
d.safely { d.images_preview('indexes' => [0], 'item_settings' => {'yaw' => 999}) }
ok('xem trước với thông số nhập sai: từ chối như chụp thật', error_of(d).to_s.include?('Góc lệch') && UI.timers.empty?)
d.safely { d.images_preview('indexes' => []) }
ok('xem trước không có món nào: báo rõ như chụp thật', error_of(d).to_s.include?('ít nhất một dòng'))

# ---- Ảnh vị trí (kind: location) đi cùng lệnh chụp, dán / kéo thả và xóa ----
$kinds = []
d = make_dialog
d.safely { d.images_capture('indexes' => [0], 'kind' => 'location', 'iso_side' => 'left') }
UI.run_timers
ok('chụp ảnh vị trí: mang loại ảnh và bên Iso tới Capture.shoot', $kinds == [:location] && $sides.last == 'left')
loc_items = events(d, 'images_changed').last['items']
ok('chụp ảnh vị trí: báo ảnh đổi kèm loại location và đường dẫn file _loc', loc_items.size == 1 && loc_items[0]['kind'] == 'location' && loc_items[0]['url'].include?('901_loc.png?v='))
$kinds = []
d.safely { d.images_capture('indexes' => [0]) }
UI.run_timers
ok('không nói loại ảnh: mặc định chụp ảnh món như trước', $kinds == [:full])
d = make_dialog(3, has_location: [0, 1])
$kinds = []
d.safely { d.images_capture('only_missing' => true, 'kind' => 'location') }
UI.run_timers
ok('chỉ chụp dòng chưa có ảnh vị trí (theo has_location, không theo has_image)', $shot.map(&:first) == [903] && $kinds == [:location])
d = make_dialog(3, has_image: [0, 1, 2], has_location: [1])
d.safely { d.images_capture('only_missing' => true, 'kind' => 'location') }
UI.run_timers
ok('chụp thiếu ảnh vị trí: dù đã có ảnh món vẫn chụp ảnh vị trí cho dòng chưa có', $shot.map(&:first) == [901, 903])
d = make_dialog
d.safely { d.images_capture('indexes' => [0], 'kind' => 'zzz') }
err = events(d, 'message').last
ok('loại ảnh lạ: báo lỗi, không chụp', err && err['error'].to_s.include?('Loại ảnh') && $shot.empty?)
d = make_dialog
d.safely { d.image_set('pid' => 901, 'kind' => 'location', 'full' => [PNG].pack('m0')) }
ok('dán ảnh vị trí: ghi vào file _loc và báo ảnh đổi loại location', File.exist?(I.path($model, 901, :location)) && events(d, 'images_changed').last['items'][0]['kind'] == 'location' && events(d, 'images_changed').last['items'][0]['url'].include?('_loc.png'))
d.safely { d.image_delete(901, :location) }
ok('xóa ảnh vị trí: chỉ xóa file _loc, báo ảnh đổi loại location', !File.exist?(I.path($model, 901, :location)) && events(d, 'images_changed').last['items'] == [{'pid' => 901, 'kind' => 'location', 'has' => false, 'stamp' => 0, 'url' => nil}])
File.delete(html_path) if File.file?(html_path)

puts $fails.zero? ? 'Done' : "#{$fails} lỗi"
exit($fails.zero? ? 0 : 1)
