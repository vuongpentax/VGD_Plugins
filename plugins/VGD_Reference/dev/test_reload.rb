# encoding: UTF-8
# Kiểm tra "Tải lại code" bằng giả lập SketchUp (chạy từ plugins/VGD_Reference: ruby dev/test_reload.rb).
require 'fileutils'
require 'tmpdir'
require 'json'
$LOADED_FEATURES << 'sketchup.rb'
$items = []; $boxes = []; $dialogs = []; $toolbars = 0
class Numeric; def mm; self; end; def degrees; self; end; end
module Geom; def self.const_missing(name); const_set(name, Class.new); end; end
class FakeModel
  def method_missing(*); self; end
  def respond_to_missing?(*); true; end
  def overlays; @overlays ||= Class.new { def find(*); nil; end; def add(*); end; def remove(*); end }.new; end
  def ==(other); equal?(other); end
end
module Sketchup
  def self.const_missing(name); const_set(name, Class.new); end
  def self.version; '24.0.0'; end
  def self.platform; :platform_osx; end
  def self.active_model; @model ||= FakeModel.new; end
  def self.add_observer(*); end
  def self.status_text=(*); end
  class Overlay
    def initialize(*); end
    def enabled=(*); end
    def enabled?; true; end
    def valid?; true; end
  end
  class AppObserver; end
end
module UI
  class Command
    def initialize(title, &b); @title = title; $items << [title, b]; end
    attr_accessor :tooltip, :status_bar_text, :small_icon, :large_icon, :small_icon_path
    def method_missing(*); nil; end
    def respond_to_missing?(*); true; end
  end
  class Toolbar
    def initialize(*); $toolbars += 1; end
    def add_item(*); end
    def restore; end
  end
  class Menu
    def add_submenu(_n); self; end
    def add_item(*); end
  end
  class HtmlDialog
    STYLE_UTILITY = 1
    STYLE_DIALOG = 0
    def initialize(*); $dialogs << self; @visible = false; end
    def set_file(*); end
    def set_html(*); end
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
end
def file_loaded?(f); ($loaded ||= {})[f]; end
def file_loaded(f); ($loaded ||= {})[f] = true; end
$pass = 0; $fail = []
def check(name, cond); cond ? ($pass += 1) : ($fail << name); puts "#{cond ? 'OK  ' : 'FAIL'} #{name}"; end

Dir.mktmpdir do |dir|
  FileUtils.cp_r(File.expand_path('../runtime/vgd_reference', __dir__), dir)
  main = File.join(dir, 'vgd_reference', 'main.rb')
  main_src = File.read(main, encoding: 'UTF-8')
  # CODE_FILES phải trùng các require_relative (trừ chính main).
  required = main_src.scan(/^\s*require_relative '([a-z_\/]+)'/).flatten
  listed = main_src[/CODE_FILES = %w\[(.*?)\]/m, 1].split - ['main']
  check 'CODE_FILES trùng các require_relative của main.rb', required.sort == listed.sort
  load main
  check 'khởi động: có mục Tải lại code', $items.map(&:first).include?('Tải lại code')
  reload = $items.find { |n, _| n == 'Tải lại code' }[1]
  count = $items.size; toolbars = $toolbars
  session_before = VGD::Reference::Session.instance_variable_get(:@store)
  2.times { reload.call }
  check 'tải lại 2 lần: không nhân đôi menu và toolbar', $items.size == count && $toolbars == toolbars
  check 'tải lại thành công báo đã tải lại', $boxes.last.to_s.start_with?('Đã tải lại')
  check 'tải lại giữ nguyên dữ liệu ảnh của phiên (store)', VGD::Reference::Session.instance_variable_get(:@store).equal?(session_before)
  VGD::Reference::Manager.open
  first = $dialogs.last
  reload.call
  check 'bảng quản lý đang mở được đóng và mở lại', !first.visible? && $dialogs.last.visible? && !$dialogs.last.equal?(first)
  src = File.join(dir, 'vgd_reference', 'core', 'reference_item.rb')
  File.write(src, File.read(src, encoding: 'UTF-8') + "\nmodule VGD; module Reference; RELOAD_MARK = 1; end; end\n")
  const = File.join(dir, 'vgd_reference', 'core', 'constants.rb')
  File.write(const, File.read(const, encoding: 'UTF-8').sub(/VERSION = '[^']+'/, "VERSION = '9.9.9'"))
  reload.call
  check 'tải lại nhận mã mới và phiên bản mới', VGD::Reference.const_defined?(:RELOAD_MARK) && VGD::Reference::VERSION == '9.9.9'
  File.write(File.join(dir, 'vgd_reference', 'core', 'reference_store.rb'), "module VGD\n  def broken(\nend\n")
  n = $boxes.size
  reload.call
  check 'lỗi cú pháp: báo lỗi và giữ bản đang chạy', $boxes.size == n + 1 && $boxes.last.start_with?('Tải lại thất bại') && VGD::Reference::VERSION == '9.9.9'
  File.write(File.join(dir, 'vgd_reference', 'core', 'reference_store.rb'), "module VGD\n  module Reference\n    raise 'lỗi giả lập lúc nạp'\n  end\nend\n")
  reload.call
  check 'lỗi lúc chạy: báo lỗi, vẫn còn danh sách file', $boxes.last.start_with?('Tải lại thất bại') && VGD::Reference.const_defined?(:CODE_FILES)
  VGD::Reference::Session.instance_variable_set(:@current_tool, Object.new)
  reload.call
  check 'đang chỉnh sửa ảnh: không cho tải lại', $boxes.last.start_with?('Đang chỉnh sửa hoặc nhập ảnh')
  VGD::Reference::Session.instance_variable_set(:@current_tool, nil)
  VGD::Reference::ImageImport.instance_variable_set(:@queue, [{}])
  reload.call
  check 'đang nhập ảnh: không cho tải lại', $boxes.last.start_with?('Đang chỉnh sửa hoặc nhập ảnh')
end
puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "CÓ #{$fail.size} LỖI: #{$fail.inspect}"
exit($fail.empty? ? 0 : 1)
