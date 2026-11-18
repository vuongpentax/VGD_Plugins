require 'csv'
require_relative 'xlsx_reader'
require_relative 'table'

module VGD
  module BIM
    # Cầu nối dữ liệu (theo mẫu 5D Auto Info): nhập file Excel / CSV vào dữ liệu chữ của món trong model.
    # Phần này chỉ là logic thuần (đọc file, ánh xạ cột, lập kế hoạch thay đổi để xem trước); việc ghi vào model do UI::Dialog làm.
    # File do người dùng chọn nên mọi giới hạn đều được kiểm tra. Ô trống nghĩa là "không đổi" (không bao giờ xóa dữ liệu trong model).
    module DataBridge
      MAX_FILE_BYTES = XlsxReader::MAX_FILE_BYTES
      MAX_ROWS = XlsxReader::MAX_ROWS
      MAX_COLUMNS = XlsxReader::MAX_COLUMNS
      MAX_TEXT = {'name' => 200, 'description' => 1000, 'owner' => 200}.freeze
      CONTROL = /[\u0000-\u001f\u007f]/
      HEADER_SEARCH_ROWS = 10 # file Excel do BIM xuất có dòng tiêu đề và ghi chú phía trên hàng tiêu đề cột

      Error = Class.new(ArgumentError)

      # Cột để khớp dòng file với món trong model. Mã đối tượng khớp không phân biệt hoa thường.
      MATCH = {'vgd_id' => 'VGD ID', 'code' => 'Mã đối tượng'}.freeze
      # Dữ liệu chữ được phép ghi. Tag, vật liệu, tầng, phòng, tình trạng, mã đối tượng không nhập từ file (xem docs/vgd_bim/BRIDGE.md).
      FIELDS = [
        {key: 'name', label: 'Tên'}, {key: 'description', label: 'Mô tả'}, {key: 'owner', label: 'Xuất xứ'},
        {key: 'url', label: 'Liên kết'}, {key: 'size', label: 'Quy cách'}, {key: 'price', label: 'Đơn giá'}
      ].freeze
      ALIASES = {
        'vgd_id' => ['vgd id', 'vgdid', 'id'], 'code' => ['ma doi tuong', 'ma', 'code'],
        'name' => ['ten', 'name', 'instance'], 'description' => ['mo ta', 'description'],
        'owner' => ['xuat xu', 'hang', 'manufacturer', 'owner'], 'url' => ['lien ket', 'link', 'url'],
        'size' => ['quy cach', 'co', 'size'], 'price' => ['don gia', 'price']
      }.freeze

      # Các trường ghi được: cố định + cột chữ người dùng tự thêm.
      def self.fields(custom_columns = [])
        FIELDS + custom_columns.select { |c| c['kind'] == 'text' }.map { |c| {key: c['key'], label: c['label']} }
      end

      # Đọc file Excel (.xlsx, trang tính đầu) hoặc CSV; trả về {name:, headers:, rows:, header_row:}. rows là mảng dòng dữ liệu (mảng chuỗi).
      def self.read_file(path)
        raise Error, 'Không tìm thấy file.' unless File.file?(path)
        raise Error, 'File quá lớn (tối đa 5 MB).' if File.size(path) > MAX_FILE_BYTES
        extension = File.extname(path).downcase
        lines = case extension
                when '.xlsx' then XlsxReader.read(File.binread(path))
                when '.csv' then parse_csv(File.read(path, encoding: 'bom|utf-8'))
                else raise Error, 'Chỉ nhập được file Excel (.xlsx) hoặc CSV.'
                end
        table(lines).merge(name: File.basename(path))
      rescue XlsxReader::Error => error
        raise Error, error.message
      end

      def self.parse_csv(text)
        raise Error, 'File này là Excel. Hãy chọn đuôi .xlsx, hoặc lưu lại dưới dạng CSV UTF-8.' if text.start_with?('PK')
        first = text.each_line.first.to_s
        separator = first.count(';') > first.count(',') ? ';' : ','
        rows = CSV.parse(text, col_sep: separator, skip_blanks: true)
        rows.map { |row| row.map { |cell| cell.to_s } }
      rescue CSV::MalformedCSVError => error
        raise Error, "File CSV bị lỗi: #{error.message}"
      end

      # Chọn dòng tiêu đề (dòng đầu có cột khớp VGD ID / Mã đối tượng trong 10 dòng đầu, nếu không có thì dòng đầu) rồi tách dữ liệu.
      def self.table(lines)
        numbered = lines.each_with_index.reject { |row, _i| row.all? { |cell| cell.to_s.strip.empty? } } # giữ số dòng gốc của file để báo đúng dòng
        lines = numbered.map(&:first)
        raise Error, 'File rỗng hoặc không có dữ liệu.' if lines.size < 2
        header_row = lines.first(HEADER_SEARCH_ROWS).index { |row| row.any? { |cell| MATCH.keys.any? { |key| ALIASES[key].include?(normalize(cell)) } } } || 0
        headers = lines[header_row].map { |cell| cell.to_s.gsub(CONTROL, ' ').strip }
        headers.pop while headers.last && headers.last.empty?
        raise Error, "File có quá nhiều cột (tối đa #{MAX_COLUMNS})." if headers.size > MAX_COLUMNS
        raise Error, 'Dòng tiêu đề trống.' if headers.empty?
        used = headers.reject(&:empty?)
        raise Error, "Tiêu đề cột bị trùng: #{(used.select { |h| used.count(h) > 1 }).uniq.first}. Hãy đổi tên cột trong file." if used.uniq.size != used.size
        rows = lines[(header_row + 1)..-1].map { |row| headers.each_index.map { |i| row[i].to_s.gsub(CONTROL, ' ') } }
        raise Error, 'File không có dòng dữ liệu nào.' if rows.empty?
        raise Error, "File có quá nhiều dòng (tối đa #{MAX_ROWS})." if rows.size > MAX_ROWS
        {headers: headers, rows: rows, header_row: numbered[header_row].last + 1, numbers: numbered[(header_row + 1)..-1].map { |_row, i| i + 1 }}
      end

      # Chữ thường, bỏ dấu, chỉ giữ chữ và số: để so tên cột "Mã đối tượng" với "ma doi tuong".
      def self.normalize(text)
        text.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '').tr('đĐ', 'dD').downcase.gsub(/[^a-z0-9]+/, ' ').strip
      end

      # Gợi ý ban đầu: cột khớp (VGD ID ưu tiên hơn Mã đối tượng) và cột nào ghi vào trường nào, theo tên cột.
      def self.suggest(headers, fields)
        match_by = MATCH.keys.find { |key| headers.any? { |h| ALIASES[key].include?(normalize(h)) } }
        match_column = match_by ? headers.find { |h| ALIASES[match_by].include?(normalize(h)) } : nil
        mapping = {}
        headers.each do |header|
          next if header.empty? || header == match_column
          norm = normalize(header)
          field = fields.find { |f| (ALIASES[f[:key]] || [normalize(f[:label])]).include?(norm) || normalize(f[:label]) == norm }
          mapping[header] = field[:key] if field && !mapping.value?(field[:key])
        end
        {match_by: match_by || 'vgd_id', match_column: match_column, mapping: mapping}
      end

      # Kiểm tra và làm sạch một giá trị. Trả về giá trị mới (Float cho đơn giá, chuỗi cho còn lại); lỗi thì raise ArgumentError.
      def self.clean(field, text)
        text = text.to_s.gsub(CONTROL, ' ').strip
        case field
        when 'url' then Table::Extras.clean_url(text)
        when 'size' then Table::Extras.clean_size(text)
        when 'price' then Table::Extras.clean_price(text)
        else
          limit = MAX_TEXT.fetch(field, CustomColumns::MAX_VALUE)
          raise ArgumentError, "Giá trị tối đa #{limit} ký tự." if text.length > limit
          text
        end
      end

      # options: {'match_by', 'match_column', 'mapping' => {tiêu đề cột => khóa trường}}.
      # targets: các món của bảng hiện tại: {index:, ids: {'vgd_id'=>, 'code'=>}, name:, locked:, current: {khóa trường => giá trị hiện tại}}.
      # Trả về {rows: [...], counts: {...}}; mỗi dòng có status ok / unchanged / unmatched / ambiguous / file_duplicate / locked / blank.
      def self.plan(file, options, targets, fields)
        match_by = options['match_by'].to_s
        raise Error, 'Hãy chọn khóa để khớp (VGD ID hoặc Mã đối tượng).' unless MATCH.key?(match_by)
        match_at = file[:headers].index(options['match_column'].to_s)
        raise Error, 'Hãy chọn cột của file dùng để khớp.' unless match_at
        mapping = options['mapping'].is_a?(Hash) ? options['mapping'].reject { |_header, key| key.to_s.empty? } : {}
        raise Error, 'Hãy chọn ít nhất một cột để nhập.' if mapping.empty?
        keys = fields.map { |f| f[:key] }
        labels = fields.each_with_object({}) { |f, h| h[f[:key]] = f[:label] }
        columns = mapping.map do |header, key|
          raise Error, "Cột “#{header}” không có trong file." unless file[:headers].include?(header)
          raise Error, "Cột “#{header}” không thể là cột khớp." if header == options['match_column']
          raise Error, 'Trường nhập không hợp lệ.' unless keys.include?(key)
          [file[:headers].index(header), key]
        end
        raise Error, 'Hai cột của file đang cùng ghi vào một trường.' if columns.map(&:last).uniq.size != columns.size
        by_key = targets.group_by { |target| match_key(target[:ids][match_by]) }
        seen = file[:rows].map { |row| match_key(row[match_at]) }.tally
        rows = file[:rows].each_with_index.map do |cells, i|
          key = cells[match_at].to_s.strip
          base = {row: file[:numbers][i], key: key, index: nil, name: '', changes: []}
          next base.merge(status: 'blank') if key.empty?
          next base.merge(status: 'file_duplicate') if seen[match_key(key)] > 1
          found = by_key[match_key(key)] || []
          next base.merge(status: 'unmatched') if found.empty?
          next base.merge(status: 'ambiguous', count: found.size) if found.size > 1
          target = found.first
          base = base.merge(index: target[:index], name: target[:name].to_s)
          changes = changes_for(cells, columns, target, labels)
          status = if target[:locked] then 'locked'
                   elsif changes.empty? then 'unchanged'
                   else 'ok'
                   end
          base.merge(status: status, changes: changes)
        end
        {rows: rows, counts: counts(rows)}
      end

      def self.match_key(text)
        text.to_s.strip.downcase
      end

      def self.changes_for(cells, columns, target, labels)
        columns.each_with_object([]) do |(at, field), out|
          raw = cells[at].to_s.strip
          next if raw.empty?
          old = target[:current][field]
          begin
            value = clean(field, raw)
            next if same?(field, old, value)
            out << {field: field, label: labels[field], old: show(old), new: show(value)}
          rescue ArgumentError => error
            out << {field: field, label: labels[field], old: show(old), new: raw, error: error.message}
          end
        end
      end

      def self.same?(field, old, value)
        return old.is_a?(Numeric) && (old - value).abs < 1e-9 if field == 'price' && !value.nil?
        old.to_s == value.to_s
      end

      def self.show(value)
        value.is_a?(Float) ? format('%.4f', value).sub(/\.?0+\z/, '') : value.to_s
      end

      def self.counts(rows)
        tally = rows.map { |row| row[:status] }.tally
        changes = rows.select { |row| row[:status] == 'ok' }.flat_map { |row| row[:changes] }
        {rows: rows.size, ok: tally.fetch('ok', 0), unchanged: tally.fetch('unchanged', 0), unmatched: tally.fetch('unmatched', 0),
         ambiguous: tally.fetch('ambiguous', 0), file_duplicate: tally.fetch('file_duplicate', 0), locked: tally.fetch('locked', 0),
         blank: tally.fetch('blank', 0), changes: changes.count { |c| !c[:error] }, errors: changes.count { |c| c[:error] }}
      end
    end
  end
end
