# encoding: UTF-8
# Ghép chuỗi khung hình PNG thành MP4 bằng ffmpeg đã cài trên máy người dùng.
# Chương trình được gọi bằng danh sách tham số (không qua shell). Chỉ chạy đúng file ffmpeg người dùng đã chọn
# hoặc lệnh ffmpeg trong PATH.
require 'open3'

module VGD
  module Diagram
    module Ffmpeg
      extend self

      SECTION = 'VGD_Diagram'.freeze
      SETTING = 'ffmpeg_path'.freeze

      # Đường dẫn ffmpeg đã lưu từ lần trước, nếu file còn tồn tại.
      def saved_path
        path = Sketchup.read_default(SECTION, SETTING, '').to_s
        path.empty? || !File.file?(path) ? nil : path
      end

      # Ưu tiên đường dẫn đã lưu, rồi đến lệnh ffmpeg trong PATH. Trả về nil nếu không có.
      def executable
        return saved_path if saved_path
        _output, status = Open3.capture2e('ffmpeg', '-version')
        status.success? ? 'ffmpeg' : nil
      rescue SystemCallError
        nil
      end

      # Hỏi người dùng chọn file ffmpeg rồi lưu lại. Trả về nil nếu bấm Hủy.
      def choose
        path = UI.openpanel('Chọn file ffmpeg', '', 'ffmpeg|ffmpeg.exe||')
        return nil unless path
        save_path(path)
      end

      # Kiểm tra file có đúng là ffmpeg và có bộ mã hóa libx264 không. Trả về thông báo lỗi, hoặc nil nếu đạt.
      def problem_with(path)
        return 'Không tìm thấy file này.' unless File.file?(path)
        version, status = Open3.capture2e(path, '-version')
        return 'File này không chạy được như ffmpeg.' unless status.success? && version.include?('ffmpeg version')
        encoders, _status = Open3.capture2e(path, '-hide_banner', '-encoders')
        return 'ffmpeg này không có bộ mã hóa libx264 (cần để ghép MP4).' unless encoders.include?('libx264')
        nil
      rescue SystemCallError => error
        "Không chạy được file này: #{error.message}"
      end

      # Lưu đường dẫn ffmpeg cho lần sau. Chuỗi rỗng là xóa cài đặt. Ném ArgumentError nếu file không dùng được.
      def save_path(path)
        path = path.to_s.strip
        if path.empty?
          Sketchup.write_default(SECTION, SETTING, '')
          return nil
        end
        problem = problem_with(path)
        raise ArgumentError, problem if problem
        Sketchup.write_default(SECTION, SETTING, path)
        path
      end

      # Ghép khung hình thành MP4. Trả về [thành công?, thông báo lỗi].
      # frame_pattern ví dụ: "/thu-muc/lap-rap-khung-%05d.png".
      def encode(exe, frame_pattern, fps, output)
        output_text, status = Open3.capture2e(exe, '-y', '-framerate', fps.to_s, '-i', frame_pattern,
                                              '-c:v', 'libx264', '-pix_fmt', 'yuv420p', output)
        ok = status.success? && File.size?(output).to_i.positive?
        [ok, ok ? '' : output_text.lines.last(5).join]
      rescue SystemCallError => error
        [false, error.message]
      end

      # Xóa đúng các file khung hình đã được tạo trong lần xuất này. Trả về số file đã xóa.
      def delete_frames(paths)
        paths.count { |path| File.file?(path) && File.delete(path) }
      end
    end
  end
end
