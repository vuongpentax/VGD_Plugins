# encoding: UTF-8
# Ghép chuỗi khung hình PNG thành MP4 bằng ffmpeg đã cài trên máy người dùng.
# Chương trình được gọi bằng danh sách tham số (không qua shell). Chỉ chạy file ffmpeg người dùng đã chọn
# hoặc lệnh ffmpeg trong PATH.
# Ghép chạy NỀN, không chặn SketchUp: start_encode chạy ffmpeg bằng Process.spawn (ghi tiến trình và thông báo ra file
# tạm), người gọi hỏi poll theo bộ hẹn giờ của SketchUp. Không dùng luồng Ruby (luồng trong SketchUp chỉ chạy khi
# giao diện rảnh) và không đọc ống (ống đầy thì ffmpeg bị kẹt).
require 'open3'
require 'tmpdir'

module VGD
  module Diagram
    module Ffmpeg
      extend self

      # Quá số giây này mà số khung ghép được không tăng thì coi là ffmpeg đứng và dừng.
      STALL_SECONDS = 120
      # Một lần ghép: pid, file tiến trình và file thông báo (tạm), file MP4 đầu ra, tổng số khung, số khung mới nhất.
      Job = Struct.new(:pid, :progress_path, :log_path, :output, :total, :last_frame, :last_change)

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

      # Bắt đầu ghép khung hình thành MP4 và trả về ngay một Job (không chờ ffmpeg).
      # frame_pattern ví dụ: "/thu-muc/lap-rap-khung-%05d.png"; total là số khung (để tính phần trăm).
      # Ném ArgumentError nếu ffmpeg không có bộ mã hóa phù hợp, SystemCallError nếu không chạy được file.
      def start_encode(exe, frame_pattern, fps, output, total)
        _name, codec_args = encoder_for(exe)
        raise ArgumentError, 'ffmpeg không có bộ mã hóa phù hợp.' unless codec_args
        stem = File.join(Dir.tmpdir, "vgd_diagram_ffmpeg_#{Process.pid}_#{Time.now.to_i}_#{rand(1_000_000)}")
        progress = "#{stem}.progress"
        log = "#{stem}.log"
        pid = Process.spawn(exe, '-y', '-nostdin', '-hide_banner', '-nostats', '-progress', progress,
                            '-framerate', fps.to_s, '-i', frame_pattern, *codec_args, output,
                            in: File::NULL, %i[out err] => log)
        Job.new(pid, progress, log, output, total.to_i, 0, Time.now)
      end

      # Hỏi tình trạng. Trả về {state: :running, frame: n}, hoặc khi đã kết thúc {state: :done | :stalled, ok:, error:, frame:}.
      # Kết thúc thì file tạm đã được xóa; ghép lỗi hoặc bị dừng thì file MP4 dở cũng bị xóa.
      def poll(job, stall: STALL_SECONDS)
        frame = last_frame(job.progress_path)
        if frame > job.last_frame
          job.last_frame = frame
          job.last_change = Time.now
        end
        status = begin
          Process.wait2(job.pid, Process::WNOHANG)&.last
        rescue Errno::ECHILD
          :gone # tiến trình đã được thu dọn nơi khác: xét theo file đầu ra
        end
        if status
          ok = (status == :gone || status.success?) && File.size?(job.output).to_i.positive?
          error = ok ? '' : message_from(job.log_path)
          finish(job, keep_output: ok)
          return { state: :done, ok: ok, error: error, frame: job.last_frame }
        end
        return { state: :running, frame: job.last_frame } if Time.now - job.last_change <= stall
        cancel(job)
        { state: :stalled, ok: false, frame: job.last_frame,
          error: "ffmpeg không có tiến triển trong #{stall} giây nên đã dừng." }
      end

      # Dừng ffmpeg (nếu còn chạy), xóa file MP4 dở và file tạm.
      def cancel(job)
        begin
          Process.kill('KILL', job.pid)
        rescue Errno::ESRCH, Errno::EPERM
          nil
        end
        begin
          Process.wait(job.pid)
        rescue Errno::ECHILD
          nil
        end
        finish(job, keep_output: false)
      end

      # Số khung mới nhất ffmpeg báo trong file tiến trình (chỉ đọc phần cuối file). 0 nếu chưa có.
      def last_frame(path)
        size = File.size?(path).to_i
        return 0 if size.zero?
        text = File.open(path, 'rb') do |file|
          file.seek([size - 4096, 0].max)
          file.read
        end
        text.scan(/^frame=(\d+)/).flatten.last.to_i
      rescue SystemCallError
        0
      end

      # 5 dòng cuối thông báo của ffmpeg, để báo lỗi cho người dùng.
      def message_from(log_path)
        return '' unless File.file?(log_path)
        File.binread(log_path).force_encoding(Encoding::UTF_8).scrub.lines.last(5).join
      rescue SystemCallError
        ''
      end

      def finish(job, keep_output:)
        paths = [job.progress_path, job.log_path]
        paths << job.output unless keep_output
        paths.each { |path| File.delete(path) if File.file?(path) }
      rescue SystemCallError
        nil
      end

      # Xóa đúng các file khung hình đã được tạo trong lần xuất này. Trả về số file đã xóa.
      def delete_frames(paths)
        paths.count { |path| File.file?(path) && File.delete(path) }
      end
    end
  end
end
