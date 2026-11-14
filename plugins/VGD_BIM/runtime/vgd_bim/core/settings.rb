require_relative 'storage'
require_relative 'measure'

module VGD
  module BIM
    # Cài đặt chung của người dùng (mọi preset dùng chung), lưu trên máy ở settings.json: ngôn ngữ giao diện, thư mục lưu ảnh và từ khóa loại trừ khỏi số đo (tay nắm).
    # Đơn vị, số lẻ, cỡ ảnh, góc nhìn... nằm trong preset (xem Preset). Mọi giá trị đều được kiểm tra khi ghi (update) và khi đọc
    # (read): file sửa tay sai thì từng mục sai về mặc định.
    module Settings
      DEFAULTS = {
        'language' => 'vi', # vi | en
        'image_dir' => '',  # trống = thư mục mặc định trong thư mục dữ liệu của plugin
        # Số đo thân của Bảng khối lượng (xem Measure): từ khóa tên / tag của phần không tính vào Rộng / Dài / Cao (như tay nắm).
        'exclude_words' => 'tay nắm, tay nam, handle, knob',
        'exclude_tags' => [], # tên các tag loại khỏi số đo (chọn bằng bảng tick trong Bảng khối lượng)
        # Tab Soạn tag > Trong model: tag ghim (người dùng tự ghim) và tag vừa gán gần đây (tự cập nhật khi gán, mới nhất đứng đầu)
        'pinned_tags' => [],
        'recent_tags' => []
      }.freeze
      RECENT_LIMIT = 8
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

      # Ghi nhớ tag vừa gán: đưa lên đầu danh sách gần đây (không trùng, không phân biệt hoa thường / dấu), tối đa RECENT_LIMIT tag.
      def self.touch_recent(name)
        name = name.to_s.strip
        return if name.empty?
        key = Measure.normalize(name)
        current = read['recent_tags']
        updated = ([name] + current.reject { |item| Measure.normalize(item) == key }).first(RECENT_LIMIT)
        update('recent_tags' => updated) unless updated == current
      rescue StandardError => error
        BIM.log("Không ghi được tag gần đây: #{error.message}") # chỉ là tiện ích, không làm hỏng việc gán tag
      end

      # Ghim / bỏ ghim một tag (theo tên, không phân biệt hoa thường / dấu).
      def self.set_pinned(name, pinned)
        name = name.to_s.strip
        raise ArgumentError, 'Hãy chọn một tag.' if name.empty?
        key = Measure.normalize(name)
        list = read['pinned_tags'].reject { |item| Measure.normalize(item) == key }
        list << name if pinned
        update('pinned_tags' => list)['pinned_tags']
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
        when 'exclude_tags', 'pinned_tags' then Measure.parse_tags(value)
        when 'recent_tags' then Measure.parse_tags(value).first(RECENT_LIMIT)
        when 'exclude_words'
          Measure.parse_words(value) # chỉ để kiểm tra; lưu nguyên chữ người dùng gõ
          value.to_s.strip
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
