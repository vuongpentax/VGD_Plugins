require 'json'
require 'csv'
require_relative 'storage'

module VGD
  module BIM
    # Bộ tag do từng người dùng soạn. Lưu trên máy (file JSON, xem Storage),
    # không nằm trong file model. Tag gán vào đối tượng là tag (layer) của SketchUp.
    # Tag chỉ là nhãn phân loại: không có đơn vị. Khối lượng được tính theo hình học
    # của đối tượng (mặt → m², khối kín → m³, group / component → số lượng).
    module Tags
      SECTION = 'VGD_BIM'.freeze
      KEY = 'tag_set'.freeze
      MAX_NAME = 60
      GROUPS = ['Phần thô', 'Hoàn thiện', 'Đồ rời', 'Thiết bị', 'Khác'].freeze
      # Bộ mẫu ban đầu. Người dùng sửa, thêm, xóa theo quy ước của mình.
      DEFAULT_SET = [
        {'name' => 'Tường 100', 'group' => 'Phần thô'},
        {'name' => 'Tường 200', 'group' => 'Phần thô'},
        {'name' => 'Cột', 'group' => 'Phần thô'},
        {'name' => 'Dầm', 'group' => 'Phần thô'},
        {'name' => 'Sàn bê tông', 'group' => 'Phần thô'},
        {'name' => 'Trần', 'group' => 'Hoàn thiện'},
        {'name' => 'Sơn 1 lớp', 'group' => 'Hoàn thiện'},
        {'name' => 'Sơn 2 lớp', 'group' => 'Hoàn thiện'},
        {'name' => 'Gạch ốp lát', 'group' => 'Hoàn thiện'},
        {'name' => 'Cửa', 'group' => 'Hoàn thiện'},
        {'name' => 'Nội thất', 'group' => 'Đồ rời'},
        {'name' => 'Thiết bị', 'group' => 'Thiết bị'}
      ].freeze

      # Khóa so sánh: bỏ khoảng trắng thừa, không phân biệt chữ hoa chữ thường.
      def self.key(name)
        name.to_s.strip.gsub(/\s+/, ' ').downcase(:fold)
      end

      def self.load
        raw = Storage.read('tag_set', SECTION, KEY)
        return DEFAULT_SET.map(&:dup) if raw.nil?
        validate(raw)
      rescue JSON::ParserError, ArgumentError => error
        BIM.log("Tag set invalid, using defaults: #{error.message}")
        DEFAULT_SET.map(&:dup)
      end

      def self.save(list)
        clean = validate(list)
        Storage.write('tag_set', clean)
        clean
      end

      def self.validate(list)
        raise ArgumentError, 'Bộ tag phải là một danh sách.' unless list.is_a?(Array)
        seen = {}
        list.map do |item|
          raise ArgumentError, 'Mỗi tag phải là một mục hợp lệ.' unless item.is_a?(Hash)
          name = item['name'].to_s.strip.gsub(/\s+/, ' ')
          raise ArgumentError, 'Tên tag không được để trống.' if name.empty?
          raise ArgumentError, "Tên tag quá dài (tối đa #{MAX_NAME} ký tự): #{name}" if name.length > MAX_NAME
          raise ArgumentError, 'Tên "Untagged" là tên mặc định của SketchUp, hãy chọn tên khác.' if key(name) == 'untagged'
          group = item['group'].to_s
          raise ArgumentError, "Nhóm không hợp lệ: #{group}" unless GROUPS.include?(group)
          k = key(name)
          raise ArgumentError, "Tên tag bị trùng: #{name}" if seen[k]
          seen[k] = true
          {'name' => name, 'group' => group}
        end
      end

      HEADERS = ['Tên tag', 'Nhóm'].freeze

      # Ô bắt đầu bằng = + - @ có thể bị Excel hiểu thành công thức, nên thêm dấu nháy đơn phía trước.
      def self.escape_cell(value)
        text = value.to_s
        text.match?(/\A[=+\-@]/) ? "'#{text}" : text
      end
      def self.unescape_cell(value)
        text = value.to_s.strip
        text.match?(/\A'[=+\-@]/) ? text[1..-1] : text
      end

      def self.to_csv(list)
        body = CSV.generate(col_sep: ';', row_sep: "\r\n") do |csv|
          csv << HEADERS
          list.each { |tag| csv << [escape_cell(tag['name']), escape_cell(tag['group'])] }
        end
        "﻿#{body}"
      end

      # Cột "Đơn vị" trong file cũ (nếu có) được bỏ qua.
      def self.from_csv(text)
        raise ArgumentError, 'File này là Excel (.xlsx). Hãy lưu lại dưới dạng CSV UTF-8 rồi nhập lại.' if text.start_with?('PK')
        text = text.sub(/\A﻿/, '')
        first_line = text.each_line.first.to_s
        separator = first_line.count(';') > first_line.count(',') ? ';' : ','
        rows = CSV.parse(text, col_sep: separator, skip_blanks: true)
        raise ArgumentError, 'File không có dữ liệu.' if rows.empty?
        header = rows.shift.map { |cell| unescape_cell(cell).downcase }
        aliases = {'name' => ['tên tag', 'ten tag', 'name'], 'group' => ['nhóm', 'nhom', 'group']}
        index = aliases.transform_values { |names| header.index { |h| names.include?(h) } }
        raise ArgumentError, 'Thiếu cột "Tên tag" trong file.' unless index['name']
        items = []
        rows.each_with_index do |row, i|
          name = unescape_cell(row[index['name']])
          next if name.empty?
          group = index['group'] ? unescape_cell(row[index['group']]) : ''
          group = 'Khác' if group.empty?
          begin
            items.concat(validate([{'name' => name, 'group' => group}]))
          rescue ArgumentError => error
            raise ArgumentError, "Dòng #{i + 2}: #{error.message}"
          end
        end
        raise ArgumentError, 'File không có tag nào.' if items.empty?
        validate(items)
      end

      def self.to_json(list)
        JSON.pretty_generate({'format' => 'VGD_BIM_TAGS', 'version' => 2, 'tags' => list.map { |t| {'name' => t['name'], 'group' => t['group']} }})
      end
      def self.from_json(text)
        data = JSON.parse(text)
        data = data['tags'] if data.is_a?(Hash)
        items = validate(data)
        raise ArgumentError, 'File JSON không có tag nào.' if items.empty?
        items
      rescue JSON::ParserError
        raise ArgumentError, 'File JSON không đúng định dạng.'
      end

      # Gộp: tag trùng tên (không phân biệt hoa thường) lấy từ bộ nhập, còn lại giữ nguyên.
      def self.merge(current, incoming)
        keys = incoming.map { |tag| key(tag['name']) }
        current.reject { |tag| keys.include?(key(tag['name'])) } + incoming
      end

      # Tìm tag đã có trong model, so sánh không phân biệt chữ hoa chữ thường.
      def self.find_layer(model, name)
        model.layers.to_a.find { |layer| key(layer.name) == key(name) }
      end

      # Tên tag dùng để gán: bỏ khoảng trắng thừa, từ chối tên rỗng và "Untagged".
      def self.normalize_name(name)
        target = name.to_s.strip.gsub(/\s+/, ' ')
        raise ArgumentError, 'Hãy chọn một tag.' if target.empty?
        raise ArgumentError, 'Tên "Untagged" không dùng để gán.' if key(target) == 'untagged'
        target
      end

      # Tag trong model: dùng tag có sẵn (không phân biệt hoa thường) hoặc tạo mới. Gọi trong một operation.
      def self.layer_for(model, name)
        target = normalize_name(name)
        find_layer(model, target) || model.layers.add(target)
      end

      # Gán tag cho các đối tượng và mặt. Bỏ qua đối tượng bị khóa.
      def self.assign(model, entities, name)
        target = normalize_name(name)
        result = {count: 0, locked: 0, hidden: false}
        Data.transaction(model, 'VGD BIM · Gán tag') do
          layer = layer_for(model, target)
          result[:hidden] = !layer.visible?
          entities.each do |entity|
            next unless entity.valid?
            if entity.respond_to?(:locked?) && entity.locked?
              result[:locked] += 1
              next
            end
            entity.layer = layer
            result[:count] += 1
          end
        end
        result
      end
    end
  end
end
