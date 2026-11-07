require 'fileutils'
require_relative 'settings'

module VGD
  module BIM
    # Ảnh của từng món đồ, lưu thành file PNG trong thư mục ảnh của cài đặt:
    #   <thư mục ảnh>/<mã model>/<mã đối tượng>.png      ảnh đầy đủ
    #   <thư mục ảnh>/<mã model>/<mã đối tượng>_t.png    ảnh nhỏ để hiện trong bảng
    # Mã đối tượng là persistent_id của group / component. Không ghi gì vào file SketchUp.
    module Images
      MAX_BYTES = 8 * 1024 * 1024 # ảnh dán / kéo thả quá lớn thì từ chối
      PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze
      KINDS = {full: '.png', thumb: '_t.png'}.freeze

      def self.model_key(model)
        key = model.guid.to_s.gsub(/[^A-Za-z0-9-]/, '')
        key.empty? ? 'model' : key
      end

      def self.dir(model)
        File.join(Settings.image_dir, model_key(model))
      end

      def self.path(model, pid, kind = :full)
        File.join(dir(model), "#{id!(pid)}#{KINDS.fetch(kind)}")
      end

      def self.temp_path(model, pid, kind)
        File.join(dir(model), "#{id!(pid)}.tmp#{kind == :thumb ? '_t' : ''}.png")
      end

      def self.id!(pid)
        number = pid.is_a?(Integer) ? pid : (Integer(pid.to_s, 10) rescue nil)
        raise ArgumentError, 'Mã đối tượng không hợp lệ.' unless number && number > 0
        number
      end

      # {has: có ảnh không, stamp: giây sửa đổi cuối} để giao diện biết khi nào cần tải lại.
      def self.info(model, pid, folder = dir(model))
        file = File.join(folder, "#{id!(pid)}#{KINDS.fetch(:full)}")
        File.file?(file) ? {has: true, stamp: File.mtime(file).to_i} : {has: false, stamp: 0}
      end

      def self.png?(bytes)
        bytes.is_a?(String) && bytes.bytesize > PNG_SIGNATURE.bytesize && bytes.byteslice(0, PNG_SIGNATURE.bytesize).b == PNG_SIGNATURE
      end

      def self.check_png!(bytes)
        raise ArgumentError, 'Dữ liệu không phải ảnh PNG.' unless png?(bytes)
        raise ArgumentError, "Ảnh quá lớn (tối đa #{MAX_BYTES / 1024 / 1024} MB)." if bytes.bytesize > MAX_BYTES
        bytes
      end

      # Ảnh do giao diện gửi lên (dán, kéo thả): base64 hoặc data URL. Chỉ nhận PNG.
      def self.decode_png(text)
        raise ArgumentError, 'Không đọc được ảnh.' unless text.is_a?(String) && !text.empty?
        # Chặn sớm trước khi giải mã để dữ liệu khổng lồ không ngốn bộ nhớ.
        raise ArgumentError, "Ảnh quá lớn (tối đa #{MAX_BYTES / 1024 / 1024} MB)." if text.bytesize > MAX_BYTES * 4 / 3 + 1024
        payload = text.sub(%r{\Adata:image/png;base64,}, '')
        bytes = payload.unpack1('m0')
        check_png!(bytes)
      rescue ArgumentError => error
        raise ArgumentError, 'Không đọc được ảnh.' if error.message.include?('invalid base64')
        raise
      end

      # Ghi cả ảnh chính và ảnh nhỏ. Kiểm tra cả hai trước khi ghi nên không để lại ảnh dở.
      def self.write(model, pid, full, thumb)
        check_png!(full)
        check_png!(thumb)
        FileUtils.mkdir_p(dir(model))
        {full: full, thumb: thumb}.each do |kind, bytes|
          temp = temp_path(model, pid, kind)
          File.binwrite(temp, bytes)
          replace_file(temp, path(model, pid, kind))
        end
      end

      # Đổi file tạm do SketchUp chụp (write_image) thành ảnh chính. Không phải PNG hoặc chưa có file thì giữ ảnh cũ.
      def self.commit(model, pid, kind)
        temp = temp_path(model, pid, kind)
        raise ArgumentError, 'SketchUp không tạo được ảnh. Kiểm tra thư mục lưu ảnh trong bảng Preset.' unless File.file?(temp)
        begin
          check_png!(File.binread(temp))
        rescue ArgumentError
          File.delete(temp)
          raise
        end
        replace_file(temp, path(model, pid, kind))
      end

      def self.delete(model, pid)
        KINDS.each_key { |kind| FileUtils.rm_f(path(model, pid, kind)) }
      end

      def self.data_url(file)
        return nil unless File.file?(file)
        "data:image/png;base64,#{[File.binread(file)].pack('m0')}"
      end

      def self.replace_file(temp, final)
        File.delete(final) if File.exist?(final)
        File.rename(temp, final)
      end
    end
  end
end
