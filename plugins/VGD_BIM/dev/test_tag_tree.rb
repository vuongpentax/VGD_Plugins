# Test quản lý tag (core/tag_tree.rb, ui/tag_manager.rb): cây thư mục / tag, bật tắt hiển thị, cô lập và khôi phục. SketchUp giả lập đơn giản;
# API thư mục tag (SketchUp 2021+) chưa kiểm được trong SketchUp thật. Chạy: ruby dev/test_tag_tree.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
module Sketchup; class Group; end; class ComponentInstance; end; class Face; end
  class Color; attr_reader :r, :g, :b; def initialize(r, g, b); @r = r; @g = g; @b = b; end; def to_a; [@r, @g, @b, 255]; end; end
end
module VGD; module BIM
  def self.log(_m); end
  module Data
    def self.transaction(_model, name = nil); $transactions << name; yield; end
  end
  module UI; end
end; end
$transactions = []
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] ||= Dir.mktmpdir('vgd_bim_tag_tree')
%w[storage measure settings].each { |f| require File.join(ROOT, "core/#{f}") }
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
class FStyle; attr_reader :name; def initialize(name); @name = name; end; end
class FTag
  attr_reader :persistent_id, :name
  attr_accessor :folder, :color, :line_style
  def initialize(id, name, visible = true, folder = nil); @persistent_id = id; @name = name; @visible = visible; @folder = folder; @color = Sketchup::Color.new(10, 20, 30); @line_style = nil; end
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
FModel = Struct.new(:layers) do
  def rendering_options; @options ||= {'DisplayColorByLayer' => false}; end
  def line_styles; @styles ||= Struct.new(:to_a).new([FStyle.new('Solid Line'), FStyle.new('Dashed Line')]); end
end
OldModel = Struct.new(:layers) { def rendering_options; @options ||= {}; end }
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
old = OldModel.new(OldTags.new([FTag.new(1, 'A'), FTag.new(2, 'B', false)]))
old_probe = Probe.new(old)
old_tree = old_probe.tag_tree_state
ok('SketchUp cũ không có thư mục tag: supported = false, tag liệt kê phẳng', old_tree[:supported] == false && old_tree[:folders].empty? && old_tree[:layers].map { |l| l[:folder_id] } == [nil, nil])
old.layers.to_a[1].visible = true
old_probe.tm_isolate('kind' => 'tag', 'id' => 1)
isolated = old.layers.to_a.map(&:visible?)
old_probe.tm_isolate('kind' => 'tag', 'id' => 1)
ok('SketchUp cũ: vẫn cô lập và khôi phục được tag', isolated == [true, false] && old.layers.to_a.map(&:visible?) == [true, true])

