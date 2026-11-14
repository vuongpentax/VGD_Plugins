require_relative 'measure'
require_relative 'tags'
require_relative 'tag_tree'
require_relative 'xlsx_reader'

module VGD
  module BIM
    # Nhập tag từ file Excel (.xlsx) theo cách của 5D Auto Tag: bảng có cột tên tag, màu, kiểu nét, thư mục. Logic thuần: nhận các dòng đã đọc
    # (XlsxReader) và trả về danh sách tag đã kiểm tra; phần tạo tag trong model nằm ở UI::TagManager#tm_excel_apply.
    #   - Dòng tiêu đề: dòng đầu có một ô là tên cột "Name" / "Tên tag" / "Tag" (không phân biệt hoa thường và dấu).
    #   - Cột Color: "Color(255, 0, 0, 255)" (cách Auto Tag xuất), "rgb(255,0,0)", "255,0,0" hoặc "#ff0000".
    #   - Cột Dashes / Kiểu nét: tên kiểu nét của SketchUp (Solid, Dash, Dot...), Default = không đổi.
    #   - Thư mục: cột Folder / Thư mục, hoặc dòng có tên bọc trong <...> (kiểu Auto Tag): các tag bên dưới thuộc thư mục đó cho tới dòng <...> kế tiếp.
    module TagExcel
      MAX_ROWS = 2000
      MAX_FOLDER_NAME = 60
      NAME_HEADERS = %w[name ten tag tenta ten\ tag tag\ name layer].freeze
      COLOR_HEADERS = %w[color colour mau].freeze
      STYLE_HEADERS = %w[dashes dash line\ style linestyle kieu\ net net style].freeze
      FOLDER_HEADERS = %w[folder thu\ muc group].freeze

      # rows: mảng các dòng chữ. Trả về {tags: [{'name','color','style','folder'}], warnings: [chữ]}; ném ArgumentError nếu không đọc được.
      def self.parse(rows)
        raise ArgumentError, 'File Excel không có dữ liệu.' unless rows.is_a?(Array) && !rows.empty?
        head_index = rows.index { |row| header_columns(row).key?(:name) }
        raise ArgumentError, 'Không tìm thấy dòng tiêu đề. Dòng đầu của bảng cần có cột "Name" (hoặc "Tên tag").' unless head_index
        columns = header_columns(rows[head_index])
        tags = []
        warnings = []
        folder = ''
        seen = {}
        rows[(head_index + 1)..].each_with_index do |row, offset|
          number = head_index + offset + 2 # số dòng trong Excel (bắt đầu từ 1)
          raw = cell(row, columns[:name])
          next if raw.empty? && cell(row, columns[:color]).empty? && cell(row, columns[:style]).empty?
          if raw =~ /\A<(.+)>\z/m # dòng thư mục kiểu Auto Tag
            folder = clean_folder(Regexp.last_match(1), number, warnings)
            next
          end
          if raw.empty?
            warnings << "Dòng #{number}: thiếu tên tag, bỏ qua."
            next
          end
          raise ArgumentError, "Quá nhiều tag (tối đa #{MAX_ROWS})." if tags.size >= MAX_ROWS
          name = raw.gsub(/\s+/, ' ').strip
          if name.length > Tags::MAX_NAME
            warnings << "Dòng #{number}: tên tag quá dài (tối đa #{Tags::MAX_NAME} ký tự), bỏ qua."
            next
          end
          if Tags.key(name) == 'untagged'
            warnings << "Dòng #{number}: Untagged là tag mặc định của SketchUp, bỏ qua."
            next
          end
          if seen[Tags.key(name)]
            warnings << "Dòng #{number}: tag \"#{name}\" bị trùng, bỏ qua."
            next
          end
          seen[Tags.key(name)] = true
          color = nil
          color_text = cell(row, columns[:color])
          unless color_text.empty?
            rgb = parse_color(color_text)
            color = rgb && TagTree.hex_color(rgb)
            warnings << "Dòng #{number}: màu \"#{color_text}\" không đọc được, bỏ qua màu." unless color
          end
          own_folder = cell(row, columns[:folder])
          tags << {'name' => name, 'color' => color, 'style' => clean_style(cell(row, columns[:style])),
                   'folder' => own_folder.empty? ? folder : clean_folder(own_folder, number, warnings)}
        end
        raise ArgumentError, 'File không có tag nào để nhập.' if tags.empty?
        {tags: tags, warnings: warnings}
      end

      # Kiểm tra lại danh sách tag do giao diện gửi lên (xem trước đã sửa / bỏ dòng). Trả về danh sách đã làm sạch hoặc ném ArgumentError.
      def self.sanitize(list)
        raise ArgumentError, 'Danh sách tag không hợp lệ.' unless list.is_a?(Array) && list.size <= MAX_ROWS
        seen = {}
        list.map do |item|
          raise ArgumentError, 'Danh sách tag không hợp lệ.' unless item.is_a?(Hash)
          name = item['name'].to_s.gsub(/\s+/, ' ').strip
          raise ArgumentError, 'Tên tag không được để trống.' if name.empty?
          raise ArgumentError, "Tên tag quá dài (tối đa #{Tags::MAX_NAME} ký tự): #{name}" if name.length > Tags::MAX_NAME
          raise ArgumentError, 'Tên "Untagged" là tên mặc định của SketchUp, hãy chọn tên khác.' if Tags.key(name) == 'untagged'
          raise ArgumentError, "Tên tag bị trùng: #{name}" if seen[Tags.key(name)]
          seen[Tags.key(name)] = true
          raise ArgumentError, "Tên tag không hợp lệ: #{name}" if name.match?(/[[:cntrl:]]/)
          color = item['color']
          raise ArgumentError, "Màu của tag \"#{name}\" không hợp lệ." unless color.nil? || (color.is_a?(String) && parse_color(color))
          style = item['style'].to_s
          raise ArgumentError, "Kiểu nét của tag \"#{name}\" không hợp lệ." if style.length > 60 || style.match?(/[[:cntrl:]]/)
          folder = item['folder'].to_s
          raise ArgumentError, "Tên thư mục của tag \"#{name}\" không hợp lệ." if folder.length > MAX_FOLDER_NAME || folder.match?(/[[:cntrl:]]/)
          {'name' => name, 'color' => color && TagTree.hex_color(parse_color(color)), 'style' => style.strip, 'folder' => folder.strip}
        end
      end

      # Màu từ chữ: "#rrggbb", "Color(r, g, b, a)", "rgb(r, g, b)" hoặc "r,g,b"; trả về [r, g, b] hoặc nil.
      def self.parse_color(text)
        text = text.to_s.strip
        return TagTree.parse_color(text) if text.start_with?('#')
        numbers = text.scan(/\d+(?:\.\d+)?/).map(&:to_f)
        return nil unless text.match?(/\A(?:color|rgba?)?\s*\(?\s*[\d.]+\s*[, ]\s*[\d.]+\s*[, ]\s*[\d.]+(?:\s*[, ]\s*[\d.]+)?\s*\)?\z/i) && numbers.size >= 3
        rgb = numbers.first(3).map(&:round)
        rgb.all? { |value| value.between?(0, 255) } ? rgb : nil
      rescue ArgumentError
        nil
      end

      # Tên kiểu nét -> khóa so sánh (bỏ hoa thường, dấu, khoảng trắng và chữ "line"): "Dash Line" khớp "dash".
      def self.style_key(text)
        Measure.normalize(text).gsub(/\bline\b/, '').gsub(/[^a-z0-9]/, '')
      end

      # Kiểu nét của model khớp với tên trong Excel: trùng khóa thì lấy luôn, không thì kiểu có khóa bắt đầu bằng khóa cần tìm (hoặc ngược lại,
      # tối thiểu 3 ký tự) và ngắn nhất: "Dash" khớp "Dashed Line", "Dot" khớp "Dotted Line". Trả về tên trong danh sách hoặc nil.
      def self.match_style(query, names)
        wanted = style_key(query)
        return nil if wanted.empty?
        keyed = names.map { |name| [name, style_key(name)] }
        exact = keyed.find { |_, key| key == wanted }
        return exact[0] if exact
        near = keyed.select { |_, key| key.length >= 3 && wanted.length >= 3 && (key.start_with?(wanted) || wanted.start_with?(key)) }
        near.min_by { |_, key| key.length }&.first
      end

      def self.header_columns(row)
        columns = {}
        Array(row).each_with_index do |value, index|
          key = Measure.normalize(value)
          next if key.empty?
          columns[:name] ||= index if NAME_HEADERS.include?(key)
          columns[:color] ||= index if COLOR_HEADERS.include?(key)
          columns[:style] ||= index if STYLE_HEADERS.include?(key)
          columns[:folder] ||= index if FOLDER_HEADERS.include?(key)
        end
        columns
      end

      def self.cell(row, index)
        return '' if index.nil?
        Array(row)[index].to_s.strip
      end

      def self.clean_folder(text, number, warnings)
        name = text.gsub(/\s+/, ' ').strip
        if name.length > MAX_FOLDER_NAME || name.match?(/[[:cntrl:]]/)
          warnings << "Dòng #{number}: tên thư mục không hợp lệ, bỏ thư mục."
          return ''
        end
        name
      end

      def self.clean_style(text)
        text = text.strip
        text.casecmp('default').zero? || text.length > 60 || text.match?(/[[:cntrl:]]/) ? '' : text
      end
    end
  end
end
