class Numeric
  def mm; self / 25.4; end
  def inch; self.to_f; end
  def to_mm; self*25.4; end
end
module Geom
  class Point3d
    attr_accessor :x,:y,:z
    def initialize(*p); @x,@y,@z=p.flatten; end
    def to_a; [x,y,z]; end
    def -(p); Vector3d.new(x-p.x,y-p.y,z-p.z); end
    def offset(v,distance=nil); v=distance ? v.normalize.to_a.map { |n| n*distance } : v.to_a; Point3d.new(to_a.zip(v).map { |a,b| a+b }); end
    def transform(tr); tr.point(self); end
    def distance(p); (self-p).length; end
  end
  class Vector3d < Point3d
    def length; Math.sqrt(to_a.sum { |n| n*n }); end
    def normalize; Vector3d.new(to_a.map { |n| n/length }); end
    def normalize!; values=normalize.to_a; @x,@y,@z=values; self; end
    def dot(other); to_a.zip(other.to_a).sum { |a,b| a*b }; end
    def cross(other); Vector3d.new(y*other.z-z*other.y,z*other.x-x*other.z,x*other.y-y*other.x); end
    def reverse; Vector3d.new(to_a.map { |n| -n }); end
  end
  class Transformation
    def initialize(p=[0,0,0])
      values=p.respond_to?(:to_a) ? p.to_a : p
      @matrix=values.size==16 ? values : [1,0,0,0,0,1,0,0,0,0,1,0,*values,1]
    end
    def offset; @matrix[12,3]; end
    def self.translation(p); new(p); end
    def +(other); self*other; end
    def to_a; @matrix; end
    def origin; Point3d.new(offset); end
    def point(p); Point3d.new((0..2).map { |row| (0..2).sum { |column| @matrix[column*4+row]*p.to_a[column] }+offset[row] }); end
    def *(other)
      result=(0..3).flat_map { |column| (0..3).map { |row| (0..3).sum { |k| @matrix[k*4+row]*other.to_a[column*4+k] } } }
      self.class.new(result)
    end
    def xaxis; Vector3d.new(@matrix[0,3]); end
    def yaxis; Vector3d.new(@matrix[4,3]); end
    def zaxis; Vector3d.new(@matrix[8,3]); end
    def self.axes(origin,x,y,z); new([*x.to_a,0,*y.to_a,0,*z.to_a,0,*origin.to_a,1]); end
    def inverse
      a,b,c=@matrix.values_at(0,4,8); d,e,f=@matrix.values_at(1,5,9); g,h,i=@matrix.values_at(2,6,10)
      determinant=a*(e*i-f*h)-b*(d*i-f*g)+c*(d*h-e*g)
      rows=[[e*i-f*h,c*h-b*i,b*f-c*e],[f*g-d*i,a*i-c*g,c*d-a*f],[d*h-e*g,b*g-a*h,a*e-b*d]].map { |r| r.map { |v| v/determinant.to_f } }
      translation=rows.map { |row| -row.zip(offset).sum { |v,n| v*n } }
      self.class.new((0..2).flat_map { |column| rows.map { |row| row[column] }+[0] }+translation+[1])
    end
    def self.scaling(*scale)
      new([scale[0],0,0,0,0,scale[1],0,0,0,0,scale[2],0,0,0,0,1])
    end
  end
  class BoundingBox
    def initialize; @points=[]; end
    def add(*points); points.flatten.each { |p| @points << p if p.is_a?(Point3d) }; self; end
    def empty?; @points.empty?; end
    def corner(i)
      low=(0..2).map { |a| @points.map { |p| p.to_a[a] }.min }; high=(0..2).map { |a| @points.map { |p| p.to_a[a] }.max }
      Point3d.new((0..2).map { |axis| i[axis]==0 ? low[axis] : high[axis] })
    end
  end