# ---- Màu, kiểu nét, tô màu theo tag ----
ok('parse_color / hex_color: chấp nhận #rrggbb (hoa thường), đổi qua lại đúng', T.parse_color('#0A1b2C') == [10, 27, 44] && T.hex_color([10, 27, 44]) == '#0a1b2c' && T.hex_color([300, -5, 7.9]) == '#ff0007')
ok('parse_color: dạng sai bị từ chối', %w[red #12345 #1234567 #gggggg 123456].all? { |bad| error_of { T.parse_color(bad) } == 'Màu không hợp lệ.' } && error_of { T.parse_color(nil) } == 'Màu không hợp lệ.')
model, probe, tags, = world
tree = probe.tag_tree_state
ok('tag_tree_state: mỗi tag có màu (#rrggbb) và kiểu nét; có danh sách kiểu nét và trạng thái tô màu theo tag', tree[:layers][0][:color] == '#0a141e' && tree[:layers][0][:line_style] == '' && tree[:styles_supported] && tree[:line_styles] == ['Solid Line', 'Dashed Line'] && tree[:color_by_tag] == false)
probe.tm_color('id' => 10, 'color' => '#FF8800')
ok('tm_color: đổi màu tag, một bước hoàn tác, gửi lại cây', tags[0].color.to_a.first(3) == [255, 136, 0] && $transactions.last == 'VGD BIM · Đổi màu tag' && probe.last('tag_tree')[:layers][0][:color] == '#ff8800')
ok('tm_color: màu sai / tag không có / mã sai bị từ chối, không đổi', error_of { probe.tm_color('id' => 10, 'color' => 'red') } == 'Màu không hợp lệ.' && error_of { probe.tm_color('id' => 99, 'color' => '#000000') }.include?('làm mới') && error_of { probe.tm_color('id' => '10', 'color' => '#000000') }.include?('không hợp lệ') && tags[0].color.to_a.first(3) == [255, 136, 0])
probe.tm_line_style('id' => 11, 'style' => 'Dashed Line')
ok('tm_line_style: đổi kiểu nét của tag, một bước hoàn tác', tags[1].line_style.name == 'Dashed Line' && $transactions.last == 'VGD BIM · Đổi kiểu nét tag' && probe.last('tag_tree')[:layers][1][:line_style] == 'Dashed Line')
ok('tm_line_style: kiểu nét không có trong model / tag không có bị từ chối', error_of { probe.tm_line_style('id' => 11, 'style' => 'Lạ') } == 'Kiểu nét không có trong model.' && error_of { probe.tm_line_style('id' => 99, 'style' => 'Solid Line') }.include?('làm mới') && tags[1].line_style.name == 'Dashed Line')
probe.tm_color_by_tag('enabled' => true)
ok('tm_color_by_tag: bật chế độ tô màu theo tag của SketchUp và báo lại', model.rendering_options['DisplayColorByLayer'] == true && probe.last('tag_tree')[:color_by_tag] == true)
probe.tm_color_by_tag('enabled' => false)
ok('tm_color_by_tag: tắt được; giá trị sai bị từ chối', model.rendering_options['DisplayColorByLayer'] == false && error_of { probe.tm_color_by_tag('enabled' => 'x') }.include?('không hợp lệ'))
ok('SketchUp cũ không có kiểu nét: không báo hỗ trợ, tm_line_style báo lỗi rõ', old_tree[:styles_supported] == false && old_tree[:line_styles].empty? && error_of { old_probe.tm_line_style('id' => 1, 'style' => 'x') }.include?('cần SketchUp 2021'))
ok('tag_tree_state vẫn sinh được JSON sau khi thêm màu / kiểu nét', JSON.parse(JSON.generate(probe.tag_tree_state))['layers'][0]['color'] == '#ff8800')

# ---- Ghim, gần đây, kéo thả vào thư mục ----
File.delete(File.join(VGD::BIM::Storage.dir, 'settings.json')) if File.exist?(File.join(VGD::BIM::Storage.dir, 'settings.json'))
model, probe, tags, fold = world
ok('tag_tree_state có danh sách ghim và gần đây (rỗng lúc đầu)', probe.tag_tree_state[:pinned] == [] && probe.tag_tree_state[:recent] == [])
probe.tm_pin('name' => 'A. WALL', 'pinned' => true)
ok('tm_pin: ghim tag, gửi lại cây kèm danh sách ghim, lưu trên máy', probe.last('tag_tree')[:pinned] == ['A. WALL'] && VGD::BIM::Settings.read['pinned_tags'] == ['A. WALL'])
probe.tm_pin('name' => 'A. WALL', 'pinned' => false)
ok('tm_pin: bỏ ghim', probe.last('tag_tree')[:pinned] == [])
ok('tm_pin: giá trị sai bị từ chối', error_of { probe.tm_pin('name' => 'A. WALL', 'pinned' => 'x') }.include?('không hợp lệ') && error_of { probe.tm_pin('name' => '', 'pinned' => true) }.include?('chọn'))
VGD::BIM::Settings.touch_recent('A. DOOR')
ok('tag_tree_state phản ánh tag gần đây', probe.tag_tree_state[:recent] == ['A. DOOR'])

model, probe, tags, fold = world
probe.tm_move('id' => 10, 'folder_id' => 3)
ok('tm_move: đưa tag vào thư mục, một bước hoàn tác, gửi lại cây', tags[0].folder.equal?(fold[2]) && $transactions.last == 'VGD BIM · Chuyển tag vào thư mục' && probe.last('tag_tree')[:layers][0][:folder_id] == 3 && probe.messages.last.include?('vào thư mục "S. STRUCTURAL"'))
probe.tm_move('id' => 10, 'folder_id' => nil)
ok('tm_move: đưa tag ra gốc (folder_id nil)', tags[0].folder.nil? && probe.last('tag_tree')[:layers][0][:folder_id].nil? && probe.messages.last.include?('ra ngoài thư mục'))
before = $transactions.size
probe.tm_move('id' => 11, 'folder_id' => 1)
ok('tm_move: tag đã nằm sẵn trong thư mục đó thì không làm gì, không tạo bước hoàn tác', $transactions.size == before && probe.messages.last == 'Tag đã nằm sẵn ở đó.')
ok('tm_move: tag Untagged không xếp vào thư mục', error_of { probe.tm_move('id' => 13, 'folder_id' => 1) }.include?('Untagged') && tags[3].folder.nil?)
ok('tm_move: tag / thư mục không có hoặc mã sai bị từ chối, không đổi', error_of { probe.tm_move('id' => 99, 'folder_id' => 1) }.include?('làm mới') && error_of { probe.tm_move('id' => 10, 'folder_id' => 99) }.include?('làm mới') && error_of { probe.tm_move('id' => 10, 'folder_id' => 'x') }.include?('không hợp lệ') && error_of { probe.tm_move('id' => '10', 'folder_id' => 1) }.include?('không hợp lệ') && tags[0].folder.nil?)
old_move = Probe.new(OldModel.new(OldTags.new([FTag.new(1, 'A')])))
ok('SketchUp cũ không có thư mục tag: tm_move báo lỗi rõ', error_of { old_move.tm_move('id' => 1, 'folder_id' => nil) }.include?('cần SketchUp 2021'))

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
