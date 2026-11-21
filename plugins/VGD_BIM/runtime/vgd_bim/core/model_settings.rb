require 'json'
require 'fileutils'
require_relative 'settings'
require_relative 'storage'

module VGD
  module BIM
    # Cài đặt RIÊNG của từng file SketchUp, lưu ở file settings.json trong thư mục cạnh file SketchUp:
    #   D:\DuAn\Nha\bep.skp  ->  D:\DuAn\Nha\bep_VGD_BIM\settings.json  (cùng thư mục chứa ảnh <mã model>\<mã đối tượng>.png)
    # Gồm: từ khóa / tag loại trừ số đo, trạng thái bảng (cột, thứ tự, các sheet...), gợi ý nhập. Gửi file SketchUp kèm thư mục này thì
    # người nhận có đủ cột, tag loại trừ và ảnh. KHÔNG còn lưu trong file SketchUp và KHÔNG lấy từ cài đặt chung của máy: file mới (chưa có
    # settings.json) luôn bắt đầu từ mặc định. File SketchUp chưa lưu thì chưa có thư mục: cài đặt giữ trong phiên làm việc và được ghi ra
    # settings.json ngay khi file được lưu và cài đặt được dùng lại. Ngôn ngữ, tag ghim / gần đây vẫn là cài đặt chung của máy (Settings).
    module ModelSettings
      FOLDER_SUFFIX = '_VGD_BIM'.freeze
      FILE_NAME = 'settings.json'.freeze
      SCHEMA = 1
      MODEL_KEYS = %w[exclude_words exclude_tags].freeze
      VIEW_KEY = 'table_view'.freeze
      # Giá trị mặc định của file mới (không lấy từ cài đặt chung của máy).
      FILE_DEFAULTS = {'exclude_words' => Settings::DEFAULTS['exclude_words'], 'exclude_tags' => []}.freeze
      # Gợi ý nhập kiểu Excel: các giá trị đã nhập vào ô chữ của bảng (Tên, Mô tả, Hãng, Cỡ, cột chữ thêm tay), mới nhất ở đầu, lưu theo file.
      SUGGEST_KEY = 'suggest'.freeze
      SUGGEST_FIELD = /\A(?:name|description|owner|size|custom_[A-Za-z0-9_]{1,60})\z/
      SUGGEST_PER_FIELD = 150
      SUGGEST_MAX_LENGTH = 120
      SUGGEST_MAX_FIELDS = 30
      NOT_SAVED = 'Chưa lưu file SketchUp. Hãy lưu file (Ctrl+S) rồi thử lại: ảnh và cài đặt được lưu trong thư mục cạnh file SketchUp.'.freeze

      @session = {}.compare_by_identity # file chưa lưu: cài đặt giữ tạm trong phiên (theo model; Ruby 2.7 của SketchUp 2022 chưa có WeakMap#delete)

      # Thư mục cạnh file SketchUp (chứa settings.json và ảnh), hoặc nil nếu file chưa lưu / model không có đường dẫn.
      def self.folder(model)
        return nil unless model.respond_to?(:path)
        path = model.path.to_s
        return nil if path.empty?
        File.join(File.dirname(path), "#{File.basename(path, '.*')}#{FOLDER_SUFFIX}")
      end

      def self.file(model)
        dir = folder(model)
        dir && File.join(dir, FILE_NAME)
      end

      def self.saved?(model)
        !folder(model).nil?
      end

      # Cài đặt riêng đã lưu của file (mục sai bị bỏ). Chưa có thì {}. Model không hỗ trợ (nil) thì {}.
      def self.read(model)
        return {} unless model.respond_to?(:path)
        path = file(model)
        return clean_data(@session[model]) unless path
        flush_session(model, path)
        clean_data(load_json(path))
      end

      # Gộp patch vào cài đặt riêng của file và ghi ra settings.json (hoặc giữ trong phiên nếu file chưa lưu). Mục sai thì cả lần ghi bị từ chối.
      # Không đổi gì thì không ghi. Trả về true nếu model hỗ trợ.
      def self.write(model, patch)
        return false unless model.respond_to?(:path)
        raise ArgumentError, 'Cài đặt không hợp lệ.' unless patch.is_a?(Hash)
        changes = {}
        patch.each do |key, value|
          if MODEL_KEYS.include?(key) then changes[key] = Settings.clean(key, value)
          elsif key == SUGGEST_KEY then changes[key] = clean_suggest(value)
          elsif key == VIEW_KEY
            raise ArgumentError, 'Trạng thái bảng không hợp lệ.' unless value.is_a?(Hash)
            changes[key] = value
          end
        end
        current = read(model)
        merged = current.merge(changes)
        return true if merged == current
        path = file(model)
        if path
          save_json(path, merged)
        else
          @session[model] = merged
        end
        true
      end

      # Cài đặt đang dùng cho file: cài đặt chung của máy (ngôn ngữ, tag ghim...) cộng mặc định của file, rồi cài đặt riêng đã lưu của file.
      # Không có thư mục ảnh ở đây: thư mục luôn là ModelSettings.folder.
      def self.effective(model)
        Settings.read.reject { |key, _| key == 'image_dir' }.merge(FILE_DEFAULTS).merge(read(model).select { |key, _| MODEL_KEYS.include?(key) })
      end

      # Thư mục ảnh của file: thư mục cạnh file SketchUp (nil nếu file chưa lưu).
      def self.image_dir(model)
        folder(model)
      end

      # Ghi nhớ một giá trị vừa nhập (đưa lên đầu danh sách của cột). Trả về true nếu có ghi; ô rỗng, cột lạ hoặc model không hỗ trợ thì không làm gì.
      def self.remember(model, field, value)
        text = value.to_s.strip
        return false if text.empty? || text.length > SUGGEST_MAX_LENGTH || !field.to_s.match?(SUGGEST_FIELD)
        current = read(model)[SUGGEST_KEY] || {}
        list = [text] + (current[field] || []).reject { |item| item.downcase == text.downcase }
        write(model, SUGGEST_KEY => current.merge(field => list))
      end

      # Danh sách gợi ý sạch: chỉ cột chữ hợp lệ, giá trị không rỗng, không quá dài, không trùng (không phân biệt hoa thường), có giới hạn số lượng.
      def self.clean_suggest(value)
        return {} unless value.is_a?(Hash)
        value.each_with_object({}) do |(field, list), out|
          next unless field.is_a?(String) && field.match?(SUGGEST_FIELD) && list.is_a?(Array)
          break out if out.size >= SUGGEST_MAX_FIELDS
          seen = {}
          items = list.filter_map do |item|
            text = item.is_a?(String) ? item.strip : ''
            next if text.empty? || text.length > SUGGEST_MAX_LENGTH || seen[text.downcase]
            seen[text.downcase] = true
            text
          end
          out[field] = items.first(SUGGEST_PER_FIELD) unless items.empty?
        end
      end

      # Chỉ giữ các mục hợp lệ của dữ liệu đọc từ settings.json (hoặc từ phiên).
      def self.clean_data(data)
        return {} unless data.is_a?(Hash)
        result = {}
        MODEL_KEYS.each do |key|
          next unless data.key?(key)
          begin
            result[key] = Settings.clean(key, data[key])
          rescue ArgumentError
            next
          end
        end
        result[VIEW_KEY] = data[VIEW_KEY] if data[VIEW_KEY].is_a?(Hash)
        result[SUGGEST_KEY] = clean_suggest(data[SUGGEST_KEY]) if data.key?(SUGGEST_KEY)
        result
      end

      def self.load_json(path)
        return {} unless File.file?(path)
        data = JSON.parse(File.read(path, encoding: 'UTF-8'))
        data.is_a?(Hash) ? data : {}
      rescue JSON::ParserError, SystemCallError
        {}
      end

      # Ghi qua file tạm rồi đổi tên: mất điện hoặc đầy ổ đĩa giữa chừng không làm hỏng settings.json cũ.
      def self.save_json(path, data)
        FileUtils.mkdir_p(File.dirname(path))
        temp = "#{path}.tmp"
        File.write(temp, JSON.pretty_generate({'schema' => SCHEMA}.merge(data)), encoding: 'UTF-8')
        Storage.replace_file(temp, path)
      rescue SystemCallError => error
        FileUtils.rm_f(temp) if temp
        raise ArgumentError, "Không ghi được #{FILE_NAME}: #{error.message}"
      end

      # File vừa được lưu lần đầu: ghi cài đặt giữ tạm trong phiên ra settings.json (nếu thư mục chưa có settings.json riêng).
      def self.flush_session(model, path)
        pending = @session[model]
        return unless pending
        save_json(path, clean_data(pending)) unless File.file?(path)
        @session.delete(model)
      rescue ArgumentError => error
        BIM.log(error.message)
      end
    end
  end
end
