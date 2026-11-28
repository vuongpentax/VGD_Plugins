# encoding: UTF-8
# Kiểm tra ghép MP4 và xóa khung hình (ffmpeg.rb, dialog.rb: finish_frames) bằng ffmpeg thật trên máy.
# Chạy từ plugins/VGD_Diagram: ruby dev/test_ffmpeg.rb  (cần ffmpeg trong PATH)
require 'tmpdir'
require 'fileutils'
require 'open3'

$LOADED_FEATURES << 'sketchup.rb'
$defaults = {}
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
    nil
  end
end

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
D.define_singleton_method(:send_js) { |fn, data| $sent << [fn, data] }

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

puts
puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "CÓ #{$fail.size} LỖI: #{$fail.inspect}"
exit($fail.empty? ? 0 : 1)
