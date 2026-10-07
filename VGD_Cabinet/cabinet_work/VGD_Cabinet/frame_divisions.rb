# frozen_string_literal: true
module VGD_Cabinet
  module FrameDivisions
    module_function
    EPS = 1e-8 unless const_defined?(:EPS, false)
    def area(poly)
      poly.each_index.sum { |i| a=poly[i]; b=poly[(i+1)%poly.size]; a[0]*b[1]-b[0]*a[1] }/2.0
    end
    def clip(poly, a, b, inside = true)
      return [] if poly.empty?
      sign = inside ? 1 : -1
      distance = ->(p) { sign*((b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0])) }
      output=[]
      poly.each_index do |i|
        from=poly[i]; to=poly[(i+1)%poly.size]; d1=distance.call(from); d2=distance.call(to)
        output << from if d1 >= -EPS
        if (d1 > EPS && d2 < -EPS) || (d1 < -EPS && d2 > EPS)
          ratio=d1/(d1-d2)
          output << [from[0]+ratio*(to[0]-from[0]), from[1]+ratio*(to[1]-from[1])]
        end
      end
      output=output.each_with_object([]) { |p,list| list << p unless list.last && (list.last[0]-p[0]).abs<EPS && (list.last[1]-p[1]).abs<EPS }
      output.pop if output.size>1 && (output.first[0]-output.last[0]).abs<EPS && (output.first[1]-output.last[1]).abs<EPS
      output.size>=3 && area(output).abs>EPS ? output : []
    end
    def subtract(poly, cutter)
      rest=poly; outside=[]
      cutter.each_index do |i|
        a=cutter[i]; b=cutter[(i+1)%cutter.size]
        piece=clip(rest,a,b,false); outside << piece unless piece.empty?
        rest=clip(rest,a,b,true); break if rest.empty?
      end
      outside
    end
    def rectangle(x0,z0,x1,z1); [[x0,z0],[x1,z0],[x1,z1],[x0,z1]]; end
    def band(a,b,breadth,rectangle)
      vx=b[0]-a[0]; vz=b[1]-a[1]; length=Math.sqrt(vx*vx+vz*vz)
      nx=-vz/length*breadth/2.0; nz=vx/length*breadth/2.0
      # Extend past the corner; clip to the clear opening afterwards.
      ex=vx/length*breadth; ez=vz/length*breadth
      poly=[[a[0]-ex-nx,a[1]-ez-nz],[b[0]+ex-nx,b[1]+ez-nz],
            [b[0]+ex+nx,b[1]+ez+nz],[a[0]-ex+nx,a[1]-ez+nz]]
      rectangle.each_index { |i| poly=clip(poly,rectangle[i],rectangle[(i+1)%rectangle.size]) }
      poly
    end
    def layout(width,height,breadth,mode,sections)
      rect=rectangle(0,0,width,height); cutters=[]
      case mode
      when 'Ngang'
        step=(height-(sections-1)*breadth)/sections
        raise ModelingRules::Invalid,'Thanh ngang chiếm hết ô cánh.' unless step>1.mm
        (1...sections).each { |i| z=i*step+(i-1)*breadth; cutters << rectangle(0,z,width,z+breadth) }
      when 'Dọc'
        step=(width-(sections-1)*breadth)/sections
        raise ModelingRules::Invalid,'Thanh dọc chiếm hết ô cánh.' unless step>1.mm
        (1...sections).each { |i| x=i*step+(i-1)*breadth; cutters << rectangle(x,0,x+breadth,height) }
      when 'Chéo X'
        raise ModelingRules::Invalid,'Bản thanh chéo quá lớn so với ô cánh.' unless breadth<[width,height].min/3.0
        cutters=[band([0,0],[width,height],breadth,rect),band([width,0],[0,height],breadth,rect)]
      end
      panels=[rect]; bars=[]
      cutters.each do |cutter|
        portions=[cutter]
        bars.each { |prior| portions=portions.flat_map { |portion| subtract(portion,prior) } }
        bars.concat(portions)
        panels=panels.flat_map { |panel| subtract(panel,cutter) }
      end
      {bars:bars, panels:panels}
    end
  end
end
