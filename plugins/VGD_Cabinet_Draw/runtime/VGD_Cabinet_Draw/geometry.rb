require 'digest'
module VGD_Cabinet_Draw
  module Geometry
    extend self
    MM = 1.mm

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

    def stamp_part(group,role,data={})
      ModelData.stamp(group,'part',data.merge('role'=>role.to_s))
      group.layer=tag(Schema::DEFAULTS['part_tag'])
      group
    end

    def tag(name)
      model=Sketchup.active_model
      model.layers[name] || model.layers.add(name)
    end

    def share_components(root)
      cache={}
      share_in(root.definition.entities,cache)
      root.layer=tag(Schema::DEFAULTS['cabinet_tag'])
      root
    end

    def share_in(entities,cache)
      containers=entities.to_a.select { |entity| entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance) }
      containers.each do |entity|
        child_entities=entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
        share_in(child_entities,cache) unless child_entities.length.zero?
      end
      groups=containers.select { |entity| entity.is_a?(Sketchup::Group) }
      groups.each do |group|
        normalize_group(group)
        key=component_signature(group)
        if (definition=cache[key])
          transformation=group.transformation
          name=group.name
          group.erase!
          instance=entities.add_instance(definition,transformation)
          instance.name=name
          instance.set_attribute(Schema::DICTIONARY,'component_shared',true)
        else
          name=group.name
          instance=group.to_component
          instance.name=name
          instance.definition.name="VGD CD | #{name}"
          cache[key]=instance.definition
        end
      end
    end

    def component_signature(group)
      pieces=[group.name]
      append_signature(group.definition.entities,Geom::Transformation.new,pieces,[])
      Digest::SHA256.hexdigest(pieces.join('|'))
    end

    def append_signature(entities,transform,pieces,ancestry)
      entities.each do |entity|
        if entity.is_a?(Sketchup::Face)
          pieces << 'F' << entity.area.to_f.round(4)
          pieces.concat(entity.vertices.map { |v| v.position.transform(transform).to_a.map { |n| n.to_f.round(4) }.join(',') }.sort)
        elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          definition=entity.definition
          next if ancestry.include?(definition)
          pieces << "I:#{entity.name}:#{definition.name}"
          append_signature(definition.entities,transform*entity.transformation,pieces,ancestry+[definition])
        end
      end
    end

    def normalize_group(group)
      origin=group.definition.bounds.min
      return if origin.x.abs<1e-8 && origin.y.abs<1e-8 && origin.z.abs<1e-8
      shift=Geom::Transformation.translation([-origin.x,-origin.y,-origin.z])
      old_transform=group.transformation
      group.entities.transform_entities(shift,group.entities.to_a)
      group.transformation=old_transform*shift.inverse
    end

    def shell_for(root)
      return nil unless root && (root.is_a?(Sketchup::Group) || root.is_a?(Sketchup::ComponentInstance))
      root.definition.entities.to_a.find { |entity| (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)) && entity.name == 'Thùng tủ' }
    end

    def preview_cabinet(box_entity,front_vector,options,preview)
      bounds=box_entity.definition.bounds
      front=Geom::Vector3d.new(front_vector); front.normalize!
      up=Z_AXIS; width_axis=up.cross(front); width_axis.normalize!; depth_axis=front.reverse
      corners=(0..7).map { |i| bounds.corner(i) }
      project=lambda { |p,v| p.x*v.x+p.y*v.y+p.z*v.z }
      xs=corners.map { |p| project.call(p,width_axis) }; ys=corners.map { |p| project.call(p,depth_axis) }; zs=corners.map { |p| project.call(p,up) }
      x0,x1=xs.min,xs.max; y0,y1=ys.min,ys.max; z0,z1=zs.min,zs.max
      t=options.fetch('board_thickness',17.5).to_f.mm; bt=options.fetch('back_thickness',6).to_f.mm
      transform=box_entity.transformation*Geom::Transformation.axes(ORIGIN,width_axis,depth_axis,up)
      emit=lambda { |pts| preview.add_polygon(pts.map { |p| Geom::Point3d.new(p).transform(transform) },:body) }
      emit.call([[x0,y0,z0],[x0,y1-bt,z0],[x0,y1-bt,z1],[x0,y0,z1]])
      emit.call([[x1-t,y0,z0],[x1-t,y0,z1],[x1-t,y1-bt,z1],[x1-t,y1-bt,z0]])
      emit.call([[x0+t,y0,z0+t],[x1-t,y0,z0+t],[x1-t,y1-bt,z0+t],[x0+t,y1-bt,z0+t]])
      emit.call([[x0+t,y0,z1-t],[x0+t,y1-bt,z1-t],[x1-t,y1-bt,z1-t],[x1-t,y0,z1-t]])
      if options['back_mode']!='none'
        emit.call([[x0+t,y1-bt,z0+t],[x1-t,y1-bt,z0+t],[x1-t,y1-bt,z1-t],[x0+t,y1-bt,z1-t]])
      end
      true
    end

    def cabinet_from_box(box_entity, options = {})
      model = Sketchup.active_model
      bounds = box_entity.definition.bounds
      thickness = (options['board_thickness'] || Schema::DEFAULTS['board_thickness']).to_f.mm
      back_t = (options['back_thickness'] || Schema::DEFAULTS['back_thickness']).to_f.mm
      front = Geom::Vector3d.new(options['front_normal'] || [0, -1, 0])
      raise 'Mặt trước phải là một mặt đứng của box.' if front.parallel?(Z_AXIS)
      front.normalize!
      up = Z_AXIS
      width_axis = up.cross(front)
      width_axis.normalize!
      depth_axis = front.reverse
      corners = (0..7).map { |index| bounds.corner(index) }
      project = lambda do |point, axis|
        point.x * axis.x + point.y * axis.y + point.z * axis.z
      end
      xs = corners.map { |point| project.call(point, width_axis) }
      ys = corners.map { |point| project.call(point, depth_axis) }
      zs = corners.map { |point| project.call(point, up) }
      x0, x1 = xs.min, xs.max
      y0, y1 = ys.min, ys.max
      z0, z1 = zs.min, zs.max
      width, depth, height = (x1-x0).to_mm, (y1-y0).to_mm, (z1-z0).to_mm
      raise 'Kích thước box không đủ cho tủ.' if width <= thickness * 2 || depth <= back_t + thickness || height <= thickness * 2
      root = model.active_entities.add_group
      root.name = 'VGD Cabinet Draw · Cabinet'
      root.transformation = box_entity.transformation
      shell = root.entities.add_group
      shell.name = 'Thùng tủ'
      shell.transformation = Geom::Transformation.axes(ORIGIN, width_axis, depth_axis, up)
      e = shell.entities
      back_mode=options.fetch('back_mode','groove')
      groove_depth=options.fetch('back_groove_depth',8.75).to_f.mm
      rear_y=back_mode=='none' ? y1 : y1-back_t
      e.add_group.tap do |g|
        g.name = 'Hông Trái'
        profile=if back_mode=='groove'
          [[x0,y0,z0],[x0+t,y0,z0],[x0+t,y1-back_t,z0],[x0+t-groove_depth,y1-back_t,z0],[x0+t-groove_depth,y1,z0],[x0,y1,z0]]
        else
          [[x0,y0,z0],[x0+t,y0,z0],[x0+t,rear_y,z0],[x0,rear_y,z0]]
        end
        f = g.entities.add_face(profile)
        f.reverse! if f.normal.z < 0
        f.pushpull(z1-z0)
        stamp_part(g,'side_left',{'thickness_mm'=>thickness.to_mm})
      end
      e.add_group.tap do |g|
        g.name = 'Hông Phải'
        x = x1 - thickness
        profile=if back_mode=='groove'
          [[x,y0,z0],[x1,y0,z0],[x1,y1,z0],[x+groove_depth,y1,z0],[x+groove_depth,y1-back_t,z0],[x,y1-back_t,z0]]
        else
          [[x,y0,z0],[x1,y0,z0],[x1,rear_y,z0],[x,rear_y,z0]]
        end
        f = g.entities.add_face(profile)
        f.reverse! if f.normal.z < 0
        f.pushpull(z1-z0)
        stamp_part(g,'side_right',{'thickness_mm'=>thickness.to_mm})
      end
      e.add_group.tap do |g|
        g.name = 'Đáy'
        f = g.entities.add_face([[x0+thickness,y0,z0],[x1-thickness,y0,z0],[x1-thickness,rear_y,z0],[x0+thickness,rear_y,z0]])
        f.reverse! if f.normal.z < 0
        f.pushpull(thickness)
        stamp_part(g,'bottom',{'thickness_mm'=>thickness.to_mm})
      end
      e.add_group.tap do |g|
        g.name = 'Nóc'
        z = z1-thickness
        f = g.entities.add_face([[x0+thickness,y0,z],[x0+thickness,rear_y,z],[x1-thickness,rear_y,z],[x1-thickness,y0,z]])
        f.reverse! if f.normal.z < 0
        f.pushpull(thickness)
        stamp_part(g,'top',{'thickness_mm'=>thickness.to_mm})
      end
      if back_mode != 'none'
        e.add_group.tap do |g|
          g.name = 'Hậu'
          f = g.entities.add_face([[x0+thickness,y1-back_t,z0+thickness],[x1-thickness,y1-back_t,z0+thickness],[x1-thickness,y1-back_t,z1-thickness],[x0+thickness,y1-back_t,z1-thickness]])
          f.reverse! if f.normal.y < 0
          f.pushpull(back_t)
          stamp_part(g,'back',{'thickness_mm'=>back_t.to_mm,'mode'=>back_mode,'groove_depth_mm'=>groove_depth.to_mm})
        end
      end
      ModelData.stamp(shell,'shell',{'front_axis'=>front.to_a})
      box_entity.erase! if options['remove_source'] == true
      ModelData.stamp(root, 'cabinet', options.merge('width_mm'=>width,'depth_mm'=>depth,'height_mm'=>height,'front_normal'=>front.to_a,'local_axes'=>{'width'=>width_axis.to_a,'depth'=>depth_axis.to_a,'up'=>up.to_a}))
      root
    rescue StandardError
      raise
    end
  end
end
