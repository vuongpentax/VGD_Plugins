# encoding: UTF-8
# Toolbar của Dim phải hiện ngay lần đầu cài, và không nhân đôi khi tải lại
# (chạy từ plugins/VGD_Dim: ruby dev/test_toolbar.rb; giả lập SketchUp, nạp mã thật).
require 'json'
require 'tmpdir'
$LOADED_FEATURES << 'sketchup.rb' << 'extensions.rb'
$items = []; $events = []; $boxes = []
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
    def add_submenu(_n); self; end
    def add_item(i, &b); $items << [(i.is_a?(String) ? i : :command), b]; end
  end
  class HtmlDialog
    STYLE_DIALOG = 0
    def initialize(*); end
    def method_missing(*); nil; end
    def respond_to_missing?(*); true; end
  end
  def self.const_missing(name); const_set(name, Class.new); end
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

root = File.expand_path('../runtime', __dir__)
%w[version defaults engine native_style store managed core presets autostyle animation smartdim regions manual_dim probe dialog update_core/manifest update_core/bootstrap update_core/client update_core/updater].each do |name|
  file = File.join(root, 'vgd_dim', "#{name}.rb")
  load file if File.file?(file)
end
load File.join(root, 'vgd_dim', 'main.rb')
toolbar = $events.select { |e| e.is_a?(Array) && e[0] == :new }
check 'có một toolbar tên VGD DIM', toolbar == [[:new, 'VGD DIM']]
check 'toolbar có 2 nút (Dim và Smart Dim)', $events.count(:add) == 2
check 'lần đầu cài (chưa từng hiện): toolbar được hiện ngay sau khi thêm đủ nút', $events.last(1) == [:show] && $events.index(:show) > $events.rindex(:add)
check 'không dùng restore khi chưa từng hiện', !$events.include?(:restore)
puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "CÓ #{$fail.size} LỖI: #{$fail.inspect}"
exit($fail.empty? ? 0 : 1)
