# Test loader và Tải lại code của VGD Structure (mô phỏng SketchUp, không thay SketchUp).
# Chạy: ruby dev/test_reload.rb. Kiểm tra: menu, tải lại nhiều lần không nhân đôi menu, lỗi cú pháp giữ bản đang chạy, đang bận thì từ chối.
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
  def self.register_extension(ext, _load); ($extensions ||= []) << ext; true; end
end
module UI
  class HtmlDialog
    STYLE_DIALOG = 1
    def initialize(**opts); ($dialogs ||= []) << self; @visible = false; end
    def set_file(*); end
    def add_action_callback(*); end
    def execute_script(*); end
    def show; @visible = true; end
    def visible?; @visible; end
    def bring_to_front; end
    def close; @visible = false; $closed = ($closed || 0) + 1; end
  end
  class Toolbar
    def initialize(name); ($toolbars ||= []) << name; end
    def add_item(*); end
    def restore; end
  end
  class Command
    attr_accessor :tooltip, :status_bar_text, :small_icon, :large_icon
    def initialize(name, &block); ($commands ||= []) << [name, block]; end
  end
  class MenuNode
    attr_reader :name, :items, :subs
    def initialize(name); @name = name; @items = []; @subs = {}; end
    def add_submenu(n); @subs[n] ||= MenuNode.new(n); end
    def add_item(n, &b); @items << [n, b]; n; end
  end
  MENU_ROOT = {}
  def self.menu(n); MENU_ROOT[n] ||= MenuNode.new(n); end
  def self.messagebox(text, *); ($boxes ||= []) << text; 0; end
end
$LOAD_PATH.unshift File.expand_path('stubs', __dir__)
require File.expand_path('../runtime/vgd_structure.rb', __dir__)
require File.expand_path('../runtime/vgd_structure/loader.rb', __dir__)
ext = $extensions.first
ok("extension tên 'VGD Structure', nạp vgd_structure/loader", ext && ext.name == 'VGD Structure' && ext.path == 'vgd_structure/loader')
ok('phiên bản theo chuẩn repo x.y.z hoặc x.y.z-beta.N, không có chữ v', VGD::Structure::VERSION.match?(/\A\d+\.\d+\.\d+(-beta\.\d+)?\z/))
vgd = UI::MENU_ROOT['Extensions'].subs['VGD']
mine = vgd && vgd.subs['VGD Structure']
ok('chỉ một menu VGD, bên trong menu con VGD Structure có Lưới trục và Tải lại code', UI::MENU_ROOT['Extensions'].subs.keys == ['VGD'] && mine && mine.items.map(&:first) == ['Lưới trục', 'Tải lại code'])
ok("toolbar 'VGD STR' (dạng VGD + 3 chữ in hoa) có Lưới trục và 7 nút vẽ, icon SVG tồn tại", $toolbars == ['VGD STR'] && $commands.size == 9 && File.exist?(File.join(VGD::Structure::ROOT, 'assets', 'icons', 'grid.svg')) && %w[column beam wall door window slab ceiling stair].all? { |t| File.exist?(File.join(VGD::Structure::ROOT, 'assets', 'icons', "draw_#{t}.svg")) })
mine.items[0][1].call
ok('menu Lưới trục và nút toolbar mở cùng một cửa sổ, gọi lại không mở thêm', $dialogs.size == 1 && $dialogs[0].visible? && ($commands[0][1].call; $dialogs.size == 1))
ok('Schema nạp được: dictionary, đủ các loại (kể cả cầu thang, lan can), mỗi loại có tag', VGD::Structure::Schema::DICTIONARY == 'VGD_STRUCT' && VGD::Structure::Schema::KINDS.sort == VGD::Structure::Schema::TAGS.keys.sort)
mine.items.last[1].call
ok('bấm Tải lại code: báo đúng chữ chuẩn kèm phiên bản', $boxes.last == "Đã tải lại VGD Structure #{VGD::Structure::VERSION}.")
3.times { VGD::Structure.reload }
ok('tải lại nhiều lần không nhân đôi menu, toolbar, extension', mine.items.size == 2 && vgd.subs.size == 1 && $extensions.size == 1 && $toolbars.size == 1 && $commands.size == 9)
ok('tải lại khi cửa sổ đang mở: đóng rồi mở lại một cửa sổ mới (đang mở)', $closed.to_i >= 1 && $dialogs.size >= 2 && $dialogs.last.visible?)
VGD::Structure.instance_variable_get(:@panel).close
count = $dialogs.size
VGD::Structure.reload
ok('tải lại khi cửa sổ đang đóng: không tự mở cửa sổ', $dialogs.size == count)
# Lỗi cú pháp: chặn trước khi nạp, không nạp file nào
loaded = []
Kernel.send(:alias_method, :__orig_load_for_test, :load)
Kernel.send(:define_method, :load) { |*args, **kw| loaded << args.first; __orig_load_for_test(*args, **kw) }
orig_compile = RubyVM::InstructionSequence.method(:compile_file)
RubyVM::InstructionSequence.define_singleton_method(:compile_file) do |path, *rest|
  raise SyntaxError, 'lỗi cú pháp giả lập' if path.end_with?('/core/schema.rb')
  orig_compile.call(path, *rest)
end
result = VGD::Structure.reload
ok('lỗi cú pháp: báo lỗi, giữ nguyên bản đang chạy, không nạp file nào', result == false && $boxes.last.start_with?('Tải lại thất bại:') && $boxes.last.end_with?('Bản đang chạy được giữ nguyên.') && loaded.empty?)
RubyVM::InstructionSequence.define_singleton_method(:compile_file) { |path, *rest| orig_compile.call(path, *rest) }
# Lỗi khi đang nạp: báo hãy mở lại SketchUp
Kernel.send(:define_method, :load) { |*args, **kw| raise 'hỏng giữa chừng' if args.first.end_with?('/core/schema.rb'); __orig_load_for_test(*args, **kw) }
result = VGD::Structure.reload
Kernel.send(:define_method, :load) { |*args, **kw| __orig_load_for_test(*args, **kw) }
ok('lỗi khi đang nạp: báo lỗi và dòng cuối hãy mở lại SketchUp', result == false && $boxes.last.start_with?('Tải lại thất bại:') && $boxes.last.end_with?('Hãy mở lại SketchUp nếu giao diện báo lỗi.'))
# Thiếu file: giữ bản đang chạy
real_files = VGD::Structure::FILES
VGD::Structure.send(:remove_const, :FILES)
VGD::Structure.const_set(:FILES, %w[core/khong_co].freeze)
result = VGD::Structure.reload
VGD::Structure.send(:remove_const, :FILES)
VGD::Structure.const_set(:FILES, real_files)
ok('thiếu file: báo lỗi, giữ bản đang chạy', result == false && $boxes.last.end_with?('Bản đang chạy được giữ nguyên.'))
# Đang bận: từ chối, nói rõ việc đang làm
VGD::Structure.define_singleton_method(:busy_reason) { 'đang dựng khối tầng 2' }
before = loaded.size
result = VGD::Structure.reload
ok('đang bận: từ chối, nêu việc đang làm và hướng dẫn chờ', result == false && $boxes.last.include?('đang dựng khối tầng 2') && $boxes.last.end_with?('Hãy chờ xong rồi tải lại code.') && loaded.size == before)
puts $fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
