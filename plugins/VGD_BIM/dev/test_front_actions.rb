# Test các lệnh Mặt trước của cửa sổ BIM (UI::FrontActions): phát hiện tự động, đặt tay (hướng, theo hướng nhìn, xoay, đảo), xóa.
# SketchUp, hộp thoại và phép đo được giả lập (FrontProbe.measure trả kết quả dựng sẵn). Chạy: ruby dev/test_front_actions.rb
require 'json'
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_front')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end

module Sketchup
  class SelectionObserver; end
  def self.active_model; $model; end
end
class FakeDefinition
  attr_reader :name
  def initialize(name); @name = name; @attrs = {}; end
  def get_attribute(dict, key, default = nil); @attrs.dig(dict, key) || default; end
  def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; end
  def delete_attribute(dict, key); @attrs[dict]&.delete(key); end
end
class FakeEntity
  attr_reader :definition, :persistent_id
  def initialize(pid, definition, locked: false); @persistent_id = pid; @definition = definition; @locked = locked; end
  def locked?; @locked; end
  def valid?; true; end
end
class FakeModel
  attr_reader :operations
  def initialize; @operations = []; end
  def active_view; :view; end
end
module VGD; module BIM; def self.log(_m); end
  module Data
    def self.supported?(e); true; end
    def self.transaction(model, name = nil); model.operations << name; yield; end
  end
  module Geometry; def self.definition(entity); entity.definition; end; end
  module Scanner; end; module Tags; GROUPS = [].freeze; end
  module Table; def self.world_corners(_r); []; end; end
  module UI; end
end; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
%w[core/storage core/settings core/images core/preset core/front core/front_probe].each { |f| require File.join(ROOT, f) }
require File.join(ROOT, 'ui/dialog')
F = VGD::BIM::Front

$measure = {}
VGD::BIM::FrontProbe.define_singleton_method(:measure) { |_model, record| $measure[record[:entity].persistent_id] }
$camera = {}
VGD::BIM::FrontProbe.define_singleton_method(:camera_direction) { |_view, record| $camera[record[:entity].persistent_id] }

class FakeDialog
  def initialize; @events = []; end
  attr_reader :events
  def execute_script(script); @events << script; end
  def visible?; true; end
end
def events(d, name); d.instance_variable_get(:@dialog).events.map { |s| JSON.parse(s[/receive\(".*?", (.*)\)\z/m, 1]) if s.include?("receive(\"#{name}\"") }.compact; end
def last_text(d); events(d, 'message').last; end

def make(count)
  $model = FakeModel.new
  defs = {}
  records = (1..count).map do |i|
    d = (defs[i] = FakeDefinition.new("Họ #{i}"))
    {entity: FakeEntity.new(100 + i, d), path: [nil], locked: false}
  end
  records.each { |r| r[:path] = [r[:entity]] }
  dlg = VGD::BIM::UI::Dialog.allocate
  dlg.instance_variable_set(:@dialog, FakeDialog.new)
  dlg.instance_variable_set(:@model, $model)
  dlg.instance_variable_set(:@table_records, records)
  dlg.instance_variable_set(:@table_rows, records.each_index.map { |i| {index: i} })
  dlg.instance_variable_set(:@mode, 'table')
  $builds = 0
  dlg.define_singleton_method(:table_build) { $builds += 1 }
  dlg.define_singleton_method(:show_outline) { nil }
  dlg.define_singleton_method(:check_model!) { nil }
  [dlg, records, defs]
end
def result(dir, conf, notes = []); {dir: dir, confidence: conf, notes: notes}; end
def front_of(def_); F.read(def_); end

