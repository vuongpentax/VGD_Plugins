# encoding: UTF-8
module VGD
  module Library
    module Pixels
      Image = Struct.new(:width, :height, :rgba)

      # UV sampling fixes the orientation of traced geometry independently of
      # the native raw scanline order. (0,0) is SketchUp's bottom-left corner.
      def self.from_uv(rep, max_side = 256)
        width, height = rep.width, rep.height
        raise 'Ảnh không có dữ liệu.' if width <= 0 || height <= 0
        factor = [1.0, max_side.to_f / [width, height].max].min
        w, h = [(width * factor).round, 1].max, [(height * factor).round, 1].max
        values = Array.new(w * h * 4)
        h.times do |y|
          w.times do |x|
            color = rep.color_at_uv((x + 0.5) / w, (y + 0.5) / h, false)
            raise 'Không đọc được điểm ảnh để dò nét.' unless color
            values[(y * w + x) * 4, 4] = color.to_a
          end
        end
        Image.new(w, h, values)
      end

      def self.from_rep(rep, max_side = 1024)
        width, height = rep.width, rep.height
        raise 'Ảnh không có dữ liệu.' if width <= 0 || height <= 0
        bytes = rep.data
        channels = rep.bits_per_pixel / 8
        raise 'Chỉ hỗ trợ dữ liệu ảnh 8/24/32 bit.' unless [1, 3, 4].include?(channels) && bytes
        stride = width * channels + rep.row_padding
        raise 'Dữ liệu ảnh bị thiếu.' if bytes.bytesize < stride * height
        factor = [1.0, max_side.to_f / [width, height].max].min
        w, h = [(width * factor).round, 1].max, [(height * factor).round, 1].max
        win = Sketchup.platform == :platform_win
        values = Array.new(w * h * 4)
        h.times do |y|
          sy = [(y * height / h), height - 1].min
          w.times do |x|
            sx = [(x * width / w), width - 1].min
            offset = sy * stride + sx * channels
            if channels == 1
              r = g = b = bytes.getbyte(offset)
            elsif win
              b, g, r = bytes.getbyte(offset), bytes.getbyte(offset + 1), bytes.getbyte(offset + 2)
            else
              r, g, b = bytes.getbyte(offset), bytes.getbyte(offset + 1), bytes.getbyte(offset + 2)
            end
            at = (y * w + x) * 4
            values[at, 4] = [r, g, b, channels == 4 ? bytes.getbyte(offset + 3) : 255]
          end
        end
        Image.new(w, h, values)
      end

      def self.clamp(value)
        [[value.round, 0].max, 255].min
      end

      def self.to_rep(image)
        data = image.rgba.dup
        if Sketchup.platform == :platform_win
          (image.width * image.height).times do |i|
            at = i * 4
            data[at], data[at + 2] = data[at + 2], data[at]
          end
        end
        Sketchup::ImageRep.new.set_data(image.width, image.height, 32, 0, data.map { |v| clamp(v) }.pack('C*'))
      end

      def self.gray(image)
        Array.new(image.width * image.height) do |i|
          at = i * 4
          (image.rgba[at] * 0.2126 + image.rgba[at + 1] * 0.7152 + image.rgba[at + 2] * 0.0722) / 255.0
        end
      end

      # Circular separable box blur; O(width*height), with wrap for tileable maps.
      def self.blur(values, width, height, radius)
        radius = [[radius.to_i, 1].max, [width, height].min].min
        size = radius * 2 + 1
        rows = Array.new(values.size)
        height.times do |y|
          sum = (-radius..radius).sum { |x| values[y * width + x % width] }
          width.times do |x|
            rows[y * width + x] = sum / size
            sum += values[y * width + (x + radius + 1) % width] - values[y * width + (x - radius) % width]
          end
        end
        result = Array.new(values.size)
        width.times do |x|
          sum = (-radius..radius).sum { |y| rows[(y % height) * width + x] }
          height.times do |y|
            result[y * width + x] = sum / size
            sum += rows[((y + radius + 1) % height) * width + x] - rows[((y - radius) % height) * width + x]
          end
        end
        result
      end

      def self.grayscale_image(values, width, height)
        Image.new(width, height, values.flat_map { |v| c = clamp(v * 255); [c, c, c, 255] })
      end

      def self.auxiliary(image, kind = 'wood', strength = 2.0)
        strength = Float(strength)
        raise 'Cường độ phải từ 0.1 đến 10.' unless strength.finite? && strength.between?(0.1, 10)
        w, h = image.width, image.height
        lum = gray(image)
        low, high = lum.minmax
        range = [high - low, 0.05].max
        heights = lum.map { |v| [[(v - low) / range, 0].max, 1].min }
        base, gain = { 'wood' => [0.2, 0.35], 'stone' => [0.35, 0.45], 'fabric' => [0.1, 0.15], 'metal' => [0.65, 0.3] }.fetch(kind, [0.2, 0.35])
        specular = heights.map { |v| [base + v * gain, 1].min }
        local = blur(heights, w, h, 4)
        ao = heights.each_with_index.map { |v, i| [1.0 - [local[i] - v, 0].max * strength, 0].max }
        normal_gl, normal_dx = [], []
        h.times do |y|
          w.times do |x|
            dx = (heights[y * w + (x + 1) % w] - heights[y * w + (x - 1) % w]) * strength
            dy = (heights[((y + 1) % h) * w + x] - heights[((y - 1) % h) * w + x]) * strength
            length = Math.sqrt(dx * dx + dy * dy + 1)
            r, g, b = clamp((-dx / length + 1) * 127.5), clamp((-dy / length + 1) * 127.5), clamp((1.0 / length + 1) * 127.5)
            normal_gl.concat([r, g, b, 255])
            normal_dx.concat([r, clamp((dy / length + 1) * 127.5), b, 255])
          end
        end
        { '02_Displacement' => grayscale_image(heights, w, h), '03_Specular' => grayscale_image(specular, w, h),
          '04_Normal' => Image.new(w, h, normal_gl), '04_Normal_DirectX' => Image.new(w, h, normal_dx),
          '05_AO' => grayscale_image(ao, w, h) }
      end

      def self.seam_error(image)
        w, h, data = image.width, image.height, image.rgba
        total = 0.0
        h.times { |y| 3.times { |c| total += (data[(y * w) * 4 + c] - data[(y * w + w - 1) * 4 + c]).abs } }
        w.times { |x| 3.times { |c| total += (data[x * 4 + c] - data[((h - 1) * w + x) * 4 + c]).abs } }
        total / (3 * (w + h))
      end

      def self.seamless(image, flatten = 0.5, feather = 0.04)
        flatten, feather = Float(flatten), Float(feather)
        raise 'Thiết lập seamless không hợp lệ.' unless flatten.between?(0, 1) && feather.between?(0, 0.15)
        w, h = image.width, image.height
        raise 'Ảnh cần ít nhất 2×2 pixel.' if w < 2 || h < 2
        data = image.rgba.map(&:to_f)
        if flatten > 0
          lum = gray(image)
          low = blur(lum, w, h, [[w, h].min / 12, 1].max)
          mean = lum.sum / lum.size
          lum.size.times do |i|
            change = (low[i] - mean) * 255 * flatten
            3.times { |c| data[i * 4 + c] -= change }
          end
        end
        # Remove the opposite-boundary color difference as a smooth ramp.
        # This is VGD's boundary-matching method, not the missing N-TEXTURE DLL.
        h.times do |y|
          3.times do |c|
            delta = data[(y * w + w - 1) * 4 + c] - data[y * w * 4 + c]
            w.times { |x| data[(y * w + x) * 4 + c] -= delta * (x.to_f / (w - 1) - 0.5) }
          end
        end
        w.times do |x|
          3.times do |c|
            delta = data[((h - 1) * w + x) * 4 + c] - data[x * 4 + c]
            h.times { |y| data[(y * w + x) * 4 + c] -= delta * (y.to_f / (h - 1) - 0.5) }
          end
        end
        if feather > 0
          3.times do |c|
            channel = Array.new(w * h) { |i| data[i * 4 + c] }
            blurred = blur(channel, w, h, [[w, h].min * feather, 1].max.to_i)
            h.times do |y|
              w.times do |x|
                edge_distance = [x, y, w - x - 1, h - y - 1].min
                blend = [1.0 - edge_distance / ([w, h].min * feather), 0].max * 0.5
                i = y * w + x
                data[i * 4 + c] = data[i * 4 + c] * (1 - blend) + blurred[i] * blend
              end
            end
          end
        end
        # Equal endpoints also for alpha and after clamping/feathering.
        h.times do |y|
          4.times do |c|
            a, b = (y * w) * 4 + c, (y * w + w - 1) * 4 + c
            data[a] = data[b] = (data[a] + data[b]) / 2
          end
        end
        w.times do |x|
          4.times do |c|
            a, b = x * 4 + c, ((h - 1) * w + x) * 4 + c
            data[a] = data[b] = (data[a] + data[b]) / 2
          end
        end
        Image.new(w, h, data.map { |v| clamp(v) })
      end

      # Color quantization and outer-background removal, then directed border
      # tracing. Each loop carries its color; opposite-color edges stay separate.
      def self.contours(image, colors = 4, tolerance = 0.75, background = true)
        levels = Integer(colors)
        raise 'Số mức màu phải từ 2 đến 8.' unless levels.between?(2, 8)
        tolerance = Float(tolerance)
        raise 'Độ đơn giản hóa phải từ 0 đến 10 px.' unless tolerance.finite? && tolerance.between?(0, 10)
        w, h = image.width, image.height
        quantize = lambda { |r, g, b| [r, g, b].map { |v| (v * (levels - 1) / 255.0).round } }
        labels = Array.new(w * h) do |i|
          rgba = image.rgba[i * 4, 4]
          rgba[3] < 32 ? nil : quantize.call(*rgba.first(3))
        end
        bg = [labels[0], labels[w - 1], labels[(h - 1) * w], labels.last].compact.group_by(&:itself).max_by { |_, v| v.size }
        if background && bg
          queue = []
          h.times { |y| queue.concat([y * w, y * w + w - 1]) }
          w.times { |x| queue.concat([x, (h - 1) * w + x]) }
          visited = {}
          until queue.empty?
            i = queue.pop
            next if visited[i] || labels[i] != bg[0]
            visited[i] = true
            labels[i] = nil
            x, y = i % w, i / w
            queue << i - 1 if x > 0
            queue << i + 1 if x < w - 1
            queue << i - w if y > 0
            queue << i + w if y < h - 1
          end
        end
        borders = Hash.new { |hash, color| hash[color] = {} }
        h.times do |y|
          w.times do |x|
            color = labels[y * w + x]
            next unless color
            edges = []
            edges << [[x, y], [x + 1, y]] if y == 0 || labels[(y - 1) * w + x] != color
            edges << [[x + 1, y], [x + 1, y + 1]] if x == w - 1 || labels[y * w + x + 1] != color
            edges << [[x + 1, y + 1], [x, y + 1]] if y == h - 1 || labels[(y + 1) * w + x] != color
            edges << [[x, y + 1], [x, y]] if x == 0 || labels[y * w + x - 1] != color
            edges.each { |a, b| (borders[color][a] ||= []) << b }
          end
        end
        result = []
        borders.each do |color, edges|
          until edges.empty?
            start = edges.keys.first
            loop = [start]
            current = start
            100_000.times do
              targets = edges[current]
              break unless targets && !targets.empty?
              target = targets.pop
              edges.delete(current) if targets.empty?
              loop << target
              current = target
              break if current == start
            end
            next unless loop.size >= 4 && loop.last == start
            simplified = simplify_closed(loop, tolerance)
            next if simplified.size < 4
            result << { points: simplified, color: color.map { |v| (v * 255.0 / (levels - 1)).round } }
            raise 'Ảnh quá phức tạp. Giảm độ phân giải hoặc số màu.' if result.size > 5000
          end
        end
        result
      end

      def self.simplify_line(points, tolerance)
        return points if points.size <= 2
        a, b = points.first, points.last
        dx, dy = b[0] - a[0], b[1] - a[1]
        length_sq = dx * dx + dy * dy
        distances = points.each_with_index.drop(1).take(points.size - 2).map do |p, i|
          t = length_sq.zero? ? 0 : [[((p[0] - a[0]) * dx + (p[1] - a[1]) * dy).to_f / length_sq, 0].max, 1].min
          [Math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy), i]
        end
        farthest = distances.max_by(&:first)
        return [a, b] unless farthest && farthest[0] > tolerance
        i = farthest[1]
        simplify_line(points[0..i], tolerance)[0...-1] + simplify_line(points[i..-1], tolerance)
      end

      def self.simplify_closed(points, tolerance)
        return points if points.size < 5 || tolerance <= 0
        ring = points[0...-1]
        pivot = (1...ring.size).max_by { |i| Math.hypot(ring[i][0] - ring[0][0], ring[i][1] - ring[0][1]) }
        simplify_line(ring[0..pivot], tolerance)[0...-1] + simplify_line(ring[pivot..-1] + [ring[0]], tolerance)
      end
    end
  end
end
