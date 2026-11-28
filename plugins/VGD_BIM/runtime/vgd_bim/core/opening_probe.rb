require_relative 'geometry'
require_relative 'structure_source'

module VGD
  module BIM
    # Phần gọi SketchUp của việc trừ cửa khỏi tường (logic ở room_openings.rb): tìm trong model các Group / Component nằm trên các tag cửa người dùng chọn
    # (so đúng toàn bộ tên tag) và đo từng ô cửa. Chỉ chạy khi người dùng bấm nút; CHỈ ĐỌC, không đổi model. Cửa của VGD Structure dùng số đo lỗ chính xác
    # (VGD_STRUCT dims w, h), cửa khác lấy chiều ngang lớn hơn và chiều cao của khung bao (ước tính). Chưa kiểm được trong SketchUp thật.
    module OpeningProbe
      MAX_VISITS = 200_000   # số Group / Component tối đa duyệt; nhiều hơn thì dừng và báo
      MAX_DEPTH = 20

      # Trả về {openings: [{x:, y:, z0:, z1:, width:, height:, exact:}], truncated:} (mm, tọa độ thế giới).
      def self.collect(model, tags)
        wanted = tags.to_h { |name| [name, true] }
        state = {visits: 0, truncated: false, empty: {}}
        found = []
        walk(model.entities, Geom::Transformation.new, wanted, found, state, 0)
        {openings: found, truncated: state[:truncated]}
      end

      # Không đi vào bên trong cửa; nhớ các định nghĩa không chứa cửa nào để khỏi duyệt lại ở các bản sao khác.
      def self.walk(entities, transform, wanted, found, state, depth)
        entities.each do |entity|
          next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          return state[:truncated] = true if (state[:visits] += 1) > MAX_VISITS
          next if Rooms.volume_entity?(entity)
          world = transform * entity.transformation
          if entity.layer && wanted[entity.layer.name.to_s]
            measured = measure(entity, world)
            found << measured if measured
            next
          end
          definition = Geometry.definition(entity)
          next if depth >= MAX_DEPTH || state[:empty][definition]
          before = found.size
          walk(definition.entities, world, wanted, found, state, depth + 1)
          state[:empty][definition] = true if found.size == before && !state[:truncated]
        end
      end

      def self.measure(entity, world)
        box = Geometry.definition(entity).bounds
        return nil if box.empty?
        corners = (0...8).map { |i| box.corner(i).transform(world) }
        xs = corners.map { |p| p.x.to_f * Geometry::INCH_MM }
        ys = corners.map { |p| p.y.to_f * Geometry::INCH_MM }
        zs = corners.map { |p| p.z.to_f * Geometry::INCH_MM }
        width, height, exact = size_of(entity, world)
        return nil unless width.positive? && height.positive?
        {x: (xs.min + xs.max) / 2, y: (ys.min + ys.max) / 2, z0: zs.min, z1: zs.max, width: width, height: height, exact: exact}
      end

      # [rộng mm, cao mm, chính xác?]
      def self.size_of(entity, world)
        if StructureSource.element?(entity) && %w[door window].include?(entity.get_attribute(StructureSource::SOURCE_DICTIONARY, 'kind'))
          dims = StructureSource.dims(entity)
          w = dims['w']
          h = dims['h']
          return [w.to_f, h.to_f, true] if w.is_a?(Numeric) && h.is_a?(Numeric) && w.positive? && h.positive?
        end
        size = Geometry.dimensions(entity, world)
        [[size[:width], size[:depth]].max, size[:height], false]
      end
    end
  end
end
