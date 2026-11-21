require_relative 'position'

module VGD
  module Position
    # Phần gọi SketchUp của VGD Position: đọc vị trí món, dời món, kiểm tra lại sau khi dời.
    # Vị trí tính trong hệ thế giới (mm). Món trong group cha đang mở được dời đúng theo hệ thế giới (xem context).
    module Move
      TOLERANCE_MM = 0.01 # sau khi dời, vị trí phải khớp trong 0,01 mm, nếu không thì hủy cả đợt
      OPERATION_NAME = 'VGD Position · Dời món'.freeze

      module_function

      # Biến đổi của ngữ cảnh đang mở (tích các group trong active_path). Không dùng Model#edit_transform (xem CLAUDE.md của BIM).
      def context(model)
        (model.active_path || []).inject(Geom::Transformation.new) { |total, entity| total * entity.transformation }
      end

      def locked_context?(model)
        (model.active_path || []).any? { |entity| entity.respond_to?(:locked?) && entity.locked? }
      end

      def supported?(entity)
        entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      end

      # Điểm gốc của món trong thế giới (mm).
      def origin_mm(entity, ctx)
        point = (ctx * entity.transformation).origin
        [point.x * MM_PER_INCH, point.y * MM_PER_INCH, point.z * MM_PER_INCH]
      end

      # Các món đang chọn: [{index:, name:, origin: [x, y, z] mm, locked:, entity:}]. index là thứ tự trong lựa chọn.
      def items(model)
        ctx = context(model)
        ancestors_locked = locked_context?(model)
        model.selection.to_a.select { |entity| supported?(entity) && entity.valid? }.each_with_index.map do |entity, index|
          {index: index, name: name_of(entity), origin: origin_mm(entity, ctx), locked: ancestors_locked || entity.locked? ? true : false, entity: entity}
        end
      end

      def name_of(entity)
        name = entity.name.to_s.strip
        name = entity.definition.name.to_s.strip if name.empty?
        name.empty? ? '(chưa đặt tên)' : name
      end

      # moves: [{index:, delta: [dx, dy, dz] mm}] từ Position.plan; items: danh sách lấy lúc bấm (items(model)).
      # Một thao tác hoàn tác cho cả đợt. Kiểm tra khóa trước khi dời và vị trí sau khi dời; sai thì hủy cả đợt, không để model dở.
      def apply(model, moves, items)
        by_index = items.to_h { |item| [item[:index], item] }
        model.start_operation(OPERATION_NAME, true)
        begin
          moved = 0
          moves.each do |move|
            item = by_index.fetch(move[:index]) { raise ArgumentError, 'Danh sách món đã thay đổi. Hãy chọn lại món rồi thử lại.' }
            entity = item[:entity]
            raise ArgumentError, "#{item[:name]} đang bị khóa, không dời được." if entity.locked? || locked_context?(model)
            move_entity(model, entity, move[:delta])
            expected = item[:origin].zip(move[:delta]).map { |a, d| a + d }
            actual = origin_mm(entity, context(model))
            unless actual.zip(expected).all? { |a, e| (a - e).abs <= TOLERANCE_MM }
              raise ArgumentError, "Vị trí của #{item[:name]} sau khi dời không khớp, đã hủy cả đợt."
            end
            moved += 1
          end
          model.commit_operation
          moved
        rescue StandardError
          model.abort_operation
          raise
        end
      end

      # Độ dời (mm, hệ thế giới) đổi sang hệ của group cha rồi tịnh tiến biến đổi của món.
      def move_entity(model, entity, delta)
        world = Geom::Vector3d.new(delta[0] / MM_PER_INCH, delta[1] / MM_PER_INCH, delta[2] / MM_PER_INCH)
        local = context(model).inverse * world
        entity.transformation = Geom::Transformation.translation(local) * entity.transformation
      end
    end
  end
end
