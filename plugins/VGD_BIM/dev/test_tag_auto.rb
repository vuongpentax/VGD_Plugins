# Test gắn tag tự động theo từ khóa tên (ui/tag_auto.rb): thu thập đối tượng (đang chọn / cả model, lồng bên trong), xem trước, áp dụng một
# bước hoàn tác, lưu / đặt lại / nhập / xuất bộ luật. SketchUp giả lập đơn giản; chạy thật trong SketchUp chưa kiểm được. Chạy: ruby dev/test_tag_auto.rb
require 'json'
require 'tmpdir'
require 'fileutils'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_tag_auto')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end

module Sketchup
  class Group; end
  class ComponentInstance; end
  class Face; end
end
module VGD; module BIM
  def self.log(_m); end
  module Data
    def self.supported?(e); e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance); end
    def self.transaction(_model, name = nil); $transactions << name; yield; end
  end
  module UI; end
end; end
$transactions = []
$panels = {}
MB_YESNO = 4
IDYES = 6
IDNO = 7
module UI
  def self.savepanel(*); $panels[:save]; end
  def self.openpanel(*); $panels[:open]; end
  def self.messagebox(*); $panels.fetch(:confirm, IDYES); end
end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
%w[storage tags measure geometry tag_rules tag_catalog].each { |f| require File.join(ROOT, "core/#{f}") }
require File.join(ROOT, 'ui/tag_auto')

class FLayer
  attr_accessor :name, :visible
  def initialize(name, visible = true); @name = name; @visible = visible; end
  def visible?; @visible; end
end
class FLayers
  include Enumerable
  def initialize(list); @list = list; end
  def each(&block); @list.each(&block); end
  def add(name); layer = FLayer.new(name); @list << layer; layer; end
  def to_a; @list.dup; end
end
class FDefinition
  attr_reader :name, :children
  def initialize(name, children = []); @name = name; @children = children; end
  def entities; @children; end
end
# Entities của group: có parent (định nghĩa của group) như SketchUp thật
class FGroupEntities
  attr_reader :parent
  def initialize(parent); @parent = parent; end
end
class FGroup < Sketchup::Group
  attr_accessor :name, :layer, :locked
  def initialize(name, kids = [], layer: nil, locked: false); @name = name; @definition = FDefinition.new('', kids); @layer = layer; @locked = locked; end
  def valid?; true; end
  def locked?; @locked; end
  def entities; FGroupEntities.new(@definition); end
end
class FComponent < Sketchup::ComponentInstance
  attr_accessor :name, :layer, :locked
  attr_reader :definition
  def initialize(name, definition, layer: nil, locked: false); @name = name; @definition = definition; @layer = layer; @locked = locked; end
  def valid?; true; end
  def locked?; @locked; end
end
FModel = Struct.new(:selection, :entities, :layers, :active_path) do
  def selection_list; selection; end
end
class SelList; def initialize(list); @list = list; end; def to_a; @list.dup; end; end
class EntList; def initialize(list); @list = list; end; def to_a; @list.dup; end; end

class Probe
  include VGD::BIM::UI::TagAuto
  attr_reader :events
  attr_writer :model
  def initialize(model); @model = model; @events = []; end
  def emit(event, payload); @events << [event, payload]; end
  def check_model!; end
  def tag_state; {tags: [], groups: [], selection: 0}; end
  def last(event); @events.reverse.find { |e, _| e == event }&.last; end
  def messages; @events.select { |e, _| e == 'message' }.map { |_, p| p[:text] }; end
end

RULES = VGD::BIM::TagRules.default
def payload(over = {}); {'rules' => RULES, 'based_on' => 'both', 'scope' => 'selection', 'nested' => false, 'overwrite' => false}.merge(over); end
def build(selection: [], root: nil, layers: [FLayer.new('Untagged')])
  model = FModel.new(SelList.new(selection), EntList.new(root || selection), FLayers.new(layers), [])
  [model, Probe.new(model)]
end

