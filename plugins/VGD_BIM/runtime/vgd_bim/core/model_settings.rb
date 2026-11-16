require 'json'
require_relative 'settings'

module VGD
  module BIM
    # Cài đặt RIÊNG của từng file SketchUp, lưu trong chính file (dictionary VGD_BIM_MODEL, khóa `settings`, JSON): thư mục ảnh, từ khóa / tag
    # loại trừ số đo và trạng thái bảng (cột, thứ tự, độ cao hàng, preset...). File nào dùng cài đặt của file đó, mở file khác không bị lẫn.
    # Cài đặt chung trên máy (Settings, table_view.json) chỉ còn làm MẪU cho file chưa có cài đặt riêng và được ghi lại theo lần dùng gần nhất.
    module ModelSettings
      DICTIONARY = 'VGD_BIM_MODEL'.freeze
      KEY = 'settings'.freeze
      MODEL_KEYS = %w[image_dir exclude_words exclude_tags].freeze
      VIEW_KEY = 'table_view'.freeze
      # Gợi ý nhập kiểu Excel: các giá trị đã nhập vào ô chữ của bảng (Tên, Mô tả, Hãng, Cỡ, cột chữ thêm tay), mới nhất ở đầu, lưu theo file.
      SUGGEST_KEY = 'suggest'.freeze
      SUGGEST_FIELD = /\A(?:name|description|owner|size|custom_[A-Za-z0-9_]{1,60})\z/
      SUGGEST_PER_FIELD = 150
      SUGGEST_MAX_LENGTH = 120
      SUGGEST_MAX_FIELDS = 30

      # Cài đặt riêng đã lưu trong model (mục sai bị bỏ, thư mục ảnh rỗng coi như chưa đặt). Model không hỗ trợ thì {}.
      def self.read(model)
        return {} unless model.respond_to?(:get_attribute)
        raw = model.get_attribute(DICTIONARY, KEY).to_s
        return {} if raw.empty?
        data = JSON.parse(raw)
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
        result.delete('image_dir') if result['image_dir'].to_s.empty?
        result[VIEW_KEY] = data[VIEW_KEY] if data[VIEW_KEY].is_a?(Hash)
        result[SUGGEST_KEY] = clean_suggest(data[SUGGEST_KEY]) if data.key?(SUGGEST_KEY)
        result
      rescue JSON::ParserError
        {}
      end

      # Gộp patch vào cài đặt riêng của model (một thao tác trong suốt, gộp vào bước hoàn tác trước). Mục sai thì cả lần ghi bị từ chối.
      # Không đổi gì thì không đụng model. Trả về true nếu model hỗ trợ.
      def self.write(model, patch)
        return false unless model.respond_to?(:set_attribute) && model.respond_to?(:start_operation)
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
        merged.delete('image_dir') if merged['image_dir'].to_s.empty?
        return true if merged == current
        model.start_operation('VGD_BIM · Cài đặt của file', true, false, true)
        begin
          model.set_attribute(DICTIONARY, KEY, JSON.generate(merged))
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end
        true
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

      # Nhớ một giá trị vừa nhập (đưa lên đầu danh sách của cột). Trả về true nếu có ghi; ô rỗng, cột lạ hoặc model không hỗ trợ thì không làm gì.
      def self.remember(model, field, value)
        text = value.to_s.strip
        return false if text.empty? || text.length > SUGGEST_MAX_LENGTH || !field.to_s.match?(SUGGEST_FIELD)
        current = read(model)[SUGGEST_KEY] || {}
        list = [text] + (current[field] || []).reject { |item| item.downcase == text.downcase }
        write(model, SUGGEST_KEY => current.merge(field => list))
      end

      # Cài đặt đang dùng cho model: cài đặt chung, mục nào file có riêng thì lấy của file.
      def self.effective(model)
        Settings.read.merge(read(model).select { |key, _| MODEL_KEYS.include?(key) })
      end

      # Thư mục ảnh của model: của file nếu có, không thì thư mục chung / mặc định.
      def self.image_dir(model)
        own = read(model)['image_dir']
        own.to_s.empty? ? Settings.image_dir : own
      end

      # Ghi cho file những mục chưa có riêng (lấy theo cài đặt chung đang có): để mở file khác, đổi cài đặt chung, rồi quay lại thì file này không bị đổi theo.
      # view: trạng thái bảng chung hiện tại (Hash). Gọi khi mở bảng; file đã có đủ thì không đụng gì.
      def self.pin(model, view)
        stored = read(model)
        global = Settings.read
        patch = {}
        patch['image_dir'] = Settings.image_dir unless stored.key?('image_dir')
        patch['exclude_words'] = global['exclude_words'] unless stored.key?('exclude_words')
        patch['exclude_tags'] = global['exclude_tags'] unless stored.key?('exclude_tags')
        patch[VIEW_KEY] = view.is_a?(Hash) ? view : {} unless stored.key?(VIEW_KEY)
        write(model, patch) unless patch.empty?
      end
    end
  end
end
