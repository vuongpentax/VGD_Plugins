# Test đọc ảnh clipboard bằng PowerShell (core/clipboard_image.rb) với bản chạy giả: không chạy PowerShell thật. Chạy: ruby dev/test_clipboard_image.rb
require 'tmpdir'
module VGD; module BIM; def self.log(m); end; end; end
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_clip')
%w[storage settings model_settings images clipboard_image].each { |f| require File.expand_path("../runtime/vgd_bim/core/#{f}.rb", __dir__) }
C = VGD::BIM::ClipboardImage
def check(label, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{label}"; $fails = ($fails || 0) + (cond ? 0 : 1); end
def error_of; yield; nil; rescue StandardError => e; e; end
PNG = ("\x89PNG\r\n\x1A\n".b + 'anh trong clipboard'.b).freeze
seen = nil

bytes = C.read_png(runner: ->(path) { seen = path; File.binwrite(path, PNG); [0, ''] })
check 'ảnh có trong clipboard: trả đúng bytes PNG', bytes == PNG
check 'file tạm được xóa sau khi đọc', seen && !File.exist?(seen)
check 'file tạm nằm trong thư mục tạm của hệ thống', File.dirname(seen) == Dir.tmpdir && File.basename(seen).start_with?('vgd_bim_clip_')

error = error_of { C.read_png(runner: ->(_p) { [C::EMPTY_EXIT, ''] }) }
check 'clipboard không có ảnh: báo rõ bằng lỗi Empty', error.is_a?(C::Empty) && error.message.include?('chưa có ảnh')

error = error_of { C.read_png(runner: ->(_p) { [1, "Exception calling GetImage\nline2"] }) }
check 'PowerShell lỗi: báo dòng lỗi đầu, không lộ cả đoạn', error && error.message.include?('PowerShell') && error.message.include?('Exception calling GetImage') && !error.message.include?('line2')

error = error_of { C.read_png(runner: ->(_p) { [0, ''] }) }
check 'PowerShell báo xong nhưng không có file: báo lỗi', error && error.message.include?('Không lấy được ảnh')

error = error_of { C.read_png(runner: ->(p) { File.binwrite(p, 'khong phai png'); [0, ''] }) }
check 'file không phải PNG bị từ chối, file tạm vẫn được xóa', error && error.message.include?('PNG')

big = nil
error = error_of { C.read_png(runner: ->(p) { big = p; File.binwrite(p, PNG + ("\0".b * C::MAX_BYTES)); [0, ''] }) }
check 'ảnh quá lớn bị từ chối, file tạm được xóa', error && error.message.include?('quá lớn') && !File.exist?(big)

unless C.windows?
  error = error_of { C.read_png }
  check 'không phải Windows: báo dùng Ctrl+V, không chạy chương trình ngoài', error && error.message.include?('Windows') && error.message.include?('Ctrl+V')
end
check 'đường dẫn file đích truyền bằng biến môi trường, không ghép vào lệnh PowerShell', C::SCRIPT.include?("$env:#{C::ENV_OUT}") && !C::SCRIPT.include?(Dir.tmpdir)
check 'lệnh PowerShell chỉ ĐỌC clipboard (GetImage), không ghi clipboard', C::SCRIPT.include?('Clipboard]::GetImage()') && !C::SCRIPT.match?(/SetImage|SetText|Clear\(/)

puts $fails.to_i.zero? ? 'Done' : "#{$fails} lỗi"
exit($fails.to_i.zero? ? 0 : 1)
