# encoding: UTF-8
# Lấy hình học 3D của model để vẽ trong hộp thoại (chỉ đọc, không đổi model).
# Mỗi bản (Group/Component) là một "mảnh": các mặt nằm trực tiếp trong bản đó, đã đổi về tọa độ thế giới.
# Cấu kiện con có mảnh riêng, với biến đổi lồng nhau.
module VGD
  module Diagram
    module Scene
      extend self

      MAX_TRIANGLES = 100_000
      MM_PER_INCH = 25.4

      # Trả về {'parts' => [{id, name, order, positions}], 'triangles' => n, 'truncated' => bool}.
      # positions: số nguyên mm, theo bộ ba đỉnh (x, y, z) của từng tam giác.
      def build(model)
        build_from(model.entities)
      end

      # Hình học của một danh sách thực thể (phạm vi đã chọn).
      def build_from(entities)
        state = { 'parts' => [], 'triangles' => 0, 'truncated' => false }
        collect(entities, Geom::Transformation.new, nil, state)
        state
      end

      def collect(entities, transform, owner, state)
        faces = entities.select { |entity| entity.is_a?(Sketchup::Face) && ModelIO.visible?(entity) }
        add_part(owner, faces, transform, state) unless faces.empty?
        entities.each do |entity|
          next unless ModelIO.instance?(entity) && ModelIO.visible?(entity)
          return if state['truncated']
          collect(ModelIO.children_entities(entity), transform * entity.transformation, entity, state)
        end
      end

      def add_part(owner, faces, transform, state)
        positions = []
        faces.each do |face|
          positions.concat(face_positions(face, transform, state))
          break if state['truncated']
        end
        return if positions.empty?
        state['parts'] << {
          'id' => owner && owner.entityID,
          'name' => owner ? ModelIO.label(owner) : 'Khác',
          'order' => owner && owner.get_attribute(ModelIO::DICT, ModelIO::KEY_ORDER),
          'positions' => positions
        }
      end

      # Chia mỗi đa giác thành tam giác (quạt từ đỉnh đầu). Dừng khi vượt giới hạn số tam giác.
      def face_positions(face, transform, state)
        mesh = face.mesh(0)
        positions = []
        mesh.polygons.each do |polygon|
          corners = polygon.map { |index| to_mm(transform * mesh.point_at(index.abs)) }
          (1...corners.size - 1).each do |k|
            if state['triangles'] >= MAX_TRIANGLES
              state['truncated'] = true
              return positions
            end
            state['triangles'] += 1
            [corners[0], corners[k], corners[k + 1]].each { |corner| positions.concat(corner) }
          end
        end
        positions
      end

      def to_mm(point)
        point.to_a.map { |value| (value * MM_PER_INCH).round }
      end
    end
  end
end
