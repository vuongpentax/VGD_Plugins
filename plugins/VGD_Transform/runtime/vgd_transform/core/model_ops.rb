require_relative 'units'
require_relative 'items'
require_relative 'steps'
require_relative 'translate'
require_relative 'rotate_scale'
require_relative 'plan'

module VGD
  module Transform
    # Phần gọi SketchUp của VGD Transform: đọc món đang chọn, áp dụng các bước dời / xoay / scale, kiểm tra lại sau khi áp dụng.
    # Vị trí tính trong hệ thế giới (mm). Món trong group cha đang mở được biến đổi đúng theo hệ thế giới (xem context).
    module ModelOps
      TOLERANCE_MM = 0.01       # điểm gốc sau khi áp dụng phải khớp trong 0,01 mm
      MATRIX_TOLERANCE = 1e-6   # phần xoay / scale của ma trận phải khớp tới sai số này
      OPERATION_NAME = 'VGD Transform · Biến đổi món'.freeze
      LOCK_NAME = 'VGD Transform · Khóa'.freeze
      UNLOCK_NAME = 'VGD Transform · Mở khóa'.freeze

      module_function

      # Biến đổi của ngữ cảnh đang mở (tích các group trong active_path). Không dùng Model#edit_transform (xem CLAUDE.md của BIM).
      def context(model)
        (model.active_path || []).inject(Geom::Transformation.new) { |total, entity| total * entity.transformation }
      end

      def locked_context?(model)
        (model.active_path || []).any? { |entity| entity.respond_to?(:locked?) && entity.locked? }
      end

      # Đơn vị độ dài đang đặt trong file ('mm', 'cm', 'm', 'in', 'ft', 'yd'), hoặc nil nếu SketchUp trả đơn vị lạ.
      def length_unit(model)
        Units.unit_of_model(model.options['UnitsOptions']['LengthUnit'])
      end

      def supported?(entity)
        entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      end

      # Các group / component đang chọn, theo thứ tự trong lựa chọn. Cạnh, mặt... không có trong danh sách (xem skipped_count).
      def items(model)
        ctx = context(model)
        ancestors_locked = locked_context?(model)
        selected_instances(model).each_with_index.map do |entity, index|
          read(entity, index, ctx, ancestors_locked)
        end
      end

      # Group / component đang chọn (không đọc ma trận), dùng cho khóa / mở khóa.
      def selected_instances(model)
        model.selection.to_a.select { |entity| supported?(entity) && entity.valid? }
      end

      # Trạng thái khóa của lựa chọn, như Lock của SketchUp: 'all' (khóa hết), 'none' (không món nào khóa), 'mixed', hoặc nil (chưa chọn).
      def lock_state(model)
        entities = selected_instances(model)
        return nil if entities.empty?
        locked = entities.count(&:locked?)
        locked.zero? ? 'none' : locked == entities.size ? 'all' : 'mixed'
      end

      # Khóa hoặc mở khóa mọi group / component đang chọn (Entity#locked= của SketchUp), một bước hoàn tác. Trả số món đã đổi.
      def set_locked(model, locked)
        entities = selected_instances(model)
        raise ArgumentError, 'Chưa chọn group hoặc component nào.' if entities.empty?
        raise ArgumentError, 'Group cha đang mở bị khóa, không đổi được khóa của món bên trong.' if locked_context?(model)
        model.start_operation(locked ? LOCK_NAME : UNLOCK_NAME, true)
        begin
          entities.each { |entity| entity.locked = locked }
          model.commit_operation
          entities.size
        rescue StandardError
          model.abort_operation
          raise
        end
      end

      # Số đối tượng đang chọn nhưng không phải group / component (không biến đổi được bằng plugin này).
      def skipped_count(model, items)
        model.selection.to_a.size - items.size
      end

      # Đọc một món từ ma trận thế giới (to_a của SketchUp: 16 số theo cột, trục X ở 0..2, Y ở 4..6, Z ở 8..10, gốc ở 12..14).
      def read(entity, index, ctx, ancestors_locked)
        world = ctx * entity.transformation
        m = world.to_a
        columns = [m[0, 3], m[4, 3], m[8, 3]]
        scale = columns.map { |c| Math.sqrt(c.sum { |v| v * v }) }
        axes = columns.zip(scale).map { |c, length| length.positive? ? c.map { |v| v / length } : [0.0, 0.0, 0.0] }
        box = entity.definition.bounds
        corners = (0..7).map { |i| world * box.corner(i) }
        bounds = {min: %i[x y z].map { |a| corners.map(&a).min * Units::MM_PER_INCH },
                  max: %i[x y z].map { |a| corners.map(&a).max * Units::MM_PER_INCH }}
        local = %i[x y z].map { |a| box.max.send(a) - box.min.send(a) }
        {index: index, name: name_of(entity), entity: entity, locked: ancestors_locked || entity.locked? ? true : false,
         origin: m[12, 3].map { |v| v * Units::MM_PER_INCH }, axes: axes, scale: scale, bounds: bounds,
         size: local.zip(scale).map { |l, s| l * s * Units::MM_PER_INCH }}
      end

      def name_of(entity)
        name = entity.name.to_s.strip
        name = entity.definition.name.to_s.strip if name.empty?
        name.empty? ? '(chưa đặt tên)' : name
      end

      # moves: [{index:, steps:}] từ Plan.build; items: danh sách lấy lúc bấm (items(model)).
      # Một thao tác hoàn tác cho cả đợt; mỗi món đặt biến đổi đúng một lần rồi kiểm tra ma trận và điểm gốc; sai thì hủy cả đợt.
      # transparent: gộp vào thao tác trước đó (kéo trực tiếp: nhiều lần cập nhật thành một bước Ctrl+Z).
      # restore: {entity => biến đổi lúc bắt đầu kéo}; mỗi lần cập nhật tính từ trạng thái ban đầu đó (ghi biến đổi mới một lần, không ghi lại
      # trạng thái đầu trước); món không còn trong danh sách bước thì được đưa về trạng thái đầu.
      def apply(model, moves, items, transparent: false, restore: nil)
        model.start_operation(OPERATION_NAME, true, false, transparent)
        begin
          apply_moves(model, moves, items, restore)
          model.commit_operation
          moves.size
        rescue StandardError
          model.abort_operation
          raise
        end
      end

      # Ghi biến đổi của các món (không mở / đóng thao tác): dùng trong apply và trong lúc kéo trực tiếp.
      # Ngữ cảnh (group cha đang mở) và trạng thái khóa của nó đọc MỘT lần cho cả đợt (mỗi lần đọc là một lời gọi API của SketchUp).
      # check: kiểm tra khóa từng món và kiểm lại ma trận / điểm gốc sau khi ghi; nhịp kéo trực tiếp bỏ qua, nhịp cuối thì kiểm.
      def apply_moves(model, moves, items, restore, check: true)
        by_index = items.to_h { |item| [item[:index], item] }
        ctx = context(model)
        blocked = locked_context?(model)
        moved = {}
        moves.each do |move|
          item = by_index.fetch(move[:index]) { raise ArgumentError, 'Danh sách món đã thay đổi. Hãy chọn lại món rồi thử lại.' }
          apply_move(model, item, move[:steps], restore && restore[item[:entity]], ctx: ctx, blocked: blocked, check: check)
          moved[item[:entity]] = true
        end
        restore&.each { |entity, transformation| entity.transformation = transformation if entity.valid? && !moved[entity] }
      end

      # Kéo trực tiếp: một thao tác MỞ SUỐT lần kéo (begin_live), mỗi nhịp chỉ ghi biến đổi (apply_live), thả nút thì đóng (finish_live).
      # Không mở / đóng thao tác mỗi nhịp: mỗi lần đóng làm SketchUp ghi bước hoàn tác và báo mọi observer của mọi plugin, rất nặng khi kéo.
      def begin_live(model)
        model.start_operation(OPERATION_NAME, false)
      end

      # check: true ở nhịp cuối (lúc thả nút) để kiểm lại như áp dụng thường; các nhịp giữa bỏ qua cho nhẹ.
      def apply_live(model, moves, items, originals, check: false)
        apply_moves(model, moves, items, originals, check: check)
      end

      # Đưa các món về biến đổi lúc bắt đầu kéo (giá trị kéo trở về 0), trong thao tác đang mở.
      def restore_entities(originals)
        originals.each { |entity, transformation| entity.transformation = transformation if entity.valid? }
      end

      # changed: còn thay đổi so với lúc bắt đầu kéo thì đóng (một bước Ctrl+Z), không thì hủy để không để lại bước trống.
      def finish_live(model, changed)
        changed ? model.commit_operation : model.abort_operation
      end

      # Đưa các món về biến đổi lúc bắt đầu kéo (khi giá trị kéo trở về 0), gộp vào thao tác trước đó.
      def restore(model, originals)
        model.start_operation(OPERATION_NAME, true, false, true)
        restore_entities(originals)
        model.commit_operation
      end

      # base: biến đổi gốc của món (kéo trực tiếp); không có thì lấy biến đổi hiện tại. ctx, blocked: đã đọc sẵn (xem apply_moves).
      def apply_move(model, item, steps, base = nil, ctx: nil, blocked: nil, check: true)
        entity = item[:entity]
        ctx ||= context(model)
        blocked = locked_context?(model) if blocked.nil?
        raise ArgumentError, "#{item[:name]} đang bị khóa, không biến đổi được." if blocked || (check && entity.locked?)
        before = ctx * (base || entity.transformation)
        expected = composite(steps) * before
        entity.transformation = ctx.inverse * expected
        verify(item, steps, ctx * entity.transformation, expected) if check
      end

      # Kiểm tra hai cách: ma trận thế giới phải đúng như đã tính (bắt lỗi xoay / scale sai),
      # và điểm gốc phải khớp công thức thuần trong Steps (tính độc lập với SketchUp).
      def verify(item, steps, actual, expected)
        a = actual.to_a
        e = expected.to_a
        linear_ok = (0..11).all? { |i| (a[i] - e[i]).abs <= MATRIX_TOLERANCE * [1.0, e[i].abs].max }
        origin = a[12, 3].map { |v| v * Units::MM_PER_INCH }
        origin_ok = origin.zip(Steps.apply_steps(steps, item[:origin])).all? { |x, y| (x - y).abs <= TOLERANCE_MM }
        raise ArgumentError, "Vị trí của #{item[:name]} sau khi biến đổi không khớp, đã hủy cả đợt." unless linear_ok && origin_ok
      end

      # Gộp các bước của một món thành một biến đổi trong thế giới (bước sau nhân bên trái bước trước).
      def composite(steps)
        steps.reduce(Geom::Transformation.new) { |total, step| world_transformation(step) * total }
      end

      def world_transformation(step)
        case step[:kind]
        when 'translate'
          Geom::Transformation.translation(vector_in(step[:delta]))
        when 'rotate'
          Geom::Transformation.rotation(point_in(step[:pivot]), Geom::Vector3d.new(*step[:axis]), step[:degrees] * Math::PI / 180.0)
        when 'scale'
          # Hệ trục đặt tại tâm: đổi sang hệ đó, scale theo trục, rồi đổi lại.
          axes = (step[:axes] || Items::WORLD_AXES).map { |a| Geom::Vector3d.new(*a) }
          frame = Geom::Transformation.axes(point_in(step[:pivot]), *axes)
          frame * Geom::Transformation.scaling(*step[:factors]) * frame.inverse
        else raise ArgumentError, 'Bước biến đổi không hợp lệ.'
        end
      end

      def vector_in(mm)
        Geom::Vector3d.new(*mm.map { |v| v / Units::MM_PER_INCH })
      end

      def point_in(mm)
        Geom::Point3d.new(*mm.map { |v| v / Units::MM_PER_INCH })
      end
    end
  end
end
