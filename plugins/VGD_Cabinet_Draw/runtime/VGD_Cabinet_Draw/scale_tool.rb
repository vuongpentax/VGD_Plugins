module VGD_Cabinet_Draw
  module Tools
    # Lệnh Scale VGD (giống Scale gốc của SketchUp): 6 điểm ở tâm các mặt của hộp tủ. Bấm một điểm = chọn mặt sẽ DỜI; mặt đối diện
    # đứng yên (điểm neo). Kéo chuột (hoặc gõ số) theo trục đó: mặt đã bấm dời tới con trỏ, số hiện là kích thước MỚI theo trục.
    # Click (hoặc gõ số rồi Enter) để áp dụng.
    # Co giãn kiểu stretch bằng Resize.apply_axis (không làm méo mộng và dấu tiết diện). Chỉ dùng cho tủ VGD.
    class ScaleTool
      PICK_PIXELS = 14
      GRIP_RADIUS = 5
      HOVER_RADIUS = 8

      attr_reader :phase, :anchor, :handle, :hover, :size_mm

      def initialize
        @root = nil
        @phase = :pick     # :pick = chọn điểm neo, :drag = đang chọn kích thước mới
        @handle = nil      # điểm đã bấm (mặt sẽ dời)
        @anchor = nil      # điểm đối diện (mặt đứng yên)
        @hover = nil
        @size_mm = nil
        @ip = Sketchup::InputPoint.new
        @active = false
      end

      def active?
        @active
      end

      def enableVCB?
        true
      end

      def activate
        @active = true
        reset_phase
        load_root(selected_root)
        invalidate
      end

      def deactivate(view)
        @active = false
        Sketchup.vcb_value = '' if Sketchup.respond_to?(:vcb_value=)
        view.invalidate if view
      end

      def resume(view)
        view.invalidate if view
      end

      def commit(view)
        apply_size(@size_mm, view) if @phase == :drag && @size_mm
      end

      def cancel_tool(view)
        view.model.select_tool(nil)
        Dialog.set_status('Đã thoát lệnh Scale VGD.')
      end

      # 6 điểm neo (tâm các mặt của hộp tủ): [{ axis: 0..2, side: :min/:max, point: điểm thế giới }].
      def grips
        return [] unless usable_root?
        dims = Rebuild.dimensions_of(@root)
        tr = @root.transformation
        [0, 1, 2].flat_map do |axis|
          %i[min max].map do |side|
            local = dims.map { |d| (d / 2.0).mm }
            local[axis] = side == :max ? dims[axis].mm : 0.0
            { axis: axis, side: side, point: Geom::Point3d.new(*local).transform(tr) }
          end
        end
      end

      def select_grip(grip, view)
        return unless grip
        @handle = grip
        @anchor = grips.find { |g| g[:axis] == grip[:axis] && g[:side] != grip[:side] }
        @phase = :drag
        @size_mm = Rebuild.dimensions_of(@root)[grip[:axis]]
        status("Kéo mặt #{side_label(grip)} (mặt #{side_label(@anchor)} đứng yên) tới kích thước mới, hoặc gõ số mm rồi Enter · click: áp dụng · Esc: chọn điểm khác.")
        show_vcb
        view.invalidate if view
      end

      def onMouseMove(_flags, x, y, view)
        if @phase == :pick
          @hover = grip_near(view, x, y)
        else
          track_cursor(view, x, y)
          show_vcb
        end
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, view)
        if @root.nil?
          root = picked_cabinet(view, x, y)
          return unless root
          Sketchup.active_model.selection.clear
          Sketchup.active_model.selection.add(root)
          load_root(root)
          view.invalidate
        elsif @phase == :pick
          select_grip(grip_near(view, x, y), view)
        else
          track_cursor(view, x, y)
          commit(view)
        end
      end

      def onUserText(text, view)
        unless @phase == :drag
          status('Hãy bấm một điểm trên tủ trước (mặt sẽ dời), rồi gõ kích thước mới (mm).')
          return
        end
        apply_size(Resize.parse_size(text), view)
      rescue ArgumentError => e
        status(e.message)
      end

      def onReturn(view)
        commit(view)
      end

      # Esc: đang kéo thì chỉ bỏ điểm neo; ở bước chọn điểm neo thì thoát lệnh. Undo/chọn lại lệnh: về bước chọn điểm neo.
      def onCancel(reason, view)
        if reason == 0 && @phase == :drag
          reset_phase
          status('Đã bỏ chọn. Chọn điểm khác hoặc Esc để thoát.')
          view.invalidate if view
        elsif reason == 0
          cancel_tool(view)
        else
          reset_phase
          view.invalidate if view
        end
      end

      def draw(view)
        return unless usable_root?
        draw_preview_box(view) if @phase == :drag && @anchor
        draw_grips(view)
        draw_size_label(view) if @phase == :drag && @size_mm
      end

      private

      def reset_phase
        @phase = :pick
        @handle = nil
        @anchor = nil
        @hover = nil
        @size_mm = nil
      end

      def usable_root?
        !@root.nil? && @root.valid?
      end

      def selected_root
        roots = ModelData.cabinets_in(Sketchup.active_model.selection.to_a.select(&:valid?))
        roots.length == 1 ? roots.first : nil
      end

      def picked_cabinet(view, x, y)
        helper = view.pick_helper
        helper.do_pick(x, y)
        (helper.path_at(0) || []).select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }.reverse.find { |e| ModelData.cabinet?(e) }
      end

      def load_root(root)
        @root = nil
        if root.nil?
          status('Hãy chọn một tủ VGD (hoặc click vào tủ) rồi bấm một điểm trên tủ.')
        elsif Rebuild.scale_of(root)
          status('Tủ đang bị Scale chưa cập nhật. Hãy đợi tự cập nhật hoặc Undo rồi chạy lại Scale VGD.')
        else
          @root = root
          status('Rê chuột vào điểm ở tâm mặt muốn dời rồi click (mặt đối diện đứng yên). Esc: thoát.')
        end
      rescue ArgumentError => e
        status(e.message)
      end

      def status(message)
        Sketchup.status_text = message
        Dialog.set_status(message)
      end

      def show_vcb
        return unless Sketchup.respond_to?(:vcb_label=)
        Sketchup.vcb_label = @phase == :drag ? "#{Resize::AXIS_NAMES[@anchor[:axis]]} (mm)" : ''
        Sketchup.vcb_value = @phase == :drag && @size_mm ? format('%.1f', @size_mm) : ''
      end

      def side_label(grip)
        face = { [0, :min] => 'trái', [0, :max] => 'phải', [1, :min] => 'trước', [1, :max] => 'sau', [2, :min] => 'đáy', [2, :max] => 'nóc' }
        face.fetch([grip[:axis], grip[:side]])
      end

      def invalidate
        Sketchup.active_model.active_view.invalidate
      end

      def grip_near(view, x, y)
        grips.map { |g| [g, (view.screen_coords(g[:point]).x - x)**2 + (view.screen_coords(g[:point]).y - y)**2] }
             .select { |_, d| d <= PICK_PIXELS**2 }.min_by { |_, d| d }&.first
      end

      # Hướng (vectơ đơn vị thế giới) từ điểm neo về mặt đối diện.
      def direction
        axis = [Geom::Vector3d.new(1, 0, 0), Geom::Vector3d.new(0, 1, 0), Geom::Vector3d.new(0, 0, 1)][@anchor[:axis]].transform(@root.transformation)
        axis.normalize!
        @anchor[:side] == :min ? axis : axis.reverse
      end

      # Kích thước mới theo con trỏ. Chính: giao tia chuột với mặt phẳng chứa trục và vuông góc hướng nhìn, rồi chiếu lên trục
      # (đúng như Scale gốc, ở góc nhìn 45° hay nhìn cao đều theo sát chuột). Nhìn gần song song với trục (không đo được):
      # dùng điểm suy luận chiếu lên trục. Làm tròn 1 mm.
      def track_cursor(view, x, y)
        return unless @anchor
        size = size_from_ray(view, x, y)
        unless size
          @ip.pick(view, x, y)
          size = size_from(@ip.position) if @ip.valid?
        end
        @size_mm = size.round if size
      end

      def size_from_ray(view, x, y)
        d = direction
        cam = view.camera.direction
        k = cam.dot(d)
        normal = Geom::Vector3d.new(cam.x - d.x * k, cam.y - d.y * k, cam.z - d.z * k)
        return nil if normal.length < 0.25 # nhìn gần song song với trục
        normal.normalize!
        point = Geom.intersect_line_plane(view.pickray(x, y), [@anchor[:point], normal])
        point ? (point - @anchor[:point]).dot(d).to_mm : nil
      end

      def size_from(position)
        (position - @anchor[:point]).dot(direction).to_mm
      end

      def apply_size(size, view)
        Resize.check_size!(size)
        axis = @anchor[:axis]
        root = @root
        if Resize.apply_axis(root, axis, size, @anchor[:side])
          status("Đã đổi #{Resize::AXIS_NAMES[axis].downcase} tủ thành #{format('%g', size.round(1))} mm.")
        else
          status('Kích thước không đổi hoặc không áp dụng được.')
        end
        reset_phase
        invalidate
      rescue ArgumentError => e
        status(e.message)
      end

      # ----- Vẽ -----
      def screen_polygon(view, point, radius)
        s = view.screen_coords(point)
        (0...20).map { |i| a = 2 * Math::PI * i / 20; [s.x + radius * Math.cos(a), s.y + radius * Math.sin(a), 0] }
      end

      def draw_grips(view)
        grips.each do |g|
          active = @handle && @handle[:axis] == g[:axis] && @handle[:side] == g[:side]
          fixed = @anchor && @anchor[:axis] == g[:axis] && @anchor[:side] == g[:side]
          hovered = @hover && @hover[:axis] == g[:axis] && @hover[:side] == g[:side]
          pts = screen_polygon(view, g[:point], hovered || active ? HOVER_RADIUS : GRIP_RADIUS)
          view.drawing_color = active ? Theme.color(:accent) : (fixed ? Theme.color(:tint) : Theme.color(:surface))
          view.draw2d(GL_POLYGON, pts)
          view.drawing_color = Theme.accent_line
          view.line_width = 2 if view.respond_to?(:line_width=)
          view.draw2d(GL_LINE_LOOP, pts)
        end
      end

      # Khung hộp tủ hiện tại (mảnh) và khung sau khi đổi (đậm); mặt đang dời vẽ nét chấm.
      def draw_preview_box(view)
        dims = Rebuild.dimensions_of(@root)
        axis = @anchor[:axis]
        size = [@size_mm, 1.0].max
        new_dims = dims.dup
        new_dims[axis] = size
        origin = [0.0, 0.0, 0.0]
        origin[axis] = (dims[axis] - size).mm if @anchor[:side] == :max
        draw_box(view, [0.0, 0.0, 0.0], dims, Preview.edge_color, 1, '')
        draw_box(view, origin, new_dims, Theme.accent_line, 2, '')
        # Mặt đối diện điểm neo (mặt đang dời): mặt cao của khung mới nếu neo mặt thấp, mặt thấp nếu neo mặt cao.
        draw_moving_face(view, origin, new_dims, axis, @anchor[:side] == :min ? size.mm : origin[axis])
      end

      def box_corners(origin, dims)
        tr = @root.transformation
        (0..7).map do |i|
          Geom::Point3d.new(origin[0] + (i & 1 == 1 ? dims[0].mm : 0), origin[1] + (i & 2 == 2 ? dims[1].mm : 0), origin[2] + (i & 4 == 4 ? dims[2].mm : 0)).transform(tr)
        end
      end

      def draw_box(view, origin, dims, color, width, stipple)
        c = box_corners(origin, dims)
        edges = [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
        view.drawing_color = color
        view.line_width = width if view.respond_to?(:line_width=)
        view.line_stipple = stipple if view.respond_to?(:line_stipple=)
        view.draw_lines(edges.flat_map { |a, b| [c[a], c[b]] })
      end

      def draw_moving_face(view, origin, dims, axis, face_offset)
        tr = @root.transformation
        others = [0, 1, 2] - [axis]
        corners = [[0, 0], [1, 0], [1, 1], [0, 1]].map do |u, w|
          local = origin.dup
          local[axis] = face_offset
          local[others[0]] = origin[others[0]] + u * dims[others[0]].mm
          local[others[1]] = origin[others[1]] + w * dims[others[1]].mm
          Geom::Point3d.new(*local).transform(tr)
        end
        view.drawing_color = Theme.accent_line
        view.line_width = 2 if view.respond_to?(:line_width=)
        view.line_stipple = '.' if view.respond_to?(:line_stipple=)
        view.draw_lines(corners.each_with_index.flat_map { |p, i| [p, corners[(i + 1) % 4]] })
        view.line_stipple = '' if view.respond_to?(:line_stipple=)
      end

      def draw_size_label(view)
        grip = grips.find { |g| g[:axis] == @anchor[:axis] && g[:side] == @anchor[:side] }
        return unless grip
        far = grip[:point].offset(direction, [@size_mm, 1.0].max.mm)
        s = view.screen_coords(far)
        text = format('%g', @size_mm) # preview chỉ hiện số
        left = s.x + 14
        top = s.y - 30
        view.drawing_color = Theme.color(:surface, 235)
        view.draw2d(GL_QUADS, [[left - 6, top - 3, 0], [left + 12 + text.length * 7, top - 3, 0], [left + 12 + text.length * 7, top + 20, 0], [left - 6, top + 20, 0]])
        Theme.draw_text(view, [left, top], text, color: Theme.color(:text), size: 11, bold: true)
      end
    end
  end
end
