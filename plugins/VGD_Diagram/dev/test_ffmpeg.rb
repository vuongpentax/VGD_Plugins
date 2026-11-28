# encoding: UTF-8
# Kiểm tra ghép MP4 và xóa khung hình (ffmpeg.rb, dialog.rb: finish_frames) bằng ffmpeg thật trên máy.
# Chạy từ plugins/VGD_Diagram: ruby dev/test_ffmpeg.rb  (cần ffmpeg trong PATH)
require 'json'
require 'base64'
require 'tmpdir'
require 'fileutils'
require 'open3'

$LOADED_FEATURES << 'sketchup.rb'
$defaults = {}
module Geom
  class Transformation
    def initialize(*); end
    def *(other); self; end
  end
end

module Sketchup
  def self.read_default(section, key, default = nil)
    $defaults.fetch([section, key], default)
  end

  def self.write_default(section, key, value)
    $defaults[[section, key]] = value
  end
end

# Hằng số hộp thoại của SketchUp là hằng số toàn cục.
MB_YESNO = 4
IDYES = 6
IDNO = 7

module UI
  $answers = []
  $boxes = []
  def self.messagebox(text, _type = 0)
    $boxes << text
    $answers.shift
  end

  def self.openpanel(*)
    $open_path
  end

  def self.savepanel(*)
    $savepanel_path
  end
end

require File.expand_path('../runtime/vgd_diagram/tree', __dir__)
require File.expand_path('../runtime/vgd_diagram/model_io', __dir__)
require File.expand_path('../runtime/vgd_diagram/scene', __dir__)
require File.expand_path('../runtime/vgd_diagram/dialog', __dir__)
require File.expand_path('../runtime/vgd_diagram/ffmpeg', __dir__)

D = VGD::Diagram::Dialog
F = VGD::Diagram::Ffmpeg

$pass = 0
$fail = []
def check(name, condition)
  condition ? $pass += 1 : $fail << name
  puts "#{condition ? 'OK  ' : 'FAIL'} #{name}"
end

# Ghi lại thông báo gửi về giao diện thay vì gửi thật (không có hộp thoại trong test).
$sent = []
# Giống SketchUp: execute_script không trả về giá trị dùng được (nil).
D.define_singleton_method(:send_js) { |fn, data| $sent << [fn, data]; nil }

ffmpeg_ok = system('ffmpeg', '-version', out: File::NULL, err: File::NULL)
abort 'Cần ffmpeg trong PATH để chạy test này.' unless ffmpeg_ok

# Tạo chuỗi khung hình PNG thật (12 khung) bằng ffmpeg.
def make_frames(folder, base, count)
  pattern = File.join(folder, "#{base}-khung-%05d.png")
  _out, status = Open3.capture2e('ffmpeg', '-y', '-f', 'lavfi', '-i', 'testsrc=size=320x240:rate=30',
                                 '-frames:v', count.to_s, pattern)
  raise 'không tạo được khung hình mẫu' unless status.success?
  (1..count).map { |i| File.join(folder, format("%s-khung-%05d.png", base, i)) }
end

