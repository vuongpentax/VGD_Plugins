require 'fileutils'
require 'securerandom'
require_relative 'settings'

module VGD
  module BIM
    # Ảnh của từng món đồ, lưu thành file PNG trong thư mục ảnh của cài đặt:
    #   <thư mục ảnh>/<mã model>/<mã đối tượng>.png      ảnh đầy đủ, cũng là ảnh hiện trong bảng (không còn ảnh nhỏ)
    # Mã đối tượng là persistent_id của group / component. Không ghi gì vào file SketchUp.
    module Images
      MAX_BYTES = 8 * 1024 * 1024 # ảnh dán / kéo thả quá lớn thì từ chối
      PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze
      KINDS = {full: '.png'}.freeze
      LEGACY_THUMB = '_t.png'.freeze # ảnh nhỏ của các bản beta trước: không còn tạo hay đọc, chỉ dọn khi xóa ảnh

      # Thư mục ảnh của model theo mã cố định lưu trong chính file SketchUp (dictionary VGD_BIM_MODEL). Không dùng model.guid vì SketchUp
      # cấp guid mới mỗi lần mở file, nên ảnh bị "mất" sau khi tắt mở lại. Chưa có mã (hoặc model không có API thuộc tính) thì dùng guid.
      MODEL_DICTIONARY = 'VGD_BIM_MODEL'.freeze
      MODEL_ID_KEY = 'model_id'.freeze
      MODEL_ID_PATTERN = /\A[A-Za-z0-9-]{8,64}\z/

      def self.model_key(model)
        stored_id(model) || legacy_key(model)
      end

      def self.legacy_key(model)
        key = model.guid.to_s.gsub(/[^A-Za-z0-9-]/, '')
        key.empty? ? 'model' : key
      end

      def self.stored_id(model)
        return nil unless model.respond_to?(:get_attribute)
        id = model.get_attribute(MODEL_DICTIONARY, MODEL_ID_KEY).to_s
        id.match?(MODEL_ID_PATTERN) ? id : nil
      end

      # Tạo mã cố định cho model nếu chưa có (một lần, ghi vào file SketchUp; cần lưu file để mã được giữ) và chuyển ảnh của phiên
      # hiện tại (thư mục theo guid) sang thư mục theo mã mới. Gọi trước khi chụp / hiện ảnh, ngoài mọi thao tác đang mở. Trả về mã,
      # hoặc nil nếu không ghi được (khi đó vẫn dùng guid như trước, không báo lỗi).
      def self.ensure_model_id(model)
        existing = stored_id(model)
        return existing if existing
        return nil unless model.respond_to?(:set_attribute) && model.respond_to?(:start_operation)
        id = SecureRandom.uuid
        model.start_operation('VGD_BIM · Mã model', true, false, true) # trong suốt: gộp vào bước hoàn tác trước, không thêm bước mới
        begin
          model.set_attribute(MODEL_DICTIONARY, MODEL_ID_KEY, id)
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end
        adopt_legacy_folder(model, id)
        id
      rescue StandardError => error
        BIM.log("Không ghi được mã model: #{error.message}")
        nil
      end

      # Ảnh đã chụp trong phiên này nằm ở thư mục theo guid: đổi tên thành thư mục theo mã mới (không đè nếu đã có).
      def self.adopt_legacy_folder(model, id)
        old = File.join(Settings.image_dir, legacy_key(model))
        new = File.join(Settings.image_dir, id)
        File.rename(old, new) if File.directory?(old) && !File.exist?(new)
      rescue SystemCallError => error
        BIM.log("Không chuyển được thư mục ảnh cũ: #{error.message}")
      end

      def self.dir(model)
        File.join(Settings.image_dir, model_key(model))
      end

      def self.path(model, pid)
        File.join(dir(model), "#{id!(pid)}#{KINDS.fetch(:full)}")
      end

      def self.temp_path(model, pid)
        File.join(dir(model), "#{id!(pid)}.tmp.png")
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

      # Ghi ảnh (kiểm tra PNG trước khi ghi nên không để lại ảnh dở).
      def self.write(model, pid, full)
        check_png!(full)
        FileUtils.mkdir_p(dir(model))
        temp = temp_path(model, pid)
        File.binwrite(temp, full)
        replace_file(temp, path(model, pid))
      end

      # Đổi file tạm do SketchUp chụp (write_image) thành ảnh chính. Không phải PNG hoặc chưa có file thì giữ ảnh cũ.
      def self.commit(model, pid)
        temp = temp_path(model, pid)
        raise ArgumentError, 'SketchUp không tạo được ảnh. Kiểm tra thư mục lưu ảnh trong bảng Preset.' unless File.file?(temp)
        begin
          check_png!(File.binread(temp))
        rescue ArgumentError
          File.delete(temp)
          raise
        end
        replace_file(temp, path(model, pid))
      end

      def self.delete(model, pid)
        FileUtils.rm_f(path(model, pid))
        FileUtils.rm_f(File.join(dir(model), "#{id!(pid)}#{LEGACY_THUMB}"))
      end

      # Đường dẫn file để giao diện hiện ảnh trực tiếp (<img src>), không phải chuyển cả ảnh qua Ruby. stamp (giờ sửa file) đi kèm
      # sau dấu ? để ảnh được tải lại khi đổi.
      # folder: thư mục ảnh của model (bảng lớn truyền sẵn để không tính lại cho từng dòng).
      def self.file_url(model, pid, stamp, folder = dir(model))
        encoded = File.join(folder, "#{id!(pid)}#{KINDS.fetch(:full)}").tr('\\', '/').b.gsub(%r{[^A-Za-z0-9/:._~-]}n) { |c| format('%%%02X', c.ord) }
        "file:///#{encoded.sub(%r{\A/+}, '')}?v=#{Integer(stamp)}"
      end

      # Dự phòng khi trình duyệt của cửa sổ không nạp được ảnh bằng đường dẫn file.
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
