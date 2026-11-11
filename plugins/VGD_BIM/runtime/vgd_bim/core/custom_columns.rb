require_relative 'storage'

module VGD
  module BIM
    # Cột thêm tay của Bảng khối lượng (nút + ở ngăn Chọn cột, theo cách AutoInfo). Ba kiểu:
    #   attribute: đọc thuộc tính tùy chọn (dictionary + tên thuộc tính) của món, thiếu thì đọc ở định nghĩa; chỉ đọc.
    #   dynamic:   đọc thuộc tính của Dynamic Components (dictionary dynamic_attributes, tên viết thường); chỉ đọc.
    #   text:      cột tự nhập, giá trị lưu trong dictionary riêng của bảng (VGD_BIM_TABLE) của từng món; sửa được trong bảng.
    # Danh sách cột lưu trên máy (custom_columns.json), khóa dạng custom_N, số N không bao giờ dùng lại.
    # Không bao giờ ghi vào dictionary của plugin khác; xóa cột chỉ bỏ cột khỏi bảng, không xóa dữ liệu đã nhập trong món.
    module CustomColumns
      FILE = 'custom_columns'.freeze
      KINDS = %w[attribute dynamic text].freeze
      MAX_COLUMNS = 20
      MAX_LABEL = 60
      MAX_NAME = 80
      MAX_VALUE = 200
      DYNAMIC_DICTIONARY = 'dynamic_attributes'.freeze
      TEXT_DICTIONARY = 'VGD_BIM_TABLE'.freeze
      KEY_PATTERN = /\Acustom_\d{1,4}\z/
      CONTROL = /[\u0000-\u001f\u007f]/

      # Kiểm tra một cột do giao diện gửi lên; trả về bảng băm sạch (chưa có khóa).
      def self.sanitize!(item)
        raise ArgumentError, 'Dữ liệu cột không hợp lệ.' unless item.is_a?(Hash)
        kind = item['kind']
        raise ArgumentError, 'Hãy chọn kiểu cột hợp lệ.' unless KINDS.include?(kind)
        clean = {'label' => label!(item['label']), 'kind' => kind}
        return clean if kind == 'text'
        if kind == 'dynamic'
          clean['dictionary'] = DYNAMIC_DICTIONARY
          clean['attribute'] = name!(item['attribute'], 'Tên thuộc tính', 'thuộc tính').downcase
        else
          clean['dictionary'] = name!(item['dictionary'], 'Tên dictionary', 'dictionary')
          clean['attribute'] = name!(item['attribute'], 'Tên thuộc tính', 'thuộc tính')
        end
        clean
      end

      def self.label!(value)
        text = value.is_a?(String) ? value.strip : ''
        raise ArgumentError, "Hãy nhập tên cột (tối đa #{MAX_LABEL} ký tự, không có ký tự điều khiển)." if text.empty? || text.length > MAX_LABEL || text.match?(CONTROL)
        text
      end

      def self.name!(value, title, word)
        text = value.is_a?(String) ? value.strip : ''
        raise ArgumentError, "#{title} phải có từ 1 đến #{MAX_NAME} ký tự và không có ký tự điều khiển (#{word})." if text.empty? || text.length > MAX_NAME || text.match?(CONTROL)
        text
      end

      # Danh sách cột đã lưu; mục hỏng hoặc trùng khóa bị bỏ, file hỏng coi như chưa có cột nào.
      def self.read
        stored.first
      end

      def self.stored
        raw = Storage.read(FILE)
        return [[], 1] unless raw.is_a?(Hash) && raw['columns'].is_a?(Array)
        seen = {}
        list = raw['columns'].filter_map do |item|
          next unless item.is_a?(Hash) && item['key'].to_s.match?(KEY_PATTERN) && !seen[item['key']]
          clean = sanitize!(item).merge('key' => item['key']) rescue next
          seen[item['key']] = true
          clean
        end.first(MAX_COLUMNS)
        used = list.map { |c| c['key'][/\d+/].to_i }.max.to_i
        [list, [raw['next'].to_i, used + 1].max]
      end

      def self.keys
        read.map { |c| c['key'] }
      end

      def self.find(key)
        read.find { |c| c['key'] == key }
      end

      def self.add(item)
        clean = sanitize!(item)
        list, next_id = stored
        raise ArgumentError, "Chỉ thêm tay được tối đa #{MAX_COLUMNS} cột. Hãy xóa bớt cột không dùng." if list.size >= MAX_COLUMNS
        column = clean.merge('key' => "custom_#{next_id}")
        save(list + [column], next_id + 1)
        column
      end

      def self.remove(key)
        raise ArgumentError, 'Khóa cột không hợp lệ.' unless key.is_a?(String) && key.match?(KEY_PATTERN)
        list, next_id = stored
        save(list.reject { |c| c['key'] == key }, next_id)
      end

      def self.save(list, next_id)
        Storage.write(FILE, {'next' => next_id, 'columns' => list})
      end

      # Cột để giao diện thêm vào bảng (sau các cột chuẩn). Chỉ cột tự nhập có editable (sửa trong bảng).
      def self.columns
        read.map do |c|
          column = {key: c['key'], label: c['label'], kind: 'text', custom: true, source: c['kind']}
          column[:editable] = c['key'] if c['kind'] == 'text'
          column
        end
      end

      # Giá trị chữ của từng cột cho một đối tượng: {khóa => chữ}. Không có thì để trống.
      def self.values(entity, defs)
        defs.each_with_object({}) { |c, out| out[c['key']] = read_value(entity, c) }
      end

      def self.read_value(entity, column)
        dictionary, attribute = column['kind'] == 'text' ? [TEXT_DICTIONARY, column['key']] : [column['dictionary'], column['attribute']]
        value = fetch(entity, dictionary, attribute)
        value = fetch(entity.definition, dictionary, attribute) if value.nil? && column['kind'] != 'text' && entity.respond_to?(:definition)
        format_value(value)
      rescue StandardError
        ''
      end

      def self.fetch(owner, dictionary, attribute)
        owner.respond_to?(:get_attribute) ? owner.get_attribute(dictionary, attribute) : nil
      end

      def self.format_value(value)
        text = case value
               when nil then ''
               when true then 'Có'
               when false then 'Không'
               when Integer then value.to_s
               when Numeric then format('%.4f', value.to_f).sub(/\.?0+\z/, '')
               else value.to_s
               end
        text.gsub(CONTROL, ' ')[0, MAX_VALUE]
      end

      # Ghi giá trị của cột tự nhập vào món (rỗng nghĩa là xóa). Cột thuộc tính tùy chọn / động chỉ đọc, không bao giờ ghi.
      def self.write(entity, key, value)
        column = find(key)
        raise ArgumentError, 'Cột này không sửa được trong bảng.' unless column && column['kind'] == 'text'
        raise ArgumentError, 'Đối tượng đang bị khóa.' if entity.locked?
        text = value.to_s.gsub(CONTROL, '').strip
        raise ArgumentError, "Giá trị tối đa #{MAX_VALUE} ký tự." if text.length > MAX_VALUE
        text.empty? ? entity.delete_attribute(TEXT_DICTIONARY, key) : entity.set_attribute(TEXT_DICTIONARY, key, text)
      end
    end
  end
end