end
module Sketchup
  class SelectionObserver; end
  class Entity
    attr_accessor :name,:layer,:transformation,:material
    def initialize; @name=''; @layer='dirty'; @attrs={}; @transformation=Geom::Transformation.new; end
    def set_attribute(dict,key,value); (@attrs[dict]||={})[key]=value; end
    def get_attribute(dict,key,fallback=nil); (@attrs[dict]||{}) .fetch(key,fallback); end
    def valid?; !@erased; end
    def erase!; @erased=true; end
    def transform!(tr); @transformation=@transformation+tr; end
  end
  Vertex=Struct.new(:position)
  class Face < Entity
    attr_reader :points,:normal
    def initialize(pts)
      super(); @points=pts.map { |p| p.respond_to?(:to_a) ? p.to_a : p }
      a,b,c=@points.first(3)
      u=b.zip(a).map { |x,y| x-y }; v=c.zip(a).map { |x,y| x-y }
      n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
      length=Math.sqrt(n.sum { |x| x*x }); raise 'Degenerate face' if length < 1e-10
      @normal=Geom::Vector3d.new(n.map { |x| x/length })
    end
    def reverse!; @normal=Geom::Vector3d.new(normal.to_a.map { |x| -x }); end
    def pushpull(distance)
      @base=@points.dup; @distance=distance
      @points+=@points.map { |p| p.zip(normal.to_a).map { |a,n| a+n*distance } }
    end
    def vertices; points.map { |p| Vertex.new(Geom::Point3d.new(p)) }; end
    def outer_loop; Struct.new(:vertices).new((@base || points).map { |p| Vertex.new(Geom::Point3d.new(p)) }); end
    def mesh
      base=@base || points; top=@points[base.size,base.size]
      polygons=top ? [base,top]+base.each_index.map { |i| [base[i],base[(i+1)%base.size],top[(i+1)%base.size],top[i]] } : [base]
      PolygonMesh.new(polygons)
    end
  end
  class PolygonMesh
    attr_reader :polygons
    def initialize(polys)
      @points=[]; @polygons=polys.map { |poly| poly.map { |p| @points << Geom::Point3d.new(p); @points.size } }
    end
    def point_at(i); @points[i-1]; end
  end
  class Edge < Entity; end
  class ConstructionLine < Entity
    attr_reader :ends
    def initialize(a,b); super(); @ends=[a,b]; end
    def start; ends[0]; end
    def end; ends[1]; end
  end
  class Entities < Array
    def add_group; e=Group.new; self << e; e; end
    def add_face(p); e=Face.new(p); self << e; e; end
    def add_cline(a,b); e=ConstructionLine.new(a,b); self << e; e; end
    def transform_entities(tr,items); items.each { |e| e.transform!(tr) }; end
    def clear!; clear; end
  end
  class Group < Entity
    attr_accessor :definition
    def entities; definition.entities; end
    def initialize
      super(); @entities=Entities.new; @definition=Definition.new(@entities)
    end
    def to_component
      self
    end
  end
  class ComponentInstance < Group; end
  class Definition < Entity
    attr_reader :entities
    def initialize(e); super(); @entities=e; end
  end
  class Layers < Hash
    def initialize; super; self[0]='Untagged'; end
    def add(n); self[n]=n; end
  end
  class Model
    attr_reader :layers,:selection,:operations,:materials
    def initialize; @layers=Layers.new; @selection=[]; @operations=0; @materials=Materials.new; end
    def start_operation(*_); @operations+=1; end
  end
  class Color
    attr_reader :rgb
    def initialize(*rgb); @rgb=rgb; end
  end
  class Material
    attr_accessor :name,:color,:alpha
  end
  class Materials < Hash
    def add(name); material=Material.new; material.name=name; self[name]=material; end
  end
  def self.active_model; @model ||= Model.new; end
  def self.read_default(*a); a.last; end
  class InputPoint
    attr_accessor :position
    def initialize; @position=Geom::Point3d.new(0,0,0); end
    def valid?; true; end
  end
end
ORIGIN=Geom::Point3d.new(0,0,0)
Z_AXIS=Geom::Vector3d.new(0,0,1)
module UI
  def self.messagebox(m); puts "UI: #{m}"; end
end
def file_loaded?(*_); true; end
