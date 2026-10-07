# frozen_string_literal: true
module VGD_Cabinet
  module RailJoinery
    module_function
    EPS=1e-7 unless const_defined?(:EPS, false)
    def inside?(point, polygon)
      x,y=point; inside=false; previous=polygon.last
      polygon.each do |current|
        if (current[1]>y)!=(previous[1]>y) && x<(previous[0]-current[0])*(y-current[1])/(previous[1]-current[1])+current[0]
          inside=!inside
        end
        previous=current
      end
      inside
    end
    def cut_loops(polygon, cuts)
      xs=(polygon.map(&:first)+cuts.flat_map { |r| [r[0],r[2]] }).uniq.sort
      ys=(polygon.map(&:last)+cuts.flat_map { |r| [r[1],r[3]] }).uniq.sort
      edges={}
      xs.each_cons(2) do |x0,x1|
        next if x1-x0<EPS
        ys.each_cons(2) do |y0,y1|
          next if y1-y0<EPS
          centre=[(x0+x1)/2,(y0+y1)/2]
          next unless inside?(centre,polygon)
          next if cuts.any? { |a,b,c,d| centre[0]>a-EPS && centre[0]<c+EPS && centre[1]>b-EPS && centre[1]<d+EPS }
          vertices=[[x0,y0],[x1,y0],[x1,y1],[x0,y1]].map { |p| p.map { |v| v.round(8) } }
          vertices.each_index do |i|
            a=vertices[i]; b=vertices[(i+1)%4]
            edges.delete([b,a]) || edges.store([a,b],true)
          end
        end
      end
      loops=[]
      until edges.empty?
        first=edges.keys.first; edges.delete(first); loop=[first[0],first[1]]
        until loop.last==loop.first
          candidates=edges.keys.select { |edge| edge[0]==loop.last }
          raise ModelingRules::Invalid,'Không khép kín tiết diện khấu hồi.' if candidates.empty?
          previous=loop[-2]; current=loop[-1]
          edge=candidates.max_by do |_,following|
            a=[current[0]-previous[0],current[1]-previous[1]]; b=[following[0]-current[0],following[1]-current[1]]
            Math.atan2(a[0]*b[1]-a[1]*b[0],a[0]*b[0]+a[1]*b[1])
          end
          edges.delete(edge); loop << edge[1]
        end
        loop.pop
        loop=loop.each_index.filter_map do |i|
          a=loop[i-1]; b=loop[i]; c=loop[(i+1)%loop.size]
          b if ((b[0]-a[0])*(c[1]-b[1])-(b[1]-a[1])*(c[0]-b[0])).abs>EPS
        end
        loops << loop if loop.size>=3
      end
      loops
    end
    def points(group)
      group.entities.grep(Sketchup::Face).flat_map(&:vertices).map { |v| v.position.transform(group.transformation) }
    end
    def bounds(group)
      vertices=points(group)
      return nil if vertices.empty?
      [[:x,:y,:z].map { |axis| vertices.map { |p| p.public_send(axis) }.min },
       [:x,:y,:z].map { |axis| vertices.map { |p| p.public_send(axis) }.max }]
    end
    def overlap?(a,b,axis)
      [a[1][axis],b[1][axis]].min-[a[0][axis],b[0][axis]].max>EPS
    end
    def box(group, low, high)
      group.entities.clear!
      group.transformation=Geom::Transformation.translation(low)
      face=group.entities.add_face([[0,0,0],[high[0]-low[0],0,0],[high[0]-low[0],high[1]-low[1],0],[0,high[1]-low[1],0]])
      raise ModelingRules::Invalid,'Không dựng được xà liền hồi.' unless face
      face.reverse! if face.normal.z<0
      face.pushpull(high[2]-low[2])
    end
    def rebate(group, slots)
      return rebate_curved(group,slots) if group.name.include?('Bo Cong')
      faces=group.entities.grep(Sketchup::Face)
      face=faces.select { |f| f.normal.x.abs>0.999 }.min_by { |f| f.vertices.map { |v| v.position.x }.min }
      vertices=face ? face.outer_loop.vertices.map(&:position) : faces.flat_map(&:vertices).map(&:position)
      return if vertices.empty?
      min_x=vertices.map(&:x).min
      polygon=vertices.select { |p| (p.x-min_x).abs<EPS }.map { |p| [p.y.to_f,p.z.to_f] }.uniq
      unless face
        # The lightweight extrusion fixture stores both caps on one Face.
        y0,y1=polygon.map(&:first).minmax; z0,z1=polygon.map(&:last).minmax
        polygon=[[y0,z0],[y1,z0],[y1,z1],[y0,z1]]
      end
      return if polygon.size<3
      extent=bounds(group); width=extent[1][0]-extent[0][0]
      offset=group.transformation.origin
      local=slots.map { |r| [r[0]-offset.y,r[1]-offset.z,r[2]-offset.y,r[3]-offset.z] }
      loops=cut_loops(polygon,local)
      positive=loops.select { |loop| FrameDivisions.area(loop)>0 }
      holes=loops.select { |loop| FrameDivisions.area(loop)<0 }
      raise ModelingRules::Invalid,'Xà cắt rời hoặc chiếm hết hồi. Giảm bản xà/đổi cấu tạo.' unless positive.size==1
      group.entities.clear!
      exterior=group.entities.add_face(positive.first.map { |y,z| [min_x,y,z] })
      raise ModelingRules::Invalid,'Không dựng được hồi có khấu xà.' unless exterior
      holes.each do |hole|
        opening=group.entities.add_face(hole.map { |y,z| [min_x,y,z] })
        opening.erase! if opening
      end
      exterior.reverse! if exterior.normal.x<0
      exterior.pushpull(width)
      group.set_attribute('VGD_CabinetPart','rail_rebates',JSON.generate(local))
    end
    def polygon_difference(polygons, cutters)
      cutters.each { |cutter| polygons=polygons.flat_map { |polygon| FrameDivisions.subtract(polygon,cutter) } }
      polygons
    end
    def rebate_curved(group, slots)
      # A curved side is a vertical prism, rather than a rectangular YZ profile.
      # Retain its original arc vertices. Build only the boundary between the
      # successive notched footprints, so adjacent bands have no internal faces.
      faces=group.entities.grep(Sketchup::Face)
      cap=faces.select { |face| face.normal.z.abs>0.999 }.min_by { |face| face.vertices.map { |v| v.position.z }.min }
      raise ModelingRules::Invalid,'Không đọc được tiết diện hồi bo.' unless cap
      footprint=cap.outer_loop.vertices.map { |v| [v.position.x.to_f,v.position.y.to_f] }
      footprint.reverse! if FrameDivisions.area(footprint)<0
      vertices=faces.flat_map(&:vertices).map(&:position)
      z0,z1=vertices.map(&:z).minmax; x0,x1=footprint.map(&:first).minmax
      offset=group.transformation.origin
      local=slots.map { |r| [r[0]-offset.y,r[1]-offset.z,r[2]-offset.y,r[3]-offset.z] }
      levels=([z0,z1]+local.flat_map { |r| [r[1],r[3]] }).select { |z| z>=z0-EPS && z<=z1+EPS }.uniq.sort
      bands=levels.each_cons(2).map do |low,high|
        middle=(low+high)/2
        cutters=local.select { |r| middle>r[1] && middle<r[3] }.map { |r| FrameDivisions.rectangle(x0-1,r[0],x1+1,r[2]) }
        [low,high,polygon_difference([footprint],cutters)]
      end
      raise ModelingRules::Invalid,'Xà chiếm hết tiết diện hồi bo.' if bands.any? { |_,_,polygons| polygons.empty? }
      group.entities.clear!
      add_cap=->(polygons,z,up) {
        polygons.each do |polygon|
          points=polygon.map { |x,y| [x,y,z] }; points.reverse! unless up
          group.entities.add_face(points)
        end
      }
      add_cap.call(bands.first[2],z0,false); add_cap.call(bands.last[2],z1,true)
      bands.each do |low,high,polygons|
        polygons.each do |polygon|
          polygon.each_index do |i|
            a=polygon[i]; b=polygon[(i+1)%polygon.size]
            group.entities.add_face([[a[0],a[1],low],[b[0],b[1],low],[b[0],b[1],high],[a[0],a[1],high]])
          end
        end
      end
      bands.each_cons(2) do |below,above|
        add_cap.call(polygon_difference(below[2],above[2]),below[1],true)
        add_cap.call(polygon_difference(above[2],below[2]),below[1],false)
      end
      group.set_attribute('VGD_CabinetPart','rail_rebates',JSON.generate(local))
    end
    def apply(entities,p)
      return if p['__independent_module']
      groups=entities.to_a.select { |e| e.respond_to?(:entities) && e.valid? }
      sides=groups.select { |g| g.name.start_with?('Hồi ', 'Hông Khung Ngăn Kéo') }
      side_bounds=sides.to_h { |g| [g,bounds(g)] }.reject { |_,b| !b }
      rails=groups.select { |g| g.name.include?('Xà') }
      extended=rails.filter_map do |rail|
        current=bounds(rail); next unless current
        low,high=current.map(&:dup)
        side_bounds.each_value do |side|
          next unless overlap?(current,side,1) && overlap?(current,side,2)
          low[0]=[low[0],side[0][0]].min if (current[0][0]-side[1][0]).abs<EPS
          high[0]=[high[0],side[1][0]].max if (current[1][0]-side[0][0]).abs<EPS
        end
        [rail,[low,high]]
      end
      merged=[]
      extended.each do |rail,extent|
        match=merged.find do |other,b|
          ComponentSharing.role(other.name)==ComponentSharing.role(rail.name) &&
          [1,2].all? { |axis| (b[0][axis]-extent[0][axis]).abs<EPS && (b[1][axis]-extent[1][axis]).abs<EPS } &&
          extent[0][0]<=b[1][0]+EPS && extent[1][0]>=b[0][0]-EPS
        end
        if match
          match[1][0][0]=[match[1][0][0],extent[0][0]].min
          match[1][1][0]=[match[1][1][0],extent[1][0]].max
          rail.entities.clear!; rail.erase!
        else
          merged << [rail,extent]
        end
      end
      merged.each { |rail,extent| box(rail,*extent) }
      side_bounds.each do |side,extent|
        slots=merged.filter_map do |_,rail|
          next unless (0..2).all? { |axis| overlap?(extent,rail,axis) }
          [[extent[0][1],rail[0][1]].max,[extent[0][2],rail[0][2]].max,
           [extent[1][1],rail[1][1]].min,[extent[1][2],rail[1][2]].min]
        end
        rebate(side,slots) unless slots.empty?
      end
    end
  end
end