Dir.mktmpdir do |dir|
  # 1. Ghép trực tiếp
  frames = make_frames(dir, 'lap-rap', 12)
  output = File.join(dir, 'lap-rap.mp4')
  ok, error = F.encode('ffmpeg', File.join(dir, 'lap-rap-khung-%05d.png'), 30, output)
  check('ghép: tạo được MP4 có dữ liệu', ok && File.size?(output).to_i > 0 && error.empty?)

  # 2. Chỉ xóa đúng khung hình đã xuất, không đụng file khác
  keep = File.join(dir, 'ghi-chu.txt')
  File.write(keep, 'giữ lại')
  removed = F.delete_frames(frames)
  check('xóa: xóa đúng 12 khung hình đã xuất', removed == 12 && frames.none? { |f| File.exist?(f) })
  check('xóa: không xóa file không thuộc danh sách', File.exist?(keep) && File.exist?(output))

  # 3. Ghép lỗi (không có khung hình): báo lỗi, không tạo file rỗng
  bad_output = File.join(dir, 'loi.mp4')
  ok, error = F.encode('ffmpeg', File.join(dir, 'khong-co-%05d.png'), 30, bad_output)
  check('ghép lỗi: báo không thành công và không để lại file', !ok && !File.exist?(bad_output) && !error.empty?)

  # 4. Luồng đầy đủ: ghép, hỏi xóa, đồng ý xóa
  dialog_dir = File.join(dir, 'luong-1')
  Dir.mkdir(dialog_dir)
  frames = make_frames(dialog_dir, 'mau', 10)
  D.instance_variable_set(:@video, { 'frames' => true, 'folder' => dialog_dir, 'base' => 'mau', 'count' => 10, 'files' => frames })
  $answers = [IDYES, IDYES]
  $sent.clear
  D.finish_frames('fps' => 30, 'count' => 10)
  check('luồng: có MP4 và đã xóa 10 khung hình khi đồng ý', File.size?(File.join(dialog_dir, 'mau.mp4')).to_i > 0 && frames.none? { |f| File.exist?(f) })
  check('luồng: báo đã xóa đúng số khung', $sent.any? { |fn, d| fn == 'onToast' && d['message'].include?('xóa 10 ảnh') })

  # 5. Luồng: không đồng ý xóa thì giữ lại ảnh
  dialog_dir = File.join(dir, 'luong-2')
  Dir.mkdir(dialog_dir)
  frames = make_frames(dialog_dir, 'mau', 6)
  D.instance_variable_set(:@video, { 'frames' => true, 'folder' => dialog_dir, 'base' => 'mau', 'count' => 6, 'files' => frames })
  $answers = [IDNO]
  $sent.clear
  D.finish_frames('fps' => 30, 'count' => 6)
  check('luồng: không đồng ý thì giữ ảnh và vẫn có MP4', frames.all? { |f| File.exist?(f) } && File.size?(File.join(dialog_dir, 'mau.mp4')).to_i > 0)

  # 6. Luồng: file MP4 đã có, không đồng ý ghi đè thì không ghép, giữ ảnh
  dialog_dir = File.join(dir, 'luong-3')
  Dir.mkdir(dialog_dir)
  frames = make_frames(dialog_dir, 'mau', 5)
  File.write(File.join(dialog_dir, 'mau.mp4'), 'cu')
  D.instance_variable_set(:@video, { 'frames' => true, 'folder' => dialog_dir, 'base' => 'mau', 'count' => 5, 'files' => frames })
  $answers = [IDNO]
  D.finish_frames('fps' => 30, 'count' => 5)
  check('ghi đè: từ chối thì giữ MP4 cũ và giữ ảnh', File.read(File.join(dialog_dir, 'mau.mp4')) == 'cu' && frames.all? { |f| File.exist?(f) })

  # 7. Chưa có ffmpeg và người dùng không chọn: chỉ báo, không ghép
  dialog_dir = File.join(dir, 'luong-4')
  Dir.mkdir(dialog_dir)
  frames = make_frames(dialog_dir, 'mau', 4)
  D.instance_variable_set(:@video, { 'frames' => true, 'folder' => dialog_dir, 'base' => 'mau', 'count' => 4, 'files' => frames })
  F.define_singleton_method(:executable) { nil }
  $answers = [IDNO]
  $sent.clear
  D.finish_frames('fps' => 30, 'count' => 4)
  check('chưa có ffmpeg: không ghép và báo hướng dẫn',
        !File.exist?(File.join(dialog_dir, 'mau.mp4')) && $sent.any? { |fn, d| fn == 'onToast' && d['message'].include?('Chưa có ffmpeg') })
  F.singleton_class.send(:remove_method, :executable)

  # 8. Ghép lỗi trong luồng: báo lỗi, giữ ảnh, không hỏi xóa
  dialog_dir = File.join(dir, 'luong-5')
  Dir.mkdir(dialog_dir)
  D.instance_variable_set(:@video, { 'frames' => true, 'folder' => dialog_dir, 'base' => 'mau', 'count' => 0, 'files' => [] })
  $answers = []
  $boxes.clear
  $sent.clear
  D.finish_frames('fps' => 30, 'count' => 0)
  check('ghép lỗi trong luồng: báo lỗi, không hỏi xóa', $sent.any? { |fn, _| fn == 'onError' } && $answers.empty? && $boxes.none? { |t| t.include?('Xóa') })
end

