# encoding: UTF-8
# Kiểm tra "Tải lại code" bằng giả lập SketchUp (chạy từ plugins/VGD_Image_Importer: ruby dev/test_reload.rb).
require 'fileutils'
require 'tmpdir'
$LOADED_FEATURES << 'sketchup.rb' << 'extensions.rb'
$items = []; $boxes = []; $toolbars = 0; $dialogs = []
module Sketchup
  def self.read_default(*a); a.last.is_a?(String) ? a.last : nil; end
  def self.register_extension(*); end
  def self.version; '24.0.0'; end
  def self.active_model; nil; end
  class SketchupExtension; end
end
class SketchupExtension
  attr_accessor :description, :version, :creator, :copyright
  def initialize(*); end
end
class Numeric; def degrees; self * Math::PI / 180; end; end
module Geom; end
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
    def add_item(i, &b); $items << (i.is_a?(String) ? [i, b] : [:command, nil]); end
  end
  class HtmlDialog
    STYLE_DIALOG = 0
    attr_reader :closed
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
  def self.menu(_n); Menu.new; end
  def self.messagebox(t); $boxes << t; end
end
def file_loaded?(f); ($loaded ||= {})[f]; end
def file_loaded(f); ($loaded ||= {})[f] = true; end
$pass = 0; $fail = []
def check(name, cond); cond ? ($pass += 1) : ($fail << name); puts "#{cond ? 'OK  ' : 'FAIL'} #{name}"; end

Dir.mktmpdir do |dir|
  FileUtils.cp_r(Dir.glob(File.expand_path('../runtime/*', __dir__)), dir)
  load File.join(dir, 'vgd_image_importer.rb')
  load File.join(dir, 'vgd_image_importer', 'main.rb')
  check 'khởi động: menu có lệnh và Tải lại code', $items.map(&:first).include?('Tải lại code')
  reload = $items.find { |n, _| n == 'Tải lại code' }[1]
  menu_count = $items.size; toolbars = $toolbars
  2.times { reload.call }
  check 'tải lại 2 lần: không nhân đôi menu và toolbar', $items.size == menu_count && $toolbars == toolbars
  check 'tải lại thành công báo đã tải lại', $boxes.last.to_s.start_with?('Đã tải lại')
  # Hộp thoại đang mở: đóng và mở lại.
  VGD_ImageImporter.show_dialog
  first = $dialogs.last
  reload.call
  check 'hộp thoại đang mở được đóng và mở lại', !first.visible? && $dialogs.last.visible? && !$dialogs.last.equal?(first)
  # Bản mới trên đĩa.
  eng = File.join(dir, 'vgd_image_importer', 'engine.rb')
  File.write(eng, File.read(eng, encoding: 'UTF-8') + "\nmodule VGD_ImageImporter; RELOAD_MARK = 1; end\n")
  ld = File.join(dir, 'vgd_image_importer.rb')
  File.write(ld, File.read(ld, encoding: 'UTF-8').sub(/VERSION = '[^']+'/, "VERSION = '9.9.9'"))
  reload.call
  check 'tải lại nhận mã mới và phiên bản mới', VGD_ImageImporter.const_defined?(:RELOAD_MARK) && VGD_ImageImporter::VERSION == '9.9.9'
  # Lỗi cú pháp: giữ bản đang chạy.
  File.write(File.join(dir, 'vgd_image_importer', 'conversion.rb'), "module VGD_ImageImporter\n  def broken(\nend\n")
  box_count = $boxes.size
  reload.call
  check 'lỗi cú pháp: báo lỗi và giữ bản đang chạy', $boxes.size == box_count + 1 && $boxes.last.start_with?('Tải lại thất bại') && VGD_ImageImporter::VERSION == '9.9.9' && VGD_ImageImporter.respond_to?(:show_dialog)
  # Đang chuẩn bị ảnh: không cho tải lại.
  VGD_ImageImporter.instance_variable_set(:@pending_import, true)
  reload.call
  check 'đang nhập ảnh: không cho tải lại', $boxes.last.start_with?('Đang chuẩn bị ảnh')
end
puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "CÓ #{$fail.size} LỖI: #{$fail.inspect}"
exit($fail.empty? ? 0 : 1)
