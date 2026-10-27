module VGD_Cabinet_Draw
  module Tools
    extend self

    class Base
      attr_reader :settings

      def initialize(settings = {})
        @settings = Schema.merge_settings(settings)
        @preview = Preview.new
        @phase = :pick
        @ip = Sketchup::InputPoint.new
        @active = false
      end

      def active?
        @active
      end

      def update_settings(settings)
        @settings = Schema.merge_settings(settings)
        rebuild_preview if respond_to?(:rebuild_preview)
        Sketchup.active_model.active_view.invalidate
      end

      # Bắt buộc phải khai báo true thì ô VCB mới nhận chữ và gọi onUserText.
      def enableVCB?
        true
      end

      def activate
        @active = true
        Sketchup.active_model.active_view.invalidate
      end

      def deactivate(view)
        @active = false
        view.invalidate if view
      end

      def resume(view)
        view.invalidate if view
      end

      # Mặc định: không có bước chờ. Lệnh nào có bước chờ (box đã chọn, mặt đã khóa...) thì khai báo pending?/clear_pending!.
      def pending?
        false
      end

      def clear_pending!; end

      # Sẵn sàng áp dụng: click vùng trống hoặc Enter sẽ tạo. Lệnh không có bước áp dụng thì để false.
      def ready?
        false
      end

      # Click vùng trống (không trúng vật thể nào) khi lệnh đã sẵn sàng: áp dụng, lệnh vẫn chạy tiếp.
      def click_finish?(view, x, y)
        return false unless ready?
        return false unless picked_path(view, x, y).empty?
        commit(view)
        true
      end

      # Space: thoát về Chọn của SketchUp (giống SketchUp), tắt chế độ VGD Chọn để không bị bật lại.
      def leave_to_select(view)
        VGD_Cabinet_Draw.stop_pick_mode if VGD_Cabinet_Draw.respond_to?(:stop_pick_mode)
        view.model.select_tool(nil)
        Dialog.set_status('Đã thoát lệnh, về Chọn của SketchUp.')
      end

      # reason 0 = Esc, 1 = chọn lại cùng công cụ, 2 = Undo khi công cụ đang chạy.
      # Esc lần 1: nếu đang có bước chờ thì chỉ hủy bước đó; lần 2 (hoặc không có bước chờ) mới thoát lệnh.
      def onCancel(reason, view)
        if reason == 0 && pending?
          clear_pending!
          rebuild_preview if respond_to?(:rebuild_preview)
          Dialog.set_status('Đã hủy bước đang chọn. Esc lần nữa để thoát lệnh.')
          view.invalidate if view
        elsif reason == 0
          cancel_tool(view)
        else
          rebuild_preview if respond_to?(:rebuild_preview)
          view.invalidate if view
        end
      end

      def cancel_tool(view)
        view.model.select_tool(nil)
        Dialog.set_status('Đã hủy thao tác.')
      end

      # Enter. (SketchUp 2025.0 trên Windows có lỗi không gọi onReturn; đã có nút Áp dụng trong bảng.)
      def onReturn(view)
        commit(view)
      end

      def onMouseMove(_flags, x, y, view)
        @ip.pick(view, x, y)
        @mouse = Geom::Point3d.new(@ip.position) if @ip.valid?
        view.invalidate
      end

      def draw(view)
        @preview.draw(view)
        @ip.draw(view) if @ip.valid?
        draw_hud(view)
      end

      def draw_hud(view)
        lines = ["VGD CABINET DRAW · #{Tools.label(@tool_name)}", hint]
        lines.each_with_index do |text, index|
          view.draw_text([18, 28 + index * 20], text, color: Sketchup::Color.new(33, 77, 90), size: 11, bold: index.zero?)
        end
        draw_side_panel(view, hud_lines) if respond_to?(:hud_lines)
      end

      # Bảng thông tin bên phải viewport. Dòng bắt đầu bằng "Lỗi:" tô đỏ.
      def draw_side_panel(view, lines)
        return if lines.nil? || lines.empty?
        width = 330
        left = [view.vpwidth - width - 12, 10].max
        top = 12
        height = 14 + lines.length * 19
        view.drawing_color = Sketchup::Color.new(255, 255, 255, 200)
        view.draw2d(GL_QUADS, [[left, top, 0], [left + width, top, 0], [left + width, top + height, 0], [left, top + height, 0]])
        lines.each_with_index do |text, index|
          error = text.start_with?('Lỗi:')
          color = error ? Sketchup::Color.new(167, 61, 54) : Sketchup::Color.new(33, 77, 90)
          view.draw_text([left + 10, top + 8 + index * 19], text, color: color, size: 10)
        end
      end

      def hint
        'Click chọn · Enter áp dụng · Esc hủy'
      end

      # Bảng phím thống nhất: Tab đổi hướng. Enter qua onReturn, Esc qua onCancel.
      def onKeyDown(key, _repeat, _flags, view)
        if Keys.space?(key)
          leave_to_select(view)
          return true
        end
        return false unless Keys.tab?(key)
        handle_tab(view)
        true
      end

      def handle_tab(view)
        if @tool_name == 'door'
          @settings['split_axis'] = @settings['split_axis'] == 'horizontal' ? 'vertical' : 'horizontal'
          rebuild_preview
        else
          @settings['reverse_front'] = !@settings['reverse_front']
        end
        view.invalidate
      end

      def commit(view)
        raise NotImplementedError
      end

      def picked_path(view, x, y)
        helper = view.pick_helper
        helper.do_pick(x, y)
        helper.path_at(0) || []
      end

      def picked_group(view, x, y)
        picked_path(view, x, y).reverse.find { |entity| entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance) }
      end

      def picked_cabinet(view, x, y)
        picked_path(view, x, y).reverse.find { |entity| ModelData.cabinet?(entity) }
      end

      def operation(label)
        model = Sketchup.active_model
        model.start_operation("VGD Cabinet Draw — #{label}", true)
        @operation_open = true
        begin
          yield model
        rescue StandardError
          model.abort_operation
          @operation_open = false
          raise
        end
        # Từ đây thao tác đã hoàn tất. Lỗi do plugin khác (observer) ném ra lúc commit KHÔNG được
        # phép kéo theo abort_operation, vì sẽ làm model dở dang.
        begin
          model.commit_operation
        rescue StandardError => e
          @commit_warning = "Plugin khác báo lỗi lúc hoàn tất thao tác: #{e.message}"
        ensure
          @operation_open = false
        end
      end

      def self.activate_entity(model, entity)
        model.selection.clear
        model.selection.add(entity) if entity && entity.valid?
      end
    end

    # Box -> Cabinet. Trạng thái:
    #   :select_boxes  chưa có box nào
    #   :pick_front    có box nhưng còn box chưa chọn mặt trước
    #   :preview       mọi box đã có mặt trước, sẵn sàng Enter
    class BoxTool < Base
      attr_reader :state

      def initialize(settings = {})
        super
        @tool_name = 'box'
        @state = :select_boxes
        @boxes = []
        @fronts = {}     # persistent_id => vectơ mặt trước, trong hệ trục cục bộ của box
        @parents = {}    # persistent_id => phép biến đổi của các group cha (hệ thế giới)
        @overrides = {}  # persistent_id => thông số riêng của box đó
        @override_pid = nil
        @last_pid = nil
        @errors = {}
        @note = nil
      end

      def hint
        'Click mặt trước từng box · Shift-click: cấu hình riêng · Tab đảo hướng · Backspace bỏ box cuối · Enter tạo'
      end

      def status_hint
        'Click mặt trước từng box · Shift+Click: cấu hình riêng · Tab: đảo hướng · Enter: tạo · Esc: thoát'
      end

      # HUD sửa thông số riêng của box đang cấu hình riêng (nếu có), nếu không thì thông số chung.
      def hud_target_settings
        @override_pid ? (@overrides[@override_pid] ||= Schema.deep_copy(@settings)) : @settings
      end

      # Đổi Loại tủ: áp các thông số đi kèm loại đó (chân, phào, hông chạm đất...).
      def hud_after_set(key)
        apply_type_preset(hud_target_settings) if key == 'cabinet_type'
      end

      def apply_type_preset(target)
        preset = Schema::TYPE_PRESETS[target['cabinet_type'].to_s]
        target.merge!(Schema.deep_copy(preset)) if preset
        target
      end

      # Dùng luôn các box đang được chọn sẵn trong model.
      def activate
        super
        model = Sketchup.active_model
        parent = model.respond_to?(:edit_transform) ? model.edit_transform : Geom::Transformation.new
        model.selection.each do |entity|
          next unless box_candidate?(entity)
          add_box(entity, parent)
        end
        refresh_state
        note(@boxes.empty? ? 'Click vào box để bắt đầu.' : "Đã lấy #{@boxes.length} box đang chọn. Click mặt trước của từng box.")
        rebuild_preview
      end

      def box_candidate?(entity)
        (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)) && entity.valid? && !ModelData.cabinet?(entity)
      end

      def update_settings(settings)
        merged = Schema.merge_settings(settings)
        previous = (@override_pid ? @overrides[@override_pid] : @settings) || {}
        if merged['cabinet_type'] != previous['cabinet_type']
          apply_type_preset(merged)
          Dialog.push_settings(merged, false, 'box')
        end
        @settings['sync_front'] = merged['sync_front']
        if @override_pid
          @overrides[@override_pid] = merged
        else
          @settings = merged
        end
        rebuild_preview
        Sketchup.active_model.active_view.invalidate
      end

      def add_box(box, parent_transform)
        pid = box.persistent_id
        @boxes << box unless @boxes.include?(box)
        @parents[pid] = parent_transform
        pid
      end

      def remove_box(box)
        pid = box.persistent_id
        @boxes.delete(box)
        @fronts.delete(pid)
        @parents.delete(pid)
        @overrides.delete(pid)
        @override_pid = nil if @override_pid == pid
      end

      def refresh_state
        @boxes.delete_if { |box| !box.valid? }
        @state = if @boxes.empty?
                   :select_boxes
                 elsif @boxes.all? { |box| @fronts[box.persistent_id] }
                   :preview
                 else
                   :pick_front
                 end
      end

      def note(text)
        @note = text
        Dialog.set_status(text)
      end

      # Tìm box và mặt được click. Trả về [box, face, phép biến đổi cha] hoặc nil.
      def locate(path)
        face_index = path.rindex { |entity| entity.is_a?(Sketchup::Face) }
        return nil unless face_index
        containers = path[0...face_index].select { |entity| entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance) }
        return nil if containers.empty?
        return :cabinet if containers.any? { |entity| ModelData.cabinet?(entity) }
        box = containers.last
        parent = containers[0...-1].reduce(Geom::Transformation.new) { |memo, entity| memo * entity.transformation }
        [box, path[face_index], parent]
      end

      def onLButtonDown(flags, x, y, view)
        return if click_finish?(view, x, y)
        hit = locate(picked_path(view, x, y))
        if hit == :cabinet
          note('Đây đã là tủ. Muốn sửa tủ: chọn tủ (không chọn box khác) rồi bấm Box → Board.')
          return
        end
        return unless hit
        box, face, parent = hit
        pid = add_box(box, parent)
        @ip.pick(view, x, y)
        world_box = parent * box.transformation
        normal = face.normal
        if @ip.valid?
          hit_local = @ip.position.transform(world_box.inverse)
          normal = normal.reverse if normal.dot(hit_local - box.definition.bounds.center) < 0
        end
        begin
          Geometry.horizontal_front(normal)
        rescue ArgumentError => e
          note(e.message)
          return
        end
        if Keys.shift?(flags)
          toggle_override(pid)
        elsif @override_pid
          leave_override
        end
        @fronts[pid] = normal
        @last_pid = pid
        sync_fronts(box, world_box, normal) if @settings['sync_front']
        refresh_state
        rebuild_preview
        note(status_text)
        view.invalidate
      end

      # Đồng bộ: mọi box khác nhận cùng hướng mặt trước (trong hệ thế giới), gắn về trục ngang gần nhất.
      def sync_fronts(source, source_world, normal)
        world_front = normal.transform(source_world)
        @boxes.each do |other|
          next if other == source
          pid = other.persistent_id
          world_other = @parents[pid] * other.transformation
          local = world_front.transform(world_other.inverse)
          next if local.length < 1e-9
          local.normalize!
          best = [X_AXIS, X_AXIS.reverse, Y_AXIS, Y_AXIS.reverse].max_by { |axis| axis.dot(local) }
          @fronts[pid] = Geom::Vector3d.new(*best.to_a) if best.dot(local) > 0.7
        end
      end

      def toggle_override(pid)
        if @override_pid == pid
          @overrides.delete(pid)
          leave_override
        else
          @override_pid = pid
          @overrides[pid] ||= Schema.deep_copy(@settings)
          Dialog.push_settings(@overrides[pid])
        end
      end

      def leave_override
        @override_pid = nil
        Dialog.push_settings(@settings)
      end

      def ready?
        !@boxes.empty? && @boxes.all? { |box| @fronts[box.persistent_id] }
      end

      def pending?
        !@boxes.empty?
      end

      def clear_pending!
        @boxes = []
        @fronts = {}
        @parents = {}
        @overrides = {}
        @override_pid = nil
        @last_pid = nil
        @errors = {}
        refresh_state
      end

      def status_text
        done = @boxes.count { |box| @fronts[box.persistent_id] }
        text = "#{@boxes.length} box, đã chọn mặt trước #{done}/#{@boxes.length}."
        text += ' Đang sửa cấu hình RIÊNG cho box vừa chọn (sửa thông số trong bảng).' if @override_pid
        text += ' Click vùng trống hoặc Enter để tạo thùng tủ.' if @state == :preview
        text
      end

      def onKeyDown(key, repeat, flags, view)
        if Keys.tab?(key)
          targets = @settings['sync_front'] ? @boxes : [@boxes.find { |box| box.persistent_id == @last_pid }].compact
          targets.each do |box|
            pid = box.persistent_id
            @fronts[pid] = @fronts[pid].reverse if @fronts[pid]
          end
          rebuild_preview
          view.invalidate
          true
        elsif Keys.backspace?(key)
          box = @boxes.last
          if box
            remove_box(box)
            refresh_state
            rebuild_preview
            note(@boxes.empty? ? 'Đã bỏ box cuối. Chưa còn box nào.' : status_text)
          end
          view.invalidate
          true
        else
          super
        end
      end

      def rebuild_preview
        @preview = Preview.new
        @errors = {}
        @boxes.delete_if { |box| !box.valid? }
        @boxes.each do |box|
          pid = box.persistent_id
          front = @fronts[pid]
          parent = @parents[pid]
          if front
            kind = @overrides.key?(pid) ? :override : :body
            message = Geometry.preview_cabinet(box, front, @overrides[pid] || @settings, @preview, kind, parent)
            @errors[pid] = message if message
          else
            add_hint_faces(box, parent)
          end
        end
      end

      # Box chưa có mặt trước: tô cam nhạt để người dùng biết còn phải click.
      def add_hint_faces(box, parent)
        bounds = box.definition.bounds
        world = parent * box.transformation
        faces = PanelModel.box_faces([bounds.min.x, bounds.min.y, bounds.min.z, bounds.max.x, bounds.max.y, bounds.max.z])
        faces.each do |face|
          @preview.add_polygon(face.map { |x, y, z| Geom::Point3d.new(x, y, z).transform(world) }, :front)
        end
      end

      def hud_lines
        done = @boxes.count { |box| @fronts[box.persistent_id] }
        back_names = { 'groove' => 'âm 4 cạnh', 'groove_sides' => 'âm 2 hông', 'lua_top' => 'lùa trên', 'lua_bottom' => 'lùa đáy', 'overlay' => 'phủ', 'none' => 'không hậu' }
        back_name = back_names.fetch(@settings['back_mode'], @settings['back_mode'].to_s)
        lines = [
          "Box: #{@boxes.length}   Đã có mặt trước: #{done}/#{@boxes.length}",
          "Đồng bộ mặt trước: #{@settings['sync_front'] ? 'BẬT' : 'tắt'}",
          "Cấu hình riêng: #{@overrides.length} box#{@override_pid ? ' (đang sửa)' : ''}",
          "Hậu: #{back_name}",
          "Loại: #{PanelModel::TYPE_NAMES.fetch(@settings['cabinet_type'].to_s, 'Tủ tùy biến')}"
        ]
        lines << "Lỗi: #{@errors.values.first}" unless @errors.empty?
        lines
      end

      def commit(view)
        refresh_state
        raise 'Chưa chọn box nào. Click vào box để bắt đầu.' if @boxes.empty?
        missing = @boxes.reject { |box| @fronts[box.persistent_id] }
        raise "Còn #{missing.length} box chưa chọn mặt trước." unless missing.empty?
        rebuild_preview
        raise @errors.values.first unless @errors.empty?
        roots = []
        operation('Box → Board') do
          @boxes.dup.each do |box|
            next unless box.valid?
            pid = box.persistent_id
            params = @overrides[pid] || @settings
            options = params.merge('front_normal' => @fronts[pid].to_a, 'remove_source' => params['keep_source'] != true)
            created = Geometry.cabinets_from_box(box, options)
            created.each { |root| Geometry.share_components(root) }
            roots.concat(created)
          end
        end
        model = view.model
        model.selection.clear
        roots.each { |root| model.selection.add(root) if root.valid? }
        clear_pending!
        rebuild_preview
        view.invalidate
        Dialog.set_status("Đã chuyển #{roots.length} box thành thùng tủ. Lệnh vẫn chạy: chọn box tiếp, hoặc Esc thoát." + (@commit_warning ? " (#{@commit_warning})" : ''))
      rescue StandardError => e
        Dialog.set_status(e.message)
      end
    end

    # Sửa tủ đã tạo (giống chỉnh thông số Dynamic Component): chọn một hoặc nhiều tủ rồi bấm Box → Board.
    # HUD hiện thông số của tủ (tủ đầu tiên) + Rộng/Sâu/Cao. Chỉ những thông số người dùng ĐỔI mới áp cho các tủ.
    # Kéo Scale tủ bằng SketchUp rồi mở lại công cụ: kích thước mới được đọc từ scale, Enter dựng lại đúng độ dày ván.
    class EditCabinetTool < Base
      DIM_KEYS = %w[_width _depth _height].freeze
      MB_YES_NO_CANCEL = 3
      ID_YES = 6
      ID_NO = 7

      def self.cabinets_only?(selection)
        items = selection.to_a
        groups = items.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
        groups.any? && groups.all? { |e| ModelData.cabinet?(e) || ModelData.split_group?(e) }
      end

      attr_reader :roots
      attr_accessor :manual_choice # :overwrite / :keep / :cancel — đặt sẵn thì không hỏi (dùng cho test)

      def initialize(settings = {})
        super
        @tool_name = 'box'
        @roots = []
        @originals = {}
        @dims = {}
        @dirty = {}
        @dirty_dims = {}
        @errors = {}
      end

      def hint
        'Sửa thông số trên HUD (gõ Rộng/Sâu/Cao) · Enter dựng lại tủ · Esc hủy'
      end

      def status_hint
        'Sửa thông số / Rộng-Sâu-Cao trên HUD · Enter (hoặc nút Áp dụng trong bảng): dựng lại tủ · Esc: hủy'
      end

      def activate
        reload_roots
        super
        Dialog.push_settings(@settings, false, 'box')
        Dialog.push_settings(@settings, false, 'base')
        scaled = @roots.count { |root| (Rebuild.scale_of(root) rescue nil) }
        Dialog.set_status("Đang sửa #{@roots.length} tủ#{scaled > 0 ? " (#{scaled} tủ đã kéo Scale — Enter để dựng lại đúng kích thước)" : ''}. Sửa thông số rồi Enter.")
        rebuild_preview
      end

      # Đọc lại các tủ đang chọn (thông số gốc, kích thước) và bỏ mọi thay đổi chưa áp dụng.
      def reload_roots
        @roots = ModelData.cabinets_in(Sketchup.active_model.selection)
        @originals = {}
        @dims = {}
        @errors = {}
        @dirty = {}
        @dirty_dims = {}
        @roots.each do |root|
          @originals[root] = Rebuild.settings_of(root)
          begin
            @dims[root] = Rebuild.dimensions_of(root)
          rescue ArgumentError => e
            @errors[root] = e.message
          end
        end
        @settings = Schema.deep_copy(@originals[@roots.first]) if @roots.first
      end

      def ready?
        !@roots.empty?
      end

      # Lệnh này không có thao tác click nào khác: click bất kỳ trong khung nhìn = dựng lại tủ.
      def onLButtonDown(_flags, _x, _y, view)
        commit(view) if ready?
      end

      def hud_read(key)
        index = DIM_KEYS.index(key)
        return @settings[key] unless index
        root = @roots.first
        root ? dims_for(root)[index] : nil
      end

      def hud_write(key, value)
        index = DIM_KEYS.index(key)
        if index
          @dirty_dims[index] = value.to_f
        else
          @settings[key] = value
          @dirty[key] = value
        end
      end

      def hud_after_set(key)
        return unless key == 'cabinet_type'
        preset = Schema::TYPE_PRESETS[@settings['cabinet_type'].to_s] || {}
        preset.each do |k, v|
          @settings[k] = v
          @dirty[k] = v
        end
      end

      # Chỉ các thông số của thùng tủ (bảng gửi cả các tab Cánh/Ngăn kéo... — bỏ qua những khóa đó).
      CARCASS_KEYS = %w[board_thickness back_thickness back_mode back_groove_depth back_lip panels leg_height ceiling_strip_height
                        sides_to_floor sides_to_ceiling toe_kick_enabled toe_kick_thickness toe_kick_setback toe_kick_back
                        cornice_enabled cornice_thickness cornice_setback cabinet_type top_mode top_rail_width hang_rail
                        rail_front_orient rail_back_orient rail_back_width rail_front_double hang_rail_height fridge_width fridge_height fridge_depth fridge_side_gap fridge_top_gap fridge_back_gap].freeze

      # Bảng điều khiển / chọn mẫu gửi sang: chỉ ghi nhận khóa thùng tủ có giá trị khác thông số hiện tại của tủ.
      def update_settings(settings)
        merged = Schema.merge_settings(settings)
        type_changed = merged['cabinet_type'] != @settings['cabinet_type']
        merged.each do |key, value|
          next unless CARCASS_KEYS.include?(key)
          next if value == @settings[key]
          @dirty[key] = value
          @settings[key] = value
        end
        hud_after_set('cabinet_type') if type_changed
        rebuild_preview
        Sketchup.active_model.active_view.invalidate
      end

      def dims_for(root)
        (@dims[root] || [0, 0, 0]).each_with_index.map { |v, i| @dirty_dims.key?(i) ? @dirty_dims[i] : v }
      end

      def settings_for(root)
        Schema.deep_merge(@originals[root], @dirty)
      end

      # Phép biến đổi (thế giới) của thùng tủ SAU khi dựng lại: tủ về phép biến đổi cứng, gốc dời theo scale.
      def target_transform(root, shell)
        rigid, scales = Geometry.rigid_of(root)
        tr = shell.transformation
        o = tr.origin
        rigid * Geom::Transformation.axes(Geom::Point3d.new(o.x * scales[0], o.y * scales[1], o.z * scales[2]), tr.xaxis, tr.yaxis, tr.zaxis)
      end

      def rebuild_preview
        @preview = Preview.new
        @errors.delete(:commit)
        @roots.each do |root|
          next unless root.valid?
          @errors.delete(root) if @dims[root]
          next unless @dims[root]
          shell = Geometry.shell_for(root)
          next unless shell
          begin
            w, d, h = dims_for(root)
            result = PanelModel.compute(w, d, h, settings_for(root))
            transform = target_transform(root, shell)
            (result.parts + result.trim).each do |part|
              PanelModel.box_faces(part.bounds).each do |face|
                @preview.add_polygon(face.map { |x, y, z| Geom::Point3d.new(x.mm, y.mm, z.mm).transform(transform) }, changed? ? :front : :override)
              end
            end
          rescue StandardError => e
            @errors[root] = e.message
          end
        end
      end

      # Gõ số khi chưa chọn hàng nào: nhắc cách làm thay vì im lặng.
      def onUserText(_text, _view)
        message = 'Bấm vào hàng thông số (ví dụ Rộng tủ) trên HUD trước, rồi gõ số và Enter.'
        Dialog.set_status(message)
        flash_status(message)
      end

      def changed?
        !(@dirty.empty? && @dirty_dims.empty?)
      end

      def hud_lines
        return ['Chưa chọn tủ nào.'] if @roots.empty?
        w, d, h = dims_for(@roots.first)
        lines = []
        lines << 'ĐANG XEM TRƯỚC (màu cam) — bấm Enter để dựng lại tủ' if changed?
        lines << format('Đang sửa: %d tủ', @roots.length)
        lines << format('Kích thước: %.0f × %.0f × %.0f mm', w, d, h)
        changed = @dirty.keys.length + @dirty_dims.length
        lines << (changed.zero? ? 'Chưa đổi thông số nào' : "Đã đổi #{changed} thông số")
        lines << "Lỗi: #{@errors.values.first}" unless @errors.empty?
        lines
      end

      def ask_manual(list)
        return @manual_choice if @manual_choice
        names = list.map { |item| item[:label] }.uniq
        text = "Có #{list.length} tấm đã bị chỉnh tay (kéo, khoét, cắt…):\n#{names.first(12).map { |n| "• #{n}" }.join("\n")}#{names.length > 12 ? "\n• …" : ''}\n\n" \
               "Yes: dựng lại theo thông số (mất phần chỉnh tay)\nNo: giữ nguyên các tấm này, dựng lại phần còn lại\nCancel: hủy, không sửa gì"
        answer = UI.messagebox(text, defined?(MB_YESNOCANCEL) ? MB_YESNOCANCEL : MB_YES_NO_CANCEL)
        case answer
        when (defined?(IDYES) ? IDYES : ID_YES) then :overwrite
        when (defined?(IDNO) ? IDNO : ID_NO) then :keep
        else :cancel
        end
      end

      def commit(view)
        raise 'Chưa chọn tủ nào.' if @roots.empty?
        rebuild_preview
        raise @errors.values.first unless @errors.empty?
        edited = @roots.map { |root| [root, Rebuild.hand_edited(root)] }.to_h
        all = edited.values.flatten
        keep = {}
        unless all.empty?
          choice = ask_manual(all)
          if choice == :cancel
            report('Đã hủy sửa tủ (có tấm chỉnh tay). Tủ giữ nguyên.')
            return
          end
          @roots.each { |root| keep[root] = choice == :keep ? edited[root].map { |item| item[:entity] } : [] }
        end
        warnings = []
        operation('Sửa tủ') do
          @roots.each { |root| warnings.concat(Rebuild.run(root, settings_for(root), dims_for(root), keep[root] || [])) }
        end
        model = view.model
        model.selection.clear
        @roots.each { |root| model.selection.add(root) if root.valid? }
        reload_roots
        Dialog.push_settings(@settings, false, 'box')
        Dialog.push_settings(@settings, false, 'base')
        rebuild_preview
        view.invalidate
        report("Đã dựng lại #{@roots.length} tủ. Sửa tiếp hoặc Esc để thoát.")
        UI.messagebox("Đã dựng lại tủ. Lưu ý:\n• #{warnings.uniq.join("\n• ")}") unless warnings.empty?
      rescue StandardError => e
        # Lỗi phải hiện cho người dùng thấy (bảng điều khiển có thể đang đóng): thanh trạng thái + HUD + hộp thoại.
        @errors[:commit] = e.message
        report(e.message)
        UI.messagebox("Không sửa được tủ:\n#{e.message}")
        puts "[VGD Cabinet Draw] Sửa tủ lỗi: #{e.class}: #{e.message}\n#{(e.backtrace || []).first(8).join("\n")}"
        Sketchup.active_model.active_view.invalidate
      end

      def report(text)
        Dialog.set_status(text)
        flash_status(text) if respond_to?(:flash_status)
      end
    end

    # Face (hoặc mặt phẳng) -> ván. Chọn các face trước, chạy công cụ: hộp thoại hỏi độ dày, Tab đổi phía dựng ván,
    # Enter (hoặc nút Áp dụng) tạo. Mỗi face thành một ván riêng (group), face gốc được giữ nguyên.
    class FaceBoardTool < Base
      SIDES = %w[normal reverse center].freeze
      SIDE_LABELS = { 'normal' => 'THEO PHÁP TUYẾN', 'reverse' => 'NGƯỢC PHÁP TUYẾN', 'center' => 'CHIA ĐỀU HAI PHÍA' }.freeze
      SIDE_CHOICES = 'Theo pháp tuyến|Ngược pháp tuyến|Chia đều hai phía'.freeze
      MIN_MM = 0.5
      MAX_MM = 500.0

      # Chỉ có face được chọn (không có group/component) thì coi là chuyển face thành ván.
      def self.faces_only?(selection)
        items = selection.to_a
        items.any? { |e| e.is_a?(Sketchup::Face) } && items.none? { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      end

      attr_reader :thickness_mm

      def initialize(settings = {})
        super
        @tool_name = 'box'
        @faces = []
        @thickness_mm = nil
        @settings['board_face_side'] = SIDES.first unless SIDES.include?(@settings['board_face_side'])
        @incoming_side = @settings['board_face_side']
      end

      def side
        @settings['board_face_side']
      end

      def hint
        'Tab đổi phía dựng ván · gõ số + Enter đổi độ dày · Enter hoặc nút Áp dụng: tạo ván · Esc hủy'
      end

      def status_hint
        'Tab: đổi phía dựng · gõ số + Enter: độ dày · Enter: tạo ván · Esc: hủy'
      end

      def hud_read(key)
        key == '_thickness' ? @thickness_mm : @settings[key]
      end

      def hud_write(key, value)
        if key == '_thickness'
          @thickness_mm = value
        else
          @settings[key] = value
          @incoming_side = value if key == 'board_face_side'
        end
      end

      def activate
        super
        @faces = Sketchup.active_model.selection.to_a.select { |e| e.is_a?(Sketchup::Face) && e.valid? }
        if @faces.empty?
          Dialog.set_status('Chưa chọn face nào. Hãy chọn các face rồi chạy lại Box → Board.')
          return
        end
        default = @settings['board_face_thickness'] || @settings['board_thickness']
        answer = ask_thickness(default)
        if answer.nil?
          Dialog.set_status('Đã hủy chuyển face thành ván.')
          # Thoát công cụ sau khi activate kết thúc, tránh đổi công cụ ngay trong activate.
          UI.start_timer(0, false) { Sketchup.active_model.select_tool(nil) }
          return
        end
        @thickness_mm = answer[0]
        @settings['board_face_side'] = answer[1]
        @incoming_side = answer[1]
        rebuild_preview
        Dialog.set_status("#{@faces.length} face · dày #{@thickness_mm} mm · #{SIDE_LABELS[side]}. Tab đổi phía, Enter tạo ván.")
      end

      # Hộp thoại nhập độ dày và phía dựng. Trả về [dày mm, phía] hoặc nil nếu hủy/không hợp lệ.
      def ask_thickness(default)
        labels = ['Độ dày ván (mm)', 'Phía dựng ván']
        defaults = [default.to_f, SIDE_CHOICES.split('|')[SIDES.index(side)]]
        result = UI.inputbox(labels, defaults, ['', SIDE_CHOICES], "Face → Ván (#{@faces.length} face)")
        return nil unless result
        value = Float(result[0].to_s.tr(',', '.')) rescue nil
        unless value && value >= MIN_MM && value <= MAX_MM
          Dialog.set_status("Độ dày phải là số từ #{MIN_MM} đến #{MAX_MM.to_i} mm.")
          return nil
        end
        index = SIDE_CHOICES.split('|').index(result[1].to_s)
        [value, SIDES[index || 0]]
      end

      def update_settings(settings)
        keep = @settings['board_face_side']
        @settings = Schema.merge_settings(settings)
        if @settings['board_face_side'] == @incoming_side
          @settings['board_face_side'] = keep
        else
          @incoming_side = @settings['board_face_side']
        end
        @settings['board_face_side'] = SIDES.first unless SIDES.include?(@settings['board_face_side'])
        rebuild_preview
        Sketchup.active_model.active_view.invalidate
      end

      def onKeyDown(key, repeat, flags, view)
        if Keys.tab?(key)
          @settings['board_face_side'] = SIDES[(SIDES.index(side).to_i + 1) % SIDES.length]
          Dialog.set_status("Phía dựng ván: #{SIDE_LABELS[side]}.")
          rebuild_preview
          view.invalidate
          true
        else
          super
        end
      end

      def ready?
        !@thickness_mm.nil? && !@faces.empty?
      end

      def pending?
        !@faces.empty?
      end

      def clear_pending!
        @faces = []
      end

      # Click vào face: thêm/bỏ face khỏi danh sách. Click vùng trống khi đã có face và độ dày: tạo ván.
      def onLButtonDown(flags, x, y, view)
        return if click_finish?(view, x, y)
        face = picked_path(view, x, y).reverse.find { |entity| entity.is_a?(Sketchup::Face) && entity.valid? }
        return unless face
        if @faces.include?(face)
          @faces.delete(face)
        else
          @faces << face
        end
        @thickness_mm ||= (@settings['board_face_thickness'] || @settings['board_thickness']).to_f
        rebuild_preview
        Dialog.set_status("#{@faces.length} face đã chọn · dày #{@thickness_mm} mm. Click vùng trống hoặc Enter để tạo ván.")
        view.invalidate
      end

      def onUserText(text, view)
        value = Float(text.to_s.strip.tr(',', '.')) rescue nil
        raise "Nhập độ dày bằng số, từ #{MIN_MM} đến #{MAX_MM.to_i} mm." unless value && value >= MIN_MM && value <= MAX_MM
        @thickness_mm = value
        rebuild_preview
        view.invalidate
        Dialog.set_status("Độ dày: #{value} mm.")
      rescue StandardError => e
        Dialog.set_status(e.message)
      end

      # Khoảng đẩy theo pháp tuyến [thấp, cao] (inch) tùy phía dựng.
      def offsets
        t = @thickness_mm.to_f.mm
        case side
        when 'reverse' then [-t, 0.0]
        when 'center' then [-t / 2, t / 2]
        else [0.0, t]
        end
      end

      def rebuild_preview
        @preview = Preview.new
        return unless @thickness_mm
        world = Sketchup.active_model.edit_transform
        low, high = offsets
        @faces.each do |face|
          next unless face.valid?
          normal = face.normal.transform(world)
          normal.normalize!
          ring = face.outer_loop.vertices.map { |v| v.position.transform(world) }
          move = lambda { |point, d| Geom::Point3d.new(point.x + normal.x * d, point.y + normal.y * d, point.z + normal.z * d) }
          @preview.add_prism(ring.map { |p| move.call(p, low) }, ring.map { |p| move.call(p, high) }, :body)
        end
      end

      def hud_lines
        return ['Chưa chọn face nào.'] if @faces.empty?
        ["Face → ván: #{@faces.length} face", "Dày: #{@thickness_mm || '?'} mm   Phía: #{SIDE_LABELS[side]} (Tab đổi)", 'Face gốc được giữ nguyên.']
      end

      def commit(view)
        raise 'Chưa chọn face nào.' if @faces.empty?
        raise 'Chưa có độ dày. Hãy chạy lại công cụ và nhập độ dày.' unless @thickness_mm
        faces = @faces.select(&:valid?)
        raise 'Các face đã chọn không còn tồn tại.' if faces.empty?
        low, high = offsets
        boards = []
        operation('Face → Ván') do
          faces.each_with_index { |face, index| boards << build_board(face, index, low, high) }
        end
        model = view.model
        model.selection.clear
        boards.each { |board| model.selection.add(board) if board.valid? }
        clear_pending!
        rebuild_preview
        view.invalidate
        Dialog.set_status("Đã tạo #{boards.length} ván dày #{@thickness_mm} mm từ face. Click face tiếp, hoặc Esc thoát." + (@commit_warning ? " (#{@commit_warning})" : ''))
      rescue StandardError => e
        Dialog.set_status(e.message)
      end

      # Dựng một ván từ một face: vòng ngoài là biên, các vòng trong là lỗ. Ván nằm cùng cấp với face.
      def build_board(face, index, low, high)
        normal = face.normal
        normal.normalize!
        shift = lambda do |loop_vertices, d|
          loop_vertices.map { |v| p = v.position; Geom::Point3d.new(p.x + normal.x * d, p.y + normal.y * d, p.z + normal.z * d) }
        end
        group = face.parent.entities.add_group
        group.name = "Ván #{index + 1}"
        base = group.entities.add_face(shift.call(face.outer_loop.vertices, low))
        raise 'Không dựng được ván từ face này (face không hợp lệ).' unless base
        face.loops.each do |loop|
          next if loop.outer?
          hole = group.entities.add_face(shift.call(loop.vertices, low))
          hole.erase! if hole
        end
        base.reverse! if base.normal.dot(normal) < 0
        base.pushpull(high - low)
        Geometry.stamp_part(group, 'board', { 'thickness_mm' => @thickness_mm, 'source' => 'face', 'side' => side })
        group
      end
    end

    # Đợt / vách (beta.28).
    #   Luồng chính: rê vào hông / nóc / đáy / tấm đã có → tô sáng mặt → click KHÓA mặt → kéo ra xem trước
    #   → Tab đổi điểm bắt (trong / giữa / ngoài) → gõ mm hoặc kéo → click/Enter TẠO tấm. Lệnh vẫn chạy để tạo tiếp.
    #   Lối tắt: /n khi chưa khóa mặt = chia cả ô đang trỏ (theo hông/nóc/đáy); khi đã khóa mặt = chia khoảng từ mặt tới mép ô.
    #   Tab khi chưa khóa: lọt trong ô ↔ xuyên qua tấm. Tab khi /n: thông thủy / lọt / phủ.
    #   Esc: bỏ mặt hoặc chia đang chờ (lần 2 thoát). Backspace: hoàn tác tấm vừa tạo.
    class PanelTool < Base
      KINDS = %w[thong_thuy lot_long phu_bi].freeze
      KIND_LABELS = { 'thong_thuy' => 'THÔNG THỦY', 'lot_long' => 'LỌT LÒNG', 'phu_bi' => 'PHỦ BÌ' }.freeze
      SPANS = %w[cell full].freeze
      SPAN_LABELS = { 'cell' => 'Lọt trong ô', 'full' => 'Xuyên qua tấm' }.freeze
      POINT_LABELS = %w[Trong Giữa Ngoài].freeze
      ROLE_LABELS = { 'side_left' => 'hông trái', 'side_right' => 'hông phải', 'top' => 'nóc', 'bottom' => 'đáy',
                      'partition' => 'vách', 'shelf' => 'đợt' }.freeze
      EPS = 1e-6

      def initialize(settings = {})
        super
        @tool_name = 'panel'
        @root = nil
        @shell = nil
        @hover_root = nil
        @hover = nil        # mặt tham chiếu đang rê chuột
        @ref = nil          # mặt đã khóa (sau click)
        @point = 0          # 0 trong, 1 giữa, 2 ngoài
        @distance = nil     # khoảng cách gõ tay (mm)
        @divide_count = nil # /n đang chờ
        @divide_ref = nil   # mặt đóng băng cho /n
        @cursor = nil
        @created = []       # bước đã tạo trong lệnh này (để Backspace hoàn tác)
        @error = nil
        @settings['panel_kind'] = KINDS.first unless KINDS.include?(@settings['panel_kind'])
        @settings['panel_span'] = 'cell' unless SPANS.include?(@settings['panel_span'])
        # Giá trị lần cuối bảng điều khiển gửi sang: chỉ khi giá trị trong bảng đổi thì mới ghi đè lựa chọn bằng chuột/Tab.
        @incoming = { 'panel_axis' => @settings['panel_axis'], 'panel_kind' => @settings['panel_kind'], 'panel_span' => @settings['panel_span'] }
      end

      def kind
        @settings['panel_kind']
      end

      def span
        @settings['panel_span']
      end

      def vertical?
        @settings['panel_axis'] == 'vertical'
      end

      def thickness
        @settings['board_thickness'].to_f.mm
      end

      def status_hint
        return 'Rê chuột vào tủ rồi click chọn tủ · Esc: thoát' unless @root
        return 'Tab đổi thông thủy / lọt / phủ · click hoặc Enter tạo · Esc: bỏ' if @divide_count
        return 'Kéo ra xem trước · Tab đổi điểm bắt · gõ mm · click hoặc Enter tạo tấm · Esc: bỏ mặt' if @ref
        'Rê vào hông / nóc / đáy / tấm đã có · click chọn mặt · Tab: lọt ô ↔ xuyên · /n chia cả ô · Alt-click: xóa tấm · Shift-click: đánh dấu xóa · Backspace: hoàn tác · Esc: thoát'
      end

      def hint
        status_hint
      end

      # Đang khóa mặt hoặc đang chờ /n thì hướng (dự phòng khi chưa trỏ) bị khóa.
      def axis_locked?
        !@divide_count.nil? || !@ref.nil?
      end

      def hud_guard(key, _value)
        return nil unless key == 'panel_axis' && axis_locked?
        'Đang khóa mặt hoặc chờ /n nên hướng bị khóa. Bấm Esc bỏ trước rồi mới đổi.'
      end

      # Hướng theo bộ phận đang trỏ (hông → vách đứng, nóc/đáy → đợt ngang). nil nếu trỏ chỗ khác.
      def panel_axis_at(view, x, y)
        path = picked_path(view, x, y)
        return nil unless @root && path.include?(@root)
        part = path.reverse.find { |entity| Interior.role_of(entity) }
        case part && Interior.role_of(part)
        when 'side_left', 'side_right' then 'vertical'
        when 'top', 'bottom' then 'horizontal'
        end
      end

      def activate
        super
        cabinet = ModelData.cabinets_in(Sketchup.active_model.selection).first
        use_cabinet(cabinet) if cabinet
        rebuild_preview
      end

      def use_cabinet(root)
        return false unless root && root.valid?
        @root = root
        @shell = Geometry.shell_for(@root)
        clear_state!
        Sketchup.active_model.selection.clear # bỏ tô vàng tủ: lệnh làm việc trực tiếp trên tủ
        Dialog.set_status('Đã chọn tủ. Rê chuột vào hông, nóc, đáy hoặc tấm đã có để chọn mặt.')
        true
      end

      def clear_state!
        @ref = nil
        @distance = nil
        @divide_count = nil
        @divide_ref = nil
        @point = 0
      end

      def update_settings(settings)
        keep = { 'panel_axis' => @settings['panel_axis'], 'panel_kind' => kind, 'panel_span' => span }
        @settings = Schema.merge_settings(settings)
        keep.each_key do |key|
          if @settings[key] == @incoming[key]
            @settings[key] = keep[key]
          else
            @incoming[key] = @settings[key]
          end
        end
        @settings['panel_kind'] = KINDS.first unless KINDS.include?(@settings['panel_kind'])
        @settings['panel_span'] = 'cell' unless SPANS.include?(@settings['panel_span'])
        rebuild_preview
        Sketchup.active_model.active_view.invalidate
      end

      def to_world_transform
        Operations.world_transform(@root, @shell)
      end

      def local_point(world)
        world.transform(to_world_transform.inverse)
      end

      # Hông/nóc/đáy/tấm đã có: { axis, plane, dir, cell, role, limit }. plane = mặt tham chiếu, dir = hướng vào trong ô.
      def make_ref(axis, plane, dir, cell, role, limit = true)
        { axis: axis, plane: plane, dir: dir, cell: cell, role: role, limit: limit }
      end

      def hover_reference(view, x, y)
        return nil unless @shell && @shell.valid? && @cursor
        path = picked_path(view, x, y)
        return nil unless path.include?(@root)
        part = path.reverse.find { |entity| Interior.role_of(entity) }
        role = part && Interior.role_of(part)
        return nil unless role
        point = local_point(@cursor)
        case role
        when 'partition', 'shelf' then panel_ref(part, role, point)
        else
          cell = Interior.cell_at(@shell, point.x, point.z)
          case role
          when 'side_left' then make_ref('vertical', cell.x0, 1, cell, role)
          when 'side_right' then make_ref('vertical', cell.x1, -1, cell, role)
          when 'bottom' then make_ref('horizontal', cell.z0, 1, cell, role)
          when 'top' then make_ref('horizontal', cell.z1, -1, cell, role)
          end
        end
      end

      # Mặt của vách/đợt đã có: nửa trái/trước/dưới của tấm → mặt bên đó; ô tính ở phía mặt đó.
      def panel_ref(part, role, point)
        b = Interior.box_of(part)
        if role == 'partition'
          if point.x < (b[0] + b[3]) / 2.0
            make_ref('vertical', b[0], -1, Interior.cell_at(@shell, b[0] - 1.mm, point.z), role)
          else
            make_ref('vertical', b[3], 1, Interior.cell_at(@shell, b[3] + 1.mm, point.z), role)
          end
        elsif point.z < (b[2] + b[5]) / 2.0
          make_ref('horizontal', b[2], -1, Interior.cell_at(@shell, point.x, b[2] - 1.mm), role)
        else
          make_ref('horizontal', b[5], 1, Interior.cell_at(@shell, point.x, b[5] + 1.mm), role)
        end
      end

      # Mặt mặc định khi không trỏ vào tấm nào: hông trái (vách) hoặc đáy (đợt) theo "Hướng", ô đang trỏ nếu có Giới hạn.
      def default_ref
        limited = @settings['panel_limit'] != false && !@cursor.nil?
        cell = if limited
                 point = local_point(@cursor)
                 Interior.cell_at(@shell, point.x, point.z)
               else
                 Interior.inner(@shell)
               end
        if vertical?
          make_ref('vertical', cell.x0, 1, cell, nil, limited)
        else
          make_ref('horizontal', cell.z0, 1, cell, nil, limited)
        end
      end

      def onMouseMove(flags, x, y, view)
        super
        @cursor = Geom::Point3d.new(@ip.position) if @ip.valid?
        if @root.nil?
          @hover_root = picked_cabinet(view, x, y)
        elsif !axis_locked?
          @hover = hover_reference(view, x, y)
        end
        rebuild_preview
        view.invalidate
      end

      # Đợt/vách trong công cụ: Alt-click xóa ngay tấm dưới con trỏ; Shift-click đánh dấu để xóa cùng lúc (thanh nút chuột phải).
      def picked_member(view, x, y)
        picked_path(view, x, y).reverse.find { |entity| Rebuild::MEMBER_ROLES.include?(Interior.role_of(entity)) }
      end

      def mark_or_remove_member(member, flags, view)
        if Keys.alt?(flags)
          @marked = []
          safely do
            operation('Xóa tấm') { Removal.remove_members(@root, [member]) }
            refresh_after_removal
          end
        else
          @marked ||= []
          @marked.include?(member) ? @marked.delete(member) : @marked << member
          Dialog.set_status("Đã đánh dấu #{@marked.length} tấm. Chuột phải → Xóa các tấm đã đánh dấu · Alt-click xóa ngay.")
        end
        view.invalidate
      end

      def remove_marked
        members = (@marked || []).select(&:valid?)
        return Dialog.set_status('Chưa đánh dấu tấm nào. Shift-click tấm cần xóa.') if members.empty?
        safely do
          operation('Xóa các tấm đã đánh dấu') { Removal.remove_members(@root, members) }
          refresh_after_removal
        end
        @marked = []
      end

      def clear_marked
        @marked = []
        Dialog.set_status('Đã bỏ đánh dấu tấm.')
        Sketchup.active_model.active_view.invalidate
      end

      def refresh_after_removal
        @shell = Geometry.shell_for(@root)
        rebuild_preview
        Sketchup.active_model.active_view.invalidate
      end

      def draw(view)
        super if defined?(super)
        (@marked || []).select(&:valid?).each { |member| draw_marked_box(view, member) }
      end

      def draw_marked_box(view, entity)
        b = entity.bounds
        corners = [[b.min.x, b.min.y, b.min.z], [b.max.x, b.min.y, b.min.z], [b.max.x, b.max.y, b.min.z], [b.min.x, b.max.y, b.min.z],
                   [b.min.x, b.min.y, b.max.z], [b.max.x, b.min.y, b.max.z], [b.max.x, b.max.y, b.max.z], [b.min.x, b.max.y, b.max.z]]
        world = Operations.world_transform(@root, Geometry.shell_for(@root))
        pts = corners.map { |c| Geom::Point3d.new(*c).transform(world) }
        edges = [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]]
        view.line_width = 3 if view.respond_to?(:line_width=)
        view.drawing_color = 'red' if view.respond_to?(:drawing_color=)
        view.draw_lines(edges.flat_map { |a, c| [pts[a], pts[c]] })
      end

      def onLButtonDown(flags, x, y, view)
        if @root && (Keys.alt?(flags) || Keys.shift?(flags))
          member = picked_member(view, x, y)
          return mark_or_remove_member(member, flags, view) if member
        end
        if @root.nil?
          use_cabinet(picked_cabinet(view, x, y))
        elsif @divide_count || @ref
          safely { create_now }
        elsif @hover
          @ref = @hover
          Dialog.set_status("Đã khóa mặt #{ROLE_LABELS[@ref[:role]] || 'chia'}. Kéo ra xem trước, click lần nữa để tạo tấm.")
        end
        rebuild_preview
        view.invalidate
      end

      # Khoảng cách từ mặt tham chiếu tới điểm bắt của tấm: gõ tay hoặc theo vị trí chuột.
      def distance_for(ref)
        return @distance.mm if @distance
        return 0.0 unless @cursor
        local = local_point(@cursor)
        coord = ref[:axis] == 'vertical' ? local.x : local.z
        [(coord - ref[:plane]) * ref[:dir], 0.0].max
      end

      # Vị trí mép dưới (theo trục) của một tấm, theo điểm bắt Trong / Giữa / Ngoài.
      def single_position(ref)
        t = thickness
        dir = ref[:dir]
        p = ref[:plane] + dir * distance_for(ref)
        lo = case @point
             when 0 then dir > 0 ? p : p - t
             when 1 then p - t / 2.0
             else dir > 0 ? p - t : p
             end
        check_inside!(ref, [lo])
        lo
      end

      def axial_range(ref)
        c = ref[:cell]
        ref[:axis] == 'vertical' ? [c.x0, c.x1] : [c.z0, c.z1]
      end

      def far_boundary(ref)
        c = ref[:cell]
        if ref[:axis] == 'vertical'
          ref[:dir] > 0 ? c.x1 : c.x0
        else
          ref[:dir] > 0 ? c.z1 : c.z0
        end
      end

      def check_inside!(ref, positions)
        lo_c, hi_c = axial_range(ref)
        t = thickness
        return if positions.all? { |p| p >= lo_c - EPS && p + t <= hi_c + EPS }
        raise 'Tấm nằm ngoài ô. Hãy kéo ngắn lại hoặc đổi điểm bắt bằng Tab.'
      end

      # Chia đều khoảng từ mặt tham chiếu tới mép đối diện của ô thành count ô. Trả mép dưới của từng tấm (inch).
      def divide_positions_in(ref, count)
        raise 'Chia ít nhất 2 ô (ví dụ /2).' if count < 2
        t = thickness
        vertical = ref[:axis] == 'vertical'
        lo_a, hi_a = [ref[:plane], far_boundary(ref)].minmax
        base_lo = lo_a
        base_len = hi_a - lo_a
        gap = (base_len - t * (count - 1)) / count
        if kind == 'phu_bi'
          c = ref[:cell]
          lo_side, hi_side = vertical ? [c.left, c.right] : [c.bottom, c.top]
          lo_c, hi_c = vertical ? [c.x0, c.x1] : [c.z0, c.z1]
          reach = ->(side) { side.kind == :inner ? side.t / 2.0 : side.t }
          base_lo = lo_a - (lo_a <= lo_c + EPS ? reach.call(lo_side) : 0.0)
          hi_ext = hi_a + (hi_a >= hi_c - EPS ? reach.call(hi_side) : 0.0)
          base_len = hi_ext - base_lo
        end
        bay = kind == 'thong_thuy' ? gap : base_len / count - t
        if bay.to_mm < PanelModel::MIN_OPENING
          raise format('Chia %d ô thì có ô chỉ còn %.0f mm (tối thiểu %d mm). Hãy chia ít hơn.', count, bay.to_mm, PanelModel::MIN_OPENING.to_i)
        end
        raw = if kind == 'thong_thuy'
                (1...count).map { |k| lo_a + gap * k + t * (k - 1) }
              else
                (1...count).map { |k| base_lo + base_len * k / count - t / 2.0 }
              end
        check_inside!(ref, raw)
        raw
      end

      def planned_positions
        return divide_positions_in(@divide_ref, @divide_count) if @divide_count
        [single_position(@ref)]
      end

      def planned_ref
        @divide_count ? @divide_ref : @ref
      end

      # Mặt tham chiếu tô sáng: nếu lọt ô thì theo ô, xuyên thì theo cả lòng tủ.
      def reference_face(ref)
        e = span == 'full' ? Interior.inner(@shell) : ref[:cell]
        p = ref[:plane]
        if ref[:axis] == 'vertical'
          # Khung theo đúng vùng vách sẽ dựng (có thể cao tới mép xà khi tủ không có nóc).
          z0, z1 = Rebuild.partition_z_range(@shell, e)
          [[p, e.y0, z0], [p, e.y1, z0], [p, e.y1, z1], [p, e.y0, z1]]
        else
          [[e.x0, e.y0, p], [e.x1, e.y0, p], [e.x1, e.y1, p], [e.x0, e.y1, p]]
        end
      end

      # Các mặt xem trước của một tấm (đợt: hộp; vách: biên dạng có khấu xà).
      def board_faces_for(pos, ref)
        span_cell = span == 'full' ? Interior.inner(@shell) : ref[:cell]
        # Cùng hàm dựng với lúc tạo tấm (Rebuild.place_panels), nên xem trước đúng hình sẽ tạo.
        if ref[:axis] == 'vertical'
          profile = Rebuild.vertical_profile(@shell, span_cell, partition_setback, [pos, pos + thickness])
          Rebuild.prism_faces(profile, pos, pos + thickness, ->(y, z, x) { [x, y, z] })
        else
          outline = Rebuild.shelf_outline(@shell, span_cell, pos, thickness, shelf_setback)
          Rebuild.prism_faces(outline, pos, pos + thickness, ->(x, y, z) { [x, y, z] })
        end
      end

      def add_face(points, transform, kind)
        @preview.add_polygon(points.map { |x, y, z| Geom::Point3d.new(x, y, z).transform(transform) }, kind)
      end

      def add_board(faces, transform, kind)
        faces.each do |face|
          @preview.add_polygon(face.map { |x, y, z| Geom::Point3d.new(x, y, z).transform(transform) }, kind)
        end
      end

      # Độ lùi mặt trước của đợt: lùi chuẩn + dày cánh khi cánh lọt (để cánh đóng không chạm đợt).
      def door_fit_for_shelf
        choice = @settings['panel_door_fit'].to_s
        return choice if %w[phu lot].include?(choice)
        fit = @root && Interior.door_fit(@root)
        fit == 'thong_thuy' ? 'lot' : (fit || 'phu')
      end

      # Vách chỉ lùi khi cánh lọt, đúng bằng dày cánh (không dùng số lùi của đợt).
      def partition_setback
        return 0.0 unless door_fit_for_shelf == 'lot'
        ((@root && Interior.door_thickness_mm(@root)) || @settings['board_thickness'].to_f).to_f.mm
      end

      def shelf_setback
        base = @settings['shelf_front_setback'].to_f.mm
        return base unless door_fit_for_shelf == 'lot'
        door_t = (@root && Interior.door_thickness_mm(@root)) || @settings['board_thickness'].to_f
        base + door_t.to_f.mm
      end

      def rebuild_preview
        @preview = Preview.new
        root = @root || @hover_root
        return unless root && root.valid?
        shell = @shell || Geometry.shell_for(root)
        return unless shell && shell.valid?
        transform = Operations.world_transform(root, shell)
        # Không tô phủ cả mặt trước tủ (che bên trong khi chia); chỉ tô mặt tham chiếu đang trỏ / đã khóa.
        return unless @root
        @error = nil
        highlight = @divide_count ? nil : (@ref || @hover)
        add_face(reference_face(highlight), transform, :front) if highlight
        return unless @divide_count || @ref
        begin
          ref = planned_ref
          positions = planned_positions
          positions.each { |pos| add_board(board_faces_for(pos, ref), transform, :front) }
          add_compartment_labels(ref, positions, transform)
        rescue StandardError => e
          @error = e.message
        end
      end

      # Khung "rộng x cao" cho từng khoang trong ô của mặt tham chiếu (theo các tấm sắp tạo).
      def add_compartment_labels(ref, positions, transform)
        lo, hi = axial_range(ref)
        t = thickness
        e = span == 'full' ? Interior.inner(@shell) : ref[:cell]
        edges = [lo] + positions.sort.flat_map { |p| [p, p + t] } + [hi]
        xaxis = Geom::Vector3d.new(1, 0, 0).transform(transform)
        zaxis = Geom::Vector3d.new(0, 0, 1).transform(transform)
        y = e.y0 - 1.mm
        edges.each_slice(2) do |from, to|
          next if to - from < 1.mm
          if ref[:axis] == 'vertical'
            w = to - from
            h = e.z1 - e.z0
            center = Geom::Point3d.new((from + to) / 2.0, y, (e.z0 + e.z1) / 2.0).transform(transform)
          else
            w = e.x1 - e.x0
            h = to - from
            center = Geom::Point3d.new((e.x0 + e.x1) / 2.0, y, (from + to) / 2.0).transform(transform)
          end
          text = "#{format('%g', w.to_mm.round(1))} x #{format('%g', h.to_mm.round(1))}"
          @preview.add_text_box(center, text, xaxis, zaxis, pixels: 14, max_height: [w, h].min * 0.45)
        end
      end

      def hud_lines
        return ['Chưa chọn tủ.', 'Rê chuột vào tủ rồi click.'] unless @root
        lines = ["Phạm vi: #{SPAN_LABELS[span]} (Tab đổi)", "Kiểu chia: #{KIND_LABELS[kind]} (Tab khi đang /n)"]
        if @divide_count
          lines << "Chia đều /#{@divide_count} ô · mặt #{ROLE_LABELS[@divide_ref[:role]] || 'cả ô'}"
        elsif @ref
          lines << "Mặt: #{ROLE_LABELS[@ref[:role]] || 'cả ô'} · Điểm bắt: #{POINT_LABELS[@point]} (Tab đổi)"
          lines << format('Khoảng cách: %.1f mm%s', distance_for(@ref).to_mm, @distance ? ' (gõ tay)' : '')
        elsif @hover
          lines << "Rê vào: #{ROLE_LABELS[@hover[:role]] || 'cả ô'} · click để khóa mặt"
        else
          lines << 'Rê vào hông, nóc, đáy hoặc tấm đã có.'
        end
        lines << "Lỗi: #{@error}" if @error
        lines << "Đã tạo trong lệnh này: #{@created.length} bước (Backspace hoàn tác)"
        lines
      end

      def safely
        yield
      rescue StandardError => e
        Dialog.set_status(e.message)
      end

      # Tạo tấm/nhóm tấm theo mặt tham chiếu: một bước ghi vào lịch sử dựng tủ (để Sửa tủ dựng lại được).
      # Mặt tham chiếu trùm cả ô (từ mặt này tới mặt kia của ô): chia đều lại được khi Sửa tủ.
      def full_cell?(ref)
        lo_a, hi_a = [ref[:plane], far_boundary(ref)].minmax
        lo_c, hi_c = axial_range(ref)
        (lo_a - lo_c).abs < EPS && (hi_a - hi_c).abs < EPS
      end

      def create_panels!(ref, positions, divide_count = nil)
        cell = ref[:cell]
        low = ref[:axis] == 'vertical' ? cell.x0 : cell.z0
        op = { 'type' => 'panel', 'axis' => ref[:axis], 'kind' => kind, 'thickness_mm' => thickness.to_mm,
               'limit' => ref[:limit] != false,
               'anchor' => Rebuild.anchor_of(@shell, (cell.x0 + cell.x1) / 2.0, (cell.z0 + cell.z1) / 2.0),
               'setback_mm' => @settings['shelf_front_setback'].to_f, 'door_fit' => @settings['panel_door_fit'].to_s,
               'span' => span, 'mode' => 'free', 'offsets' => positions.map { |pos| (pos - low).to_mm } }
        op = op.reject { |key, _| key == 'offsets' }.merge('mode' => 'divide', 'count' => divide_count) if divide_count && full_cell?(ref)
        operation('Tạo đợt / vách') do
          @root.make_unique if @root.respond_to?(:make_unique)
          @shell = Geometry.shell_for(@root)
          @shell.make_unique if @shell.respond_to?(:make_unique)
          op['op'] = Rebuild.record(@root, op)
          Rebuild.place_panels(@root, @shell, op)
          @created << op['op']
        end
        positions.length
      end

      # Click/Enter khi đã khóa mặt hoặc đang chờ /n: tạo tấm rồi về trạng thái chọn mặt (lệnh vẫn chạy).
      def create_now
        ref = planned_ref
        positions = planned_positions
        count = create_panels!(ref, positions, @divide_count)
        word = ref[:axis] == 'vertical' ? 'vách' : 'đợt'
        Dialog.set_status(@divide_count ? "Đã chia #{count} #{word} (/#{@divide_count} ô)." : "Đã tạo 1 #{word}. Chọn mặt tiếp theo hoặc Esc thoát.")
        clear_state!
      end

      # Backspace: hoàn tác bước vừa tạo của lệnh này (chỉ khi nó là bước cuối cùng của tủ).
      def undo_last
        ops = Rebuild.ops(@root)
        last = ops.last
        unless last && @created.include?(last['op'])
          Dialog.set_status('Không có tấm nào của lệnh này để hoàn tác.')
          return
        end
        operation('Hoàn tác đợt / vách') do
          @root.make_unique if @root.respond_to?(:make_unique)
          shell = Geometry.shell_for(@root)
          # Xóa chính các tấm của bước này trước: nếu còn sót thì Rebuild coi chúng là bản cũ và giữ lại.
          Interior.containers(shell).each do |entity|
            role = Interior.role_of(entity)
            next unless Rebuild::MEMBER_ROLES.include?(role) && ModelData.params(entity)['op'] == last['op']
            entity.erase!
          end
          Rebuild.save_ops(@root, ops[0...-1])
          keep = Rebuild.hand_edited(@root).map { |item| item[:entity] }
          Rebuild.run(@root, Rebuild.settings_of(@root), Rebuild.dimensions_of(@root), keep)
        end
        @created.delete(last['op'])
        @shell = Geometry.shell_for(@root)
        Dialog.set_status('Đã hoàn tác tấm vừa tạo.')
      end

      def onUserText(text, _view)
        raise 'Hãy chọn tủ trước.' unless @root && @shell
        raw = text.to_s.strip
        match = raw.match(%r{\A/(\d+)\z})
        if match
          count = [[match[1].to_i, 1].max, 20].min
          ref = @ref || @hover || default_ref
          divide_positions_in(ref, count) # kiểm tra trước: lỗi thì không đổi gì
          @divide_ref = ref
          @divide_count = count
          @ref = nil
        else
          distance = Float(raw.downcase.sub(/\s*mm\z/, '').tr(',', '.')) rescue nil
          raise 'Gõ /2, /3… để chia đều, hoặc gõ số mm để đặt tấm cách mặt tham chiếu.' unless distance
          @ref ||= @hover || default_ref
          @distance = distance
          @divide_count = nil
          @divide_ref = nil
        end
        rebuild_preview
        Sketchup.active_model.active_view.invalidate
      rescue StandardError => e
        Dialog.set_status(e.message)
      end

      def commit(view)
        if @divide_count || @ref
          safely { create_now }
        else
          Dialog.set_status('Click chọn mặt trước, hoặc gõ /n để chia cả ô.')
        end
        rebuild_preview
        view.invalidate
      end

      def pending?
        !(@ref.nil? && @divide_count.nil?)
      end

      def clear_pending!
        clear_state!
      end

      def ready?
        pending?
      end

      def handle_tab(view)
        if @divide_count
          @settings['panel_kind'] = KINDS[(KINDS.index(kind).to_i + 1) % KINDS.length]
          Dialog.set_status("Kiểu chia: #{KIND_LABELS[kind]}.")
        elsif @ref
          @point = (@point + 1) % POINT_LABELS.length
          Dialog.set_status("Điểm bắt: #{POINT_LABELS[@point]}.")
        else
          @settings['panel_span'] = span == 'cell' ? 'full' : 'cell'
          Dialog.set_status("Phạm vi: #{SPAN_LABELS[span]}.")
        end
        rebuild_preview
        view.invalidate
      end

      def onKeyDown(key, repeat, flags, view)
        if Keys.tab?(key)
          handle_tab(view)
          true
        elsif Keys.backspace?(key)
          if @ref || @divide_count
            clear_state!
            Dialog.set_status('Đã bỏ mặt đang chờ.')
          else
            undo_last
          end
          rebuild_preview
          view.invalidate
          true
        else
          super
        end
      end
    end

    # Chia cánh theo VÙNG (DoorLayout): mặt tủ là các hình chữ nhật ghép kín; click trong một vùng để chia vùng đó
    # (dọc hoặc ngang tùy Tab), Shift-click chọn vùng rồi G (hoặc gõ g) để gộp. Chỉ khi Enter mới dựng cánh thật.
    class DoorTool < Base
      SAVED_KEYS = %w[door_gap door_fit door_cover_left door_cover_right door_edge_gap door_inset_gap board_thickness show_dims door_style frame_joint frame_width rail_width panel_recess glass_rows glass_columns glass_bar_width glass_thickness].freeze

      def initialize(settings = {})
        super
        @tool_name = 'door'
        @root = nil
        @shell = nil
        @layout = DoorLayout::Layout.new
        @selected = []       # id các vùng đang chọn (Shift-click)
        @hover_root = nil
        @hover_region = nil  # id vùng đang trỏ vào
        @hover_split = nil   # vị trí chia gợi ý (0..1 trên toàn mặt tủ), nil nếu không hợp lệ
        @hover_uv = nil
        @hover_shift = false
        @error = nil
      end

      attr_reader :layout, :selected

      def hint
        if @root
          'Click: chia vùng · Shift-click: chọn vùng · Alt+G (hoặc G): gộp · /n chia đều · gõ mm: chia theo khoảng · Ctrl: dọc/ngang · Tab: cánh lọt/phủ · Backspace: hoàn tác · Enter: tạo · Alt+G gộp · xóa cánh: chuột phải'
        else
          'Rê chuột vào tủ (vàng) rồi click để chọn · hoặc chọn tủ trước khi mở công cụ'
        end
      end

      def status_hint
        return 'Click chọn tủ cần chia cánh · Esc: thoát' unless @root
        'Click: chia vùng · Shift+Click: chọn · G: gộp · /n: chia đều · gõ mm: chia theo khoảng · Ctrl: dọc/ngang · Tab: lọt/phủ · Enter: tạo'
      end

      def split_axis
        @settings['split_axis'] == 'horizontal' ? 'horizontal' : 'vertical'
      end

      FITS = %w[phu lot].freeze
      FIT_LABELS = { 'phu' => 'CÁNH PHỦ', 'lot' => 'CÁNH LỌT' }.freeze

      # Chỉ còn hai kiểu: phủ và lọt. Tủ cũ lưu 'thông thủy' thì coi là lọt.
      def fit
        return 'lot' if @settings['door_fit'] == 'thong_thuy'
        FITS.include?(@settings['door_fit']) ? @settings['door_fit'] : 'phu'
      end

      def cover_left?
        @settings['door_cover_left'] != false
      end

      def cover_right?
        @settings['door_cover_right'] != false
      end

      # Tủ đã (hoặc sắp) dùng kiểu mới: thùng tủ lùi theo dày cánh, mặt ngoài cánh trùng mặt trước box.
      # Tủ cũ chưa có 'door_recess' (khi chỉ dựng lại cánh) vẫn giữ cách đặt cũ để không đè vào thùng tủ.
      def new_style?
        @interactive ? true : @new_style ? true : false
      end

      # Đổi chế độ/khe mép thì vùng chia cánh đổi kích thước: cập nhật lại bố cục cho khớp.
      def hud_after_set(_key)
        sync_size if @root && @root.valid? && @shell && @shell.valid?
        reset_hover
      end

      # Hình chữ nhật mà các cánh chia nhau (đơn vị SketchUp, hệ thùng tủ) và mặt phẳng y của cánh.
      #   phủ:        trùm cả mặt trước thân tủ (trừ khe mép), cánh nằm trước thân tủ
      #   lọt:        nằm trong lòng tủ (giữa hông, nóc, đáy), trừ khe mép, mặt cánh bằng mặt trước thân tủ
      #   thông thủy: như lọt nhưng vừa khít lòng tủ, không chừa khe mép
      #   Lòng tủ đo từ tấm thật (hông/nóc/đáy có thể dày khác dày ván đang đặt, hoặc bị tắt).
      def area(bounds)
        t = @settings['board_thickness'].to_f.mm
        edge = @settings['door_edge_gap'].to_f.mm
        gap = @settings['door_inset_gap'].to_f.mm
        inner = @shell && @shell.valid? ? Interior.inner(@shell) : nil
        ix0, ix1 = inner ? [inner.x0, inner.x1] : [bounds.min.x + t, bounds.max.x - t]
        if new_style?
          # Phủ: phủ nóc, đáy và (tùy chọn) hông trái/phải. Lọt: nằm giữa hai hông nhưng cao phủ nóc và đáy.
          x0 = fit == 'phu' && cover_left? ? bounds.min.x + edge : ix0 + gap
          x1 = fit == 'phu' && cover_right? ? bounds.max.x - edge : ix1 - gap
          z0, z1 = bounds.min.z + edge, bounds.max.z - edge
          y = t # mặt sau cánh; mặt ngoài cánh (y - dày) nằm đúng mặt trước box (y = 0)
        elsif fit == 'phu'
          x0, x1, z0, z1 = bounds.min.x + edge, bounds.max.x - edge, bounds.min.z + edge, bounds.max.z - edge
          # Tủ cũ: cánh phủ áp sát mặt trước thân tủ, nằm ngoài thân.
          y = bounds.min.y
        else
          iz0, iz1 = inner ? [inner.z0, inner.z1] : [bounds.min.z + t, bounds.max.z - t]
          x0, x1, z0, z1 = ix0 + gap, ix1 - gap, iz0 + gap, iz1 - gap
          y = bounds.min.y + t
        end
        x1 = [x1, x0 + MIN_AREA].max
        z1 = [z1, z0 + MIN_AREA].max
        { x0: x0, x1: x1, z0: z0, z1: z1, y: y }
      end

      MIN_AREA = 20.0 / 25.4

      # Dùng luôn tủ đang chọn sẵn nếu có.
      def activate
        @interactive = true
        super
        cabinet = ModelData.cabinets_in(Sketchup.active_model.selection).first
        load_cabinet(cabinet) if cabinet
        rebuild_preview
      end

      def load_cabinet(root)
        return false unless root && root.valid?
        shell = Geometry.shell_for(root)
        return false unless shell
        @root = root
        @new_style = !Rebuild.settings_of(root)['door_recess'].nil?
        @shell = shell
        bounds = Geometry.body_bounds(@shell)
        saved = (JSON.parse(@root.get_attribute(Schema::DICTIONARY, 'door_layout_json', '{}')) rescue {})
        @settings.merge!(saved['settings']) if saved['settings'].is_a?(Hash)
        a = area(bounds)
        @layout = DoorLayout::Layout.from_h(saved, (a[:x1] - a[:x0]).to_mm, (a[:z1] - a[:z0]).to_mm)
        @selected = []
        reset_hover
        note_cabinet
        true
      end

      def note_cabinet
        Dialog.set_status('Đã chọn tủ. Rê chuột vào vùng, click để chia.')
      end

      def update_settings(settings)
        split_axis_keep = @settings['split_axis']
        @settings = Schema.merge_settings(settings)
        @settings['split_axis'] = split_axis_keep
        rebuild_preview
        Sketchup.active_model.active_view.invalidate
      end

      def reset_hover
        @hover_region = nil
        @hover_split = nil
        @hover_uv = nil
      end

      # Toạ độ (u, v) trong 0..1 trên mặt trước thân tủ của một điểm thế giới.
      def uv_at(point)
        local = point.transform(Operations.world_transform(@root, @shell).inverse)
        a = area(Geometry.body_bounds(@shell))
        u = (local.x - a[:x0]) / (a[:x1] - a[:x0])
        v = (local.z - a[:z0]) / (a[:z1] - a[:z0])
        [[[u, 0.0].max, 1.0].min, [[v, 0.0].max, 1.0].min]
      end

      def sync_size
        a = area(Geometry.body_bounds(@shell))
        @layout.set_size((a[:x1] - a[:x0]).to_mm, (a[:z1] - a[:z0]).to_mm)
      end

      # Cập nhật vùng đang trỏ và vị trí chia gợi ý. Trả về true nếu có gì đổi.
      def update_hover(point, shift)
        sync_size
        u, v = uv_at(point)
        region = @layout.region_at(u, v)
        id = region && region['id']
        split = nil
        split = @layout.propose(id, split_axis, split_axis == 'horizontal' ? v : u) if id && !shift
        changed = id != @hover_region || split != @hover_split || shift != @hover_shift
        @hover_region = id
        @hover_split = split
        @hover_shift = shift
        @hover_uv = [u, v]
        changed
      end

      def onMouseMove(flags, x, y, view)
        super
        if @root.nil?
          root = picked_cabinet(view, x, y)
          if root != @hover_root
            @hover_root = root
            rebuild_preview
          end
        elsif @shell && @shell.valid?
          point = cursor_point(view, x, y)
          rebuild_preview if point && update_hover(point, Keys.shift?(flags))
        end
        view.invalidate
      end

      # Điểm con trỏ trên MẶT PHẲNG MẶT NGOÀI CỦA CÁNH (giao tia nhìn với mặt phẳng đó), không dùng điểm suy luận
      # (có thể rơi vào hông/hậu/đợt phía sau nên lệch khi xoay góc nhìn).
      def cursor_point(view, x, y)
        transform = Operations.world_transform(@root, @shell)
        a = area(Geometry.body_bounds(@shell))
        origin = Geom::Point3d.new(0, a[:y] - @settings['board_thickness'].to_f.mm, 0).transform(transform)
        normal = Geom::Vector3d.new(0, 1, 0).transform(transform)
        point = Geom.intersect_line_plane(view.pickray(x, y), [origin, normal])
        return point if point
        @ip.pick(view, x, y)
        @ip.valid? ? @ip.position : nil
      end

      def onLButtonDown(flags, x, y, view)
        if @root.nil?
          root = picked_cabinet(view, x, y)
          load_cabinet(root) if root
          rebuild_preview
          view.invalidate
          return
        end
        return if click_finish?(view, x, y)
        return unless @shell && @shell.valid?
        point = cursor_point(view, x, y)
        return unless point
        update_hover(point, Keys.shift?(flags))
        if Keys.shift?(flags)
          toggle_selection(@hover_region)
        elsif @hover_region && @hover_split
          @layout.split(@hover_region, split_axis, @hover_split)
          @selected = []
          @hover_split = nil
          Dialog.set_status("Đã chia: #{@layout.regions.length} vùng. Enter để tạo cánh.")
        else
          Dialog.set_status('Vị trí này sát mép vùng (mỗi vùng tối thiểu 20 mm). Rê chuột vào giữa vùng.')
        end
        rebuild_preview
        view.invalidate
      rescue ArgumentError => e
        Dialog.set_status(e.message)
      end

      def toggle_selection(id)
        return unless id
        if @selected.include?(id)
          @selected.delete(id)
        else
          @selected << id
        end
        Dialog.set_status(@selected.empty? ? 'Đã bỏ chọn vùng.' : "Đã chọn #{@selected.length} vùng. Bấm G (hoặc gõ g + Enter) để gộp.")
      end

      # Gộp các vùng đang chọn (phải ghép thành hình chữ nhật).
      def merge_selected(view)
        region = @layout.merge(@selected)
        @selected = [region['id']]
        reset_hover
        Dialog.set_status("Đã gộp, còn #{@layout.regions.length} vùng.")
        rebuild_preview
        view.invalidate if view
      rescue ArgumentError => e
        Dialog.set_status(e.message)
      end

      # Xóa cánh của vùng đã chọn: vùng thành trống (không gộp vào cánh bên cạnh). Enter để áp dụng.
      def empty_selected(view)
        ids = target_ids
        return Dialog.set_status('Chọn vùng cần xóa cánh (Shift-click) rồi chọn lại lệnh.') if ids.empty?
        ids.each do |id|
          region = @layout.find(id)
          region['empty'] = true if region
        end
        @selected = []
        reset_hover
        Dialog.set_status("Đã đánh dấu #{ids.length} vùng trống (không cánh). Enter để áp dụng.")
        rebuild_preview
        view.invalidate if view
      end

      # Vùng cần chia khi gõ /n hoặc số: các vùng đang chọn, hoặc vùng đang trỏ, hoặc vùng duy nhất.
      def target_ids
        return @selected.dup unless @selected.empty?
        return [@hover_region] if @hover_region
        @layout.regions.length == 1 ? [@layout.regions.first['id']] : []
      end

      def onUserText(text, view)
        raw = text.to_s.strip
        sync_size
        if raw.match?(/\Ag\z/i)
          merge_selected(view)
          return
        end
        if (match = raw.match(%r{\A/(\d+)\z}))
          divide_even(match[1].to_i)
        elsif raw.match?(/\A\d+([.,]\d+)?\s*(mm)?\z/i)
          divide_mm(raw.sub(/\s*mm\z/i, '').tr(',', '.').to_f)
        else
          raise 'Nhập /2, /3… (chia đều), số mm (chia theo khoảng cách) hoặc g (gộp vùng chọn).'
        end
        @selected = []
        reset_hover
        rebuild_preview
        view.invalidate
      rescue ArgumentError, RuntimeError => e
        Dialog.set_status(e.message)
      end

      def divide_even(count)
        count = [[count, 2].max, 20].min
        ids = target_ids
        if ids.empty?
          # Không trỏ vào vùng nào và đã có nhiều vùng: chia đều lại toàn mặt tủ.
          @layout.reset_even(split_axis, count)
          Dialog.set_status("Đã chia đều lại toàn mặt tủ thành #{count} vùng.")
        else
          @layout.batch { ids.each { |id| @layout.split_even(id, split_axis, count) } }
          Dialog.set_status("Đã chia đều #{ids.length} vùng, mỗi vùng #{count} phần. Tổng #{@layout.regions.length} vùng.")
        end
      end

      def divide_mm(mm)
        ids = target_ids
        raise 'Rê chuột vào vùng cần chia (hoặc Shift-click chọn vùng) rồi gõ số mm.' if ids.length != 1
        region = @layout.find(ids.first)
        axis = split_axis
        pointer = @hover_uv ? (axis == 'horizontal' ? @hover_uv[1] : @hover_uv[0]) : nil
        low = axis == 'horizontal' ? region['v0'] : region['u0']
        high = axis == 'horizontal' ? region['v1'] : region['u1']
        # Đo từ mép gần con trỏ hơn.
        from = pointer && pointer > (low + high) / 2 ? :high : :low
        @layout.split_mm(ids.first, axis, mm, from)
        Dialog.set_status("Đã chia cách mép #{from == :high ? 'trên/phải' : 'dưới/trái'} #{mm.round(1)} mm.")
      end

      def onKeyDown(key, repeat, flags, view)
        if Keys.backspace?(key)
          if @layout.undo
            @selected &= @layout.ids
            reset_hover
            Dialog.set_status("Đã hoàn tác bước chia, còn #{@layout.regions.length} vùng.")
          elsif !@selected.empty?
            @selected = []
          end
          rebuild_preview
          view.invalidate
          true
        elsif Keys.letter?(key, 'g')
          merge_selected(view)
          true
        elsif Keys.ctrl_key?(key)
          # Ctrl đổi dọc/ngang; giữ phím không đổi liên tục (chỉ đổi ở lần nhấn đầu).
          toggle_split_axis(view) unless @ctrl_down
          @ctrl_down = true
          true
        else
          super
        end
      end

      def onKeyUp(key, _repeat, _flags, _view)
        @ctrl_down = false if Keys.ctrl_key?(key)
        false
      end

      # Ctrl đổi hướng chia dọc/ngang; các đường chia đã có được GIỮ NGUYÊN.
      def toggle_split_axis(view)
        @settings['split_axis'] = split_axis == 'horizontal' ? 'vertical' : 'horizontal'
        @hover_split = nil
        rebuild_preview
        view.invalidate
        Dialog.set_status("Chia theo hướng #{split_axis == 'horizontal' ? 'ngang (các cánh xếp chồng)' : 'dọc (các cánh xếp cạnh nhau)'}.")
      end

      # Tab đổi cánh lọt / cánh phủ. Kích thước phủ bì (cả cánh) luôn giữ bằng box ban đầu.
      def handle_tab(view)
        @settings['door_fit'] = fit == 'phu' ? 'lot' : 'phu'
        hud_after_set('door_fit')
        rebuild_preview
        view.invalidate
        Dialog.set_status(fit == 'lot' ? 'Cánh LỌT: nằm giữa hai hông, phủ nóc và đáy (nóc, đáy, phào, chân lùi vào bằng dày cánh).' : 'Cánh PHỦ: phủ nóc, đáy và hông được tick trong bảng (Phủ hông trái / phải).')
      end

      # Kiểu cánh quyết định độ lùi của thùng tủ: dựng lại thùng tủ khi độ lùi đổi (giữ đợt/vách/ngăn kéo/tấm chỉnh tay).
      # Trả về true nếu có dựng lại.
      def apply_recess!
        recess = DoorFit.recess_for(fit, cover_left?, cover_right?, @settings['board_thickness'])
        current = Rebuild.settings_of(@root)
        @new_style = true
        return false if DoorFit.same?(current['door_recess'], recess)
        dims = Rebuild.dimensions_of(@root)
        keep = Rebuild.hand_edited(@root).map { |entry| entry[:entity] }
        Rebuild.run(@root, current.merge('door_recess' => recess), dims, keep)
        @shell = Geometry.shell_for(@root)
        true
      end

      # Bố cục dùng để vẽ preview: bố cục hiện tại cộng đường chia đang rê chuột (chưa click).
      def preview_layout
        return @layout unless @hover_region && @hover_split && !@hover_shift
        copy = @layout.dup
        copy.split(@hover_region, split_axis, @hover_split)
        copy
      rescue ArgumentError
        @layout
      end

      # Các ô cánh (đơn vị trong của SketchUp). Dùng chung cho preview và dựng thật để hai bên luôn khớp.
      # Khe hở (door_gap) chỉ nằm GIỮA hai cánh liền kề, mép ngoài của cánh luôn sát mép mặt tủ.
      def cells(bounds, layout = @layout)
        a = area(bounds)
        gap = @settings['door_gap'].to_f.mm
        layout.rects(a[:x1] - a[:x0], a[:z1] - a[:z0], gap).map do |r|
          { x0: a[:x0] + r[:x0], x1: a[:x0] + r[:x1], z0: a[:z0] + r[:z0], z1: a[:z0] + r[:z1],
            y: a[:y], index: r[:index], id: r[:id], region: r[:region] }
        end
      end

      def ready?
        !@root.nil? && @root.valid?
      end

      def pending?
        !@selected.empty?
      end

      def clear_pending!
        @selected = []
      end

      def commit(view)
        raise 'Chọn tủ trước.' unless @root && @root.valid?
        @shell = Geometry.shell_for(@root)
        raise 'Không tìm thấy hình học thùng tủ.' unless @shell
        # Kiểm tra kiểu cánh trước khi chạm vào model.
        bounds = Geometry.body_bounds(@shell)
        sync_size
        cells(bounds).each { |cell| DoorGeometry.parts(cell, @settings) }
        operation('Chia cánh') do
          save_layout!
          apply_recess!
          build_doors
        end
        clear_pending!
        view.invalidate
        warn = shelf_clash_warning
        Dialog.set_status("Đã lưu bố cục và tạo cánh (#{FIT_LABELS[fit].downcase}). Có thể chia lại bằng công cụ này.#{warn}")
      rescue StandardError => e
        Dialog.set_status(e.message)
      end

      # Dựng (lại) toàn bộ cánh theo bố cục hiện tại, giữ tay nắm và góc mở theo vùng. Không mở operation:
      # dùng trong lệnh Chia cánh và khi Sửa tủ dựng lại.
      # Ghi bố cục + kiểu cánh TRƯỚC khi dựng lại đợt/vách: đợt và vách đọc kiểu cánh (lọt/phủ) từ đây để lùi đúng.
      def save_layout!
        data = @layout.to_h.merge('gap_mm' => @settings['door_gap'].to_f, 'settings' => @settings.slice(*SAVED_KEYS))
        @root.set_attribute(Schema::DICTIONARY, 'door_layout_json', JSON.generate(data))
      end

      def build_doors
        sync_size
        @root.make_unique if @root.respond_to?(:make_unique)
        @shell = Geometry.shell_for(@root)
        bounds = Geometry.body_bounds(@shell)
        # Nhớ tay nắm và góc mở của từng vùng để dựng lại sau khi chia lại cánh.
        keep = {}
        Operations.doors_of(@root).each do |old|
          rid = old.get_attribute(Schema::DICTIONARY, 'region_id')
          next unless rid
          keep[rid.to_i] = { angle: Operations.door_angle(old), side: old.get_attribute(Schema::DICTIONARY, 'opening_side'),
                             handles: Operations.handle_specs(old) }
        end
        # Xóa cánh cũ (kể cả cánh nằm lẻ trong tủ ở bản trước) rồi dựng lại trong group 'Cánh' riêng.
        Operations.door_container_clear(@root)
        container = Operations.door_container(@root, @shell)
        cells(bounds).each do |cell|
          region = cell[:region]
          front = DoorGeometry.build(container.entities, cell, 'Cánh Draw', @settings)
          front.set_attribute(Schema::DICTIONARY, 'part_index', cell[:index] + 1)
          front.set_attribute(Schema::DICTIONARY, 'region_id', region['id'])
          ModelData.stamp(front, 'door', region.merge('gap_mm' => @settings['door_gap'].to_f, 'fit' => fit))
          front.set_attribute(Schema::DICTIONARY, 'style', @settings.fetch('door_style', 'flat'))
          Operations.apply_opening_metadata(front, region['opening_type'])
          old = keep[region['id'].to_i]
          next unless old
          old[:handles].each { |spec| Operations.add_handle(front, spec) }
          side = DoorLayout.opening_type(region['opening_type'])
          side = old[:side].to_s unless Operations::HINGE_SIDES.include?(side)
          next unless old[:angle] > 0.5 && Operations::HINGE_SIDES.include?(side)
          Operations.apply_opening_metadata(front, side) unless DoorLayout.opening_type(region['opening_type']) == side
          Operations.set_door_angle(front, side, old[:angle])
        end
        Geometry.share_components(@root)
      end

      # Cánh lọt/thông thủy chiếm phần trước lòng tủ: báo nếu có đợt cũ nằm sát mép trước (sẽ chạm cánh).
      def shelf_clash_warning
        return '' if fit == 'phu' || @shell.nil? || !@shell.valid?
        limit = Geometry.body_bounds(@shell).min.y + @settings['board_thickness'].to_f.mm
        count = Interior.members(@shell)[:shelves].count { |b| b[1] < limit - 0.01.mm }
        count.zero? ? '' : " Lưu ý: #{count} đợt đang chạm cánh lọt — hãy xóa và chia lại đợt (đợt sẽ tự lùi theo cánh lọt)."
      end

      def rebuild_preview
        @preview = Preview.new
        @error = nil
        if @root.nil?
          outline_front(@hover_root, @preview) if @hover_root && @hover_root.valid?
          return
        end
        return unless @root.valid? && @shell && @shell.valid?
        bounds = Geometry.body_bounds(@shell)
        transform = Operations.world_transform(@root, @shell)
        begin
          cells(bounds, preview_layout).each do |cell|
            DoorGeometry.parts(cell, @settings).each do |part|
              @preview.add_prism_y(part[:polygon], part[:y], part[:depth], transform, part[:kind])
            end
          end
        rescue StandardError => e
          @error = e.message
        end
        add_dimension_labels(bounds, transform) if @settings['show_dims'] && @error.nil?
        highlight_regions(bounds, transform)
        add_split_marker(bounds, transform) if @hover_region && @hover_split && !@hover_shift
      end

      # Nhãn kích thước từng cánh (rộng × cao, mm) ở mặt trước cánh.
      def add_dimension_labels(bounds, transform)
        depth = @settings['board_thickness'].to_f.mm
        cells(bounds, preview_layout).each do |cell|
          spot = Geom::Point3d.new((cell[:x0] + cell[:x1]) / 2, cell[:y] - depth - 1.mm, (cell[:z0] + cell[:z1]) / 2).transform(transform)
          @preview.add_label(spot, format('%.0f × %.0f', (cell[:x1] - cell[:x0]).to_mm, (cell[:z1] - cell[:z0]).to_mm))
        end
      end

      # Vùng đang chọn: xanh lá. Vùng đang trỏ khi giữ Shift: vàng (sắp được chọn/bỏ chọn).
      def highlight_regions(bounds, transform)
        cells(bounds).each do |cell|
          selected = @selected.include?(cell[:id])
          hovered = @hover_shift && cell[:id] == @hover_region
          next unless selected || hovered
          polygon = [[cell[:x0], cell[:z0]], [cell[:x1], cell[:z0]], [cell[:x1], cell[:z1]], [cell[:x0], cell[:z1]]]
          y = cell[:y] - @settings['board_thickness'].to_f.mm - 3.mm
          @preview.add_prism_y(polygon, y, 2.mm, transform, selected ? :override : :hover)
        end
      end

      # Đường chia đang rê chuột, chỉ chạy trong phạm vi vùng đang trỏ, kèm số đo hai bên.
      def add_split_marker(bounds, transform)
        region = @layout.find(@hover_region)
        return unless region
        horizontal = split_axis == 'horizontal'
        w = 3.mm
        a = area(bounds)
        aw = a[:x1] - a[:x0]
        ah = a[:z1] - a[:z0]
        y = a[:y] - @settings['board_thickness'].to_f.mm
        x0 = a[:x0] + region['u0'] * aw
        x1 = a[:x0] + region['u1'] * aw
        z0 = a[:z0] + region['v0'] * ah
        z1 = a[:z0] + region['v1'] * ah
        if horizontal
          v = a[:z0] + @hover_split * ah
          polygon = [[x0, v - w], [x1, v - w], [x1, v + w], [x0, v + w]]
          label_at = [(x0 + x1) / 2, v]
          low_mm = (v - z0).to_mm
          high_mm = (z1 - v).to_mm
        else
          v = a[:x0] + @hover_split * aw
          polygon = [[v - w, z0], [v + w, z0], [v + w, z1], [v - w, z1]]
          label_at = [v, (z0 + z1) / 2]
          low_mm = (v - x0).to_mm
          high_mm = (x1 - v).to_mm
        end
        @preview.add_prism_y(polygon, y + 2.mm, 2.mm, transform, :hover)
        spot = Geom::Point3d.new(label_at[0], y, label_at[1]).transform(transform)
        @preview.add_label(spot, format('%.0f | %.0f mm', low_mm, high_mm))
      end

      # Viền mặt trước của tủ khi rê chuột chọn tủ.
      def outline_front(root, preview)
        shell = Geometry.shell_for(root)
        return unless shell
        b = Geometry.body_bounds(shell)
        tr = Operations.world_transform(root, shell)
        pts = [[b.min.x, b.min.z], [b.max.x, b.min.z], [b.max.x, b.max.z], [b.min.x, b.max.z]]
        preview.add_prism_y(pts, b.min.y, 2.mm, tr, :hover)
      end

      def hud_lines
        return ['Chưa chọn tủ.', 'Rê chuột vào tủ (viền vàng) rồi click.'] unless @root
        return [] unless @shell && @shell.valid?
        bounds = Geometry.body_bounds(@shell)
        list = cells(bounds, preview_layout)
        lines = ["Cánh: #{list.length}   #{FIT_LABELS[fit]}   Chia #{split_axis == 'horizontal' ? 'NGANG' : 'DỌC'}   Đã chọn: #{@selected.length}",
                 "Kiểu: #{{ 'flat' => 'phẳng', 'shaker' => 'shaker', 'recessed' => 'panel âm', 'glass' => 'khung kính' }.fetch(@settings['door_style'], @settings['door_style'].to_s)}"]
        list.first(6).each do |cell|
          mark = @selected.include?(cell[:id]) ? ' *' : ''
          lines << format('Cánh %d: %.0f × %.0f mm%s', cell[:index] + 1, (cell[:x1] - cell[:x0]).to_mm, (cell[:z1] - cell[:z0]).to_mm, mark)
        end
        lines << "(còn #{list.length - 6} cánh nữa)" if list.length > 6
        lines << "Lỗi: #{@error}" if @error
        lines
      end
    end

    class OpeningTool < Base
      PIXELS_PER_DEGREE = 3.0
      MAX_ANGLE = 135.0

      def initialize(settings = {})
        super
        @tool_name = 'opening'
        @targets = []
        @parent_transforms = {}
        @hover_door = nil
        @queue = []        # cánh chọn sẵn đang chờ tới lượt (mỗi cánh một góc riêng)
        @angle = 0.0
        @ref_x = nil
        @hinge_side = nil
      end

      def status_hint
        'Click cánh → rê chuột chọn góc → click chốt · Ctrl+Click: gom nhóm · Tab: đổi bản lề · Enter: kết thúc'
      end

      def hud_read(key)
        key == 'hinge_side' ? hinge_side : @settings[key]
      end

      def hud_write(key, value)
        if key == 'hinge_side'
          @hinge_side = value
        else
          @settings[key] = value
        end
      end

      def hint
        'Click một cánh → rê chuột trái/phải = góc mở → click chốt (rồi click cánh khác) · Ctrl+click: gom nhiều cánh dùng chung một góc · Shift: bước 15° · gõ số + Enter · Tab đổi bản lề · Backspace bỏ cánh · Enter (không chọn cánh): kết thúc'
      end

      # Các cánh chọn sẵn xếp hàng: mỗi cánh đặt một góc riêng, lần lượt từng cánh.
      def activate
        super
        Sketchup.active_model.selection.each do |entity|
          next unless Operations.door?(entity)
          @parent_transforms[entity] = Operations.parent_transform(entity) || Geom::Transformation.new
          @queue << entity
        end
        advance_queue
        rebuild_preview
      end

      def add_target(entity, parent)
        first = @targets.empty?
        @targets << entity unless @targets.include?(entity)
        @parent_transforms[entity] = parent || Geom::Transformation.new
        saved = Operations.opening_type_of(entity)
        @hinge_side = saved if saved != 'none' && first
        @hinge_side ||= 'left'
      end

      # Lấy cánh kế tiếp trong hàng chờ làm cánh đang chỉnh (nếu chưa có cánh nào đang chỉnh).
      def advance_queue
        @queue.delete_if { |door| !door.valid? }
        return unless @targets.empty? && !@queue.empty?
        door = @queue.shift
        add_target(door, @parent_transforms[door])
        sync_angle
      end

      # Góc ban đầu lấy từ cánh đầu tiên để chuột bắt đầu từ trạng thái hiện tại.
      def sync_angle
        first = @targets.find(&:valid?)
        @angle = first ? Operations.door_angle(first) : 0.0
        @ref_x = nil
      end

      def hinge_side
        @hinge_side || 'left'
      end

      # Cánh đang mở giữ bản lề đã lưu; cánh đóng nhận bản lề đang chọn.
      def side_for(door)
        if Operations.door_angle(door) > 0.5
          stored = door.get_attribute(Schema::DICTIONARY, 'opening_side', hinge_side)
          Operations::HINGE_SIDES.include?(stored) ? stored : hinge_side
        else
          hinge_side
        end
      end

      SIDE_ORDER = %w[left right top bottom drawer].freeze
      SIDE_NAMES = { 'left' => 'trái', 'right' => 'phải', 'top' => 'trên (lật lên)', 'bottom' => 'dưới (lật xuống)', 'drawer' => 'ngăn kéo (chỉ lưu dữ liệu)' }.freeze

      def update_settings(settings)
        keep = @settings.slice('hinge_side')
        @settings = Schema.merge_settings(settings).merge(keep)
      end

      # Tìm cánh VGD và phép biến đổi của các group cha từ đường dẫn pick.
      def door_from_path(path)
        entity = path.reverse.find { |item| Operations.door?(item) }
        return nil unless entity && entity.valid?
        parent_path = path.take_while { |item| item != entity }
        parent = parent_path.select { |item| item.is_a?(Sketchup::Group) || item.is_a?(Sketchup::ComponentInstance) }.reduce(Geom::Transformation.new) { |memo, item| memo * item.transformation }
        [entity, parent]
      end

      def onMouseMove(flags, x, y, view)
        found = door_from_path(picked_path(view, x, y))
        entity = found && found[0]
        @parent_transforms[entity] = found[1] if found
        @hover_door = entity
        unless @targets.empty?
          @ref_x ||= x - @angle * PIXELS_PER_DEGREE
          angle = (x - @ref_x) / PIXELS_PER_DEGREE
          angle = (angle / 15.0).round * 15.0 if Keys.shift?(flags)
          @angle = [[angle, 0.0].max, MAX_ANGLE].min
          show_angle
        end
        rebuild_preview
        view.invalidate
      end

      def show_angle
        Sketchup.vcb_label = 'Góc mở'
        Sketchup.vcb_value = format('%.1f°', @angle)
      rescue StandardError
        nil
      end

      # Click: chưa có cánh đang chỉnh -> chọn cánh đó. Đang chỉnh -> chốt góc; nếu click vào một cánh khác thì chọn luôn cánh đó.
      # Ctrl+click: thêm/bỏ cánh khỏi nhóm dùng chung một góc.
      def onLButtonDown(flags, x, y, view)
        return if click_finish?(view, x, y)
        found = door_from_path(picked_path(view, x, y))
        entity, parent = found
        if Keys.ctrl?(flags)
          if entity
            if @targets.include?(entity)
              @targets.delete(entity)
            else
              add_target(entity, parent)
            end
            @queue.delete(entity)
            sync_angle
            note_selection
          end
        elsif @targets.empty?
          if entity
            @queue.delete(entity)
            add_target(entity, parent)
            sync_angle
            note_selection
          end
        else
          committed = apply_angle(view)
          if committed && entity && !committed.include?(entity)
            @queue.delete(entity)
            @targets.clear
            add_target(entity, parent)
            sync_angle
            note_selection
          end
        end
        rebuild_preview
        view.invalidate
      end

      def note_selection
        count = @targets.length
        extra = @queue.empty? ? '' : " Còn #{@queue.length} cánh chờ."
        Dialog.set_status(count > 1 ? "Đang chỉnh nhóm #{count} cánh dùng chung một góc. Rê chuột chọn góc, click chốt.#{extra}" : "Đang chỉnh 1 cánh. Rê chuột trái/phải chọn góc, click chốt.#{extra}")
      end

      # Esc lần 1: bỏ cánh đang chỉnh (chưa áp dụng gì); Esc khi không còn cánh nào: thoát công cụ.
      def cancel_tool(view)
        if @targets.empty? && @queue.empty?
          super
        else
          @targets.clear
          @queue.clear
          sync_angle
          rebuild_preview
          Dialog.set_status('Đã bỏ chọn cánh. Esc lần nữa để thoát công cụ.')
          view.invalidate if view
        end
      end

      def onUserText(text, view)
        value = text.to_s.strip.tr(',', '.').sub(/°\z/, '')
        raise 'Nhập góc mở bằng số (độ), ví dụ 90. Nhập 0 để đóng cánh.' unless value.match?(/\A\d+(\.\d+)?\z/)
        raise 'Hãy chọn cánh trước (click vào cánh).' if @targets.empty?
        @angle = [value.to_f, MAX_ANGLE].min
        apply_angle(view)
      rescue StandardError => e
        Dialog.set_status(e.message)
      end

      def onKeyDown(key, repeat, flags, view)
        if Keys.tab?(key)
          @hinge_side = SIDE_ORDER[(SIDE_ORDER.index(hinge_side).to_i + 1) % SIDE_ORDER.length]
          Dialog.set_status("Bản lề: #{SIDE_NAMES[hinge_side]} (chỉ áp dụng cho cánh đang đóng).")
          rebuild_preview
          view.invalidate
          true
        elsif Keys.backspace?(key)
          @targets.pop
          advance_queue
          sync_angle
          rebuild_preview
          view.invalidate
          true
        else
          super
        end
      end

      def ready?
        !@targets.empty?
      end

      # Enter hoặc nút Áp dụng: có cánh đang chỉnh thì chốt góc; không có thì kết thúc công cụ.
      def commit(view)
        @targets.delete_if { |door| !door.valid? }
        if @targets.empty?
          view.model.select_tool(nil)
          Dialog.set_status('Đã kết thúc công cụ mở cánh.')
        else
          apply_angle(view)
        end
      end

      # Áp góc đang xem cho cánh đang chỉnh (một cánh, hoặc nhóm Ctrl+click), rồi chuyển sang cánh kế tiếp trong hàng chờ.
      # Trả về danh sách cánh vừa áp dụng, hoặc nil nếu lỗi.
      def apply_angle(view)
        @targets.delete_if { |door| !door.valid? }
        raise 'Click vào một cánh trước.' if @targets.empty?
        angle = @angle
        doors = @targets.dup
        operation(angle < 0.5 ? 'Đóng cánh' : "Mở cánh #{angle.round(1)}°") do
          doors.each do |door|
            side = side_for(door)
            if side == 'drawer'
              # Ngăn kéo: chỉ lưu loại mở, không xoay.
              Operations.apply_opening_metadata(door, 'drawer')
            else
              Operations.set_door_angle(door, side, angle)
              Operations.opening_marker(door, side) unless door.definition.entities.to_a.any? { |e| e.name == Operations::MARKER_NAME && e.get_attribute(Schema::DICTIONARY, 'opening_side') == side }
            end
            # Ghi vào bố cục của tủ để chia lại cánh sau này không mất loại mở.
            Operations.save_opening_to_layout(door, side)
          end
        end
        @targets.clear
        @ref_x = nil
        advance_queue
        verb = angle < 0.5 ? 'đóng' : "mở #{angle.round(1)}°"
        more = @targets.empty? ? ' Click cánh khác, hoặc Enter/Esc để kết thúc.' : " Đang chỉnh cánh kế tiếp (còn #{@queue.length} chờ)."
        Dialog.set_status("Đã #{verb} #{doors.length} cánh.#{more}")
        rebuild_preview
        view.invalidate if view
        doors
      rescue StandardError => e
        Dialog.set_status(e.message)
        nil
      end

      # Xem trước cánh ở góc đang rê: khối xanh = vị trí mới, nét đứt vàng = vị trí hiện tại, cung = đường quét của mép cánh.
      def rebuild_preview
        @preview = Preview.new
        shown = @targets.dup
        @queue.each do |door|
          next unless door.valid?
          b = Operations.door_bounds(door)
          next unless b
          parent = @parent_transforms[door] || Geom::Transformation.new
          PanelModel.box_faces(b).each do |face|
            @preview.add_polygon(face.map { |x, y, z| Geom::Point3d.new(x, y, z).transform(door.transformation).transform(parent) }, :override)
          end
        end
        shown << @hover_door if @hover_door && @hover_door.valid? && !shown.include?(@hover_door)
        shown.each do |door|
          next unless door && door.valid?
          hover_only = !@targets.include?(door)
          b = Operations.door_bounds(door)
          next unless b
          side = side_for(door)
          angle = hover_only ? [@angle, 90.0].max : @angle
          current = Operations.door_angle(door)
          rotation = side == 'drawer' ? Geom::Transformation.new : Operations.rotation_between(door, side, current, angle)
          parent = @parent_transforms[door] || Geom::Transformation.new
          faces = PanelModel.box_faces(b)
          faces.each do |face|
            pts = face.map { |x, y, z| Geom::Point3d.new(x, y, z).transform(door.transformation).transform(rotation).transform(parent) }
            @preview.add_polygon(pts, hover_only ? :hover : :door)
          end
          faces.each do |face|
            pts = face.map { |x, y, z| Geom::Point3d.new(x, y, z).transform(door.transformation).transform(parent) }
            @preview.add_polygon(pts, :hover)
          end
          add_swing_arc(door, b, side, current, angle, parent) unless hover_only || side == 'drawer'
        end
      end

      # Điểm mép tự do của cánh (giữa cạnh đối diện bản lề), quỹ đạo quét của nó là cung xem trước.
      def add_swing_arc(door, b, side, current, angle, parent)
        point = case side
                when 'top' then Geom::Point3d.new((b[0] + b[3]) / 2, b[1], b[2])
                when 'bottom' then Geom::Point3d.new((b[0] + b[3]) / 2, b[1], b[5])
                else Geom::Point3d.new(side == 'left' ? b[3] : b[0], b[1], (b[2] + b[5]) / 2)
                end.transform(door.transformation)
        steps = 24
        top = [current, angle].max
        points = (0..steps).map do |i|
          deg = top * i / steps
          point.transform(Operations.rotation_between(door, side, current, deg)).transform(parent)
        end
        points.each_cons(2) { |p0, p1| @preview.add_line(p0, p1, :guide) }
        @preview.add_label(points.last, format('%.0f°', angle))
      end

      def hud_lines
        waiting = @queue.empty? ? '' : "   Còn chờ: #{@queue.length} cánh (xanh lá)"
        lines = ["Đang chỉnh: #{@targets.length} cánh#{@targets.length > 1 ? ' (chung một góc)' : ''}   Bản lề: #{SIDE_NAMES[hinge_side]}#{waiting}"]
        if @targets.empty?
          lines << 'Click vào một cánh để chỉnh góc riêng cho cánh đó.'
          lines << 'Ctrl+click: gom nhiều cánh dùng chung một góc · Enter: kết thúc'
        else
          lines << format('Góc mở xem trước: %.1f°%s', @angle, @angle < 0.5 ? ' (đóng)' : '')
          lines << 'Click / Enter: chốt rồi chọn cánh khác · gõ số + Enter: góc chính xác · góc 0 = chỉ đánh dấu hướng mở (cánh đóng) · Tab: đổi bản lề'
        end
        lines
      end
    end

    # Ngăn kéo: rê chuột vào ô của tủ (giữa hông/đợt/vách) để xem trước, click chọn ô (nhiều ô được), /n số hộc, Enter tạo.
    class DrawerTool < Base
      def initialize(settings = {})
        super
        @tool_name = 'drawer'
        @targets = []   # [root, điểm cục bộ]
        @hover = nil
        @error = nil
        @plans = []
      end

      def hint
        'Rê chuột vào ô cần đặt ngăn kéo · click chọn ô (có thể nhiều ô) · /n số hộc · Backspace bỏ ô · Enter tạo · Esc hủy'
      end

      def status_hint
        'Rê vào ô, click chọn ô · /n: số hộc · Backspace: bỏ ô · Enter: tạo · Esc: thoát'
      end

      def local_of(root, point)
        shell = Geometry.shell_for(root)
        return nil unless shell
        point.transform(Operations.world_transform(root, shell).inverse)
      end

      def onMouseMove(flags, x, y, view)
        super
        root = picked_cabinet(view, x, y)
        @hover = root && @ip.valid? ? [root, local_of(root, @ip.position)] : nil
        @hover = nil if @hover && @hover[1].nil?
        rebuild_preview
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, view)
        return if click_finish?(view, x, y)
        root = picked_cabinet(view, x, y)
        @ip.pick(view, x, y)
        return Dialog.set_status('Hãy click vào một tủ.') unless root && @ip.valid?
        local = local_of(root, @ip.position)
        return unless local
        @targets << [root, local]
        rebuild_preview
        Dialog.set_status("Đã chọn #{@targets.length} ô. Enter để tạo ngăn kéo.")
        view.invalidate
      end

      def onUserText(text, _view)
        match = text.to_s.strip.match(%r{\A/(\d+)\z})
        unless match
          Dialog.set_status('Ngăn kéo: gõ /2, /3… để đổi số hộc.')
          return
        end
        @settings['drawer_count'] = [[match[1].to_i, 1].max, 20].min
        rebuild_preview
        Sketchup.active_model.active_view.invalidate
      end

      def onKeyDown(key, repeat, flags, view)
        if Keys.backspace?(key)
          @targets.pop
          rebuild_preview
          view.invalidate
          true
        else
          super
        end
      end

      def rebuild_preview
        @preview = Preview.new
        @error = nil
        @plans = []
        list = @targets.dup
        list << @hover if @hover
        list.each_with_index do |(root, local), index|
          next unless root.valid?
          shell = Geometry.shell_for(root)
          next unless shell && shell.valid?
          transform = Operations.world_transform(root, shell)
          begin
            plan = Operations.drawer_plan(root, shell, @settings, local)
          rescue StandardError => e
            @error = e.message
            next
          end
          @plans << plan if index < @targets.length
          c = plan[:cell]
          @preview.add_prism_y([[c.x0, c.z0], [c.x1, c.z0], [c.x1, c.z1], [c.x0, c.z1]], c.y0 + 2.mm, 1.mm, transform, index < @targets.length ? :target : :hover)
          depth = @settings['board_thickness'].to_f.mm
          plan[:fronts].each do |f|
            @preview.add_prism_y([[f[:x0], f[:z0]], [f[:x1], f[:z0]], [f[:x1], f[:z1]], [f[:x0], f[:z1]]], f[:y], depth, transform, :drawer)
            next unless @settings['drawer_show_dims']
            spot = Geom::Point3d.new((f[:x0] + f[:x1]) / 2, f[:y] - depth - 1.mm, (f[:z0] + f[:z1]) / 2).transform(transform)
            @preview.add_label(spot, format('%.0f × %.0f', (f[:x1] - f[:x0]).to_mm, (f[:z1] - f[:z0]).to_mm))
          end
          plan[:boxes].each do |parts|
            parts.each do |_name, _role, x0, x1, y0, y1, z0, z1|
              PanelModel.box_faces([x0, y0, z0, x1, y1, z1]).each { |face| @preview.add_polygon(face.map { |px, py, pz| Geom::Point3d.new(px, py, pz).transform(transform) }, :body) }
            end
          end
        end
      end

      def hud_lines
        lines = ["Ô đã chọn: #{@targets.length}   Số hộc: #{@settings.fetch('drawer_count', 2)}"]
        plan = @plans.last || begin
          @hover && Operations.drawer_plan(@hover[0], Geometry.shell_for(@hover[0]), @settings, @hover[1])
        rescue StandardError
          nil
        end
        if plan
          fit = { 'phu' => 'phủ', 'lot' => 'lọt', 'thong_thuy' => 'thông thủy' }[plan[:fit]]
          lines << format('Mặt hộc %s: cao %.0f mm', fit, plan[:front_height_mm])
          lines << format('Ray %s · thùng sâu %.0f mm', plan[:slide] == 'under' ? 'âm' : 'bi (bên)', plan[:depth_mm])
        end
        lines << "Lỗi: #{@error}" if @error
        lines
      end

      def ready?
        !@targets.empty?
      end

      def pending?
        !@targets.empty?
      end

      def clear_pending!
        @targets = []
      end

      def commit(view)
        raise 'Click chọn ít nhất một ô của tủ.' if @targets.empty?
        warn = ''
        operation('Ngăn kéo') do
          @targets.each do |root, local|
            Operations.build_drawers(root, @settings, local)
            warn = ' Lưu ý: tủ đã có cánh, kiểm tra mặt hộc có chồng lên cánh không.' unless Operations.doors_of(root).empty?
          end
        end
        count = @targets.length
        clear_pending!
        rebuild_preview
        view.invalidate
        Dialog.set_status("Đã tạo ngăn kéo cho #{count} ô.#{warn} Click ô tiếp hoặc Esc thoát.")
      rescue StandardError => e
        Dialog.set_status(e.message)
      end
    end

    class SelectAndApplyTool < Base
      def initialize(name, settings = {}); super(settings); @tool_name = name; @targets = []; @points = []; end
      def onLButtonDown(flags, x, y, view)
        return if click_finish?(view, x, y)
        path=picked_path(view,x,y)
        entity = if @tool_name=='handle'
          path.reverse.find { |item| (item.is_a?(Sketchup::Group) || item.is_a?(Sketchup::ComponentInstance)) && (item.name.start_with?('Cánh Draw') || item.name == 'Mặt Ngăn Kéo') }
        elsif @tool_name=='round'
          path.reverse.find { |item| (item.is_a?(Sketchup::Group) || item.is_a?(Sketchup::ComponentInstance)) && !ModelData.cabinet?(item) }
        else
          picked_cabinet(view,x,y)
        end
        if entity && entity.valid?
          @targets << entity unless @targets.include?(entity)
          @ip.pick(view,x,y)
          @points << [entity, @ip.position, path.reverse.find { |item| item.is_a?(Sketchup::Edge) }] if @ip.valid?
          rebuild_preview
        end
        view.invalidate
      end
      def ready?
        !@targets.empty?
      end

      def pending?
        !@targets.empty?
      end

      def clear_pending!
        @targets = []
        @points = []
      end

      def hint; 'Click đặt/chọn điểm · Shift-click thêm · nhập /n chia đều · Enter xem trước và áp dụng · Esc hủy'; end
      def status_hint
        @tool_name == 'bay' ? 'Click chọn ô tủ · /n: số ngăn kéo · Enter: dựng khoang + ngăn kéo · Esc: thoát' : @tool_name == 'drawer' ? 'Click chọn tủ, click vị trí từng mặt hộc · /n: chia đều · Enter: áp dụng · Esc: thoát' : 'Click đặt/chọn điểm · Enter: áp dụng · Esc: thoát'
      end
      def onUserText(text,view)
        if %w[drawer bay].include?(@tool_name) && (match=text.to_s.strip.match(%r{\A/(\d+)\z}))
          @settings['drawer_count']=[[match[1].to_i,1].max,20].min
          rebuild_preview; view.invalidate
        else
          Dialog.set_status('Ngăn kéo: nhập /2, /3… hoặc click vị trí từng mặt hộc.')
        end
      end
      def rebuild_preview
        @preview=Preview.new
        @targets.each do |root|
          shell=Geometry.shell_for(root); next unless shell && shell.valid?
          b=Geometry.body_bounds(shell); transform=Operations.world_transform(root, shell)
          t=@settings.fetch('board_thickness',17.5).to_f.mm
          points=@points.select { |item| item[0]==root }
          if @tool_name=='drawer'
            count=points.empty? ? [[@settings.fetch('drawer_count',2).to_i,1].max,20].min : points.length
            height=@settings.fetch('drawer_front_height',180).to_f.mm
            gap=@settings.fetch('drawer_tier_gap',25).to_f.mm
            levels=points.empty? ? (0...count).map { |i| b.min.z+i*(height+gap) } : points.map { |item| item[1].transform(transform.inverse).z }
            levels.each do |z|
              pts=[[b.min.x+t,b.min.y-1.mm,z],[b.max.x-t,b.min.y-1.mm,z],[b.max.x-t,b.min.y-1.mm,z+height],[b.min.x+t,b.min.y-1.mm,z+height]].map { |p| Geom::Point3d.new(p).transform(transform) }
              @preview.add_polygon(pts,:front)
              if @settings['drawer_show_dims']
                mid = [(pts[0].x + pts[2].x) / 2, (pts[0].y + pts[2].y) / 2, (pts[0].z + pts[2].z) / 2]
                @preview.add_label(Geom::Point3d.new(*mid), format('Mặt hộc %.0f × %.0f mm', ((b.max.x - b.min.x) - 2 * t).to_mm, height.to_mm))
              end
            end
          elsif @tool_name=='blocker'
            c,=Operations.cell_for_click(root,shell,points)
            z=points.first ? points.first[1].transform(transform.inverse).z : c.z0+c.height*0.7
            h=@settings.fetch('blocker_height',60).to_f.mm
            z=[[z,c.z0].max,c.z1-h].min
            pts=[[c.x0,c.y0,z],[c.x1,c.y0,z],[c.x1,c.y0,z+h],[c.x0,c.y0,z+h]].map { |p| Geom::Point3d.new(p).transform(transform) }
            @preview.add_polygon(pts,:target)
          elsif @tool_name=='bay'
            begin
              c,local=Operations.cell_for_click(root,shell,points)
              geo=DrawerBay.geometry(root,shell,@settings,local)
              pts=[[geo[:x0],geo[:y0],geo[:z0]],[geo[:x1],geo[:y0],geo[:z0]],[geo[:x1],geo[:y0],geo[:z1]],[geo[:x0],geo[:y0],geo[:z1]]].map { |p| Geom::Point3d.new(p).transform(transform) }
              @preview.add_polygon(pts,:body)
            rescue StandardError => e
              Dialog.set_status(e.message)
            end
          elsif @tool_name=='wardrobe' && points.length>=2
            a=points[0][1].transform(transform.inverse); c=points[1][1].transform(transform.inverse)
            x0,x1=[a.x,c.x].minmax; z0,z1=[a.z,c.z].minmax
            pts=[[x0,b.min.y,z0],[x1,b.min.y,z0],[x1,b.min.y,z1],[x0,b.min.y,z1]].map { |p| Geom::Point3d.new(p).transform(transform) }
            @preview.add_polygon(pts,:body)
          elsif @tool_name=='handle'
            p=points.last && points.last[1].transform(Operations.world_transform(root).inverse)
            if p
              w=@settings.fetch('handle_width',100).to_f.mm
              @preview.add_polygon([[p.x-w/2,p.y,p.z-4.mm],[p.x+w/2,p.y,p.z-4.mm],[p.x+w/2,p.y,p.z+4.mm],[p.x-w/2,p.y,p.z+4.mm]].map { |v| Geom::Point3d.new(v).transform(Operations.world_transform(root)) },:front)
            end
          end
        end
      end
      def commit(view)
        raise 'Chọn ít nhất một đối tượng.' if @targets.empty?
        operation(Tools.label(@tool_name)) do
          case @tool_name
          when 'drawer' then Operations.drawers(@targets, @settings, @points)
          when 'wardrobe' then Operations.wardrobe(@targets, @settings, @points)
          when 'bay' then DrawerBay.run(@targets, @settings, @points)
          when 'blocker' then Operations.blockers(@targets, @settings, @points)
          when 'handle' then Operations.handles(@targets, @settings, @points)
          when 'round' then Operations.round_edges(@targets, @settings, @points)
          end
        end
        clear_pending!
        rebuild_preview
        view.invalidate
        Dialog.set_status("Đã áp dụng #{Tools.label(@tool_name)}. Chọn tiếp hoặc Esc thoát.")
      rescue StandardError => e
        Dialog.set_status(e.message)
      end
    end

    class CutTool < Base
      def initialize(settings = {}); super; @tool_name='cut'; @target=nil; @point=nil; @axis=0; end
      def hint; 'Chọn tấm, click vị trí cắt · Tab đổi trục · Enter cắt · Esc hủy'; end
      def onLButtonDown(_flags,x,y,view)
        return if click_finish?(view,x,y)
        path=picked_path(view,x,y)
        @target=path.reverse.find { |item| (item.is_a?(Sketchup::Group) || item.is_a?(Sketchup::ComponentInstance)) && !ModelData.cabinet?(item) }
        @ip.pick(view,x,y); @point=@ip.position if @ip.valid?
        rebuild_preview
        view.invalidate
      end
      def onKeyDown(key,repeat,flags,view)
        if Keys.tab?(key); @axis=(@axis+1)%3; rebuild_preview; view.invalidate; else; super; end
      end
      def rebuild_preview
        @preview=Preview.new
        return unless @target && @point
        b=@target.definition.bounds; p=@point.transform(@target.transformation.inverse); coordinate=[p.x,p.y,p.z][@axis]
        pts=case @axis
        when 0 then [[coordinate,b.min.y,b.min.z],[coordinate,b.max.y,b.min.z],[coordinate,b.max.y,b.max.z],[coordinate,b.min.y,b.max.z]]
        when 1 then [[b.min.x,coordinate,b.min.z],[b.max.x,coordinate,b.min.z],[b.max.x,coordinate,b.max.z],[b.min.x,coordinate,b.max.z]]
        else [[b.min.x,b.min.y,coordinate],[b.max.x,b.min.y,coordinate],[b.max.x,b.max.y,coordinate],[b.min.x,b.max.y,coordinate]]
        end
        transform=@target.transformation
        @preview.add_polygon(pts.map { |point| Geom::Point3d.new(point).transform(transform) },:cutter)
      end
      def ready?
        !(@target.nil? || @point.nil?)
      end

      def pending?
        !(@target.nil? && @point.nil?)
      end

      def clear_pending!
        @target = nil
        @point = nil
      end

      def commit(view)
        raise 'Chọn một cấu kiện và điểm cắt.' unless @target && @point
        operation('Cắt ván') { Operations.cut([@target],@settings,[[@target,@point]],@axis) }
        clear_pending!; rebuild_preview; view.invalidate; Dialog.set_status('Đã cắt cấu kiện. Chọn tấm và điểm cắt tiếp, hoặc Esc thoát.')
      rescue StandardError=>e
        Dialog.set_status(e.message)
      end
    end

    class NotchTool < Base
      def initialize(settings = {}); super; @tool_name='notch'; @targets=[]; @cutters=[]; end
      def hint; 'Click chọn tấm đích · Shift-click chọn dao cắt · Enter khấu · Esc hủy'; end
      def onLButtonDown(flags,x,y,view)
        return if click_finish?(view,x,y)
        path=picked_path(view,x,y)
        entity=path.reverse.find { |item| (item.is_a?(Sketchup::Group) || item.is_a?(Sketchup::ComponentInstance)) && !ModelData.cabinet?(item) }
        return unless entity && entity.valid?
        if Keys.shift?(flags); @cutters << entity unless @cutters.include?(entity); else; @targets << entity unless @targets.include?(entity); end
        box=entity.bounds; corners=(0..7).map { |i| box.corner(i) }
        faces=[[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]
        faces.each { |ids| @preview.add_polygon(ids.map { |i| corners[i] },Keys.shift?(flags) ? :cutter : :target) }
        Dialog.set_status("Đích #{@targets.length} · dao cắt #{@cutters.length}.")
        view.invalidate
      end
      def ready?
        !@targets.empty? && !@cutters.empty?
      end

      def pending?
        !(@targets.empty? && @cutters.empty?)
      end

      def clear_pending!
        @targets = []
        @cutters = []
        @preview = Preview.new
      end

      def commit(view)
        raise 'Chọn tấm đích và dao cắt bằng Shift-click.' if @targets.empty? || @cutters.empty?
        operation('Khấu ván') { Operations.notch(@targets,@cutters) }
        clear_pending!; view.invalidate; Dialog.set_status('Đã khấu các tấm đích. Chọn tiếp hoặc Esc thoát.')
      rescue StandardError=>e
        Dialog.set_status(e.message)
      end
    end

    def label(name); Schema::TOOLS.fetch(name.to_s, name.to_s); end

    # Đang mở (double-click) vào bên trong một tủ: thoát ra ngoài tủ và chọn tủ đó, để Box → Board mở Sửa tủ.
    def leave_cabinet_context
      model = Sketchup.active_model
      return unless model.respond_to?(:active_path) && model.respond_to?(:close_active)
      path = model.active_path || []
      cabinet = path.reverse.find { |entity| ModelData.cabinet?(entity) }
      return unless cabinet
      (path.length - path.index(cabinet)).times { model.close_active }
      model.selection.clear
      model.selection.add(cabinet)
    rescue StandardError
      nil
    end
    def build(name, settings = {})
      name = name.to_s
      case name
      when 'box'
        leave_cabinet_context
        selection = Sketchup.active_model.selection
        if FaceBoardTool.faces_only?(selection) then FaceBoardTool.new(settings)
        elsif EditCabinetTool.cabinets_only?(selection) then EditCabinetTool.new(settings)
        else BoxTool.new(settings)
        end
      when 'panel' then PanelTool.new(settings)
      when 'door' then DoorTool.new(settings)
      when 'drawer' then DrawerTool.new(settings)
      when 'opening' then OpeningTool.new(settings)
      when 'cut' then CutTool.new(settings)
      when 'notch' then NotchTool.new(settings)
      else SelectAndApplyTool.new(name, settings)
      end
    end
  end

  module Operations
    extend self
    def shell_for(root); Geometry.shell_for(root) || root; end

    def solid_box(entities,name,x0,x1,y0,y1,z0,z1)
      raise 'Kích thước cấu kiện phải dương.' unless x1>x0 && y1>y0 && z1>z0
      g=entities.add_group; g.name=name
      face=g.entities.add_face([[x0,y0,z0],[x1,y0,z0],[x1,y1,z0],[x0,y1,z0]])
      raise 'Không dựng được khối.' unless face
      face.reverse! if face.normal.z<0
      face.pushpull(z1-z0)
      g
    end

    DRAWER_CONTAINER = 'Ngăn kéo'.freeze
    SLIDE_LENGTHS_MM = [250, 300, 350, 400, 450, 500, 550, 600].freeze
    UNDERMOUNT_DEDUCT_MM = 42.0   # ray âm (kiểu Blum Tandem): lòng thùng = lòng ô − 42 mm
    UNDERMOUNT_BOTTOM_MM = 13.0   # ray âm: đáy thùng nâng lên khỏi mép dưới hông thùng

    # Kế hoạch ngăn kéo cho một ô của tủ (không chạm model): preview và dựng thật dùng chung.
    # local: điểm (hệ thùng tủ) để chọn ô; nil = cả lòng tủ.
    # Trả về { cell, fit, fronts: [{x0,x1,z0,z1,y}], boxes: [[[tên, vai trò, x0,x1,y0,y1,z0,z1], ...]], depth_mm, slide }.
    def drawer_plan(root, shell, settings, local = nil, bay = nil)
      mm = ->(key, default) { (settings[key].nil? ? default : settings[key]).to_f.mm }
      cell = local ? Interior.cell_at(shell, local.x, local.z) : Interior.inner(shell)
      cell = bay[:cell] if bay
      body = Geometry.body_bounds(shell)
      fit = settings['drawer_fit'].to_s
      fit = Interior.door_fit(root) || 'phu' unless %w[phu lot thong_thuy].include?(fit)
      fit = 'lot' if bay
      mode = settings.fetch('drawer_mode', 'full').to_s
      count = [[settings.fetch('drawer_count', 2).to_i, 1].max, 20].min
      gap = mm.call('drawer_gap', 0)
      ft = mm.call('board_thickness', 17.5)
      cover = ->(side) { Interior.front_cover(side, fit, mm.call('door_edge_gap', 0), gap, mm.call('door_inset_gap', 2)) }
      ax0 = cell.x0 - cover.call(cell.left)
      ax1 = cell.x1 + cover.call(cell.right)
      az0 = cell.z0 - cover.call(cell.bottom)
      az1 = cell.z1 + cover.call(cell.top)
      span = az1 - az0
      raise 'Ô quá hẹp để đặt ngăn kéo.' if ax1 - ax0 < 100.mm || span < 60.mm
      height = mm.call('drawer_front_height', 0)
      if height <= 0
        height = (span - gap * (count - 1)) / count
      elsif height * count + gap * (count - 1) > span + 0.01.mm
        raise format('Không đủ cao: %d hộc × %.0f mm + khe vượt chiều cao ô %.0f mm. Giảm số hộc hoặc để Cao mặt hộc = 0 (chia đều).', count, height.to_mm, span.to_mm)
      end
      raise 'Mặt hộc quá thấp (dưới 60 mm). Giảm số hộc.' if height < 60.mm
      # Tủ đã lùi thùng theo cánh (door_recess): mặt ngoài mặt hộc trùm mặt trước box, mặt sau ở y = dày.
      recessed = !Rebuild.settings_of(root)['door_recess'].nil?
      y_front = recessed ? ft : (fit == 'phu' ? body.min.y : body.min.y + ft)
      y_front = bay[:y_front] if bay
      fronts = (0...count).map do |i|
        z0 = az0 + i * (height + gap)
        { x0: ax0, x1: ax1, z0: z0, z1: z0 + height, y: y_front, index: i }
      end
      slide = settings.fetch('drawer_slide', 'side').to_s == 'under' ? 'under' : 'side'
      st = settings['drawer_box_thickness'] ? mm.call('drawer_box_thickness', 15) : ft
      bt = mm.call('drawer_bottom_thickness', 8)
      by0 = recessed ? ft : (fit == 'phu' ? body.min.y : body.min.y + ft)
      by0 = bay[:y_front] if bay
      avail = Interior.back_limit(shell, cell.z0, cell.z0 + 1.mm) - by0 - mm.call('drawer_back_clearance', 10)
      custom = mm.call('drawer_depth', 0)
      depth = if custom > 0
                raise format('Thùng sâu %.0f mm vượt chỗ trống %.0f mm.', custom.to_mm, avail.to_mm) if custom > avail + 0.01.mm
                custom
              else
                best = SLIDE_LENGTHS_MM.select { |n| n.mm <= avail + 0.01.mm }.max
                best ? best.mm : (avail.to_mm / 10).floor * 10.0.mm
              end
      raise format('Tủ quá nông cho thùng ngăn kéo (còn %.0f mm).', avail.to_mm) if depth < 150.mm
      if slide == 'under'
        outer = cell.width - UNDERMOUNT_DEDUCT_MM.mm + 2 * st
        bx0 = (cell.x0 + cell.x1) / 2 - outer / 2
        bx1 = bx0 + outer
      else
        ray = mm.call('drawer_ray_space', 13)
        bx0 = cell.x0 + ray
        bx1 = cell.x1 - ray
      end
      raise 'Ô quá hẹp cho thùng ngăn kéo.' if bx1 - bx0 < 2 * st + 50.mm
      lift = [mm.call('drawer_box_bottom_lift', 10), slide == 'under' ? 14.mm : 0].max
      top_gap = mm.call('drawer_box_top_clearance', 13)
      boxes = []
      unless mode == 'front_only'
        fronts.each do |front|
          z0 = [front[:z0], cell.z0].max + lift
          top = [front[:z1], cell.z1].min - top_gap
          raise format('Thùng hộc %d quá thấp (%.0f mm).', front[:index] + 1, (top - z0).to_mm) if top - z0 < 40.mm
          # Thùng nằm cùng độ cao giằng sau (tủ bếp dưới) thì ngắn lại cho vừa.
          room = Interior.back_limit(shell, z0, top) - by0 - mm.call('drawer_back_clearance', 10)
          box_depth = depth
          if room + 0.01.mm < depth
            standard = SLIDE_LENGTHS_MM.select { |n| n.mm <= room + 0.01.mm }.max
            box_depth = custom > 0 || standard.nil? ? (room.to_mm / 10).floor * 10.0.mm : standard.mm
          end
          raise format('Thùng hộc %d không đủ sâu (còn %.0f mm).', front[:index] + 1, room.to_mm) if box_depth < 150.mm
          y1 = by0 + box_depth
          parts = DrawerParts.parts(slide: slide, bottom: settings['drawer_bottom_type'], x0: bx0, x1: bx1, y0: by0, y1: y1, z0: z0, top: top,
                                    side: st, bottom_t: bt, lift: UNDERMOUNT_BOTTOM_MM.mm,
                                    groove_depth: mm.call('drawer_groove_depth', 8), groove_height: mm.call('drawer_groove_height', 10))
          boxes << parts
        end
      end
      { cell: cell, fit: fit, fronts: mode == 'box_only' ? [] : fronts, all_fronts: fronts, boxes: boxes,
        depth_mm: depth.to_mm, slide: slide, front_height_mm: height.to_mm, bottom: DrawerParts.bottom_type(settings['drawer_bottom_type']) }
    end

    def drawer_container(root, shell)
      found = root.definition.entities.to_a.find { |e| e.is_a?(Sketchup::Group) && e.name == DRAWER_CONTAINER }
      found.make_unique if found && found.respond_to?(:make_unique)
      return found if found
      group = root.definition.entities.add_group
      group.name = DRAWER_CONTAINER
      group.transformation = shell.transformation
      group.layer = ensure_tag(Schema::DEFAULTS['cabinet_tag']) if group.respond_to?(:layer=)
      group
    end

    # Dựng ngăn kéo cho một ô. Mặt hộc dùng chung kiểu cánh (phẳng/shaker...) với cánh tủ.
    # op_id: khi dựng lại (Sửa tủ) truyền số bước có sẵn; tạo mới thì ghi một bước mới.
    def build_drawers(root, settings, local = nil, op_id = nil, bay = nil)
      root.make_unique if root.respond_to?(:make_unique)
      shell = shell_for(root)
      plan = drawer_plan(root, shell, settings, local, bay)
      op_id ||= Rebuild.record(root, { 'type' => 'drawer', 'anchor' => local ? Rebuild.anchor_of(shell, local.x, local.z) : nil,
                                       'settings' => settings.select { |key, _| Rebuild::DRAWER_KEYS.include?(key) } })
      container = drawer_container(root, shell)
      start = container.entities.to_a.count { |e| e.respond_to?(:name) && e.name == 'Mặt Ngăn Kéo' }
      plan[:fronts].each do |front|
        group = DoorGeometry.build(container.entities, front, 'Mặt Ngăn Kéo', settings)
        ModelData.stamp(group, 'drawer_front', { 'height_mm' => (front[:z1] - front[:z0]).to_mm, 'width_mm' => (front[:x1] - front[:x0]).to_mm,
                                                 'fit' => plan[:fit], 'gap_mm' => settings.fetch('drawer_gap', 0).to_f,
                                                 'slide_max_mm' => [plan[:depth_mm] - DrawerSlide::RESERVE_MM, 0.0].max })
        group.set_attribute(Schema::DICTIONARY, 'part_index', start + front[:index] + 1)
        group.set_attribute(Schema::DICTIONARY, 'opening_type', 'drawer')
        group.set_attribute(Schema::DICTIONARY, 'opening_kind', 'drawer')
        group.set_attribute(Schema::DICTIONARY, 'op', op_id)
        group.set_attribute(Schema::DICTIONARY, 'op_index', front[:index])
      end
      plan[:boxes].each_with_index do |parts, index|
        box = container.entities.add_group
        box.name = 'Thùng Ngăn Kéo'
        parts.each do |name, role, x0, x1, y0, y1, z0, z1|
          Geometry.stamp_part(solid_box(box.entities, name, x0, x1, y0, y1, z0, z1), role, { 'thickness_mm' => [x1 - x0, y1 - y0, z1 - z0].min.to_mm })
        end
        ModelData.stamp(box, 'drawer_box', { 'depth_mm' => plan[:depth_mm], 'slide' => plan[:slide], 'fit' => plan[:fit], 'bottom' => plan[:bottom],
                                             'slide_max_mm' => [plan[:depth_mm] - DrawerSlide::RESERVE_MM, 0.0].max })
        box.set_attribute(Schema::DICTIONARY, 'part_index', start + index + 1)
        box.set_attribute(Schema::DICTIONARY, 'op', op_id)
        box.set_attribute(Schema::DICTIONARY, 'op_index', index)
      end
      Geometry.share_components(root)
      plan
    end

    # Giữ tương thích: mỗi tủ dựng ngăn kéo trong ô chứa điểm click đầu tiên (hoặc cả lòng tủ).
    def drawers(targets, settings, points)
      targets.each do |root|
        shell = shell_for(root)
        click = points.find { |item| item[0] == root }
        local = click && click[1].transform(Operations.world_transform(root, shell).inverse)
        build_drawers(root, settings, local)
      end
    end

    # Ô của tủ chứa điểm click (hệ thùng tủ), hoặc cả lòng tủ nếu không click.
    def cell_for_click(root, shell, points)
      click = points.find { |item| item[0] == root }
      return [Interior.inner(shell), nil] unless click
      local = click[1].transform(Operations.world_transform(root, shell).inverse)
      [Interior.cell_at(shell, local.x, local.z), local]
    end

    def part_box(entities, name, role, x0, x1, y0, y1, z0, z1)
      Geometry.stamp_part(solid_box(entities, name, x0, x1, y0, y1, z0, z1), role, { 'thickness_mm' => [x1 - x0, y1 - y0, z1 - z0].min.to_mm })
    end

    def local_clicks(root, shell, points)
      inverse = Operations.world_transform(root, shell).inverse
      points.select { |item| item[0] == root }.map { |item| item[1].transform(inverse) }
    end

    def record_extra(root, shell, type, settings, locals)
      Rebuild.record(root, { 'type' => type, 'points' => locals.map { |p| Rebuild.anchor_of(shell, p.x, p.z) },
                             'settings' => settings.select { |key, _| Rebuild::BLOCKER_KEYS.include?(key) } })
    end

    # Hộc tủ áo: nằm TRONG ô (giữa hông/vách, trên đáy/đợt), sâu từ mặt trước tới mặt trước tấm hậu.
    def wardrobe(targets, settings, points)
      targets.each do |root|
        root.make_unique if root.respond_to?(:make_unique)
        shell = shell_for(root)
        shell.make_unique if shell.respond_to?(:make_unique)
        locals = local_clicks(root, shell, points)
        op = record_extra(root, shell, 'wardrobe', settings, locals)
        place_wardrobe(root, shell, settings, locals, op)
        Geometry.share_components(root)
      end
    end

    def place_wardrobe(root, shell, settings, clicks, op = nil)
      cell = clicks.first ? Interior.cell_at(shell, clicks.first.x, clicks.first.z) : Interior.inner(shell)
      x0, x1 = clicks.length >= 2 ? [clicks[0].x, clicks[1].x].minmax : [cell.x0, cell.x1]
      x0 = [[x0, cell.x0].max, cell.x1].min
      x1 = [[x1, cell.x0].max, cell.x1].min
      z0 = clicks.first ? clicks.first.z : cell.z0
      z1 = clicks[1] ? clicks[1].z : z0 + settings.fetch('compartment_height', 400).to_f.mm
      z0, z1 = [z0, z1].minmax
      z0 = [z0, cell.z0].max
      z1 = [z1, cell.z1].min
      t = settings.fetch('board_thickness', 17.5).to_f.mm
      raise 'Khoang tủ áo quá nhỏ.' if x1 - x0 < 2 * t + 50.mm || z1 - z0 < 2 * t + 50.mm
      y0 = cell.y0
      y1 = Interior.back_limit(shell, z0, z1)
      g = shell.definition.entities.add_group
      g.name = 'Hộc Tủ Áo'
      part_box(g.entities, 'Đáy Hộc', 'wardrobe_bottom', x0, x1, y0, y1, z0, z0 + t)
      part_box(g.entities, 'Nóc Hộc', 'wardrobe_top', x0, x1, y0, y1, z1 - t, z1)
      part_box(g.entities, 'Hông Hộc Trái', 'wardrobe_side', x0, x0 + t, y0, y1, z0 + t, z1 - t) if x0 > cell.x0 + 0.5.mm
      part_box(g.entities, 'Hông Hộc Phải', 'wardrobe_side', x1 - t, x1, y0, y1, z0 + t, z1 - t) if x1 < cell.x1 - 0.5.mm
      ModelData.stamp(g, 'wardrobe_compartment', { 'width_mm' => (x1 - x0).to_mm, 'height_mm' => (z1 - z0).to_mm, 'op' => op })
      g
    end

    # Xà chặn: chạy giữa hai hông (hoặc hông/vách của ô), sâu từ mặt trước tới mặt trước tấm hậu.
    def blockers(targets, settings, points)
      targets.each do |root|
        root.make_unique if root.respond_to?(:make_unique)
        shell = shell_for(root)
        shell.make_unique if shell.respond_to?(:make_unique)
        locals = local_clicks(root, shell, points).first(1)
        op = record_extra(root, shell, 'blocker', settings, locals)
        place_blocker(root, shell, settings, locals.first, op)
        Geometry.share_components(root)
      end
    end

    def place_blocker(root, shell, settings, local, op = nil)
      cell = local ? Interior.cell_at(shell, local.x, local.z) : Interior.inner(shell)
      t = settings.fetch('board_thickness', 17.5).to_f.mm
      h = settings.fetch('blocker_height', 60).to_f.mm
      z = local ? local.z : cell.z0 + cell.height * 0.7
      z = [[z, cell.z0].max, cell.z1 - h].min
      x0 = cell.x0
      x1 = cell.x1
      y0 = cell.y0
      y1 = Interior.back_limit(shell, z, z + h)
      raise 'Ô quá nhỏ cho xà chặn.' if x1 - x0 < 50.mm || y1 - y0 < 3 * t
      profile = settings.fetch('blocker_profile', 'C')
      g = shell.definition.entities.add_group
      g.name = "Xà Chặn #{profile}"
      case profile
      when 'I'
        part_box(g.entities, 'Bản trước', 'blocker', x0, x1, y0, y0 + t, z, z + h)
        part_box(g.entities, 'Bản sau', 'blocker', x0, x1, y1 - t, y1, z, z + h)
        part_box(g.entities, 'Lõi', 'blocker', x0, x1, y0 + t, y1 - t, z + h / 2 - t / 2, z + h / 2 + t / 2)
      when 'L'
        part_box(g.entities, 'Mặt đứng', 'blocker', x0, x1, y0, y0 + t, z, z + h)
        part_box(g.entities, 'Cánh ngang', 'blocker', x0, x1, y0 + t, y1, z, z + t)
      else
        part_box(g.entities, 'Mặt trước', 'blocker', x0, x1, y0, y0 + t, z, z + h - t)
        part_box(g.entities, 'Mặt sau', 'blocker', x0, x1, y1 - t, y1, z, z + h - t)
        part_box(g.entities, 'Mặt nối', 'blocker', x0, x1, y0, y1, z + h - t, z + h)
      end
      ModelData.stamp(g, 'blocker', { 'profile' => profile, 'height_mm' => h.to_mm, 'op' => op })
      g
    end

    HANDLE_NAME = 'Tay Nắm'.freeze

    # Tay nắm: gắn SÁT mặt trước cánh/mặt hộc (không lơ lửng). Không click = tự đặt theo hướng mở:
    #   bản lề trái -> tay nắm dọc gần mép phải, bản lề phải -> gần mép trái (cách mép handle_edge_offset);
    #   lật lên -> ngang gần mép dưới; lật xuống -> ngang gần mép trên; ngăn kéo -> ngang ở giữa.
    #   Chiều cao (cánh mở ngang): tủ trên (đáy cánh cao hơn 1200 mm) -> gần mép dưới; cánh cao (>1200 mm) -> tâm
    #   tay nắm ở cao 1000 mm so với sàn; tủ dưới -> gần mép trên.
    # Click lên cánh = đặt tại điểm click (tự đặt thay thế tay nắm tự đặt cũ, click thì thêm tay nắm).
    def handles(targets, settings, points)
      targets.each do |door|
        next unless door.valid?
        door.make_unique if door.respond_to?(:make_unique)
        # Mặc định tự đặt theo hướng mở; chỉ khi chọn "Tại điểm click" mới đặt đúng chỗ click.
        click = settings.fetch('handle_position', 'auto') == 'custom' ? points.find { |item| item[0] == door } : nil
        spec = handle_spec_for(door, settings, click && click[1])
        next unless spec
        handle_groups(door).each { |g| g.erase! if ModelData.params(g)['position'] == 'auto' } if spec['position'] == 'auto'
        add_handle(door, spec)
      end
    end

    def handle_groups(door)
      door.definition.entities.to_a.select { |e| e.is_a?(Sketchup::Group) && e.valid? && e.name == HANDLE_NAME }
    end

    def handle_specs(door)
      handle_groups(door).map { |g| ModelData.params(g) }.select { |spec| spec['u'] && spec['v'] }
    end

    # Phép biến đổi từ hệ cánh ra hệ thế giới (gồm các group cha).
    def door_world(door)
      (parent_transform(door) || Geom::Transformation.new) * door.transformation
    end

    def handle_spec_for(door, settings, world_point)
      b = door_bounds(door)
      return nil unless b
      width = b[3] - b[0]
      height = b[5] - b[2]
      return nil unless width > 0 && height > 0
      length = settings.fetch('handle_width', 128).to_f.mm
      edge = settings.fetch('handle_edge_offset', 50).to_f.mm
      type = opening_type_of(door)
      type = 'drawer' if door.get_attribute(Schema::DICTIONARY, 'kind') == 'drawer_front' || door.name.to_s.start_with?('Mặt Ngăn Kéo')
      orientation = %w[left right none].include?(type) ? 'vertical' : 'horizontal'
      spec = { 'profile' => settings.fetch('handle_profile', 'bar').to_s, 'length_mm' => length.to_mm,
               'projection_mm' => settings.fetch('handle_projection', 30).to_f, 'orientation' => orientation }
      if world_point
        local = world_point.transform(door_world(door).inverse)
        return spec.merge('position' => 'custom', 'u' => ((local.x - b[0]) / width).clamp(0.0, 1.0), 'v' => ((local.z - b[2]) / height).clamp(0.0, 1.0))
      end
      half = (orientation == 'vertical' ? [length, height].min : [length, width].min) / 2.0
      # Neo: tay nắm cách mép đã chọn một khoảng mm cố định, nên cánh đổi kích thước thì tay nắm vẫn ở đúng chỗ.
      ax, dx = case type
               when 'right' then ['left', edge]
               when 'left', 'none' then ['right', edge]
               else ['center', 0.0]
               end
      az, dz = case type
               when 'top' then ['bottom', edge]
               when 'bottom' then ['top', edge]
               when 'drawer' then ['center', 0.0]
               else vertical_handle_anchor(door, b, edge, half)
               end
      anchored = spec.merge('position' => 'auto', 'ax' => ax, 'dx_mm' => dx.to_mm, 'az' => az, 'dz_mm' => dz.to_mm)
      # u/v (tỷ lệ) vẫn lưu để các đoạn mã cũ đọc được tay nắm; vị trí thật lấy theo neo.
      anchored.merge('u' => (handle_center(anchored, 'x', b[0], b[3]) - b[0]) / width,
                     'v' => (handle_center(anchored, 'z', b[2], b[5]) - b[2]) / height)
    end

    # Neo theo chiều đứng cho tay nắm đặt tự động: [mép, khoảng cách tới mép] (inch).
    def vertical_handle_anchor(door, b, edge, half)
      world = door_world(door)
      wz0 = Geom::Point3d.new(b[0], b[1], b[2]).transform(world).z
      wz1 = Geom::Point3d.new(b[0], b[1], b[5]).transform(world).z
      low = b[2] + edge + half
      high = b[5] - edge - half
      return ['center', 0.0] if low > high
      if [wz0, wz1].min > 1200.mm then ['bottom', low - b[2]]
      elsif (wz1 - wz0).abs > 1200.mm then ['bottom', (b[2] + (1000.mm - [wz0, wz1].min)).clamp(low, high) - b[2]]
      else ['top', b[5] - high]
      end
    end

    # Vị trí tâm tay nắm theo neo (mm cách mép đã chọn). Spec cũ chỉ có u/v (tỷ lệ) thì dùng tỷ lệ.
    def handle_center(spec, axis, low, high)
      anchor = spec["a#{axis}"]
      return low + spec[axis == 'x' ? 'u' : 'v'].to_f * (high - low) if anchor.nil?
      offset = spec["d#{axis}_mm"].to_f.mm
      case anchor
      when 'left', 'bottom' then low + offset
      when 'right', 'top' then high - offset
      else (low + high) / 2.0
      end
    end

    # Dựng tay nắm từ thông số (dùng cả khi dựng lại cánh). Thanh: 2 chân + thân, nhô ra handle_projection.
    def add_handle(door, spec)
      b = door_bounds(door)
      return nil unless b
      cx = handle_center(spec, 'x', b[0], b[3])
      cz = handle_center(spec, 'z', b[2], b[5])
      face = b[1]
      out = [spec['projection_mm'].to_f, 12.0].max.mm
      group = door.definition.entities.add_group
      group.name = HANDLE_NAME
      if spec['profile'] == 'knob'
        radius = 12.5.mm
        ring = (0...16).map { |i| a = Math::PI * 2 * i / 16; [cx + radius * Math.cos(a), face, cz + radius * Math.sin(a)] }
        knob = group.entities.add_group
        knob.name = 'Núm'
        f = knob.entities.add_face(ring)
        f.reverse! if f.normal.y > 0
        f.pushpull(out)
      else
        bar = 10.mm
        half = [spec['length_mm'].to_f.mm, spec['orientation'] == 'vertical' ? b[5] - b[2] : b[3] - b[0]].min / 2.0
        if spec['orientation'] == 'vertical'
          solid_box(group.entities, 'Thân', cx - bar / 2, cx + bar / 2, face - out, face - out + bar, cz - half, cz + half)
          solid_box(group.entities, 'Chân 1', cx - bar / 2, cx + bar / 2, face - out + bar, face, cz - half, cz - half + bar)
          solid_box(group.entities, 'Chân 2', cx - bar / 2, cx + bar / 2, face - out + bar, face, cz + half - bar, cz + half)
        else
          solid_box(group.entities, 'Thân', cx - half, cx + half, face - out, face - out + bar, cz - bar / 2, cz + bar / 2)
          solid_box(group.entities, 'Chân 1', cx - half, cx - half + bar, face - out + bar, face, cz - bar / 2, cz + bar / 2)
          solid_box(group.entities, 'Chân 2', cx + half - bar, cx + half, face - out + bar, face, cz - bar / 2, cz + bar / 2)
        end
      end
      ModelData.stamp(group, 'handle', spec)
      group.layer = ensure_tag(Schema::DEFAULTS['part_tag']) if group.respond_to?(:layer=)
      group
    end

    DOOR_CONTAINER = 'Cánh'.freeze
    MARKER_NAME = 'Ký Hiệu Hướng Mở'.freeze

    def door?(entity)
      (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)) && entity.name.to_s.start_with?('Cánh Draw')
    end

    # Group 'Cánh' nằm trong tủ, cùng hệ trục với thùng tủ (các cánh bên trong dùng tọa độ thùng tủ).
    def door_container(root, shell)
      found = root.definition.entities.to_a.find { |e| e.is_a?(Sketchup::Group) && e.name == DOOR_CONTAINER }
      # Tủ copy dùng chung định nghĩa: tách riêng nhóm Cánh trước khi sửa để không đổi lây sang bản copy.
      found.make_unique if found && found.respond_to?(:make_unique)
      return found if found
      group = root.definition.entities.add_group
      group.name = DOOR_CONTAINER
      group.transformation = shell.transformation
      group.layer = ensure_tag(Schema::DEFAULTS['cabinet_tag']) if group.respond_to?(:layer=)
      group
    end

    # Xóa mọi cánh cũ: nằm trong group 'Cánh', hoặc nằm lẻ trực tiếp trong tủ (bản cũ).
    def door_container_clear(root)
      entities = root.definition.entities
      entities.to_a.select { |e| door?(e) }.each(&:erase!)
      container = entities.to_a.find { |e| e.is_a?(Sketchup::Group) && e.valid? && e.name == DOOR_CONTAINER }
      container.make_unique if container && container.respond_to?(:make_unique)
      container.entities.to_a.select { |e| door?(e) }.each(&:erase!) if container
    end

    # Các cánh của một tủ (cả hai cách lưu).
    def doors_of(root)
      entities = root.definition.entities.to_a
      container = entities.find { |e| e.is_a?(Sketchup::Group) && e.name == DOOR_CONTAINER }
      list = entities.select { |e| door?(e) }
      list += container.entities.to_a.select { |e| door?(e) } if container
      list
    end

    # Phép biến đổi từ hệ tủ (root, và thân tủ nếu có) ra hệ thế giới, TÍNH CẢ group cha của tủ.
    # Điểm click/rê chuột là tọa độ thế giới nên mọi phép đổi ngược phải đi qua hàm này.
    def world_transform(root, shell = nil)
      parent = root.parent.is_a?(Sketchup::Model) ? nil : parent_transform(root)
      tr = parent ? parent * root.transformation : root.transformation
      shell ? tr * shell.transformation : tr
    end

    # Phép biến đổi của mọi group cha của một đối tượng (tìm từ gốc model), hoặc nil nếu không thấy.
    def parent_transform(entity, entities = Sketchup.active_model.entities, acc = Geom::Transformation.new, depth = 0)
      return nil if depth > 8
      entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        return acc if e == entity
        found = parent_transform(entity, e.definition.entities, acc * e.transformation, depth + 1)
        return found if found
      end
      nil
    end

    # Hộp bao [x0,y0,z0,x1,y1,z1] của thân cánh, KHÔNG tính ký hiệu mở và tay nắm
    # (nếu tính tay nắm thì trục bản lề bị dời ra trước, cánh xoay sai).
    def door_bounds(door)
      mins = [nil, nil, nil]
      maxs = [nil, nil, nil]
      door.definition.entities.each do |e|
        next if e.respond_to?(:name) && (e.name == MARKER_NAME || e.name == HANDLE_NAME)
        next unless e.respond_to?(:bounds)
        lo = e.bounds.min.to_a
        hi = e.bounds.max.to_a
        3.times do |i|
          mins[i] = lo[i] if mins[i].nil? || lo[i] < mins[i]
          maxs[i] = hi[i] if maxs[i].nil? || hi[i] > maxs[i]
        end
      end
      return nil if mins.any?(&:nil?)
      mins + maxs
    end

    # Ký hiệu mở cánh theo quy ước bản vẽ: hình tam giác nét đứt nằm trên mặt trước của cánh,
    # đỉnh ở cạnh bản lề (giữa chiều cao), hai cạnh đi về hai góc đối diện (phía tay nắm).
    def opening_marker(door, side)
      door.make_unique if door.respond_to?(:make_unique)
      old = door.definition.entities.to_a.find { |e| e.is_a?(Sketchup::Group) && e.name == MARKER_NAME }
      old.erase! if old && old.valid?
      b = door_bounds(door)
      return nil unless b
      y = b[1] - 0.5.mm
      if side == 'top' || side == 'bottom'
        # Bản lề ngang (cánh lật): đỉnh ở cạnh bản lề giữa bề rộng, hai cạnh đi về hai góc đối diện.
        hinge_z = side == 'top' ? b[5] : b[2]
        free_z = side == 'top' ? b[2] : b[5]
        apex = [(b[0] + b[3]) / 2.0, y, hinge_z]
        corners = [[b[0], y, free_z], [b[3], y, free_z]]
      else
        hinge_x = side == 'left' ? b[0] : b[3]
        free_x = side == 'left' ? b[3] : b[0]
        apex = [hinge_x, y, (b[2] + b[5]) / 2.0]
        corners = [[free_x, y, b[5]], [free_x, y, b[2]]]
      end
      marker = door.definition.entities.add_group
      marker.name = MARKER_NAME
      marker.layer = ensure_tag(Schema::DEFAULTS['opening_tag'])
      corners.each do |corner|
        dashed_line(marker.entities, apex, corner, 28.mm, 16.mm)
      end
      marker.set_attribute(Schema::DICTIONARY, 'kind', 'opening_symbol')
      marker.set_attribute(Schema::DICTIONARY, 'opening_side', side)
      door.set_attribute(Schema::DICTIONARY, 'opening_side', side)
      marker
    end

    HINGE_SIDES = %w[left right top bottom].freeze

    # Ghi loại mở vào cánh (dữ liệu gốc) rồi vẽ ký hiệu từ dữ liệu đó. Cánh vẫn ở trạng thái đóng.
    # none = chưa đặt; left/right/top/bottom = bản lề; drawer = ngăn kéo (chỉ lưu dữ liệu).
    def apply_opening_metadata(door, type)
      type = DoorLayout.opening_type(type)
      door.set_attribute(Schema::DICTIONARY, 'opening_type', type)
      if HINGE_SIDES.include?(type)
        door.set_attribute(Schema::DICTIONARY, 'opening_kind', 'hinged')
        opening_marker(door, type)
      elsif type == 'drawer'
        door.set_attribute(Schema::DICTIONARY, 'opening_kind', 'drawer')
      end
      door
    end

    # Loại mở hiện tại của cánh (đọc cả dữ liệu bản cũ chỉ có opening_side).
    def opening_type_of(door)
      type = door.get_attribute(Schema::DICTIONARY, 'opening_type')
      type = door.get_attribute(Schema::DICTIONARY, 'opening_side') if type.nil? || type == 'none'
      DoorLayout.opening_type(type)
    end

    # Tìm tủ chứa cánh này (quét từ gốc model).
    def cabinet_of(door, entities = Sketchup.active_model.entities, depth = 0)
      return nil if depth > 8
      entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        return e if ModelData.cabinet?(e) && doors_of(e).include?(door)
        found = cabinet_of(door, e.definition.entities, depth + 1)
        return found if found
      end
      nil
    end

    # Ghi loại mở của cánh ngược vào bố cục đã lưu trong tủ, để chia lại cánh sau này không mất.
    def save_opening_to_layout(door, type)
      root = cabinet_of(door)
      return nil unless root
      json = (JSON.parse(root.get_attribute(Schema::DICTIONARY, 'door_layout_json', '{}')) rescue {})
      return nil unless json.is_a?(Hash) && json['regions'].is_a?(Array)
      layout = DoorLayout::Layout.from_h(json)
      rid = door.get_attribute(Schema::DICTIONARY, 'region_id')
      region = rid && layout.find(rid.to_i)
      unless region
        index = door.get_attribute(Schema::DICTIONARY, 'part_index').to_i - 1
        region = layout.sorted[index] if index >= 0
      end
      return nil unless region
      layout.set_opening(region['id'], type)
      root.set_attribute(Schema::DICTIONARY, 'door_layout_json', JSON.generate(json.merge(layout.to_h)))
      region['id']
    end

    # Đóng mọi cánh đang mở của một tủ (cánh trở về đúng vị trí đóng).
    def close_doors(root)
      count = 0
      doors_of(root).each do |door|
        next unless door_angle(door) > 0.5
        side = door.get_attribute(Schema::DICTIONARY, 'opening_side', 'left')
        side = 'left' unless HINGE_SIDES.include?(side)
        set_door_angle(door, side, 0)
        count += 1
      end
      count
    end

    # Đường nét đứt bằng các đoạn thẳng ngắn (SketchUp không có nét đứt cho cạnh).
    def dashed_line(entities, p0, p1, dash, gap)
      dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
      length = Math.sqrt(dx * dx + dy * dy + dz * dz)
      return if length < 1e-6
      step = dash + gap
      pos = 0.0
      while pos < length
        e = [pos + dash, length].min
        entities.add_line(
          [p0[0] + dx * pos / length, p0[1] + dy * pos / length, p0[2] + dz * pos / length],
          [p0[0] + dx * e / length, p0[1] + dy * e / length, p0[2] + dz * e / length]
        )
        pos += step
      end
    end

    # Góc mở hiện tại của cánh (độ). Tương thích bản cũ chỉ lưu open_state.
    def door_angle(door)
      value = door.get_attribute(Schema::DICTIONARY, 'angle_deg')
      return value.to_f if value
      door.get_attribute(Schema::DICTIONARY, 'open_state') == 'open' ? 105.0 : 0.0
    end

    # Điểm nằm trên trục bản lề (hệ thế giới của group chứa cánh). Trái/phải: trục đứng; trên/dưới: trục ngang.
    def hinge_pivot(door, side)
      b = door_bounds(door)
      point = case side
              when 'right' then [b[3], b[1], b[2]]
              when 'top' then [b[0], b[1], b[5]]
              else [b[0], b[1], b[2]]
              end
      Geom::Point3d.new(*point).transform(door.transformation)
    end

    # Phép quay (trong hệ của group chứa cánh) để đưa cánh từ góc from sang góc to (độ, 0 = đóng).
    # Mở ra phía trước (-Y): bản lề trái và trên quay âm, bản lề phải và dưới quay dương.
    # Bản lề trên/dưới quay quanh trục X của cánh, bản lề trái/phải quanh trục Z.
    def rotation_between(door, side, from, to)
      sign = %w[left top].include?(side) ? -1.0 : 1.0
      horizontal = side == 'top' || side == 'bottom'
      axis = horizontal ? door.transformation.xaxis : door.transformation.zaxis
      Geom::Transformation.rotation(hinge_pivot(door, side), axis, sign * (to.to_f - from.to_f).degrees)
    end

    def set_door_angle(door, side, angle)
      angle = [[angle.to_f, 0.0].max, 135.0].min
      current = door_angle(door)
      door.transformation = rotation_between(door, side, current, angle) * door.transformation
      door.set_attribute(Schema::DICTIONARY, 'angle_deg', angle)
      door.set_attribute(Schema::DICTIONARY, 'open_state', angle > 0.5 ? 'open' : 'closed')
      door.set_attribute(Schema::DICTIONARY, 'opening_side', side)
      door.set_attribute(Schema::DICTIONARY, 'opening_type', side)
      door.set_attribute(Schema::DICTIONARY, 'opening_kind', 'hinged')
      door
    end

    def ensure_tag(name)
      model=Sketchup.active_model
      model.layers[name] || model.layers.add(name)
    end

    def require_solid!(group)
      raise 'Cấu kiện không phải solid/manifold; thao tác đã hủy an toàn.' unless group.respond_to?(:manifold?) && group.manifold?
    end

    def cut(targets,_settings,points,axis)
      targets.each do |target|
        require_solid!(target); click=points.find { |item| item[0]==target }; raise 'Chưa chọn điểm cắt.' unless click
        target.make_unique if target.respond_to?(:make_unique); b=target.definition.bounds; p=click[1].transform(target.transformation.inverse)
        i=axis.to_i; low=[b.min.x,b.min.y,b.min.z]; high=[b.max.x,b.max.y,b.max.z]; coordinate=[p.x,p.y,p.z][i]
        raise 'Mặt cắt phải nằm trong cấu kiện.' unless coordinate>low[i] && coordinate<high[i]
        ranges=[[b.min.x-1.mm,b.max.x+1.mm],[b.min.y-1.mm,b.max.y+1.mm],[b.min.z-1.mm,b.max.z+1.mm]]
        ranges[i]=[coordinate,high[i]+1.mm]
        cutter=target.parent.entities.add_group; cutter.name='Cutter'; cutter.transformation=target.transformation
        solid_box(cutter.entities,'Mặt Cắt',ranges[0][0],ranges[0][1],ranges[1][0],ranges[1][1],ranges[2][0],ranges[2][1])
        saved=ModelData.snapshot(target); name=target.name
        result=target.subtract(cutter); raise 'Cắt thất bại. Kiểm tra solid và điểm cắt.' unless result
        # Giữ vai trò/dữ liệu của tấm, đánh dấu đã chỉnh tay (Sửa tủ sẽ hỏi trước khi dựng lại).
        ModelData.restore(result,saved); result.name=name; result.set_attribute(Schema::DICTIONARY,'kind','part') unless saved.dig(Schema::DICTIONARY,'kind'); result.set_attribute(Schema::DICTIONARY,'notched',true)
      end
    end

    def round_edges(targets,settings,points)
      radius=settings.fetch('round_radius',3).to_f.mm; raise 'Bán kính phải lớn hơn 0.' unless radius>0
      targets.each do |target|
        require_solid!(target); item=points.find { |entry| entry[0]==target }; edge=item && item[2]
        raise 'Click trực tiếp vào cạnh cần bo.' unless edge && edge.faces.length==2
        a=edge.start.position; b=edge.end.position; axis=a.vector_to(b); length=axis.length; axis.normalize!
        n1,n2=edge.faces.map(&:normal); center=a.offset(axis,-radius).offset(n1,-radius).offset(n2,-radius)
        cutter=target.parent.entities.add_group; cutter.name='VGD Draw · Round'; cutter.transformation=target.transformation
        circle=cutter.entities.add_circle(center,axis,radius,24); circle.first.find_faces
        cap=cutter.entities.grep(Sketchup::Face).max_by(&:area); raise 'Không dựng được dao bo.' unless cap
        cap.pushpull(length+radius*2)
        saved=ModelData.snapshot(target); name=target.name
        result=target.subtract(cutter); raise 'Bo cạnh thất bại; cần solid manifold.' unless result
        ModelData.restore(result,saved); result.name=name; result.set_attribute(Schema::DICTIONARY,'notched',true)
      end
    end

    def notch(targets,cutters)
      targets.each do |target|
        current=target; require_solid!(current)
        cutters.each do |cutter|
          next if cutter==target
          require_solid!(cutter); saved=ModelData.snapshot(current); name=current.name; result=current.subtract(cutter)
          raise 'Khấu thất bại; dao cắt và tấm đích cần là solid manifold giao nhau.' unless result
          ModelData.restore(result,saved); result.name=name; result.set_attribute(Schema::DICTIONARY,'kind','part') unless saved.dig(Schema::DICTIONARY,'kind'); result.set_attribute(Schema::DICTIONARY,'notched',true); current=result
        end
      end
      cutters.each { |cutter| cutter.erase! if cutter.valid? }
    end
  end
end
