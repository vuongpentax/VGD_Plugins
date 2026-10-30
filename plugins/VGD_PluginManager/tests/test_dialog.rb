# encoding: UTF-8
# Kiểm thử: bấm mở nhiều lần chỉ có một hộp thoại.
require 'tmpdir'
require 'fileutils'
$LOAD_PATH.unshift(File.join(__dir__, 'stub'))

build = File.expand_path(ARGV[0])
fake = Dir.mktmpdir('fake_appdata')
ENV['APPDATA'] = fake
FileUtils.mkdir_p(File.join(fake, 'SketchUp/SketchUp 2024/SketchUp/Plugins'))

module UI
  class HtmlDialog
    STYLE_DIALOG = 1
    @@made = []
    attr_reader :fronted
    def self.made; @@made; end
    def initialize(**_o); @@made << self; @visible = false; @fronted = 0; end
    def set_file(_f); end
    def add_action_callback(_n, &_b); end
    def set_on_closed(&b); @closed = b; end
    def show; @visible = true; end
    def visible?; @visible; end
    def bring_to_front; @fronted += 1; end
    def close; @visible = false; @closed.call if @closed; end
  end
end

require File.join(build, 'VGD_PluginManager/main')
PM = VGD::PluginManager

def check(label, cond)
  puts "#{cond ? 'OK  ' : 'FAIL'} #{label}"
  $fail = true unless cond
end

check 'chưa mở thì không có hộp thoại', !PM.dialog_open?
PM.run
check 'mở lần đầu tạo một hộp thoại', UI::HtmlDialog.made.size == 1 && PM.dialog_open?
PM.run
PM.run
check 'bấm thêm không tạo hộp thoại mới, đưa cửa sổ cũ lên trước', UI::HtmlDialog.made.size == 1 && UI::HtmlDialog.made[0].fronted == 2
UI::HtmlDialog.made[0].close
check 'đóng xong thì ghi nhận là đã đóng', !PM.dialog_open?
PM.run
check 'sau khi đóng, bấm mở tạo hộp thoại mới', UI::HtmlDialog.made.size == 2 && PM.dialog_open?
UI::HtmlDialog.made[0].close
check 'đóng cửa sổ cũ không làm mất dấu cửa sổ mới', PM.dialog_open?

loader = File.read(File.join(build, 'VGD_PluginManager.rb'), encoding: 'UTF-8')[/ex\.version\s*=\s*'([^']+)'/, 1]
check "phiên bản trong loader (#{loader}) khớp VERSION (#{PM::VERSION})", loader == PM::VERSION

puts($fail ? 'CÓ LỖI' : 'TẤT CẢ ĐẠT')
exit($fail ? 1 : 0)