wall = FGroup.new('Tường 100')
door = FComponent.new('', FDefinition.new('Door_900'))
chair = FGroup.new('Ghế ăn')
tagged = FGroup.new('Wall B', [], layer: FLayer.new('Khác'))
locked = FGroup.new('Tường khóa', [], locked: true)
model, d = build(selection: [wall, door, chair, tagged, locked])
d.tag_auto_preview(payload)
plan = d.last('tag_auto_plan')
ok('xem trước (đang chọn): tính đủ 5 đối tượng, gắn 2 (Tường, Cửa), giữ 1 đã có tag khác, 1 không khớp, 1 bị khóa',
   plan && plan[:total] == 5 && plan[:assign] == 2 && plan[:kept] == 1 && plan[:unmatched] == 1 && plan[:locked] == 1 && plan[:same] == 0)
ok('xem trước: tóm tắt theo tag kèm tên mẫu', plan[:rules].map { |r| [r[:tag], r[:count], r[:samples]] } == [['A. WALL', 1, ['Tường 100']], ['A. DOOR', 1, ['Door_900']]])
ok('xem trước: không sửa gì trong model, không mở bước hoàn tác', wall.layer.nil? && door.layer.nil? && $transactions.empty?)

d.tag_auto_preview(payload('overwrite' => true))
ok('bật ghi đè: đối tượng đã có tag khác cũng được gắn (3 đối tượng, không còn mục giữ)', d.last('tag_auto_plan')[:assign] == 3 && d.last('tag_auto_plan')[:kept] == 0)

_, empty = build(selection: [])
ok('không chọn gì (phạm vi đang chọn): báo lỗi rõ', error_of { empty.tag_auto_preview(payload) }.to_s.include?('Hãy chọn'))
ok('cả model: lấy các đối tượng ở gốc model dù không chọn gì', (_, whole = build(selection: [], root: [wall, chair]); whole.tag_auto_preview(payload('scope' => 'model')); whole.last('tag_auto_plan')[:total] == 2))

# ---- Lồng bên trong ----
inner = FGroup.new('Wall inner')
shared = FDefinition.new('Cột_shared', [])
comp_a = FComponent.new('', shared)
comp_b = FComponent.new('', shared)
shared.children << FGroup.new('Beam trong cột')
holder = FGroup.new('Nhà', [inner, comp_a, comp_b])
_, nest = build(selection: [holder])
nest.tag_auto_preview(payload)
ok('không bật lồng: chỉ xét đối tượng được chọn (1 đối tượng "Nhà", không khớp luật)', nest.last('tag_auto_plan')[:total] == 1 && nest.last('tag_auto_plan')[:unmatched] == 1)
nest.tag_auto_preview(payload('nested' => true))
ok('bật lồng: xét cả group / component bên trong; định nghĩa dùng chung chỉ duyệt một lần (Nhà, Wall inner, 2 bản sao, 1 Beam = 5)', nest.last('tag_auto_plan')[:total] == 5)
locked_parent = FGroup.new('Vỏ', [FGroup.new('Wall con')], locked: true)
_, lp = build(selection: [locked_parent])
lp.tag_auto_preview(payload('nested' => true))
ok('group cha bị khóa: đối tượng bên trong cũng coi là bị khóa', lp.last('tag_auto_plan')[:locked] == 2 && lp.last('tag_auto_plan')[:assign] == 0)
ok('quá nhiều đối tượng: báo lỗi, không treo', (many = Array.new(VGD::BIM::UI::TagAuto::MAX_ITEMS + 1) { FGroup.new('x') }; _, big = build(selection: many); error_of { big.tag_auto_preview(payload) }.to_s.include?('Quá nhiều')))

# ---- Dựa theo ----
comp_named = FComponent.new('Bản 1', FDefinition.new('Window_A'))
_, based = build(selection: [comp_named])
ok('dựa theo tên bản sao: "Bản 1" không khớp', (based.tag_auto_preview(payload('based_on' => 'instance')); based.last('tag_auto_plan')[:assign] == 0))
ok('dựa theo tên component: "Window_A" khớp A. WINDOW', (based.tag_auto_preview(payload('based_on' => 'definition')); based.last('tag_auto_plan')[:rules].map { |r| r[:tag] } == ['A. WINDOW']))
ok('cả hai: khớp qua tên component', (based.tag_auto_preview(payload('based_on' => 'both')); based.last('tag_auto_plan')[:assign] == 1))
ok('group không có tên component: dựa theo "tên component" thì dùng tên group', (_, g = build(selection: [FGroup.new('Wall X')]); g.tag_auto_preview(payload('based_on' => 'definition')); g.last('tag_auto_plan')[:assign] == 1))

