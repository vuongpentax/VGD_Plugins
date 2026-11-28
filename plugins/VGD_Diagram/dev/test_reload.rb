# encoding: UTF-8
# Menu, toolbar và nút Tải lại code (giả lập SketchUp, nạp mã thật từ runtime/).
# Chạy từ plugins/VGD_Diagram: ruby dev/test_reload.rb
require 'json'
require 'tmpdir'
require 'fileutils'

$LOADED_FEATURES << 'sketchup.rb' << 'extensions.rb'
$items = []
$boxes = []
$dialogs = []
$toolbars = 0
$toolbar_items = []
::TB_NEVER_SHOWN = 0

module Sketchup
  def self.active_model
    nil
  end
end

module UI
  class Command
    attr_accessor :tooltip, :status_bar_text, :small_icon, :large_icon
    attr_reader :block

    def initialize(title, &block)
      @title = title
      @block = block
    end
  end

  class Toolbar
    def initialize(_name)
      $toolbars += 1
    end

    def add_item(item)
      $toolbar_items << item
    end

    def get_last_state; TB_NEVER_SHOWN; end
    def show; end
    def restore; end
  end

  class Menu
    def initialize(path)
      @path = path
    end

    def add_submenu(name)
      Menu.new(@path + [name])
    end

    def add_item(item, &block)
      label = item.is_a?(String) ? item : item.instance_variable_get(:@title)
      $items << [@path.join(' > '), label, block || item.block]
    end
  end

  class HtmlDialog
    STYLE_DIALOG = 0

    def initialize(*)
      @visible = false
      $dialogs << self
    end

    def set_file(*); end
    def add_action_callback(*); end
    def execute_script(*); end
    def visible?; @visible; end
    def show; @visible = true; end
    def bring_to_front; end

    def close
      @visible = false
    end
  end

  def self.menu(name)
    Menu.new([name])
  end

  def self.messagebox(text)
    $boxes << text
  end
end

$pass = 0
$fail = []
def check(name, condition)
  condition ? $pass += 1 : $fail << name
  puts "#{condition ? 'OK  ' : 'FAIL'} #{name}"
end

def file_loaded?(file)
  ($loaded ||= {})[file]
end

def file_loaded(file)
  ($loaded ||= {})[file] = true
end

root = File.expand_path('../runtime/vgd_diagram', __dir__)
# require (không phải load) để require_relative trong main.rb nhận ra các file đã nạp.
%w[version tree model_io dialog main].each { |name| require File.join(root, name + '.rb') }

# Danh sách file nạp nằm ở MỘT nơi (code_files.rb), dùng cho cả lúc mở SketchUp (main.rb) và "Tải lại code" (reload.rb).
# Thêm file mới mà quên một nơi thì tải lại sẽ thiếu file: các kiểm tra tĩnh dưới đây chặn lỗi đó.
list = VGD::Diagram::CODE_FILES
code_files = Dir[File.join(root, '*.rb')].reject { |path| File.basename(path) == 'reload.rb' }
required = code_files.flat_map { |path| File.read(path, encoding: 'UTF-8').scan(/^\s*require_relative '([^']+)'/).flatten }.uniq - ['code_files']
check 'danh sách file nạp: mọi file được require_relative đều có trong CODE_FILES', (required - list).empty?
check 'danh sách file nạp: mọi tên trong CODE_FILES có file thật', list.all? { |name| File.file?(File.join(root, name + '.rb')) }
check 'danh sách file nạp: main nạp cuối', list.last == 'main'
check 'danh sách file nạp: reload.rb không tự giữ danh sách riêng', !File.read(File.join(root, 'reload.rb'), encoding: 'UTF-8').include?('%w[')
check 'danh sách file nạp: main.rb chỉ require_relative danh sách chung',
      File.read(File.join(root, 'main.rb'), encoding: 'UTF-8').scan(/^\s*require_relative '([^']+)'/).flatten == ['code_files']
package = File.read(File.expand_path('package.py', __dir__), encoding: 'UTF-8')
check 'đóng gói: package.py có đủ file trong CODE_FILES và code_files.rb',
      (list + ['code_files']).all? { |name| package.include?("'vgd_diagram/#{name}.rb'") }

