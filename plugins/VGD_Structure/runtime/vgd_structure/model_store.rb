require 'json'

module VGD
  module Structure
    # Đọc / ghi dữ liệu nguồn của plugin trong model (dictionary VGD_STRUCT, khóa state, JSON). Dữ liệu đọc từ model luôn được kiểm tra lại.
    module ModelStore
      KEY = 'state'.freeze
      MAX_BYTES = 1_000_000

      # {'grid' => lưới đã chuẩn hóa, 'symbol' => thiết lập ký hiệu}. Chưa có hoặc hỏng thì trả mặc định (và không ghi gì vào model).
      def self.read(model)
        raw = model.get_attribute(Schema::DICTIONARY, KEY)
        parsed = raw.is_a?(String) && raw.bytesize <= MAX_BYTES ? JSON.parse(raw) : nil
        grid = Grid.normalize!(parsed['grid'])
        symbol = AxisSymbol.options!(parsed['symbol'])
        {'grid' => grid, 'symbol' => symbol, 'saved' => true}
      rescue JSON::ParserError, ArgumentError, NoMethodError, TypeError
        {'grid' => Grid.default, 'symbol' => AxisSymbol.options!(nil), 'saved' => false}
      end

      # Ghi dữ liệu đã kiểm tra. Gọi trong một thao tác hoàn tác (start_operation) của người gọi.
      def self.write(model, grid, symbol)
        json = JSON.generate('schema_version' => 1, 'grid' => Grid.normalize!(grid), 'symbol' => AxisSymbol.options!(symbol))
        raise ArgumentError, 'Dữ liệu quá lớn.' if json.bytesize > MAX_BYTES
        model.set_attribute(Schema::DICTIONARY, KEY, json)
      end
    end
  end
end
