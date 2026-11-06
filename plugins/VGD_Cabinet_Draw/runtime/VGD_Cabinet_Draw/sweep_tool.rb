module VGD_Cabinet_Draw
  module Tools
    # Lệnh Quét & dời tấm: quét chọn nhiều group/component của một tủ rồi dời cùng một khoảng.
    #   - Quét khung: kéo trái→phải chọn tấm nằm TRỌN trong khung; phải→trái chọn mọi tấm CHẠM khung.
    #   - Quét cọ (Tab): giữ chuột rê qua các tấm, tấm nào nét đi qua thì được chọn. Shift: cộng thêm. Click: chọn một tấm.
    #   - F đổi bộ lọc (tất cả / hồi và đợt / chỉ hồi / chỉ đợt).
    #   - Dời: chọn xong click một lần nữa để kéo đi (di chuột rồi click đặt), hoặc gõ số mm rồi Enter (số âm = ngược lại), hoặc Enter
    #     để bắt đầu kéo. Esc: lùi một bước. Preview chỉ hiện số (không đơn vị, không chữ).
    #   - Hồi (vách) dời ngang và đợt dời đứng theo bước tạo tấm (lưu lại, Scale/dựng lại tủ vẫn giữ; cánh tự động đi theo).
    #     Tấm khác (hông, đáy, hậu, cánh, ngăn kéo, vật tự vẽ) chỉ dời khi đã khóa trục bằng phím mũi tên
    #     (→ trái–phải, ← trước–sau, ↑/↓ lên–xuống; bấm lại để bỏ khóa) và bị đánh dấu chỉnh tay.
    class SweepTool
      OPERATION = 'VGD Cabinet Draw — Dời tấm'.freeze
      MIN_DRAG_PX = 4
      CLICK_PX = 3.0
      BRUSH_PX = 2.0
      MAX_MM = 10_000.0
      FILTERS = %i[all members vach dot].freeze
      FILTER_LABELS = { all: 'tất cả', members: 'hồi và đợt', vach: 'chỉ hồi (vách)', dot: 'chỉ đợt' }.freeze
      AXIS_LABELS = ['trái–phải', 'trước–sau', 'lên–xuống'].freeze

      attr_reader :phase, :mode, :filter, :axis_lock, :distance_mm

      def initialize
        @root = nil
        @shell = nil
        @items = []
        @selected = []
        @phase = :select # :select = chọn tấm, :move = đang di chuột để chọn khoảng dời
        @mode = :rect    # :rect = quét khung, :brush = quét cọ
        @filter = :all
        @axis_lock = nil
        @distance_mm = 0.0
        @down = nil
        @cursor = nil
        @path = []
        @drag = false
        @shift = false
        @start_param = nil
        @ip = Sketchup::InputPoint.new
        @active = false
      end

      def active?
        @active
      end

      def enableVCB?
        true
      end

      def items
        @items
      end

      def selected
        @selected.select(&:valid?)
      end

      def activate
        @active = true
        reset_state
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
        @phase == :move ? apply_distance(@distance_mm, view) : start_move(view)
      end

      def cancel_tool(view)
        view.model.select_tool(nil)
        Dialog.set_status('Đã thoát lệnh Quét & dời tấm.')
      end

      # ----- Sự kiện chuột / phím -----
      def onMouseMove(flags, x, y, view)
        @cursor = [x, y]
        @shift = Keys.shift?(flags)
        if @phase == :move
          param = axis_param(view, x, y)
          @distance_mm = (param - @start_param).round if param && @start_param
          Sketchup.vcb_value = format('%g', @distance_mm) if Sketchup.respond_to?(:vcb_value=)
        elsif @down
          @drag = true if !@drag && [(x - @down[0]).abs, (y - @down[1]).abs].max >= MIN_DRAG_PX
          @path << [x, y] if @drag
        end
        view.invalidate
      end

      def onLButtonDown(flags, x, y, view)
        @shift = Keys.shift?(flags)
        if @root.nil?
          root = picked_cabinet(view, x, y)
          return unless root
          Sketchup.active_model.selection.clear
          Sketchup.active_model.selection.add(root)
          load_root(root)
          view.invalidate
        elsif @phase == :move
          apply_distance(@distance_mm, view)
        else
          @down = [x, y]
          @path = [[x, y]]
          @drag = false
        end
      end

      def onLButtonUp(flags, x, y, view)
        return unless @down
        @shift = Keys.shift?(flags)
        down = @down
        @down = nil
        if @drag
          @path << [x, y]
          finish_sweep(down, [x, y], view)
        elsif !@shift && !selected.empty?
          # Đã có vùng chọn: click tiếp theo là điểm bắt đầu kéo đi (không cần Enter). Muốn chọn lại: kéo khung mới hoặc Esc.
          @cursor = [x, y]
          start_move(view)
        else
          click_select(x, y, view)
        end
        @path = []
        @drag = false
        view.invalidate
      end

      def onKeyDown(key, _repeat, _flags, view)
        if Keys.tab?(key)
          return true unless @phase == :select
          @mode = @mode == :rect ? :brush : :rect
          status("Chế độ #{@mode == :rect ? 'quét khung (trái→phải: nằm trọn; phải→trái: chạm khung)' : 'quét cọ (rê qua các tấm)'}. Tab: đổi · Shift: cộng thêm.")
          true
        elsif Keys.letter?(key, 'f')
          @filter = FILTERS[(FILTERS.index(@filter) + 1) % FILTERS.length]
          status("Bộ lọc quét: #{FILTER_LABELS[@filter]}. F: đổi.")
          true
        elsif (dir = Keys.arrow(key))
          lock_axis({ right: 0, left: 1, up: 2, down: 2 }.fetch(dir), view)
          true
        else
          false
        end
      end

      def onReturn(view)
        commit(view)
      end

      def onUserText(text, view)
        apply_distance(parse_mm(text), view)
      rescue ArgumentError => e
        status(e.message)
      end

      # Esc lùi một bước: đang dời → về chọn; đang có vùng chọn → bỏ chọn; không còn gì → thoát lệnh. Undo / chọn lại lệnh: về bước chọn.
      def onCancel(reason, view)
        if reason != 0
          @phase = :select
          @down = nil
          load_items
        elsif @phase == :move
          @phase = :select
          status('Đã hủy bước dời. Gõ số mm + Enter để dời, hoặc chọn lại.')
        elsif !@selected.empty?
          @selected = []
          status(select_hint)
        else
          cancel_tool(view)
          return
        end
        view.invalidate if view
      end

      def draw(view)
        return unless usable_root?
        draw_hover(view)
        draw_selected(view)
        draw_sweep(view) if @down && @drag
        draw_ghosts(view) if @phase == :move
      end

      private

      def reset_state
        @selected = []
        @phase = :select
        @down = nil
        @drag = false
        @path = []
        @axis_lock = nil
        @distance_mm = 0.0
      end

      def usable_root?
        !@root.nil? && @root.valid? && !@shell.nil? && @shell.valid?
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
        @shell = nil
        @items = []
        if root.nil?
          status('Hãy chọn một tủ VGD (hoặc click vào tủ) rồi quét chọn các tấm.')
        elsif Rebuild.scale_of(root)
          status('Tủ đang bị Scale chưa cập nhật. Hãy đợi tự cập nhật hoặc Undo rồi chạy lại.')
        else
          @root = root
          @shell = Geometry.shell_for(root)
          load_items
          status(select_hint)
        end
      rescue ArgumentError => e
        status(e.message)
      end

      def select_hint
        "Kéo khung để chọn tấm (Tab: quét cọ · F: bộ lọc · Shift: cộng thêm); chọn xong click một lần nữa để kéo đi, hoặc gõ số mm + Enter. Hồi dời ngang, đợt dời đứng; tấm khác cần khóa trục bằng phím mũi tên."
      end

      def status(message)
        Sketchup.status_text = message
        Dialog.set_status(message)
      end

      def invalidate
        Sketchup.active_model.active_view.invalidate
      end

      # Mọi group/component của tủ: tấm trong thùng tủ, cánh, mặt và thùng ngăn kéo.
      def load_items
        return @items = [] unless usable_root?
        entities = Interior.containers(@shell)
        entities += Operations.doors_of(@root)
        drawers = @root.definition.entities.to_a.find { |e| e.is_a?(Sketchup::Group) && e.valid? && e.name == Operations::DRAWER_CONTAINER }
        entities += drawers.definition.entities.to_a.select { |e| e.valid? && (DrawerSlide.front?(e) || DrawerSlide.box?(e)) } if drawers
        @items = entities.select(&:valid?).map { |e| { entity: e, axis: member_axis(e), member: !member_axis(e).nil? } }
      end

      def member_axis(entity)
        case Interior.role_of(entity)
        when 'partition' then 0
        when 'shelf' then 2
        end
      end

      def entry_of(entity)
        @items.find { |item| item[:entity].equal?(entity) }
      end

      def allowed?(item)
        case @filter
        when :members then item[:member]
        when :vach then item[:axis] == 0
        when :dot then item[:axis] == 2
        else true
        end
      end

      # ----- Hình chiếu màn hình -----
      def world_transform
        Operations.world_transform(@root, @shell)
      end

      def corners_of(entity)
        b = entity.bounds
        tr = world_transform
        [b.min.x, b.max.x].product([b.min.y, b.max.y], [b.min.z, b.max.z]).map { |x, y, z| Geom::Point3d.new(x, y, z).transform(tr) }
      end

      def hull_of(entity, view)
        ScreenPick.hull(corners_of(entity).map { |p| s = view.screen_coords(p); [s.x, s.y] })
      end

      def hull_area(hull)
        return 0.0 if hull.length < 3
        (0...hull.length).sum { |i| a = hull[i]; b = hull[(i + 1) % hull.length]; a[0] * b[1] - b[0] * a[1] }.abs / 2.0
      end

      # ----- Chọn -----
      def finish_sweep(down, up, view)
        hits =
          if @mode == :rect
            box = ScreenPick.rect(down[0], down[1], up[0], up[1])
            window = up[0] >= down[0]
            @items.select { |item| allowed?(item) }.select do |item|
              hull = hull_of(item[:entity], view)
              window ? ScreenPick.inside_rect?(hull, box) : ScreenPick.hull_touches_rect?(hull, box)
            end
          else
            @items.select { |item| allowed?(item) }.select { |item| ScreenPick.touched_by_path?(hull_of(item[:entity], view), @path, BRUSH_PX) }
          end
        apply_hits(hits.map { |item| item[:entity] })
      end

      def click_select(x, y, view)
        hit = @items.select { |item| allowed?(item) }
                    .select { |item| ScreenPick.hull_touches_point?(hull_of(item[:entity], view), [x, y], CLICK_PX) }
                    .min_by { |item| hull_area(hull_of(item[:entity], view)) }
        if hit.nil?
          @selected = [] unless @shift
          report_selection
        elsif @shift
          entity = hit[:entity]
          @selected.include?(entity) ? @selected.delete(entity) : @selected << entity
          report_selection
        else
          @selected = [hit[:entity]]
          report_selection
        end
      end

      def apply_hits(entities)
        @selected = @shift ? (selected + entities).uniq : entities
        report_selection
      end

      def report_selection
        list = selected
        if list.empty?
          status(select_hint)
        else
          members = list.count { |e| !member_axis(e).nil? }
          status("Đã chọn #{list.length} tấm (#{members} hồi/đợt, #{list.length - members} tấm khác). Click để kéo đi (hoặc gõ số mm + Enter). Kéo khung mới hoặc Esc để chọn lại. #{lock_hint}")
        end
      end

      def lock_hint
        @axis_lock ? "Đang khóa trục #{AXIS_LABELS[@axis_lock]} cho tấm khác." : 'Tấm khác chỉ dời khi khóa trục bằng phím mũi tên.'
      end

      def lock_axis(axis, view)
        @axis_lock = @axis_lock == axis ? nil : axis
        status(@axis_lock ? "Khóa trục #{AXIS_LABELS[@axis_lock]} (tấm khác dời theo trục này). Bấm lại phím để bỏ khóa." : 'Đã bỏ khóa trục.')
        view.invalidate if view
      end

      # ----- Dời -----
      # Trục dùng để đo khoảng dời bằng chuột: trục khóa, hoặc trục của số hồi/đợt đã chọn nhiều hơn.
      def primary_axis
        return @axis_lock unless @axis_lock.nil?
        counts = selected.filter_map { |e| member_axis(e) }.tally
        counts.empty? ? nil : counts.max_by { |axis, n| [n, -axis] }.first
      end

      def start_move(view)
        list = selected
        return status('Chưa chọn tấm nào. Kéo khung để chọn trước.') if list.empty?
        axis = primary_axis
        return status('Hãy khóa trục bằng phím mũi tên (→ trái–phải, ← trước–sau, ↑ lên–xuống) rồi click để kéo tấm này.') if axis.nil?
        x, y = @cursor || [0, 0]
        param = axis_param(view, x, y)
        return status('Không đo được khoảng dời từ góc nhìn này: hãy xoay nhìn nghiêng hơn, hoặc gõ số mm.') unless param
        @start_param = param
        @distance_mm = 0.0
        @phase = :move
        status("Di chuột để chọn khoảng dời (#{AXIS_LABELS[axis]}), click để áp dụng, hoặc gõ số mm + Enter. Esc: hủy.")
      end

      def axis_vector(axis)
        v = [Geom::Vector3d.new(1, 0, 0), Geom::Vector3d.new(0, 1, 0), Geom::Vector3d.new(0, 0, 1)][axis].transform(world_transform)
        v.normalize!
        v
      end

      def selection_center
        pts = selected.flat_map { |e| corners_of(e) }
        Geom::Point3d.new(pts.sum(&:x) / pts.length, pts.sum(&:y) / pts.length, pts.sum(&:z) / pts.length)
      end

      # Vị trí (mm) của con trỏ dọc trục chính, đo từ tâm vùng chọn: giao tia chuột với mặt phẳng chứa trục và vuông góc hướng nhìn.
      # Nhìn gần song song với trục thì dùng điểm suy luận.
      def axis_param(view, x, y)
        axis = primary_axis
        return nil if axis.nil? || selected.empty?
        d = axis_vector(axis)
        origin = selection_center
        cam = view.camera.direction
        k = cam.dot(d)
        normal = Geom::Vector3d.new(cam.x - d.x * k, cam.y - d.y * k, cam.z - d.z * k)
        if normal.length >= 0.25
          normal.normalize!
          point = Geom.intersect_line_plane(view.pickray(x, y), [origin, normal])
          return (point - origin).dot(d).to_mm if point
        end
        @ip.pick(view, x, y)
        @ip.valid? ? (@ip.position - origin).dot(d).to_mm : nil
      end

      def parse_mm(text)
        value = Float(text.to_s.strip.sub(/\s*mm\z/i, '').tr(',', '.'))
        raise ArgumentError, 'Khoảng dời phải là số mm (âm = dời ngược lại).' unless value.abs <= MAX_MM
        value
      rescue ArgumentError, TypeError
        raise ArgumentError, 'Khoảng dời phải là số mm, ví dụ 50 hoặc -30.'
      end

      def apply_distance(mm, view)
        list = selected
        return status('Chưa chọn tấm nào. Kéo khung để chọn trước.') if list.empty?
        return status('Khoảng dời bằng 0, không có gì để đổi.') if mm.to_f.abs < 0.01
        members = list.select { |e| !member_axis(e).nil? }
        others = list - members
        skipped = []
        if others.any? && @axis_lock.nil?
          skipped = others
          others = []
        end
        if members.empty? && others.empty?
          return status("Chưa dời: #{skipped.length} tấm không phải hồi/đợt, hãy khóa trục bằng phím mũi tên (→ trái–phải, ← trước–sau, ↑ lên–xuống) rồi gõ lại.")
        end
        result = move_in_operation(members, others, mm)
        return unless result
        finish_move(result, skipped)
      end

      def move_in_operation(members, others, mm)
        model = Sketchup.active_model
        keys = others.map { |e| [e, Rebuild.stretch_key(e)] }
        model.start_operation(OPERATION, true)
        begin
          moved = Removal.move_members(@root, members.map { |m| [m, mm] }) unless members.empty?
          warnings = moved ? moved[:warnings] : []
          @shell = Geometry.shell_for(@root)
          moved_others = move_others(keys, mm)
        rescue StandardError => e
          model.abort_operation
          load_items
          status(e.message)
          return nil
        end
        model.commit_operation
        { warnings: warnings, offsets: moved ? moved[:offsets] : {}, others: moved_others, members: members.length }
      end

      # Dời tấm khác theo trục khóa (trong hệ tủ): chạy sau khi dựng lại hồi/đợt nên tìm lại tấm theo khóa nhận diện.
      def move_others(keys, mm)
        return [] if keys.empty?
        fresh = (Rebuild.stretch_items(@root, @shell) || {})
        vector = [[1, 0, 0], [0, 1, 0], [0, 0, 1]][@axis_lock].map { |c| (c * mm).mm }
        keys.filter_map do |entity, key|
          target = key && fresh[key] ? fresh[key] : (entity.valid? ? entity : nil)
          next unless target
          target.transformation = Geom::Transformation.translation(vector) * target.transformation
          target
        end
      end

      def finish_move(result, skipped)
        load_items
        @selected = reselect_members(result[:offsets]) + result[:others]
        @phase = :select
        text = "Đã dời #{result[:members] + result[:others].length} tấm #{format('%g', @distance_mm.zero? ? 0 : 0)}".rstrip
        text = "Đã dời #{result[:members]} hồi/đợt và #{result[:others].length} tấm khác."
        text += " #{skipped.length} tấm khác không dời vì chưa khóa trục." unless skipped.empty?
        text += " Lưu ý: #{result[:warnings].uniq.join('; ')}" unless result[:warnings].empty?
        status(text)
        invalidate
      end

      # Tìm lại các hồi/đợt đã dời (sau khi dựng lại) theo vị trí mới trong bước tạo.
      def reselect_members(offsets)
        return [] if offsets.empty?
        inner = Interior.inner(@shell)
        found = []
        offsets.each do |op_id, list|
          list.each do |mm|
            @items.each do |item|
              entity = item[:entity]
              next unless item[:member] && ModelData.params(entity)['op'] == op_id && !found.include?(entity)
              box = Interior.box_of(entity)
              pos = item[:axis] == 0 ? box[0] - inner.x0 : box[2] - inner.z0
              if (pos.to_mm - mm).abs < 0.6
                found << entity
                break
              end
            end
          end
        end
        found
      end

      # ----- Vẽ -----
      def draw_box(view, entity, color, width, stipple = '', shift = nil)
        c = corners_of(entity)
        c = c.map { |p| p.offset(shift[0], shift[1]) } if shift
        edges = [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
        view.drawing_color = color
        view.line_width = width if view.respond_to?(:line_width=)
        view.line_stipple = stipple if view.respond_to?(:line_stipple=)
        view.draw_lines(edges.flat_map { |a, b| [c[a], c[b]] })
        view.line_stipple = '' if view.respond_to?(:line_stipple=)
      end

      def draw_hover(view)
        return unless @phase == :select && @cursor && !@down
        hit = @items.select { |item| allowed?(item) }
                    .select { |item| ScreenPick.hull_touches_point?(hull_of(item[:entity], view), @cursor, CLICK_PX) }
                    .min_by { |item| hull_area(hull_of(item[:entity], view)) }
        draw_box(view, hit[:entity], Preview.edge_color, 1) if hit
      end

      def draw_selected(view)
        selected.each { |entity| draw_box(view, entity, Theme.accent_line, 3) }
      end

      def draw_sweep(view)
        if @mode == :rect
          x0, y0 = @down
          x1, y1 = @path.last
          pts = [[x0, y0, 0], [x1, y0, 0], [x1, y1, 0], [x0, y1, 0]]
          view.drawing_color = Theme.color(:accent, x1 >= x0 ? 45 : 25)
          view.draw2d(GL_QUADS, pts)
          view.drawing_color = Theme.accent_line
          view.line_width = 1 if view.respond_to?(:line_width=)
          view.line_stipple = x1 >= x0 ? '' : '-' if view.respond_to?(:line_stipple=)
          view.draw2d(GL_LINE_LOOP, pts)
          view.line_stipple = '' if view.respond_to?(:line_stipple=)
        else
          view.drawing_color = Theme.accent_line
          view.line_width = 3 if view.respond_to?(:line_width=)
          view.draw2d(GL_LINE_STRIP, @path.map { |x, y| [x, y, 0] }) if @path.length >= 2
        end
      end

      # Hình bóng nơi các tấm sẽ tới: hồi/đợt theo hướng riêng, tấm khác theo trục khóa; kèm nhãn khoảng dời.
      def draw_ghosts(view)
        selected.each do |entity|
          axis = member_axis(entity) || @axis_lock
          next unless axis
          draw_box(view, entity, Theme.accent_line, 2, '.', [axis_vector(axis), @distance_mm.mm])
        end
        return unless @cursor
        text = format('%g', @distance_mm) # preview chỉ hiện số
        left = @cursor[0] + 14
        top = @cursor[1] - 30
        view.drawing_color = Theme.color(:surface, 235)
        view.draw2d(GL_QUADS, [[left - 6, top - 3, 0], [left + 12 + text.length * 7, top - 3, 0], [left + 12 + text.length * 7, top + 20, 0], [left - 6, top + 20, 0]])
        Theme.draw_text(view, [left, top], text, color: Theme.color(:text), size: 11, bold: true)
      end
    end
  end
end
