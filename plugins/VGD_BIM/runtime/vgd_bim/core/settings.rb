require_relative 'storage'

module VGD
  module BIM
    # Cài đặt chung của người dùng (mọi preset dùng chung), lưu trên máy ở settings.json: ngôn ngữ giao diện và thư mục lưu ảnh.
    # Đơn vị, số lẻ, cỡ ảnh, góc nhìn... nằm trong preset (xem Preset). Mọi giá trị đều được kiểm tra khi ghi (update) và khi đọc
    # (read): file sửa tay sai thì từng mục sai về mặc định.
    module Settings
      DEFAULTS = {
        'language' => 'vi', # vi | en
        'image_dir' => ''   # trống = thư mục mặc định trong thư mục dữ liệu của plugin
      }.freeze
      LANGUAGES = %w[vi en].freeze
      MAX_DIR_LENGTH = 240 # dưới giới hạn đường dẫn 260 ký tự của Windows, chừa chỗ cho tên file

      def self.read
        raw = Storage.read('settings')
        raw = {} unless raw.is_a?(Hash)
        DEFAULTS.each_with_object({}) do |(key, default), result|
          result[key] = raw.key?(key) && (clean(key, raw[key]) rescue nil) ? clean(key, raw[key]) : default
        end
      end

      # Ghi các mục có trong patch (mục lạ bị bỏ qua). Một mục sai thì cả lần ghi bị từ chối.
      def self.update(patch)
        raise ArgumentError, 'Cài đặt không hợp lệ.' unless patch.is_a?(Hash)
        current = read
        changes = patch.select { |key, _| DEFAULTS.key?(key) }.each_with_object({}) { |(key, value), result| result[key] = clean(key, value) }
        merged = current.merge(changes)
        Storage.write('settings', merged)
        merged
      end

      # Thư mục lưu ảnh đang dùng (mặc định hoặc do người dùng chọn).
      def self.image_dir
        custom = read['image_dir']
        custom.empty? ? File.join(Storage.dir, 'images') : custom
      end

      def self.clean(key, value)
        case key
        when 'language'
          raise ArgumentError, 'Ngôn ngữ không hợp lệ.' unless LANGUAGES.include?(value.to_s)
          value.to_s
        when 'image_dir' then directory(value)
        end
      end

      def self.directory(value)
        text = value.to_s.strip
        return '' if text.empty?
        raise ArgumentError, 'Đường dẫn thư mục ảnh không hợp lệ.' if text.length > MAX_DIR_LENGTH || text.match?(/[\u0000-\u001f]/)
        raise ArgumentError, 'Thư mục ảnh phải là đường dẫn đầy đủ (ví dụ C:\\Anh\\NoiThat).' unless windows_absolute?(text) || File.absolute_path?(text)
        text
      end

      def self.windows_absolute?(text)
        text.match?(/\A[A-Za-z]:[\\\/]/) || text.start_with?('\\\\')
      end
    end
  end
end
