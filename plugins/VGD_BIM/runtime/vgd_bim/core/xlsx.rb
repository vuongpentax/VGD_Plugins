require 'zlib'
require 'cgi'

module VGD
  module BIM
    # Ghi file .xlsx (Excel) bằng Ruby thuần: một file zip chứa các tệp XML và ảnh PNG. Không cần thư viện ngoài.
    # Nhận báo cáo đã kiểm tra từ TableReport (cột, dòng, ảnh), xem TableReport.build.
    module Xlsx
      PX_TO_EMU = 9525
      TITLE_ROW = 1
      META_ROW = 2
      IMAGE_COLUMN_CHARS = 20  # độ rộng cột Ảnh (ký tự Excel, 145 px)
      IMAGE_ROW_POINTS = 84    # chiều cao hàng có ảnh (point, 112 px)
      IMAGE_BOX_PX = [136, 106].freeze # khung chứa ảnh trong ô (rộng, cao), chừa lề nhỏ; ảnh vẫn nhúng nguyên độ phân giải

      NS_MAIN = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'.freeze
      NS_REL = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'.freeze
      NS_PKG_REL = 'http://schemas.openxmlformats.org/package/2006/relationships'.freeze
      REL_BASE = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'.freeze

      # Tệp zip tối thiểu: tệp XML nén deflate, ảnh PNG lưu nguyên (đã nén sẵn).
      class Zip
        def initialize
          @out = String.new(encoding: Encoding::BINARY)
          @entries = []
          now = Time.now
          @dos_time = (now.hour << 11) | (now.min << 5) | (now.sec / 2)
          @dos_date = ((now.year - 1980) << 9) | (now.month << 5) | now.day
        end

        def add(name, data, compress: true)
          data = data.dup.force_encoding(Encoding::BINARY)
          crc = Zlib.crc32(data)
          method = 0
          body = data
          if compress
            deflater = Zlib::Deflate.new(Zlib::DEFAULT_COMPRESSION, -Zlib::MAX_WBITS)
            body = deflater.deflate(data, Zlib::FINISH)
            deflater.close
            method = 8
          end
          offset = @out.bytesize
          name_bytes = name.b
          @out << [0x04034b50, 20, 0x0800, method, @dos_time, @dos_date, crc, body.bytesize, data.bytesize, name_bytes.bytesize, 0].pack('VvvvvvVVVvv')
          @out << name_bytes << body
          @entries << {name: name_bytes, crc: crc, csize: body.bytesize, size: data.bytesize, method: method, offset: offset}
        end

        def to_s
          directory_start = @out.bytesize
          directory = String.new(encoding: Encoding::BINARY)
          @entries.each do |e|
            directory << [0x02014b50, 20, 20, 0x0800, e[:method], @dos_time, @dos_date, e[:crc], e[:csize], e[:size], e[:name].bytesize, 0, 0, 0, 0, 0, e[:offset]].pack('VvvvvvvVVVvvvvvVV')
            directory << e[:name]
          end
          @out + directory + [0x06054b50, 0, 0, @entries.size, @entries.size, directory.bytesize, directory_start, 0].pack('VvvvvVVv')
        end
      end

      # Danh sách kiểu ô (phông, màu nền, viền, định dạng số, căn lề): mỗi tổ hợp dùng chung một chỉ số trong styles.xml.
      class Styles
        # Phông 0 là phông gốc của file (Calibri 11): Excel lấy độ rộng một chữ số của phông này làm đơn vị độ rộng cột (7 px).
        FONTS = [
          '<font><sz val="11"/><color rgb="FF222222"/><name val="Calibri"/><family val="2"/></font>',
          '<font><sz val="10"/><color rgb="FF222222"/><name val="Calibri"/><family val="2"/></font>',                      # 1 thường
          '<font><b/><sz val="10"/><color rgb="FF222222"/><name val="Calibri"/><family val="2"/></font>',                  # 2 đậm
          '<font><b/><sz val="15"/><color rgb="FF222222"/><name val="Calibri"/><family val="2"/></font>',                  # 3 tiêu đề
          '<font><i/><sz val="9"/><color rgb="FF6B6B6B"/><name val="Calibri"/><family val="2"/></font>',                   # 4 ghi chú
          '<font><u/><sz val="10"/><color rgb="FF0563C1"/><name val="Calibri"/><family val="2"/></font>'                   # 5 liên kết
        ].freeze
        FONT_NORMAL, FONT_BOLD, FONT_TITLE, FONT_NOTE, FONT_LINK = 1, 2, 3, 4, 5
        FILLS = [
          '<fill><patternFill patternType="none"/></fill>',
          '<fill><patternFill patternType="gray125"/></fill>',
          '<fill><patternFill patternType="solid"><fgColor rgb="FFE8DCCB"/><bgColor indexed="64"/></patternFill></fill>',  # 2 tiêu đề cột, dòng tổng
          '<fill><patternFill patternType="solid"><fgColor rgb="FFF4EEE6"/><bgColor indexed="64"/></patternFill></fill>'   # 3 dòng nhóm
        ].freeze
        EDGE = '<color rgb="FFBFBFBF"/>'.freeze
        BORDERS = [
          '<border><left/><right/><top/><bottom/><diagonal/></border>',
          "<border><left style=\"thin\">#{EDGE}</left><right style=\"thin\">#{EDGE}</right><top style=\"thin\">#{EDGE}</top><bottom style=\"thin\">#{EDGE}</bottom><diagonal/></border>",
          "<border><left style=\"thin\">#{EDGE}</left><right style=\"thin\">#{EDGE}</right><top style=\"medium\"><color rgb=\"FF222222\"/></top><bottom style=\"thin\">#{EDGE}</bottom><diagonal/></border>"
        ].freeze
        FIRST_CUSTOM_FORMAT = 164

        def initialize
          @formats = {}  # mã định dạng số => id
          @xfs = []      # từng tổ hợp
          @index = {}
          xf # kiểu 0: mặc định (Excel yêu cầu có sẵn)
        end

        def xf(font: FONT_NORMAL, fill: 0, border: 0, format: nil, h: nil, v: 'center', wrap: false)
          key = [font, fill, border, format, h, v, wrap]
          @index[key] ||= begin
            format_id = format ? (@formats[format] ||= FIRST_CUSTOM_FORMAT + @formats.size) : 0
            @xfs << {font: font, fill: fill, border: border, format_id: format_id, h: h, v: v, wrap: wrap}
            @xfs.size - 1
          end
        end

        def to_xml
          formats = @formats.map { |code, id| "<numFmt numFmtId=\"#{id}\" formatCode=\"#{CGI.escapeHTML(code)}\"/>" }.join
          xfs = @xfs.map do |s|
            align = %(<alignment#{s[:h] ? %( horizontal="#{s[:h]}") : ''} vertical="#{s[:v]}"#{s[:wrap] ? ' wrapText="1"' : ''}/>)
            %(<xf numFmtId="#{s[:format_id]}" fontId="#{s[:font]}" fillId="#{s[:fill]}" borderId="#{s[:border]}" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">#{align}</xf>)
          end.join
          %(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<styleSheet xmlns="#{NS_MAIN}">) +
            (@formats.empty? ? '' : %(<numFmts count="#{@formats.size}">#{formats}</numFmts>)) +
            %(<fonts count="#{FONTS.size}">#{FONTS.join}</fonts><fills count="#{FILLS.size}">#{FILLS.join}</fills><borders count="#{BORDERS.size}">#{BORDERS.join}</borders>) +
            %(<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="#{@xfs.size}">#{xfs}</cellXfs>) +
            %(<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>)
        end
      end

      def self.write(path, report)
        File.binwrite(path, build(report))
      end

      # Trả về nội dung file .xlsx (chuỗi nhị phân).
      def self.build(report)
        columns = report[:columns]
        styles = Styles.new
        image_col = columns.index { |c| c[:type] == 'image' }
        units_row = columns.any? { |c| !c[:unit].to_s.empty? }
        header_row = META_ROW + 2 # sau tiêu đề, ghi chú và một dòng trống
        first_data = header_row + (units_row ? 2 : 1)

        sheet_rows = []
        sheet_rows << row_xml(TITLE_ROW, [text_cell(TITLE_ROW, 0, report[:title], styles.xf(font: Styles::FONT_TITLE))])
        sheet_rows << row_xml(META_ROW, [text_cell(META_ROW, 0, report[:meta], styles.xf(font: Styles::FONT_NOTE))])
        head_style = styles.xf(font: Styles::FONT_BOLD, fill: 2, border: 1, h: 'center', wrap: true)
        sheet_rows << row_xml(header_row, columns.each_with_index.map { |c, i| text_cell(header_row, i, c[:label], head_style) })
        if units_row
          unit_style = styles.xf(font: Styles::FONT_NOTE, fill: 2, border: 1, h: 'center')
          sheet_rows << row_xml(header_row + 1, columns.each_with_index.map { |c, i| text_cell(header_row + 1, i, c[:unit], unit_style) })
        end

        media = {}      # pid => số thứ tự ảnh
        pictures = []   # {pid, col, row, w, h, dx, dy} (px)
        hyperlinks = []
        image_px = image_col ? column_px(IMAGE_COLUMN_CHARS) : 0
        row_number = first_data - 1
        report[:rows].each do |row|
          row_number += 1
          cells = []
          height = nil
          columns.each_with_index do |col, i|
            value = row[:cells][i]
            base = {border: row[:kind] == 'total' ? 2 : 1, fill: row[:kind] == 'row' ? 0 : (row[:kind] == 'group' ? 3 : 2), font: row[:kind] == 'row' ? Styles::FONT_NORMAL : Styles::FONT_BOLD}
            if col[:type] == 'image'
              cells << blank_cell(row_number, i, styles.xf(**base))
              image = row[:images] && row[:images][i]
              next unless image
              media[image[:key]] ||= media.size + 1
              fit = fit_image(image[:width], image[:height])
              pictures << {pid: image[:key], col: i, row: row_number - 1, w: fit[0], h: fit[1], dx: [(image_px - fit[0]) / 2, 0].max, dy: [(row_px(IMAGE_ROW_POINTS) - fit[1]) / 2, 0].max}
              height = IMAGE_ROW_POINTS
            elsif value.is_a?(Numeric) && col[:type] == 'ordinal'
              cells << number_cell(row_number, i, value, styles.xf(**base, h: 'center'))
            elsif value.is_a?(Numeric)
              cells << number_cell(row_number, i, value, styles.xf(**base, format: number_format(col[:digits]), h: 'right'))
            elsif col[:type] == 'link' && row[:kind] == 'row' && !value.to_s.empty? && value.to_s.match?(%r{\Ahttps?://}i)
              cells << text_cell(row_number, i, value, styles.xf(**base, font: Styles::FONT_LINK, h: 'left'))
              hyperlinks << {ref: "#{column_letter(i)}#{row_number}", url: value.to_s}
            else
              cells << (value.to_s.empty? ? blank_cell(row_number, i, styles.xf(**base)) : text_cell(row_number, i, value, styles.xf(**base, wrap: col[:type] == 'text', h: col[:type] == 'ordinal' ? 'center' : 'left')))
            end
          end
          height = IMAGE_ROW_POINTS if image_col && height.nil? && row[:kind] == 'row'
          sheet_rows << row_xml(row_number, cells, height)
        end
        last_row = [row_number, first_data].max

        zip = Zip.new
        sheet_name = sheet_name(report[:title])
        has_pictures = !pictures.empty?
        zip.add('[Content_Types].xml', content_types_xml(has_pictures))
        zip.add('_rels/.rels', rels_xml([['rId1', 'officeDocument', 'xl/workbook.xml']]))
        zip.add('xl/workbook.xml', workbook_xml(sheet_name, header_row, header_row + (units_row ? 1 : 0)))
        zip.add('xl/_rels/workbook.xml.rels', rels_xml([['rId1', 'worksheet', 'worksheets/sheet1.xml'], ['rId2', 'styles', 'styles.xml']]))
        zip.add('xl/styles.xml', styles.to_xml)
        zip.add('xl/worksheets/sheet1.xml', sheet_xml(report, columns, sheet_rows, header_row, first_data, last_row, hyperlinks, has_pictures))
        sheet_rels = []
        hyperlinks.each_with_index { |h, i| sheet_rels << ["rId#{i + 1}", 'hyperlink', h[:url], true] }
        sheet_rels << ["rId#{hyperlinks.size + 1}", 'drawing', '../drawings/drawing1.xml'] if has_pictures
        zip.add('xl/worksheets/_rels/sheet1.xml.rels', rels_xml(sheet_rels)) unless sheet_rels.empty?
        if has_pictures
          zip.add('xl/drawings/drawing1.xml', drawing_xml(pictures, media))
          zip.add('xl/drawings/_rels/drawing1.xml.rels', rels_xml(media.map { |pid, n| ["rId#{n}", 'image', "../media/image#{n}.png"] }))
          media.each { |pid, n| zip.add("xl/media/image#{n}.png", report[:images].fetch(pid)[:bytes], compress: false) }
        end
        zip.to_s
      end

      def self.fit_image(width, height)
        scale = [IMAGE_BOX_PX[0].to_f / width, IMAGE_BOX_PX[1].to_f / height, 1.0].min
        [[(width * scale).round, 1].max, [(height * scale).round, 1].max]
      end

      # Độ rộng cột theo nội dung: chữ ngắn thì gọn, dài thì tối đa 45 ký tự rồi xuống dòng.
      def self.column_chars(report, index)
        col = report[:columns][index]
        return 6 if col[:type] == 'ordinal'
        return IMAGE_COLUMN_CHARS if col[:type] == 'image'
        longest = report[:rows].map { |row| value = row[:cells][index]; value.is_a?(Numeric) ? 14 : value.to_s.length }.max.to_i
        header = [col[:label].to_s.length, col[:unit].to_s.length].max
        return 14 if col[:type] == 'number' && header <= 14
        [[longest, header * 0.75 + 2].max + 2, 10].max.clamp(10, col[:type] == 'link' ? 36 : 45).to_f
      end

      def self.column_px(chars)
        (chars * 7 + 5).truncate
      end

      def self.row_px(points)
        (points * 96 / 72.0).round
      end

      def self.number_format(digits)
        digits.to_i.zero? ? '#,##0' : "#,##0.#{'0' * digits.to_i}"
      end

      def self.column_letter(index)
        letters = +''
        index += 1
        while index > 0
          index, rest = (index - 1).divmod(26)
          letters.prepend((65 + rest).chr)
        end
        letters
      end

      def self.sheet_name(title)
        name = title.to_s.gsub(%r{[\[\]:*?/\\]}, ' ').strip[0, 31].to_s
        name.empty? ? 'Bang khoi luong' : name
      end

      # Bỏ ký tự điều khiển (XML không cho phép) rồi mã hóa &, <, >, ".
      def self.xml_text(value)
        CGI.escapeHTML(value.to_s.encode('UTF-8').gsub(/[\u0000-\u0008\u000B\u000C\u000E-\u001F￾￿]/, ''))
      end

      def self.text_cell(row, col, value, style)
        %(<c r="#{column_letter(col)}#{row}" s="#{style}" t="inlineStr"><is><t xml:space="preserve">#{xml_text(value)}</t></is></c>)
      end

      def self.blank_cell(row, col, style)
        %(<c r="#{column_letter(col)}#{row}" s="#{style}"/>)
      end

      def self.number_cell(row, col, value, style)
        number = value.is_a?(Integer) ? value.to_s : format('%.12g', value.to_f)
        %(<c r="#{column_letter(col)}#{row}" s="#{style}"><v>#{number}</v></c>)
      end

      def self.row_xml(number, cells, height = nil)
        %(<row r="#{number}"#{height ? %( ht="#{height}" customHeight="1") : ''}>#{cells.join}</row>)
      end

      def self.sheet_xml(report, columns, rows, header_row, first_data, last_row, hyperlinks, has_pictures)
        cols = columns.each_index.map { |i| %(<col min="#{i + 1}" max="#{i + 1}" width="#{format('%.2f', column_chars(report, i))}" customWidth="1"/>) }.join
        frozen_rows = header_row + (columns.any? { |c| !c[:unit].to_s.empty? } ? 1 : 0)
        links = hyperlinks.empty? ? '' : "<hyperlinks>#{hyperlinks.each_with_index.map { |h, i| %(<hyperlink ref="#{h[:ref]}" r:id="rId#{i + 1}"/>) }.join}</hyperlinks>"
        drawing = has_pictures ? %(<drawing r:id="rId#{hyperlinks.size + 1}"/>) : ''
        %(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<worksheet xmlns="#{NS_MAIN}" xmlns:r="#{NS_REL}">) +
          %(<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr><dimension ref="A1:#{column_letter(columns.size - 1)}#{last_row}"/>) +
          %(<sheetViews><sheetView workbookViewId="0" showGridLines="0"><pane ySplit="#{frozen_rows}" topLeftCell="A#{frozen_rows + 1}" activePane="bottomLeft" state="frozen"/><selection pane="bottomLeft"/></sheetView></sheetViews>) +
          %(<sheetFormatPr defaultRowHeight="15"/><cols>#{cols}</cols><sheetData>#{rows.join}</sheetData>#{links}) +
          %(<pageMargins left="0.4" right="0.4" top="0.5" bottom="0.5" header="0.3" footer="0.3"/><pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/>#{drawing}</worksheet>)
      end

      def self.workbook_xml(sheet_name, title_first_row, title_last_row)
        quoted = "'#{sheet_name.gsub("'", "''")}'"
        %(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<workbook xmlns="#{NS_MAIN}" xmlns:r="#{NS_REL}"><bookViews><workbookView/></bookViews>) +
          %(<sheets><sheet name="#{xml_text(sheet_name)}" sheetId="1" r:id="rId1"/></sheets>) +
          %(<definedNames><definedName name="_xlnm.Print_Titles" localSheetId="0">#{xml_text(quoted)}!$#{title_first_row}:$#{title_last_row}</definedName></definedNames></workbook>)
      end

      def self.content_types_xml(has_pictures)
        overrides = [['/xl/workbook.xml', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml'],
                     ['/xl/worksheets/sheet1.xml', 'application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml'],
                     ['/xl/styles.xml', 'application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml']]
        overrides << ['/xl/drawings/drawing1.xml', 'application/vnd.openxmlformats-officedocument.drawing+xml'] if has_pictures
        %(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">) +
          %(<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/>) +
          overrides.map { |part, type| %(<Override PartName="#{part}" ContentType="#{type}"/>) }.join + '</Types>'
      end

      # relations: [id, loại, đích, (true nếu đích nằm ngoài file)]
      def self.rels_xml(relations)
        items = relations.map do |id, type, target, external|
          %(<Relationship Id="#{id}" Type="#{REL_BASE}/#{type}" Target="#{xml_text(target)}"#{external ? ' TargetMode="External"' : ''}/>)
        end
        %(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Relationships xmlns="#{NS_PKG_REL}">#{items.join}</Relationships>)
      end

      def self.drawing_xml(pictures, media)
        anchors = pictures.each_with_index.map do |pic, i|
          %(<xdr:oneCellAnchor><xdr:from><xdr:col>#{pic[:col]}</xdr:col><xdr:colOff>#{pic[:dx] * PX_TO_EMU}</xdr:colOff><xdr:row>#{pic[:row]}</xdr:row><xdr:rowOff>#{pic[:dy] * PX_TO_EMU}</xdr:rowOff></xdr:from>) +
            %(<xdr:ext cx="#{pic[:w] * PX_TO_EMU}" cy="#{pic[:h] * PX_TO_EMU}"/><xdr:pic><xdr:nvPicPr><xdr:cNvPr id="#{i + 2}" name="Anh #{i + 1}"/><xdr:cNvPicPr><a:picLocks noChangeAspect="1"/></xdr:cNvPicPr></xdr:nvPicPr>) +
            %(<xdr:blipFill><a:blip r:embed="rId#{media.fetch(pic[:pid])}"/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill>) +
            %(<xdr:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="#{pic[:w] * PX_TO_EMU}" cy="#{pic[:h] * PX_TO_EMU}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr></xdr:pic><xdr:clientData/></xdr:oneCellAnchor>)
        end
        %(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="#{NS_REL}">#{anchors.join}</xdr:wsDr>)
      end
    end
  end
end
