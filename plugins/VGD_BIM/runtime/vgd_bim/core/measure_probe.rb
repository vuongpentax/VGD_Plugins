require_relative 'measure'
require_relative 'settings'

module VGD
  module BIM
    # Phần gọi SketchUp của số đo thân (xem Measure): duyệt hình trong định nghĩa, bỏ các group / component / mặt / cạnh có tên hoặc tag chứa
    # từ khóa loại trừ, tính khung bao còn lại. Chỉ đọc model. Chưa kiểm được trong SketchUp thật.
    # Mỗi định nghĩa (component / group) chỉ duyệt MỘT lần trong một lần dựng bảng, kết quả dùng lại cho mọi bản sao và mọi cấp lồng,
    # nên món gộp nhiều cấp, nhiều mặt vẫn đo nhanh và không cần giới hạn số mặt.
    module MeasureProbe
      # Phần còn lại của một định nghĩa sau khi bỏ các phần loại trừ: mặt và cạnh trực tiếp, các định nghĩa con (kèm biến đổi của bản sao),
      # và tên các phần đã bỏ (kể cả phần nằm sâu trong định nghĩa con).
      class Part
        attr_reader :excluded

        def initialize(faces, edges, children, excluded)
          @faces = faces
          @edges = edges
          @children = children
          @excluded = excluded
        end

        # Có phần nào bị bỏ (ở bất kỳ cấp nào) không.
        def touched?
          !@excluded.empty?
        end

        # Khung bao (inch, khung cục bộ của định nghĩa): [nhỏ nhất, lớn nhất], hoặc nil nếu không còn gì. Tính một lần khi cần.
        # Định nghĩa con được tính bằng khung bao của nó (như SketchUp tính khung bao của component lồng nhau).
        def box
          return @box if defined?(@box)
          lo = [Float::INFINITY] * 3
          hi = [-Float::INFINITY] * 3
          grow = lambda do |point|
            3.times do |axis|
              lo[axis] = point[axis] if point[axis] < lo[axis]
              hi[axis] = point[axis] if point[axis] > hi[axis]
            end
          end
          @faces.each { |face| bounds = face.bounds; grow.call(bounds.min.to_a); grow.call(bounds.max.to_a) }
          @edges.each { |edge| grow.call(edge.start.position.to_a); grow.call(edge.end.position.to_a) }
          @children.each do |part, transform|
            child = part.box
            next unless child
            child[0].zip(child[1]).then { |xs, ys, zs| xs.product(ys, zs) }.each { |x, y, z| grow.call(Geom::Point3d.new(x, y, z).transform(transform).to_a) }
          end
          @box = lo[0] == Float::INFINITY ? nil : [lo, hi]
        end
      end

      # Cài đặt đo của một lần dựng bảng, nhớ kết quả theo định nghĩa (nhiều bản sao dùng chung một lần đo).
      class Context
        attr_reader :words, :tags

        def initialize(words, tags = [])
          @words = words
          @tags = tags.map { |name| Measure.normalize(name) }.uniq # tên tag đã chuẩn hóa
          @cache = {}
          @parts = {} # định nghĩa => Part, dùng chung cho mọi định nghĩa cha
        end

        def active?
          !@words.empty? || !@tags.empty?
        end

        # {size: [rộng X, sâu Y, cao Z] (inch, trước khi nhân phóng to), note: ghi chú} hoặc nil nếu khung bao giữ nguyên.
        def extent(definition)
          return nil unless active?
          return @cache[definition] if @cache.key?(definition)
          @cache[definition] = MeasureProbe.measure(definition, @words, @tags, @parts)
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

      # parts: bảng nhớ Part theo định nghĩa (Context truyền vào để dùng chung giữa các định nghĩa cha).
      def self.measure(definition, words, tags = [], parts = {})
        return nil if definition.bounds.empty?
        part = part_of(definition, words, tags, parts)
        return nil unless part.touched?
        box = part.box
        return nil unless box
        {size: (0..2).map { |axis| box[1][axis] - box[0][axis] }, note: Measure.note(part.excluded)}
      end

      # Duyệt các phần tử trực tiếp của định nghĩa (một lần), đệ quy vào định nghĩa con còn lại. Bỏ group / component / mặt / cạnh
      # có từ khóa hoặc tag loại trừ; phần bị bỏ không được đi vào bên trong.
      def self.part_of(definition, words, tags, parts)
        return parts[definition] if parts.key?(definition)
        parts[definition] = Part.new([], [], [], []) # chặn vòng lặp (SketchUp không cho định nghĩa chứa chính nó, giữ cho chắc)
        faces = []
        edges = []
        children = []
        excluded = []
        definition.entities.to_enum.each do |entity|
          next unless entity.respond_to?(:valid?) && entity.valid?
          if Data.supported?(entity)
            if Measure.match(words, entity.name, Geometry.definition(entity).name, layer_name(entity)) || Measure.tag_excluded?(tags, layer_name(entity))
              excluded << label(entity)
            else
              sub = part_of(Geometry.definition(entity), words, tags, parts)
              excluded.concat(sub.excluded)
              children << [sub, entity.transformation]
            end
          elsif entity.is_a?(Sketchup::Face)
            if Measure.match(words, layer_name(entity)) || Measure.tag_excluded?(tags, layer_name(entity)) then excluded << label(entity) else faces << entity end
          elsif entity.is_a?(Sketchup::Edge)
            edges << entity unless Measure.match(words, layer_name(entity)) || Measure.tag_excluded?(tags, layer_name(entity))
          end
        end
        parts[definition] = Part.new(faces, edges, children, excluded)
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
