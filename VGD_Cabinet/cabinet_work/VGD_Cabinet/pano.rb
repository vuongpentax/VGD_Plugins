# frozen_string_literal: true
module VGD_Cabinet
  module Modeling
    module_function
    def pano_sizes(width,height,p)
      b=p['pano_stile_width']; r=p['pano_rail_width']; m=p['pano_mid_rail']; n=p['pano_panel_count'].to_i
      opening_w=width-2*b
      opening_h=(height-2*r-(n-1)*m)/n
      raise ModelingRules::Invalid,'Cánh pano quá nhỏ cho bản khung/số ô đã chọn.' unless opening_w>1 && opening_h>1
      capture=p['pano_groove_depth']-p['pano_clearance']
      {opening_w:opening_w,opening_h:opening_h,panel_w:opening_w+2*capture,panel_h:opening_h+2*capture}
    end
    def profile_part(entities,name,points,axis,extrusion,material)
      group=entities.add_group; group.name=name; group.material=material
      face=group.entities.add_face(points)
      raise ModelingRules::Invalid,'Không tạo được tiết diện khung pano.' unless face
      normal=axis==:x ? face.normal.x : face.normal.z
      face.reverse! if normal<0
      face.pushpull(extrusion)
      group
    end
    def pano_rail(entities,name,x,z,width,depth,breadth,groove,gy,pt,bottom,top,bevel,lip,material)
      # Closed YZ profile with real straight panel grooves, and optional top back bevel.
      points=[[0,0]]
      points += [[gy,0],[gy,groove],[gy+pt,groove],[gy+pt,0]] if bottom
      points << [depth,0]
      if bevel
        points += [[depth,breadth-(depth-lip)],[lip,breadth]]
      else
        points << [depth,breadth]
      end
      points += [[gy+pt,breadth],[gy+pt,breadth-groove],[gy,breadth-groove],[gy,breadth]] if top
      points << [0,breadth]
      profile_part(entities,name,points.map { |y,v| [x,y,z+v] },:x,width,material)
    end
    def pano_front(entities,x,width,depth,height,p)
      mode=p['frame_division'] || 'Không chia'
      horizontal=mode=='Ngang' ? p['frame_sections'].to_i : (mode=='Không chia' ? p['pano_panel_count'].to_i : 1)
      middle=p['frame_bar_width'].to_f>0 ? p['frame_bar_width'] : p['pano_mid_rail']
      effective=p.merge('pano_panel_count'=>horizontal,'pano_mid_rail'=>middle)
      sizes=pano_sizes(width.to_f*25.4,height.to_f*25.4,effective)
      b=p['pano_stile_width'].mm; r=p['pano_rail_width'].mm; m=middle.mm
      g=p['pano_groove_depth'].mm; c=p['pano_clearance'].mm; pt=p['pano_panel_thickness'].mm
      gy=p['door_style']=='Shaker' ? p['shaker_recess'].mm : (depth-pt)/2
      n=horizontal; opening_h=sizes[:opening_h].mm
      label=p['door_style']=='Shaker' ? 'Shaker' : 'Pano'
      frame=concept_material("VGD Khung #{label}",[185,144,94]); panel=concept_material("VGD #{label}",[205,169,120])
      left=[[x,0,0],[x+b,0,0],[x+b,gy,0],[x+b-g,gy,0],
            [x+b-g,gy+pt,0],[x+b,gy+pt,0],[x+b,depth,0],[x,depth,0]]
      right=left.map { |px,y,z| [2*x+width-px,y,z] }
      profile_part(entities,"Đố #{label} Trái",left,:z,height,frame)
      profile_part(entities,"Đố #{label} Phải",right,:z,height,frame)
      pano_rail(entities,"Thanh #{label} Dưới",x+b,0,width-2*b,depth,r,g,gy,pt,false,true,false,0,frame)
      pano_rail(entities,"Thanh #{label} Trên",x+b,height-r,width-2*b,depth,r,g,gy,pt,true,false,p['front_bevel'],p['bevel_lip'].mm,frame)
      if mode=='Dọc'
        count=p['frame_sections'].to_i
        opening=(width-2*b-(count-1)*m)/count
        raise ModelingRules::Invalid,'Cánh quá hẹp cho khung dọc.' unless opening>1.mm
        count.times do |index|
          px=x+b+index*(opening+m)
          group=entities.add_group; group.name="#{label} #{index+1}"; group.material=panel
          concept_box(group.entities,px-g+c,gy,r-g+c,opening+2*(g-c),pt,height-2*r+2*(g-c),panel)
          if index<count-1
            sx=px+opening
            profile=[[sx,0,r],[sx+m,0,r],[sx+m,gy,r],[sx+m-g,gy,r],[sx+m-g,gy+pt,r],[sx+m,gy+pt,r],
                     [sx+m,depth,r],[sx,depth,r],[sx,gy+pt,r],[sx+g,gy+pt,r],[sx+g,gy,r],[sx,gy,r]]
            profile_part(entities,"Đố Giữa #{label} #{index+1}",profile,:z,height-2*r,frame)
          end
        end
        return
      end
      n.times do |index|
        z=r+index*(opening_h+m)
        group=entities.add_group; group.name="#{label} #{index+1}"; group.material=panel
        concept_box(group.entities,x+b-g+c,gy,z-g+c,sizes[:panel_w].mm,pt,sizes[:panel_h].mm,panel)
        if index<n-1
          pano_rail(entities,"Thanh Giữa #{label} #{index+1}",x+b,z+opening_h,width-2*b,depth,m,g,gy,pt,true,true,false,0,frame)
        end
      end
      if mode=='Chéo X'
        # Applied X bars stop at the square inner frame and meet the recessed
        # panel face; split at their crossing to avoid overlapping solids.
        layout=FrameDivisions.layout(width-2*b,height-2*r,m,mode,2)
        layout[:bars].each_with_index do |poly,index|
          group=entities.add_group; group.name="Thanh Chéo #{label} #{index+1}"; group.material=frame
          framed_polygon(group.entities,poly,x+b,r,0,gy,frame)
        end
      end
    end
  end
end
