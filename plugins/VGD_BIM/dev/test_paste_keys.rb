# Test gửi phím Ctrl+V cho nút dán (core/paste_keys.rb) với bản gửi giả: không gửi phím thật. Chạy: ruby dev/test_paste_keys.rb
module VGD; module BIM; def self.log(m); end; end; end
require File.expand_path('../runtime/vgd_bim/core/paste_keys.rb', __dir__)
P = VGD::BIM::PasteKeys
$fails = 0
def check(label, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{label}"; $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e; end

sent = nil
check 'gửi đúng thứ tự: Ctrl xuống, V xuống, V lên, Ctrl lên', P.press_ctrl_v(sender: ->(keys) { sent = keys }) == true && sent == [[0x11, 0], [0x56, 0], [0x56, 2], [0x11, 2]]
check 'bản gửi lỗi thì lỗi được báo ra (giao diện chuyển cách khác)', error_of { P.press_ctrl_v(sender: ->(_k) { raise 'x' }) }.is_a?(StandardError)
unless P.windows?
  error = error_of { P.press_ctrl_v }
  check 'không phải Windows: báo lỗi, không gửi phím', error && error.message.include?('Windows')
end
sent = nil
check 'chặn thanh menu khi nhấn Alt: chỉ gửi một phím không gán (nhấn rồi thả)', P.cancel_alt_menu(sender: ->(keys) { sent = keys }) == true && sent == [[0xE8, 0], [0xE8, 2]]
check 'bản gửi lỗi thì trả false, không ném lỗi (không làm hỏng công cụ)', P.cancel_alt_menu(sender: ->(_k) { raise 'x' }) == false
check 'không phải Windows và không có bản gửi: trả false, không gửi gì', P.windows? || P.cancel_alt_menu == false
src = File.read(File.expand_path('../runtime/vgd_bim/core/paste_keys.rb', __dir__))
check 'chỉ gửi khi cửa sổ đang chọn thuộc tiến trình SketchUp (không gửi phím vào ứng dụng khác)', src.include?('GetWindowThreadProcessId') && src.include?('owner == Process.pid')
check 'chỉ có ba mã phím: Ctrl, V và phím không gán', src.scan(/VK_\w+ = 0x\h+/).size == 3

puts $fails.zero? ? 'Done' : "#{$fails} lỗi"
exit($fails.zero? ? 0 : 1)
