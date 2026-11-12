require 'json'
require 'securerandom'

module VGD
  module BIM
    # Luật kiểm tra tự đặt cho Bảng khối lượng: "cột + phép so sánh + giá trị + mức độ + lời nhắn". Lưu trong file SketchUp
    # (dictionary VGD_BIM_MODEL, khóa `check_rules`, JSON) nên đi theo model. Chỉ ĐỌC các dòng của bảng, không bao giờ đổi model.
    # Số đo trong bảng là đơn vị gốc (mm). Xem docs/vgd_bim/ROADMAP.md cột mốc 4c.
    module CheckRules
      DICTIONARY = 'VGD_BIM_MODEL'.freeze
      KEY = 'check_rules'.freeze
      MAX_RULES = 50
      MAX_NAME = 60
      MAX_VALUE = 80
      MAX_MESSAGE = 120
      MAX_RESULTS = 2000
      OPS = %w[lt lte gt gte eq neq empty not_empty contains].freeze
      NUMERIC_OPS = %w[lt lte gt gte].freeze
      NO_VALUE_OPS = %w[empty not_empty].freeze
      SEVERITIES = %w[INFO WARNING ERROR].freeze
      ID_PATTERN = /\Ack_[0-9a-f]{8}\z/
      COLUMN_PATTERN = /\A[A-Za-z0-9_]{1,40}\z/
      CONTROL = /[\u0000-\u001f\u007f]/

      def self.text(value, limit, label)
        string = value.is_a?(String) ? value.strip : ''
        raise ArgumentError, "#{label} tối đa #{limit} ký tự và không có ký tự điều khiển." if string.length > limit || string.match?(CONTROL)
        string
      end

      def self.number(value)
        Float(value.to_s.strip.tr(',', '.'))
      rescue ArgumentError, TypeError
        nil
      end

      # Kiểm tra danh sách luật từ giao diện hoặc file; trả về danh sách sạch (mỗi luật có id). column_keys: cột hợp lệ của bảng (nil = không kiểm).
      def self.sanitize!(list, column_keys = nil)
        raise ArgumentError, 'Danh sách luật không hợp lệ.' unless list.is_a?(Array)
        raise ArgumentError, "Chỉ có tối đa #{MAX_RULES} luật." if list.size > MAX_RULES
        list.map do |item|
          raise ArgumentError, 'Danh sách luật không hợp lệ.' unless item.is_a?(Hash)
          name = text(item['name'], MAX_NAME, 'Tên luật')
          raise ArgumentError, 'Hãy nhập tên luật.' if name.empty?
          column = item['column']
          raise ArgumentError, "Luật #{name}: cột không hợp lệ." unless column.is_a?(String) && column.match?(COLUMN_PATTERN)
          raise ArgumentError, "Luật #{name}: cột #{column} không có trong bảng." if column_keys && !column_keys.include?(column)
          op = item['op']
          raise ArgumentError, "Luật #{name}: phép so sánh không hợp lệ." unless OPS.include?(op)
          severity = item['severity']
          raise ArgumentError, "Luật #{name}: mức độ phải là INFO, WARNING hoặc ERROR." unless SEVERITIES.include?(severity)
          value = NO_VALUE_OPS.include?(op) ? '' : text(item['value'].is_a?(Numeric) ? item['value'].to_s : item['value'], MAX_VALUE, "Luật #{name}: giá trị")
          raise ArgumentError, "Luật #{name}: hãy nhập giá trị so sánh." if value.empty? && !NO_VALUE_OPS.include?(op)
          raise ArgumentError, "Luật #{name}: phép so sánh này cần giá trị là số." if NUMERIC_OPS.include?(op) && number(value).nil?
          id = item['id']
          raise ArgumentError, 'Mã luật không hợp lệ.' unless id.nil? || (id.is_a?(String) && id.match?(ID_PATTERN))
          {'id' => id || "ck_#{SecureRandom.hex(4)}", 'name' => name, 'column' => column, 'op' => op, 'value' => value, 'severity' => severity,
           'message' => text(item['message'], MAX_MESSAGE, "Luật #{name}: lời nhắn")}
        end
      end

      # Luật đã lưu trong model; dữ liệu hỏng thì coi như chưa có (không đoán).
      def self.read(model)
        return [] unless model.respond_to?(:get_attribute)
        raw = model.get_attribute(DICTIONARY, KEY).to_s
        return [] if raw.empty?
        sanitize!(JSON.parse(raw))
      rescue JSON::ParserError, ArgumentError
        []
      end

      # Ghi luật trong thao tác trong suốt (gộp vào bước hoàn tác trước). Không đổi gì thì không đụng model.
      def self.write(model, list)
        return false unless model.respond_to?(:set_attribute) && model.respond_to?(:start_operation)
        clean = sanitize!(list)
        return true if clean == read(model)
        model.start_operation('VGD_BIM · Luật kiểm tra', true, false, true)
        begin
          model.set_attribute(DICTIONARY, KEY, JSON.generate(clean))
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end
        true
      end

      # Dòng này có vi phạm luật không. Giá trị không so sánh được (cột chữ với phép số, ô trống với phép số) thì KHÔNG vi phạm:
      # muốn bắt ô trống thì dùng phép "trống".
      def self.violated?(rule, value)
        op = rule['op']
        blank = value.nil? || value.to_s.strip.empty?
        return blank if op == 'empty'
        return !blank if op == 'not_empty'
        return false if blank
        expected = rule['value']
        if NUMERIC_OPS.include?(op)
          actual = value.is_a?(Numeric) ? value.to_f : number(value)
          limit = number(expected)
          return false if actual.nil? || limit.nil?
          return {'lt' => actual < limit, 'lte' => actual <= limit, 'gt' => actual > limit, 'gte' => actual >= limit}[op]
        end
        left = value.to_s.strip.downcase
        right = expected.downcase
        case op
        when 'eq' then left == right || (value.is_a?(Numeric) && number(expected) && value.to_f == number(expected))
        when 'neq' then !(left == right || (value.is_a?(Numeric) && number(expected) && value.to_f == number(expected)))
        when 'contains' then left.include?(right)
        end
      end

      # rows: các dòng của bảng (Hash, khóa Symbol, có :index). Trả về {results: [...], truncated:}. Cột không còn trong bảng (cột thêm tay đã xóa) thì bỏ luật đó.
      def self.evaluate(rules, rows)
        results = []
        truncated = false
        rules.each do |rule|
          key = rule['column'].to_sym
          rows.each do |row|
            next unless row.key?(key) && violated?(rule, row[key])
            if results.size >= MAX_RESULTS
              truncated = true
              break
            end
            message = rule['message'].to_s.empty? ? rule['name'] : rule['message']
            results << {rule: rule['id'], name: rule['name'], severity: rule['severity'], message: message, index: row[:index]}
          end
        end
        {results: results, truncated: truncated}
      end
    end
  end
end
