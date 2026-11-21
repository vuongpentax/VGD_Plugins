require_relative 'units'
require_relative 'translate'
require_relative 'rotate_scale'
require_relative 'steps'
require_relative 'plan'

module VGD
  module Transform
    # Phần gọi SketchUp của VGD Transform: đọc vị trí món, áp dụng các bước dời / xoay / scale, kiểm tra lại sau khi áp dụng.
    # Vị trí tính trong hệ thế giới (mm). Món trong group cha đang mở được biến đổi đúng theo hệ thế giới (xem context).
    module Move
      TOLERANCE_MM = 0.01 # sau khi áp dụng, vị trí phải khớp trong 0,01 mm, nếu không thì hủy cả đợt
      OPERATION_NAME = 'VGD Transform · Biến đổi món'.freeze

      module_function

      # Biến đổi của ngữ cảnh đang mở (tích các group trong active_path). Không dùng Model#edit_transform (xem CLAUDE.md của BIM).
      def context(model)
        (model.active_path || []).inject(Geom::Transformation.new) { |total, entity| total * entity.transformation }
      end

      def locked_context?(model)
        (model.active_path || []).any? { |entity| entity.respond_to?(:locked?) && entity.locked? }
      end

      # Đơn vị độ dài đang đặt trong file: 'mm', 'cm', 'm', 'in' hoặc 'ft'.
      def length_unit(model)
        Units.unit_of_model(model.options['UnitsOptions']['LengthUnit'])
      end

      def supported?(entity)
        entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      end

      # Điểm gốc của món trong thế giới (mm).
      def origin_mm(entity, ctx)
        point = (ctx * entity.transformation).origin
        [point.x * Units::MM_PER_INCH, point.y * Units::MM_PER_INCH, point.z * Units::MM_PER_INCH]
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

      # moves: [{index:, steps:}] từ Plan.build; items: danh sách lấy lúc bấm (items(model)).
      # Một thao tác hoàn tác cho cả đợt. Kiểm tra khóa trước khi biến đổi và vị trí sau khi biến đổi; sai thì hủy cả đợt, không để model dở.
      def apply(model, moves, items)
        by_index = items.to_h { |item| [item[:index], item] }
        model.start_operation(OPERATION_NAME, true)
        begin
          moved = 0
          moves.each do |move|
            item = by_index.fetch(move[:index]) { raise ArgumentError, 'Danh sách món đã thay đổi. Hãy chọn lại món rồi thử lại.' }
            entity = item[:entity]
            raise ArgumentError, "#{item[:name]} đang bị khóa, không dời được." if entity.locked? || locked_context?(model)
            move[:steps].each { |step| apply_step(model, entity, step) }
            expected = Steps.apply_steps(move[:steps], item[:origin])
            actual = origin_mm(entity, context(model))
            unless actual.zip(expected).all? { |a, e| (a - e).abs <= TOLERANCE_MM }
              raise ArgumentError, "Vị trí của #{item[:name]} sau khi biến đổi không khớp, đã hủy cả đợt."
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

      # Một bước biến đổi trong thế giới, đổi sang hệ của group cha rồi nhân vào biến đổi của món.
      def apply_step(model, entity, step)
        ctx = context(model)
        world = world_transformation(step)
        entity.transformation = ctx.inverse * world * ctx * entity.transformation
      end

      def world_transformation(step)
        case step[:kind]
        when 'translate'
          Geom::Transformation.translation(vector_in(step[:delta]))
        when 'rotate'
          Geom::Transformation.rotation(point_in(step[:pivot]), Geom::Vector3d.new(*step[:axis]), step[:degrees] * Math::PI / 180.0)
        when 'scale'
          to_pivot = Geom::Transformation.translation(vector_in(step[:pivot]))
          from_pivot = Geom::Transformation.translation(vector_in(step[:pivot].map(&:-@)))
          to_pivot * Geom::Transformation.scaling(*step[:factors]) * from_pivot
        else raise ArgumentError, 'Bước biến đổi không hợp lệ.'
        end
      end

      def vector_in(mm)
        Geom::Vector3d.new(mm[0] / Units::MM_PER_INCH, mm[1] / Units::MM_PER_INCH, mm[2] / Units::MM_PER_INCH)
      end

      def point_in(mm)
        Geom::Point3d.new(mm[0] / Units::MM_PER_INCH, mm[1] / Units::MM_PER_INCH, mm[2] / Units::MM_PER_INCH)
      end
    end
  end
end