# 9. Đường dẫn ffmpeg nhập tay: lưu file đúng, từ chối file sai, xóa được
ffmpeg_path = `which ffmpeg`.strip
Dir.mktmpdir do |dir|
  fake = File.join(dir, 'ffmpeg.exe')
  File.write(fake, "#!/bin/sh\necho 'khong phai ffmpeg'\n")
  File.chmod(0o755, fake)
  $defaults.delete(['VGD_Diagram', 'ffmpeg_path'])
  saved = F.save_path(ffmpeg_path)
  check('đường dẫn: lưu được ffmpeg thật và đọc lại được', saved == ffmpeg_path && F.saved_path == ffmpeg_path)
  rejected = begin
    F.save_path(fake)
    false
  rescue ArgumentError => error
    error.message.include?('ffmpeg')
  end
  check('đường dẫn: từ chối file không phải ffmpeg, giữ nguyên đường dẫn cũ', rejected && F.saved_path == ffmpeg_path)
  missing = begin
    F.save_path(File.join(dir, 'khong-co.exe'))
    false
  rescue ArgumentError => error
    error.message.include?('Không tìm thấy')
  end
  check('đường dẫn: báo khi file không tồn tại', missing)
  F.save_path('')
  check('đường dẫn: để trống là xóa cài đặt', F.saved_path.nil?)
end

# 10. Mở hộp thoại (đường đi thật của callback 'ready'): phải gửi đường dẫn ffmpeg đã lưu về giao diện
module UI
  class HtmlDialog
    STYLE_DIALOG = 0
    attr_reader :callbacks
    def initialize(*)
      @callbacks = {}
      @visible = false
    end
    def set_file(*); end
    def add_action_callback(name, &block)
      @callbacks[name] = block
    end
    def execute_script(*); nil; end
    def show; @visible = true; end
    def visible?; @visible; end
    def bring_to_front; end
    def close; @visible = false; end
  end
end

module Sketchup
  class FakeSelection
    def to_a; []; end
  end
  class FakeModel
    def selection; FakeSelection.new; end
    def entities; []; end
    def path; ''; end
    def find_entity_by_id(_id); nil; end
  end
  def self.active_model
    @model ||= FakeModel.new
  end
end

F.save_path(ffmpeg_path) # mục 9 đã xóa đường dẫn; lưu lại để kiểm tra đúng cái đang có
D.send(:remove_instance_variable, :@dlg) if D.instance_variable_defined?(:@dlg)
D.show
ready = D.instance_variable_get(:@dlg).callbacks['ready']
$sent.clear
ready.call(nil, nil)
settings = $sent.find { |fn, _| fn == 'onSettings' }
check('mở hộp thoại: giao diện nhận đường dẫn ffmpeg đã lưu (onSettings)', !settings.nil? && settings[1]['ffmpegPath'] == ffmpeg_path)
version_sent = $sent.find { |fn, _| fn == 'onVersion' }
check('mở hộp thoại: giao diện nhận số phiên bản (onVersion)', !version_sent.nil? && version_sent[1]['version'] == VGD::Diagram::VERSION)