# ---- Dữ liệu sai ----
ok('tùy chọn lạ bị từ chối', error_of { d.tag_auto_preview(payload('based_on' => 'lạ')) }.to_s.include?('Dựa theo') && error_of { d.tag_auto_preview(payload('scope' => 'lạ')) }.to_s.include?('Phạm vi'))
ok('luật sai bị từ chối, nêu số dòng', error_of { d.tag_auto_preview(payload('rules' => [{'tag' => '', 'keywords' => 'ab'}])) }.to_s.downcase.include?('dòng 1'))

# ---- Áp dụng ----
$transactions.clear
model, ap = build(selection: [wall, door, chair, tagged, locked], layers: [FLayer.new('Untagged'), FLayer.new('A. DOOR', false)])
ap.tag_auto_apply(payload)
ok('áp dụng: gắn A. WALL (tạo tag mới) và A. DOOR (dùng tag có sẵn), giữ đối tượng đã có tag khác, bỏ qua đối tượng khóa / không khớp',
   wall.layer && wall.layer.name == 'A. WALL' && door.layer.name == 'A. DOOR' && model.layers.map(&:name) == ['Untagged', 'A. DOOR', 'A. WALL'] && tagged.layer.name == 'Khác' && locked.layer.nil? && chair.layer.nil?)
ok('áp dụng: đúng một bước hoàn tác cho cả đợt', $transactions == ['VGD BIM · Gắn tag tự động'])
msg = ap.messages.last
ok('áp dụng: báo số đối tượng, số tag, giữ nguyên, bị khóa và cảnh báo tag đang ẩn', msg.start_with?('Đã gắn tag tự động cho 2 đối tượng (2 tag).') && msg.include?('Giữ nguyên 1') && msg.include?('Bỏ qua 1 đối tượng bị khóa') && msg.include?('A. DOOR') && msg.include?('ẩn'))
ok('áp dụng: xóa bản xem trước cũ ở giao diện và cập nhật danh sách tag', ap.last('tag_auto_plan') == {cleared: true} && ap.events.any? { |e, _| e == 'tags' })
$transactions.clear
ok('áp dụng lần hai khi đã đúng tag: báo không còn gì để gắn, không mở bước hoàn tác', error_of { ap.tag_auto_apply(payload) }.to_s.include?('Không có đối tượng nào cần gắn') && $transactions.empty?)
ok('áp dụng có ghi đè: đổi tag của đối tượng đã có tag khác', (ap.tag_auto_apply(payload('overwrite' => true)); tagged.layer.name == 'A. WALL'))
ok('áp dụng không đụng tới đối tượng bị khóa dù bật ghi đè', locked.layer.nil?)

# ---- Thư viện tag mẫu: tick cụm rồi Nhập ----
$transactions.clear
VGD::BIM::Tags.save(VGD::BIM::Tags::DEFAULT_SET + [{'name' => 'Tag riêng', 'group' => '# BASIC'}])
cat_model, cat = build(layers: [FLayer.new('Untagged'), FLayer.new('a. door')])
cat.tag_catalog_import('groups' => ['F. FIRE PROTECTION', 'A. ARCHITECTURAL'])
set_names = VGD::BIM::Tags.load.map { |t| t['name'] }
ok('Nhập cụm: tag của các cụm đã tick vào bộ tag của BIM (16 tag), không trùng, tag riêng cũ giữ nguyên', set_names.include?('A. CHIMNEY') && set_names.include?('F. FIRE SUPPRESSION') && set_names.include?('Tag riêng') && set_names.size == set_names.map { |n| VGD::BIM::Tags.key(n) }.uniq.size && set_names.size == 16 + 1)
ok('Nhập cụm: mỗi tag mang nhóm của cụm', VGD::BIM::Tags.load.find { |t| t['name'] == 'F. FIRE SUPPRESSION' }['group'] == 'F. FIRE PROTECTION' && VGD::BIM::Tags.load.find { |t| t['name'] == 'A. WALL' }['group'] == 'A. ARCHITECTURAL')
layer_names = cat_model.layers.map(&:name)
ok('Nhập cụm: tạo luôn tag trong model (15 tag mới; tag đã có "a. door" không tạo lại dù khác hoa thường)', layer_names.size == 2 + 15 && layer_names.count { |n| n.casecmp('A. DOOR').zero? } == 1 && layer_names.include?('F. FIRE SUPPRESSION'))
ok('Nhập cụm: đúng một bước hoàn tác cho cả đợt', $transactions == ['VGD BIM · Nhập tag mẫu'])
ok('Nhập cụm: báo số tag, số cụm, số tag mới trong model và cập nhật danh sách tag ở giao diện', cat.messages.last == 'Đã nhập 16 tag từ 2 cụm vào bộ tag (15 tag mới tạo trong model).' && cat.events.any? { |e, _| e == 'tags' })
$transactions.clear
cat.tag_catalog_import('groups' => ['F. FIRE PROTECTION'])
ok('Nhập lại cụm đã nhập: không tạo thêm tag, báo 0 tag mới', cat.messages.last == 'Đã nhập 1 tag từ 1 cụm vào bộ tag (0 tag mới tạo trong model).' && cat_model.layers.map(&:name).size == 17)
$transactions.clear
ok('Nhập khi chưa tick cụm nào hoặc cụm lạ: báo lỗi, không đụng vào bộ tag và model', error_of { cat.tag_catalog_import('groups' => []) }.to_s.include?('tick') && error_of { cat.tag_catalog_import('groups' => ['Phần thô']) }.to_s.include?('không hợp lệ') && error_of { cat.tag_catalog_import({}) }.to_s.include?('tick') && $transactions.empty? && VGD::BIM::Tags.load.size == 17)

