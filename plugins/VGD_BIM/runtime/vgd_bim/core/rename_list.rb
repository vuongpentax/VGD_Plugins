require_relative 'rename'
require_relative 'storage'

module VGD
  module BIM
    # Cửa sổ Đổi tên độc lập (ui/rename_window.rb): logic thuần, không gọi SketchUp.
    # Giao diện ghép tên mới = tiền tố + tên + hậu tố (bấm các mẫu tên hoặc gõ tay) cho các món đang chọn trong SketchUp; Ruby chỉ kiểm tra
    # danh sách tên gửi lên rồi ghi trong một bước hoàn tác. Mẫu tên lưu trên máy (rename_templates.json), dùng chung cho mọi file SketchUp.
    module RenameList
      MAX_ITEMS = 2000        # số món tối đa trong danh sách (chọn nhiều hơn thì chỉ lấy chừng này món đầu)
      TEMPLATE_KEYS = %w[prefix name suffix].freeze
      MAX_TEMPLATES = 300     # số mẫu tối đa của mỗi cột
      MAX_TEMPLATE = 100      # độ dài tối đa của một mẫu
      CONTROL = /[\u0000-\u001f\u007f]/
      STORE = 'rename_templates'

      # payload['changes'] = [{'id' => mã món, 'name' => tên mới}]; known: {mã món => đối tượng} của danh sách đang hiện.
      # Trả về [[mã món, tên mới đã cắt khoảng trắng], ...]. Dữ liệu sai thì ArgumentError, không đổi gì.
      def self.changes!(payload, known)
        list = payload.is_a?(Hash) ? payload['changes'] : nil
        raise ArgumentError, 'Dữ liệu đổi tên không hợp lệ.' unless list.is_a?(Array) && list.size <= MAX_ITEMS
        raise ArgumentError, 'Không có món nào cần đổi tên.' if list.empty?
        seen = {}
        list.map do |change|
          raise ArgumentError, 'Dữ liệu đổi tên không hợp lệ.' unless change.is_a?(Hash) && change['id'].is_a?(Integer) && change['name'].is_a?(String)
          id = change['id']
          raise ArgumentError, 'Danh sách đã cũ. Hãy chọn lại các món trong SketchUp.' unless known.key?(id)
          raise ArgumentError, 'Dữ liệu đổi tên không hợp lệ.' if seen[id]
          seen[id] = true
          name = change['name'].strip
          raise ArgumentError, 'Tên mới không được để trống.' if name.empty?
          raise ArgumentError, "Tên mới dài quá #{Rename::MAX_NAME} ký tự." if name.length > Rename::MAX_NAME
          raise ArgumentError, 'Tên mới có ký tự điều khiển.' if name.match?(CONTROL)
          [id, name]
        end
      end

      # Ba cột mẫu tên {'prefix' => [...], 'name' => [...], 'suffix' => [...]}: bỏ mục không phải chữ, trống, quá dài, có ký tự điều khiển, trùng.
      def self.clean_templates(data)
        source = data.is_a?(Hash) ? data : {}
        TEMPLATE_KEYS.to_h do |key|
          list = source[key].is_a?(Array) ? source[key] : []
          words = list.grep(String).map(&:strip).reject { |word| word.empty? || word.length > MAX_TEMPLATE || word.match?(CONTROL) }
          [key, words.uniq.first(MAX_TEMPLATES)]
        end
      end

      def self.templates
        clean_templates(Storage.read(STORE))
      end

      def self.save_templates(data)
        Storage.write(STORE, clean_templates(data))
      end
    end
  end
end
