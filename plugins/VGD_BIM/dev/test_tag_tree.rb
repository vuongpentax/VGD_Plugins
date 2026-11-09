# Test quản lý tag (core/tag_tree.rb, ui/tag_manager.rb): cây thư mục / tag, bật tắt hiển thị, cô lập và khôi phục. SketchUp giả lập đơn giản;
# API thư mục tag (SketchUp 2021+) chưa kiểm được trong SketchUp thật. Chạy: ruby dev/test_tag_tree.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
module Sketchup; class Group; end; class ComponentInstance; end; class Face; end; end
module VGD; module BIM
  def self.log(_m); end
  module Data
    def self.transaction(_model, name = nil); $transactions << name; yield; end
  end
  module UI; end
end; end
$transactions = []
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
require File.join(ROOT, 'core/tag_tree')
require File.join(ROOT, 'ui/tag_manager')
T = VGD::BIM::TagTree

# ---- Logic thuần ----
folders = [{id: 1, name: 'A', visible: true, parent_id: nil}, {id: 2, name: 'A1', visible: true, parent_id: 1}, {id: 3, name: 'B', visible: true, parent_id: nil}]
layers = [{id: 10, name: 'x', visible: true, folder_id: 2}, {id: 11, name: 'y', visible: true, folder_id: 1}, {id: 12, name: 'z', visible: false, folder_id: 3}, {id: 13, name: 'Untagged', visible: true, folder_id: nil}]
ok('with_ancestors: thư mục và các thư mục cha, từ dưới lên', T.with_ancestors(folders, 2) == [2, 1] && T.with_ancestors(folders, nil) == [] && T.with_ancestors(folders, 99) == [])
ok('with_ancestors: dữ liệu vòng lặp không treo', T.with_ancestors([{id: 1, parent_id: 2}, {id: 2, parent_id: 1}], 1) == [1, 2])
ok('with_descendants: thư mục và mọi thư mục con cháu', T.with_descendants(folders, 1).sort == [1, 2] && T.with_descendants(folders, 3) == [3])
ok('snapshot: ghi hiển thị của mọi tag và thư mục', T.snapshot(layers, folders) == {layers: {10 => true, 11 => true, 12 => false, 13 => true}, folders: {1 => true, 2 => true, 3 => true}})
plan = T.isolate_plan(layers, folders, 'tag', 10)
ok('cô lập tag trong thư mục lồng: chỉ tag đó và hai thư mục chứa nó hiện', plan[:layers] == {10 => true, 11 => false, 12 => false, 13 => false} && plan[:folders] == {1 => true, 2 => true, 3 => false})
plan = T.isolate_plan(layers, folders, 'tag', 13)
ok('cô lập tag ở gốc: mọi thư mục đều ẩn', plan[:layers][13] == true && plan[:folders].values.none?)
plan = T.isolate_plan(layers, folders, 'folder', 1)
ok('cô lập thư mục: thư mục, thư mục con và mọi tag bên trong hiện, phần còn lại ẩn', plan[:folders] == {1 => true, 2 => true, 3 => false} && plan[:layers] == {10 => true, 11 => true, 12 => false, 13 => false})
plan = T.isolate_plan(layers, folders, 'folder', 2)
ok('cô lập thư mục con: giữ cả thư mục cha hiện (không thì bị ẩn theo cha), tag của thư mục cha ở ngoài thì ẩn', plan[:folders] == {1 => true, 2 => true, 3 => false} && plan[:layers][10] == true && plan[:layers][11] == false)
ok('cô lập mục không có / loại mục sai: báo lỗi tiếng Việt', error_of { T.isolate_plan(layers, folders, 'tag', 99) }.include?('làm mới') && error_of { T.isolate_plan(layers, folders, 'folder', 99) }.include?('làm mới') && error_of { T.isolate_plan(layers, folders, 'x', 1) }.include?('không hợp lệ'))
ok('changes: chỉ liệt kê mục có hiển thị khác hiện tại', T.changes(layers, folders, T.isolate_plan(layers, folders, 'tag', 10)) == {layers: [11, 13], folders: [3]})

