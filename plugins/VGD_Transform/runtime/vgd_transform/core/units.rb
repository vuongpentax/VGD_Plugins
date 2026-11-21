module VGD
  module Transform
    # Đơn vị độ dài và số trong ô nhập. Logic thuần, không gọi SketchUp.
    # Mọi tính toán nội bộ dùng mm. Số không có đơn vị được hiểu theo đơn vị của file SketchUp đang mở.
    # Gõ thêm đơn vị sau số (1m, 250 mm, 2in) thì số đó dùng đơn vị đã gõ, như ô nhập VCB của SketchUp.
    module Units
      MM_PER_UNIT = {'mm' => 1.0, 'cm' => 10.0, 'm' => 1000.0, 'in' => 25.4, 'ft' => 304.8}.freeze
      MM_PER_INCH = MM_PER_UNIT.fetch('in')
      # Thứ tự theo chỉ số LengthUnit của SketchUp (model.options['UnitsOptions']['LengthUnit']).
      MODEL_UNITS = %w[in ft mm cm m].freeze
      DEFAULT_UNIT = 'mm'
      LIMIT_MM = 1_000_000.0 # tọa độ / độ dời / kích thước ngoài ±1 km (mm) là nhập nhầm
      NUMBER = /\A[+-]?(\d+\.?\d*|\.\d+)\z/.freeze
      LENGTH = /\A([+-]?(?:\d+\.?\d*|\.\d+))\s*(mm|cm|m|in|ft)?\z/i.freeze

      module_function

      # Tên đơn vị của file theo chỉ số của SketchUp. Chỉ số lạ thì dùng mm.
      def unit_of_model(index)
        return DEFAULT_UNIT unless index.is_a?(Integer)
        MODEL_UNITS.fetch(index, DEFAULT_UNIT)
      end

      # Ô độ dài → mm. Trống hoặc nil: nil (nghĩa là không nhập). Sai định dạng hoặc vượt giới hạn: báo lỗi.
      def parse_length(text, default_unit)
        raw = clean(text)
        return nil if raw.nil?
        match = LENGTH.match(raw)
        raise ArgumentError, "Tọa độ \"#{text}\" không phải số hoặc đơn vị không hỗ trợ." unless match
        unit = (match[2] || default_unit).downcase
        mm = Float(match[1]) * MM_PER_UNIT.fetch(unit)
        raise ArgumentError, "Giá trị vượt giới hạn ±#{LIMIT_MM.to_i} mm." if mm.abs > LIMIT_MM
        mm
      end

      # Ô scale: số không có đơn vị là hệ số (1 = giữ). Số có đơn vị (1m, 1000mm) là kích thước đích theo trục đó → {length: mm}.
      # Trống hoặc nil: nil.
      def parse_scale(text)
        raw = clean(text)
        return nil if raw.nil?
        match = LENGTH.match(raw)
        raise ArgumentError, "\"#{text}\" không phải số hoặc đơn vị không hỗ trợ." unless match
        value = Float(match[1])
        return value unless match[2]
        mm = value * MM_PER_UNIT.fetch(match[2].downcase)
        raise ArgumentError, 'Kích thước đích phải lớn hơn 0.' unless mm.positive?
        raise ArgumentError, "Giá trị vượt giới hạn ±#{LIMIT_MM.to_i} mm." if mm > LIMIT_MM
        {length: mm}
      end

      # Ô số không có đơn vị (góc). Trống hoặc nil: nil. Sai định dạng: báo lỗi.
      def parse_number(text)
        raw = clean(text)
        return nil if raw.nil?
        raise ArgumentError, "\"#{text}\" không phải số." unless raw.match?(NUMBER)
        Float(raw)
      end

      def clean(text)
        return nil if text.nil?
        raw = text.to_s.strip.tr(',', '.')
        raw.empty? ? nil : raw
      end
    end
  end
end