# ---- Phát hiện ----
d, recs, defs = make(3)
$measure = {101 => result('+y', 'high', ['sát tường phía -y']), 102 => result('-x', 'medium'), 103 => result('+x', 'low', ['chưa đủ bằng chứng'])}
d.safely { d.front_detect('indexes' => [0, 1, 2]) }
ok('phát hiện: ghi hướng, nguồn tự động và độ tin cậy vào định nghĩa', front_of(defs[1]) == {dir: '+y', source: 'auto', confidence: 'high', note: 'sát tường phía -y'} && front_of(defs[2])[:dir] == '-x' && front_of(defs[3])[:confidence] == 'low')
ok('phát hiện: một bước hoàn tác, vẽ lại bảng, báo số liệu', $model.operations == ['VGD_BIM · Phát hiện mặt trước'] && $builds == 1 && last_text(d)['text'].start_with?('Đã xác định mặt trước cho 3 loại: tin cậy cao 1, trung bình 1, cần duyệt 1.'))
d, recs, defs = make(2)
$measure = {101 => result(nil, 'low', ['chưa đủ bằng chứng, cần duyệt']), 102 => result('+y', 'high')}
d.safely { d.front_detect('indexes' => [0, 1]) }
ok('không xác định được: không ghi gì cho món đó, báo cần đặt tay', front_of(defs[1])[:dir].nil? && front_of(defs[2])[:dir] == '+y' && last_text(d)['text'].include?('Chưa xác định được 1 loại'))
# Component có nhiều bản sao dùng chung một định nghĩa
d, recs, defs = make(1)
shared = defs[1]
recs << {entity: FakeEntity.new(201, shared), path: [], locked: false}; recs[1][:path] = [recs[1][:entity]]
recs << {entity: FakeEntity.new(202, shared), path: [], locked: false}; recs[2][:path] = [recs[2][:entity]]
d.instance_variable_set(:@table_records, recs)
$measure = {101 => result('+y', 'medium'), 201 => result('+y', 'high'), 202 => result('+y', 'medium')}
d.safely { d.front_detect('indexes' => [0, 1, 2]) }
ok('ba bản sao trùng hướng: một kết quả cho định nghĩa, độ tin cậy cao nhất giữa các bản sao đồng ý', front_of(shared)[:dir] == '+y' && front_of(shared)[:confidence] == 'high' && last_text(d)['text'].include?('cho 1 loại'))
F.clear(shared)
$measure = {101 => result('+y', 'high'), 201 => result('+y', 'high'), 202 => result('-y', 'medium')}
d.safely { d.front_detect('indexes' => [0, 1, 2]) }
ok('các bản sao mâu thuẫn: lấy hướng nhiều phiếu nhưng chỉ tin cậy thấp, ghi chú cần duyệt', front_of(shared)[:dir] == '+y' && front_of(shared)[:confidence] == 'low' && front_of(shared)[:note].include?('khác nhau'))
# Bảo vệ món đặt tay và món khóa
d, recs, defs = make(3)
F.write(defs[1], '-y')
recs[2][:locked] = true
$measure = {101 => result('+y', 'high'), 102 => result('+y', 'high'), 103 => result('+y', 'high')}
d.safely { d.front_detect('indexes' => [0, 1, 2]) }
ok('món đã đặt tay không bị ghi đè, món khóa bị bỏ qua, báo rõ cả hai', front_of(defs[1])[:dir] == '-y' && front_of(defs[1])[:source] == 'manual' && front_of(defs[2])[:dir] == '+y' && front_of(defs[3])[:dir].nil? && last_text(d)['text'].include?('Bỏ qua 1 đối tượng đã đặt tay') && last_text(d)['text'].include?('Bỏ qua 1 đối tượng bị khóa'))
d.safely { d.front_detect('indexes' => [0], 'overwrite' => true) }
ok('overwrite = true: ghi đè được món đặt tay', front_of(defs[1])[:source] == 'auto' && front_of(defs[1])[:dir] == '+y')
d, recs, defs = make(2)
$measure = {101 => result('+x', 'high'), 102 => result('-x', 'high')}
d.safely { d.front_detect({}) }
ok('không nói indexes: xem xét mọi dòng trong bảng', front_of(defs[1])[:dir] == '+x' && front_of(defs[2])[:dir] == '-x')
d, = make(0)
d.safely { d.front_detect({}) }
ok('bảng trống: báo lỗi tiếng Việt, không mở bước hoàn tác', events(d, 'message').last['error'].to_s.include?('Chưa có đối tượng') && $model.operations.empty?)
d, recs, = make(VGD::BIM::UI::FrontActions::MAX_FRONT_BATCH + 1)
d.safely { d.front_detect({}) }
ok('quá giới hạn một lần: từ chối trước khi đo', events(d, 'message').last['error'].to_s.include?('tối đa'))
d, recs, = make(1)
d.safely { d.front_detect('indexes' => [5]) }
ok('chỉ số dòng không có trong bảng: báo bảng đã cũ', events(d, 'message').last['error'].to_s.include?('đã cũ'))

