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

    # Danh sách các khối của một cánh, KHÔNG chạm vào model. Cả preview lẫn build dùng chung hàm này
    # nên hình xem trước luôn trùng kết quả. Mỗi khối: { name, polygon [[x,z]...], y, depth, kind (:door|:glass) }.
    # Khối đẩy từ mặt phẳng y ra phía trước (hướng -Y), tức chiếm khoảng [y - depth, y].
    def parts(bounds, settings)
      x0, x1 = bounds[:x0], bounds[:x1]
      z0, z1 = bounds[:z0], bounds[:z1]
      y = bounds[:y]
      depth = settings.fetch('board_thickness', 17.5).to_f.mm
      style = settings.fetch('door_style', 'flat')
      rect = lambda { |a0, a1, c0, c1| [[a0, c0], [a1, c0], [a1, c1], [a0, c1]] }
      list = []
      if style == 'flat'
        list << { name: 'Cánh phẳng', polygon: rect.call(x0, x1, z0, z1), y: y, depth: depth, kind: :door }
        return list
      end
      frame_width = settings.fetch('frame_width', 60).to_f.mm
      rail_width = settings.fetch('rail_width', 60).to_f.mm
      raise 'Khung cánh quá rộng so với ô cánh.' if x1 - x0 <= frame_width * 2 || z1 - z0 <= rail_width * 2
      joint = settings.fetch('frame_joint', 'vertical')
      frame_polygons(x0, x1, z0, z1, frame_width, rail_width, joint).each do |part, polygon|
        list << { name: part, polygon: polygon, y: y, depth: depth, kind: :door }
      end
      ix0, ix1 = x0 + frame_width, x1 - frame_width
      iz0, iz1 = z0 + rail_width, z1 - rail_width
      if style == 'glass'
        glass_t = settings.fetch('glass_thickness', 5).to_f.mm
        layout = pane_layout(ix0, ix1, iz0, iz1, settings)
        # Kính nằm giữa bề dày cánh: chiếm [y - depth/2 - glass_t/2, y - depth/2 + glass_t/2].
        layout[:panes].each_with_index do |r, i|
          list << { name: "Tấm kính #{i + 1}", polygon: rect.call(r[0], r[1], r[2], r[3]), y: y - depth / 2 + glass_t / 2, depth: glass_t, kind: :glass }
        end
        layout[:bars].each_with_index do |r, i|
          list << { name: "Đố kính #{i + 1}", polygon: rect.call(r[0], r[1], r[2], r[3]), y: y, depth: depth, kind: :door }
        end
      else
        recess = settings.fetch('panel_recess', 8).to_f.mm
        panel_depth = [depth - [recess, depth - 1.mm].min, 1.mm].max
        # Pano lõm: phẳng mặt sau cánh (y), lõm vào so với mặt trước một đoạn recess.
        list << { name: style == 'shaker' ? 'Pano Shaker' : 'Panel âm', polygon: rect.call(ix0, ix1, iz0, iz1), y: y, depth: panel_depth, kind: :door }
      end
      list
    end

    def build(entities, bounds, name, settings)
      door = entities.add_group
      door.name = name
      glass = nil
      parts(bounds, settings).each do |part|
        if part[:kind] == :glass
          glass ||= door.entities.add_group.tap { |g| g.name = 'Kính' }
          pane = prism_y(glass.entities, part[:name], part[:polygon], part[:y], part[:depth])
          pane.material = glass_material
        else
          prism_y(door.entities, part[:name], part[:polygon], part[:y], part[:depth])
        end
      end
      glass.material = glass_material if glass
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
      # Đố ngang chỉ nằm giữa các đố dọc (không chồng lên nhau ở chỗ giao, tránh thừa khối lượng).
      (1...rows).each do |row|
        z=z0+row*pane_h+(row-0.5)*bar
        columns.times do |column|
          left=x0+column*(pane_w+bar)
          bars << [left,left+pane_w,z-bar/2,z+bar/2]
        end
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
