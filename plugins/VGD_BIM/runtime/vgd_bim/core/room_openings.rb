module VGD
  module BIM
    # Trừ cửa đi / cửa sổ khỏi diện tích tường hoàn thiện của phòng (cột mốc 3c). Logic thuần, không gọi SketchUp: nhận các ô cửa đã đo (mm, tọa độ thế giới)
    # và danh sách phòng, trả về số cửa và diện tích cửa của từng phòng. Một ô cửa thuộc phòng khi tâm của nó (mặt bằng) cách một cạnh của viền phòng
    # (hoặc viền lỗ) không quá REACH và khoảng cao của nó chồng lên khoảng cao của phòng; cửa giữa hai phòng được trừ cho cả hai bên (mỗi bên một mặt tường).
    module RoomOpenings
      REACH = 400.0          # mm: tâm cửa nằm trong bề dày tường, cách mặt tường phía phòng tối đa nửa tường dày + độ lệch của cửa
      MAX_COUNT = 10_000     # số cửa tối đa ghi cho một phòng
      MAX_AREA = 1.0e6       # m2
      MAX_TAGS = 50
      MAX_TAG_LENGTH = 100
      CONTROL = /[\u0000-\u001f\u007f]/

      # openings: [{x:, y:, z0:, z1:, width:, height:, exact:}] (mm; exact = số đo lỗ chính xác của VGD Structure, false = ước tính theo khung bao).
      # rooms: danh sách đã qua Rooms.sanitize! / Rooms.read. Trả về {rooms: {id => {'count', 'area' (m2), 'estimated'}}, unmatched: số cửa không thuộc phòng nào}.
      def self.match(openings, rooms)
        result = {}
        unmatched = 0
        openings.each do |opening|
          hits = rooms.select { |room| belongs?(opening, room) }
          unmatched += 1 if hits.empty?
          hits.each do |room|
            entry = result[room['id']] ||= {'count' => 0, 'area' => 0.0, 'estimated' => 0}
            entry['count'] += 1
            entry['area'] += opening[:width] * effective_height(opening, room) / 1.0e6
            entry['estimated'] += 1 unless opening[:exact]
          end
        end
        result.each_value { |entry| entry['area'] = entry['area'].round(3) }
        {rooms: result, unmatched: unmatched}
      end

      def self.belongs?(opening, room)
        return false unless effective_height(opening, room).positive?
        rings = [room['boundary'], *Array(room['holes'])]
        rings.any? { |ring| ring.each_index.any? { |i| segment_distance(opening[:x], opening[:y], ring[i], ring[(i + 1) % ring.size]) <= REACH } }
      end

      # Chiều cao cửa nằm trong khoảng sàn - trần của phòng (cửa cao hơn trần chỉ trừ phần trong phòng).
      def self.effective_height(opening, room)
        floor = room['elevation']
        top = floor + room['height']
        overlap = [opening[:z1], top].min - [opening[:z0], floor].max
        overlap.positive? ? [opening[:height], overlap].min : 0.0
      end

      def self.segment_distance(px, py, a, b)
        dx = b[0] - a[0]
        dy = b[1] - a[1]
        length2 = dx * dx + dy * dy
        t = length2.zero? ? 0.0 : (((px - a[0]) * dx + (py - a[1]) * dy).to_f / length2).clamp(0.0, 1.0)
        Math.hypot(a[0] + dx * t - px, a[1] + dy * t - py)
      end

      # Danh sách tên tag cửa do giao diện gửi lên: chuỗi khác rỗng, không trùng, không phải tag mặc định.
      def self.tags!(value)
        raise ArgumentError, 'Danh sách tag cửa không hợp lệ.' unless value.is_a?(Array) && value.all? { |name| name.is_a?(String) }
        names = value.map(&:strip).reject(&:empty?).uniq
        raise ArgumentError, 'Hãy chọn ít nhất một tag của cửa đi / cửa sổ.' if names.empty?
        raise ArgumentError, "Tối đa #{MAX_TAGS} tag cửa, mỗi tên không quá #{MAX_TAG_LENGTH} ký tự." if names.size > MAX_TAGS || names.any? { |name| name.length > MAX_TAG_LENGTH || name.match?(CONTROL) }
        raise ArgumentError, 'Không chọn được tag Untagged làm tag cửa.' if names.any? { |name| %w[Untagged Layer0].include?(name) }
        names
      end

      # Dữ liệu cửa đã trừ lưu trong phòng ('openings'); nil nếu chưa trừ. Dùng trong Rooms.sanitize!.
      def self.record!(value, name)
        return nil if value.nil?
        bad = -> { raise ArgumentError, "Dữ liệu cửa đã trừ của #{name} không hợp lệ." }
        bad.call unless value.is_a?(Hash)
        count = value['count']
        area = value['area']
        estimated = value['estimated'] || 0
        bad.call unless count.is_a?(Integer) && count.between?(0, MAX_COUNT) && estimated.is_a?(Integer) && estimated.between?(0, count)
        bad.call unless area.is_a?(Numeric) && area.finite? && area.between?(0, MAX_AREA)
        tags = value['tags'] || []
        bad.call unless tags.is_a?(Array) && tags.size <= MAX_TAGS && tags.all? { |tag| tag.is_a?(String) && !tag.empty? && tag.length <= MAX_TAG_LENGTH && !tag.match?(CONTROL) }
        {'count' => count, 'area' => area.to_f.round(3), 'estimated' => estimated, 'tags' => tags}
      end
    end
  end
end
