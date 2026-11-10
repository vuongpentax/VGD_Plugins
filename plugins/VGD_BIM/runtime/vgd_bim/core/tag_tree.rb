module VGD
  module BIM
    # Cây tag của model (thư mục tag và tag) và kế hoạch cô lập. Logic thuần, không gọi SketchUp: nhận danh sách đã đọc sẵn
    #   layers:  [{id:, name:, visible:, folder_id:}]   folder_id nil = nằm ở gốc
    #   folders: [{id:, name:, visible:, parent_id:}]   parent_id nil = nằm ở gốc
    # (id là persistent_id của SketchUp; phần tử có thêm khóa khác, ví dụ :object, thì bỏ qua).
    module TagTree
      # "#rrggbb" (hoa thường đều được) -> [r, g, b]. Ném lỗi nếu không đúng dạng.
      def self.parse_color(text)
        match = text.to_s.strip.match(/\A#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})\z/)
        raise ArgumentError, 'Màu không hợp lệ.' unless match
        match.captures.map { |part| part.to_i(16) }
      end

      # [r, g, b] -> "#rrggbb" (chữ thường).
      def self.hex_color(rgb)
        format('#%02x%02x%02x', *rgb.first(3).map { |value| [[value.to_i, 0].max, 255].min })
      end

      # Hiển thị hiện tại của mọi tag và thư mục, để khôi phục sau khi cô lập.
      def self.snapshot(layers, folders)
        {layers: layers.to_h { |layer| [layer[:id], layer[:visible] ? true : false] },
         folders: folders.to_h { |folder| [folder[:id], folder[:visible] ? true : false] }}
      end

      # Thư mục chứa folder_id và mọi thư mục cha của nó (đi từ dưới lên, chống vòng lặp do dữ liệu hỏng).
      def self.with_ancestors(folders, folder_id)
        by_id = folders.to_h { |folder| [folder[:id], folder] }
        result = []
        current = folder_id
        while current && by_id[current] && !result.include?(current)
          result << current
          current = by_id[current][:parent_id]
        end
        result
      end

      # Thư mục folder_id và mọi thư mục con cháu.
      def self.with_descendants(folders, folder_id)
        result = [folder_id]
        loop do
          more = folders.select { |folder| result.include?(folder[:parent_id]) && !result.include?(folder[:id]) }.map { |folder| folder[:id] }
          break if more.empty?
          result.concat(more)
        end
        result
      end

      # Hiển thị mong muốn khi cô lập một tag (kind 'tag') hoặc một thư mục (kind 'folder'): chỉ đối tượng đó (cùng các thư mục chứa nó,
      # và với thư mục thì cả tag con cháu) hiện, mọi thứ khác ẩn. Trả {layers: {id => true/false}, folders: {id => true/false}}.
      def self.isolate_plan(layers, folders, kind, id)
        keep_layers = []
        keep_folders = []
        case kind
        when 'tag'
          layer = layers.find { |item| item[:id] == id } or raise ArgumentError, 'Không tìm thấy tag này. Hãy làm mới danh sách.'
          keep_layers = [id]
          keep_folders = with_ancestors(folders, layer[:folder_id])
        when 'folder'
          folder = folders.find { |item| item[:id] == id } or raise ArgumentError, 'Không tìm thấy thư mục này. Hãy làm mới danh sách.'
          inside = with_descendants(folders, id)
          keep_folders = with_ancestors(folders, folder[:parent_id]) | inside
          keep_layers = layers.select { |layer| inside.include?(layer[:folder_id]) }.map { |layer| layer[:id] }
        else
          raise ArgumentError, 'Loại mục không hợp lệ.'
        end
        {layers: layers.to_h { |layer| [layer[:id], keep_layers.include?(layer[:id])] },
         folders: folders.to_h { |item| [item[:id], keep_folders.include?(item[:id])] }}
      end

      # Chỉ giữ phần khác với hiện tại, để chỉ đụng vào mục thật sự đổi.
      def self.changes(layers, folders, desired)
        {layers: layers.select { |layer| desired[:layers].key?(layer[:id]) && (layer[:visible] ? true : false) != desired[:layers][layer[:id]] }.map { |layer| layer[:id] },
         folders: folders.select { |item| desired[:folders].key?(item[:id]) && (item[:visible] ? true : false) != desired[:folders][item[:id]] }.map { |item| item[:id] }}
      end
    end
  end
end
