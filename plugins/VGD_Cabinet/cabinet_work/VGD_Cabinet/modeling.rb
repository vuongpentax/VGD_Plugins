# frozen_string_literal: true
require_relative 'pano'
require_relative 'component_sharing'
require_relative 'frame_divisions'
require_relative 'rail_joinery'
module VGD_Cabinet
  module Modeling
    module_function
    def context_model
      Thread.current[:vgd_cabinet_preview_model] || Sketchup.active_model
    end
    def metal_glass?(p)
      p['door_style'] == 'Kính khung kim loại'
    end
    def door_depth_mm(p)
      return p['pano_depth'].to_f if ['Pano khung gỗ','Shaker'].include?(p['door_style']) && p['opt_door']!='Không Cánh' && !p['is_full_drawer']
      return p['wood_carved_thickness'].to_f if p['door_style']=='Cánh soi' && p['opt_door']!='Không Cánh' && !p['is_full_drawer']
      return p['wood_bevel_thickness'].to_f if p['door_style']=='Cánh soi vát 4 cạnh' && p['opt_door']!='Không Cánh' && !p['is_full_drawer']
      return p['wood_glass_frame_thickness'].to_f if p['door_style']=='Cánh kính bo góc' && p['opt_door']!='Không Cánh' && !p['is_full_drawer']
      metal_glass?(p) && p['opt_door'] != 'Không Cánh' && !p['is_full_drawer'] ? p['metal_frame_depth'].to_f : p['t'].to_f
    end
    def concept_material(name, rgb, alpha=1.0)
      materials = context_model.materials
      # Reuse existing swatches without overwriting colors edited by the user.
      return materials[name] if materials[name]
      legacy = name.sub('VGD Khung ', 'VGD Concept | Khung | ').sub('VGD Kính ', 'VGD Concept | Kính | ')
      if materials[legacy]
        material = materials[legacy]
        material.name = name
        return material
      end
      material = materials.add(name)
      material.color = Sketchup::Color.new(*rgb)
      material.alpha = alpha
      material
    end
    def concept_box(entities, x, y, z, w, depth, height, material)
      face = entities.add_face([[x,y,z],[x+w,y,z],[x+w,y+depth,z],[x,y+depth,z]])
      raise 'Không dựng được phần cánh concept.' unless face
      face.reverse! if face.normal.z < 0
      face.pushpull(height)
    end
    def separate_metal_frame(entities,x,width,depth,height,border,glass_t,layout,metal,glass,p)
      frame=entities.add_group; frame.name='Khung Kim Loại'; frame.material=metal
      members=if p['frame_joint']=='Chéo'
        [['Khung Kim Loại Hông Trái',[[x,0],[x+border,border],[x+border,height-border],[x,height]]],
         ['Khung Kim Loại Hông Phải',[[x+width,0],[x+width-border,border],[x+width-border,height-border],[x+width,height]]],
         ['Khung Kim Loại Dưới',[[x,0],[x+width,0],[x+width-border,border],[x+border,border]]],
         ['Khung Kim Loại Trên',[[x,height],[x+width,height],[x+width-border,height-border],[x+border,height-border]]]]
      elsif p['frame_joint']=='Ngang'
        [['Khung Kim Loại Hông Trái',[[x,border],[x+border,border],[x+border,height-border],[x,height-border]]],
         ['Khung Kim Loại Hông Phải',[[x+width-border,border],[x+width,border],[x+width,height-border],[x+width-border,height-border]]],
         ['Khung Kim Loại Dưới',[[x,0],[x+width,0],[x+width,border],[x,border]]],
         ['Khung Kim Loại Trên',[[x,height-border],[x+width,height-border],[x+width,height],[x,height]]]]
      else
        [['Khung Kim Loại Hông Trái',[[x,0],[x+border,0],[x+border,height],[x,height]]],
         ['Khung Kim Loại Hông Phải',[[x+width-border,0],[x+width,0],[x+width,height],[x+width-border,height]]],
         ['Khung Kim Loại Dưới',[[x+border,0],[x+width-border,0],[x+width-border,border],[x+border,border]]],
         ['Khung Kim Loại Trên',[[x+border,height-border],[x+width-border,height-border],[x+width-border,height],[x+border,height]]]]
      end
      members.each do |name,poly|
        piece=frame.entities.add_group; piece.name=name; piece.material=metal
        framed_polygon(piece.entities,poly,0,0,0,depth,metal)
      end
      layout[:bars].each_with_index do |poly,index|
        division=p['frame_division']=='Ngang' ? 'Ngang' : 'Dọc'
        positioned=poly.map { |px,pz| [x+border+px,border+pz] }
        piece=frame.entities.add_group; piece.name="Thanh Chia #{division} #{index+1}"; piece.material=metal
        framed_polygon(piece.entities,positioned,0,0,0,depth,metal)
      end
      panes=entities.add_group; panes.name='Kính'; panes.material=glass
      layout[:panels].each_with_index do |poly,index|
        pane=panes.entities.add_group; pane.name="Tấm Kính #{index+1}"; pane.material=glass
        framed_polygon(pane.entities,poly,x+border,border,(depth-glass_t)/2,glass_t,glass)
      end
      frame
    end
    def door_front(entities, x, width, depth, height, p)
      return pano_front(entities,x,width,depth,height,p) if ['Pano khung gỗ','Shaker'].include?(p['door_style'])
      return carved_front(entities,x,width,depth,height,p) if p['door_style']=='Cánh soi'
      return beveled_front(entities,x,width,depth,height,p) if p['door_style']=='Cánh soi vát 4 cạnh'
      return wooden_glass_front(entities,x,width,depth,height,p) if p['door_style']=='Cánh kính bo góc'
      return front_solid(entities,x,width,depth,height,p) unless metal_glass?(p)
      border = p['metal_frame_width'].to_f.mm
      glass_t = p['glass_thickness'].to_f.mm
      if width <= 2*border + 0.1.mm || height <= 2*border + 0.1.mm
        raise ModelingRules::Invalid, 'Bản khung quá lớn: cánh phải còn ô kính rộng và cao lớn hơn 0,1 mm.'
      end
      raise ModelingRules::Invalid, 'Kính không được dày hơn khung.' if glass_t > depth
      metal_colors = {'Đen'=>[40,40,40], 'Champagne'=>[190,166,124], 'Inox'=>[180,185,190]}
      glass_colors = {'Trong'=>[210,232,235], 'Trà'=>[142,105,73], 'Xám'=>[115,128,140]}
      metal = concept_material("VGD Khung #{p['metal_finish']}",metal_colors.fetch(p['metal_finish']))
      glass = concept_material("VGD Kính #{p['glass_finish']}",glass_colors.fetch(p['glass_finish']),0.30)
      bar_width=p['frame_bar_width'].to_f>0 ? p['frame_bar_width'].mm : border
      layout=FrameDivisions.layout(width-2*border,height-2*border,bar_width,p['frame_division'],p['frame_sections'].to_i)
      return separate_metal_frame(entities,x,width,depth,height,border,glass_t,layout,metal,glass,p)
    end
    def framed_polygon(entities,poly,x,z,y,depth,material)
      face=entities.add_face(poly.map { |px,pz| [x+px,y,z+pz] })
      raise ModelingRules::Invalid,'Không dựng được ô chia khung.' unless face
      face.reverse! if face.normal.y<0
      face.pushpull(depth)
    end
    def front_solid(entities, x, dx, dy, dz, p)
      if p['front_bevel']
        cut = dy - p['bevel_lip'].to_f.mm
        raise ModelingRules::Invalid, 'Chiều cao mặt quá nhỏ để vát 45°.' unless dz > cut
        pts = [[x,0,0],[x,dy,0],[x,dy,dz-cut],[x,p['bevel_lip'].to_f.mm,dz],[x,0,dz]]
        f = entities.add_face(pts)
        raise 'Không dựng được tiết diện vát.' unless f
        f.reverse! if f.normal.x < 0
        f.pushpull(dx)
      else
        f = entities.add_face([[x,0,0],[x+dx,0,0],[x+dx,dy,0],[x,dy,0]])
        raise 'Không dựng được mặt tấm.' unless f
        f.reverse! if f.normal.z < 0
        f.pushpull(dz)
      end
    end
    def clean_tags(entities)
      model = context_model
      entities.each do |e|
        if e.is_a?(Sketchup::ConstructionLine)
          e.layer = model.layers['VGD_KY HIEU'] || model.layers.add('VGD_KY HIEU')
        elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          front = e.name.to_s.start_with?('Mặt Ngăn Kéo') || (e.respond_to?(:definition) && e.definition.name.to_s.start_with?('Cánh'))
          e.layer = front ? (model.layers['VGD_CANH'] || model.layers.add('VGD_CANH')) : model.layers[0]
          clean_tags(e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities)
        elsif e.respond_to?(:layer=)
          e.layer = model.layers[0]
        end
      end
    end
    def draw(entities, p)
      widths = ModelingRules.widths(p)
      if p['module_mode'] == 'Độc lập'
        x = 0.0
        widths.each_with_index do |width, index|
          group = entities.add_group
          group.name = "Module #{format('%02d',index+1)} — #{width.round(1)} mm"
          child = p.merge('w'=>width, 'module_mode'=>'Chung vách', '__independent_module'=>true)
          child['opt_left_side'] = 'Vuông' if index > 0
          child['opt_right_side'] = 'Vuông' if index < widths.size-1
          GeometryEngine.draw(group.entities, child)
          group.transform!(Geom::Transformation.translation([x.mm,0,0]))
          x += width
        end
      else
        GeometryEngine.draw(entities,p)
      end
      unless Thread.current[:vgd_cabinet_preview_model]
        ComponentSharing.apply(entities)
        clean_tags(entities)
      end
    end
  end
end
