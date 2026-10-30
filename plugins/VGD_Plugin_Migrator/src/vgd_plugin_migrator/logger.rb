# encoding: UTF-8
require 'fileutils'

module VGD
  module PluginMigrator
    # Ghi nhật ký lỗi ra file để dễ gửi cho người hỗ trợ. Không bao giờ làm plugin lỗi theo.
    module Log
      MAX_BYTES = 512 * 1024   # quá cỡ này thì đổi tên thành .1 và ghi file mới

      def self.dir
        File.join(ENV['APPDATA'].to_s.tr('\\', '/'), 'SketchUp', 'VGD_PluginMigrator')
      end

      def self.path
        File.join(dir, 'migrator.log')
      end

      # exc: ngoại lệ (nếu có) để ghi kèm loại lỗi và vài dòng đầu của backtrace
      def self.write(message, exc = nil)
        FileUtils.mkdir_p(dir)
        rotate
        lines = ["[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{message}"]
        if exc
          lines << "  #{exc.class}: #{exc.message}"
          Array(exc.backtrace).first(5).each { |b| lines << "    #{b}" }
        end
        File.open(path, 'a:UTF-8') { |f| f.puts(lines) }
        true
      rescue StandardError
        false
      end

      # Câu nhắc người dùng biết xem log ở đâu
      def self.hint
        "Chi tiết lỗi đã ghi vào: #{path}"
      end

      def self.rotate
        return unless File.exist?(path) && File.size(path) > MAX_BYTES
        FileUtils.mv(path, "#{path}.1", force: true)
      end
    end
  end
end
