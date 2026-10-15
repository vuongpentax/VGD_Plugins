# encoding: UTF-8
module VGD
  module Library
    module Geometry
      MAX_DEPTH = 64

      # Make selected instances unique before editing their definitions. Other
      # instances outside the selection must retain their geometry/materials.
      def self.each_face(entities, inherited = nil, depth = 0, &block)
        raise 'Cấu trúc group quá sâu (hơn 64 cấp).' if depth > MAX_DEPTH
        entities.each do |entity|
          next unless entity.valid?
          next if entity.respond_to?(:hidden?) && entity.hidden?
          next if entity.respond_to?(:locked?) && entity.locked?
          if entity.is_a?(Sketchup::Face)
            block.call(entity, entity.material || inherited)
          elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
            entity.make_unique
            children = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
            each_face(children.to_a, entity.material || inherited, depth + 1, &block)
          end
        end
      end

      def self.selection_inherited(model)
        path = model.active_path || []
        path.reverse_each do |instance|
          return instance.material if instance.material
        end
        nil
      end

      def self.uv_transform(u, v, angle, offset_u = 0, offset_v = 0, center_u = 0, center_v = 0, width = 1, height = 1)
        cos, sin = Math.cos(angle), Math.sin(angle)
        x, y = (u - center_u) * width, (v - center_v) * height
        [center_u + (x * cos - y * sin) / width + offset_u, center_v + (x * sin + y * cos) / height + offset_v]
      end

      def self.points(face)
        vertices = face.outer_loop.vertices.map(&:position)
        first = vertices.first
        second = vertices.find { |p| p.distance(first) > 1.0e-8 }
        third = second && vertices.find { |p| (second - first).cross(p - first).length > 1.0e-8 }
        raise 'Mặt quá nhỏ hoặc không có ba điểm độc lập.' unless third
        [first, second, third]
      end

      def self.transform(face, material, angle, offset_u = 0, offset_v = 0)
        # Inherited materials have no face-specific mapping until assigned.
        face.material = material unless face.material
        uv_helper = face.get_UVHelper(true, false, Sketchup.create_texture_writer)
        positions = points(face)
        uv = positions.map do |point|
          q = uv_helper.get_front_UVQ(point)
          raise 'Map có tọa độ UV không hợp lệ.' if q.z.abs < 1.0e-12
          [q.x / q.z, q.y / q.z]
        end
        center_u = uv.map(&:first).sum / 3.0
        center_v = uv.map(&:last).sum / 3.0
        mapping = positions.each_with_index.flat_map do |point, index|
          u, v = uv_transform(*uv[index], angle, offset_u, offset_v, center_u, center_v, material.texture.width.to_f, material.texture.height.to_f)
          [point, Geom::Point3d.new(u, v, 1)]
        end
        face.clear_texture_projection(true)
        raise 'Không thể đặt map trên mặt này.' unless face.position_material(material, mapping, true)
      end

      def self.fit(face, material)
        face.material = material unless face.material
        edge = face.outer_loop.edges.max_by(&:length)
        origin = edge.start.position
        axis_x = (edge.end.position - origin).normalize
        axis_y = face.normal.cross(axis_x).normalize
        xy = face.outer_loop.vertices.map do |vertex|
          delta = vertex.position - origin
          [delta.dot(axis_x), delta.dot(axis_y)]
        end
        min_x, max_x = xy.map(&:first).minmax
        min_y, max_y = xy.map(&:last).minmax
        raise 'Mặt quá nhỏ để fit map.' if max_x - min_x < 1.0e-8 || max_y - min_y < 1.0e-8
        p0 = origin.offset(axis_x, min_x).offset(axis_y, min_y)
        p1 = origin.offset(axis_x, max_x).offset(axis_y, min_y)
        p2 = origin.offset(axis_x, min_x).offset(axis_y, max_y)
        face.clear_texture_projection(true)
        raise 'Không thể fit map trên mặt này.' unless face.position_material(material, [p0, Geom::Point3d.new(0, 0, 1), p1, Geom::Point3d.new(1, 0, 1), p2, Geom::Point3d.new(0, 1, 1)], true)
      end

      def self.restore_size(face, material)
        edge = face.outer_loop.edges.max_by(&:length)
        origin = edge.start.position
        axis_x = (edge.end.position - origin).normalize
        axis_y = face.normal.cross(axis_x).normalize
        mapping = points(face).flat_map do |point|
          delta = point - origin
          [point, Geom::Point3d.new(delta.dot(axis_x) / material.texture.width.to_f, delta.dot(axis_y) / material.texture.height.to_f, 1)]
        end
        face.material = material
        face.clear_texture_projection(true)
        raise 'Không thể phục hồi map.' unless face.position_material(material, mapping, true)
      end

      def self.edit(model, action, angle = 90)
        raise 'Chọn mặt, group hoặc component trước khi chỉnh map.' if model.selection.empty?
        count = 0
        each_face(model.selection.to_a, selection_inherited(model)) do |face, material|
          next unless material && material.texture
          case action
          when 'rotate' then transform(face, material, Float(angle) * Math::PI / 180.0)
          when 'random_rotate' then transform(face, material, [0, 90, 180, 270].sample * Math::PI / 180.0)
          when 'shuffle' then transform(face, material, 0, rand, rand)
          when 'fit', 'auto_scale' then fit(face, material)
          when 'restore' then restore_size(face, material)
          when 'reset_uv'
            face.material = material unless face.material
            face.clear_texture_projection(true)
            face.clear_texture_position(true)
          else raise 'Lệnh chỉnh map không hợp lệ.'
          end
          count += 1
        end
        raise 'Vùng chọn không có mặt dùng vật liệu có ảnh.' if count.zero?
        "Đã chỉnh #{count} mặt trước. Ctrl+Z để hoàn tác."
      end

      def self.clear(model)
        raise 'Chọn mặt, group hoặc component trước khi xóa vật liệu.' if model.selection.empty?
        if selection_inherited(model)
          raise 'Vật liệu đang kế thừa từ vỏ ngoài chế độ sửa. Đóng chế độ sửa rồi chọn vỏ group/component để xóa vật liệu.'
        end
        count = 0
        each_face(model.selection.to_a, selection_inherited(model)) { |face, _| face.material = nil; count += 1 }
        clear_shells(model.selection.to_a)
        raise 'Vùng chọn không có mặt có thể sửa.' if count.zero?
        "Đã xóa vật liệu mặt trước và vỏ trong vùng chọn (#{count} mặt)."
      end

      def self.clear_shells(entities)
        entities.each do |entity|
          next unless entity.valid? && !entity.hidden?
          next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          next if entity.locked?
          entity.material = nil
          children = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
          clear_shells(children.to_a)
        end
      end
    end
  end
end
