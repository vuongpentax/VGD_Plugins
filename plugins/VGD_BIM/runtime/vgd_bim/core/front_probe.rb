require_relative 'front'

module VGD
  module BIM
    # Phần gọi SketchUp của việc tìm mặt trước: đo mặt (pháp tuyến, tâm, diện tích) trong khung cục bộ của món, bắn tia ngang ra bốn phía
    # để biết mặt nào sát tường, rồi đưa số đo cho Front.analyze chọn. Chỉ đọc model, không sửa gì. Chưa kiểm được trong SketchUp thật
    # (chỉ có test với model giả lập, xem dev/test_front_probe.rb).
    module FrontProbe
      MAX_FACES = 4000        # số mặt tối đa đọc cho một món; nhiều hơn thì dừng và ghi chú "lấy mẫu"
      RAY_COUNT = 3           # số tia cho mỗi mặt, lấy giá trị giữa để một cột / tay nắm nhô ra không làm sai
      RAY_OFFSET_MM = 5.0     # điểm bắt đầu tia cách mặt khung bao ra ngoài mức này để không trúng chính món đồ
      ARROW_LENGTH = 0.7      # chiều dài mũi tên so với kích thước món theo hướng mặt trước
      ARROW_HEAD = 0.4        # phần đầu tam giác so với chiều dài mũi tên
      ARROW_WIDTH = 0.3       # nửa bề rộng đầu mũi tên so với kích thước món theo chiều ngang
      ARROW_SHAFT = 0.38      # nửa bề rộng thân so với nửa bề rộng đầu
      ARROW_LIFT = 3.0        # độ nhích lên khỏi mặt trên (mm)

      # record: một phần tử của Table.build (:entity, :transform). Trả về kết quả của Front.analyze (xem front.rb) hoặc nil nếu món rỗng.
      def self.measure(model, record)
        entity = record[:entity]
        world = record[:transform]
        definition = Geometry.definition(entity)
        box = definition.bounds
        return nil if box.empty?
        axes = axes_of(world)
        faces, sampled = local_faces(definition, box)
        size = [box.width, box.height, box.depth].map { |v| v.to_f * Geometry::INCH_MM }
        free = model.respond_to?(:raytest) ? ray_distances(model, world, box, axes) : nil
        result = Front.analyze(faces: faces, size: size, free: free, upright: axes[2][2] > 0.99, mirrored: mirrored?(axes), dynamic: dynamic?(entity, definition))
        result[:notes] << "chỉ đọc #{MAX_FACES} mặt đầu tiên của món (lấy mẫu)" if sampled
        result
      end

      # Hướng nhìn của camera làm mặt trước: từ món tới mắt nhìn (chỉ thành phần ngang), đổi sang hướng cục bộ của món.
      def self.camera_direction(view, record)
        axes = axes_of(record[:transform])
        center = record[:transform] * local_center(record[:entity])
        eye = view.camera.eye
        Front.local_direction([eye.x - center.x, eye.y - center.y, 0.0], axes[0], axes[1])
      end

      # Hướng mặt trước của món trong thế giới: vector ngang đơn vị [x, y], hoặc nil nếu chưa có mặt trước / không có hướng ngang.
      def self.front_world(record)
        return nil unless record[:transform]
        dir = Front.read(Geometry.definition(record[:entity]))[:dir]
        return nil unless dir
        axes = axes_of(record[:transform])
        x, y, = Front.world_vector(dir, axes[0], axes[1])
        length = Math.sqrt(x * x + y * y)
        length < 1e-9 ? nil : [x / length, y / length]
      end

      # Mũi tên mặt trước nằm trên mặt trên của khung bao, để nhìn rõ trên mặt bằng. Trả về [tam giác tô (mỗi 3 điểm một tam giác),
      # đường viền (cặp điểm)] theo tọa độ thế giới; rỗng nếu chưa có mặt trước hoặc món rỗng.
      def self.arrow_shapes(record, dir)
        return [[], []] unless Front.valid?(dir)
        box = Geometry.definition(record[:entity]).bounds
        return [[], []] if box.empty?
        vx, vy = Front::VECTORS.fetch(dir)
        px = -vy
        py = vx
        along = (vx != 0 ? box.width : box.height).to_f   # kích thước theo hướng mũi tên
        across = (vx != 0 ? box.height : box.width).to_f  # kích thước ngang mũi tên
        length = along * ARROW_LENGTH
        head = length * ARROW_HEAD
        head_half = [across * ARROW_WIDTH, head * 0.7].min
        shaft_half = head_half * ARROW_SHAFT
        center = box.center
        z = box.max.z + ARROW_LIFT / Geometry::INCH_MM # nhích lên một chút để không đè lên mặt trên (tránh nhấp nháy)
        at = ->(forward, side) { Geom::Point3d.new(center.x + vx * forward + px * side, center.y + vy * forward + py * side, z) }
        base = -length / 2.0
        neck = length / 2.0 - head
        tip = length / 2.0
        corners = {a: at.call(base, shaft_half), b: at.call(neck, shaft_half), c: at.call(neck, head_half), t: at.call(tip, 0.0),
                   d: at.call(neck, -head_half), e: at.call(neck, -shaft_half), f: at.call(base, -shaft_half)}
        fills = [corners[:a], corners[:b], corners[:e], corners[:a], corners[:e], corners[:f], corners[:c], corners[:t], corners[:d]]
        ring = %i[a b c t d e f].map { |key| corners[key] }
        lines = ring.each_with_index.flat_map { |point, i| [point, ring[(i + 1) % ring.size]] }
        world = record[:transform]
        [fills.map { |point| point.transform(world) }, lines.map { |point| point.transform(world) }]
      end

      # ---- Chi tiết ----

      # Trục X, Y, Z của món trong thế giới, đã chuẩn hóa (mảng số).
      def self.axes_of(world)
        [world.xaxis, world.yaxis, world.zaxis].map do |axis|
          values = axis.to_a
          length = Math.sqrt(values.sum { |v| v * v })
          length.zero? ? [0.0, 0.0, 0.0] : values.map { |v| v / length }
        end
      end

      # Hệ trục tay trái (lật gương): X x Y ngược chiều Z.
      def self.mirrored?(axes)
        x, y, z = axes
        cross = [x[1] * y[2] - x[2] * y[1], x[2] * y[0] - x[0] * y[2], x[0] * y[1] - x[1] * y[0]]
        Front.dot(cross, z) < 0
      end

      def self.dynamic?(entity, definition)
        [entity, definition].any? { |e| e.respond_to?(:attribute_dictionary) && e.attribute_dictionary('dynamic_attributes') }
      end

      def self.local_center(entity)
        Geometry.definition(entity).bounds.center
      end

      # Mọi mặt của món (kể cả trong group / component lồng nhau) trong khung cục bộ, tâm tính từ góc nhỏ nhất của khung bao (mm).
      def self.local_faces(definition, box)
        faces = []
        sampled = false
        origin = box.min
        catch(:enough) do
          Scanner.walk(definition.entities, Geom::Transformation.new, [], [], nil, false, faces: true) do |record|
            face = record[:entity]
            next unless face.is_a?(Sketchup::Face)
            if faces.size >= MAX_FACES
              sampled = true
              throw :enough
            end
            transform = record[:transform]
            normal = face.normal.transform(transform).to_a
            length = Math.sqrt(normal.sum { |v| v * v })
            next if length.zero?
            center = face.bounds.center.transform(transform)
            faces << {n: normal.map { |v| v / length },
                      c: [(center.x - origin.x) * Geometry::INCH_MM, (center.y - origin.y) * Geometry::INCH_MM, (center.z - origin.z) * Geometry::INCH_MM],
                      a: face.area(transform).to_f * Geometry::INCH_MM**2}
          end
        end
        [faces, sampled]
      end

      # Khoảng thoáng (mm) ở bốn phía: bắn RAY_COUNT tia ngang từ giữa chiều cao, lấy giá trị giữa. Tia không chạm gì thì bằng FREE_MAX.
      def self.ray_distances(model, world, box, axes)
        center = box.center
        half = {x: box.width.to_f / 2.0, y: box.height.to_f / 2.0}
        offset = RAY_OFFSET_MM / Geometry::INCH_MM
        Front::DIRECTIONS.to_h do |dir|
          vx, vy = Front::VECTORS.fetch(dir)
          along = vx != 0 ? :y : :x # chạy dọc theo mặt đang xét
          direction = Geom::Vector3d.new(*Front.world_vector(dir, *axes[0, 2]))
          distances = RAY_COUNT.times.map do |i|
            shift = half[along] * (i / (RAY_COUNT - 1.0) - 0.5) # ba tia: giữa mặt và hai bên một nửa nửa-chiều-rộng
            local = Geom::Point3d.new(center.x + vx * (half[:x] + offset) + (along == :x ? shift : 0.0),
                                      center.y + vy * (half[:y] + offset) + (along == :y ? shift : 0.0), center.z)
            start = local.transform(world)
            hit = model.raytest([start, direction], true)
            hit ? [start.distance(hit[0]) * Geometry::INCH_MM, Front::FREE_MAX].min : Front::FREE_MAX
          end
          [dir, distances.sort[RAY_COUNT / 2]]
        end
      end
    end
  end
end