# 11. Các callback đi đúng đường đi thật: payload là chuỗi JSON như SketchUp gửi
dlg = D.instance_variable_get(:@dlg)
call = ->(name, json) { dlg.callbacks.fetch(name).call(nil, json) }
Dir.mktmpdir do |dir|
  png = File.join(dir, 'mau.png')
  abort 'không tạo được PNG mẫu' unless system('ffmpeg', '-v', 'error', '-y', '-f', 'lavfi', '-i', 'color=c=red:s=64x48', '-frames:v', '1', png)
  png_b64 = Base64.strict_encode64(File.binread(png))

  $sent.clear
  call.call('save_ffmpeg', JSON.generate('path' => ffmpeg_path))
  check('callback save_ffmpeg: lưu đường dẫn thật', F.saved_path == ffmpeg_path)

  $sent.clear
  call.call('save_ffmpeg', JSON.generate('path' => File.join(dir, 'khong-co.exe')))
  check('callback save_ffmpeg: đường dẫn sai thì báo onError', $sent.any? { |fn, _| fn == 'onError' })

  $sent.clear
  $open_path = ffmpeg_path
  call.call('pick_ffmpeg', '{}')
  check('callback pick_ffmpeg: chọn file, lưu và gửi onSettings', F.saved_path == ffmpeg_path && $sent.any? { |fn, _| fn == 'onSettings' })

  $sent.clear
  $savepanel_path = File.join(dir, 'anh.jpg')
  call.call('export_views', '{"format":"jpg"}')
  check('callback export_views: mở hộp lưu và báo onExport jpg', $sent.any? { |fn, d| fn == 'onExport' && d['format'] == 'jpg' })
  call.call('save_image', JSON.generate('key' => 'truoc', 'data' => "data:image/jpeg;base64,#{png_b64}"))
  check('callback save_image: ghi ảnh .jpg đúng tên', File.file?(File.join(dir, 'anh-truoc.jpg')))

  $sent.clear
  $savepanel_path = File.join(dir, 'clip.png')
  call.call('export_video', '{"format":"png"}')
  check('callback export_video (png): báo onVideo png', $sent.any? { |fn, d| fn == 'onVideo' && d['format'] == 'png' })
  3.times { |i| call.call('save_frame', JSON.generate('index' => i + 1, 'data' => "data:image/png;base64,#{png_b64}")) }
  check('callback save_frame: ghi đủ 3 khung PNG', (1..3).all? { |i| File.file?(File.join(dir, format('clip-khung-%05d.png', i))) })
  $answers = [IDYES, IDYES]
  $sent.clear
  call.call('video_done', '{"count":3,"fps":30}')
  check('callback video_done: ghép được MP4 bằng ffmpeg thật', File.size?(File.join(dir, 'clip.mp4')).to_i > 0)
  check('callback video_done: xóa khung khi đồng ý', Dir.glob(File.join(dir, 'clip-khung-*.png')).empty?)
  check('callback video_done: báo kết quả cho giao diện', $sent.any? { |fn, _| fn == 'onToast' })

  # Video WebM: không có đuôi thì thêm .webm; đuôi mp4 bị từ chối; ext không khớp bị từ chối; ghi đúng file
  $sent.clear
  $savepanel_path = File.join(dir, 'clip-webm')
  call.call('export_video', '{"format":"webm"}')
  check('callback export_video (webm): không có đuôi thì thêm .webm', $sent.any? { |fn, d| fn == 'onVideo' && d['format'] == 'webm' })
  $sent.clear
  $savepanel_path = File.join(dir, 'clip-mp4.mp4')
  call.call('export_video', '{"format":"webm"}')
  check('callback export_video: đuôi .mp4 bị từ chối', $sent.any? { |fn, _| fn == 'onError' })
  $sent.clear
  $savepanel_path = File.join(dir, 'clip-webm')
  call.call('export_video', '{"format":"webm"}')
  $sent.clear
  call.call('save_video', JSON.generate('ext' => 'mp4', 'data' => 'data:video/mp4;base64,AAAA'))
  check('callback save_video: ext không khớp thì báo onError và không ghi', $sent.any? { |fn, _| fn == 'onError' } && !File.exist?(File.join(dir, 'clip-webm.webm')))
  webm_bytes = 'du-lieu-webm-gia-lap'
  call.call('save_video', JSON.generate('ext' => 'webm', 'data' => "data:video/webm;base64,#{Base64.strict_encode64(webm_bytes)}"))
  check('callback save_video: ghi đúng file .webm', File.binread(File.join(dir, 'clip-webm.webm')) == webm_bytes)
  check('callback save_video: báo đã lưu', $sent.any? { |fn, d| fn == 'onToast' && d['message'].include?('clip-webm.webm') })

  # Đuôi viết hoa trong hộp lưu (Anh.PNG): phần tên không được dính đuôi.
  $sent.clear
  $savepanel_path = File.join(dir, 'Anh.PNG')
  call.call('export_views', '{"format":"png"}')
  call.call('save_image', JSON.generate('key' => 'truoc', 'data' => "data:image/png;base64,#{png_b64}"))
  check('đuôi .PNG viết hoa: ảnh xuất ra tên Anh-truoc.png, không dính đuôi', File.file?(File.join(dir, 'Anh-truoc.png')))
  call.call('export_done', '{}')

  # Đuôi .PNG viết hoa ở video chuỗi khung hình, kèm dấu % trong tên thư mục và tên file:
  # mẫu khung hình của ffmpeg dùng % nên phải thoát thành %%.
  special = File.join(dir, 'tu 50%')
  Dir.mkdir(special)
  $sent.clear
  $savepanel_path = File.join(special, 'Bep 100%.PNG')
  call.call('export_video', '{"format":"png"}')
  3.times { |i| call.call('save_frame', JSON.generate('index' => i + 1, 'data' => "data:image/png;base64,#{png_b64}")) }
  check('khung hình: tên có đuôi .PNG viết hoa vẫn đúng Bep 100%-khung-00001.png', File.file?(File.join(special, 'Bep 100%-khung-00001.png')))
  $answers = [IDNO]
  call.call('video_done', '{"count":3,"fps":30}')
  check('dấu % trong tên file và thư mục: ghép được MP4', File.size?(File.join(special, 'Bep 100%.mp4')).to_i > 0)
  check('dấu % trong tên: không xóa khung khi người dùng chọn giữ', Dir.glob(File.join(special, '*.png')).size == 3)
