require_relative 'geometry'

module VGD
  module BIM
    # Phần gọi SketchUp của việc dò phòng từ tường (thuật toán ở room_detect.rb): đọc các mặt đứng của những đối tượng đang chọn (đi sâu vào group và
    # component), cắt chúng bằng mặt phẳng nằm ngang ở độ cao cắt (tính từ chân tường thấp nhất) và trả về các đoạn thẳng (mm, tọa độ thế giới).
    # CHỈ ĐỌC: không đổi model, không thêm hình. Chưa kiểm được trong SketchUp thật (chỉ có test với model giả lập, xem dev/test_room_detect_probe.rb).
    module RoomDetectProbe
      DEFAULT_CUT = 2400.0    # mm: độ cao cắt mặc định tính từ chân tường (cao hơn cửa đi thông thường)
      MIN_CUT = 100.0
      MAX_CUT = 20_000.0
      MAX_FACES = 30_000      # số mặt tối đa đọc; nhiều hơn thì dừng và báo (model quá nặng, hãy chọn ít tường hơn)
      MAX_DEPTH = 12          # độ sâu lồng group / component tối đa
      VERTICAL_NZ = 0.05      # mặt có thành phần đứng của pháp tuyến nhỏ hơn mức này (khoảng 3 độ) coi là mặt đứng

      # entities: các đối tượng đang chọn; context: biến đổi (cục bộ -> thế giới) của group đang mở sửa; cut_mm: độ cao cắt tính từ chân tường.
      # Trả về {segments:, floor:, top:, faces:, walls:, truncated:}: floor / top là Z thấp nhất / cao nhất (mm) của các mặt đứng, walls là số mặt đứng
      # bị mặt phẳng cắt cắt trúng, faces là số mặt đứng đọc được.
      def self.read(entities, context, cut_mm)
        raise ArgumentError, 'Độ cao cắt phải là số lớn hơn 0.' unless cut_mm.is_a?(Numeric) && cut_mm.finite? && cut_mm.positive?
        loops = []
        state = {count: 0, truncated: false}
        entities.each { |entity| collect(entity, context, loops, state, 0) }
        return {segments: [], floor: nil, top: nil, faces: 0, walls: 0, truncated: state[:truncated]} if loops.empty?
        zs = loops.flatten(2).map { |p| p[2] }
        floor = zs.min
        plane = floor + cut_mm
        segments = []
        walls = 0
        loops.each do |face_loops|
          found = slice(face_loops, plane)
          next if found.empty?
          walls += 1
          segments.concat(found)
        end
        {segments: segments, floor: floor, top: zs.max, faces: loops.size, walls: walls, truncated: state[:truncated]}
      end

      # Gom vòng của mọi mặt đứng: mỗi phần tử là danh sách vòng (vòng ngoài đầu tiên), mỗi vòng là danh sách điểm [x, y, z] mm thế giới.
      def self.collect(entity, transform, out, state, depth)
        return if state[:truncated] || visible?(entity) == false
        case entity
        when Sketchup::Face
          state[:count] += 1
          return state[:truncated] = true if state[:count] > MAX_FACES
          face_loops = [entity.outer_loop, *entity.loops.reject { |l| l.equal?(entity.outer_loop) }].map { |lp| lp.vertices.map { |v| to_mm(transform * v.position) } }
          out << face_loops if vertical?(face_loops.first)
        when Sketchup::Group
          descend(entity.entities, transform * entity.transformation, out, state, depth)
        when Sketchup::ComponentInstance
          descend(entity.definition.entities, transform * entity.transformation, out, state, depth)
        end
      end

      def self.descend(children, transform, out, state, depth)
        return if depth >= MAX_DEPTH
        children.each { |child| collect(child, transform, out, state, depth + 1) }
      end

      def self.visible?(entity)
        return false if entity.respond_to?(:hidden?) && entity.hidden?
        return false if entity.respond_to?(:layer) && entity.layer && entity.layer.respond_to?(:visible?) && !entity.layer.visible?
        true
      end

      def self.to_mm(point)
        [point.x.to_f * Geometry::INCH_MM, point.y.to_f * Geometry::INCH_MM, point.z.to_f * Geometry::INCH_MM]
      end

      # Mặt đứng: pháp tuyến tính từ vòng ngoài bằng công thức Newell (đúng cả khi mặt lõm), thành phần Z nhỏ so với độ dài.
      def self.vertical?(ring)
        return false if ring.size < 3
        nx = ny = nz = 0.0
        ring.each_index do |i|
          a = ring[i]
          b = ring[(i + 1) % ring.size]
          nx += (a[1] - b[1]) * (a[2] + b[2])
          ny += (a[2] - b[2]) * (a[0] + b[0])
          nz += (a[0] - b[0]) * (a[1] + b[1])
        end
        length = Math.sqrt(nx * nx + ny * ny + nz * nz)
        length > 1.0e-9 && nz.abs / length < VERTICAL_NZ
      end

      # Giao của một mặt đứng (các vòng) với mặt phẳng z = plane: các điểm cắt của mọi cạnh được sắp dọc theo đường giao rồi ghép đôi theo quy tắc
      # chẵn lẻ, nên lỗ cửa bị cắt qua sẽ để lại khoảng hở đúng chỗ. Trả về [[x1, y1, x2, y2], ...].
      def self.slice(face_loops, plane)
        crossings = []
        face_loops.each do |ring|
          ring.each_index do |i|
            a = ring[i]
            b = ring[(i + 1) % ring.size]
            next unless (a[2] < plane) != (b[2] < plane)
            t = (plane - a[2]) / (b[2] - a[2])
            crossings << [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]
          end
        end
        return [] if crossings.size < 2 || crossings.size.odd?
        far = crossings.max_by { |p| Math.hypot(p[0] - crossings[0][0], p[1] - crossings[0][1]) }
        dx = far[0] - crossings[0][0]
        dy = far[1] - crossings[0][1]
        length = Math.hypot(dx, dy)
        return [] if length < 1.0e-6
        sorted = crossings.sort_by { |p| ((p[0] - crossings[0][0]) * dx + (p[1] - crossings[0][1]) * dy) / length }
        sorted.each_slice(2).map { |a, b| [a[0], a[1], b[0], b[1]] }
      end
    end
  end
end
