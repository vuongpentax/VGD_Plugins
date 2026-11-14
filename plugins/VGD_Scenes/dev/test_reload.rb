# encoding: UTF-8
# Kiểm tra "Tải lại code" bằng giả lập SketchUp (chạy từ plugins/VGD_Scenes: ruby dev/test_reload.rb).
require 'fileutils'
require 'tmpdir'
require 'json'
$LOADED_FEATURES << 'sketchup.rb' << 'extensions.rb'
$items = []; $boxes = []; $dialogs = []; $toolbars = 0
TB_NEVER_SHOWN = 0
module Sketchup
  def self.const_missing(name); const_set(name, Class.new); end
  def self.version; '24.0.0'; end
  def self.register_extension(*); end
  def self.read_default(*a); a.length > 2 ? a.last : nil; end
  def self.write_default(*); end
  class FakeModel
    def entities; []; end
    def materials; []; end
    def selection; []; end
    def method_missing(*); nil; end
    def respond_to_missing?(*); true; end
  end
  def self.active_model; @model ||= FakeModel.new; end
  def self.status_text=(*); end
end
class SketchupExtension
  attr_accessor :description, :version, :creator, :copyright
  def initialize(*); end
end
class Numeric; def mm; self; end; def inch; self; end; def degrees; self; end; end
module Geom; def self.const_missing(name); const_set(name, Class.new); end; end
module UI
  class Command
    attr_accessor :tooltip, :status_bar_text, :small_icon, :large_icon
    def initialize(title, &b); @title = title; @b = b; end
  end
  class Toolbar
    def initialize(*); $toolbars += 1; end
    def add_item(*); end
    def get_last_state; 0; end
    def show; end
    def restore; end
  end
  class Menu
    def add_submenu(_n); self; end
    def add_item(i, &b); $items << [(i.is_a?(String) ? i : :command), b]; end
    def add_separator; end
  end
  class HtmlDialog
    STYLE_DIALOG = 0
    def initialize(**); $dialogs << self; @visible = false; end
    def set_file(*); end
    def add_action_callback(*); end
    def set_on_closed(&b); @on_closed = b; end
    def execute_script(*); end
    def visible?; @visible; end
    def show; @visible = true; end
    def bring_to_front; end
    def close; @visible = false; @on_closed&.call; end
  end
  def self.const_missing(name); const_set(name, Class.new); end
  def self.menu(_n); Menu.new; end
  def self.messagebox(t); $boxes << t; end
  def self.add_context_menu_handler(&b); end
  def self.start_timer(*); 0; end
  def self.stop_timer(*); end
end
def file_loaded?(f); ($loaded ||= {})[f]; end
def file_loaded(f); ($loaded ||= {})[f] = true; end
$pass = 0; $fail = []
def check(name, cond); cond ? ($pass += 1) : ($fail << name); puts "#{cond ? 'OK  ' : 'FAIL'} #{name}"; end

Dir.mktmpdir do |dir|
  FileUtils.cp_r(Dir.glob(File.expand_path('../runtime/*', __dir__)), dir)
  main = File.join(dir, 'vgd_scenes', 'main.rb')
  main_src = File.read(main, encoding: 'UTF-8')
  # CODE_FILES phải trùng các require_relative ở đầu main.rb (trừ chính main).
  required = main_src.scan(/^require_relative '([a-z_]+)'/).flatten
  listed = main_src[/CODE_FILES = %w\[(.*?)\]/m, 1].split - ['main']
  check 'CODE_FILES trùng các require_relative của main.rb', required.sort == listed.sort
  load File.join(dir, 'vgd_scenes.rb')
  load main
  check 'khởi động: có mục Tải lại code', $items.map(&:first).include?('Tải lại code')
  reload = $items.find { |n, _| n == 'Tải lại code' }[1]
  count = $items.size; toolbars = $toolbars
  2.times { reload.call }
  check 'tải lại 2 lần: không nhân đôi menu và toolbar', $items.size == count && $toolbars == toolbars
  check 'tải lại thành công báo đã tải lại', $boxes.last.to_s.start_with?('Đã tải lại')
  VGD::Scenes.open
  first = $dialogs.last
  reload.call
  check 'hộp thoại đang mở được đóng và mở lại', !first.visible? && $dialogs.last.visible? && !$dialogs.last.equal?(first)
  uti = File.join(dir, 'vgd_scenes', 'utils.rb')
  File.write(uti, File.read(uti, encoding: 'UTF-8') + "\nmodule VGD; module Scenes; RELOAD_MARK = 1; end; end\n")
  ld = File.join(dir, 'vgd_scenes.rb')
  File.write(ld, File.read(ld, encoding: 'UTF-8').sub(/VERSION = '[^']+'/, "VERSION = '9.9.9'"))
  reload.call
  check 'tải lại nhận mã mới và phiên bản mới', VGD::Scenes.const_defined?(:RELOAD_MARK) && VGD::Scenes::VERSION == '9.9.9'
  File.write(File.join(dir, 'vgd_scenes', 'geometry.rb'), "module VGD\n  def broken(\nend\n")
  n = $boxes.size
  reload.call
  check 'lỗi cú pháp: báo lỗi và giữ bản đang chạy', $boxes.size == n + 1 && $boxes.last.start_with?('Tải lại thất bại') && VGD::Scenes::VERSION == '9.9.9'
  File.write(File.join(dir, 'vgd_scenes', 'geometry.rb'), "module VGD\n  module Scenes\n    raise 'lỗi giả lập lúc nạp'\n  end\nend\n")
  reload.call
  check 'lỗi lúc chạy: báo lỗi, khôi phục phiên bản và danh sách file', $boxes.last.start_with?('Tải lại thất bại') && VGD::Scenes.const_defined?(:VERSION) && VGD::Scenes.const_defined?(:CODE_FILES)
  VGD::Scenes.instance_variable_set(:@job, Object.new)
  reload.call
  check 'đang xuất: không cho tải lại', $boxes.last.start_with?('VGD Scenes đang xử lý')
end
puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "CÓ #{$fail.size} LỖI: #{$fail.inspect}"
exit($fail.empty? ? 0 : 1)
