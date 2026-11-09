# Test xếp tag vào thư mục tag (ui/tag_auto.rb, phần thư mục): xem trước, áp dụng một bước hoàn tác, ghi đè, tạo thư mục, SketchUp cũ không có thư mục tag,
# lưu / đặt lại / nhập / xuất bộ luật. SketchUp giả lập đơn giản; chạy thật trong SketchUp chưa kiểm được. Chạy: ruby dev/test_tag_folders.rb
require 'json'
require 'tmpdir'
require 'fileutils'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_tag_folders')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
module Sketchup; class Group; end; class ComponentInstance; end; class Face; end; end
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
%w[storage tags measure geometry tag_rules tag_catalog folder_rules].each { |f| require File.join(ROOT, "core/#{f}") }
require File.join(ROOT, 'ui/tag_auto')

class FFolder
  attr_reader :name
  def initialize(name); @name = name; end
end
class FTag
  attr_accessor :name, :folder
  def initialize(name, folder = nil); @name = name; @folder = folder; end
  def visible?; true; end
end
class FTags
  include Enumerable
  attr_reader :folders
  def initialize(list, folders = []); @list = list; @folders = folders; end
  def each(&block); @list.each(&block); end
  def to_a; @list.dup; end
  def add(name); tag = FTag.new(name); @list << tag; tag; end
  def add_folder(name); folder = FFolder.new(name); @folders << folder; folder; end
end
# Bản SketchUp cũ: không có thư mục tag
class OldTags
  include Enumerable
  def initialize(list); @list = list; end
  def each(&block); @list.each(&block); end
  def to_a; @list.dup; end
end
FModel = Struct.new(:layers, :active_path, :selection, :entities)
class Probe
  include VGD::BIM::UI::TagAuto
  attr_reader :events
  def initialize(model); @model = model; @events = []; end
  def emit(event, payload); @events << [event, payload]; end
  def check_model!; end
  def tag_state; {tags: [], groups: [], selection: 0}; end
  def last(event); @events.reverse.find { |e, _| e == event }&.last; end
  def messages; @events.select { |e, _| e == 'message' }.map { |_, p| p[:text] }; end
end
RULES = VGD::BIM::FolderRules.default
def payload(over = {}); {'rules' => RULES, 'overwrite' => false}.merge(over); end
def build(tags, folders = [])
  model = FModel.new(FTags.new(tags, folders), [], [], [])
  [model, Probe.new(model)]
end

untagged = FTag.new('Untagged')
wall = FTag.new('A. WALL')
door = FTag.new('A. DOOR')
beam = FTag.new('S. BEAM')
mine = FTag.new('Tag riêng')                                     # không khớp luật nào
arch_folder = FFolder.new('A. ARCHITECTURAL')
placed = FTag.new('A. STAIR', arch_folder)                       # đã đúng thư mục
moved = FTag.new('S. COLUMN', FFolder.new('Thư mục tự xếp'))    # đã nằm ở thư mục khác
model, d = build([untagged, wall, door, beam, mine, placed, moved], [arch_folder, moved.folder])
d.folder_auto_preview(payload)
plan = d.last('folder_auto_plan')
ok('xem trước: 6 tag (bỏ Untagged); xếp 3 (A. WALL, A. DOOR, S. BEAM); 1 đã đúng thư mục; 1 giữ nguyên vì đã ở thư mục khác; 1 không khớp luật',
   plan && plan[:total] == 6 && plan[:assign] == 3 && plan[:same] == 1 && plan[:kept] == 1 && plan[:unmatched] == 1 && !plan.key?(:locked))
ok('xem trước: tóm tắt theo thư mục kèm tên tag mẫu', plan[:rules].map { |r| [r[:tag], r[:count], r[:samples]] } == [['A. ARCHITECTURAL', 2, ['A. WALL', 'A. DOOR']], ['S. STRUCTURAL', 1, ['S. BEAM']]])
ok('xem trước: không đụng vào model (chưa thư mục mới, chưa tag nào đổi), không mở bước hoàn tác', model.layers.folders.size == 2 && wall.folder.nil? && $transactions.empty?)
d.folder_auto_preview(payload('overwrite' => true))
ok('bật ghi đè: tag đã ở thư mục khác cũng được xếp lại theo luật (4 tag, không còn mục giữ)', d.last('folder_auto_plan')[:assign] == 4 && d.last('folder_auto_plan')[:kept] == 0)

