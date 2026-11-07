module VGD
  module BIM
    # Số đo "thân" của món: bỏ những phần nhô ra ngoài thân (tay nắm...) để Rộng / Dài / Cao không bị phình. Hai cách, dùng riêng hoặc cùng nhau:
    #   1. Loại trừ theo từ khóa: group / component / tag có tên chứa một từ khóa (ví dụ "tay nắm") không được tính vào khung bao.
    #   2. Tự cắt phần nhô theo hình học (tùy chọn, tắt mặc định): ở hai trục ngang X, Y, các lớp mặt vuông góc với trục mà diện tích nhỏ
    #      hơn nhiều so với lớp lớn nhất và nằm ở sát đầu mút (nhô ra không quá một phần nhỏ kích thước món) bị coi là phần nhô và bỏ đi.
    #      Không cắt theo trục Z (chân bàn, chân tủ là một phần của chiều cao).
    # Phần này là logic thuần (không gọi SketchUp); phần đo thật nằm ở MeasureProbe. Ngưỡng là giá trị khởi đầu chưa chỉnh trên model thật.
    module Measure
      MAX_WORDS = 12
      MAX_WORD_LENGTH = 40
      MAX_WORDS_TEXT = 200
      AXIAL = 0.95          # mặt vuông góc với trục khi |cosin pháp tuyến với trục| từ mức này trở lên
      AREA_FRACTION = 0.04  # lớp mặt nhỏ hơn tỉ lệ này so với lớp lớn nhất được coi là phần nhô
      TRIM_MAX_RATIO = 0.10 # phần nhô tối đa so với kích thước món theo trục đó
      TRIM_MAX_MM = 150.0   # và tối đa tuyệt đối (mm)
      TRIM_AXES = [0, 1].freeze # chỉ X và Y
      CLUSTER_MM = 0.1      # các mặt cách nhau dưới mức này tính là cùng một lớp
      AXIS_NAMES = %w[X Y Z].freeze

      # Chữ thường, bỏ dấu tiếng Việt, đ -> d, gộp khoảng trắng: để "Tay Nắm" khớp với "tay nam".
      def self.normalize(text)
        text.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '').tr('đĐ', 'dd').downcase.gsub(/\s+/, ' ').strip
      end

      # "tay nắm, Handle; knob" -> ["tay nam", "handle", "knob"]. Ném lỗi nếu quá dài hoặc quá nhiều từ.
      def self.parse_words(text)
        raise ArgumentError, "Danh sách từ khóa tối đa #{MAX_WORDS_TEXT} ký tự." if text.to_s.length > MAX_WORDS_TEXT
        words = text.to_s.split(/[,;\n]/).map { |word| normalize(word) }.reject(&:empty?).uniq
        raise ArgumentError, "Tối đa #{MAX_WORDS} từ khóa, mỗi từ không quá #{MAX_WORD_LENGTH} ký tự." if words.size > MAX_WORDS || words.any? { |word| word.length > MAX_WORD_LENGTH }
        words
      end

      # Tên nào trong danh sách chứa một từ khóa (đã chuẩn hóa) thì khớp. Trả về từ khóa khớp hoặc nil.
      def self.match(words, *names)
        return nil if words.empty?
        texts = names.map { |name| normalize(name) }.reject(&:empty?)
        words.find { |word| texts.any? { |text| text.include?(word) } }
      end

      # faces: danh sách {n: [x, y, z] pháp tuyến đơn vị, c: [x, y, z] tâm mặt (mm), a: diện tích mm², lo: [x, y, z], hi: [x, y, z] (mm)}
      # trong khung cục bộ của định nghĩa. Trả về {lo: [x, y, z], hi: [x, y, z], trimmed: [[bớt đầu nhỏ, bớt đầu lớn] mỗi trục]} (mm).
      # Không có mặt nào thì trả về nil.
      def self.body_extents(faces)
        return nil if faces.empty?
        lo = (0..2).map { |axis| faces.map { |face| face[:lo][axis] }.min }
        hi = (0..2).map { |axis| faces.map { |face| face[:hi][axis] }.max }
        trimmed = Array.new(3) { [0.0, 0.0] }
        TRIM_AXES.each do |axis|
          new_lo, new_hi = trim_axis(faces, axis, lo[axis], hi[axis])
          trimmed[axis] = [new_lo - lo[axis], hi[axis] - new_hi]
          lo[axis] = new_lo
          hi[axis] = new_hi
        end
        {lo: lo, hi: hi, trimmed: trimmed}
      end

      # Với một trục: tìm các lớp mặt vuông góc với trục (cùng vị trí), bỏ các lớp nhỏ ở sát hai đầu nếu bỏ đi không quá mức cho phép.
      def self.trim_axis(faces, axis, lo, hi)
        extent = hi - lo
        allowance = [extent * TRIM_MAX_RATIO, TRIM_MAX_MM].min
        layers = Hash.new(0.0)
        faces.each do |face|
          next unless face[:n][axis].abs >= AXIAL
          layers[(face[:c][axis] / CLUSTER_MM).round] += face[:a]
        end
        return [lo, hi] if layers.empty?
        biggest = layers.values.max
        keep = layers.select { |_, area| area >= biggest * AREA_FRACTION }.keys.map { |key| key * CLUSTER_MM }
        new_hi = keep.max
        new_lo = keep.min
        new_hi = hi if new_hi.nil? || hi - new_hi > allowance || new_hi > hi
        new_lo = lo if new_lo.nil? || new_lo - lo > allowance || new_lo < lo
        [new_lo, new_hi]
      end

      # Ghi chú ngắn cho cột "Ghi chú số đo": các phần đã loại theo từ khóa và các chỗ đã cắt nhô (mm).
      def self.note(excluded_names, trimmed)
        parts = []
        parts << "Bỏ #{excluded_names.size} phần theo từ khóa (#{excluded_names.uniq.first(3).join(', ')}#{excluded_names.uniq.size > 3 ? '…' : ''})" unless excluded_names.empty?
        TRIM_AXES.each do |axis|
          low, high = trimmed[axis]
          parts << "cắt nhô -#{AXIS_NAMES[axis]} #{low.round} mm" if low >= 0.5
          parts << "cắt nhô +#{AXIS_NAMES[axis]} #{high.round} mm" if high >= 0.5
        end
        parts.join('; ')
      end
    end
  end
end
