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
  class Group; end; class ComponentInstance < Group; end; class Face; end; class Color; def initialize(*); end; end
  class Model; def selection; Struct.new(:x) { def any?; false; end; def to_a; []; end }.new(nil); end; end
  def self.register_extension(*); true; end
  def self.active_model; Model.new; end
  def self.read_default(*); nil; end
  def self.write_default(*); true; end
end
module UI
  class HtmlDialog; STYLE_DIALOG = 1; end
  class Toolbar; def initialize(n); @name = n; end; def add_item(*); end; def restore; end; end
  class Command; attr_accessor :tooltip, :status_bar_text, :small_icon, :large_icon; def initialize(n, &b); @name = n; end; end
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
ok('menu Extensions > VGD > VGD BIM: Mở bảng khối lượng và Tải lại code', vgd && vgd.items.map(&:first) == ['Mở bảng khối lượng', 'Tải lại code'])
ok('menu VGD BIM không có submenu', vgd && vgd.subs.empty?)
VGD::BIM.define_singleton_method(:open_panel) { |mode| $opened << mode }
vgd.items.find { |n, _| n == 'Mở bảng khối lượng' }[1].call
ok('bấm Mở bảng khối lượng mở thẳng bảng khối lượng', $opened == ['table'])
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
