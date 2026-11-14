require 'securerandom'
require_relative 'storage'
require_relative 'schema'
require_relative 'measure'
require_relative 'quantity'

module VGD
  module BIM
    # Thư viện vật liệu: dữ liệu vật liệu (mã, hãng, sản phẩm, độ dày, đơn vị, đơn giá, hao hụt, quy cách) lưu trên máy (material_library.json),
    # nối với vật liệu SketchUp theo TÊN (không phân biệt hoa thường và dấu). Dùng để tính khối lượng có hao hụt và thành tiền theo vật liệu
    # (chỉ khi đơn vị vật liệu trùng đơn vị tính của dòng). Xem docs/vgd_bim/ROADMAP.md cột mốc 3.
    module MaterialLibrary
      FILE = 'material_library'.freeze
      MAX_ITEMS = 500
      MAX_NAME = 80
      MAX_CODE = 30
      MAX_SPEC = 200
      ID_PATTERN = /\Amt_[0-9a-f]{8}\z/
      CONTROL = /[\u0000-\u001f\u007f]/
      MAX_PRICE = 1.0e12
      MAX_THICKNESS = 1000.0

      def self.text!(value, limit, label)
        text = value.nil? ? '' : value
        raise ArgumentError, "Giá trị #{label} tối đa #{limit} ký tự và không có ký tự điều khiển." unless text.is_a?(String) && text.strip.length <= limit && !text.match?(CONTROL)
        text.strip
      end

      def self.optional_number!(value, label, max)
        return nil if value.nil?
        raise ArgumentError, "Giá trị #{label} phải là số từ 0 đến #{max.to_i}." unless value.is_a?(Numeric) && value.finite? && value >= 0 && value <= max
        value
      end

      def self.sanitize!(list)
        raise ArgumentError, 'Danh sách vật liệu không hợp lệ.' unless list.is_a?(Array)
        raise ArgumentError, "Chỉ có tối đa #{MAX_ITEMS} vật liệu." if list.size > MAX_ITEMS
        codes = {}
        links = {}
        list.map do |item|
          raise ArgumentError, 'Danh sách vật liệu không hợp lệ.' unless item.is_a?(Hash)
          name = item['name'].is_a?(String) ? item['name'].strip : ''
          raise ArgumentError, "Hãy nhập tên vật liệu (tối đa #{MAX_NAME} ký tự, không có ký tự điều khiển)." if name.empty? || name.length > MAX_NAME || name.match?(CONTROL)
          code = text!(item['code'], MAX_CODE, 'mã vật liệu')
          raise ArgumentError, "Mã vật liệu trùng nhau: #{code}." if !code.empty? && codes[code.downcase]
          codes[code.downcase] = true
          link = text!(item['sketchup_material'], MAX_NAME, 'vật liệu SketchUp')
          raise ArgumentError, "Vật liệu SketchUp được nối trùng nhau: #{link}." if !link.empty? && links[Measure.normalize(link)]
          links[Measure.normalize(link)] = true
          id = item['id']
          raise ArgumentError, 'Mã nội bộ của vật liệu không hợp lệ.' unless id.nil? || (id.is_a?(String) && id.match?(ID_PATTERN))
          unit = item['unit'].nil? || item['unit'] == '' ? 'm2' : item['unit']
          raise ArgumentError, "Giá trị đơn vị không hợp lệ: #{unit}." unless Schema::UNITS.include?(unit)
          waste = item['waste'].nil? ? 0 : item['waste']
          raise ArgumentError, 'Giá trị hao hụt phải là số từ 0 đến 100 (%).' unless waste.is_a?(Numeric) && waste.finite? && waste >= 0 && waste <= 100
          price = optional_number!(item['price'], 'đơn giá', MAX_PRICE)
          thickness = optional_number!(item['thickness'], 'độ dày (mm)', MAX_THICKNESS)
          {'id' => id || "mt_#{SecureRandom.hex(4)}", 'code' => code, 'name' => name, 'manufacturer' => text!(item['manufacturer'], MAX_NAME, 'hãng'),
           'product' => text!(item['product'], MAX_NAME, 'sản phẩm'), 'thickness' => thickness && thickness.round(1).to_f, 'unit' => unit,
           'price' => price && price.round(2).to_f, 'waste' => waste.round(1).to_f, 'spec' => text!(item['spec'], MAX_SPEC, 'quy cách'), 'sketchup_material' => link}
        end
      end

      # Thư viện đã lưu trên máy; file hỏng coi như chưa có, mục sai bị bỏ (không đoán).
      def self.read
        raw = Storage.read(FILE)
        return [] unless raw.is_a?(Hash) && raw['items'].is_a?(Array)
        dedupe(raw['items'].filter_map { |item| sanitize!([item]).first rescue nil })
      end

      # Bỏ mục trùng mã / trùng liên kết sau khi đọc file (file sửa tay).
      def self.dedupe(items)
        seen_code = {}
        seen_link = {}
        items.select do |i|
          c = i['code'].downcase
          l = Measure.normalize(i['sketchup_material'])
          next false if (!c.empty? && seen_code[c]) || (!l.empty? && seen_link[l])
          seen_code[c] = true unless c.empty?
          seen_link[l] = true unless l.empty?
          true
        end
      end

      def self.write(list)
        Storage.write(FILE, {'items' => sanitize!(list)})
      end

      # Mục thư viện nối với vật liệu SketchUp có tên này; không có thì nil.
      def self.find(items, material_name)
        key = Measure.normalize(material_name.to_s)
        return nil if key.empty?
        items.find { |item| !item['sketchup_material'].empty? && Measure.normalize(item['sketchup_material']) == key }
      end

      # Khối lượng có hao hụt và thành tiền theo vật liệu của một dòng: method / qty lấy từ cột Khối lượng tính.
      # Thành tiền chỉ tính khi đơn vị vật liệu trùng đơn vị tính (m2 / m / m3 / cái); khác đơn vị thì ghi chú, không đoán quy đổi.
      def self.cost(entry, method, qty)
        none = {qty: nil, cost: nil, note: nil}
        return none unless entry && qty.is_a?(Numeric) && Quantity::SCHEMA_UNIT.key?(method)
        with_waste = (qty * (1 + entry['waste'] / 100.0)).round(3)
        calc_unit = Quantity::SCHEMA_UNIT[method]
        return {qty: with_waste, cost: nil, note: 'Vật liệu chưa có đơn giá'} if entry['price'].nil?
        return {qty: with_waste, cost: nil, note: "Đơn vị vật liệu (#{entry['unit']}) khác đơn vị tính (#{calc_unit})"} unless entry['unit'] == calc_unit
        {qty: with_waste, cost: (with_waste * entry['price']).round(2), note: nil}
      end
    end
  end
end
