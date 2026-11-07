require 'cgi'
require 'tmpdir'
require_relative 'images'
require_relative 'xlsx'

module VGD
  module BIM
    # Báo cáo xuất từ Bảng khối lượng, đúng như bảng đang hiện (cột, thứ tự, tiêu đề, đơn vị, nhóm, dòng tổng). Giao diện gửi lên
    # cấu trúc bảng; ở đây kiểm tra lại rồi lấy ảnh từ file ảnh của plugin (không nhận đường dẫn từ giao diện).
    #   payload = {'title', 'preset', 'decimal_separator', 'labels' => {'model','preset','date','print'},
    #              'columns' => [{'label','unit','type','digits'}], 'rows' => [{'kind','pid','cells'}]}
    # type: text | number | image | link | ordinal; kind: row | group | total. Ô số gửi dạng số (đã đổi đơn vị), chưa làm tròn.
    module TableReport
      MAX_ROWS = 50_000
      MAX_COLUMNS = 60
      MAX_TEXT = 2000
      TYPES = %w[text number image link ordinal].freeze
      KINDS = %w[row group total].freeze
      LABEL_KEYS = %w[model preset date print].freeze
      PREFIX = 'VGD_BIM_bao_cao_'.freeze
      KEEP_SECONDS = 2 * 24 * 3600

      # image_for: gọi với mã đối tượng, trả về nội dung PNG (hoặc nil nếu không có / mã không thuộc bảng).
      def self.build(payload, model_name, image_for)
        raise ArgumentError, 'Dữ liệu bảng không hợp lệ.' unless payload.is_a?(Hash)
        columns = columns!(payload['columns'])
        rows = rows!(payload['rows'], columns.size)
        raise ArgumentError, 'Bảng chưa có dòng nào. Hãy chọn group hoặc component trong SketchUp.' unless rows.any? { |row| row[:kind] == 'row' }
        labels = LABEL_KEYS.each_with_object({}) { |key, hash| hash[key] = text!(payload.dig('labels', key), 60) }
        title = text!(payload['title'], 200)
        preset = text!(payload['preset'], 100)
        separator = payload['decimal_separator'] == '.' ? '.' : ','
        images = {}
        has_image_column = columns.any? { |c| c[:type] == 'image' }
        rows.each do |row|
          next unless has_image_column && row[:pid]
          images[row[:pid]] = load_image(row[:pid], image_for) unless images.key?(row[:pid])
          row[:image] = images[row[:pid]]
        end
        meta = ["#{labels['model']}: #{model_name}", ("#{labels['preset']}: #{preset}" unless preset.empty?), "#{labels['date']}: #{Time.now.strftime('%d/%m/%Y')}"].compact.join('  ·  ')
        {title: title, meta: meta, preset: preset, model: model_name, labels: labels, separator: separator, columns: columns, rows: rows,
         images: images.compact}
      end

      def self.columns!(list)
        raise ArgumentError, 'Dữ liệu bảng không hợp lệ.' unless list.is_a?(Array) && !list.empty? && list.size <= MAX_COLUMNS
        list.map do |col|
          raise ArgumentError, 'Dữ liệu bảng không hợp lệ.' unless col.is_a?(Hash) && TYPES.include?(col['type'])
          digits = col['digits'].nil? ? 0 : col['digits']
          raise ArgumentError, 'Số lẻ không hợp lệ.' unless digits.is_a?(Integer) && digits.between?(0, 6)
          {label: text!(col['label'], 200), unit: text!(col['unit'], 20), type: col['type'], digits: digits}
        end
      end

      def self.rows!(list, width)
        raise ArgumentError, 'Dữ liệu bảng không hợp lệ.' unless list.is_a?(Array) && list.size <= MAX_ROWS
        list.map do |row|
          raise ArgumentError, 'Dữ liệu bảng không hợp lệ.' unless row.is_a?(Hash) && KINDS.include?(row['kind']) && row['cells'].is_a?(Array) && row['cells'].size == width
          pid = row['pid'].nil? ? nil : Images.id!(row['pid'])
          cells = row['cells'].map { |value| cell!(value) }
          {kind: row['kind'], pid: pid, cells: cells, image: nil}
        end
      end

      def self.cell!(value)
        return nil if value.nil?
        return value if value.is_a?(Integer)
        return value if value.is_a?(Float) && value.finite?
        return text!(value, MAX_TEXT) if value.is_a?(String)
        raise ArgumentError, 'Dữ liệu bảng không hợp lệ.'
      end

      def self.text!(value, limit)
        return '' if value.nil?
        raise ArgumentError, 'Dữ liệu bảng không hợp lệ.' unless value.is_a?(String) && value.length <= limit
        value.gsub(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/, '') # ký tự điều khiển không in được, XML cũng không cho phép
      end

      # Ảnh nhỏ do plugin ghi: phải là PNG đọc được kích thước. Ảnh hỏng thì bỏ qua (ô để trống), không làm hỏng cả báo cáo.
      def self.load_image(pid, image_for)
        bytes = image_for.call(pid)
        return nil unless Images.png?(bytes) && bytes.bytesize <= Images::MAX_BYTES
        width, height = bytes.byteslice(16, 8).unpack('NN')
        return nil unless width.to_i.between?(1, 16_384) && height.to_i.between?(1, 16_384)
        {bytes: bytes, width: width, height: height, mime: 'image/png'}
      end

      # Số theo định dạng của preset (dấu thập phân, nhóm hàng nghìn), dùng cho trang in PDF.
      def self.format_number(value, digits, separator)
        whole, frac = format("%.#{digits}f", value.round(digits, half: :up)).split('.')
        thousands = separator == ',' ? '.' : ','
        whole = whole.sub(/\A(-?)(\d+)\z/) { "#{$1}#{$2.reverse.scan(/\d{1,3}/).join(thousands).reverse}" }
        frac ? "#{whole}#{separator}#{frac}" : whole
      end

      def self.html_cell(report, row, col, index)
        value = row[:cells][index]
        case col[:type]
        when 'image'
          image = row[:image]
          return '<td class="img"></td>' unless image
          %(<td class="img"><img alt="" src="data:image/png;base64,#{[image[:bytes]].pack('m0')}"></td>)
        when 'ordinal'
          %(<td class="ord">#{CGI.escapeHTML(value.is_a?(Numeric) ? value.to_i.to_s : value.to_s)}</td>)
        when 'link'
          url = value.to_s
          text = CGI.escapeHTML(url)
          url.match?(%r{\Ahttps?://}i) && row[:kind] == 'row' ? %(<td class="link"><a href="#{CGI.escapeHTML(url)}">#{text}</a></td>) : "<td>#{text}</td>"
        else
          return %(<td class="num">#{CGI.escapeHTML(format_number(value, col[:digits], report[:separator]))}</td>) if value.is_a?(Numeric)
          "<td>#{CGI.escapeHTML(value.to_s)}</td>"
        end
      end

      # Trang HTML tự chứa (ảnh nhúng sẵn): mở bằng trình duyệt rồi In > Lưu thành PDF. Khổ A4 ngang, tiêu đề cột lặp lại mỗi trang.
      def self.html(report)
        head = report[:columns].map { |c| "<th>#{CGI.escapeHTML(c[:label])}#{c[:unit].empty? ? '' : %(<span class="unit">#{CGI.escapeHTML(c[:unit])}</span>)}</th>" }.join
        body = report[:rows].map do |row|
          cells = report[:columns].each_with_index.map { |col, i| html_cell(report, row, col, i) }.join
          %(<tr class="#{row[:kind]}">#{cells}</tr>)
        end.join("\n")
        <<~HTML
          <!doctype html>
          <html lang="vi"><head><meta charset="utf-8"><title>#{CGI.escapeHTML(report[:title])}</title>
          <style>
          @page{size:A4 landscape;margin:10mm}
          *{box-sizing:border-box}
          body{font:9pt/1.35 "Segoe UI",Arial,sans-serif;color:#222;margin:0;padding:12px}
          h1{font-size:16pt;margin:0 0 2px}
          .meta{color:#666;font-size:8.5pt;margin:0 0 10px}
          .bar{margin:0 0 10px}
          .bar button{font:inherit;padding:6px 14px;border:1px solid #b48963;background:#b48963;color:#fff;border-radius:4px;cursor:pointer}
          table{border-collapse:collapse;width:100%}
          thead{display:table-header-group}
          th,td{border:1px solid #c8c8c8;padding:3px 5px;vertical-align:middle;text-align:left}
          th{background:#e8dccb;font-weight:700;text-align:center}
          .unit{display:block;font-weight:400;font-style:italic;color:#555;font-size:8pt}
          tr{page-break-inside:avoid}
          td.num{text-align:right;white-space:nowrap;font-variant-numeric:tabular-nums}
          td.ord{text-align:center}
          td.img{text-align:center;width:22mm;padding:2px}
          td.img img{max-width:20mm;max-height:16mm;display:block;margin:0 auto}
          td.link a{color:#0563c1;word-break:break-all}
          tr.group td{background:#f4eee6;font-weight:700}
          tr.total td{background:#e8dccb;font-weight:700;border-top:2px solid #222}
          @media print{.bar{display:none}body{padding:0}}
          </style></head><body>
          <div class="bar"><button type="button" onclick="window.print()">#{CGI.escapeHTML(report[:labels]['print'].empty? ? 'In / Lưu PDF' : report[:labels]['print'])}</button></div>
          <h1>#{CGI.escapeHTML(report[:title])}</h1>
          <p class="meta">#{CGI.escapeHTML(report[:meta])}</p>
          <table><thead><tr>#{head}</tr></thead><tbody>
          #{body}
          </tbody></table>
          <script>window.addEventListener('load',function(){setTimeout(function(){window.print();},500);});</script>
          </body></html>
        HTML
      end

      # Ghi trang HTML vào thư mục tạm (xóa các trang cũ của plugin quá 2 ngày) và trả về đường dẫn.
      def self.write_html(report, dir = Dir.tmpdir)
        sweep(dir)
        path = File.join(dir, "#{PREFIX}#{Time.now.strftime('%Y%m%d_%H%M%S')}.html")
        File.write(path, html(report), encoding: 'UTF-8')
        path
      end

      def self.sweep(dir)
        Dir.glob(File.join(dir, "#{PREFIX}*.html")).each do |file|
          File.delete(file) if Time.now - File.mtime(file) > KEEP_SECONDS
        end
      rescue StandardError
        nil
      end

      # Địa chỉ file:/// cho UI.openURL (mã hóa mọi ký tự ngoài chữ, số và / : . _ ~ -).
      def self.file_url(path)
        encoded = path.tr('\\', '/').b.gsub(%r{[^A-Za-z0-9/:._~-]}n) { |c| format('%%%02X', c.ord) }
        "file:///#{encoded.sub(%r{\A/+}, '')}"
      end
    end
  end
end
