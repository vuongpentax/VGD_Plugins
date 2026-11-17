module VGD
  module Structure
    # Vẽ lưới trục vào model: một Group "Lưới trục" trên tag `!grid` chứa các đường trục (nét gạch dài - chấm theo kiểu nét của tag)
    # và mỗi ký hiệu trục là một nhóm con (vòng tròn + tên trục đặt giữa). Mỗi lần vẽ là MỘT bước hoàn tác; vẽ lại thì thay nhóm cũ.
    # Chưa xác minh trong SketchUp thật (xem README): chỉ kiểm bằng giả lập.
    module GridBuilder
      CIRCLE_SEGMENTS = 48
      GROUP_NAME = 'Lưới trục'.freeze
      FONT = 'Arial'.freeze

      Result = Struct.new(:group, :style_note, :axes, :symbols)

      # grid, options: dữ liệu CHƯA kiểm tra (từ giao diện); tại đây kiểm tra lại trước khi đụng model.
      def self.build(model, grid, options)
        grid = Grid.normalize!(grid)
        options = AxisSymbol.options!(options)
        plan = AxisSymbol.plan(grid, options)
        old = find(model)
        raise Grid::Error, 'Lưới trục cũ đang bị khóa. Hãy mở khóa nhóm “Lưới trục” rồi vẽ lại.' if old && old.locked?
        model.start_operation('VGD Structure · Vẽ lưới trục', true)
        begin
          old.erase! if old
          tag, style_note = GridTag.ensure(model)
          group = model.entities.add_group
          group.name = GROUP_NAME
          group.layer = tag
          group.set_attribute(Schema::DICTIONARY, 'kind', Schema::GRID_KIND)
          group.set_attribute(Schema::DICTIONARY, 'plugin_version', VERSION)
          draw(group, plan, tag)
          ModelStore.write(model, grid, options)
          model.commit_operation
        rescue StandardError, ScriptError
          model.abort_operation
          raise
        end
        Result.new(group, style_note, plan.size, plan.sum { |axis| axis[:bubbles].size })
      end

      # Xóa lưới khỏi model (dữ liệu lưới trong VGD_STRUCT vẫn giữ để vẽ lại). Trả về true nếu có xóa.
      def self.remove(model)
        old = find(model)
        return false unless old
        raise Grid::Error, 'Lưới trục đang bị khóa. Hãy mở khóa nhóm “Lưới trục” rồi xóa.' if old.locked?
        model.start_operation('VGD Structure · Xóa lưới trục', true)
        begin
          old.erase!
          model.commit_operation
        rescue StandardError, ScriptError
          model.abort_operation
          raise
        end
        true
      end

      def self.find(model)
        model.entities.grep(Sketchup::Group).find { |g| g.valid? && g.get_attribute(Schema::DICTIONARY, 'kind') == Schema::GRID_KIND }
      end

      def self.draw(group, plan, tag)
        plan.each do |axis|
          (a, b) = axis[:line]
          edge = group.entities.add_line(point(a), point(b))
          edge.layer = tag if edge
          axis[:bubbles].each_with_index { |bubble, i| draw_symbol(group, axis, bubble, i, tag) }
        end
      end

      # Ký hiệu trục: nhóm con gồm vòng tròn và chữ đặt giữa vòng tròn (chữ tạo bằng 3D text phẳng, căn giữa theo hộp bao).
      def self.draw_symbol(group, axis, bubble, index, tag)
        sym = group.entities.add_group
        sym.name = "Ký hiệu trục #{axis[:name]}#{index.zero? ? '' : " (#{index + 1})"}"
        sym.layer = tag
        cx, cy = bubble[:center]
        edges = sym.entities.add_circle(point([cx, cy]), Geom::Vector3d.new(0, 0, 1), bubble[:radius].mm, CIRCLE_SEGMENTS)
        edges.each { |e| e.layer = tag }
        label = sym.entities.add_group
        label.name = "Tên trục #{axis[:name]}"
        label.layer = tag
        label.entities.add_3d_text(axis[:name], TextAlignCenter, FONT, false, false, axis[:text_height].mm, 0.0, 0.0, true, 0.0)
        center = label.bounds.center
        label.transform!(Geom::Transformation.translation(Geom::Vector3d.new(point([cx, cy]).x - center.x, point([cx, cy]).y - center.y, 0)))
      end

      def self.point(xy)
        Geom::Point3d.new(xy[0].mm, xy[1].mm, 0)
      end
    end
  end
end
