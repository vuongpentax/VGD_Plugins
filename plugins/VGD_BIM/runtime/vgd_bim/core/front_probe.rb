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
      ARROW_MIN_MM = 300.0    # chiều dài tối thiểu của mũi tên chỉ mặt trước

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

      # Mũi tên chỉ mặt trước: các đoạn thẳng (cặp điểm) theo tọa độ thế giới, để vẽ cùng khung đánh dấu. Rỗng nếu món rỗng.
      def self.arrow_points(record, dir)
        return [] unless Front.valid?(dir)
        definition = Geometry.definition(record[:entity])
        box = definition.bounds
        return [] if box.empty?
        world = record[:transform]
        vx, vy = Front::VECTORS.fetch(dir)
        center = box.center
        reach = (vx != 0 ? box.width : box.height).to_f / 2.0
        length = [reach, ARROW_MIN_MM / Geometry::INCH_MM].max
        start = Geom::Point3d.new(center.x + vx * reach, center.y + vy * reach, center.z)
        tip = Geom::Point3d.new(start.x + vx * length, start.y + vy * length, start.z)
        head = length * 0.3
        wings = [[-vy, vx], [vy, -vx]].map { |sx, sy| Geom::Point3d.new(tip.x - vx * head + sx * head * 0.6, tip.y - vy * head + sy * head * 0.6, tip.z) }
        points = [start, tip, tip, wings[0], tip, wings[1]]
        points.map { |point| point.transform(world) }
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