# ---- Áp dụng ----
$transactions.clear
d.folder_auto_apply(payload)
ok('áp dụng: A. WALL, A. DOOR vào thư mục A. ARCHITECTURAL có sẵn (dùng lại, không tạo trùng); S. BEAM vào thư mục S. STRUCTURAL mới tạo', wall.folder.equal?(arch_folder) && door.folder.equal?(arch_folder) && beam.folder&.name == 'S. STRUCTURAL' && model.layers.folders.map(&:name) == ['A. ARCHITECTURAL', 'Thư mục tự xếp', 'S. STRUCTURAL'])
ok('áp dụng: tag đã ở thư mục khác (không ghi đè) và tag không khớp luật giữ nguyên', moved.folder.name == 'Thư mục tự xếp' && mine.folder.nil? && untagged.folder.nil?)
ok('áp dụng: đúng một bước hoàn tác cho cả đợt', $transactions == ['VGD BIM · Xếp tag vào thư mục'])
ok('áp dụng: báo số tag, số thư mục, số thư mục mới, đã đúng sẵn, giữ nguyên', d.messages.last == 'Đã xếp 3 tag vào 2 thư mục (1 thư mục mới tạo). Đã đúng thư mục sẵn: 1. Giữ nguyên 1 tag đã nằm trong thư mục khác.' && d.last('folder_auto_plan') == {cleared: true} && d.events.any? { |e, _| e == 'tags' })
$transactions.clear
ok('áp dụng lần hai khi không còn gì: báo lỗi, không mở bước hoàn tác', error_of { d.folder_auto_apply(payload) }.to_s.include?('Không có tag nào cần xếp') && $transactions.empty?)
d.folder_auto_apply(payload('overwrite' => true))
ok('áp dụng có ghi đè: S. COLUMN chuyển sang thư mục S. STRUCTURAL (dùng lại thư mục vừa tạo)', moved.folder.equal?(beam.folder) && model.layers.folders.count { |f| f.name == 'S. STRUCTURAL' } == 1)
ok('tên thư mục khác hoa thường vẫn dùng lại thư mục có sẵn (a. architectural)', (m2, d2 = build([FTag.new('A. WALL')], [FFolder.new('a. architectural')]); d2.folder_auto_apply(payload); m2.layers.folders.size == 1 && m2.layers.to_a[0].folder.name == 'a. architectural'))

# ---- Dữ liệu sai, SketchUp cũ ----
ok('luật sai bị từ chối nêu số dòng; không có luật nào bị từ chối', error_of { d.folder_auto_preview(payload('rules' => [{'folder' => '', 'keywords' => 'ab'}])) }.to_s.downcase.include?('dòng 1') && error_of { d.folder_auto_preview(payload('rules' => [])) }.to_s.include?('Chưa có luật'))
_, old = build([FTag.new('A. WALL')])
old.instance_variable_get(:@model).layers = OldTags.new([FTag.new('A. WALL')])
ok('SketchUp cũ không có thư mục tag: báo lỗi rõ cả khi xem trước và khi áp dụng, không đổi gì', error_of { old.folder_auto_preview(payload) }.to_s.include?('SketchUp 2021') && error_of { old.folder_auto_apply(payload) }.to_s.include?('SketchUp 2021'))
ok('model không có tag nào ngoài Untagged: báo lỗi rõ', error_of { build([FTag.new('Untagged')])[1].folder_auto_preview(payload) }.to_s.include?('Chưa có tag'))

# ---- Lưu, đặt lại, nhập, xuất ----
_, io = build([])
io.folder_rules_save('rules' => [{'folder' => ' Thư mục riêng ', 'keywords' => 'riêng'}])
ok('lưu mặc định: ghi file và gửi lại bộ luật sạch', VGD::BIM::FolderRules.load == [{'folder' => 'Thư mục riêng', 'keywords' => 'riêng'}] && io.last('folder_rules')[:rules] == VGD::BIM::FolderRules.load && io.messages.last.include?('mặc định'))
ok('lưu sai: báo lỗi, giữ bộ đã lưu', error_of { io.folder_rules_save('rules' => [{'folder' => 'A', 'keywords' => ''}]) }.to_s.downcase.include?('dòng 1') && VGD::BIM::FolderRules.load.size == 1)
$panels[:confirm] = IDNO
io.folder_rules_reset
ok('đặt lại nhưng chọn Không: giữ nguyên', VGD::BIM::FolderRules.load.size == 1)
$panels[:confirm] = IDYES
io.folder_rules_reset
ok('đặt lại: về bộ mặc định 18 luật và gửi cho giao diện', VGD::BIM::FolderRules.load.size == 18 && io.last('folder_rules')[:rules].size == 18)
file = File.join(Dir.tmpdir, "luat_thu_muc_#{Process.pid}")
$panels[:save] = file
io.folder_rules_export('rules' => RULES)
ok('xuất: file .json đúng định dạng, nhập lại được, báo số luật', File.exist?("#{file}.json") && VGD::BIM::FolderRules.from_json(File.read("#{file}.json")) == RULES && io.messages.last.start_with?('Đã xuất 18 luật'))
$panels[:save] = nil
$panels[:open] = "#{file}.json"
io.folder_rules_import
ok('nhập: gửi bộ luật trong file cho giao diện (chưa lưu mặc định), báo rõ', io.last('folder_rules')[:rules] == RULES && io.last('folder_rules')[:imported] == true && io.messages.last.include?('chưa lưu'))
File.write("#{file}.json", '{hỏng')
ok('nhập file hỏng: báo lỗi', error_of { io.folder_rules_import }.to_s.include?('JSON'))
$panels[:open] = nil
ok('hủy hộp chọn file: không làm gì', error_of { io.folder_rules_import }.nil?)
FileUtils.rm_f("#{file}.json")
puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