top_level = $items.select { |path, _label, _block| path == 'Extensions' }
check 'không có mục lẻ nằm thẳng trong menu Extensions', top_level.empty?
check 'mọi mục nằm trong Extensions > VGD > VGD Diagram', $items.all? { |path, _l, _b| path == 'Extensions > VGD > VGD Diagram' }
labels = $items.map { |_p, label, _b| label }
check "có mục 'Tải lại code'", labels.include?('Tải lại code')
check 'không có mục kiểm tra cập nhật', labels.none? { |label| label.to_s.include?('cập nhật') }
check 'toolbar được tạo đúng một lần', $toolbars == 1

# Nút toolbar mở hộp thoại là nút bật / tắt (quy tắc chung của repo); mục menu chỉ mở.
check 'toolbar có đúng một nút', $toolbar_items.size == 1
toolbar_click = $toolbar_items.first.block
menu_open = $items.find { |_p, label, _b| label == 'VGD Diagram' }[2]
dialog = VGD::Diagram::Dialog
toolbar_click.call
check 'nút toolbar: bấm khi đang đóng thì mở hộp thoại', dialog.visible?
toolbar_click.call
check 'nút toolbar: bấm lần nữa khi đang mở thì đóng hộp thoại', !dialog.visible?
toolbar_click.call
check 'nút toolbar: bấm lần ba thì mở lại', dialog.visible?
menu_open.call
check 'mục menu: đang mở thì giữ mở, không đóng', dialog.visible?
$dialogs.last.close # người dùng tự đóng bằng nút X của cửa sổ
toolbar_click.call
check 'nút toolbar: cửa sổ đã bị đóng bằng nút X thì bấm sẽ mở lại, không bị coi là đang mở', dialog.visible?
toolbar_click.call
dialog.close
check 'sau thử bật / tắt hộp thoại đang đóng', !dialog.visible?

reload = $items.find { |_p, label, _b| label == 'Tải lại code' }[2]
reload.call
check 'tải lại khi chưa mở cửa sổ: không tự mở cửa sổ', $dialogs.none?(&:visible?)
check 'tải lại thành công báo đúng chữ chuẩn', $boxes.last == "Đã tải lại VGD Diagram #{VGD::Diagram::VERSION}."

VGD::Diagram.show_dialog
open_dialog = $dialogs.last
check 'mở cửa sổ', open_dialog.visible?
reload.call
check 'tải lại khi đang mở: đóng cửa sổ cũ và mở lại cửa sổ mới',
      !open_dialog.visible? && $dialogs.last.visible? && !$dialogs.last.equal?(open_dialog)

reload.call
reload.call
check 'tải lại nhiều lần không nhân đôi mục menu', $items.size == labels.size
check 'tải lại nhiều lần không tạo thêm toolbar', $toolbars == 1

VGD::Diagram::Dialog.instance_variable_set(:@busy, true)
boxes_before = $boxes.size
result = reload.call
check 'đang ghi model: không tải lại và báo chờ xong',
      result == false && $boxes.size == boxes_before + 1 && $boxes.last.end_with?('Hãy chờ xong rồi tải lại code.')
VGD::Diagram::Dialog.instance_variable_set(:@busy, false)

# Lỗi cú pháp: làm trên bản sao để không đụng file thật. Nạp bản sao trước (khi file còn đúng),
# rồi làm hỏng một file như khi cài bản lỗi; bản đang chạy phải giữ nguyên.
Dir.mktmpdir do |dir|
  copy = File.join(dir, 'vgd_diagram')
  FileUtils.cp_r(root, copy)
  verbose = $VERBOSE
  $VERBOSE = nil # tắt cảnh báo định nghĩa lại hằng số của lần nạp bản sao
  begin
    load File.join(copy, 'main.rb')
  ensure
    $VERBOSE = verbose
  end
  File.write(File.join(copy, 'dialog.rb'), "module VGD\n  def broken(\nend\n")
  boxes_before = $boxes.size
  reload.call
  check 'lỗi cú pháp: báo lỗi rõ và giữ nguyên bản đang chạy',
        $boxes.size == boxes_before + 1 && $boxes.last.start_with?('Tải lại thất bại') && $boxes.last.include?('giữ nguyên')
  check 'lỗi cú pháp: hàm của bản đang chạy vẫn dùng được', VGD::Diagram.respond_to?(:show_dialog)
end

puts
puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "CÓ #{$fail.size} LỖI: #{$fail.inspect}"
exit($fail.empty? ? 0 : 1)
