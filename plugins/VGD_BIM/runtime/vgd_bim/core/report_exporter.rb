require 'csv'
module VGD
  module BIM
    module ReportExporter
      NAMES = {'bim' => 'Danh_muc_doi_tuong', 'components' => 'Thong_ke_thanh_phan', 'materials' => 'Dien_tich_vat_lieu', 'validation' => 'Ket_qua_kiem_tra'}.freeze
      def self.build(kind, records, model = Sketchup.active_model)
        valid = records.select { |r| r[:entity].valid? }
        case kind
        when 'bim'
          headers = ['STT', 'Đường dẫn trong mô hình', 'Tên đối tượng', 'Tên định nghĩa', 'Nguồn dữ liệu'] + (Schema::FIELDS - [:schema_version]).map { |key| Locale.field(key) } + ['Rộng (mm)', 'Sâu (mm)', 'Cao (mm)', 'Trạng thái']
          rows = valid.select { |r| Data.supported?(r[:entity]) }.each_with_index.map do |r, i|
            e = r[:entity]; data = Data.read(e); raw = RawScanner.identity(e)
            [i + 1, path_name(r), raw[:instance_name], raw[:definition_name], Locale.label('source', Data.source(e))] +
              (Schema::FIELDS - [:schema_version]).map { |key| Locale.value(key, data[key]) } +
              Geometry.dimensions(e, r[:transform]).values + [Locale.label('status', Validator.validate([r]).first[:status])]
          end
        when 'components'
          headers = ['Tên định nghĩa', 'Tên đối tượng', 'Số lần xuất hiện', 'Thẻ', 'Vật liệu', 'Rộng mẫu (mm)', 'Sâu mẫu (mm)', 'Cao mẫu (mm)', 'Số biến thể kích thước']
          rows = RawScanner.report(valid, model)[:components].map { |r| [r[:definition_name], r[:names].join(' / '), r[:instances], r[:tags].join(' / '), r[:material]] + r[:dimensions].values + [r[:dimension_variants]] }
        when 'materials'
          headers = ['Vật liệu', 'Diện tích mặt trước (m²)', 'Diện tích mặt sau có sơn (m²)', 'Số mặt trước', 'Loại báo cáo']
          rows = RawScanner.report(valid, model)[:materials].map { |r| [r[:material] == '(Unpainted)' ? 'Chưa có vật liệu' : r[:material], r[:area], r[:back_area], r[:faces], 'Khối lượng hình học gốc; chưa phải bảng khối lượng báo giá'] }
        when 'validation'
          headers = ['Đường dẫn trong mô hình', 'Tên đối tượng', 'Trạng thái', 'Mức độ', 'Nội dung kiểm tra']
          rows = Validator.validate(valid).flat_map do |r|
            issues = r[:issues].empty? ? [{severity: 'INFO', message: 'Thông tin hợp lệ'}] : r[:issues]
            issues.map { |issue| [path_name(r), r[:entity].name, Locale.label('status', r[:status]), Locale.label('status', issue[:severity]), issue[:message]] }
          end
        else
          raise ArgumentError, 'Loại báo cáo không hợp lệ.'
        end
        {headers: headers, rows: rows}
      end
      def self.path_name(record)
        record[:path].select { |e| Data.supported?(e) }.map do |e|
          name = e.name.to_s.empty? ? Geometry.definition(e).name.to_s : e.name.to_s
          name.empty? ? 'Chưa đặt tên' : name
        end.join(' / ')
      end
      def self.cell(value)
        return value.round(3).to_s.tr('.', ',') if value.is_a?(Float)
        return value if value.is_a?(Numeric)
        string = value.to_s
        # Model names are untrusted spreadsheet text, never formulas.
        string = "'#{string}" if string.match?(/\A[\s\uFEFF]*[=+@-]/)
        string
      end
      def self.write(path, kind, records, model = Sketchup.active_model)
        report = build(kind, records, model)
        contents = CSV.generate(col_sep: ';', row_sep: "\r\n") do |csv|
          csv << report[:headers]
          report[:rows].each { |row| csv << row.map { |value| cell(value) } }
        end
        File.open(path, 'wb') { |file| file.write("\xEF\xBB\xBF".b); file.write(contents.encode('UTF-8')) }
        report[:rows].size
      end
    end
  end
end
