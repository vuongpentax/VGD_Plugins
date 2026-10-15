module VGD_Cabinet_Draw
  module DoorGeometry
    extend self

    def prism_y(entities, name, polygon, y, depth, material = nil)
      group = entities.add_group
      group.name = name
      points = polygon.map { |x, z| [x, y, z] }
      face = group.entities.add_face(points)
      raise "Không dựng được #{name}." unless face
      face.reverse! if face.normal.y > 0
      face.pushpull(depth)
      group.material = material if material
      group
    end

    def rectangle(entities, name, x0, x1, z0, z1, y, depth, material = nil)
      prism_y(entities, name, [[x0,z0],[x1,z0],[x1,z1],[x0,z1]], y, depth, material)
    end

    def build(entities, bounds, name, settings)
      door = entities.add_group
      door.name = name
      x0, x1 = bounds[:x0], bounds[:x1]
      z0, z1 = bounds[:z0], bounds[:z1]
      y = bounds[:y]
      depth = settings.fetch('board_thickness', 17.5).to_f.mm
      style = settings.fetch('door_style', 'flat')
      if style == 'flat'
        rectangle(door.entities, 'Cánh phẳng', x0, x1, z0, z1, y, depth)
      else
        frame_width = settings.fetch('frame_width', 60).to_f.mm
        rail_width = settings.fetch('rail_width', 60).to_f.mm
        raise 'Khung cánh quá rộng so với ô cánh.' if x1-x0 <= frame_width*2 || z1-z0 <= rail_width*2
        joint = settings.fetch('frame_joint', 'vertical')
        members = frame_polygons(x0,x1,z0,z1,frame_width,rail_width,joint)
        members.each_with_index { |(part, polygon), index| prism_y(door.entities, part, polygon, y, depth) }
        inner_x0, inner_x1 = x0+frame_width, x1-frame_width
        inner_z0, inner_z1 = z0+rail_width, z1-rail_width
        if style == 'glass'
          glass_t = settings.fetch('glass_thickness', 5).to_f.mm
          glass = door.entities.add_group
          glass.name = 'Kính'
          layout = pane_layout(inner_x0,inner_x1,inner_z0,inner_z1,settings)
          layout[:panes].each_with_index do |rect,index|
            pane = rectangle(glass.entities, "Tấm kính #{index+1}", rect[0],rect[1],rect[2],rect[3],y+depth/2-glass_t/2,glass_t)
            pane.material = glass_material
          end
          layout[:bars].each_with_index do |rect,index|
            rectangle(door.entities, "Đố kính #{index+1}", rect[0],rect[1],rect[2],rect[3],y,depth)
          end
          glass.material = glass_material
        else
          recess = settings.fetch('panel_recess', 8).to_f.mm
          panel_y = y + (depth - [recess, depth-1.mm].min)
          panel_depth = [depth-recess, 1.mm].max
          rectangle(door.entities, style == 'shaker' ? 'Pano Shaker' : 'Panel âm', inner_x0,inner_x1,inner_z0,inner_z1,panel_y,panel_depth)
        end
      end
      door
    end

    def frame_polygons(x0,x1,z0,z1,side,rail,joint)
      if joint == 'miter'
        [
          ['Khung Hông Trái', [[x0,z0],[x0+side,z0+rail],[x0+side,z1-rail],[x0,z1]]],
          ['Khung Hông Phải', [[x1,z0],[x1,z1],[x1-side,z1-rail],[x1-side,z0+rail]]],
          ['Khung Dưới', [[x0,z0],[x1,z0],[x1-side,z0+rail],[x0+side,z0+rail]]],
          ['Khung Trên', [[x0,z1],[x0+side,z1-rail],[x1-side,z1-rail],[x1,z1]]]
        ]
      elsif joint == 'horizontal'
        [
          ['Khung Hông Trái', [[x0,z0+rail],[x0+side,z0+rail],[x0+side,z1-rail],[x0,z1-rail]]],
          ['Khung Hông Phải', [[x1-side,z0+rail],[x1,z0+rail],[x1,z1-rail],[x1-side,z1-rail]]],
          ['Khung Dưới', [[x0,z0],[x1,z0],[x1,z0+rail],[x0,z0+rail]]],
          ['Khung Trên', [[x0,z1-rail],[x1,z1-rail],[x1,z1],[x0,z1]]]
        ]
      else
        [
          ['Khung Hông Trái', [[x0,z0],[x0+side,z0],[x0+side,z1],[x0,z1]]],
          ['Khung Hông Phải', [[x1-side,z0],[x1,z0],[x1,z1],[x1-side,z1]]],
          ['Khung Dưới', [[x0+side,z0],[x1-side,z0],[x1-side,z0+rail],[x0+side,z0+rail]]],
          ['Khung Trên', [[x0+side,z1-rail],[x1-side,z1-rail],[x1-side,z1],[x0+side,z1]]]
        ]
      end
    end

    def pane_layout(x0,x1,z0,z1,settings)
      rows = settings.fetch('glass_rows',1).to_i.clamp(1,8)
      columns = settings.fetch('glass_columns',1).to_i.clamp(1,8)
      bar = settings.fetch('glass_bar_width',20).to_f.mm
      pane_w = (x1-x0-bar*(columns-1))/columns.to_f
      pane_h = (z1-z0-bar*(rows-1))/rows.to_f
      raise 'Ô kính quá nhỏ; giảm số hàng/cột hoặc bản thanh chia.' if pane_w <= 10.mm || pane_h <= 10.mm
      panes = []
      rows.times do |row|
        columns.times do |column|
          left=x0+column*(pane_w+bar); bottom=z0+row*(pane_h+bar)
          panes << [left,left+pane_w,bottom,bottom+pane_h]
        end
      end
      bars = []
      (1...columns).each do |column|
        x=x0+column*pane_w+(column-0.5)*bar
        bars << [x-bar/2,x+bar/2,z0,z1]
      end
      (1...rows).each do |row|
        z=z0+row*pane_h+(row-0.5)*bar
        bars << [x0,x1,z-bar/2,z+bar/2]
      end
      {panes:panes,bars:bars}
    end

    def glass_material
      model=Sketchup.active_model
      name='VGD Cabinet Draw | Kính'
      material=model.materials[name] || model.materials.add(name)
      material.color=Sketchup::Color.new(125,195,206)
      material.alpha=0.42
      material
    end
  end
end
