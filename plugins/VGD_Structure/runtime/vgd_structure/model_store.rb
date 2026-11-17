require 'json'

module VGD
  module Structure
    # Đọc / ghi dữ liệu nguồn của plugin trong model (dictionary VGD_STRUCT, khóa state, JSON). Dữ liệu đọc từ model luôn được kiểm tra lại.
    module ModelStore
      KEY = 'state'.freeze
      MAX_BYTES = 1_000_000

      # Trạng thái đầy đủ (lưới, ký hiệu, loại cột, tầng) kèm 'saved'. Chưa có hoặc hỏng thì trả mặc định (và không ghi gì vào model).
      def self.read(model)
        raw = model.get_attribute(Schema::DICTIONARY, KEY)
        parsed = raw.is_a?(String) && raw.bytesize <= MAX_BYTES ? JSON.parse(raw) : nil
        State.normalize!(parsed).merge('saved' => true)
      rescue JSON::ParserError, ArgumentError, NoMethodError, TypeError
        State.default.merge('removed' => 0, 'saved' => false)
      end

      # Ghi trạng thái (kiểm tra lại toàn bộ). Gọi trong một thao tác hoàn tác (start_operation) của người gọi. Trả về trạng thái sạch đã ghi.
      def self.write(model, state)
        clean = State.normalize!(state)
        json = JSON.generate('schema_version' => 1, 'grid' => clean['grid'], 'symbol' => clean['symbol'], 'types' => clean['types'], 'levels' => clean['levels'])
        raise ArgumentError, 'Dữ liệu quá lớn.' if json.bytesize > MAX_BYTES
        model.set_attribute(Schema::DICTIONARY, KEY, json)
        clean
      end

      # Thay lưới và thiết lập ký hiệu, giữ loại cột và tầng đã lưu trong model (lựa chọn cột ở giao điểm không còn thì bị bỏ).
      def self.write_grid(model, grid, symbol)
        write(model, read(model).merge('grid' => grid, 'symbol' => symbol))
      end
    end
  end
end