end

puts
# 12. Nhập thư mục (ví dụ C:\Program Files\ShareX), dự phòng mpeg4 khi thiếu libx264, và không có bộ mã hóa nào
ffmpeg_real = `which ffmpeg`.strip
Dir.mktmpdir do |dir|
  bin = File.join(dir, 'bin')
  Dir.mkdir(bin)
  File.symlink(ffmpeg_real, File.join(bin, 'ffmpeg.exe'))
  check('thư mục: tìm được bin\ffmpeg.exe trong thư mục đã nhập', F.resolve(dir) == File.join(bin, 'ffmpeg.exe'))
  check('thư mục: nhận đường dẫn file và đường dẫn có dấu ngoặc kép', F.resolve(File.join(bin, 'ffmpeg.exe')) == File.join(bin, 'ffmpeg.exe') && F.resolve("\"#{bin}\"") == File.join(bin, 'ffmpeg.exe'))
  empty = File.join(dir, 'trong')
  Dir.mkdir(empty)
  check('thư mục: thư mục không có ffmpeg thì không tìm thấy', F.resolve(empty).nil?)
  check('thư mục: chuỗi rỗng không tìm thấy', F.resolve('  ').nil?)

  F.save_path(dir)
  check('thư mục: lưu đường dẫn file, không lưu thư mục', F.saved_path == File.join(bin, 'ffmpeg.exe'))
  F.save_path('')

  # Wrapper giả lập ffmpeg không có libx264: danh sách bộ mã hóa bỏ libx264 (và mpeg4 nếu cần)
  wrap = File.join(dir, 'wrap-no-x264.sh')
  File.write(wrap, "#!/bin/sh\nif [ \"$1\" = \"-hide_banner\" ] && [ \"$2\" = \"-encoders\" ]; then\n  \"#{ffmpeg_real}\" -hide_banner -encoders | grep -v libx264\n  exit 0\nfi\nexec \"#{ffmpeg_real}\" \"$@\"\n")
  File.chmod(0o755, wrap)
  check('mpeg4: ffmpeg thiếu libx264 chọn bộ mã hóa mpeg4', F.encoder_for(wrap)&.first == 'mpeg4')
  check('mpeg4: file này vẫn được chấp nhận', F.problem_with(wrap).nil?)
  make_frames(dir, 'mp4', 12)
  mp4_out = File.join(dir, 'mp4.mp4')
  ok, error = F.encode(wrap, File.join(dir, 'mp4-khung-%05d.png'), 30, mp4_out)
  check('mpeg4: ghép được MP4 khi thiếu libx264', ok && File.size?(mp4_out).to_i > 0 && error.empty?)

  wrap_none = File.join(dir, 'wrap-none.sh')
  File.write(wrap_none, "#!/bin/sh\nif [ \"$1\" = \"-hide_banner\" ] && [ \"$2\" = \"-encoders\" ]; then\n  \"#{ffmpeg_real}\" -hide_banner -encoders | grep -v -e libx264 -e mpeg4\n  exit 0\nfi\nexec \"#{ffmpeg_real}\" \"$@\"\n")
  File.chmod(0o755, wrap_none)
  check('không bộ mã hóa: báo rõ thiếu libx264 và MPEG-4', F.problem_with(wrap_none).to_s.include?('libx264'))
  ok_none, _error = F.encode(wrap_none, File.join(dir, 'mp4-khung-%05d.png'), 30, File.join(dir, 'none.mp4'))
  check('không bộ mã hóa: không ghép và không tạo file', !ok_none && !File.exist?(File.join(dir, 'none.mp4')))
  rejected = begin
    F.save_path(wrap_none)
    false
  rescue ArgumentError
    true
  end
  check('không bộ mã hóa: không lưu đường dẫn', rejected && F.saved_path.nil?)

  # File không phải ffmpeg: thông báo phải nêu mã thoát và dòng đầu kết quả
  notff = File.join(dir, 'khong-phai.exe')
  File.write(notff, "#!/bin/sh\necho 'chay thu sai'\nexit 3\n")
  File.chmod(0o755, notff)
  message = F.problem_with(notff).to_s
  check('báo lỗi: nêu mã thoát và dòng đầu kết quả', message.include?('mã thoát 3') && message.include?('chay thu sai'))
end
$defaults.delete(['VGD_Diagram', 'ffmpeg_path'])

puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "CÓ #{$fail.size} LỖI: #{$fail.inspect}"
exit($fail.empty? ? 0 : 1)
