# encoding: UTF-8
# Kiểm tra chọn định dạng khi lưu (dialog.rb: resolve_format). Chạy từ plugins/VGD_Diagram: ruby dev/test_formats.rb
require 'json'
require 'base64'
$LOADED_FEATURES << 'sketchup.rb'
module Sketchup; def self.active_model; nil; end; end
module UI; def self.messagebox(*); end; end
require File.expand_path('../runtime/vgd_diagram/dialog', __dir__)

D = VGD::Diagram::Dialog
$pass = 0
$fail = []
def check(name, condition)
  condition ? $pass += 1 : $fail << name
  puts "#{condition ? 'OK  ' : 'FAIL'} #{name}"
end

def raises?(message_part)
  yield
  false
rescue ArgumentError => error
  error.message.include?(message_part)
end

check 'đuôi mp4 được giữ nguyên', D.resolve_format('/tmp/a/video.mp4', %w[mp4 webm], 'webm') == ['/tmp/a/video.mp4', 'mp4']
check 'đuôi viết hoa được chấp nhận, định dạng trả về là chữ thường', D.resolve_format('/tmp/a/anh.JPG', %w[png jpg], 'png') == ['/tmp/a/anh.JPG', 'jpg']
check 'không có đuôi thì dùng định dạng đã chọn', D.resolve_format('/tmp/a/tu-bep', %w[png jpg], 'jpg') == ['/tmp/a/tu-bep.jpg', 'jpg']
check 'đuôi không hỗ trợ thì báo rõ các định dạng được phép', raises?('Chọn: png, jpg') { D.resolve_format('/tmp/a/anh.gif', %w[png jpg], 'png') }
check 'đuôi video sai với nhóm ảnh thì báo lỗi', raises?('không được hỗ trợ') { D.resolve_format('/tmp/a/x.mp4', %w[png jpg], 'png') }

check 'video: đuôi png chọn chuỗi khung hình', D.resolve_format('/tmp/a/khung.png', %w[mp4 webm png], 'mp4') == ['/tmp/a/khung.png', 'png']

puts
puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "CÓ #{$fail.size} LỖI: #{$fail.inspect}"
exit($fail.empty? ? 0 : 1)
