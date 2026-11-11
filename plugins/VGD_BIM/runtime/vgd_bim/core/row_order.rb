module VGD
  module BIM
    # Thứ tự dòng do người dùng tự kéo trong Bảng khối lượng. Lưu trong chính file SketchUp (dictionary VGD_BIM_MODEL, khóa row_order)
    # dưới dạng danh sách mã bền (persistent_id) của các món, nên mở lại file nào cũng đúng thứ tự của file đó.
    # Món chưa có trong danh sách (món mới) không bị đụng tới: giao diện xếp chúng xuống cuối bảng.
    module RowOrder
      DICTIONARY = 'VGD_BIM_MODEL'.freeze
      KEY = 'row_order'.freeze
      MAX_ENTRIES = 20_000 # đủ cho model rất lớn; giới hạn để dữ liệu từ giao diện không phình file SketchUp

      # Danh sách mã hợp lệ (số nguyên dương, không trùng). Sai kiểu hoặc quá lớn là lỗi (dữ liệu từ giao diện).
      def self.sanitize!(list)
        raise ArgumentError, 'Thứ tự dòng không hợp lệ.' unless list.is_a?(Array)
        raise ArgumentError, "Thứ tự dòng quá dài (tối đa #{MAX_ENTRIES} món)." if list.size > MAX_ENTRIES
        list.each { |pid| raise ArgumentError, 'Thứ tự dòng có mã món không hợp lệ.' unless pid.is_a?(Integer) && pid.positive? }
        list.uniq
      end

      # Đọc thứ tự đã lưu; dữ liệu hỏng hoặc không có thì coi như chưa sắp (không báo lỗi, không đoán).
      def self.read(model)
        return [] unless model.respond_to?(:get_attribute)
        raw = model.get_attribute(DICTIONARY, KEY).to_s
        return [] if raw.empty?
        sanitize!(JSON.parse(raw))
      rescue JSON::ParserError, ArgumentError
        []
      end

      # incoming: thứ tự mới của các món đang có trong bảng (danh sách đầy đủ của bảng, đã đúng thứ tự người dùng muốn).
      # Các món đã lưu mà bảng hiện tại không có (bảng của lần chọn khác) giữ nguyên chỗ; các món của bảng chiếm lại đúng
      # những chỗ của chúng trong danh sách đã lưu, theo thứ tự mới. Món chưa từng lưu được thêm vào cuối trước khi xếp chỗ.
      def self.merge(stored, incoming)
        incoming = sanitize!(incoming)
        present = incoming.to_h { |pid| [pid, true] }
        base = stored + incoming.reject { |pid| stored.include?(pid) }
        queue = incoming.dup
        merged = base.map { |pid| present[pid] ? queue.shift : pid }
        raise ArgumentError, 'Thứ tự dòng quá dài.' if merged.size > MAX_ENTRIES
        merged
      end

      # Bỏ các món khỏi thứ tự đã lưu (nút "Bỏ xếp tay" cho các món đang trong bảng).
      def self.without(stored, pids)
        drop = sanitize!(pids).to_h { |pid| [pid, true] }
        stored.reject { |pid| drop[pid] }
      end

      # Ghi danh sách đã gộp vào model, trong một thao tác trong suốt (gộp vào bước hoàn tác trước, không thêm bước mới).
      def self.write(model, list)
        return false unless model.respond_to?(:set_attribute) && model.respond_to?(:start_operation)
        model.start_operation('VGD_BIM · Thứ tự dòng', true, false, true)
        begin
          model.set_attribute(DICTIONARY, KEY, JSON.generate(list))
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end
        true
      end

      # payload từ giao diện: {'order' => [...]} (thứ tự mới của bảng) hoặc {'reset' => [...]} (các món bỏ xếp tay).
      def self.apply(model, payload)
        raise ArgumentError, 'Yêu cầu sắp xếp không hợp lệ.' unless payload.is_a?(Hash)
        stored = read(model)
        updated = if payload.key?('reset') then without(stored, payload['reset'])
                  elsif payload.key?('order') then merge(stored, payload['order'])
                  else raise ArgumentError, 'Yêu cầu sắp xếp không hợp lệ.'
                  end
        write(model, updated) unless updated == stored
        updated
      end
    end
  end
end
