require 'zlib'

module VGD
  module BIM
    # Đọc bảng tính .xlsx (Excel) bằng Ruby thuần, không thêm thư viện: chỉ đọc các ô chữ và số của trang tính đầu tiên.
    # Dữ liệu là file do người dùng chọn nên mọi giới hạn đều được kiểm tra (dung lượng file, dung lượng sau khi giải nén, số dòng, số cột);
    # không giải nén ra đĩa, chỉ đọc vài phần cần thiết (workbook, quan hệ, chuỗi dùng chung, trang tính) trong bộ nhớ.
    module XlsxReader
      MAX_FILE_BYTES = 5 * 1024 * 1024        # file .xlsx
      MAX_PART_BYTES = 20 * 1024 * 1024       # một phần sau khi giải nén (chống file nén bom)
      MAX_ENTRIES = 500
      MAX_ROWS = 5000
      MAX_COLUMNS = 40
      MAX_CELL_CHARS = 500

      Error = Class.new(ArgumentError)

      # bytes: nội dung file .xlsx. Trả về mảng các dòng, mỗi dòng là mảng chuỗi (ô trống là ""), dòng cuối trống bị bỏ.
      def self.read(bytes)
        bytes = bytes.to_s.b
        raise Error, 'File Excel quá lớn (tối đa 5 MB).' if bytes.bytesize > MAX_FILE_BYTES
        parts = entries(bytes)
        raise Error, 'File không phải Excel (.xlsx) hợp lệ.' unless parts.key?('xl/workbook.xml')
        sheet_path = first_sheet_path(parts, bytes)
        sheet = part(parts, bytes, sheet_path) or raise Error, 'Không đọc được trang tính đầu tiên.'
        strings = shared_strings(part(parts, bytes, 'xl/sharedStrings.xml'))
        rows(sheet, strings)
      end

      # Thư mục trung tâm của zip: {tên => thông tin}. Chỉ đọc cấu trúc, chưa giải nén.
      def self.entries(bytes)
        eocd = bytes.rindex([0x06054b50].pack('V'))
        raise Error, 'File không phải Excel (.xlsx) hợp lệ.' unless eocd && bytes.bytesize >= eocd + 22
        total, _size, start = bytes.byteslice(eocd + 10, 12).unpack('vVV')
        raise Error, 'File Excel có quá nhiều phần.' if total > MAX_ENTRIES
        found = {}
        position = start
        total.times do
          header = bytes.byteslice(position, 46)
          raise Error, 'File không phải Excel (.xlsx) hợp lệ.' unless header && header.bytesize == 46
          signature, _v1, _v2, flag, method, _t, _d, _crc, csize, size, name_len, extra_len, comment_len, _disk, _int, _ext, offset = header.unpack('VvvvvvvVVVvvvvvVV')
          raise Error, 'File không phải Excel (.xlsx) hợp lệ.' unless signature == 0x02014b50
          raise Error, 'File Excel có mã hóa, chưa đọc được.' if flag & 1 == 1
          name = bytes.byteslice(position + 46, name_len).to_s.force_encoding('UTF-8')
          found[name] = {method: method, csize: csize, size: size, offset: offset}
          position += 46 + name_len + extra_len + comment_len
        end
        found
      end

      # Nội dung một phần (đã giải nén, UTF-8) hoặc nil nếu không có.
      def self.part(parts, bytes, name)
        entry = parts[name]
        return nil unless entry
        raise Error, 'File Excel có phần quá lớn.' if entry[:size] > MAX_PART_BYTES
        local = bytes.byteslice(entry[:offset], 30)
        raise Error, 'File không phải Excel (.xlsx) hợp lệ.' unless local && local.bytesize == 30 && local.unpack1('V') == 0x04034b50
        name_len, extra_len = local.byteslice(26, 4).unpack('vv')
        body = bytes.byteslice(entry[:offset] + 30 + name_len + extra_len, entry[:csize])
        raise Error, 'File không phải Excel (.xlsx) hợp lệ.' unless body && body.bytesize == entry[:csize]
        data = case entry[:method]
               when 0 then body
               when 8 then inflate(body)
               else raise Error, 'File Excel dùng kiểu nén chưa hỗ trợ.'
               end
        data.force_encoding('UTF-8')
        data.valid_encoding? ? data : data.scrub('?')
      end

      def self.inflate(body)
        out = String.new(encoding: Encoding::BINARY)
        inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
        inflater.inflate(body) do |chunk|
          out << chunk
          raise Error, 'File Excel có phần quá lớn.' if out.bytesize > MAX_PART_BYTES
        end
        inflater.close
        out
      rescue Zlib::Error
        raise Error, 'File Excel bị hỏng (không giải nén được).'
      end

      # Đường dẫn trang tính đầu tiên theo workbook.xml và quan hệ; không có thì xl/worksheets/sheet1.xml.
      def self.first_sheet_path(parts, bytes)
        workbook = part(parts, bytes, 'xl/workbook.xml').to_s
        rid = workbook[/<sheet\b[^>]*\br:id="([^"]+)"/, 1]
        rels = part(parts, bytes, 'xl/_rels/workbook.xml.rels').to_s
        if rid
          rels.scan(/<Relationship\b[^>]*>/).each do |tag|
            next unless tag[/\bId="([^"]+)"/, 1] == rid
            target = tag[/\bTarget="([^"]+)"/, 1].to_s
            path = target.start_with?('/') ? target.sub(%r{\A/}, '') : "xl/#{target}"
            return path if parts.key?(path)
          end
        end
        parts.key?('xl/worksheets/sheet1.xml') ? 'xl/worksheets/sheet1.xml' : parts.keys.find { |name| name.start_with?('xl/worksheets/') && name.end_with?('.xml') }
      end

      def self.shared_strings(xml)
        return [] unless xml
        xml.scan(%r{<si\b[^>]*>(.*?)</si>}m).map { |(item)| text_of(item) }
      end

      # Chữ của một mục: nối các <t>, bỏ phần phiên âm <rPh>.
      def self.text_of(fragment)
        fragment.gsub(%r{<rPh\b.*?</rPh>}m, '').scan(%r{<t\b[^>]*>(.*?)</t>}m).map { |(text)| unescape(text) }.join
      end

      def self.unescape(text)
        text.gsub(/&(#x[0-9A-Fa-f]+|#\d+|amp|lt|gt|quot|apos);/) do
          entity = Regexp.last_match(1)
          case entity
          when 'amp' then '&'
          when 'lt' then '<'
          when 'gt' then '>'
          when 'quot' then '"'
          when 'apos' then "'"
          when /\A#x/ then [entity[2..].to_i(16)].pack('U')
          else [entity[1..].to_i].pack('U')
          end
        end
      end

      def self.column_index(letters)
        letters.upcase.each_char.inject(0) { |sum, ch| sum * 26 + (ch.ord - 64) } - 1
      end

      def self.rows(sheet, strings)
        result = []
        sheet.scan(%r{<row\b[^>]*?(?:/>|>(.*?)</row>)}m).each do |(content)|
          raise Error, "File Excel có quá nhiều dòng (tối đa #{MAX_ROWS})." if result.size >= MAX_ROWS
          cells = []
          content.to_s.scan(%r{<c\b([^>]*?)(?:/>|>(.*?)</c>)}m) do |attributes, inner|
            ref = attributes[/\br="([A-Za-z]+)\d+"/, 1]
            index = ref ? column_index(ref) : cells.size
            next if index >= MAX_COLUMNS
            cells[index] = cell_value(attributes[/\bt="([^"]+)"/, 1], inner.to_s, strings)[0, MAX_CELL_CHARS]
          end
          result << cells.map { |value| value.to_s }
        end
        result.pop while result.last && result.last.all?(&:empty?)
        result
      end

      def self.cell_value(type, inner, strings)
        value = inner[%r{<v>(.*?)</v>}m, 1]
        case type
        when 's' then strings[value.to_i].to_s
        when 'inlineStr' then text_of(inner[%r{<is\b[^>]*>(.*?)</is>}m, 1].to_s)
        when 'str', 'e' then unescape(value.to_s)
        when 'b' then value == '1' ? 'TRUE' : 'FALSE'
        else
          number = value.to_s
          number.match?(/\A-?\d+\.0+\z/) ? number.sub(/\.0+\z/, '') : number
        end
      end
    end
  end
end
