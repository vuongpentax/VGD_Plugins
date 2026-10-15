module VGD_Cabinet_Draw
  module Tools
    extend self

    class Base
      attr_reader :settings
      def initialize(settings = {})
        @settings = Schema::DEFAULTS.merge(settings || {})
        @preview = Preview.new
        @phase = :pick
        @ip = Sketchup::InputPoint.new
      end
      def update_settings(settings)
        @settings=Schema::DEFAULTS.merge(settings || {})
        rebuild_preview if respond_to?(:rebuild_preview)
        Sketchup.active_model.active_view.invalidate
      end
      def activate; Sketchup.active_model.active_view.invalidate; end
      def deactivate(view); view.invalidate if view; end
      def onCancel(_reason, view); view.invalidate if view; end
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
      end
      def hint; 'Click chọn · Enter áp dụng · Esc hủy'; end
      def onKeyDown(key, _repeat, _flags, view)
        if key == VK_ESCAPE
          view.model.select_tool(nil)
          Dialog.set_status('Đã hủy thao tác.')
        elsif key == VK_RETURN || key == VK_NUMPAD_ENTER
          commit(view)
        elsif key == VK_TAB
          if @tool_name == 'door'
            @settings['split_axis'] = @settings['split_axis'] == 'horizontal' ? 'vertical' : 'horizontal'
            rebuild_preview
          else
            @settings['reverse_front'] = !@settings['reverse_front']
          end
          view.invalidate
        end
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
        yield model
        model.commit_operation
        @operation_open = false
      rescue StandardError
        model.abort_operation if model && @operation_open
        @operation_open = false
        raise
      end
      def self.activate_entity(model, entity)
        model.selection.clear
        model.selection.add(entity) if entity && entity.valid?
      end
    end

    class BoxTool < Base
      def initialize(settings = {})
        super
        @tool_name = 'box'
        @boxes = []
        @faces = {}
        @overrides = {}
        @override_pid = nil
        @preview = Preview.new
      end
      def hint; 'Click mặt trước của từng box · Tab đảo hướng · Enter chuyển thành thùng'; end
      def update_settings(settings)
        if @override_pid
          @overrides[@override_pid]=Schema::DEFAULTS.merge(settings || {})
        else
          @settings=Schema::DEFAULTS.merge(settings || {})
        end
        rebuild_preview
        Sketchup.active_model.active_view.invalidate
      end
      def rebuild_preview
        @preview=Preview.new
        @boxes.each { |item| Geometry.preview_cabinet(item,@faces[item.persistent_id],@overrides[item.persistent_id]||@settings,@preview) if @faces[item.persistent_id] }
      end
      def onKeyDown(key,repeat,flags,view)
        if key==VK_TAB
          @faces.transform_values!(&:reverse)
          rebuild_preview
          view.invalidate
        else
          super
        end
      end
      def onLButtonDown(flags, x, y, view)
        path = picked_path(view, x, y)
        box = path.reverse.find { |e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && !ModelData.cabinet?(e) }
        face = path.reverse.find { |e| e.is_a?(Sketchup::Face) }
        return unless box && face
        @boxes << box unless @boxes.include?(box)
        if (flags & CONSTRAIN_MODIFIER_KEY)!=0
          pid=box.persistent_id
          if @override_pid==pid
            @override_pid=nil
            @overrides.delete(pid)
          else
            @override_pid=pid
            @overrides[pid]=@settings.dup
          end
          Dialog.set_status(@override_pid ? 'Cấu hình riêng cho box này đã bật; sửa thông số trong bảng.' : 'Đã bỏ cấu hình riêng cho box.')
        else
          @override_pid=nil
        end
        @ip.pick(view,x,y)
        normal = face.normal
        hit = @ip.position.transform(box.transformation.inverse) if @ip.valid?
        if hit && normal.dot(hit - box.definition.bounds.center) < 0
          normal = normal.reverse
        end
        @faces[box.persistent_id] = normal
        rebuild_preview
        Dialog.set_status("Đã chọn mặt trước cho #{@boxes.length} box. Enter để xem trước / tạo thùng.")
        view.invalidate
      end
      def commit(view)
        raise 'Chưa chọn mặt trước của box nào.' if @boxes.empty?
        operation('Box → Cabinet') do
          @boxes.each do |box|
            next unless box.valid?
            params=@settings.merge(@overrides[box.persistent_id]||{})
            root = Geometry.cabinet_from_box(box, params.merge('front_normal' => @faces[box.persistent_id].to_a, 'remove_source' => params['keep_source'] != true))
            Geometry.share_components(root)
            ModelData.stamp(root, 'cabinet', ModelData.params(root).merge('front_normal' => @faces[box.persistent_id].to_a))
          end
        end
        view.model.select_tool(nil)
        Dialog.set_status("Đã chuyển #{@boxes.length} box thành thùng tủ.")
      rescue StandardError => e
        Dialog.set_status(e.message)
      end
    end

    class PanelTool < Base
      def initialize(settings = {})
        super
        @tool_name = 'panel'
        @root = nil
        @shell = nil
        @levels = []
      end
      def hint; 'Chọn tủ, click cao độ đợt/vách · nhập /n để chia đều · Enter tạo'; end
      def onLButtonDown(_flags, x, y, view)
        @root ||= picked_cabinet(view, x, y) || Sketchup.active_model.selection.find { |entity| ModelData.cabinet?(entity) }
        @shell ||= Geometry.shell_for(@root)
        return unless @root && @shell && @root.valid? && @ip.valid?
        point = @ip.position
        @levels << point
        rebuild_preview
        view.invalidate
      end
      def onUserText(text, view)
        match = text.to_s.strip.match(%r{\A/(\d+)\z})
        raise 'Nhập dạng /2, /3… để chia đều.' unless match
        @divide_count = [[match[1].to_i, 1].max, 20].min
        rebuild_preview
        view.invalidate
      rescue StandardError => e
        Dialog.set_status(e.message)
      end
      def onKeyDown(key, repeat, flags, view)
        if key == VK_TAB
          @settings['panel_axis'] = @settings['panel_axis'] == 'vertical' ? 'horizontal' : 'vertical'
          rebuild_preview
          view.invalidate
        else
          super
        end
      end
      def rebuild_preview
        @preview = Preview.new
        return unless @root && @root.valid? && @shell && @shell.valid?
        bounds = @shell.definition.bounds
        transform = @root.transformation * @shell.transformation
        if @divide_count
          vertical = @settings['panel_axis'] == 'vertical'
          low = vertical ? bounds.min.x + @settings['board_thickness'].to_f.mm : bounds.min.z + @settings['board_thickness'].to_f.mm
          high = vertical ? bounds.max.x - @settings['board_thickness'].to_f.mm : bounds.max.z - @settings['board_thickness'].to_f.mm
          @levels = (1...@divide_count).map do |i|
            point = vertical ? Geom::Point3d.new(low+(high-low)*i/@divide_count.to_f,(bounds.min.y+bounds.max.y)/2,(bounds.min.z+bounds.max.z)/2) : Geom::Point3d.new((bounds.min.x+bounds.max.x)/2,(bounds.min.y+bounds.max.y)/2,low+(high-low)*i/@divide_count.to_f)
            point.transform(transform)
          end
        end
        @levels.each do |world|
          local = world.transform(transform.inverse)
          if @settings['panel_axis'] == 'vertical'
            x=local.x
            pts=[[x,bounds.min.y,bounds.min.z+@settings['board_thickness'].to_f.mm],[x,bounds.max.y,bounds.min.z+@settings['board_thickness'].to_f.mm],[x,bounds.max.y,bounds.max.z-@settings['board_thickness'].to_f.mm],[x,bounds.min.y,bounds.max.z-@settings['board_thickness'].to_f.mm]].map { |p| Geom::Point3d.new(p).transform(transform) }
          else
            z = local.z
            pts = [[bounds.min.x + @settings['board_thickness'].to_f.mm,bounds.min.y,z], [bounds.max.x - @settings['board_thickness'].to_f.mm,bounds.min.y,z], [bounds.max.x - @settings['board_thickness'].to_f.mm,bounds.max.y,z], [bounds.min.x + @settings['board_thickness'].to_f.mm,bounds.max.y,z]].map { |p| Geom::Point3d.new(p).transform(transform) }
          end
          @preview.add_polygon(pts, :front)
        end
      end
      def commit(view)
        raise 'Hãy chọn tủ và vị trí đợt/vách; nhập /n để chia đều.' unless @root && !@levels.empty?
        operation('Tạo đợt / vách') do
          @root.make_unique if @root.respond_to?(:make_unique)
          @shell = Geometry.shell_for(@root)
          @shell.make_unique if @shell.respond_to?(:make_unique)
          bounds = @shell.definition.bounds
          @levels.each_with_index do |point, index|
            local = point.transform((@root.transformation * @shell.transformation).inverse)
            t=@settings['board_thickness'].to_f.mm
            if @settings['panel_axis'] == 'vertical'
              x=[[local.x,bounds.min.x+t].max,bounds.max.x-t].min
              points=[[x,bounds.min.y,bounds.min.z+t],[x,bounds.max.y,bounds.min.z+t],[x,bounds.max.y,bounds.max.z-t],[x,bounds.min.y,bounds.max.z-t]]
              Geometry.rectangular_board(@shell.definition.entities, "Vách #{index + 1}", points, t, X_AXIS)
            else
              z=[[local.z,bounds.min.z+t].max,bounds.max.z-t].min
              points=[[bounds.min.x+t,bounds.min.y,z],[bounds.max.x-t,bounds.min.y,z],[bounds.max.x-t,bounds.max.y,z],[bounds.min.x+t,bounds.max.y,z]]
              Geometry.rectangular_board(@shell.definition.entities, "Đợt #{index + 1}", points, t, Z_AXIS)
            end
          end
        end
        view.model.select_tool(nil)
        Dialog.set_status("Đã tạo #{@levels.length} đợt/vách.")
      rescue StandardError => e
        Dialog.set_status(e.message)
      end
    end

    class DoorTool < Base
      def initialize(settings = {})
        super
        @tool_name = 'door'
        @root = nil
        @shell = nil
        @splits = []
      end
      def hint; 'Click mặt trước rồi click đường chia · Tab ngang/dọc · Backspace hoàn tác · Enter tạo'; end
      def onLButtonDown(flags, x, y, view)
        group = picked_cabinet(view, x, y)
        if @root.nil?
          @root = group || Sketchup.active_model.selection.find { |entity| ModelData.cabinet?(entity) }
          return unless @root && @root.valid?
          @shell = Geometry.shell_for(@root)
          saved = JSON.parse(@root.get_attribute(Schema::DICTIONARY, 'door_layout_json', '{}')) rescue {}
          if saved['regions'].is_a?(Array) && saved['regions'].length > 1
            @settings['split_axis'] = saved['regions'].first['axis'] || @settings['split_axis']
            @splits = saved['regions'][0...-1].map { |region| region['u1'].to_f }
            @settings.merge!(saved['settings']) if saved['settings'].is_a?(Hash)
          end
          rebuild_preview
          return
        end
        if @ip.valid?
          local = @ip.position.transform((@root.transformation * @shell.transformation).inverse)
          bounds = @shell.definition.bounds
          horizontal = @settings['split_axis'] == 'horizontal'
          coordinate = horizontal ? (local.z - bounds.min.z) / bounds.height : (local.x - bounds.min.x) / bounds.width
          coordinate=[[coordinate,0.02].max,0.98].min
          existing=@splits.find { |value| (value-coordinate).abs<0.035 }
          if (flags & CONSTRAIN_MODIFIER_KEY)!=0 && existing
            @splits.delete(existing)
          elsif existing.nil?
            @splits << coordinate
          end
          @splits.sort!
          rebuild_preview
        end
        view.invalidate
      end
      def onUserText(text, view)
        match = text.to_s.strip.match(%r{\A/(\d+)\z})
        raise 'Nhập /2, /3… để chia cánh đều.' unless match
        count = [[match[1].to_i, 2].max, 20].min
        @splits = (1...count).map { |i| i.to_f / count }
        rebuild_preview
        view.invalidate
      rescue StandardError => e
        Dialog.set_status(e.message)
      end
      def onKeyDown(key, repeat, flags, view)
        if key == VK_BACKSPACE
          @splits.pop
          rebuild_preview
          view.invalidate
        else
          super
        end
      end
      def commit(view)
        raise 'Chọn tủ trước.' unless @root && @root.valid?
        @shell = Geometry.shell_for(@root)
        raise 'Không tìm thấy hình học thùng tủ.' unless @shell
        bounds = @shell.definition.bounds
        boundaries = ([0.0] + @splits.uniq + [1.0]).sort
        count = boundaries.length - 1
        operation('Chia cánh') do
          @root.make_unique if @root.respond_to?(:make_unique)
          @shell = Geometry.shell_for(@root)
          bounds = @shell.definition.bounds
          @root.definition.entities.to_a.select { |entity| (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)) && entity.name.start_with?('Cánh Draw') }.each(&:erase!)
          # The layout is saved as editable regions; actual door solids are generated by apply_layout.
          regions = (0...count).map do |i|
            { 'index' => i, 'u0' => boundaries[i], 'u1' => boundaries[i + 1], 'gap_mm' => @settings['door_gap'].to_f, 'axis' => @settings['split_axis'] }
          end
          @root.set_attribute(Schema::DICTIONARY, 'door_layout_json', JSON.generate({ 'schema' => 1, 'regions' => regions, 'splits' => @splits, 'settings' => @settings.slice('door_gap','door_style','frame_joint','frame_width','rail_width','panel_recess','glass_rows','glass_columns','glass_bar_width','glass_thickness') }))
          regions.each_with_index do |region, index|
            axis = region['axis']
            low = axis == 'horizontal' ? bounds.min.z : bounds.min.x
            span = axis == 'horizontal' ? bounds.height : bounds.width
            a = low + span * region['u0'] + @settings['door_gap'].to_f.mm / 2
            b = low + span * region['u1'] - @settings['door_gap'].to_f.mm / 2
            next if b <= a
            y = bounds.min.y - 1.mm
            x0, x1, z0, z1 = if axis == 'horizontal'
              [bounds.min.x+@settings['door_gap'].to_f.mm/2,bounds.max.x-@settings['door_gap'].to_f.mm/2,a,b]
            else
              [a,b,bounds.min.z,bounds.max.z]
            end
            front = DoorGeometry.build(@root.definition.entities, {x0:x0,x1:x1,z0:z0,z1:z1,y:y}, 'Cánh Draw', @settings)
            front.transformation = @shell.transformation
            front.set_attribute(Schema::DICTIONARY,'part_index',index+1)
            ModelData.stamp(front, 'door', region)
            front.set_attribute(Schema::DICTIONARY, 'style', @settings.fetch('door_style','flat'))
          end
          Geometry.share_components(@root)
        end
        view.model.select_tool(nil)
        Dialog.set_status('Đã lưu bố cục và tạo cánh. Có thể chia lại bằng công cụ này.')
      rescue StandardError => e
        Dialog.set_status(e.message)
      end
      def rebuild_preview
        @preview = Preview.new
        return unless @root && @root.valid?
        return unless @shell && @shell.valid?
        b = @shell.definition.bounds
        transform = @root.transformation * @shell.transformation
        horizontal=@settings['split_axis']=='horizontal'; low=horizontal ? b.min.z : b.min.x; span=horizontal ? b.height : b.width
        boundaries=([0.0]+@splits.uniq+[1.0]).sort
        boundaries.each_cons(2) do |u0,u1|
          gap=@settings['door_gap'].to_f.mm/2
          a=low+span*u0+gap; c=low+span*u1-gap; next if c<=a
          points=horizontal ? [[b.min.x,b.min.y-1.mm,a],[b.max.x,b.min.y-1.mm,a],[b.max.x,b.min.y-1.mm,c],[b.min.x,b.min.y-1.mm,c]] : [[a,b.min.y-1.mm,b.min.z],[c,b.min.y-1.mm,b.min.z],[c,b.min.y-1.mm,b.max.z],[a,b.min.y-1.mm,b.max.z]]
          @preview.add_polygon(points.map { |point| Geom::Point3d.new(point).transform(transform) },:front)
        end
      end
    end

    class OpeningTool < Base
      def initialize(settings = {})
        super
        @tool_name='opening'
        @targets=Sketchup.active_model.selection.to_a.select { |item| item.name.start_with?('Cánh Draw') }
        @settings['hinge_side']=@targets.first&.get_attribute(Schema::DICTIONARY,'opening_side','left') || 'left'
        @parent_transforms={}
      end
      def hint; 'Click cánh để chọn · Tab đổi bên bản lề · Enter mở/đóng preview'; end
      def onLButtonDown(_flags, x, y, view)
        path=picked_path(view,x,y)
        entity = path.reverse.find { |item| (item.is_a?(Sketchup::Group) || item.is_a?(Sketchup::ComponentInstance)) && item.name.start_with?('Cánh Draw') }
        if entity && entity.valid?
          @targets << entity unless @targets.include?(entity)
          parent_path=path.take_while { |item| item!=entity }
          @parent_transforms[entity]=parent_path.select { |item| item.is_a?(Sketchup::Group) || item.is_a?(Sketchup::ComponentInstance) }.reduce(Geom::Transformation.new) { |memo,item| memo*item.transformation }
        end
        rebuild_preview
        view.invalidate
      end
      def onKeyDown(key,repeat,flags,view)
        if key==VK_TAB
          @settings['hinge_side']=@settings['hinge_side']=='right' ? 'left' : 'right'
          Dialog.set_status("Bản lề: #{@settings['hinge_side']=='left' ? 'trái' : 'phải'}.")
          rebuild_preview
          view.invalidate
        else
          super
        end
      end
      def commit(view)
        raise 'Chọn ít nhất một cánh.' if @targets.empty?
        operation('Đánh hướng mở') do
          @targets.each do |target|
            side = @settings['hinge_side'] || target.get_attribute(Schema::DICTIONARY,'opening_side','left')
            target.set_attribute(Schema::DICTIONARY, 'opening_kind', 'hinged')
            target.set_attribute(Schema::DICTIONARY, 'opening_side', side)
            target.set_attribute(Schema::DICTIONARY, 'open_angle', 105.0)
            target.set_attribute(Schema::DICTIONARY, 'opening_schema', 1)
            Operations.opening_marker(target,side)
            Operations.toggle_opening(target, side, 105.0)
          end
        end
        view.model.select_tool(nil)
        Dialog.set_status("Đã đảo trạng thái mở cho #{@targets.length} cánh.")
      rescue StandardError => e
        Dialog.set_status(e.message)
      end
      def rebuild_preview
        @preview=Preview.new
        @targets.each do |target|
          next unless target && target.valid?
          opened=target.get_attribute(Schema::DICTIONARY,'open_state')!='open'
          rotation=Operations.opening_rotation(target,@settings['hinge_side']||target.get_attribute(Schema::DICTIONARY,'opening_side','left'),105.0,opened)
          b=target.definition.bounds
          points=[[b.min.x,b.min.y,b.min.z],[b.max.x,b.min.y,b.min.z],[b.max.x,b.min.y,b.max.z],[b.min.x,b.min.y,b.max.z]]
          parent=@parent_transforms[target] || Geom::Transformation.new
          points.map! { |point| Geom::Point3d.new(point).transform(target.transformation).transform(rotation).transform(parent) }
          @preview.add_polygon(points,:front)
        end
      end
    end

    class SelectAndApplyTool < Base
      def initialize(name, settings = {}); super(settings); @tool_name = name; @targets = []; @points = []; end
      def onLButtonDown(flags, x, y, view)
        path=picked_path(view,x,y)
        entity = if @tool_name=='handle'
          path.reverse.find { |item| (item.is_a?(Sketchup::Group) || item.is_a?(Sketchup::ComponentInstance)) && item.name.start_with?('Cánh Draw') }
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
      def hint; 'Click đặt/chọn điểm · Shift-click thêm · nhập /n chia đều · Enter xem trước và áp dụng · Esc hủy'; end
      def onUserText(text,view)
        if @tool_name=='drawer' && (match=text.to_s.strip.match(%r{\A/(\d+)\z}))
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
          b=shell.definition.bounds; transform=root.transformation*shell.transformation
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
            end
          elsif @tool_name=='blocker'
            z=points.first ? points.first[1].transform(transform.inverse).z : b.min.z+b.height*0.7
            h=@settings.fetch('blocker_height',60).to_f.mm
            pts=[[b.min.x,b.min.y,z],[b.max.x,b.min.y,z],[b.max.x,b.min.y,z+h],[b.min.x,b.min.y,z+h]].map { |p| Geom::Point3d.new(p).transform(transform) }
            @preview.add_polygon(pts,:target)
          elsif @tool_name=='wardrobe' && points.length>=2
            a=points[0][1].transform(transform.inverse); c=points[1][1].transform(transform.inverse)
            x0,x1=[a.x,c.x].minmax; z0,z1=[a.z,c.z].minmax
            pts=[[x0,b.min.y,z0],[x1,b.min.y,z0],[x1,b.min.y,z1],[x0,b.min.y,z1]].map { |p| Geom::Point3d.new(p).transform(transform) }
            @preview.add_polygon(pts,:body)
          elsif @tool_name=='handle'
            p=points.last && points.last[1].transform(root.transformation.inverse)
            if p
              w=@settings.fetch('handle_width',100).to_f.mm
              @preview.add_polygon([[p.x-w/2,p.y,p.z-4.mm],[p.x+w/2,p.y,p.z-4.mm],[p.x+w/2,p.y,p.z+4.mm],[p.x-w/2,p.y,p.z+4.mm]].map { |v| Geom::Point3d.new(v).transform(root.transformation) },:front)
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
          when 'blocker' then Operations.blockers(@targets, @settings, @points)
          when 'handle' then Operations.handles(@targets, @settings, @points)
          when 'round' then Operations.round_edges(@targets, @settings, @points)
          end
        end
        view.model.select_tool(nil)
        Dialog.set_status("Đã áp dụng #{Tools.label(@tool_name)}.")
      rescue StandardError => e
        Dialog.set_status(e.message)
      end
    end

    class CutTool < Base
      def initialize(settings = {}); super; @tool_name='cut'; @target=nil; @point=nil; @axis=0; end
      def hint; 'Chọn tấm, click vị trí cắt · Tab đổi trục · Enter cắt · Esc hủy'; end
      def onLButtonDown(_flags,x,y,view)
        path=picked_path(view,x,y)
        @target=path.reverse.find { |item| (item.is_a?(Sketchup::Group) || item.is_a?(Sketchup::ComponentInstance)) && !ModelData.cabinet?(item) }
        @ip.pick(view,x,y); @point=@ip.position if @ip.valid?
        rebuild_preview
        view.invalidate
      end
      def onKeyDown(key,repeat,flags,view)
        if key==VK_TAB; @axis=(@axis+1)%3; rebuild_preview; view.invalidate; else; super; end
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
      def commit(view)
        raise 'Chọn một cấu kiện và điểm cắt.' unless @target && @point
        operation('Cắt ván') { Operations.cut([@target],@settings,[[@target,@point]],@axis) }
        view.model.select_tool(nil); Dialog.set_status('Đã cắt cấu kiện.')
      rescue StandardError=>e
        Dialog.set_status(e.message)
      end
    end

    class NotchTool < Base
      def initialize(settings = {}); super; @tool_name='notch'; @targets=[]; @cutters=[]; end
      def hint; 'Click chọn tấm đích · Shift-click chọn dao cắt · Enter khấu · Esc hủy'; end
      def onLButtonDown(flags,x,y,view)
        path=picked_path(view,x,y)
        entity=path.reverse.find { |item| (item.is_a?(Sketchup::Group) || item.is_a?(Sketchup::ComponentInstance)) && !ModelData.cabinet?(item) }
        return unless entity && entity.valid?
        if (flags & CONSTRAIN_MODIFIER_KEY)!=0; @cutters << entity unless @cutters.include?(entity); else; @targets << entity unless @targets.include?(entity); end
        box=entity.bounds; corners=(0..7).map { |i| box.corner(i) }
        faces=[[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]
        faces.each { |ids| @preview.add_polygon(ids.map { |i| corners[i] },(flags & CONSTRAIN_MODIFIER_KEY)!=0 ? :cutter : :target) }
        Dialog.set_status("Đích #{@targets.length} · dao cắt #{@cutters.length}.")
        view.invalidate
      end
      def commit(view)
        raise 'Chọn tấm đích và dao cắt bằng Shift-click.' if @targets.empty? || @cutters.empty?
        operation('Khấu ván') { Operations.notch(@targets,@cutters) }
        view.model.select_tool(nil); Dialog.set_status('Đã khấu các tấm đích.')
      rescue StandardError=>e
        Dialog.set_status(e.message)
      end
    end

    def label(name); Schema::TOOLS.fetch(name.to_s, name.to_s); end
    def build(name, settings = {})
      name = name.to_s
      case name
      when 'box' then BoxTool.new(settings)
      when 'panel' then PanelTool.new(settings)
      when 'door' then DoorTool.new(settings)
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

    def drawers(targets,settings,points)
      targets.each do |root|
        root.make_unique if root.respond_to?(:make_unique)
        shell=shell_for(root); shell.make_unique if shell.respond_to?(:make_unique); b=shell.definition.bounds; t=settings.fetch('board_thickness',17.5).to_f.mm
        h=settings.fetch('drawer_front_height',180).to_f.mm; gap=settings.fetch('drawer_gap',0).to_f.mm
        levels=points.select { |item| item[0]==root }.map { |item| item[1].transform((root.transformation*shell.transformation).inverse).z }
        if levels.empty?
          count=[[settings.fetch('drawer_count',2).to_i,1].max,20].min
          gap_tier=settings.fetch('drawer_tier_gap',25).to_f.mm
          raise 'Không đủ cao để chia hộc theo chiều cao đã nhập.' if count*h+(count-1)*gap_tier>b.height
          levels=(0...count).map { |i| b.min.z+i*(h+gap_tier) }
        end
        levels.each_with_index do |z,index|
          z=[[z,b.min.z].max,b.max.z-h].min
          front=shell.definition.entities.add_group; front.name='Mặt Ngăn Kéo'
          y=b.min.y-1.mm; x0=b.min.x+t; x1=b.max.x-t
          face=front.entities.add_face([[x0,y,z],[x1,y,z],[x1,y,z+h],[x0,y,z+h]])
          raise 'Không tạo được mặt ngăn kéo.' unless face
          face.reverse! if face.normal.y>0; face.pushpull(t)
          ModelData.stamp(front,'drawer_front',{'height_mm'=>h.to_mm,'gap_mm'=>gap.to_mm})
          front.set_attribute(Schema::DICTIONARY,'part_index',index+1)
          y0=y+t; y1=b.max.y-t-settings.fetch('drawer_back_clearance',20).to_f.mm
          z0=z+settings.fetch('drawer_box_bottom_lift',10).to_f.mm
          box_h=[h-t-settings.fetch('drawer_box_top_clearance',13).to_f.mm,20.mm].max
          side=settings.fetch('drawer_ray_space',13).to_f.mm
          drawer=shell.definition.entities.add_group
          drawer.name='Thùng Ngăn Kéo'
          drawer_x0=x0+side; drawer_x1=x1-side; drawer_z1=z0+box_h
          raise 'Khoang ngăn kéo quá nhỏ.' unless drawer_x1-drawer_x0>2*t && y1-y0>2*t && box_h>t
          solid_box(drawer.entities,'Hông Trái',drawer_x0,drawer_x0+t,y0,y1,z0+t,drawer_z1)
          solid_box(drawer.entities,'Hông Phải',drawer_x1-t,drawer_x1,y0,y1,z0+t,drawer_z1)
          solid_box(drawer.entities,'Mặt Trước',drawer_x0+t,drawer_x1-t,y0,y0+t,z0+t,drawer_z1)
          solid_box(drawer.entities,'Mặt Sau',drawer_x0+t,drawer_x1-t,y1-t,y1,z0+t,drawer_z1)
          solid_box(drawer.entities,'Đáy',drawer_x0+t,drawer_x1-t,y0+t,y1-t,z0,z0+t)
          ModelData.stamp(drawer,'drawer_box',{'depth_mm'=>(y1-y0).to_mm,'height_mm'=>box_h.to_mm,'side_thickness_mm'=>t.to_mm})
          drawer.set_attribute(Schema::DICTIONARY,'part_index',index+1)
        end
        Geometry.share_components(root)
      end
    end

    def wardrobe(targets,settings,points)
      targets.each do |root|
        root.make_unique if root.respond_to?(:make_unique)
        shell=shell_for(root); shell.make_unique if shell.respond_to?(:make_unique); b=shell.definition.bounds
        clicks=points.select { |item| item[0]==root }.map { |item| item[1].transform((root.transformation*shell.transformation).inverse) }
        x0,x1=clicks.length>=2 ? [clicks[0].x,clicks[1].x].minmax : [b.min.x+b.width*0.25,b.min.x+b.width*0.75]
        z0=clicks.first ? clicks.first.z : b.min.z+b.height*0.2
        z1=clicks[1] ? clicks[1].z : z0+settings.fetch('compartment_height',400).to_f.mm
        z0,z1=[z0,z1].minmax; t=settings.fetch('board_thickness',17.5).to_f.mm
        raise 'Khoang tủ áo quá nhỏ.' if x1-x0<2*t || z1-z0<2*t
        g=shell.definition.entities.add_group; g.name='Hộc Tủ Áo'
        solid_box(g.entities,'Đáy Hộc',x0,x1,b.min.y+t,b.max.y-t,z0,z0+t)
        solid_box(g.entities,'Nóc Hộc',x0,x1,b.min.y+t,b.max.y-t,z1-t,z1)
        solid_box(g.entities,'Hông Hộc Trái',x0,x0+t,b.min.y+t,b.max.y-t,z0+t,z1-t)
        solid_box(g.entities,'Hông Hộc Phải',x1-t,x1,b.min.y+t,b.max.y-t,z0+t,z1-t)
        ModelData.stamp(g,'wardrobe_compartment',{'width_mm'=>(x1-x0).to_mm,'height_mm'=>(z1-z0).to_mm})
        Geometry.share_components(root)
      end
    end

    def blockers(targets,settings,points)
      targets.each do |root|
        root.make_unique if root.respond_to?(:make_unique)
        shell=shell_for(root); shell.make_unique if shell.respond_to?(:make_unique); b=shell.definition.bounds; t=settings.fetch('board_thickness',17.5).to_f.mm; h=settings.fetch('blocker_height',60).to_f.mm
        click=points.find { |item| item[0]==root }; z=click ? click[1].transform((root.transformation*shell.transformation).inverse).z : b.min.z+b.height*0.7
        profile=settings.fetch('blocker_profile','C'); g=shell.definition.entities.add_group; g.name="Xà Chặn #{profile}"
        case profile
        when 'I'
          solid_box(g.entities,'Bản trước',b.min.x,b.max.x,b.min.y,b.min.y+t,z,z+h)
          solid_box(g.entities,'Bản sau',b.min.x,b.max.x,b.max.y-t,b.max.y,z,z+h)
          solid_box(g.entities,'Lõi',b.min.x,b.max.x,b.min.y+t,b.max.y-t,z+h/2-t/2,z+h/2+t/2)
        when 'L'
          solid_box(g.entities,'Mặt đứng',b.min.x,b.max.x,b.min.y,b.min.y+t,z,z+h)
          solid_box(g.entities,'Cánh ngang',b.min.x,b.max.x,b.min.y,b.max.y,z,z+t)
        else
          solid_box(g.entities,'Mặt trước',b.min.x,b.max.x,b.min.y,b.min.y+t,z,z+h)
          solid_box(g.entities,'Mặt sau',b.min.x,b.max.x,b.max.y-t,b.max.y,z,z+h)
          solid_box(g.entities,'Mặt nối',b.min.x,b.max.x,b.min.y,b.max.y,z+h-t,z+h)
        end
        ModelData.stamp(g,'blocker',{'profile'=>profile,'height_mm'=>h.to_mm})
        Geometry.share_components(root)
      end
    end

    def handles(targets,settings,points)
      targets.each do |door|
        door.make_unique if door.respond_to?(:make_unique)
        b=door.definition.bounds; click=points.find { |item| item[0]==door }
        p=click ? click[1].transform(door.transformation.inverse) : Geom::Point3d.new((b.min.x+b.max.x)/2,b.min.y,(b.min.z+b.max.z)/2)
        width=settings.fetch('handle_width',100).to_f.mm; g=door.definition.entities.add_group; g.name='Tay Nắm'
        if settings.fetch('handle_profile','bar')=='knob'
          circle=g.entities.add_circle([p.x,p.y-8.mm,p.z],Y_AXIS,8.mm,16)
          face=circle.first.find_faces
          cap=circle.first.faces.max_by(&:area)
          cap.pushpull(8.mm) if cap
        else
          radius=4.mm
          face=g.entities.add_face([[p.x-width/2,p.y-8.mm,p.z-radius],[p.x+width/2,p.y-8.mm,p.z-radius],[p.x+width/2,p.y-8.mm,p.z+radius],[p.x-width/2,p.y-8.mm,p.z+radius]])
          face.reverse! if face && face.normal.y>0; face.pushpull(8.mm) if face
        end
        ModelData.stamp(g,'handle',{'profile'=>settings.fetch('handle_profile','bar'),'position'=>'custom','point'=>p.to_a})
      end
    end

    def opening_marker(door,side)
      door.make_unique if door.respond_to?(:make_unique)
      b=door.definition.bounds; width=b.width; height=b.height; y=b.min.y-2.mm
      marker=door.definition.entities.grep(Sketchup::Group).find { |item| item.name=='Ký Hiệu Hướng Mở' }
      marker.erase! if marker && marker.valid?
      marker=door.definition.entities.add_group; marker.name='Ký Hiệu Hướng Mở'
      marker.layer=ensure_tag(Schema::DEFAULTS['opening_tag'])
      # A segmented swing indicator remains editable model geometry and shares the stored opening metadata.
      hinge_x=side=='left' ? b.min.x : b.max.x
      free_x=side=='left' ? b.max.x : b.min.x
      z0=b.min.z; z1=b.max.z
      points=14
      points.times do |i|
        next if i.odd?
        a=i.to_f/points; c=[a+1.0/points,1.0].min
        p0=[hinge_x+(free_x-hinge_x)*a,y,z1-height*a*0.35]
        p1=[hinge_x+(free_x-hinge_x)*c,y,z1-height*c*0.35]
        marker.entities.add_line(p0,p1)
      end
      marker.set_attribute(Schema::DICTIONARY,'kind','opening_symbol')
      marker.set_attribute(Schema::DICTIONARY,'opening_side',side)
    end

    def opening_rotation(door,side,angle,opening)
      bounds=door.definition.bounds
      x=side=='left' ? bounds.min.x : bounds.max.x
      pivot=Geom::Point3d.new(x,bounds.min.y,bounds.min.z).transform(door.transformation)
      axis=door.transformation.zaxis
      sign=side=='left' ? -1.0 : 1.0
      sign *= -1.0 unless opening
      Geom::Transformation.rotation(pivot,axis,sign*angle.to_f.degrees)
    end

    def toggle_opening(door,side,angle)
      opened=door.get_attribute(Schema::DICTIONARY,'open_state')=='open'
      rotation=opening_rotation(door,side,angle,!opened)
      door.transformation=rotation*door.transformation
      door.set_attribute(Schema::DICTIONARY,'open_state',opened ? 'closed' : 'open')
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
        result=target.subtract(cutter); raise 'Cắt thất bại. Kiểm tra solid và điểm cắt.' unless result
        result.name=target.name; result.set_attribute(Schema::DICTIONARY,'kind','part')
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
        result=target.subtract(cutter); raise 'Bo cạnh thất bại; cần solid manifold.' unless result
        result.name=target.name
      end
    end

    def notch(targets,cutters)
      targets.each do |target|
        current=target; require_solid!(current)
        cutters.each do |cutter|
          next if cutter==target
          require_solid!(cutter); result=current.subtract(cutter)
          raise 'Khấu thất bại; dao cắt và tấm đích cần là solid manifold giao nhau.' unless result
          result.name=target.name; result.set_attribute(Schema::DICTIONARY,'kind','part'); result.set_attribute(Schema::DICTIONARY,'notched',true); current=result
        end
      end
      cutters.each { |cutter| cutter.erase! if cutter.valid? }
    end
  end
end