# ---- Đặt tay ----
d, recs, defs = make(2)
d.safely { d.front_set('indexes' => [0, 1], 'mode' => 'dir', 'dir' => '-y') }
ok('đặt tay theo hướng: thủ công, tin cậy cao, hai món', defs.values.all? { |x| front_of(x)[:dir] == '-y' && front_of(x)[:source] == 'manual' && front_of(x)[:confidence] == 'high' } && $model.operations == ['VGD_BIM · Đặt mặt trước'])
%w[z +z].each { |bad| d.safely { d.front_set('indexes' => [0], 'mode' => 'dir', 'dir' => bad) }; ok("hướng sai bị từ chối: #{bad}", events(d, 'message').last['error'].to_s.include?('Hướng mặt trước')) }
d.safely { d.front_set('indexes' => [0], 'mode' => 'khac') }
ok('cách đặt lạ bị từ chối', events(d, 'message').last['error'].to_s.include?('Cách đặt'))
$camera = {101 => '+x', 102 => '-x'}
d.safely { d.front_set('indexes' => [0, 1], 'mode' => 'camera') }
ok('theo hướng nhìn: mỗi món lấy hướng cục bộ từ camera', front_of(defs[1])[:dir] == '+x' && front_of(defs[2])[:dir] == '-x')
d.safely { d.front_set('indexes' => [0, 1], 'mode' => 'turn') }
ok('xoay 90°: +x thành +y, -x thành -y', front_of(defs[1])[:dir] == '+y' && front_of(defs[2])[:dir] == '-y')
d.safely { d.front_set('indexes' => [0, 1], 'mode' => 'opposite') }
ok('đảo chiều: +y thành -y, -y thành +y', front_of(defs[1])[:dir] == '-y' && front_of(defs[2])[:dir] == '+y')
F.clear(defs[2])
d.safely { d.front_set('indexes' => [0, 1], 'mode' => 'turn') }
ok('xoay khi một món chưa có mặt trước: bỏ qua món đó và báo', front_of(defs[1])[:dir] == '+x' && front_of(defs[2])[:dir].nil? && last_text(d)['text'].include?('Bỏ qua 1 đối tượng chưa có mặt trước'))
d, recs, defs = make(1)
d.safely { d.front_set('indexes' => [0], 'mode' => 'turn') }
ok('xoay khi chưa có mặt trước nào: báo lỗi, không ghi', events(d, 'message').last['error'].to_s.include?('Chưa có mặt trước') && $model.operations.empty?)
# Bản sao cùng định nghĩa nhưng camera cho hướng khác nhau: hủy cả lệnh
d, recs, defs = make(1)
recs << {entity: FakeEntity.new(201, defs[1]), path: [], locked: false}; recs[1][:path] = [recs[1][:entity]]
d.instance_variable_set(:@table_records, recs)
$camera = {101 => '+y', 201 => '-y'}
d.safely { d.front_set('indexes' => [0, 1], 'mode' => 'camera') }
ok('hai bản sao của một component nhìn khác hướng: hủy cả lệnh, không ghi nửa chừng', events(d, 'message').last['error'].to_s.include?('khác nhau') && front_of(defs[1])[:dir].nil? && $model.operations.empty?)
$camera = {101 => '+y', 201 => '+y'}
d.safely { d.front_set('indexes' => [0, 1], 'mode' => 'camera') }
ok('hai bản sao của một component nhìn cùng hướng: đặt được một lần cho định nghĩa chung', front_of(defs[1])[:dir] == '+y' && last_text(d)['text'].include?('cho 1 loại'))
F.clear(defs[1])
$camera = {101 => nil}
d.safely { d.front_set('indexes' => [0], 'mode' => 'camera') }
ok('camera nhìn thẳng từ trên xuống (không có hướng ngang): báo lỗi nói rõ về camera, không ghi gì', events(d, 'message').last['error'].to_s.include?('hướng nhìn ngang của camera') && front_of(defs[1])[:dir].nil?)
d, recs, defs = make(2)
recs[0][:locked] = true
d.safely { d.front_set('indexes' => [0, 1], 'mode' => 'dir', 'dir' => '+x') }
ok('món khóa bị bỏ qua khi đặt tay, món khác vẫn được đặt', front_of(defs[1])[:dir].nil? && front_of(defs[2])[:dir] == '+x' && last_text(d)['text'].include?('bị khóa'))
recs[1][:locked] = true
d.safely { d.front_set('indexes' => [0, 1], 'mode' => 'dir', 'dir' => '+x') }
ok('toàn bộ bị khóa: báo lỗi', events(d, 'message').last['error'].to_s.include?('bị khóa'))

# ---- Xóa ----
d, recs, defs = make(2)
F.write(defs[1], '+y'); F.write(defs[2], '-x')
d.safely { d.front_clear('indexes' => [0]) }
ok('xóa: chỉ món đã chọn, một bước hoàn tác', front_of(defs[1])[:dir].nil? && front_of(defs[2])[:dir] == '-x' && $model.operations == ['VGD_BIM · Xóa mặt trước'])
recs[1][:locked] = true
d.safely { d.front_clear('indexes' => [1]) }
ok('xóa món khóa: báo lỗi, giữ nguyên', events(d, 'message').last['error'].to_s.include?('bị khóa') && front_of(defs[2])[:dir] == '-x')

# ---- Phán quyết nhiều bản sao ----
v = d.front_verdict([result('+y', 'medium', ['a']), result('+y', 'low', ['a', 'b'])])
ok('front_verdict: trùng hướng lấy độ tin cậy cao nhất, gộp ghi chú không trùng', v == {dir: '+y', confidence: 'medium', notes: %w[a b]})
ok('front_verdict: tất cả không có hướng thì không chọn', d.front_verdict([result(nil, 'low', ['x'])]) == {dir: nil, confidence: 'low', notes: ['x']})

puts $fails.zero? ? 'Done' : "#{$fails} lỗi"
exit($fails.zero? ? 0 : 1)
