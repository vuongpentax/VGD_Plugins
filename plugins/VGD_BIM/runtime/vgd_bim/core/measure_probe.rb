require_relative 'measure'
require_relative 'settings'

module VGD
  module BIM
    # Phần gọi SketchUp của số đo thân (xem Measure): duyệt hình trong định nghĩa, bỏ các group / component / mặt / cạnh có tên hoặc tag chứa
    # từ khóa loại trừ, tính khung bao còn lại (và tùy chọn cắt phần nhô). Chỉ đọc model. Chưa kiểm được trong SketchUp thật.
    module MeasureProbe
      MAX_FACES = 20_000 # định nghĩa nhiều mặt hơn thì giữ khung bao gốc (không đo thân) để bảng không chậm

      # Cài đặt đo của một lần dựng bảng, nhớ kết quả theo định nghĩa (nhiều bản sao dùng chung một lần đo).
      class Context
        attr_reader :words, :trim

        def initialize(words, trim)
          @words = words
          @trim = trim ? true : false
          @cache = {}
        end

        def active?
          !@words.empty? || @trim
        end

        # {size: [rộng X, sâu Y, cao Z] (inch, trước khi nhân phóng to), note: ghi chú} hoặc nil nếu khung bao giữ nguyên.
        def extent(definition)
          return nil unless active?
          return @cache[definition] if @cache.key?(definition)
          @cache[definition] = MeasureProbe.measure(definition, @words, @trim)
        end
      end

      # Đọc cài đặt chung. Từ khóa hỏng (file sửa tay) thì bỏ qua cả danh sách.
      def self.context(settings = Settings.read)
        Context.new(Measure.parse_words(settings['exclude_words']), settings['trim_protrusions'])
      rescue ArgumentError
        Context.new([], settings['trim_protrusions'])
      end

      def self.measure(definition, words, trim)
        native = definition.bounds
        return nil if native.empty?
        excluded = []
        faces = []
        points = []
        complete = collect(definition, words, excluded, faces, points)
        return nil unless complete
        return nil if excluded.empty? && !trim
        return nil if faces.empty? && points.empty?
        lo, hi = union(faces, points)
        trimmed = Array.new(3) { [0.0, 0.0] }
        if trim
          body = Measure.body_extents(faces)
          if body
            Measure::TRIM_AXES.each do |axis|
              trimmed[axis] = body[:trimmed][axis]
              lo[axis] += trimmed[axis][0]
              hi[axis] -= trimmed[axis][1]
            end
          end
        end
        size = (0..2).map { |axis| (hi[axis] - lo[axis]) / Geometry::INCH_MM }
        native_size = [native.width.to_f, native.height.to_f, native.depth.to_f]
        return nil if excluded.empty? && size.zip(native_size).all? { |a, b| (a - b).abs < 1e-6 }
        {size: size, note: Measure.note(excluded, trimmed)}
      end

      # Duyệt toàn bộ hình trong định nghĩa. Trả về false nếu quá nhiều mặt (không đo). excluded nhận tên các phần bị loại.
      def self.collect(definition, words, excluded, faces, points)
        stack = [[definition.entities.to_enum, Geom::Transformation.new, [definition]]]
        until stack.empty?
          iterator, transform, ancestors = stack.last
          begin
            entity = iterator.next
          rescue StopIteration
            stack.pop
            next
          end
          next unless entity.respond_to?(:valid?) && entity.valid?
          if Data.supported?(entity)
            reason = Measure.match(words, entity.name, Geometry.definition(entity).name, layer_name(entity))
            if reason then excluded << label(entity); next end
            child = Geometry.definition(entity)
            stack << [child.entities.to_enum, transform * entity.transformation, ancestors + [child]] unless ancestors.include?(child)
          elsif entity.is_a?(Sketchup::Face)
            if Measure.match(words, layer_name(entity)) then excluded << label(entity); next end
            return false if faces.size >= MAX_FACES
            faces << face_data(entity, transform)
          elsif entity.is_a?(Sketchup::Edge)
            next if Measure.match(words, layer_name(entity))
            [entity.start.position, entity.end.position].each do |point|
              moved = point.transform(transform)
              points << [moved.x * Geometry::INCH_MM, moved.y * Geometry::INCH_MM, moved.z * Geometry::INCH_MM]
            end
          end
        end
        true
      end

      def self.face_data(face, transform)
        bounds = face.bounds
        corners = [bounds.min, bounds.max].then { |a, b| [a.x, b.x].product([a.y, b.y], [a.z, b.z]) }.map { |x, y, z| Geom::Point3d.new(x, y, z).transform(transform) }
        center = bounds.center.transform(transform)
        normal = face.normal.transform(transform).to_a
        length = Math.sqrt(normal.sum { |v| v * v })
        normal = length.zero? ? [0.0, 0.0, 0.0] : normal.map { |v| v / length }
        mm = ->(values) { values.map { |v| v * Geometry::INCH_MM } }
        {n: normal, c: mm.call([center.x, center.y, center.z]),
         a: face.area(transform).to_f * Geometry::INCH_MM**2,
         lo: mm.call((0..2).map { |axis| corners.map { |p| p.to_a[axis] }.min }), hi: mm.call((0..2).map { |axis| corners.map { |p| p.to_a[axis] }.max })}
      end

      def self.union(faces, points)
        boxes = faces.map { |f| [f[:lo], f[:hi]] } + points.map { |p| [p, p] }
        [(0..2).map { |axis| boxes.map { |lo, _| lo[axis] }.min }, (0..2).map { |axis| boxes.map { |_, hi| hi[axis] }.max }]
      end

      def self.layer_name(entity)
        entity.respond_to?(:layer) && entity.layer ? entity.layer.name.to_s : ''
      end

      def self.label(entity)
        name = entity.respond_to?(:name) ? entity.name.to_s.strip : ''
        name = Geometry.definition(entity).name.to_s.strip if name.empty? && Data.supported?(entity)
        name = layer_name(entity) if name.empty?
        name.empty? ? '(chưa đặt tên)' : name
      end
    end
  end
end
