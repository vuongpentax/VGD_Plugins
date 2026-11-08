require_relative 'measure'
require_relative 'settings'

module VGD
  module BIM
    # Phần gọi SketchUp của số đo thân (xem Measure): duyệt hình trong định nghĩa, bỏ các group / component / mặt / cạnh có tên hoặc tag chứa
    # từ khóa loại trừ, tính khung bao còn lại. Chỉ đọc model. Chưa kiểm được trong SketchUp thật.
    module MeasureProbe
      MAX_FACES = 20_000 # định nghĩa nhiều mặt hơn thì giữ khung bao gốc (không đo thân) để bảng không chậm

      # Cài đặt đo của một lần dựng bảng, nhớ kết quả theo định nghĩa (nhiều bản sao dùng chung một lần đo).
      class Context
        attr_reader :words, :tags

        def initialize(words, tags = [])
          @words = words
          @tags = tags.map { |name| Measure.normalize(name) }.uniq # tên tag đã chuẩn hóa
          @cache = {}
        end

        def active?
          !@words.empty? || !@tags.empty?
        end

        # {size: [rộng X, sâu Y, cao Z] (inch, trước khi nhân phóng to), note: ghi chú} hoặc nil nếu khung bao giữ nguyên.
        def extent(definition)
          return nil unless active?
          return @cache[definition] if @cache.key?(definition)
          @cache[definition] = MeasureProbe.measure(definition, @words, @tags)
        end
      end

      # Đọc cài đặt chung. Từ khóa hỏng (file sửa tay) thì bỏ qua cả danh sách.
      def self.context(settings = Settings.read)
        words = begin
          Measure.parse_words(settings['exclude_words'])
        rescue ArgumentError
          []
        end
        tags = begin
          Measure.parse_tags(settings['exclude_tags'] || [])
        rescue ArgumentError
          []
        end
        Context.new(words, tags)
      end

      def self.measure(definition, words, tags = [])
        native = definition.bounds
        return nil if native.empty?
        excluded = []
        boxes = []
        return nil unless collect(definition, words, tags, excluded, boxes)
        return nil if excluded.empty? || boxes.empty?
        lo = (0..2).map { |axis| boxes.map { |box| box[0][axis] }.min }
        hi = (0..2).map { |axis| boxes.map { |box| box[1][axis] }.max }
        {size: (0..2).map { |axis| (hi[axis] - lo[axis]) / Geometry::INCH_MM }, note: Measure.note(excluded)}
      end

      # Duyệt toàn bộ hình trong định nghĩa, gom khung bao (mm, khung cục bộ của định nghĩa) của mặt và cạnh còn lại. Trả về false nếu quá nhiều mặt
      # (không đo). excluded nhận tên các phần bị loại.
      def self.collect(definition, words, tags, excluded, boxes)
        faces = 0
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
            reason = Measure.match(words, entity.name, Geometry.definition(entity).name, layer_name(entity)) || (Measure.tag_excluded?(tags, layer_name(entity)) ? 'tag' : nil)
            if reason then excluded << label(entity); next end
            child = Geometry.definition(entity)
            stack << [child.entities.to_enum, transform * entity.transformation, ancestors + [child]] unless ancestors.include?(child)
          elsif entity.is_a?(Sketchup::Face)
            if Measure.match(words, layer_name(entity)) || Measure.tag_excluded?(tags, layer_name(entity)) then excluded << label(entity); next end
            faces += 1
            return false if faces > MAX_FACES
            boxes << face_box(entity, transform)
          elsif entity.is_a?(Sketchup::Edge)
            next if Measure.match(words, layer_name(entity)) || Measure.tag_excluded?(tags, layer_name(entity))
            [entity.start.position, entity.end.position].each do |point|
              moved = point.transform(transform)
              mm = [moved.x * Geometry::INCH_MM, moved.y * Geometry::INCH_MM, moved.z * Geometry::INCH_MM]
              boxes << [mm, mm]
            end
          end
        end
        true
      end

      # Khung bao của một mặt sau khi đổi sang khung cục bộ của định nghĩa (mm): [nhỏ nhất, lớn nhất].
      def self.face_box(face, transform)
        bounds = face.bounds
        corners = [bounds.min, bounds.max].then { |a, b| [a.x, b.x].product([a.y, b.y], [a.z, b.z]) }.map { |x, y, z| Geom::Point3d.new(x, y, z).transform(transform) }
        [(0..2).map { |axis| corners.map { |p| p.to_a[axis] }.min * Geometry::INCH_MM }, (0..2).map { |axis| corners.map { |p| p.to_a[axis] }.max * Geometry::INCH_MM }]
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
