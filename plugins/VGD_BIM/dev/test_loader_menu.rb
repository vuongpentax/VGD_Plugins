$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def file_loaded?(f); ($loaded_files ||= {})[f]; end
def file_loaded(f); ($loaded_files ||= {})[f] = true; end
class SketchupExtension
  attr_accessor :description, :version, :creator
  attr_reader :name, :path
  def initialize(name, path); @name = name; @path = path; end
end
module Sketchup
  class SelectionObserver; end
  class AppObserver; end
  class Group; end; class ComponentInstance < Group; end; class Face; end; class Color; def initialize(*); end; end
  class Model; def selection; Struct.new(:x) { def any?; false; end; def to_a; []; end }.new(nil); end; end
  def self.register_extension(*); true; end
  def self.active_model; Model.new; end
  def self.read_default(*); nil; end
  def self.write_default(*); true; end
end
module UI
  class HtmlDialog
    STYLE_DIALOG = 1
    def initialize(options); ($dialogs ||= []) << options[:dialog_title]; end
    def set_file(*); end
    def add_action_callback(*); end
    def set_on_closed(*); end
    def visible?; false; end
    def show; end
  end
  class Toolbar; attr_reader :items; def initialize(n); @name = n; @items = []; ($toolbars ||= []) << self; end; def add_item(c); @items << c; end; def restore; end; end
  class Command; attr_accessor :tooltip, :status_bar_text, :small_icon, :large_icon; attr_reader :block; def initialize(n, &b); @name = n; @block = b; end; end
  class MenuNode
    attr_reader :name, :items, :subs
    def initialize(name); @name = name; @items = []; @subs = {}; end
    def add_submenu(n); @subs[n] ||= MenuNode.new(n); end
    def add_item(n, &b); @items << [n, b]; n; end
  end
  MENU_ROOT = {}
  def self.menu(n); MENU_ROOT[n] ||= MenuNode.new(n); end
  def self.messagebox(text, *); ($boxes ||= []) << text; 0; end
  def self.add_context_menu_handler(&b); end
  def self.start_timer(*); 0; end
  def self.stop_timer(*); end
end
$LOAD_PATH.unshift File.expand_path('stubs', __dir__)
Dir.chdir(__dir__)
ext_loader = File.expand_path('../runtime/vgd_bim.rb', __dir__)
require ext_loader
ext = Sketchup.respond_to?(:register_extension) ? nil : nil
loader = File.expand_path('../runtime/vgd_bim/loader.rb', __dir__)
$opened = []
require loader rescue (puts "load error: #{$!.class}: #{$!.message}"; raise)
vgd = UI::MENU_ROOT['Extensions'].subs['VGD'].subs['VGD BIM']
ok('menu Extensions > VGD > VGD BIM: Mở bảng khối lượng, Đổi tên, Soạn tag, Hút / đổ tag và Tải lại code', vgd && vgd.items.map(&:first) == ['Mở bảng khối lượng', 'Đổi tên', 'Soạn tag', 'Hút / đổ tag', 'Tải lại code'])
ok('menu VGD BIM không có submenu', vgd && vgd.subs.empty?)
VGD::BIM.define_singleton_method(:open_panel) { |mode| $opened << mode }
vgd.items.find { |n, _| n == 'Mở bảng khối lượng' }[1].call
ok('bấm Mở bảng khối lượng mở thẳng bảng khối lượng', $opened == ['table'])
VGD::BIM.define_singleton_method(:open_rename) { $opened << 'rename' }
vgd.items.find { |n, _| n == 'Đổi tên' }[1].call
ok('bấm Đổi tên mở cửa sổ Đổi tên riêng', $opened == ['table', 'rename'])
VGD::BIM.define_singleton_method(:open_tags) { $opened << 'tags' }
vgd.items.find { |n, _| n == 'Soạn tag' }[1].call
ok('bấm Soạn tag mở cửa sổ Soạn tag riêng', $opened.last == 'tags')
VGD::BIM.define_singleton_method(:toggle_tag_paint) { $opened << 'paint' }
vgd.items.find { |n, _| n == 'Hút / đổ tag' }[1].call
ok('mục Hút / đổ tag (đặt phím tắt được) bật công cụ', $opened.last == 'paint')
VGD::BIM.singleton_class.send(:remove_method, :toggle_tag_paint)
buttons = $toolbars.first.items
ok('thanh công cụ VGD BIM: Bảng khối lượng, Đổi tên, Soạn tag', buttons.map(&:tooltip) == ['VGD_BIM · Bảng khối lượng', 'VGD_BIM · Đổi tên', 'VGD_BIM · Soạn tag'])
ok('mỗi nút có file icon SVG có thật', buttons.all? { |b| b.small_icon == b.large_icon && b.small_icon.end_with?('.svg') && File.file?(b.small_icon) })
$opened.clear
buttons[1].block.call
buttons[2].block.call
ok('bấm nút Đổi tên / Soạn tag trên thanh công cụ mở đúng cửa sổ', $opened == ['rename', 'tags'])
buttons[0].block.call
ok('bấm nút Bảng khối lượng khi cửa sổ đang đóng: mở Bảng khối lượng', $opened.last == 'table')
# Bấm lại nút khi cửa sổ đang mở: đóng cửa sổ đó, không mở thêm.
class ToggleStub
  attr_reader :closes
  def initialize(visible); @visible = visible; @closes = 0; end
  def closed?; @closes > 0; end
  def visible?; @visible; end
  def close; @closes += 1; end
