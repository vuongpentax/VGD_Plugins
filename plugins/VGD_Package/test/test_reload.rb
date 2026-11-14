# encoding: UTF-8
# Kiểm tra "Tải lại code" bằng giả lập SketchUp (chạy từ plugins/VGD_Package: ruby test/test_reload.rb).
require 'fileutils'
require 'tmpdir'
require 'json'
$LOADED_FEATURES << 'sketchup.rb'
$items = []; $boxes = []; $dialogs = []
module Sketchup
  def self.version; '24.0.0'; end
  def self.active_model; nil; end
  def self.status_text=(*); end
  class Material; end
  class Texture; end
end
module UI
  class Menu
    def add_submenu(_n); self; end
    def add_item(i, &b); $items << [i, b]; end
  end
  class HtmlDialog
    STYLE_DIALOG = 0
    def initialize(**); $dialogs << self; @visible = false; end
    def set_file(*); end
    def add_action_callback(*); end
    def visible?; @visible; end
    def show; @visible = true; end
    def bring_to_front; end
    def close; @visible = false; end
  end
  def self.menu(_n); Menu.new; end
  def self.messagebox(t); $boxes << t; end
end
def file_loaded?(f); ($loaded ||= {})[f]; end
def file_loaded(f); ($loaded ||= {})[f] = true; end
$pass = 0; $fail = []
def check(name, cond); cond ? ($pass += 1) : ($fail << name); puts "#{cond ? 'OK  ' : 'FAIL'} #{name}"; end

Dir.mktmpdir do |dir|
  FileUtils.cp_r(Dir.glob(File.expand_path('../vgd_package*', __dir__)), dir)
  FileUtils.rm_rf(File.join(dir, 'vgd_package', 'outputs'))
  load File.join(dir, 'vgd_package', 'vgd_pack.rb')
  check 'khởi động: có Mở VGD Package và Tải lại code', $items.map(&:first) == ['Mở VGD Package', 'Tải lại code']
  reload = $items.last[1]
  2.times { reload.call }
  check 'tải lại 2 lần: không nhân đôi menu', $items.size == 2
  check 'tải lại thành công báo đã tải lại', $boxes.last.to_s.start_with?('Đã tải lại')
  VGD::Pack::UI.show
  first = $dialogs.last
  reload.call
  check 'hộp thoại đang mở được đóng và mở lại', !first.visible? && $dialogs.last.visible? && !$dialogs.last.equal?(first)
  scanner = File.join(dir, 'vgd_package', 'scanner.rb')
  File.write(scanner, File.read(scanner, encoding: 'UTF-8') + "\nmodule VGD; module Pack; RELOAD_MARK = 1; end; end\n")
  pack = File.join(dir, 'vgd_package', 'vgd_pack.rb')
  File.write(pack, File.read(pack, encoding: 'UTF-8').sub(/PLUGIN_VERSION = '[^']+'/, "PLUGIN_VERSION = '9.9.9'"))
  reload.call
  check 'tải lại nhận mã mới và phiên bản mới', VGD::Pack.const_defined?(:RELOAD_MARK) && VGD::Pack::PLUGIN_VERSION == '9.9.9'
  File.write(File.join(dir, 'vgd_package', 'asset.rb'), "module VGD\n  def broken(\nend\n")
  n = $boxes.size
  reload.call
  check 'lỗi cú pháp: báo lỗi và giữ bản đang chạy', $boxes.size == n + 1 && $boxes.last.start_with?('Tải lại thất bại') && $boxes.last.include?('giữ nguyên') && VGD::Pack::PLUGIN_VERSION == '9.9.9'
end
puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "CÓ #{$fail.size} LỖI: #{$fail.inspect}"
exit($fail.empty? ? 0 : 1)
