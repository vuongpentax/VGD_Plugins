# Test menu, thanh công cụ và "Tải lại code" của VGD Transform với SketchUp giả lập:
# không nhân đôi mục menu khi tải lại nhiều lần; lỗi cú pháp thì giữ nguyên bản đang chạy; đang bận thì không nạp lại.
# Chạy: ruby dev/test_reload.rb (từ plugins/VGD_Transform)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def file_loaded?(f); ($loaded_files ||= {})[f]; end
def file_loaded(f); ($loaded_files ||= {})[f] = true; end
class SketchupExtension
  attr_accessor :description, :version, :creator
  attr_reader :name, :path
  def initialize(name, path); @name = name; @path = path; end
end
module Geom; class Transformation; def initialize(*); end; end; class Vector3d; def initialize(*); end; end; class Point3d; def initialize(*); end; end; end
module Sketchup
  class SelectionObserver; end
  class ModelObserver; end
  class Group; end
  class ComponentInstance < Group; end
  class Model; def selection; @selection ||= Struct.new(:x) { def add_observer(*); end; def remove_observer(*); end; def to_a; []; end }.new(nil); end; def active_path; []; end; end
  def self.register_extension(*); true; end
  def self.active_model; Model.new; end
end
module UI
  class HtmlDialog; STYLE_DIALOG = 1; end
  class Toolbar; attr_reader :name, :items; def initialize(n); @name = n; @items = []; UI.toolbars << self; end; def add_item(i); @items << i; end; def restore; end; end
  def self.toolbars; @toolbars ||= []; end
  class Command; attr_accessor :tooltip, :status_bar_text, :small_icon, :large_icon; def initialize(n, &b); @name = n; @block = b; end; end
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
  def self.reset_toolbars; @toolbars = []; end
end
$LOAD_PATH.unshift File.expand_path('stubs', __dir__)
RUNTIME_DIR = File.expand_path('../runtime', __dir__)
require File.join(RUNTIME_DIR, 'vgd_transform')
require File.join(RUNTIME_DIR, 'vgd_transform', 'loader') # SketchUp nạp loader khi bật extension

menu = UI::MENU_ROOT['Extensions'].subs['VGD']
ok('menu Extensions > VGD > VGD Transform có đúng hai mục', menu && menu.subs['VGD Transform'] && menu.subs['VGD Transform'].items.map(&:first) == ['Mở bảng biến đổi', 'Tải lại code'])
ok('không có mục nào ngoài hai mục trên', menu.subs['VGD Transform'].items.size == 2)

# Tải lại nhiều lần: không nhân đôi mục menu
before = menu.subs['VGD Transform'].items.size
3.times { VGD::Transform.reload }
ok('tải lại 3 lần: không nhân đôi mục menu', menu.subs['VGD Transform'].items.size == before)
ok('tải lại thành công: báo đúng chữ chuẩn', $boxes.last == "Đã tải lại VGD Transform #{VGD::Transform::VERSION}.")

# Đang bận (đang xử lý dở): không nạp lại, báo việc đang làm và hướng dẫn chờ
class BusyPanel
  def closed?; false; end
  def busy_reason; 'đang xử lý'; end
end
VGD::Transform.instance_variable_set(:@panel, BusyPanel.new)
loaded = []
Kernel.send(:alias_method, :__orig_load_for_test, :load)
Kernel.send(:define_method, :load) { |*args, **kw| loaded << args.first; __orig_load_for_test(*args, **kw) }
busy_result = VGD::Transform.reload
ok('đang bận: không tải lại, báo việc đang làm và hướng dẫn chờ', busy_result == false && $boxes.last.include?('đang xử lý') && $boxes.last.include?('Hãy chờ xong rồi tải lại code.') && loaded.empty?)
VGD::Transform.instance_variable_set(:@panel, nil)

# Lỗi cú pháp: chặn trước khi nạp file nào, giữ nguyên bản đang chạy
orig_compile = RubyVM::InstructionSequence.method(:compile_file)
RubyVM::InstructionSequence.define_singleton_method(:compile_file) do |path, *rest|
  raise SyntaxError, 'lỗi cú pháp giả lập' if path.end_with?('/core/model_ops.rb')
  orig_compile.call(path, *rest)
end
loaded.clear
result = VGD::Transform.reload
RubyVM::InstructionSequence.define_singleton_method(:compile_file) { |path, *rest| orig_compile.call(path, *rest) }
Kernel.send(:define_method, :load) { |*args, **kw| __orig_load_for_test(*args, **kw) }
ok('lỗi cú pháp: báo thất bại, giữ nguyên bản đang chạy, không nạp file nào', result == false && $boxes.last.start_with?('Tải lại thất bại') && $boxes.last.include?('giữ nguyên') && loaded.empty?)
ok('sau lỗi cú pháp: chức năng cũ vẫn chạy', VGD::Transform.respond_to?(:open_panel) && VGD::Transform::ModelOps.respond_to?(:apply))

# Thanh công cụ VGD TRF: ba nút Dời, Xoay, Scale như 3ds Max, icon là file có thật
bar = UI.toolbars.find { |t| t.name == 'VGD TRF' }
names = bar ? bar.items.map { |c| c.instance_variable_get(:@name) } : []
ok('thanh công cụ VGD TRF có ba nút Dời, Xoay, Scale', names == %w[VGD_TRANSFORM_MOVE VGD_TRANSFORM_ROTATE VGD_TRANSFORM_SCALE])
ok('icon của ba nút là file SVG có thật', bar && bar.items.all? { |c| c.small_icon.end_with?('.svg') && File.file?(c.small_icon) && c.small_icon == c.large_icon })
ok('tải lại nhiều lần không thêm thanh công cụ', UI.toolbars.count { |t| t.name == 'VGD TRF' } == 1)
puts $fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
