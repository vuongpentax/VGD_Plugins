require 'json'
require 'securerandom'
require_relative 'levels'

module VGD
  module BIM
    # Phòng (Room / Space): khoảng không gian bao bởi sàn, tường, trần. VGD_BIM giữ DỮ LIỆU và SỐ ĐO của phòng; khối 3D do plugin VGD_Room dựng
    # (xem docs/vgd_bim/ROADMAP.md, cột mốc 2). Danh sách phòng lưu trong file SketchUp (dictionary VGD_BIM_MODEL, khóa `rooms`, JSON):
    # id rm_xxxxxxxx ổn định, tên, mã phòng, tầng (id tầng), cao độ sàn (mm), chiều cao (mm), viền (đa giác phẳng, mm, XY thế giới),
    # hoàn thiện sàn / tường / trần (chữ). Món thuộc phòng bằng nhãn ở dictionary riêng VGD_BIM_LOC (khóa `room`). Không dời hình học.
    module Rooms
      DICTIONARY = 'VGD_BIM_MODEL'.freeze
      KEY = 'rooms'.freeze
      ENTITY_DICTIONARY = 'VGD_BIM_LOC'.freeze
      ENTITY_KEY = 'room'.freeze
      MAX_ROOMS = 500
      MAX_NAME = 60
      MAX_TEXT = 60
      MAX_POINTS = 200
      MAX_HEIGHT = 100_000
      MIN_AREA = 10_000.0 # mm2 (0,01 m2): nhỏ hơn coi như viền suy biến
      LEVEL_FLAT = 1.0    # mm: các điểm của mặt sàn phải cùng cao độ
      TOLERANCE = 50      # mm: món đặt hơi thấp hơn sàn phòng vẫn thuộc phòng
      ID_PATTERN = /\Arm_[0-9a-f]{8}\z/
      CONTROL = /[\u0000-\u001f\u007f]/

      # ---- Hình học (mm) ----
      def self.polygon_area(points)
        sum = 0.0
        points.each_with_index { |(x1, y1), i| x2, y2 = points[(i + 1) % points.size]; sum += x1 * y2 - x2 * y1 }
        sum.abs / 2.0
      end

      def self.polygon_perimeter(points)
        points.each_with_index.sum { |(x1, y1), i| x2, y2 = points[(i + 1) % points.size]; Math.hypot(x2 - x1, y2 - y1) }
      end

      def self.cross(ax, ay, bx, by, cx, cy)
        (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
      end

      def self.on_segment?(ax, ay, bx, by, px, py)
        px.between?([ax, bx].min, [ax, bx].max) && py.between?([ay, by].min, [ay, by].max)
      end

      def self.segments_cross?(a, b, c, d)
        d1 = cross(*c, *d, *a); d2 = cross(*c, *d, *b); d3 = cross(*a, *b, *c); d4 = cross(*a, *b, *d)
        return true if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))
        (d1.zero? && on_segment?(*c, *d, *a)) || (d2.zero? && on_segment?(*c, *d, *b)) || (d3.zero? && on_segment?(*a, *b, *c)) || (d4.zero? && on_segment?(*a, *b, *d))
      end

      # Đa giác tự cắt (cạnh không kề nhau chạm hoặc cắt nhau) thì diện tích và thể tích không đáng tin.
      def self.self_intersecting?(points)
        n = points.size
        n.times do |i|
          ((i + 1)...n).each do |j|
            next if j == i + 1 || (i.zero? && j == n - 1)
            return true if segments_cross?(points[i], points[(i + 1) % n], points[j], points[(j + 1) % n])
          end
        end
        false
      end

      def self.contains?(points, x, y)
        inside = false
        points.each_with_index do |(x1, y1), i|
          x2, y2 = points[(i + 1) % points.size]
          inside = !inside if (y1 > y) != (y2 > y) && x < (x2 - x1) * (y - y1) / (y2 - y1) + x1
        end
        inside
      end

      # ---- Kiểm tra dữ liệu ----
      def self.sanitize!(list)
        raise ArgumentError, 'Danh sách phòng không hợp lệ.' unless list.is_a?(Array)
        raise ArgumentError, "Chỉ có tối đa #{MAX_ROOMS} phòng." if list.size > MAX_ROOMS
        names = {}
        numbers = {}
        list.map do |item|
          raise ArgumentError, 'Danh sách phòng không hợp lệ.' unless item.is_a?(Hash)
          name = item['name'].is_a?(String) ? item['name'].strip : ''
          raise ArgumentError, "Hãy nhập tên phòng (tối đa #{MAX_NAME} ký tự, không có ký tự điều khiển)." if name.empty? || name.length > MAX_NAME || name.match?(CONTROL)
          raise ArgumentError, "Tên phòng trùng nhau: #{name}." if names[name.downcase]
          names[name.downcase] = true
          number = text!(item['number'], "Giá trị mã phòng của #{name}")
          raise ArgumentError, "Mã phòng trùng nhau: #{number}." if !number.empty? && numbers[number.downcase]
          numbers[number.downcase] = true
          id = item['id']
          raise ArgumentError, 'Mã nội bộ của phòng không hợp lệ.' unless id.nil? || (id.is_a?(String) && id.match?(ID_PATTERN))
          level = item['level'].nil? ? '' : item['level']
          raise ArgumentError, "Mã tầng của #{name} không hợp lệ." unless level.is_a?(String) && (level.empty? || level.match?(Levels::ID_PATTERN))
          height = item['height']
          raise ArgumentError, "Giá trị chiều cao của #{name} phải là số lớn hơn 0 và không quá #{MAX_HEIGHT} mm." unless height.is_a?(Numeric) && height.finite? && height.positive? && height <= MAX_HEIGHT
          elevation = item['elevation']
          raise ArgumentError, "Giá trị cao độ sàn của #{name} phải là số từ #{Levels::ELEVATION_RANGE.first} đến #{Levels::ELEVATION_RANGE.last} mm." unless elevation.is_a?(Numeric) && elevation.finite? && Levels::ELEVATION_RANGE.cover?(elevation)
          {'id' => id || "rm_#{SecureRandom.hex(4)}", 'name' => name, 'number' => number, 'level' => level, 'height' => height.round(1).to_f, 'elevation' => elevation.round(1).to_f,
           'boundary' => boundary!(item['boundary'], name), 'finish_floor' => finish!(item['finish_floor'], name), 'finish_wall' => finish!(item['finish_wall'], name),
           'finish_ceiling' => finish!(item['finish_ceiling'], name)}
        end
      end

      def self.text!(value, title)
        text = value.nil? ? '' : value
        raise ArgumentError, "#{title} tối đa #{MAX_TEXT} ký tự và không có ký tự điều khiển." unless text.is_a?(String) && text.strip.length <= MAX_TEXT && !text.match?(CONTROL)
        text.strip
      end

      def self.finish!(value, name)
        text!(value, "Vật liệu hoàn thiện của #{name}")
      rescue ArgumentError
        raise ArgumentError, "Vật liệu hoàn thiện của #{name} tối đa #{MAX_TEXT} ký tự và không có ký tự điều khiển."
      end

      def self.boundary!(points, name)
        fail_boundary = ->(why) { raise ArgumentError, "Giá trị viền của #{name} không hợp lệ: #{why}." }
        fail_boundary.call("cần từ 3 đến #{MAX_POINTS} điểm") unless points.is_a?(Array) && points.size.between?(3, MAX_POINTS)
        clean = points.map do |point|
          fail_boundary.call('mỗi điểm gồm hai số X, Y (mm)') unless point.is_a?(Array) && point.size == 2 && point.all? { |v| v.is_a?(Numeric) && v.finite? && v.abs <= 1.0e8 }
          [point[0].round(1).to_f, point[1].round(1).to_f]
        end
        fail_boundary.call('diện tích quá nhỏ hoặc các điểm thẳng hàng') if polygon_area(clean) < MIN_AREA
        fail_boundary.call('các cạnh tự cắt nhau') if self_intersecting?(clean)
        clean
      end

      # ---- Lưu trong model ----
      def self.read(model)
        return [] unless model.respond_to?(:get_attribute)
        raw = model.get_attribute(DICTIONARY, KEY).to_s
        return [] if raw.empty?
        sanitize!(JSON.parse(raw))
      rescue JSON::ParserError, ArgumentError
        []
      end

      def self.write(model, list)
        return false unless model.respond_to?(:set_attribute) && model.respond_to?(:start_operation)
        clean = sanitize!(list)
        return true if clean == read(model)
        model.start_operation('VGD_BIM · Phòng', true, false, true)
        begin
          model.set_attribute(DICTIONARY, KEY, JSON.generate(clean))
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end
        true
      end

      # ---- Số đo ----
      def self.metrics(room)
        area = polygon_area(room['boundary'])
        perimeter = polygon_perimeter(room['boundary'])
        {area: (area / 1.0e6).round(3), perimeter: (perimeter / 1000.0).round(3), volume: (area * room['height'] / 1.0e9).round(3),
         wall_area: (perimeter * room['height'] / 1.0e6).round(3), ceiling_area: (area / 1.0e6).round(3)}
      end

      # ---- Khối phòng do plugin VGD_Room dựng (cầu nối room_volume, docs/vgd_bim/BRIDGE.md) ----
      SOURCE_DICTIONARY = 'VGD_BIM_SOURCE'.freeze

      # Đối tượng là khối phòng do plugin dựng: không tính khối lượng.
      def self.volume_entity?(entity)
        entity.respond_to?(:get_attribute) && entity.get_attribute(SOURCE_DICTIONARY, 'kind') == 'room'
      end

      # ---- Món thuộc phòng ----
      def self.entity_room(entity)
        return '' unless entity.respond_to?(:get_attribute)
        value = entity.get_attribute(ENTITY_DICTIONARY, ENTITY_KEY)
        value.is_a?(String) && value.match?(ID_PATTERN) ? value : ''
      end

      def self.assign(entity, id)
        raise ArgumentError, 'Mã phòng không hợp lệ.' unless id.is_a?(String) && (id.empty? || id.match?(ID_PATTERN))
        raise ArgumentError, 'Đối tượng không hỗ trợ gán phòng.' unless entity.respond_to?(:set_attribute) && entity.respond_to?(:locked?)
        raise ArgumentError, 'Đối tượng đang bị khóa.' if entity.locked?
        id.empty? ? entity.delete_attribute(ENTITY_DICTIONARY, ENTITY_KEY) : entity.set_attribute(ENTITY_DICTIONARY, ENTITY_KEY, id)
      end

      # items: [{index:, x:, y:, z:, locked:}] (tâm đáy món, mm). Món thuộc phòng đầu tiên chứa nó trong viền và trong khoảng cao của phòng.
      def self.plan_auto(items, rooms)
        plan = {assign: {}, locked: [], none: []}
        items.each do |item|
          if item[:locked] then plan[:locked] << item[:index]; next end
          found = %i[x y z].all? { |k| item[k].is_a?(Numeric) && item[k].finite? } && rooms.find do |room|
            item[:z] >= room['elevation'] - TOLERANCE && item[:z] <= room['elevation'] + room['height'] && contains?(room['boundary'], item[:x], item[:y])
          end
          found ? plan[:assign][item[:index]] = found['id'] : plan[:none] << item[:index]
        end
        plan
      end

      # Viền từ các điểm 3D (mm) của một mặt nằm ngang: bỏ Z (lấy làm cao độ sàn), bỏ điểm trùng và điểm thẳng hàng thừa.
      def self.boundary_from_points(points3)
        raise ArgumentError, 'Mặt phải có ít nhất 3 điểm.' unless points3.is_a?(Array) && points3.size >= 3
        z = points3.first[2].to_f
        raise ArgumentError, 'Mặt chọn phải nằm ngang (các điểm cùng cao độ).' unless points3.all? { |p| (p[2].to_f - z).abs <= LEVEL_FLAT }
        flat = points3.map { |p| [p[0].to_f, p[1].to_f] }
        flat = flat.each_with_index.reject { |p, i| p == flat[(i + 1) % flat.size] }.map(&:first)
        flat = flat.each_with_index.reject do |p, i|
          prev = flat[i - 1]
          nxt = flat[(i + 1) % flat.size]
          cross(*prev, *p, *nxt).abs < 1.0 # thẳng hàng (diện tích tam giác ~ 0)
        end.map(&:first)
        {boundary: flat, elevation: z.round(1)}
      end
    end
  end
end
