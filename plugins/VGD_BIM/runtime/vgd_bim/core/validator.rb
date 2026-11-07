module VGD
  module BIM
    module Validator
      def self.inspect_entity(entity)
        return [{severity: 'INFO', message: 'Đối tượng không còn tồn tại'}] unless entity.valid?
        return [{severity: 'INFO', message: 'Chưa phân loại'}] unless Data.has_data?(entity)
        data = Data.read(entity)
        issues = []
        add = lambda { |level, text, code = nil| issues << {severity: level, message: text, code: code} }
        add.call('ERROR', 'Phiên bản dữ liệu chưa được hỗ trợ') unless data[:schema_version] == 1
        add.call('ERROR', 'Mục đưa vào bảng khối lượng phải là Có hoặc Không') unless [true, false].include?(data[:include_boq])
        (Schema::FIELDS - %i[schema_version include_boq]).each { |key| add.call('ERROR', "#{Locale.field(key)} phải là văn bản") unless data[key].is_a?(String) }
        if data[:include_boq] == true
          %i[category item_type description unit quantity_method].each { |key| add.call('ERROR', "Thiếu #{Locale.field(key).downcase}", 'missing') if data[key].to_s.strip.empty? }
        end
        {category: Schema::CATEGORIES, unit: Schema::UNITS, quantity_method: Schema::METHODS}.each do |key, allowed|
          add.call('ERROR', "#{Locale.field(key)} không hợp lệ") unless data[key].to_s.empty? || allowed.include?(data[key])
        end
        expected = {'area' => ['m2'], 'length' => ['m'], 'volume' => ['m3'], 'count' => %w[pcs set lot]}[data[:quantity_method]]
        add.call('ERROR', "#{Locale.label('quantity_method', data[:quantity_method])} cần đơn vị #{expected.map { |unit| Locale.label('unit', unit) }.join(' / ')}") if expected && !expected.include?(data[:unit])
        add.call('WARNING', 'Chưa nhập mã hạng mục') if data[:include_boq] && data[:code].to_s.empty?
        add.call('INFO', 'Chưa gán khu vực / phòng') if data[:zone].to_s.empty?
        issues
      rescue StandardError => error
        BIM.log("Validation failed: #{error.message}")
        [{severity: 'ERROR', message: 'Không đọc được dữ liệu BIM'}]
      end
      def self.validate(records)
        records.select { |r| Data.supported?(r[:entity]) }.map do |record|
          issues = inspect_entity(record[:entity])
          errors = issues.select { |i| i[:severity] == 'ERROR' }
          status = if !Data.has_data?(record[:entity])
                     'UNCLASSIFIED'
                   elsif errors.empty?
                     'VGD READY'
                   elsif errors.all? { |i| i[:code] == 'missing' }
                     'INCOMPLETE'
                   else
                     'ERROR'
                   end
          record.merge(issues: issues, status: status)
        end
      end
      def self.selection; validate(Scanner.scan_selection); end
      def self.model; validate(Scanner.scan_model); end
    end
  end
end
