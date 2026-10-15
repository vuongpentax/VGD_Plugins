module VGD
  module BIM
    module Schema
      DICTIONARY = 'VGD_BIM'.freeze
      FIELDS = %i[schema_version category item_type code description unit quantity_method zone floor include_boq finish_code manufacturer model_number note].freeze
      CATEGORIES = %w[architecture finish furniture electrical equipment plumbing hvac other].freeze
      UNITS = %w[m2 m m3 pcs set lot kg none].freeze
      METHODS = %w[area length volume count assembly manual].freeze
      DEFAULTS = FIELDS.each_with_object({}) { |key, h| h[key] = '' }.merge(schema_version: 1, include_boq: true).freeze
      def self.normalize(hash)
        hash.each_with_object({}) do |(key, value), result|
          key = key.to_sym
          raise ArgumentError, "Trường dữ liệu không hợp lệ: #{key}" unless FIELDS.include?(key)
          if key == :include_boq
            raise ArgumentError, 'Mục đưa vào bảng khối lượng phải là Có hoặc Không.' unless value == true || value == false
          elsif key == :schema_version
            raise ArgumentError, 'Phiên bản dữ liệu chưa được hỗ trợ.' unless value == 1
          else
            raise ArgumentError, "#{Locale.field(key)} phải là văn bản." unless value.is_a?(String)
            value = value.strip
          end
          allowed = {category: CATEGORIES, unit: UNITS, quantity_method: METHODS}[key]
          raise ArgumentError, "Giá trị #{Locale.field(key)} không hợp lệ: #{value}" if allowed && !value.empty? && !allowed.include?(value)
          result[key] = value
        end
      end
    end
  end
end