# ---- Phần gọi SketchUp (giả lập) ----
class FFolder
  attr_reader :persistent_id, :name, :folders
  attr_accessor :folder
  def initialize(id, name, visible = true, parent = nil); @persistent_id = id; @name = name; @visible = visible; @folders = []; @folder = parent; parent.folders << self if parent; end
  def visible?; @visible; end
  def visible=(v); @visible = v; end
end
class FTag
  attr_reader :persistent_id, :name
  attr_accessor :folder
  def initialize(id, name, visible = true, folder = nil); @persistent_id = id; @name = name; @visible = visible; @folder = folder; end
  def visible?; @visible; end
  def visible=(v); @visible = v; end
end
class FTags
  include Enumerable
  attr_reader :folders
  def initialize(list, folders); @list = list; @folders = folders; end
  def each(&block); @list.each(&block); end
  def to_a; @list.dup; end
end
class OldTags
  include Enumerable
  def initialize(list); @list = list; end
  def each(&block); @list.each(&block); end
  def to_a; @list.dup; end
end
FModel = Struct.new(:layers)
class Probe
  include VGD::BIM::UI::TagManager
  attr_reader :events
  def initialize(model); @model = model; @events = []; end
  def emit(event, payload); @events << [event, payload]; end
  def check_model!; end
  def last(event); @events.reverse.find { |e, _| e == event }&.last; end
  def messages; @events.select { |e, _| e == 'message' }.map { |_, p| p[:text] }; end
end
def world
  fa = FFolder.new(1, 'A. ARCHITECTURAL'); fa1 = FFolder.new(2, 'Con', true, fa); fb = FFolder.new(3, 'S. STRUCTURAL')
  tags = [FTag.new(10, 'A. WALL', true, fa1), FTag.new(11, 'A. DOOR', true, fa), FTag.new(12, 'S. BEAM', false, fb), FTag.new(13, 'Untagged', true, nil)]
  model = FModel.new(FTags.new(tags, [fa, fb]))
  [model, Probe.new(model), tags, [fa, fa1, fb]]
end

model, probe, tags, fold = world
tree = probe.tag_tree_state
ok('tag_tree_state: đủ thư mục (kể cả lồng) và tag, kèm thư mục cha / chứa, không lộ đối tượng SketchUp', tree[:supported] && tree[:folders].map { |f| [f[:id], f[:name], f[:parent_id]] } == [[1, 'A. ARCHITECTURAL', nil], [2, 'Con', 1], [3, 'S. STRUCTURAL', nil]] && tree[:layers].map { |l| [l[:id], l[:folder_id]] } == [[10, 2], [11, 1], [12, 3], [13, nil]] && tree[:layers].none? { |l| l.key?(:object) } && tree[:isolated].nil?)
ok('tag_tree_state: sinh được JSON (gửi cho giao diện)', JSON.parse(JSON.generate(tree))['layers'].size == 4)
ok('tag_tree_state: hiển thị đúng như model', tree[:layers].map { |l| l[:visible] } == [true, true, false, true])

probe.tm_visible('kind' => 'tag', 'id' => 12, 'visible' => true)
ok('tm_visible tag: bật tag, một bước hoàn tác, gửi lại cây', tags[2].visible? && $transactions.last == 'VGD BIM · Hiện tag' && probe.last('tag_tree')[:layers][2][:visible] == true)
probe.tm_visible('kind' => 'folder', 'id' => 1, 'visible' => false)
ok('tm_visible folder: ẩn thư mục', !fold[0].visible? && $transactions.last == 'VGD BIM · Ẩn tag')
ok('tm_visible: dữ liệu sai bị từ chối, không đổi model', error_of { probe.tm_visible('kind' => 'tag', 'id' => '10', 'visible' => false) }.include?('không hợp lệ') && error_of { probe.tm_visible('kind' => 'tag', 'id' => 10, 'visible' => 'x') }.include?('không hợp lệ') && error_of { probe.tm_visible('kind' => 'tag', 'id' => 99, 'visible' => false) }.include?('làm mới') && tags[0].visible?)

