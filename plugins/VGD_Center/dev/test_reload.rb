# encoding: UTF-8
# Kiểm tra "Tải lại code" bằng giả lập SketchUp (chạy từ plugins/VGD_Center: ruby dev/test_reload.rb).
require 'fileutils'
require 'tmpdir'
require 'json'
$LOADED_FEATURES << 'sketchup.rb'
$items = []; $boxes = []; $dialogs = []; $toolbars = 0
module Sketchup
  def self.const_missing(name); const_set(name, Class.new); end
  def self.version; '24.0.0'; end
  def self.read_default(*a); a.length > 2 ? a.last : nil; end
  def self.write_default(*); end
  def self.find_support_file(*); Dir.tmpdir; end
  def self.extensions; []; end
  def self.active_model; nil; end
  def self.platform; :platform_win; end
  def self.status_text=(*); end
end
module UI
  class Command
    attr_accessor :tooltip, :status_bar_text, :small_icon, :large_icon
    def initialize(*, &b); end
  end
  class Toolbar
    def initialize(*); $toolbars += 1; end
    def add_item(*); end
    def restore; end
  end
  class Menu
    def add_submenu(_n); self; end
    def add_item(i, &b); $items << [(i.is_a?(String) ? i : :command), b]; end
  end
  class HtmlDialog
    STYLE_DIALOG = 0
    def initialize(*); $dialogs << self; @visible = false; end
    def set_file(*); end
    def add_action_callback(*); end
    def set_on_closed(&b); @on_closed = b; end
    def execute_script(*); end
    def visible?; @visible; end
    def show; @visible = true; end
    def bring_to_front; end
    def close; @visible = false; @on_closed&.call; end
    def method_missing(*); nil; end
    def respond_to_missing?(*); true; end
  end
  def self.menu(_n); Menu.new; end
  def self.messagebox(t); $boxes << t; end
  def self.start_timer(*); 0; end
  def self.stop_timer(*); end
  def self.add_context_menu_handler(&b); end
end
def file_loaded?(f); ($loaded ||= {})[f]; end
def file_loaded(f); ($loaded ||= {})[f] = true; end
$pass = 0; $fail = []
def check(name, cond); cond ? ($pass += 1) : ($fail << name); puts "#{cond ? 'OK  ' : 'FAIL'} #{name}"; end

Dir.mktmpdir do |dir|
  FileUtils.cp_r(File.expand_path('../vgd_center', __dir__), dir)
  FileUtils.cp(File.expand_path('../vgd_center.rb', __dir__), dir)
  main = File.join(dir, 'vgd_center', 'main.rb')
  main_src = File.read(main, encoding: 'UTF-8')
  # CODE_FILES phải gồm mọi file Ruby của tab Quản lý và main.
  listed = main_src[/CODE_FILES = %w\[(.*?)\]/m, 1].split
  actual = Dir.glob(File.join(dir, 'vgd_center', 'manager', '*.rb')).map { |f| "manager/#{File.basename(f, '.rb')}" } + ['main']
  check 'CODE_FILES gồm mọi file .rb của manager/ và main', listed.sort == actual.sort
  load main
  check 'khởi động: có mục Tải lại code', $items.map(&:first).include?('Tải lại code')
  reload = $items.find { |n, _| n == 'Tải lại code' }[1]
  count = $items.size; toolbars = $toolbars
  2.times { reload.call }
  check 'tải lại 2 lần: không nhân đôi menu và toolbar', $items.size == count && $toolbars == toolbars
  check 'tải lại thành công báo đã tải lại', $boxes.last.to_s.start_with?('Đã tải lại')
  VGD::Center.show_dialog
  first = $dialogs.last
  reload.call
  check 'hộp thoại đang mở được đóng và mở lại', !first.visible? && $dialogs.last.visible? && !$dialogs.last.equal?(first)
  tgl = File.join(dir, 'vgd_center', 'manager', 'toggle.rb')
  File.write(tgl, File.read(tgl, encoding: 'UTF-8') + "\nmodule VGD; module Center; RELOAD_MARK = 1; end; end\n")
  File.write(main, File.read(main, encoding: 'UTF-8').sub(/VERSION = '[^']+'/, "VERSION = '9.9.9'"))
  reload.call
  check 'tải lại nhận mã mới và phiên bản mới', VGD::Center.const_defined?(:RELOAD_MARK) && VGD::Center::VERSION == '9.9.9'
  File.write(File.join(dir, 'vgd_center', 'manager', 'linker.rb'), "module VGD\n  def broken(\nend\n")
  n = $boxes.size
  reload.call
  check 'lỗi cú pháp: báo lỗi và giữ bản đang chạy', $boxes.size == n + 1 && $boxes.last.start_with?('Tải lại thất bại') && VGD::Center::VERSION == '9.9.9'
  File.write(File.join(dir, 'vgd_center', 'manager', 'linker.rb'), "module VGD\n  module Center\n    raise 'lỗi giả lập lúc nạp'\n  end\nend\n")
  reload.call
  check 'lỗi lúc chạy: báo lỗi, vẫn còn danh sách file', $boxes.last.start_with?('Tải lại thất bại') && VGD::Center.const_defined?(:CODE_FILES)
  VGD::Center.instance_variable_set(:@busy, true)
  reload.call
  check 'đang tải hoặc cài: không cho tải lại', $boxes.last.start_with?('VGD Center đang tải')
end
puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "CÓ #{$fail.size} LỖI: #{$fail.inspect}"
exit($fail.empty? ? 0 : 1)
