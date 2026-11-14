# encoding: UTF-8
# Menu và nút Tải lại code của Dim (chạy từ plugins/VGD_Dim: ruby dev/test_reload.rb; giả lập SketchUp, nạp mã thật).
require 'json'
require 'tmpdir'
$LOADED_FEATURES << 'sketchup.rb' << 'extensions.rb'
$items = []; $events = []; $boxes = []; $dialogs = []
::TB_NEVER_SHOWN = 0
module Sketchup
  def self.const_missing(name); const_set(name, Class.new { def initialize(*); end; def method_missing(*); self; end; def respond_to_missing?(*); true; end }); end
  def self.version; '24.0.0'; end
  def self.find_support_file(*); nil; end
  def self.read_default(*a); a.length > 2 ? a.last : nil; end
  def self.write_default(*); end
  def self.register_extension(*); end
  def self.active_model; @model ||= Class.new { def method_missing(*); self; end; def respond_to_missing?(*); true; end }.new; end
  def self.add_observer(*); end
  def self.remove_observer(*); end
  def self.status_text=(*); end
end
class SketchupExtension
  attr_accessor :description, :version, :creator, :copyright
  def initialize(*); end
end
class Numeric; def mm; self; end; def degrees; self; end; end
module Geom; def self.const_missing(name); const_set(name, Class.new { def initialize(*); end; def method_missing(*); self; end; def respond_to_missing?(*); true; end }); end; end
module UI
  class Command
    attr_accessor :tooltip, :status_bar_text, :small_icon, :large_icon
    def initialize(title, &b); @title = title; end
  end
  class Toolbar
    def initialize(name); $events << [:new, name]; end
    def add_item(*); $events << :add; end
    def get_last_state; $last_state || 0; end
    def show; $events << :show; end
    def restore; $events << :restore; end
  end
  class Menu
    attr_reader :path
    def initialize(path); @path = path; end
    def add_submenu(n); Menu.new(@path + [n]); end
    def add_item(i, &b); $items << [@path.join(' > '), (i.is_a?(String) ? i : :command), b]; end
  end
  class HtmlDialog
    STYLE_DIALOG = 0
    def initialize(*); $dialogs << self; @visible = false; end
    def visible?; @visible; end
    def show; @visible = true; end
    def close; @visible = false; end
    def method_missing(*); nil; end
    def respond_to_missing?(*); true; end
  end
  def self.const_missing(name); const_set(name, Class.new); end
  def self.menu(n); Menu.new([n]); end
  def self.messagebox(t); $boxes << t; end
  def self.start_timer(*); 0; end
  def self.stop_timer(*); end
  def self.add_context_menu_handler(&b); end
end
def file_loaded?(f); ($loaded ||= {})[f]; end
def file_loaded(f); ($loaded ||= {})[f] = true; end
$pass = 0; $fail = []
def check(name, cond, _extra = nil); cond ? ($pass += 1) : ($fail << name); puts "#{cond ? 'OK  ' : 'FAIL'} #{name}"; end

root = File.expand_path('../runtime', __dir__)
%w[version defaults engine native_style store managed core presets autostyle animation smartdim regions manual_dim probe dialog].each do |name|
  file = File.join(root, 'vgd_dim', "#{name}.rb")
  load file if File.file?(file)
end
load File.join(root, 'vgd_dim', 'main.rb')
top = $items.select { |path, _n, _b| path == 'Extensions' }
check 'không có mục lẻ nằm thẳng trong menu Extensions', top.empty?, top.map { |x| x[1] }.inspect
check "mọi mục nằm trong Extensions > VGD > VGD Dim", $items.all? { |path, _n, _b| path == 'Extensions > VGD > VGD Dim' }
names = $items.map { |_p, n, _b| n }
check "không có mục kiểm tra cập nhật (VGD Center lo cập nhật)", names.none? { |n| n.to_s.include?('cập nhật') }
check "có mục 'Tải lại code'", names.include?('Tải lại code')
reload = $items.find { |_p, n, _b| n == 'Tải lại code' }[2]
reload.call
check 'tải lại khi chưa mở cửa sổ: KHÔNG tự mở cửa sổ', $dialogs.none?(&:visible?), $dialogs.size
check 'tải lại thành công báo đã tải lại', $boxes.last.to_s.start_with?('Đã tải lại VGD Dim')
VGD::Dim.show_dialog
open_dialog = $dialogs.last
check 'cửa sổ đang mở', open_dialog.visible?
reload.call
check 'tải lại khi cửa sổ đang mở: đóng và mở lại', !open_dialog.visible? && $dialogs.last.visible? && !$dialogs.last.equal?(open_dialog)
reload.call
check 'tải lại không nhân đôi mục menu', $items.size == names.size
# Lỗi cú pháp: báo lỗi rõ, không làm hỏng bản đang chạy (dùng bản sao để có file lỗi).
require 'fileutils'
Dir.mktmpdir do |dir|
  FileUtils.cp_r(File.join(root, 'vgd_dim'), dir)
  load File.join(dir, 'vgd_dim', 'main.rb')
  File.write(File.join(dir, 'vgd_dim', 'store.rb'), "module VGD\n  def broken(\nend\n")
  boxes = $boxes.size
  reload.call
  check 'lỗi cú pháp: báo lỗi và giữ nguyên bản đang chạy', $boxes.size == boxes + 1 && $boxes.last.start_with?('Tải lại thất bại') && $boxes.last.include?('giữ nguyên')
  check 'lỗi cú pháp: vẫn gọi được hàm của bản đang chạy', VGD::Dim.respond_to?(:show_dialog)
end
puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "CÓ #{$fail.size} LỖI: #{$fail.inspect}"
exit($fail.empty? ? 0 : 1)