end
[[:@panel, 0, 'table'], [:@rename, 1, 'rename'], [:@tags, 2, 'tags']].each do |ivar, index, label|
  open_window = ToggleStub.new(true)
  VGD::BIM.instance_variable_set(ivar, open_window)
  $opened.clear
  buttons[index].block.call
  ok("bấm lại nút #{label} khi cửa sổ đang mở: đóng cửa sổ, không mở thêm", open_window.closes == 1 && $opened.empty?)
  buttons[index].block.call
  ok("bấm nút #{label} lần nữa (cửa sổ đã đóng): mở lại", $opened == [label])
  VGD::BIM.instance_variable_set(ivar, nil)
end
VGD::BIM.singleton_class.send(:remove_method, :open_tags)
ok('phiên bản theo chuẩn repo x.y.z hoặc x.y.z-beta.N, không có chữ v', VGD::BIM::VERSION.match?(/\A\d+\.\d+\.\d+(-beta\.\d+)?\z/))
# Tải lại code: thành công, và lỗi cú pháp được chặn trước khi nạp (giữ nguyên bản đang chạy).
reload_item = vgd.items.find { |n, _| n == 'Tải lại code' }
ok('có mục Tải lại code', !reload_item.nil?)
count_before = vgd.items.size
ok('tải lại thành công', VGD::BIM.reload == true && $boxes.last.to_s.start_with?('Đã tải lại VGD BIM'))
ok('tải lại không nhân đôi mục menu', vgd.items.size == count_before)
loaded = []
Kernel.send(:alias_method, :__orig_load_for_test, :load)
Kernel.send(:define_method, :load) { |*args, **kw| loaded << args.first; __orig_load_for_test(*args, **kw) }
# Đang chụp ảnh hoặc đang vẽ khung xem trước: không tải lại code, báo rõ việc đang làm, không nạp file nào (CLAUDE.md, mục tải lại).
class BusyPanel
  def initialize(reason); @reason = reason; end
  def closed?; false; end
  def busy_reason; @reason; end
end
[['đang chụp ảnh', 'chụp'], ['đang vẽ khung xem trước', 'vẽ']].each do |reason, label|
  VGD::BIM.instance_variable_set(:@panel, BusyPanel.new(reason))
  before = loaded.size
  busy_result = VGD::BIM.reload
  ok("tải lại khi #{label}: không nạp, báo việc đang làm và hướng dẫn chờ", busy_result == false && $boxes.last.include?(reason) && $boxes.last.include?('Hãy chờ xong rồi tải lại code.') && loaded.size == before)
end
VGD::BIM.instance_variable_set(:@panel, nil)
# Cửa sổ Đổi tên đang mở: tải lại thì đóng rồi mở lại (đang đóng thì không mở).
class RenameStub
  attr_reader :closes
  def initialize; @closes = 0; end
  def closed?; @closes > 0; end
  def close; @closes += 1; end
  def busy_reason; nil; end
end
VGD::BIM.singleton_class.send(:remove_method, :open_rename)
stub = RenameStub.new
VGD::BIM.instance_variable_set(:@rename, stub)
$dialogs = []
reloaded = VGD::BIM.reload
ok('tải lại: đóng cửa sổ Đổi tên đang mở rồi mở lại', reloaded == true && stub.closes == 1 && $dialogs == ['VGD BIM · Đổi tên'] && !VGD::BIM.instance_variable_get(:@rename).closed?)
VGD::BIM.instance_variable_set(:@rename, nil)
$dialogs.clear
VGD::BIM.reload
ok('tải lại khi cửa sổ Đổi tên đang đóng: không tự mở', $dialogs.empty?)
VGD::BIM.instance_variable_set(:@tags, RenameStub.new)
$dialogs.clear
VGD::BIM.reload
ok('tải lại: đóng rồi mở lại cửa sổ Soạn tag đang mở', $dialogs == ['VGD BIM · Soạn tag'])
VGD::BIM.instance_variable_set(:@tags, nil)
loaded.clear
orig_compile = RubyVM::InstructionSequence.method(:compile_file)
RubyVM::InstructionSequence.define_singleton_method(:compile_file) do |path, *rest|
  raise SyntaxError, 'lỗi cú pháp giả lập' if path.end_with?('/core/data.rb')
  orig_compile.call(path, *rest)
end
result = VGD::BIM.reload
RubyVM::InstructionSequence.define_singleton_method(:compile_file) { |path, *rest| orig_compile.call(path, *rest) }
Kernel.send(:define_method, :load) { |*args, **kw| __orig_load_for_test(*args, **kw) }
ok('lỗi cú pháp: báo lỗi, giữ nguyên bản đang chạy, không nạp file nào', result == false && $boxes.last.start_with?('Tải lại thất bại') && $boxes.last.include?('giữ nguyên') && loaded.empty?)
puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
