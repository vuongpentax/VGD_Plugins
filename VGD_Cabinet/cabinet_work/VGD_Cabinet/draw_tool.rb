# frozen_string_literal: true

# Interactive three-click cabinet placement tool. Kept separate from the
# cabinet data/orchestration layer so drawing UX can evolve independently.
require_relative 'preview_mesh'
module VGD_Cabinet
  class CabinetDrawTool
    def initialize(params)
      @params = params.dup
      @state = 0
      @pt1 = nil
      @pt2 = nil
      @pt3 = nil
      @preview_key = nil
      @preview_mesh = nil
      @placement_direction = nil
      @ip = Sketchup::InputPoint.new
      @ip_first = Sketchup::InputPoint.new
    end

    def activate
      @state = 0
      @pt1 = nil
      @pt2 = nil
      @pt3 = nil
      @preview_key = nil
      @preview_mesh = nil
      @placement_direction = nil
      Sketchup.vcb_label = "Rộng, Sâu W,D (mm)"
      Sketchup.vcb_value = ""
      Sketchup.status_text = "Click điểm 1: Chọn vị trí góc bắt đầu đáy tủ"
    end

    def deactivate(view)
      view.invalidate
    end

    def getExtents
      bb = Geom::BoundingBox.new
      if @pt1
        bb.add(@pt1)
        bb.add(@ip.position) if @ip && @ip.valid?
        bb.add(@pt2) if @pt2
        bb.add(@pt3) if @pt3
        bb.add(@pt1.offset(Z_AXIS, @params['h'].to_f.mm))
        if @preview_mesh && @preview_transform
          8.times { |i| bb.add(@preview_mesh.bounds.corner(i).transform(@preview_transform)) }
        end
      end
      bb
    end

    def snap_dim_50mm(val_mm)
      return 0.0 if val_mm.abs < 5.0
      sign = val_mm < 0 ? -1.0 : 1.0
      step = (@params['snap_step'] || 50).to_f
      snapped = (val_mm.abs / step).round * step
      snapped = step if snapped < step
      sign * snapped
    end

    def get_snapped_pt2(raw_pt)
      return raw_pt unless @pt1
      dx_mm = (raw_pt.x - @pt1.x).to_mm
      dy_mm = (raw_pt.y - @pt1.y).to_mm
      return @pt1 if dx_mm.abs < 5.0 && dy_mm.abs < 5.0

      snapped_dx = snap_dim_50mm(dx_mm)
      snapped_dy = snap_dim_50mm(dy_mm)
      Geom::Point3d.new(@pt1.x + snapped_dx.mm, @pt1.y + snapped_dy.mm, @pt1.z)
    end

    def get_snapped_pt3(raw_pt3)
      return raw_pt3 unless @pt1
      dz_mm = (raw_pt3.z - @pt1.z).to_mm
      return @pt1 if dz_mm.abs < 5.0

      snapped_dz = snap_dim_50mm(dz_mm)
      Geom::Point3d.new(@pt1.x, @pt1.y, @pt1.z + snapped_dz.mm)
    end

    def onMouseMove(flags, x, y, view)
      if @state == 0
        @ip.pick(view, x, y)
        Sketchup.status_text = "Click điểm 1: Chọn góc bắt đầu đáy tủ"
        view.tooltip = "Click 1: Góc bắt đầu"
      elsif @state == 1
        @ip.pick(view, x, y, @ip_first)
        Sketchup.status_text = "Click điểm 2: Chọn góc đối diện đáy tủ (Snap 50mm) hoặc gõ W,D vào VCB (ví dụ: 1200, 600)"
        view.tooltip = "Click 2: Kích thước đáy (Snap 50mm)"
      elsif @state == 2
        line = [@pt1, Geom::Vector3d.new(0, 0, 1)]
        @ip.pick(view, x, y)
        raw_pt3 = @ip.position.project_to_line(line)
        @pt3 = get_snapped_pt3(raw_pt3)
        Sketchup.status_text = "Click điểm 3: Chọn chiều cao H (Snap 50mm) hoặc gõ H vào VCB (ví dụ: 2400)"
        view.tooltip = "Click 3: Chiều cao H (Snap 50mm)"
      end
      view.invalidate
    end

    def onLButtonDown(flags, x, y, view)
      if @state == 0
        @ip.pick(view, x, y)
        return unless @ip.valid?
        @pt1 = @ip.position
        @placement_direction = view.camera.direction.clone
        @ip_first.copy!(@ip)
        @state = 1
        Sketchup.vcb_label = "Rộng, Sâu W,D (mm)"
      elsif @state == 1
        @ip.pick(view, x, y, @ip_first)
        return unless @ip.valid?
        @pt2 = get_snapped_pt2(@ip.position)
        @state = 2
        Sketchup.vcb_label = "Chiều cao H (mm)"
      elsif @state == 2
        line = [@pt1, Geom::Vector3d.new(0, 0, 1)]
        @ip.pick(view, x, y)
        raw_pt3 = @ip.position.project_to_line(line)
        @pt3 = get_snapped_pt3(raw_pt3)
        h_mm = (@pt3.z - @pt1.z).abs.to_mm
        return if h_mm <= 10.0

        finish_drawing(view)
      end
    end

    def onUserText(text, view)
      if @state == 1
        parts = text.split(/[,;\s]+/).reject(&:empty?).map(&:to_f)
        w_val = parts[0] ? parts[0].abs : 800.0
        d_val = parts[1] ? parts[1].abs : 600.0

        pt_curr = @ip.position
        sign_x = (pt_curr.x >= @pt1.x) ? 1 : -1
        sign_y = (pt_curr.y >= @pt1.y) ? 1 : -1

        @pt2 = Geom::Point3d.new(@pt1.x + sign_x * w_val.mm, @pt1.y + sign_y * d_val.mm, @pt1.z)
        @state = 2
        Sketchup.vcb_label = "Chiều cao H (mm)"
        view.invalidate
      elsif @state == 2
        h_val = text.to_f.abs
        if h_val > 10.0
          @pt3 = Geom::Point3d.new(@pt1.x, @pt1.y, @pt1.z + h_val.mm)
          finish_drawing(view)
        end
      end
    rescue => e
      UI.messagebox("Lỗi nhập dữ liệu VCB: #{e.message}")
    end

    def onCancel(reason, view)
      reset_tool(view)
    end

    def onKeyDown(key, repeat, flags, view)
      if key == 27 # ESC Key
        if @state > 0
          @state -= 1
          @pt2 = nil if @state == 1
          @pt3 = nil
          @preview_key = nil
          @preview_mesh = nil
          @state == 0 ? reset_tool(view) : view.invalidate
        else
          Sketchup.active_model.select_tool(nil)
        end
      end
    end

    def draw_fixed_hud(view, w_mm = nil, d_mm = nil, h_mm = nil)
      t_val = (@params['t'] || 17).to_f.round(1)
      t_val = t_val.to_i if t_val == t_val.to_i

      case @state
      when 0
        step_title = "ĐIỂM 1/3: CHỌN GÓC ĐÁY"
        w_str = "-- mm"
        d_str = "-- mm"
        h_def = (@params['h'] || 2400).to_f.round
        h_str = "#{h_def} mm (Mặc định)"
        guide_str = "Click điểm 1 để chọn góc bắt đầu đáy tủ"
      when 1
        step_title = "ĐIỂM 2/3: CHỌN GÓC ĐỐI DIỆN"
        w_str = (w_mm && w_mm >= 10) ? "#{w_mm.round} mm" : "-- mm"
        d_str = (d_mm && d_mm >= 10) ? "#{d_mm.round} mm" : "-- mm"
        h_def = (@params['h'] || 2400).to_f.round
        h_str = "#{h_def} mm (Mặc định)"
        guide_str = "Click điểm 2 hoặc gõ W,D vào VCB rồi Enter"
      when 2
        step_title = "ĐIỂM 3/3: CHỌN CHIỀU CAO"
        w_str = (w_mm && w_mm >= 10) ? "#{w_mm.round} mm" : "-- mm"
        d_str = (d_mm && d_mm >= 10) ? "#{d_mm.round} mm" : "-- mm"
        h_str = (h_mm && h_mm >= 10) ? "#{h_mm.round} mm" : "-- mm"
        guide_str = "Click điểm 3 hoặc gõ H vào VCB rồi Enter"
      else
        return
      end

      # Kích thước & Tọa độ HUD cố định ở góc trên bên trái màn hình (rộng rãi, vừa vặn không tràn)
      hud_x = 24
      hud_y = 24
      hud_w = 410
      hud_h = 100

      p1 = Geom::Point3d.new(hud_x, hud_y, 0)
      p2 = Geom::Point3d.new(hud_x + hud_w, hud_y, 0)
      p3 = Geom::Point3d.new(hud_x + hud_w, hud_y + hud_h, 0)
      p4 = Geom::Point3d.new(hud_x, hud_y + hud_h, 0)

      # 1. Nền Card tối màu chuẩn brand (#2B2B2B) bóng mờ sang trọng
      view.drawing_color = Sketchup::Color.new(43, 43, 43, 240)
      view.draw2d(GL_QUADS, [p1, p2, p3, p4])

      # 2. Đường viền tinh tế
      view.drawing_color = Sketchup::Color.new(90, 90, 90, 200)
      view.line_width = 1
      view.draw2d(GL_LINE_LOOP, [p1, p2, p3, p4])

      # 3. Nẹp chỉ màu thương hiệu (#B48963) trên đỉnh card
      view.drawing_color = Sketchup::Color.new(180, 137, 99, 255)
      view.line_width = 3
      view.draw2d(GL_LINES, [p1, p2])

      # 4. Nội dung text HUD ghim cố định ở góc trên màn hình (Cỡ chữ vừa vặn khung, không tràn viền)
      # Tiêu đề & Bước vẽ
      view.draw_text([hud_x + 14, hud_y + 10], "📐 VGD_CABINET v#{VERSION}  •  #{step_title}", { :color => Sketchup::Color.new(200, 169, 138), :size => 9, :bold => true })

      # Kích thước Rộng (W) x Sâu (D)
      view.draw_text([hud_x + 14, hud_y + 32], "Rộng (W): #{w_str}   |   Sâu (D): #{d_str}", { :color => Sketchup::Color.new(255, 255, 255), :size => 10, :bold => true })

      # Kích thước Cao (H) x Dày ván (t)
      view.draw_text([hud_x + 14, hud_y + 53], "Cao (H):  #{h_str}   |   Dày ván: #{t_val} mm", { :color => Sketchup::Color.new(200, 169, 138), :size => 10, :bold => true })

      # Dòng hướng dẫn thao tác
      view.draw_text([hud_x + 14, hud_y + 75], "💡 #{guide_str}", { :color => Sketchup::Color.new(180, 180, 180), :size => 9 })
    end

    def draw(view)
      @ip.draw(view) if @ip.valid?
      unless @pt1
        draw_fixed_hud(view)
        return
      end
      opposite=@pt2 || (@ip.valid? ? get_snapped_pt2(@ip.position) : @pt1)
      min_x,max_x=[@pt1.x,opposite.x].minmax
      min_y,max_y=[@pt1.y,opposite.y].minmax
      min_z,max_z=@pt3 ? [@pt1.z,@pt3.z].minmax : [@pt1.z,@pt1.z+@params['h'].to_f.mm]
      direction=@placement_direction || view.camera.direction
      cfg=compute_cabinet_placement(min_x,max_x,min_y,max_y,min_z,max_z,direction)
      w=cfg[:w_mm]; depth=cfg[:d_mm]; height=cfg[:h_mm]
      if max_x-min_x>=100.mm && max_y-min_y>=100.mm && max_z-min_z>=100.mm
        key=[w,depth,height].map { |value| value.round(1) }
        if @preview_key!=key
          @preview_key=key; @preview_mesh=nil; @preview_error=nil
          begin
            @preview_mesh=PreviewMesh.new(VGD_Cabinet.normalize(params_for_size(w,depth,height)))
          rescue ModelingRules::Invalid => error
            @preview_error=error.message
          end
        end
        @preview_transform=cfg[:tr]
        @preview_mesh.draw(view,@preview_transform) if @preview_mesh
      end
      view.drawing_color=Sketchup::Color.new(180,137,99,220)
      view.line_stipple=''; view.line_width=2
      base=[Geom::Point3d.new(min_x,min_y,min_z),Geom::Point3d.new(max_x,min_y,min_z),
            Geom::Point3d.new(max_x,max_y,min_z),Geom::Point3d.new(min_x,max_y,min_z)]
      view.draw(GL_LINE_LOOP,base)
      draw_fixed_hud(view,w,depth,height)
      view.draw_text([38,130],@preview_error,color:Sketchup::Color.new(125,89,58),size:10) if @preview_error
    ensure
      view.line_stipple=''; view.line_width=1
    end

    def params_for_size(width,depth,height)
      result=@params.merge('w'=>width.round(1),'d'=>depth.round(1),'h'=>height.round(1))
      if @params['module_mode']=='Độc lập' && !@params['module_widths'].to_s.strip.empty?
        widths=ModelingRules.widths(@params)
        resized=widths.map { |value| (value*width/widths.sum).round(3) }
        resized[-1]=(width-resized[0...-1].sum).round(3)
        result['module_widths']=resized.join(';')
      end
      result
    end

    private

    def compute_cabinet_placement(min_x, max_x, min_y, max_y, min_z, max_z, cam_dir)
      dx = (max_x - min_x).to_mm
      dy = (max_y - min_y).to_mm
      dz = (max_z - min_z).to_mm

      cam_dir_flat = Geom::Vector3d.new(-cam_dir.x, -cam_dir.y, 0)
      if cam_dir_flat.length < 0.01
        cam_dir_flat = Geom::Vector3d.new(0, -1, 0)
      else
        cam_dir_flat.normalize!
      end

      # 4 hướng trục chính song song với hệ trục tọa độ SketchUp
      axes = [
        { :vec => Geom::Vector3d.new(0, -1, 0), :type => :neg_y },
        { :vec => Geom::Vector3d.new(0, 1, 0),  :type => :pos_y },
        { :vec => Geom::Vector3d.new(-1, 0, 0), :type => :neg_x },
        { :vec => Geom::Vector3d.new(1, 0, 0),  :type => :pos_x }
      ]
      best = axes.max_by { |a| cam_dir_flat.dot(a[:vec]) }

      case best[:type]
      when :neg_y # Cánh tủ hướng -Y
        w_mm = dx
        d_mm = dy
        origin = Geom::Point3d.new(min_x, max_y, min_z)
        v_x = Geom::Vector3d.new(1, 0, 0)
        v_y = Geom::Vector3d.new(0, 1, 0)
        v_z = Geom::Vector3d.new(0, 0, 1)
        door_p1 = Geom::Point3d.new(min_x, min_y, min_z)
        door_p2 = Geom::Point3d.new(max_x, min_y, min_z)
        door_p3 = Geom::Point3d.new(max_x, min_y, max_z)
        door_p4 = Geom::Point3d.new(min_x, min_y, max_z)
      when :pos_y # Cánh tủ hướng +Y
        w_mm = dx
        d_mm = dy
        origin = Geom::Point3d.new(max_x, min_y, min_z)
        v_x = Geom::Vector3d.new(-1, 0, 0)
        v_y = Geom::Vector3d.new(0, -1, 0)
        v_z = Geom::Vector3d.new(0, 0, 1)
        door_p1 = Geom::Point3d.new(max_x, max_y, min_z)
        door_p2 = Geom::Point3d.new(min_x, max_y, min_z)
        door_p3 = Geom::Point3d.new(min_x, max_y, max_z)
        door_p4 = Geom::Point3d.new(max_x, max_y, max_z)
      when :neg_x # Cánh tủ hướng -X
        w_mm = dy
        d_mm = dx
        origin = Geom::Point3d.new(max_x, max_y, min_z)
        v_x = Geom::Vector3d.new(0, -1, 0)
        v_y = Geom::Vector3d.new(1, 0, 0)
        v_z = Geom::Vector3d.new(0, 0, 1)
        door_p1 = Geom::Point3d.new(min_x, max_y, min_z)
        door_p2 = Geom::Point3d.new(min_x, min_y, min_z)
        door_p3 = Geom::Point3d.new(min_x, min_y, max_z)
        door_p4 = Geom::Point3d.new(min_x, max_y, max_z)
      when :pos_x # Cánh tủ hướng +X
        w_mm = dy
        d_mm = dx
        origin = Geom::Point3d.new(min_x, min_y, min_z)
        v_x = Geom::Vector3d.new(0, 1, 0)
        v_y = Geom::Vector3d.new(-1, 0, 0)
        v_z = Geom::Vector3d.new(0, 0, 1)
        door_p1 = Geom::Point3d.new(max_x, min_y, min_z)
        door_p2 = Geom::Point3d.new(max_x, max_y, min_z)
        door_p3 = Geom::Point3d.new(max_x, max_y, max_z)
        door_p4 = Geom::Point3d.new(max_x, min_y, max_z)
      end

      w_mm = 800.0 if w_mm < 10.0
      d_mm = 600.0 if d_mm < 10.0
      h_mm = dz < 10.0 ? 2400.0 : dz

      tr = Geom::Transformation.axes(origin, v_x, v_y, v_z)

      {
        :w_mm => w_mm,
        :d_mm => d_mm,
        :h_mm => h_mm,
        :tr => tr,
        :origin => origin,
        :v_x => v_x,
        :v_y => v_y,
        :v_z => v_z,
        :door_pts => [door_p1, door_p2, door_p3, door_p4]
      }
    end

    def reset_tool(view = nil)
      @state = 0
      @pt1 = nil
      @pt2 = nil
      @pt3 = nil
      @preview_key = nil
      @preview_mesh = nil
      @placement_direction = nil
      Sketchup.vcb_label = "Rộng, Sâu W,D (mm)"
      Sketchup.vcb_value = ""
      Sketchup.status_text = "Click điểm 1: Chọn góc bắt đầu đáy tủ"
      view.invalidate if view
    end

    def finish_drawing(view)
      min_x = [@pt1.x, @pt2.x].min
      max_x = [@pt1.x, @pt2.x].max
      min_y = [@pt1.y, @pt2.y].min
      max_y = [@pt1.y, @pt2.y].max

      z1 = @pt1.z
      z2 = @pt3 ? @pt3.z : @pt1.z
      min_z = [z1, z2].min
      max_z = [z1, z2].max

      cfg = compute_cabinet_placement(min_x, max_x, min_y, max_y, min_z, max_z, @placement_direction || view.camera.direction)
      w_mm = cfg[:w_mm]
      d_mm = cfg[:d_mm]
      h_mm = cfg[:h_mm]
      tr = cfg[:tr]

      @params = params_for_size(w_mm,d_mm,h_mm)

      # Resolve automatic structural rules using the exact same helpers as final geometry.
      split_rule = GeometryEngine.resolve_overheight_mm(@params, h_mm)
      if split_rule[:is_overheight]
        @params['is_overheight'] = true
        @params['h_bottom'] = split_rule[:h_bottom].round(1) if split_rule[:h_bottom]
        shadow = (@params['opt_top'] == 'Đỉnh Lọt Hồi') ? [0.0, @params['shadow_gap_h'].to_f].max : 0.0
        @params['h_top'] = [0.0, h_mm - shadow - @params['h_bottom'].to_f].max.round(1)
      elsif GeometryEngine.truthy_param?(@params, 'auto_overheight', true)
        @params['is_overheight'] = false
      end

      # Không ghi đè div_count thủ công bằng giá trị auto; GeometryEngine tự giải khi dựng.

      VGD_Cabinet.send_params_to_ui(@params)
      VGD_Cabinet.create_new_cabinet_at(@params, Sketchup.active_model.edit_transform.inverse * tr)
      Sketchup.active_model.select_tool(nil)
    end
  end

end