model, probe, tags, fold = world
before = $transactions.size
probe.tm_isolate('kind' => 'tag', 'id' => 10)
ok('cô lập tag: chỉ tag đó và thư mục chứa nó hiện, một bước hoàn tác', tags.map(&:visible?) == [true, false, false, false] && fold.map(&:visible?) == [true, true, false] && $transactions.size == before + 1 && $transactions.last == 'VGD BIM · Cô lập tag')
ok('cô lập tag: giao diện biết đang cô lập mục nào, có thông báo', probe.last('tag_tree')[:isolated] == {kind: 'tag', id: 10, name: 'A. WALL'} && probe.messages.last.include?('Đã cô lập tag "A. WALL" (ẩn 3 tag khác)'))
probe.tm_isolate('kind' => 'folder', 'id' => 3)
ok('đang cô lập thì chọn mục khác: chuyển sang mục mới', tags.map(&:visible?) == [false, false, true, false] && fold.map(&:visible?) == [false, false, true] && probe.last('tag_tree')[:isolated][:id] == 3)
probe.tm_isolate('kind' => 'folder', 'id' => 3)
ok('bấm lại mục đang cô lập: khôi phục đúng hiển thị gốc từ trước khi cô lập (kể cả tag đã ẩn sẵn)', tags.map(&:visible?) == [true, true, false, true] && fold.map(&:visible?) == [true, true, true] && probe.last('tag_tree')[:isolated].nil? && probe.messages.last.include?('khôi phục'))
probe.tm_isolate('kind' => 'tag', 'id' => 11)
probe.tm_isolate('restore' => true)
ok('lệnh restore: khôi phục không cần chỉ mục', tags.map(&:visible?) == [true, true, false, true] && probe.last('tag_tree')[:isolated].nil?)
ok('restore khi chưa cô lập: báo lỗi, không đổi gì', error_of { probe.tm_isolate('restore' => true) }.include?('Chưa cô lập') && tags.map(&:visible?) == [true, true, false, true])
probe.tm_isolate('kind' => 'tag', 'id' => 10)
model2 = FModel.new(FTags.new([FTag.new(10, 'Khác')], []))
probe.instance_variable_set(:@model, model2)
ok('đổi sang model khác: không còn coi là đang cô lập (tránh khôi phục nhầm)', probe.tag_tree_state[:isolated].nil?)
ok('cô lập mục không có / dữ liệu sai: báo lỗi', error_of { probe.tm_isolate('kind' => 'tag', 'id' => 99) }.include?('làm mới') && error_of { probe.tm_isolate('kind' => 'tag', 'id' => 'a') }.include?('không hợp lệ'))

# SketchUp cũ không có thư mục tag: chỉ liệt kê tag phẳng
old = FModel.new(OldTags.new([FTag.new(1, 'A'), FTag.new(2, 'B', false)]))
old_probe = Probe.new(old)
old_tree = old_probe.tag_tree_state
ok('SketchUp cũ không có thư mục tag: supported = false, tag liệt kê phẳng', old_tree[:supported] == false && old_tree[:folders].empty? && old_tree[:layers].map { |l| l[:folder_id] } == [nil, nil])
old.layers.to_a[1].visible = true
old_probe.tm_isolate('kind' => 'tag', 'id' => 1)
isolated = old.layers.to_a.map(&:visible?)
old_probe.tm_isolate('kind' => 'tag', 'id' => 1)
ok('SketchUp cũ: vẫn cô lập và khôi phục được tag', isolated == [true, false] && old.layers.to_a.map(&:visible?) == [true, true])

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
