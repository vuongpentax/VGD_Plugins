require 'json'
require 'securerandom'

module VGD
  module BIM
    # Tầng (Level) của công trình: danh sách lưu trong chính file SketchUp (dictionary VGD_BIM_MODEL, khóa `levels`, JSON), mỗi tầng có
    # id ổn định (lv_xxxxxxxx), tên, cao độ sàn và chiều cao tầng (mm). Món được gán tầng bằng id, lưu ở dictionary riêng VGD_BIM_LOC của món
    # (khóa `level`, không đụng VGD_BIM). Gán tầng chỉ là NHÃN: không dời hình học. Xem docs/vgd_bim/ROADMAP.md cột mốc 2a.
    module Levels
      DICTIONARY = 'VGD_BIM_MODEL'.freeze
      KEY = 'levels'.freeze
      ENTITY_DICTIONARY = 'VGD_BIM_LOC'.freeze
      ENTITY_KEY = 'level'.freeze
      MAX_LEVELS = 50
      MAX_NAME = 60
      ELEVATION_RANGE = (-50_000..500_000).freeze # mm
      MAX_HEIGHT = 100_000                        # mm
      TOLERANCE = 50                              # mm: món đặt hơi thấp hơn cao độ sàn vẫn thuộc tầng đó
      ID_PATTERN = /\Alv_[0-9a-f]{8}\z/
      CONTROL = /[\u0000-\u001f\u007f]/

      # Kiểm tra danh sách tầng (dữ liệu từ giao diện hoặc file); trả về danh sách sạch, mỗi tầng có id, sắp theo cao độ.
      def self.sanitize!(list)
        raise ArgumentError, 'Danh sách tầng không hợp lệ.' unless list.is_a?(Array)
        raise ArgumentError, "Chỉ có tối đa #{MAX_LEVELS} tầng." if list.size > MAX_LEVELS
        seen = {}
        clean = list.map do |item|
          raise ArgumentError, 'Danh sách tầng không hợp lệ.' unless item.is_a?(Hash)
          name = item['name'].is_a?(String) ? item['name'].strip : ''
          raise ArgumentError, "Hãy nhập tên tầng (tối đa #{MAX_NAME} ký tự, không có ký tự điều khiển)." if name.empty? || name.length > MAX_NAME || name.match?(CONTROL)
          raise ArgumentError, "Tên tầng trùng nhau: #{name}." if seen[name.downcase]
          seen[name.downcase] = true
          elevation = item['elevation']
          raise ArgumentError, "Giá trị cao độ của #{name} phải là số từ #{ELEVATION_RANGE.first} đến #{ELEVATION_RANGE.last} mm." unless elevation.is_a?(Numeric) && elevation.finite? && ELEVATION_RANGE.cover?(elevation)
          height = item['height']
          raise ArgumentError, "Giá trị chiều cao của #{name} phải là số lớn hơn 0 và không quá #{MAX_HEIGHT} mm." unless height.is_a?(Numeric) && height.finite? && height.positive? && height <= MAX_HEIGHT
          id = item['id']
          raise ArgumentError, 'Mã tầng không hợp lệ.' unless id.nil? || (id.is_a?(String) && id.match?(ID_PATTERN))
          {'id' => id || "lv_#{SecureRandom.hex(4)}", 'name' => name, 'elevation' => elevation.round(1).to_f, 'height' => height.round(1).to_f}
        end
        clean.sort_by { |level| [level['elevation'], level['name'].downcase] }
      end

      # Tầng đã lưu trong model; dữ liệu hỏng thì coi như chưa có (không đoán).
      def self.read(model)
        return [] unless model.respond_to?(:get_attribute)
        raw = model.get_attribute(DICTIONARY, KEY).to_s
        return [] if raw.empty?
        sanitize!(JSON.parse(raw))
      rescue JSON::ParserError, ArgumentError
        []
      end

      # Ghi danh sách tầng trong thao tác trong suốt (gộp vào bước hoàn tác trước). Không đổi gì thì không đụng model.
      def self.write(model, list)
        return false unless model.respond_to?(:set_attribute) && model.respond_to?(:start_operation)
        clean = sanitize!(list)
        return true if clean == read(model)
        model.start_operation('VGD_BIM · Tầng', true, false, true)
        begin
          model.set_attribute(DICTIONARY, KEY, JSON.generate(clean))
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end
        true
      end

      # Tầng theo cao độ Z (mm, theo thế giới) của đáy món: tầng cao nhất có cao độ sàn <= z + dung sai; thấp hơn mọi tầng thì không gợi ý.
      def self.for_z(levels, z)
        return nil unless z.is_a?(Numeric) && z.finite?
        found = levels.select { |level| level['elevation'] <= z + TOLERANCE }.max_by { |level| level['elevation'] }
        found && found['id']
      end

      def self.entity_level(entity)
        return '' unless entity.respond_to?(:get_attribute)
        value = entity.get_attribute(ENTITY_DICTIONARY, ENTITY_KEY)
        value.is_a?(String) && value.match?(ID_PATTERN) ? value : ''
      end

      # Gán tầng cho món (id rỗng = bỏ tầng). Gọi trong một thao tác của người gọi (Data.transaction).
      def self.assign(entity, id)
        raise ArgumentError, 'Mã tầng không hợp lệ.' unless id.is_a?(String) && (id.empty? || id.match?(ID_PATTERN))
        raise ArgumentError, 'Đối tượng không hỗ trợ gán tầng.' unless entity.respond_to?(:set_attribute) && entity.respond_to?(:locked?)
        raise ArgumentError, 'Đối tượng đang bị khóa.' if entity.locked?
        id.empty? ? entity.delete_attribute(ENTITY_DICTIONARY, ENTITY_KEY) : entity.set_attribute(ENTITY_DICTIONARY, ENTITY_KEY, id)
      end

      # items: [{index:, z:, locked:}]. Gán theo cao độ: món gán được, món khóa, món không gợi ý được.
      def self.plan_auto(items, levels)
        plan = {assign: {}, locked: [], none: []}
        items.each do |item|
          if item[:locked] then plan[:locked] << item[:index]
          elsif (id = for_z(levels, item[:z])) then plan[:assign][item[:index]] = id
          else plan[:none] << item[:index]
          end
        end
        plan
      end
    end
  end
end
