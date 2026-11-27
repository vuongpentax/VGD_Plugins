require 'open3'
require 'tmpdir'
require 'rbconfig'

module VGD
  module BIM
    # Đọc ảnh đang có trong clipboard của Windows khi cửa sổ web không đọc được (HtmlDialog của SketchUp có thể chặn
    # navigator.clipboard). Chạy PowerShell có sẵn của Windows một lần, chỉ khi người dùng bấm nút dán: lấy ảnh clipboard ra file PNG tạm
    # (đường dẫn truyền bằng biến môi trường, không ghép vào lệnh), đọc rồi xóa. Trả về bytes PNG; việc thu nhỏ và lưu do giao diện làm
    # qua đường dán ảnh thường (image_set). Nền tảng khác Windows chưa hỗ trợ.
    module ClipboardImage
      MAX_BYTES = 20 * 1024 * 1024 # ảnh chụp cả màn hình lớn có thể nặng; giao diện thu nhỏ lại trước khi lưu
      TIMEOUT = 10                 # giây
      EMPTY_EXIT = 3               # mã thoát của PowerShell khi clipboard không có ảnh
      ENV_OUT = 'VGD_BIM_CLIP_OUT'.freeze
      SCRIPT = [
        "$ErrorActionPreference='Stop'",
        'Add-Type -AssemblyName System.Windows.Forms',
        'Add-Type -AssemblyName System.Drawing',
        '$img=[System.Windows.Forms.Clipboard]::GetImage()',
        "if($null -eq $img){exit #{EMPTY_EXIT}}",
        "$img.Save($env:#{ENV_OUT},[System.Drawing.Imaging.ImageFormat]::Png)",
        '$img.Dispose()'
      ].join(';').freeze

      class Empty < StandardError; end

      def self.windows?
        RbConfig::CONFIG['host_os'].to_s.match?(/mswin|mingw|cygwin/i)
      end

      # runner: lambda(đường_dẫn_file_đích) -> [mã_thoát, lỗi]; mặc định chạy PowerShell (test thay bằng bản giả).
      def self.read_png(runner: nil)
        unless runner
          raise 'Dán bằng nút chỉ có trên Windows. Hãy bấm vào ô ảnh rồi nhấn Ctrl+V.' unless windows?
          runner = method(:run_powershell)
        end
        path = File.join(Dir.tmpdir, "vgd_bim_clip_#{Process.pid}_#{(Time.now.to_f * 1000).to_i}.png")
        code, error = runner.call(path)
        raise Empty, 'Trong clipboard chưa có ảnh. Hãy chụp màn hình hoặc copy ảnh rồi bấm lại.' if code == EMPTY_EXIT
        raise "Không đọc được clipboard bằng PowerShell: #{error.to_s.strip.lines.first.to_s.strip[0, 160]}" unless code.zero?
        raise 'Không lấy được ảnh từ clipboard.' unless File.file?(path)
        raise "Ảnh trong clipboard quá lớn (tối đa #{MAX_BYTES / 1024 / 1024} MB)." if File.size(path) > MAX_BYTES
        bytes = File.binread(path)
        raise 'Ảnh trong clipboard không phải PNG hợp lệ.' unless Images.png?(bytes)
        bytes
      ensure
        File.delete(path) if path && File.file?(path)
      end

      def self.run_powershell(path)
        command = ['powershell.exe', '-NoProfile', '-NonInteractive', '-STA', '-WindowStyle', 'Hidden', '-Command', SCRIPT]
        Open3.popen3({ENV_OUT => path}, *command) do |stdin, stdout, stderr, thread|
          stdin.close
          unless thread.join(TIMEOUT)
            Process.kill('KILL', thread.pid) rescue nil
            raise 'PowerShell không trả lời kịp (quá 10 giây).'
          end
          stdout.read
          [thread.value.exitstatus, stderr.read]
        end
      rescue SystemCallError => error
        raise "Không chạy được PowerShell: #{error.message}"
      end
    end
  end
end