# ---- Lưu, đặt lại, nhập, xuất ----
_, io = build
io.tag_rules_save('rules' => [{'tag' => ' Nội thất ', 'keywords' => 'bàn, ghế'}])
ok('lưu mặc định: ghi xuống file và gửi lại bộ luật sạch cho giao diện', VGD::BIM::TagRules.load == [{'tag' => 'Nội thất', 'keywords' => 'bàn, ghế'}] && io.last('tag_rules')[:rules] == VGD::BIM::TagRules.load && io.messages.last.include?('mặc định'))
ok('lưu luật sai: báo lỗi, giữ bộ đã lưu', error_of { io.tag_rules_save('rules' => [{'tag' => 'A1', 'keywords' => ''}]) }.to_s.downcase.include?('dòng 1') && VGD::BIM::TagRules.load.size == 1)
$panels[:confirm] = IDNO
io.tag_rules_reset
ok('đặt lại nhưng chọn Không: giữ nguyên bộ đã lưu, không gửi gì', VGD::BIM::TagRules.load.size == 1 && io.last('tag_rules')[:rules].size == 1)
$panels[:confirm] = IDYES
io.tag_rules_reset
ok('đặt lại: về bộ mặc định và gửi cho giao diện', VGD::BIM::TagRules.load == VGD::BIM::TagRules.default && io.last('tag_rules')[:rules] == VGD::BIM::TagRules.default)
file = File.join(Dir.tmpdir, "luat_tag_#{Process.pid}")
$panels[:save] = file
io.tag_rules_export('rules' => RULES)
ok('xuất: file có đuôi .json, đúng định dạng và nhập lại được', File.exist?("#{file}.json") && VGD::BIM::TagRules.from_json(File.read("#{file}.json")) == RULES && io.messages.last.start_with?("Đã xuất #{RULES.size} luật"))
$panels[:save] = nil
before = io.messages.size
io.tag_rules_export('rules' => RULES)
ok('hủy hộp chọn nơi lưu: không làm gì', io.messages.size == before)
$panels[:open] = "#{file}.json"
io.tag_rules_import
ok('nhập: gửi bộ luật trong file cho giao diện (chưa lưu làm mặc định), báo rõ', io.last('tag_rules')[:rules] == RULES && io.last('tag_rules')[:imported] == true && VGD::BIM::TagRules.load == VGD::BIM::TagRules.default && io.messages.last.include?('chưa lưu'))
File.write("#{file}.json", '{hỏng')
ok('nhập file hỏng: báo lỗi, không đổi gì', error_of { io.tag_rules_import }.to_s.include?('JSON'))
$panels[:open] = nil
ok('hủy hộp chọn file: không làm gì', error_of { io.tag_rules_import }.nil?)
FileUtils.rm_f("#{file}.json")
puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
