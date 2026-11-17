module VGD
  module Structure
    # Lưới trục: dữ liệu, kiểm tra và tính giao điểm / nhịp / ô. Logic thuần, không gọi SketchUp (đặc tả: docs/vgd_structure/SPEC.md mục 1).
    #
    # `x_axes` là các trục có VỊ TRÍ theo X (trên mặt bằng là đường thẳng đứng, đánh số 1, 2, 3),
    # `y_axes` là các trục có vị trí theo Y (đường nằm ngang, đánh chữ A, B, C). Mọi số là mm.
    module Grid
      MIN_AXES = 2
      MAX_AXES = 60
      MAX_NAME = 4            # ký hiệu trục nằm trong vòng tròn nhỏ, tối đa 4 ký tự
      MIN_SPACING = 100.0     # nhịp nhỏ hơn 100 mm là nhập nhầm
      MAX_COORD = 1_000_000.0 # 1 km: giới hạn chống số vô lý
      CONTROL = /[\u0000-\u001f\u007f]/
      REF_CHARS = /[-\/:]/ # dùng để ghép mã giao điểm, nhịp, ô nên không được có trong tên trục
      LETTERS = (('A'..'Z').to_a - %w[I O]).freeze # bỏ I và O (dễ nhầm với 1 và 0), chủ dự án chốt 17/11/2026

      Error = Class.new(ArgumentError)

      # Lưới mặc định khi model chưa có: 4 trục đứng cách 4200, 3 trục ngang cách 3600.
      def self.default
        normalize!('origin' => [0, 0], 'x_axes' => axes_from_spacings('4200*3', :number), 'y_axes' => axes_from_spacings('3600*2', :letter))
      end

      # Tên mặc định: số 1, 2, 3... hoặc chữ A, B, C... (bỏ I, O; hết 24 chữ thì AA, AB...).
      def self.default_names(kind, count)
        raise Error, 'Kiểu tên không hợp lệ.' unless %i[number letter].include?(kind)
        raise Error, "Số trục phải từ #{MIN_AXES} đến #{MAX_AXES}." unless count.is_a?(Integer) && count.between?(MIN_AXES, MAX_AXES)
        return (1..count).map(&:to_s) if kind == :number
        count.times.map { |i| i < LETTERS.size ? LETTERS[i] : LETTERS[i / LETTERS.size - 1] + LETTERS[i % LETTERS.size] }
      end

      # Dấu phẩy và khoảng trắng ngăn cách các nhịp (số lẻ dùng dấu chấm). "4200, 3600*2, 3000" -> các nhịp [4200, 3600, 3600, 3000]; từ đó ra danh sách trục (tên mặc định, vị trí cộng dồn từ 0).
      def self.axes_from_spacings(text, kind)
        spans = parse_spacings(text)
        names = default_names(kind, spans.size + 1)
        offset = 0.0
        axes = [{'name' => names[0], 'offset' => 0.0}]
        spans.each_with_index { |span, i| offset += span; axes << {'name' => names[i + 1], 'offset' => offset.round(1)} }
        axes
      end

      def self.parse_spacings(text)
        raise Error, 'Hãy nhập khoảng cách các nhịp, ví dụ 4200, 3600*2.' unless text.is_a?(String) && !text.strip.empty?
        spans = text.split(/[,;\s]+/).reject(&:empty?).flat_map do |token|
          match = token.match(/\A(\d+(?:\.\d+)?)(?:[*x×](\d{1,2}))?\z/i) or raise Error, "Không hiểu “#{token}”. Dùng số mm, ví dụ 4200 hoặc 3600*2."
          value = match[1].to_f
          raise Error, "Nhịp phải từ #{MIN_SPACING.to_i} mm trở lên (nhập “#{token}”)." if value < MIN_SPACING
          [value] * (match[2] ? match[2].to_i : 1)
        end
        raise Error, "Tối đa #{MAX_AXES - 1} nhịp mỗi phương." if spans.size > MAX_AXES - 1
        raise Error, 'Cần ít nhất một nhịp.' if spans.empty?
        spans
      end

      # Kiểm tra dữ liệu lưới (từ giao diện hoặc đọc từ model); trả về bảng băm sạch, mới. Sai thì raise Error có lời nhắn tiếng Việt.
      def self.normalize!(raw)
        raise Error, 'Dữ liệu lưới trục không hợp lệ.' unless raw.is_a?(Hash)
        origin = raw['origin'].nil? ? [0.0, 0.0] : raw['origin']
        raise Error, 'Gốc lưới phải gồm hai số (X, Y).' unless origin.is_a?(Array) && origin.size == 2 && origin.all? { |v| finite?(v) && v.abs <= MAX_COORD }
        x = axes!(raw['x_axes'], 'đứng')
        y = axes!(raw['y_axes'], 'ngang')
        names = (x + y).map { |axis| axis['name'].downcase }
        dup = names.find { |name| names.count(name) > 1 }
        raise Error, "Tên trục “#{dup.upcase}” bị trùng. Mỗi trục cần một tên riêng." if dup
        {'origin' => origin.map { |v| v.to_f.round(1) }, 'x_axes' => x, 'y_axes' => y}
      end

      def self.axes!(list, label)
        raise Error, "Hãy nhập các trục #{label}." unless list.is_a?(Array)
        raise Error, "Cần từ #{MIN_AXES} đến #{MAX_AXES} trục #{label}." unless list.size.between?(MIN_AXES, MAX_AXES)
        previous = nil
        list.each_with_index.map do |axis, i|
          raise Error, "Trục #{label} thứ #{i + 1} không hợp lệ." unless axis.is_a?(Hash)
          name = axis['name'].is_a?(String) ? axis['name'].strip : ''
          raise Error, "Trục #{label} thứ #{i + 1}: tên từ 1 đến #{MAX_NAME} ký tự, không có ký tự điều khiển." if name.empty? || name.length > MAX_NAME || name.match?(CONTROL)
          raise Error, "Trục #{label} thứ #{i + 1}: tên không được chứa dấu - / hoặc :." if name.match?(REF_CHARS)
          offset = axis['offset']
          raise Error, "Trục “#{name}”: vị trí phải là số (mm), không quá #{MAX_COORD.to_i}." unless finite?(offset) && offset.abs <= MAX_COORD
          offset = offset.to_f.round(1)
          raise Error, "Trục “#{name}” phải cách trục trước ít nhất #{MIN_SPACING.to_i} mm (vị trí tăng dần)." if previous && offset - previous < MIN_SPACING
          previous = offset
          {'name' => name, 'offset' => offset}
        end
      end

      def self.finite?(value)
        value.is_a?(Numeric) && value.to_f.finite?
      end

      # Khung bao các trục trong tọa độ thế giới: [x_nhỏ, y_nhỏ, x_lớn, y_lớn].
      def self.bounds(grid)
        ox, oy = grid['origin']
        [ox + grid['x_axes'].first['offset'], oy + grid['y_axes'].first['offset'], ox + grid['x_axes'].last['offset'], oy + grid['y_axes'].last['offset']]
      end

      # Giao điểm: {ref: 'tên trục x-tên trục y', x:, y: (thế giới), placement: middle | edge | corner}.
      # edge: nằm trên đúng một trục biên; corner: nằm trên hai trục biên (xem SPEC mục 4).
      def self.intersections(grid)
        ox, oy = grid['origin']
        last_x = grid['x_axes'].size - 1
        last_y = grid['y_axes'].size - 1
        grid['x_axes'].each_with_index.flat_map do |ax, xi|
          grid['y_axes'].each_with_index.map do |ay, yi|
            edges = [xi.zero? || xi == last_x, yi.zero? || yi == last_y].count(true)
            {ref: "#{ax['name']}-#{ay['name']}", xn: ax['name'], yn: ay['name'], x: ox + ax['offset'], y: oy + ay['offset'], placement: %w[middle edge corner][edges]}
          end
        end
      end

      # Nhịp: đoạn trục giữa hai giao điểm liền nhau. dir 'x' = chạy theo X (nằm trên một trục ngang), 'y' = chạy theo Y (nằm trên một trục đứng).
      # ref 'x:A:1-2' = nhịp chạy theo X trên trục A giữa trục 1 và 2. placement: edge nếu nằm trên trục biên, inner nếu không.
      def self.spans(grid)
        ox, oy = grid['origin']
        out = []
        grid['y_axes'].each_with_index do |ay, yi|
          edge = yi.zero? || yi == grid['y_axes'].size - 1
          side = yi.zero? ? 'min' : (edge ? 'max' : nil)
          grid['x_axes'].each_cons(2) do |a, b|
            out << {ref: "x:#{ay['name']}:#{a['name']}-#{b['name']}", dir: 'x', from: [ox + a['offset'], oy + ay['offset']], to: [ox + b['offset'], oy + ay['offset']], length: (b['offset'] - a['offset']).round(1),
                    placement: edge ? 'edge' : 'inner', side: side, from_ref: "#{a['name']}-#{ay['name']}", to_ref: "#{b['name']}-#{ay['name']}"}
          end
        end
        grid['x_axes'].each_with_index do |ax, xi|
          edge = xi.zero? || xi == grid['x_axes'].size - 1
          side = xi.zero? ? 'min' : (edge ? 'max' : nil)
          grid['y_axes'].each_cons(2) do |a, b|
            out << {ref: "y:#{ax['name']}:#{a['name']}-#{b['name']}", dir: 'y', from: [ox + ax['offset'], oy + a['offset']], to: [ox + ax['offset'], oy + b['offset']], length: (b['offset'] - a['offset']).round(1),
                    placement: edge ? 'edge' : 'inner', side: side, from_ref: "#{ax['name']}-#{a['name']}", to_ref: "#{ax['name']}-#{b['name']}"}
          end
        end
        out
      end

      # Ô: vùng chữ nhật giữa hai trục đứng liền nhau và hai trục ngang liền nhau. ref '1-2/A-B'.
      def self.cells(grid)
        ox, oy = grid['origin']
        grid['x_axes'].each_cons(2).flat_map do |x1, x2|
          grid['y_axes'].each_cons(2).map do |y1, y2|
            {ref: "#{x1['name']}-#{x2['name']}/#{y1['name']}-#{y2['name']}", min: [ox + x1['offset'], oy + y1['offset']], max: [ox + x2['offset'], oy + y2['offset']],
             width: (x2['offset'] - x1['offset']).round(1), depth: (y2['offset'] - y1['offset']).round(1)}
          end
        end
      end
    end
  end
end
