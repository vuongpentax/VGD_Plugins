require 'digest'
module VGD_Cabinet_Draw
  module Geometry
    extend self
    MM = 1.mm

    # Hệ trục cục bộ của một tủ dựng từ box. width/depth/height tính bằng mm.
    Frame = Struct.new(:front, :width_axis, :depth_axis, :up, :origin, :width, :depth, :height, :rigid)

    # Hộp bao của thân tủ (không tính phần hông kéo xuống sàn / lên trần), dùng cho cánh, đợt, vách, ngăn kéo.
    # Cùng giao diện với BoundingBox ở những chỗ plugin cần: min, max, width, depth, height, center.
    BodyBounds = Struct.new(:min, :max) do
      def width; max.x - min.x; end
      def depth; max.y - min.y; end
      def height; max.z - min.z; end
      def center
        Geom::Point3d.new((min.x + max.x) / 2, (min.y + max.y) / 2, (min.z + max.z) / 2)
      end
    end

    # Thân tủ của một thùng tủ. Tủ cũ chưa lưu độ cao thân thì dùng luôn hộp bao của thùng tủ.
    # Chỉ tính các tấm VỎ TỦ (hông, nóc, đáy, hậu): đợt, vách, ngăn kéo, xà... nằm trong thùng tủ
    # không được làm "phình" thân tủ (trước đây mặt hộc làm thân tủ lùi ra trước 18.5 mm).
    CARCASS_ROLES = %w[side_left side_right top bottom back].freeze

    def body_bounds(shell)
      bounds = carcass_bounds(shell) || begin
        b = shell.definition.bounds
        [b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z]
      end
      data = ModelData.params(shell)
      z0 = data['body_z0_mm'] ? data['body_z0_mm'].to_f.mm : bounds[2]
      z1 = data['body_z1_mm'] ? data['body_z1_mm'].to_f.mm : bounds[5]
      # Luôn trả về BodyBounds (height = trục Z). BoundingBox thật của SketchUp có height = trục Y nên không dùng trực tiếp.
      BodyBounds.new(Geom::Point3d.new(bounds[0], bounds[1], z0), Geom::Point3d.new(bounds[3], bounds[4], z1))
    end

    # Hộp bao của các tấm vỏ tủ, hoặc nil nếu tủ không có tấm nào được gắn vai trò.
    def carcass_bounds(shell)
      box = nil
      shell.definition.entities.to_a.each do |entity|
        next unless (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)) && entity.valid?
        next unless entity.get_attribute(Schema::DICTIONARY, 'kind') == 'part'
        next unless CARCASS_ROLES.include?(ModelData.params(entity)['role'])
        b = entity.bounds
        values = [b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z]
        box = box ? (0..5).map { |i| i < 3 ? [box[i], values[i]].min : [box[i], values[i]].max } : values
      end
      box
    end

    def axis_vector(axis)
      { x: X_AXIS, y: Y_AXIS, z: Z_AXIS }.fetch(axis)
    end

    def box(entities, name, origin, x_axis, y_axis, width, depth, height, material = nil)
      group = entities.add_group
      group.name = name
      x0, y0, z0 = origin
      face = group.entities.add_face(
        [x0, y0, z0], [x0 + x_axis[0] * width, y0 + x_axis[1] * width, z0 + x_axis[2] * width],
        [x0 + x_axis[0] * width + y_axis[0] * depth, y0 + x_axis[1] * width + y_axis[1] * depth, z0 + x_axis[2] * width + y_axis[2] * depth],
        [x0 + y_axis[0] * depth, y0 + y_axis[1] * depth, z0 + y_axis[2] * depth]
      )
      raise 'Không tạo được mặt cấu kiện.' unless face
      face.reverse! if face.normal.z < 0
      face.pushpull(height)
      group.material = material if material
      group
    end

    def rectangular_board(entities, name, points, thickness, normal)
      group = entities.add_group
      group.name = name
      face = group.entities.add_face(points)
      raise "Không tạo được cấu kiện #{name}." unless face
      face.reverse! if face.normal.dot(normal) < 0
      face.pushpull(thickness)
      group
    end

    def stamp_part(group, role, data = {})
      ModelData.stamp(group, 'part', data.merge('role' => role.to_s))
      group.layer = tag(Schema::DEFAULTS['part_tag'])
      group
    end

    def tag(name)
      model = Sketchup.active_model
      model.layers[name] || model.layers.add(name)
    end

    # ---- Dùng chung component (chia sẻ definition cho các tấm giống hệt) ----

    # Tắt mặc định: việc đổi group thành component trong cùng một operation xóa các group vừa tạo,
    # làm các plugin khác đang lắng nghe onElementAdded (ví dụ VGD_Dim) bị lỗi "reference to deleted Group"
    # và khiến commit_operation ném lỗi. Bật lại bằng Geometry::SHARE_COMPONENTS = true khi cần.
    SHARE_COMPONENTS = false unless const_defined?(:SHARE_COMPONENTS, false)

    def share_components(root)
      cache = {}
      share_in(root.definition.entities, cache) if SHARE_COMPONENTS
      root.layer = tag(Schema::DEFAULTS['cabinet_tag'])
      root
    end

    def share_in(entities, cache)
      containers = entities.to_a.select { |entity| entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance) }
      containers.each do |entity|
        child_entities = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
        share_in(child_entities, cache) unless child_entities.length.zero?
      end
      groups = containers.select { |entity| entity.is_a?(Sketchup::Group) }
      groups.each do |group|
        normalize_group(group)
        key = component_signature(group)
        name = group.name
        # Chụp thuộc tính, tag, vật liệu trước khi thay group bằng component:
        # bản sao thứ hai trở đi nếu không được chép lại sẽ mất vai trò và thông số.
        saved = ModelData.snapshot(group)
        layer = group.layer
        material = group.material
        if (definition = cache[key])
          transformation = group.transformation
          group.erase!
          instance = entities.add_instance(definition, transformation)
          instance.name = name
          ModelData.restore(instance, saved)
          ModelData.new_id!(instance)
          instance.layer = layer if layer
          instance.material = material if material
          instance.set_attribute(Schema::DICTIONARY, 'component_shared', true)
        else
          instance = group.to_component
          instance.name = name
          instance.definition.name = "VGD CD | #{name}"
          ModelData.restore(instance, saved)
          cache[key] = instance.definition
        end
      end
    end

    def component_signature(group)
      pieces = [group.name]
      append_signature(group.definition.entities, Geom::Transformation.new, pieces, [])
      Digest::SHA256.hexdigest(pieces.join('|'))
    end

    def append_signature(entities, transform, pieces, ancestry)
      entities.each do |entity|
        if entity.is_a?(Sketchup::Face)
          pieces << 'F' << entity.area.to_f.round(4)
          pieces.concat(entity.vertices.map { |v| v.position.transform(transform).to_a.map { |n| n.to_f.round(4) }.join(',') }.sort)
        elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          definition = entity.definition
          next if ancestry.include?(definition)
          pieces << "I:#{entity.name}:#{definition.name}"
          append_signature(definition.entities, transform * entity.transformation, pieces, ancestry + [definition])
        end
      end
    end

    def normalize_group(group)
      origin = group.definition.bounds.min
      return if origin.x.abs < 1e-8 && origin.y.abs < 1e-8 && origin.z.abs < 1e-8
      shift = Geom::Transformation.translation([-origin.x, -origin.y, -origin.z])
      old_transform = group.transformation
      group.entities.transform_entities(shift, group.entities.to_a)
      group.transformation = old_transform * shift.inverse
    end

    def shell_for(root)
      return nil unless root && (root.is_a?(Sketchup::Group) || root.is_a?(Sketchup::ComponentInstance))
      root.definition.entities.to_a.find { |entity| (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)) && entity.name == 'Thùng tủ' }
    end

    # ---- Hệ trục và kích thước của tủ dựng từ box ----

    # Chiếu vectơ mặt trước xuống mặt phẳng ngang. Ném ArgumentError nếu đó là mặt trên/dưới.
    def horizontal_front(vector)
      raw = Geom::Vector3d.new(*vector.to_a)
      if raw.length < 1e-9 || raw.z.abs / raw.length > 0.1
        raise ArgumentError, 'Mặt trước phải là một mặt đứng của box (không phải mặt trên hoặc mặt dưới).'
      end
      flat = Geom::Vector3d.new(raw.x, raw.y, 0)
      flat.normalize!
      flat
    end

    # Tách phép biến đổi của box thành phần cứng (xoay + vị trí, không scale) và hệ số scale theo ba trục cục bộ.
    # Tủ dựng theo kích thước thật sau scale với phép biến đổi cứng, nên ván luôn đúng độ dày.
    # Từ chối box bị lật (mirror) hoặc bị xiên (shear), vì khi đó không có kích thước thật rõ ràng.
    def rigid_of(entity)
      tr = entity.transformation
      vx = X_AXIS.transform(tr)
      vy = Y_AXIS.transform(tr)
      vz = Z_AXIS.transform(tr)
      scales = [vx.length, vy.length, vz.length]
      raise ArgumentError, 'Box có tỷ lệ bằng 0 trên một trục nên không dựng được tủ.' if scales.any? { |v| v < 1e-9 }
      ux = vx.normalize
      uy = vy.normalize
      uz = vz.normalize
      if [ux.dot(uy), ux.dot(uz), uy.dot(uz)].any? { |v| v.abs > 1e-4 }
        raise ArgumentError, 'Box bị xiên (shear) do scale sau khi xoay. Hãy Explode rồi Make Group lại trước khi chuyển thành tủ.'
      end
      if ux.cross(uy).dot(uz) < 0
        raise ArgumentError, 'Box đang bị lật gương (mirror / scale âm). Hãy Explode rồi Make Group lại trước khi chuyển thành tủ.'
      end
      origin = Geom::Point3d.new(0, 0, 0).transform(tr)
      [Geom::Transformation.axes(origin, ux, uy, uz), scales]
    end

    def cabinet_frame(box_entity, front_vector)
      rigid, scales = rigid_of(box_entity)
      front = horizontal_front(front_vector)
      up = Z_AXIS
      width_axis = up.cross(front)
      width_axis.normalize!
      depth_axis = front.reverse
      corners = (0..7).map do |index|
        corner = box_entity.definition.bounds.corner(index)
        Geom::Point3d.new(corner.x * scales[0], corner.y * scales[1], corner.z * scales[2])
      end
      project = ->(point, axis) { point.x * axis.x + point.y * axis.y + point.z * axis.z }
      xs = corners.map { |point| project.call(point, width_axis) }
      ys = corners.map { |point| project.call(point, depth_axis) }
      zs = corners.map { |point| project.call(point, up) }
      x0, x1 = xs.min, xs.max
      y0, y1 = ys.min, ys.max
      z0, z1 = zs.min, zs.max
      origin = Geom::Point3d.new(
        width_axis.x * x0 + depth_axis.x * y0 + up.x * z0,
        width_axis.y * x0 + depth_axis.y * y0 + up.y * z0,
        width_axis.z * x0 + depth_axis.z * y0 + up.z * z0
      )
      Frame.new(front, width_axis, depth_axis, up, origin, (x1 - x0).to_mm, (y1 - y0).to_mm, (z1 - z0).to_mm, rigid)
    end

    # Vẽ preview thùng tủ. Trả về nil nếu thành công, hoặc thông báo lỗi (tiếng Việt) nếu không dựng được.
    # kind: :body (cyan) hoặc :override (xanh lá). parent_transform: phép biến đổi của các group cha của box.
    def preview_cabinet(box_entity, front_vector, options, preview, kind = :body, parent_transform = nil)
      frame = cabinet_frame(box_entity, front_vector)
      result = PanelModel.compute(frame.width, frame.depth, frame.height, Schema.merge_settings(options))
      axes = Geom::Transformation.axes(frame.origin, frame.width_axis, frame.depth_axis, frame.up)
      transform = (parent_transform || Geom::Transformation.new) * frame.rigid * axes
      to_world = lambda { |face| face.map { |x, y, z| Geom::Point3d.new(x.mm, y.mm, z.mm).transform(transform) } }
      (result.parts + result.trim).each do |part|
        PanelModel.box_faces(part.bounds).each { |face| preview.add_polygon(to_world.call(face), kind) }
      end
      preview.add_polygon(to_world.call(PanelModel.front_face(frame.width, frame.height)), :front)
      PanelModel.box_faces(result.reference).each { |face| preview.add_polygon(to_world.call(face), :target) } if result.reference
      nil
    rescue ArgumentError => e
      e.message
    end

    # Dựng một tấm từ mô tả của PanelModel: một group riêng, đa giác phẳng rồi đẩy khối.
    def build_part(entities, part, extra = {})
      group = entities.add_group
      group.name = part.name
      points = part.points.map { |x, y, z| Geom::Point3d.new(x.mm, y.mm, z.mm) }
      face = group.entities.add_face(points)
      raise "Không dựng được tấm #{part.name}." unless face
      face.reverse! if face.normal.dot(axis_vector(part.axis)) < 0
      face.pushpull(part.distance.mm)
      stamp_part(group, part.role, { 'thickness_mm' => part.thickness, 'grooved' => part.grooved }.merge(extra))
      stamp_signature(group)
      group
    end

    # Chữ ký hình học của một tấm (hộp bao 0.1 mm + số mặt). Lưu lúc plugin dựng; lúc sửa tủ so lại để biết
    # tấm có bị chỉnh tay (kéo, khoét, sửa hình) hay không.
    def signature(group)
      b = group.bounds
      box = [b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z].map { |v| (v.to_mm * 10).round }
      faces = group.definition.entities.to_a.count { |e| e.is_a?(Sketchup::Face) }
      (box + [faces]).join(',')
    end

    def stamp_signature(group)
      group.set_attribute(Schema::DICTIONARY, 'geo_sig', signature(group))
      group
    end

    def hand_edited?(group)
      saved = group.get_attribute(Schema::DICTIONARY, 'geo_sig')
      return true if group.get_attribute(Schema::DICTIONARY, 'notched')
      saved ? saved != signature(group) : nil
    end

    # Hộp tham chiếu tủ lạnh (khung dây + mặt mờ, tag riêng để ẩn/hiện). Không phải tấm ván, không vào bóc khối lượng.
    def add_reference(root, shell, box)
      group = root.entities.add_group
      group.name = 'Tủ lạnh (tham chiếu)'
      group.transformation = shell.transformation
      x0, y0, z0, x1, y1, z1 = box.map { |v| v.mm }
      face = group.entities.add_face([[x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0]])
      face.reverse! if face.normal.z < 0
      face.pushpull(z1 - z0)
      ModelData.stamp(group, 'fridge_reference', { 'width_mm' => (box[3] - box[0]), 'depth_mm' => (box[4] - box[1]), 'height_mm' => (box[5] - box[2]) })
      group.layer = tag('VGD_CD_REFERENCE')
      group
    end

    # Dựng các tấm vỏ tủ + chân/phào + khối tham chiếu và ghi dữ liệu tủ. Dùng khi tạo tủ và khi sửa tủ.
    # skip_roles: vai trò không dựng lại (tấm chỉnh tay người dùng muốn giữ).
    def build_carcass(root, shell, result, settings, width, depth, height, extra_data = {}, skip_roles = [])
      result.parts.each do |part|
        next if skip_roles.include?(part.role)
        extra = part.role == 'back' ? { 'mode' => settings['back_mode'] } : {}
        build_part(shell.entities, part, extra)
      end
      # Độ cao thân tủ (đáy tới nóc): hông có thể kéo xuống sàn / lên trần nên hộp bao thùng tủ cao hơn thân tủ.
      strip = result.resolved['ceiling_strip_height'].to_f
      # Thân tủ bắt đầu ở chân cao; thùng tủ lạnh: bắt đầu ở đáy hộc trên (phần dưới là chỗ đặt tủ lạnh).
      body_z0 = (result.resolved['body_z0_mm'] || result.resolved['leg_height']).to_f
      ModelData.stamp(shell, 'shell', { 'front_axis' => (extra_data['front_normal'] || ModelData.params(root)['front_normal']),
                                        'body_z0_mm' => body_z0, 'body_z1_mm' => height - strip,
                                        'cabinet_type' => result.resolved['cabinet_type'] })
      add_reference(root, shell, result.reference) if result.reference
      unless result.trim.empty?
        trim = root.entities.add_group
        trim.name = 'Chân & phào'
        trim.transformation = shell.transformation
        result.trim.each { |part| build_part(trim.entities, part) }
        ModelData.stamp(trim, 'trim', {})
      end
      old = ModelData.params(root)
      keep = old.select { |key, _| %w[front_normal local_axes].include?(key) }
      # 'panels_input' = cấu hình tấm như người dùng nhập (độ dày trống = theo dày ván chung) để Sửa tủ đổi dày ván đúng.
      data = settings.reject { |key, _| key == 'panels' }.merge(keep).merge(extra_data).merge('panels_input' => settings['panels']).merge(
        'width_mm' => width, 'depth_mm' => depth, 'height_mm' => height, 'panel_spec' => result.resolved
      )
      ModelData.stamp(root, 'cabinet', data)
      root
    end

    # Chuyển một box thành thùng tủ. Mọi kiểm tra đầu vào chạy TRƯỚC khi chạm vào model.
    def cabinet_from_box(box_entity, options = {})
      settings = Schema.merge_settings(options)
      frame = cabinet_frame(box_entity, options['front_normal'] || [0, -1, 0])
      result = PanelModel.compute(frame.width, frame.depth, frame.height, settings)

      # Tạo tủ cùng cấp với box (kể cả box nằm trong group cha chưa mở), không dùng active_entities.
      root = box_entity.parent.entities.add_group
      root.name = 'VGD Cabinet Draw · Cabinet'
      root.transformation = frame.rigid
      shell = root.entities.add_group
      shell.name = 'Thùng tủ'
      shell.transformation = Geom::Transformation.axes(frame.origin, frame.width_axis, frame.depth_axis, frame.up)
      build_carcass(root, shell, result, settings, frame.width, frame.depth, frame.height,
                    'front_normal' => frame.front.to_a,
                    'local_axes' => { 'width' => frame.width_axis.to_a, 'depth' => frame.depth_axis.to_a, 'up' => frame.up.to_a })
      box_entity.erase! if options['remove_source'] == true
      root
    end
  end
end
