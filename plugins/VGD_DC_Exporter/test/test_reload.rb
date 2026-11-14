# encoding: UTF-8
# Kiểm tra "Tải lại code" bằng giả lập SketchUp (chạy từ plugins/VGD_DC_Exporter: ruby test/test_reload.rb).
require 'fileutils'
require 'tmpdir'
$LOADED_FEATURES << 'sketchup.rb'
$boxes = []
$items = []
module Sketchup; class ComponentInstance; end; class Group; end; def self.active_model; nil; end; end
module UI
  class M; def add_submenu(_n); self; end; def add_item(n, &b); $items << [n, b]; end; end
  def self.menu(_n); M.new; end
  def self.messagebox(t); $boxes << t; end
  def self.savepanel(*); nil; end
end
def file_loaded?(f); ($loaded ||= {})[f]; end
def file_loaded(f); ($loaded ||= {})[f] = true; end
$pass = 0; $fail = []
def check(name, cond); cond ? ($pass += 1) : ($fail << name); puts "#{cond ? 'OK  ' : 'FAIL'} #{name}"; end

Dir.mktmpdir do |dir|
  FileUtils.cp_r(File.expand_path('../vgd_dc_exporter', __dir__), dir)
  main = File.join(dir, 'vgd_dc_exporter', 'main.rb')
  load main
  check 'khởi động: có mục Xuất JSON và Tải lại code', $items.map(&:first) == ['Xuất JSON đối tượng đang chọn', 'Tải lại code']
  reload = $items.last[1]
  2.times { reload.call }
  check 'tải lại 2 lần: không nhân đôi mục menu', $items.size == 2
  check 'tải lại thành công báo đã tải lại', $boxes.last.to_s.start_with?('Đã tải lại')
  # Có bản mới trên đĩa: tải lại phải nhận phiên bản và hàm mới.
  src = File.read(File.join(dir, 'vgd_dc_exporter', 'walker.rb'), encoding: 'UTF-8')
  File.write(File.join(dir, 'vgd_dc_exporter', 'walker.rb'), src + "\nmodule VGD_DC_Exporter; RELOAD_MARK = 1; end\n")
  File.write(main, File.read(main, encoding: 'UTF-8').sub(/VERSION = '[^']+'/, "VERSION = '9.9.9'"))
  reload.call
  check 'tải lại nhận mã mới (walker) và phiên bản mới', VGD_DC_Exporter.const_defined?(:RELOAD_MARK) && VGD_DC_Exporter::VERSION == '9.9.9'
  # Lỗi cú pháp: giữ bản đang chạy.
  File.write(File.join(dir, 'vgd_dc_exporter', 'params.rb'), "module VGD_DC_Exporter\n  def broken(\nend\n")
  before = VGD_DC_Exporter::VERSION
  reload.call
  check 'lỗi cú pháp: báo lỗi, giữ nguyên bản đang chạy', $boxes.last.to_s.start_with?('Tải lại thất bại') && $boxes.last.include?('giữ nguyên') && VGD_DC_Exporter::VERSION == before && VGD_DC_Exporter.respond_to?(:export_selected)
  check 'lỗi cú pháp: menu vẫn nguyên', $items.size == 2
  # Lỗi lúc chạy (cú pháp đúng): vẫn khôi phục hằng, lần tải lại sau còn dùng được.
  File.write(File.join(dir, 'vgd_dc_exporter', 'params.rb'), "module VGD_DC_Exporter\n  raise 'lỗi giả lập lúc nạp'\nend\n")
  reload.call
  check 'lỗi lúc chạy: báo lỗi, khôi phục phiên bản và danh sách file', $boxes.last.start_with?('Tải lại thất bại') && $boxes.last.include?('Hãy mở lại SketchUp') && VGD_DC_Exporter::VERSION == before && VGD_DC_Exporter.const_defined?(:CODE_FILES)
  File.write(File.join(dir, 'vgd_dc_exporter', 'params.rb'), "module VGD_DC_Exporter\nend\n")
  reload.call
  check 'sau lỗi, tải lại lần sau thành công', $boxes.last.start_with?('Đã tải lại')
end
puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "CÓ #{$fail.size} LỖI: #{$fail.inspect}"
exit($fail.empty? ? 0 : 1)
