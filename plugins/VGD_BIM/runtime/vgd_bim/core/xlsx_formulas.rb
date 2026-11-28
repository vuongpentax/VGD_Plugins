require_relative 'formula'

module VGD
  module BIM
    # Công thức Excel cho các ô tính toán của Bảng khối lượng khi xuất .xlsx: người dùng sửa Rộng / Cao / Đơn giá / Hao hụt... trên Excel là kết quả tự tính lại.
    # Logic thuần: nhận cột (khóa, hệ số đổi đơn vị) và dữ liệu tính của từng dòng do giao diện gửi (đã kiểm tra ở TableReport), trả về chữ công thức
    # (không có dấu "=") theo ô Excel. Công thức chỉ dựng từ khóa cột đã biết, số và cây phép tính của Formula; không bao giờ chép chữ người dùng vào công thức.
    #
    # Cột (khóa => ý nghĩa, giống Table / Quantity / MaterialLibrary):
    #   areaXZ = Rộng x Cao, areaXY = Rộng x Dài, total = Đơn giá x Số lượng, calc_qty = khối lượng theo cách tính, calc_total = Đơn giá x Khối lượng tính,
    #   mat_qty = Khối lượng tính x (1 + Hao hụt / 100), mat_cost = Khối lượng có hao hụt x Đơn giá vật liệu.
    # Số đo của cột theo đơn vị đang hiện; hệ số si của cột đổi về m / m² / m³ (ví dụ cột mm có si 0,001). Ô thiếu số thì kết quả để trống như trong plugin.
    # Dòng nhóm và dòng tổng: SUBTOTAL(9, ...) của các dòng được cộng (lọc trên Excel vẫn cộng đúng), bỏ dòng con của món cha có trong bảng như plugin.
    module XlsxFormulas
      KEY = /\A[A-Za-z0-9_]{1,40}\z/
      METHODS = %w[count area length volume none formula].freeze
      NUMBER_KEYS = %w[struct_area struct_volume struct_length volume].freeze
      MAX_RUNS = 200 # số khoảng ô tối đa trong một SUBTOTAL (Excel nhận tối đa 254 đối số)
      SUM_KEYS = %w[areaXZ areaXY areaFace areaProjected volume quantity total calc_total mat_cost].freeze

      # Dữ liệu tính của một dòng do giao diện gửi ('calc'); nil nếu không có. Sai kiểu thì ArgumentError.
      def self.meta!(value)
        return nil if value.nil?
        bad = -> { raise ArgumentError, 'Dữ liệu bảng không hợp lệ.' }
        bad.call unless value.is_a?(Hash)
        method = value['method'].to_s
        bad.call unless method.empty? || METHODS.include?(method)
        formula = value['formula']
        bad.call unless formula.nil? || (formula.is_a?(String) && formula.length <= Formula::MAX_LENGTH)
        unit = value['unit'].to_s
        bad.call unless unit.length <= 10 && unit.match?(/\A[a-z0-9]*\z/)
        numbers = NUMBER_KEYS.to_h do |key|
          number = value[key]
          bad.call unless number.nil? || (number.is_a?(Numeric) && number.finite? && number.abs < 1.0e12)
          [key.to_sym, number]
        end
        %w[counted mat_ok mat_unit_ok].each { |key| bad.call unless value[key].nil? || value[key] == true || value[key] == false }
        {method: method, formula: formula, unit: unit, counted: value['counted'] != false, mat_ok: value['mat_ok'] == true, mat_unit_ok: value['mat_unit_ok'] == true}.merge(numbers)
      end

      # Bảng tra khóa cột => số thứ tự cột, và hệ số si.
      class Sheet
        def initialize(columns)
          @index = {}
          @si = {}
          @keys = columns.map { |col| col[:key] }
          columns.each_with_index do |col, i|
            next unless col[:key]
            @index[col[:key]] ||= i
            @si[col[:key]] = col[:si] || 1.0
          end
        end
        def index(key); @index[key]; end
        def has?(key); @index.key?(key); end
        def key_at(i); @keys[i]; end
        def si(key); @si.fetch(key, 1.0); end
        def ref(key, row); "#{Xlsx.column_letter(@index.fetch(key))}#{row}"; end
      end

      # Công thức của các ô trong một dòng món: {số cột => chữ công thức}.
      def self.row_formulas(sheet, meta, row)
        out = {}
        put = ->(key, formula) { out[sheet.index(key)] = formula if formula && sheet.has?(key) }
        put.call('areaXZ', product(sheet, row, %w[lenX lenZ], sheet.si('areaXZ')))
        put.call('areaXY', product(sheet, row, %w[lenX lenY], sheet.si('areaXY')))
        if sheet.has?('price')
          quantity = sheet.has?('quantity') ? sheet.ref('quantity', row) : '1'
          put.call('total', "IF(COUNT(#{sheet.ref('price', row)})=0,\"\",#{sheet.ref('price', row)}*#{quantity})")
        end
        put.call('calc_qty', meta && calc_formula(sheet, meta, row))
        put.call('calc_total', both(sheet, row, 'price', 'calc_qty'))
        put.call('mat_qty', "IF(COUNT(#{sheet.ref('calc_qty', row)})=0,\"\",#{sheet.ref('calc_qty', row)}*(1+#{waste(sheet, row)}/100))") if meta && meta[:mat_ok] && sheet.has?('calc_qty')
        put.call('mat_cost', both(sheet, row, 'mat_qty', 'mat_price')) if meta && meta[:mat_unit_ok]
        out
      end

      def self.waste(sheet, row)
        sheet.has?('mat_waste') ? "N(#{sheet.ref('mat_waste', row)})" : '0'
      end

      # Tích các số đo (đổi về mét) chia hệ số của cột kết quả; thiếu cột thì không có công thức.
      def self.product(sheet, row, keys, divisor)
        return nil unless keys.all? { |key| sheet.has?(key) }
        refs = keys.map { |key| sheet.ref(key, row) }
        expr = keys.map { |key| metres(sheet, key, row) }.join('*')
        expr = "(#{expr})/#{Formula.excel_number(divisor)}" unless divisor == 1.0
        "IF(COUNT(#{refs.join(',')})=#{refs.size},#{expr},\"\")"
      end

      def self.both(sheet, row, a, b)
        return nil unless sheet.has?(a) && sheet.has?(b)
        "IF(COUNT(#{sheet.ref(a, row)},#{sheet.ref(b, row)})=2,#{sheet.ref(a, row)}*#{sheet.ref(b, row)},\"\")"
      end

      # Ô số đo đổi về đơn vị chuẩn (m, m², m³).
      def self.metres(sheet, key, row)
        factor = sheet.si(key)
        factor == 1.0 ? sheet.ref(key, row) : "#{sheet.ref(key, row)}*#{Formula.excel_number(factor)}"
      end

      # [biểu thức, ô tham chiếu] của một số đo dùng trong khối lượng; nil nếu không dựng được (thiếu cột). Số cố định (phần tử VGD Structure) không có ô.
      def self.measure(sheet, meta, key, row)
        case key
        when :w, :d, :h
          col = {w: 'lenX', d: 'lenY', h: 'lenZ'}.fetch(key)
          sheet.has?(col) ? [metres(sheet, col, row), [sheet.ref(col, row)]] : nil
        when :area
          return [Formula.excel_number(meta[:struct_area]), []] if meta[:struct_area].is_a?(Numeric)
          return [metres(sheet, 'areaXZ', row), [sheet.ref('areaXZ', row)]] if sheet.has?('areaXZ')
          return nil unless sheet.has?('lenX') && sheet.has?('lenZ')
          ["#{metres(sheet, 'lenX', row)}*#{metres(sheet, 'lenZ', row)}", [sheet.ref('lenX', row), sheet.ref('lenZ', row)]]
        when :volume
          return [Formula.excel_number(meta[:struct_volume]), []] if meta[:struct_volume].is_a?(Numeric) && meta[:struct_volume].positive?
          if meta[:volume].is_a?(Numeric) && meta[:volume].positive?
            return sheet.has?('volume') ? [metres(sheet, 'volume', row), [sheet.ref('volume', row)]] : [Formula.excel_number(meta[:volume]), []]
          end
          return nil unless %w[lenX lenY lenZ].all? { |col| sheet.has?(col) }
          [%w[lenX lenY lenZ].map { |col| metres(sheet, col, row) }.join('*'), %w[lenX lenY lenZ].map { |col| sheet.ref(col, row) }]
        end
      end

      # Khối lượng tính theo cách tính của dòng (như Quantity.amount / Quantity.formula_amount). Theo cái, không tính, số đo chính xác của
      # VGD Structure: giữ số (không có công thức).
      def self.calc_formula(sheet, meta, row)
        case meta[:method]
        when 'area'
          return nil if meta[:struct_area].is_a?(Numeric)
          wrap(measure(sheet, meta, :area, row))
        when 'length'
          return nil if meta[:struct_length].is_a?(Numeric)
          wrap(measure(sheet, meta, :w, row))
        when 'volume'
          return nil if meta[:struct_volume].is_a?(Numeric) && meta[:struct_volume].positive?
          return nil if meta[:volume].is_a?(Numeric) && meta[:volume].positive? && !sheet.has?('volume')
          wrap(measure(sheet, meta, :volume, row))
        when 'formula'
          tree = begin
            Formula.parse!(meta[:formula].to_s)
          rescue ArgumentError
            return nil
          end
          parts = Formula.variables(tree).to_h { |key| [key, measure(sheet, meta, key, row)] }
          return nil if parts.values.any?(&:nil?)
          refs = parts.values.flat_map(&:last).uniq
          expr = Formula.to_excel(tree, parts.transform_values(&:first))
          refs.empty? ? expr : "IF(COUNT(#{refs.join(',')})=#{refs.size},#{expr},\"\")"
        end
      end

      def self.wrap(part)
        return nil unless part
        expr, refs = part
        refs.empty? ? expr : "IF(COUNT(#{refs.uniq.join(',')})=#{refs.uniq.size},#{expr},\"\")"
      end

      # Công thức tổng của một cột cho các dòng (số dòng Excel kèm dữ liệu tính) của nhóm / bảng. Khối lượng tính chỉ cộng khi mọi dòng cùng đơn vị.
      def self.summary_formula(sheet, key, members)
        counted = members.select { |_number, meta| meta.nil? || meta[:counted] }
        return nil if counted.empty?
        if key == 'calc_qty'
          units = counted.map { |_number, meta| meta && meta[:unit] }.uniq
          return nil unless units.size == 1 && units.first.to_s != ''
        elsif !SUM_KEYS.include?(key)
          return nil
        end
        runs = runs(counted.map(&:first))
        return nil if runs.size > MAX_RUNS
        letter = Xlsx.column_letter(sheet.index(key))
        "SUBTOTAL(9,#{runs.map { |a, b| a == b ? "#{letter}#{a}" : "#{letter}#{a}:#{letter}#{b}" }.join(',')})"
      end

      # [[đầu, cuối], ...] các khoảng số dòng liên tiếp.
      def self.runs(numbers)
        numbers.sort.slice_when { |a, b| b != a + 1 }.map { |run| [run.first, run.last] }
      end
    end
  end
end
