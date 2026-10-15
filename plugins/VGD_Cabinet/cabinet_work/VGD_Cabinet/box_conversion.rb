# frozen_string_literal: true

require_relative 'preview_mesh'
require_relative 'model_data'

module VGD_Cabinet
  # Turns selected block groups into production cabinets only after the user
  # marks each front face and confirms the complete batch with Enter.
  class BoxToCabinetTool
    remove_const(:Record) if const_defined?(:Record, false)
    Record = Struct.new(:source, :bounds, :front_normal, :params, :mesh, :transform)

    def initialize(params, targets)
      @model = Sketchup.active_model
      @model_guid = @model.guid.to_s
      @base_params = VGD_Cabinet.normalize(params)
      @targets = targets.dup
      @records = @targets.map { |entity| Record.new(entity, entity.definition.bounds, nil, nil, nil, nil) }
      @index = 0
      @message = nil
    end

    def activate
      Sketchup.status_text = "VGD · Chọn mặt trước lần lượt #{@targets.size} hộp; Enter xem trước/áp dụng, Esc hủy."
    end

    def deactivate(view); view.invalidate; end

    def getExtents
      bounds = Geom::BoundingBox.new
      @records.each do |record|
        if record.mesh && record.transform
          8.times { |i| bounds.add(record.mesh.bounds.corner(i).transform(record.transform)) }
        else
          bounds.add(record.source.bounds) if record.source.valid?
        end
      end
      bounds
    end

    def draw(view)
      @records.each do |record|
        record.mesh.draw(view, record.transform) if record.mesh && record.transform
      end
      if @index < @records.size
        view.draw_text([24, 24], "VGD · HỘP → TỦ · Chọn mặt trước #{@index + 1}/#{@records.size}", color: Sketchup::Color.new(200, 169, 138), size: 12, bold: true)
      else
        view.draw_text([24, 24], 'VGD · XEM TRƯỚC LÔ TỦ · Enter áp dụng · Esc hủy', color: Sketchup::Color.new(200, 169, 138), size: 12, bold: true)
      end
      view.draw_text([24, 46], 'Enter thay group/component hộp bằng cabinet; Ctrl+Z hoàn tác cả lô.', color: Sketchup::Color.new(255, 255, 255), size: 10)
      view.draw_text([24, 64], @message, color: Sketchup::Color.new(255, 205, 140), size: 10) if @message
    end

    def onLButtonDown(_flags, x, y, view)
      return if @index >= @records.size
      helper = view.pick_helper
      helper.do_pick(x, y)
      face_index = (0...helper.count).find do |index|
        path = helper.path_at(index)
        path && path.include?(@records[@index].source) && path.last.is_a?(Sketchup::Face)
      end
      unless face_index
        @message = 'Hãy bấm một mặt bên của hộp đang chờ; mặt trên/dưới không dùng làm mặt trước.'
        view.invalidate
        return
      end
      path = helper.path_at(face_index)
      face = path.last
      root_transform = @model.edit_transform.inverse * helper.transformation_at(face_index)
      local_transform = @records[@index].source.transformation.inverse * root_transform
      normal = face.normal.transform(local_transform).normalize
      orientation = cabinet_frame(@records[@index].source, normal)
      raise ModelingRules::Invalid, 'Không xác định được mặt trước; chọn một mặt bên song song trục local X hoặc Y.' unless orientation
      record = @records[@index]
      record.front_normal = normal
      record.params = sized_params(orientation[:width], orientation[:depth], orientation[:height])
      record.mesh = PreviewMesh.new(record.params)
      record.transform = orientation[:transform]
      @index += 1
      @message = nil
      Sketchup.status_text = @index == @records.size ? 'Đã có đủ mặt trước. Xem preview rồi Enter áp dụng cả lô hoặc Esc hủy.' : "Chọn mặt trước hộp #{@index + 1}/#{@records.size}."
      view.invalidate
    rescue => error
      @message = error.message
      view.invalidate
    end

    def onMouseMove(_flags, _x, _y, view); view.invalidate; end

    def onKeyDown(key, _repeat, _flags, view)
      if key == 27
        @model.select_tool(nil)
      elsif key == 13
        if @index < @records.size
          @message = 'Chọn mặt trước cho tất cả hộp trước khi áp dụng.'
          view.invalidate
          return
        end
        VGD_Cabinet.apply_box_conversion(@records, @model_guid)
        @model.select_tool(nil)
      end
    end

    def onCancel(_reason, _view); @model.select_tool(nil); end

    private

    def sized_params(width, depth, height)
      result = @base_params.merge('w' => width.round(1), 'd' => depth.round(1), 'h' => height.round(1))
      if result['module_mode'] == 'Độc lập' && !result['module_widths'].to_s.strip.empty?
        widths = ModelingRules.widths(result)
        resized = widths.map { |value| (value * width / widths.sum).round(3) }
        resized[-1] = (width - resized[0...-1].sum).round(3)
        result['module_widths'] = resized.join(';')
      end
      VGD_Cabinet.normalize(result)
    end

    # A front face must be in the cabinet's local horizontal plane. The frame
    # is built from the box's own axes, so rotated cabinets do not use world X/Y.
    def cabinet_frame(entity, normal)
      components = [normal.x, normal.y, normal.z]
      cardinal = components.map { |value| value.abs > 0.999 ? value <=> 0 : 0 }
      return nil unless cardinal.count { |value| !value.zero? } == 1 && cardinal[2].zero?
      inward = Geom::Vector3d.new(-cardinal[0], -cardinal[1], 0)
      z_axis = Geom::Vector3d.new(0, 0, 1)
      x_axis = inward.cross(z_axis).normalize
      bounds = entity.definition.bounds
      scale_axes = [entity.transformation.xaxis, entity.transformation.yaxis, entity.transformation.zaxis]
      scale_lengths = scale_axes.map(&:length)
      normalized_axes = scale_axes.map(&:normalize)
      raise ModelingRules::Invalid, 'Hộp bị xiên hoặc có scale bằng 0; hãy sửa trục trước khi chuyển.' if scale_lengths.any? { |length| length < 1e-8 } || normalized_axes.combination(2).any? { |a, b| a.dot(b).abs > 1e-6 }
      width_axis = x_axis.x.abs > 0.5 ? 0 : 1
      depth_axis = inward.x.abs > 0.5 ? 0 : 1
      spans = [bounds.width, bounds.height, bounds.depth]
      width = (spans[width_axis] * scale_lengths[width_axis]).to_mm
      depth = (spans[depth_axis] * scale_lengths[depth_axis]).to_mm
      height = (spans[2] * scale_lengths[2]).to_mm
      raise ModelingRules::Invalid, 'Hộp cần có đủ rộng, sâu và cao lớn hơn 10 mm.' if [width, depth, height].any? { |value| value <= 10 }
      origin = Geom::Point3d.new(
        x_axis.x > 0 ? bounds.min.x : (x_axis.x < 0 ? bounds.max.x : (inward.x > 0 ? bounds.max.x : bounds.min.x)),
        x_axis.y > 0 ? bounds.min.y : (x_axis.y < 0 ? bounds.max.y : (inward.y > 0 ? bounds.max.y : bounds.min.y)),
        bounds.min.z
      ).transform(entity.transformation)
      transform = entity.transformation
      world_x = transform_vector(transform, x_axis)
      world_y = transform_vector(transform, inward)
      world_z = transform_vector(transform, z_axis)
      return nil if world_x.cross(world_y).dot(world_z) <= 0
      world_x.normalize!; world_y.normalize!; world_z.normalize!
      {
        width: width, depth: depth, height: height,
        transform: Geom::Transformation.axes(origin, world_x, world_y, world_z)
      }
    end

    def transform_vector(transform, vector)
      Geom::Vector3d.new(
        transform.xaxis.x * vector.x + transform.yaxis.x * vector.y + transform.zaxis.x * vector.z,
        transform.xaxis.y * vector.x + transform.yaxis.y * vector.y + transform.zaxis.y * vector.z,
        transform.xaxis.z * vector.x + transform.yaxis.z * vector.y + transform.zaxis.z * vector.z
      )
    end
  end
end
