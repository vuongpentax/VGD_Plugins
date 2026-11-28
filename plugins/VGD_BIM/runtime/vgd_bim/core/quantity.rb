module VGD
  module BIM
    # Nối tag với dữ liệu chuẩn của VGD: từ tag (và nhóm tag) của món suy ra hạng mục và cách tính (theo cái / diện tích / mét dài / thể tích / không tính),
    # rồi tính khối lượng từ số đo của dòng trong Bảng khối lượng. Tính ảo trong bảng, không ghi vào món; chỉ ghi khi người dùng bấm "Ghi cách tính vào món"
    # (commit_values), và khi ghi chỉ điền các mục còn trống, không ghi đè dữ liệu người dùng đã nhập.
    #
    # Thứ tự ưu tiên của cách tính: dữ liệu trong món (quantity_method, include_boq) > ghi đè theo tag của người dùng > từ khóa trong tên tag >
    # nhóm tag > mặc định (theo cái).
    module Quantity
      METHODS = %w[count area length volume none].freeze
      SCHEMA_UNIT = {'count' => 'pcs', 'area' => 'm2', 'length' => 'm', 'volume' => 'm3'}.freeze
      FILE = 'tag_quantity'.freeze
      LABELS = {'count' => 'theo cái', 'area' => 'theo diện tích', 'length' => 'theo mét dài', 'volume' => 'theo thể tích', 'none' => 'không tính', 'formula' => 'theo công thức'}.freeze
      # Công thức do người dùng đặt cho tag (core/formula.rb): chỉ đặt được theo tag, kết quả mang đơn vị người dùng chọn (mã đơn vị của schema).
      FORMULA = 'formula'.freeze
      FORMULA_UNITS = (Schema::UNITS - ['none']).freeze

      # Nhóm tag (18 cụm Auto Tag) => [hạng mục, cách tính]. Nhóm chỉ để định hướng: tag nào khác ý thì đổi riêng theo tag.
      GROUP_DEFAULTS = {
        'A. ARCHITECTURAL' => %w[architecture area], 'I. INTERIOR' => %w[furniture count], 'E. ELECTRICAL' => %w[electrical count],
        'F. FIRE PROTECTION' => %w[equipment count], 'M. MECHANICAL' => %w[hvac count], 'P. PLUMBING' => %w[plumbing count],
        'Q. EQUIPMENT' => %w[equipment count], 'L. LANDSCAPE' => %w[other area], '2. SITE' => %w[other area],
        'S. STRUCTURAL' => %w[architecture volume], 'C. CIVIL' => %w[architecture volume], '# MATERIALS' => %w[finish area],
        '1. CONTEXT' => %w[other none], '3. BUILDING STORIES' => %w[other none], '! INFORMATION' => %w[other none],
        '# BASIC' => %w[other none], '@ STATUS' => %w[other none], '@ REFERENCES' => %w[other none]
      }.freeze
      DEFAULT = %w[other count].freeze

      # Từ khóa nguyên từ (đã bỏ dấu, chữ thường) trong tên tag => cách tính; thắng nhóm vì cửa / lan can... khác cách tính với phần còn lại của nhóm.
      KEYWORDS = {
        'door' => 'count', 'window' => 'count', 'cua' => 'count', 'stair' => 'count',
        'railing' => 'length', 'handrail' => 'length', 'fence' => 'length', 'skirting' => 'length', 'baseboard' => 'length', 'trim' => 'length',
        'column' => 'volume', 'beam' => 'volume', 'slab' => 'volume', 'foundation' => 'volume', 'footing' => 'volume', 'pile' => 'volume',
        'wall' => 'area', 'floor' => 'area', 'ceiling' => 'area', 'roof' => 'area', 'tile' => 'area', 'paint' => 'area', 'plaster' => 'area', 'carpet' => 'area'
      }.freeze

      # Khóa chuẩn hóa của tên tag (không phân biệt hoa thường và dấu), dùng cho ghi đè theo tag.
      def self.key(tag)
        Measure.normalize(tag.to_s).strip
      end

      # item: dữ liệu VGD của món (Data.read, {} nếu chưa có). overrides: ghi đè theo tag (overrides).
      # Trả về {category:, method:, source:} với source = item | tag | keyword | group | default.
      def self.resolve(tag, group, item, overrides)
        category_default, method_default = GROUP_DEFAULTS.fetch(group.to_s, DEFAULT)
        category = Schema::CATEGORIES.include?(item[:category].to_s) ? item[:category].to_s : category_default
        return {category: category, method: 'none', source: 'item'} if item[:include_boq] == false
        from_item = item_method(item[:quantity_method])
        return {category: category, method: from_item, source: 'item'} if from_item
        own = overrides[key(tag)]
        return {category: category, method: FORMULA, source: 'tag', formula: own['formula'], unit: own['unit']} if own.is_a?(Hash)
        return {category: category, method: own, source: 'tag'} if METHODS.include?(own)
        word = key(tag).split(/[^a-z0-9]+/).find { |token| KEYWORDS.key?(token) }
        return {category: category, method: KEYWORDS.fetch(word), source: 'keyword'} if word
        {category: category, method: method_default, source: GROUP_DEFAULTS.key?(group.to_s) ? 'group' : 'default'}
      end

      # Cách tính ghi trong món (trường quantity_method của schema): assembly tính theo cái, manual không tự tính, giá trị lạ hoặc trống thì bỏ qua.
      def self.item_method(value)
        case value.to_s
        when 'count', 'area', 'length', 'volume' then value.to_s
        when 'assembly' then 'count'
        when 'manual' then 'none'
        end
      end

      # Khối lượng theo cách tính từ số đo của dòng (mm, m², m³ như trong bảng). Trả về [số lượng, ghi chú].
      #   theo cái: 1; diện tích: Rộng x Cao (areaXZ, m²); mét dài: Rộng (m); thể tích: thể tích khối, không kín thì ước tính theo khối bao.
      def self.amount(method, row)
        case method
        when 'count' then [1.0, nil]
        when 'area'
          face = number(row[:struct_area]) # diện tích mặt thật của phần tử VGD Structure
          return [face, nil] if face
          box = number(row[:areaXZ]) # không có mặt thật: Rộng x Cao của khung bao, có thể lớn hơn diện tích thật (tường xiên, hình lạ)
          [box, box ? 'ước tính theo khối bao' : nil]
        when 'length'
          return [number(row[:struct_length]), nil] if number(row[:struct_length])
          [number(row[:lenX]) && (row[:lenX] / 1000.0).round(3), nil]
        when 'volume'
          exact = number(row[:struct_volume]) # phần tử của VGD Structure: thể tích chính xác từ kích thước plugin ghi, không đoán từ khối bao
          return [exact, nil] if exact && exact.positive?
          solid = number(row[:volume])
          return [solid, nil] if solid && solid.positive?
          sizes = %i[lenX lenY lenZ].map { |key| number(row[key]) }
          sizes.all? ? [(sizes.inject(:*) / 1.0e9).round(4), 'ước tính theo khối bao'] : [nil, nil]
        else [nil, nil]
        end
      end

      def self.number(value)
        value.is_a?(Numeric) ? value.to_f : nil
      end

      # Các trường tính thêm cho một dòng của bảng.
      def self.row_fields(row, tag, group, item, overrides)
        found = resolve(tag, group, item, overrides)
        kind_method = StructureSource.default_method(row[:struct_kind]) if defined?(StructureSource)
        found = found.merge(method: kind_method, source: 'structure') if kind_method && found[:source] == 'default' # phần tử của VGD Structure không có tag cho biết cách tính
        qty, note = found[:method] == FORMULA ? formula_amount(found[:formula], row) : amount(found[:method], row)
        price = number(row[:price])
        {calc_category: found[:category], calc_method: found[:method], calc_source: found[:source], calc_qty: qty,
         calc_total: price && qty ? (price * qty).round(2) : nil, calc_note: note,
         calc_unit: found[:method] == FORMULA ? found[:unit] : SCHEMA_UNIT[found[:method]], calc_formula: found[:formula]}
      end

      # Khối lượng theo công thức: Rộng / Sâu / Cao là mét (lenX / lenY / lenZ), Diện tích và Thể tích lấy như cách tính theo diện tích / thể tích
      # (có thể là ước tính theo khối bao). Cây phép tính nhớ theo chữ công thức để không đọc lại ở mỗi dòng.
      def self.formula_amount(text, row)
        @trees ||= {}
        @trees.clear if @trees.size > 200
        tree = @trees[text] ||= Formula.parse!(text)
        metre = ->(key) { number(row[key]) && row[key] / 1000.0 }
        area = amount('area', row)
        volume = amount('volume', row)
        qty, note = Formula.evaluate(tree, {w: metre.call(:lenX), d: metre.call(:lenY), h: metre.call(:lenZ), area: area[0], volume: volume[0]})
        rough = [(area[1] if Formula.variables(tree).include?(:area)), (volume[1] if Formula.variables(tree).include?(:volume))].compact.uniq
        [qty, note || rough.first]
      rescue ArgumentError => error
        [nil, error.message]
      end

      # ---- Ghi đè theo tag (lưu trên máy, dùng cho mọi model) ----
      def self.overrides
        raw = Storage.read(FILE)
        tags = raw.is_a?(Hash) && raw['tags'].is_a?(Hash) ? raw['tags'] : {}
        tags.each_with_object({}) do |(name, method), out|
          if METHODS.include?(method) then out[name.to_s] = method
          elsif method.is_a?(Hash) && (clean = formula_override(method['formula'], method['unit']) rescue nil) then out[name.to_s] = clean
          end
        end
      end

      # Ghi đè bằng công thức: kiểm tra công thức và đơn vị, trả về mục lưu được.
      def self.formula_override(formula, unit)
        Formula.parse!(formula)
        raise ArgumentError, 'Đơn vị của công thức không hợp lệ.' unless FORMULA_UNITS.include?(unit)
        {'method' => FORMULA, 'formula' => formula.strip, 'unit' => unit}
      end

      # method rỗng nghĩa là bỏ ghi đè của tag (về theo từ khóa / nhóm). method 'formula' cần formula (chữ công thức) và unit (mã đơn vị).
      def self.set_override(tag, method, formula: nil, unit: nil)
        name = key(tag)
        raise ArgumentError, 'Món chưa có tag nên không đặt cách tính theo tag được. Hãy gắn tag trước.' if name.empty?
        method = method.to_s
        raise ArgumentError, 'Cách tính không hợp lệ.' unless method.empty? || METHODS.include?(method) || method == FORMULA
        entry = method == FORMULA ? formula_override(formula, unit) : method
        current = overrides
        method.empty? ? current.delete(name) : current[name] = entry
        Storage.write(FILE, {'tags' => current})
        current
      end

      # Các trường dữ liệu chuẩn cần ghi vào món (chỉ mục còn trống, không ghi đè). has_data: món đã có dữ liệu VGD chưa.
      def self.commit_values(item, has_data, derived)
        values = {}
        values[:category] = derived[:category] if item[:category].to_s.empty?
        if derived[:method] == 'none'
          values[:include_boq] = false unless has_data # món đã có dữ liệu thì không đổi ý người dùng về BOQ
        elsif derived[:method] == FORMULA # schema không có cách tính "công thức": chỉ ghi đơn vị
          values[:unit] = derived[:unit] if item[:unit].to_s.empty? && FORMULA_UNITS.include?(derived[:unit])
        else
          values[:quantity_method] = derived[:method] if item[:quantity_method].to_s.empty?
          values[:unit] = SCHEMA_UNIT.fetch(derived[:method]) if item[:unit].to_s.empty?
        end
        values
      end
    end
  end
end
