module VGD
  module Structure
    # Ký hiệu trục theo thông lệ bản vẽ quốc tế: trục là nét gạch dài - chấm mảnh, kéo dài quá trục biên,
    # đầu trục có vòng tròn đường kính 8 đến 12 mm trên giấy (dùng 10 mm) chứa tên trục đặt giữa vòng tròn.
    # Trục đứng (số) có ký hiệu ở đầu dưới, trục ngang (chữ) ở đầu trái; tùy chọn thêm ký hiệu ở đầu kia.
    # Kích thước tính theo mm trên giấy nhân tỉ lệ bản vẽ (1:100 → vòng tròn 1000 mm trong model). Logic thuần, không gọi SketchUp.
    module AxisSymbol
      PAPER_DIAMETER_MM = 10.0 # đường kính vòng tròn trên giấy
      EXTENSION_RATIO = 1.5    # đoạn trục kéo dài quá trục biên = 1,5 lần đường kính (tính tới mép vòng tròn)
      TEXT_RATIO = 0.4         # chiều cao chữ = 0,4 lần đường kính (1 đến 2 ký tự); từ 3 ký tự thu nhỏ để lọt vòng tròn
      TEXT_RATIO_LONG = 0.28
      SCALES = (10..1000)      # tỉ lệ 1:n hợp lệ

      Error = Class.new(ArgumentError)

      def self.options!(raw)
        raw = {} if raw.nil?
        raise Error, 'Thiết lập ký hiệu trục không hợp lệ.' unless raw.is_a?(Hash)
        scale = raw.key?('scale') ? raw['scale'] : 100
        raise Error, "Tỉ lệ bản vẽ phải là số nguyên từ 1:#{SCALES.first} đến 1:#{SCALES.last}." unless scale.is_a?(Integer) && SCALES.cover?(scale)
        both = raw.key?('both_ends') ? raw['both_ends'] : false
        raise Error, 'Mục “ký hiệu hai đầu” phải là Có hoặc Không.' unless both == true || both == false
        {'scale' => scale, 'both_ends' => both}
      end

      def self.diameter(options)
        PAPER_DIAMETER_MM * options['scale']
      end

      # Kế hoạch vẽ cho lưới đã chuẩn hóa: mỗi trục có đoạn thẳng (thế giới, mm), các vòng tròn ký hiệu và chiều cao chữ.
      # {name:, dir: 'x' | 'y', line: [[x1, y1], [x2, y2]], bubbles: [{center: [x, y], radius:}], text_height:}
      def self.plan(grid, options)
        opts = options!(options)
        d = diameter(opts)
        r = d / 2.0
        ext = EXTENSION_RATIO * d
        x0, y0, x1, y1 = Grid.bounds(grid)
        ox, oy = grid['origin']
        axes = []
        grid['x_axes'].each do |axis|
          x = ox + axis['offset']
          bubbles = [{center: [x, y0 - ext - r], radius: r}]
          bubbles << {center: [x, y1 + ext + r], radius: r} if opts['both_ends']
          axes << {name: axis['name'], dir: 'x', line: [[x, y0 - ext], [x, y1 + ext]], bubbles: bubbles, text_height: text_height(axis['name'], d)}
        end
        grid['y_axes'].each do |axis|
          y = oy + axis['offset']
          bubbles = [{center: [x0 - ext - r, y], radius: r}]
          bubbles << {center: [x1 + ext + r, y], radius: r} if opts['both_ends']
          axes << {name: axis['name'], dir: 'y', line: [[x0 - ext, y], [x1 + ext, y]], bubbles: bubbles, text_height: text_height(axis['name'], d)}
        end
        axes
      end

      def self.text_height(name, diameter)
        diameter * (name.length >= 3 ? TEXT_RATIO_LONG : TEXT_RATIO)
      end
    end
  end
end
