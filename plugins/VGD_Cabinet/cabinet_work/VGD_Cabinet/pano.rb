# frozen_string_literal: true
module VGD_Cabinet
  module Modeling
    module_function
    def rounded_rect_points(x,z,width,height,r,y,segments=8)
      radius=[[r.to_f,0].max,width.to_f/2,height.to_f/2].min
      centers=[[x+radius,z+radius,180,270],[x+width-radius,z+radius,270,360],
               [x+width-radius,z+height-radius,0,90],[x+radius,z+height-radius,90,180]]
      points=centers.flat_map do |cx,cz,start_angle,end_angle|
        (0..segments).map do |i|
          angle=(start_angle+(end_angle-start_angle)*i.to_f/segments)*Math::PI/180
          [cx+radius*Math.cos(angle),y,cz+radius*Math.sin(angle)]
        end
      end
      clean=[]
      points.each do |point|
        previous=clean.last
        clean << point unless previous && 3.times.sum { |axis| (point[axis]-previous[axis])**2 } < 1.0e-10
      end
      clean.pop if clean.size>2 && 3.times.sum { |axis| (clean.first[axis]-clean.last[axis])**2 } < 1.0e-10
      clean
    end
    def add_profile_lines(entities,name,points)
      group=entities.add_group; group.name=name
      points.each_index do |index|
        a=Geom::Point3d.new(points[index]); b=Geom::Point3d.new(points[(index+1)%points.size])
        group.entities.respond_to?(:add_line) ? group.entities.add_line(a,b) : group.entities.add_cline(a,b)
      end
      group
    end
    def profile_cutter(entities,name,points,y,depth)
      group=entities.add_group; group.name=name
      face=group.entities.add_face(points.map { |px,_,pz| [px,y,pz] })
      raise ModelingRules::Invalid,'Không dựng được biên dạng soi cánh.' unless face
      face.reverse! if face.normal.y<0
      face.pushpull(depth)
      group
    end
    def trim_profile(target,cutter)
      return target unless target.respond_to?(:trim)
      name=target.name; material=target.material; layer=target.layer if target.respond_to?(:layer)
      result=cutter.trim(target)
      unless result && result.valid?
        cutter.erase! if cutter.valid?
        raise ModelingRules::Invalid,'SketchUp không khấu được biên dạng cánh. Kiểm tra kích thước soi/vát.'
      end
      cutter.erase! if cutter.valid?
      result.name=name; result.material=material if material
      result.layer=layer if layer && result.respond_to?(:layer=)
      result
    end
    def carved_front(entities,x,width,depth,height,p)
      thickness=p['wood_carved_thickness'].mm; rail=p['wood_carved_rail'].mm
      raise ModelingRules::Invalid,'Bản huỳnh quá lớn so với cánh.' unless width>2*rail && height>2*rail
      material=concept_material('VGD Cánh Soi',[190,157,126])
      target=entities.add_group; target.name='Cánh Soi'; target.material=material
      concept_box(target.entities,x,0,0,width,thickness,height,material)
      ix=x+rail; iz=rail; iw=width-2*rail; ih=height-2*rail
      points=rounded_rect_points(ix,iz,iw,ih,p['wood_carved_radius'].mm,-1.mm)
      if target.respond_to?(:trim)
        cutter=profile_cutter(entities,'Dao Soi Bo Góc',points,-1.mm,p['wood_carved_recess'].mm+1.mm)
        target=trim_profile(target,cutter)
      end
      add_profile_lines(entities,'Rãnh Soi Bo Góc',rounded_rect_points(ix,iz,iw,ih,p['wood_carved_radius'].mm,0))
      target
    end
    def bevel_cutter(entities,x,z,width,height,flat,bevel,recess)
      outer=[[x+flat,z+flat],[x+width-flat,z+flat],[x+width-flat,z+height-flat],[x+flat,z+height-flat]]
      inner=[[x+flat+bevel,z+flat+bevel],[x+width-flat-bevel,z+flat+bevel],
             [x+width-flat-bevel,z+height-flat-bevel],[x+flat+bevel,z+height-flat-bevel]]
      y0=-1.mm; y1=recess+1.mm
      top=outer.map { |px,pz| Geom::Point3d.new(px,y0,pz) }
      bottom=inner.map { |px,pz| Geom::Point3d.new(px,y1,pz) }
      all=top+bottom; center=Geom::Point3d.new(3.times.map { |axis| all.map { |pt| pt.to_a[axis] }.sum/all.size.to_f })
      group=entities.add_group; group.name='Dao Vát Bốn Cạnh'
      faces=[top,bottom.reverse]
      4.times { |i| faces << [top[i],top[(i+1)%4],bottom[(i+1)%4],bottom[i]] }
      faces.each do |loop|
        face=group.entities.add_face(loop)
        next unless face
        centroid=Geom::Point3d.new(3.times.map { |axis| loop.sum { |pt| pt.to_a[axis] }/loop.size.to_f })
        face.reverse! if face.normal.dot(centroid-center)<0
      end
      group
    end
    def beveled_front(entities,x,width,depth,height,p)
      thickness=p['wood_bevel_thickness'].mm; flat=p['wood_bevel_flat'].mm
      bevel=p['wood_bevel_width'].mm; recess=p['wood_bevel_recess'].mm
      raise ModelingRules::Invalid,'Bề rộng vát không vừa với cánh.' unless width>2*(flat+bevel) && height>2*(flat+bevel)
      material=concept_material('VGD Cánh Soi Vát',[190,157,126])
      target=entities.add_group; target.name='Cánh Soi Vát 4 Cạnh'; target.material=material
      concept_box(target.entities,x,0,0,width,thickness,height,material)
      if target.respond_to?(:trim)
        target=trim_profile(target,bevel_cutter(entities,x,0,width,height,flat,bevel,recess))
      end
      add_profile_lines(entities,'Vát Bốn Cạnh',[[x+flat,-0.2.mm,flat],[x+width-flat,-0.2.mm,flat],
        [x+width-flat,-0.2.mm,height-flat],[x+flat,-0.2.mm,height-flat]])
      target
    end
    def wooden_glass_front(entities,x,width,depth,height,p)
      thickness=p['wood_glass_frame_thickness'].mm; rail=p['wood_glass_rail'].mm
      glass_depth=p['wood_glass_depth'].mm; inset=p['wood_glass_inset'].mm
      inner_w=width-2*rail; inner_h=height-2*rail
      raise ModelingRules::Invalid,'Khung gỗ quá nhỏ cho ô kính.' unless inner_w>1.mm && inner_h>1.mm
      raise ModelingRules::Invalid,'Chiều dày khung không đủ chứa kính.' unless inset+glass_depth<=thickness
      radius=p['wood_glass_radius'].mm
      frame_material=concept_material('VGD Khung Kính Gỗ',[185,144,94])
      members=case p['frame_joint']
      when 'Ngang'
        [['Khung Kính Gỗ Hông Trái',[[x,rail],[x+rail,rail],[x+rail,height-rail],[x,height-rail]]],
         ['Khung Kính Gỗ Hông Phải',[[x+width-rail,rail],[x+width,rail],[x+width,height-rail],[x+width-rail,height-rail]]],
         ['Khung Kính Gỗ Dưới',[[x,0],[x+width,0],[x+width,rail],[x,rail]]],
         ['Khung Kính Gỗ Trên',[[x,height-rail],[x+width,height-rail],[x+width,height],[x,height]]]]
      when 'Chéo'
        [['Khung Kính Gỗ Hông Trái',[[x,0],[x+rail,rail],[x+rail,height-rail],[x,height]]],
         ['Khung Kính Gỗ Hông Phải',[[x+width,0],[x+width-rail,rail],[x+width-rail,height-rail],[x+width,height]]],
         ['Khung Kính Gỗ Dưới',[[x,0],[x+width,0],[x+width-rail,rail],[x+rail,rail]]],
         ['Khung Kính Gỗ Trên',[[x,height],[x+width,height],[x+width-rail,height-rail],[x+rail,height-rail]]]]
      else
        [['Khung Kính Gỗ Hông Trái',[[x,0],[x+rail,0],[x+rail,height],[x,height]]],
         ['Khung Kính Gỗ Hông Phải',[[x+width-rail,0],[x+width,0],[x+width,height],[x+width-rail,height]]],
         ['Khung Kính Gỗ Dưới',[[x+rail,0],[x+width-rail,0],[x+width-rail,rail],[x+rail,rail]]],
         ['Khung Kính Gỗ Trên',[[x+rail,height-rail],[x+width-rail,height-rail],[x+width-rail,height],[x+rail,height]]]]
      end
      opening=rounded_rect_points(x+rail,rail,inner_w,inner_h,radius,-1.mm)
      members.each do |name,poly|
        member=entities.add_group; member.name=name; member.material=frame_material
        framed_polygon(member.entities,poly,0,0,0,thickness,frame_material)
        if member.respond_to?(:trim)
          cutter=profile_cutter(entities,'Dao Khoét Kính Bo Góc',opening,-1.mm,thickness+2.mm)
          trim_profile(member,cutter)
        end
      end
      glass_color={'Trong'=>[210,232,235],'Trà'=>[142,105,73],'Xám'=>[115,128,140]}
      glass_material=concept_material("VGD #{p['wood_glass_type']}",glass_color.fetch(p['glass_finish'],[210,232,235]),0.35)
      division=p['frame_division'] || 'Không chia'
      bar_width=p['frame_bar_width'].to_f>0 ? p['frame_bar_width'].mm : rail
      layout=FrameDivisions.layout(inner_w,inner_h,bar_width,division,p['frame_sections'].to_i)
      layout[:bars].each_with_index do |poly,index|
        positioned=poly.map { |px,pz| [x+rail+px,rail+pz] }
        bar=entities.add_group; bar.name="Thanh Chia Kính #{division} #{index+1}"; bar.material=frame_material
        framed_polygon(bar.entities,positioned,0,0,0,thickness,frame_material)
      end
      layout[:panels].each_with_index do |poly,index|
        pane=entities.add_group; pane.name="Kính Phẳng Bo Góc #{index+1}"; pane.material=glass_material
        if division=='Không chia'
          points=rounded_rect_points(x+rail,rail,inner_w,inner_h,radius,inset)
          face=pane.entities.add_face(points)
          raise ModelingRules::Invalid,'Không dựng được tấm kính bo góc.' unless face
          face.reverse! if face.normal.y<0
          face.pushpull(glass_depth)
        else
          points=poly.map { |px,pz| [x+rail+px,inset,rail+pz] }
          framed_polygon(pane.entities,points.map { |px,py,pz| [px,pz] },0,0,inset,glass_depth,glass_material)
        end
      end
    end
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
      # Pano/Shaker panel count is independent; frame_division is reserved for glass doors.
      mode='Không chia'
      horizontal=p['pano_panel_count'].to_i
      middle=p['pano_mid_rail']
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
      left_stile=right_stile=nil
      if p['frame_joint']=='Ngang'
        left_stile=profile_part(entities,"Đố #{label} Trái",left.map { |px,y,z| [px,y,z+r] },:z,height-2*r,frame)
        right_stile=profile_part(entities,"Đố #{label} Phải",right.map { |px,y,z| [px,y,z+r] },:z,height-2*r,frame)
        pano_rail(entities,"Thanh #{label} Dưới",x,0,width,depth,r,g,gy,pt,false,true,false,0,frame)
        pano_rail(entities,"Thanh #{label} Trên",x,height-r,width,depth,r,g,gy,pt,true,false,p['front_bevel'],p['bevel_lip'].mm,frame)
      elsif p['frame_joint']=='Chéo'
        left_stile=profile_part(entities,"Đố #{label} Trái",left,:z,height,frame)
        right_stile=profile_part(entities,"Đố #{label} Phải",right,:z,height,frame)
        pano_rail(entities,"Thanh #{label} Dưới",x,0,width,depth,r,g,gy,pt,false,true,false,0,frame)
        pano_rail(entities,"Thanh #{label} Trên",x,height-r,width,depth,r,g,gy,pt,true,false,p['front_bevel'],p['bevel_lip'].mm,frame)
        if left_stile.respond_to?(:trim)
          left_cuts=[[[x,0],[x+b,0],[x,b]],[[x,height-r],[x+b,height],[x,height]]]
          right_cuts=[[[x+width-b,0],[x+width,0],[x+width,b]],[[x+width,height-r],[x+width-b,height],[x+width,height]]]
          left_cuts.each { |poly| left_stile=trim_profile(left_stile,profile_cutter(entities,'Dao Ghép Mòi',poly.map { |px,pz| [px,0,pz] },-1.mm,depth+2.mm)) }
          right_cuts.each { |poly| right_stile=trim_profile(right_stile,profile_cutter(entities,'Dao Ghép Mòi',poly.map { |px,pz| [px,0,pz] },-1.mm,depth+2.mm)) }
        end
      else
        left_stile=profile_part(entities,"Đố #{label} Trái",left,:z,height,frame)
        right_stile=profile_part(entities,"Đố #{label} Phải",right,:z,height,frame)
        pano_rail(entities,"Thanh #{label} Dưới",x+b,0,width-2*b,depth,r,g,gy,pt,false,true,false,0,frame)
        pano_rail(entities,"Thanh #{label} Trên",x+b,height-r,width-2*b,depth,r,g,gy,pt,true,false,p['front_bevel'],p['bevel_lip'].mm,frame)
      end
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
    end
  end
end
