# encoding: UTF-8
# Ghép chuỗi khung hình PNG thành MP4 bằng ffmpeg đã cài trên máy người dùng.
# Chương trình được gọi bằng danh sách tham số (không qua shell). Chỉ chạy file ffmpeg người dùng đã chọn
# hoặc lệnh ffmpeg trong PATH.
require 'open3'

module VGD
  module Diagram
    module Ffmpeg
      extend self

      SECTION = 'VGD_Diagram'.freeze
      SETTING = 'ffmpeg_path'.freeze
      # Bộ mã hóa ưu tiên: H.264 (libx264). Nếu ffmpeg không có, dùng MPEG-4 Part 2 (vẫn là MP4).
      ENCODERS = [
        ['libx264', %w[-c:v libx264 -pix_fmt yuv420p]],
        ['mpeg4', %w[-c:v mpeg4 -q:v 3 -pix_fmt yuv420p]]
      ].freeze

      # Đường dẫn ffmpeg đã lưu từ lần trước, nếu còn tồn tại.
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

      # Từ đường dẫn người dùng nhập, tìm file ffmpeg: có thể là file ffmpeg.exe, hoặc thư mục chứa nó
      # (ví dụ C:\Program Files\ShareX, hoặc thư mục có bin\ffmpeg.exe). Trả về đường dẫn file, hoặc nil.
      def resolve(path)
        path = path.to_s.strip.delete_prefix('"').delete_suffix('"')
        return nil if path.empty?
        return path if File.file?(path)
        return nil unless File.directory?(path)
        ['ffmpeg.exe', 'ffmpeg', File.join('bin', 'ffmpeg.exe'), File.join('bin', 'ffmpeg')]
          .map { |name| File.join(path, name) }
          .find { |candidate| File.file?(candidate) }
      end

      # Bộ mã hóa dùng được của ffmpeg: [tên, tham số] đầu tiên có trong danh sách. Trả về nil nếu không có.
      def encoder_for(exe)
        encoders, _status = Open3.capture2e(exe, '-hide_banner', '-encoders')
        available = encoders.lines.map { |line| line[/^\s*V\S*\s+(\S+)/, 1] }.compact
        ENCODERS.find { |name, _args| available.include?(name) }
      end

      # Kiểm tra file có đúng là ffmpeg và có bộ mã hóa dùng được không. Trả về thông báo lỗi, hoặc nil nếu đạt.
      def problem_with(path)
        return 'Không tìm thấy file ffmpeg.exe tại đường dẫn này. Hãy chọn file ffmpeg.exe hoặc thư mục chứa nó.' unless File.file?(path)
        version, status = Open3.capture2e(path, '-version')
        return "File này không phải ffmpeg (#{describe_run(version, status)})." unless status.success? && version.include?('ffmpeg version')
        return 'ffmpeg này không có bộ mã hóa H.264 (libx264) hay MPEG-4, nên không ghép được MP4.' unless encoder_for(path)
        nil
      rescue SystemCallError => error
        "Không chạy được file này: #{error.message}"
      end

      # Mã thoát và dòng đầu kết quả khi chạy thử, để báo lỗi cho người dùng biết vì sao.
      def describe_run(output, status)
        first_line = output.to_s.scrub.lines.map(&:strip).reject(&:empty?).first
        "mã thoát #{status.exitstatus.inspect}, kết quả: #{first_line ? first_line[0, 160] : 'không có'}"
      end

      # Lưu đường dẫn ffmpeg cho lần sau (nhận file hoặc thư mục). Chuỗi rỗng là xóa cài đặt.
      # Ném ArgumentError nếu không tìm thấy hoặc file không dùng được. Trả về đường dẫn file đã lưu.
      def save_path(input)
        if input.to_s.strip.empty?
          Sketchup.write_default(SECTION, SETTING, '')
          return nil
        end
        path = resolve(input)
        raise ArgumentError, 'Không tìm thấy ffmpeg.exe trong đường dẫn này. Hãy nhập đường dẫn tới file ffmpeg.exe hoặc thư mục chứa nó.' unless path
        problem = problem_with(path)
        raise ArgumentError, problem if problem
        Sketchup.write_default(SECTION, SETTING, path)
        path
      end

      # Mẫu tên khung hình cho ffmpeg (-i): "<tên>-khung-%05d.png" trong thư mục. ffmpeg hiểu % là chỗ đánh số nên
      # dấu % trong thư mục hoặc tên file người dùng đặt phải thoát thành %%.
      def frame_pattern(folder, base)
        File.join(folder.to_s.gsub('%', '%%'), "#{base.to_s.gsub('%', '%%')}-khung-%05d.png")
      end

      # Ghép khung hình thành MP4. Trả về [thành công?, thông báo lỗi].
      # frame_pattern ví dụ: "/thu-muc/lap-rap-khung-%05d.png".
      def encode(exe, frame_pattern, fps, output)
        _name, codec_args = encoder_for(exe)
        return [false, 'ffmpeg không có bộ mã hóa phù hợp.'] unless codec_args
        output_text, status = Open3.capture2e(exe, '-y', '-framerate', fps.to_s, '-i', frame_pattern,
                                              *codec_args, output)
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
