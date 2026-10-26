# Mô phỏng tối thiểu API SketchUp để chạy thử logic thuần Ruby. KHÔNG thay thế thử nghiệm trong SketchUp thật.
require 'json'
class Numeric
  def mm; self / 25.4; end
  def to_mm; self * 25.4; end
end
module Geom
  class Vector3d
    attr_accessor :x, :y, :z
    def initialize(x=0,y=0,z=0); @x,@y,@z = x.to_f,y.to_f,z.to_f; end
    def to_a; [x,y,z]; end
    def length; Math.sqrt(x*x+y*y+z*z); end
    def normalize!; l=length; @x/=l; @y/=l; @z/=l; self; end
    def normalize; Vector3d.new(*to_a).normalize!; end
    def dot(o); x*o.x+y*o.y+z*o.z; end
    def cross(o); Vector3d.new(y*o.z-z*o.y, z*o.x-x*o.z, x*o.y-y*o.x); end
    def reverse; Vector3d.new(-x,-y,-z); end
    def transform(t); a=t.apply_vec(to_a); Vector3d.new(*a); end
    def -@; reverse; end
  end
  class Point3d
    attr_accessor :x,:y,:z
    def initialize(x=0,y=0,z=0)
      x, y, z = x.to_a if x.respond_to?(:to_a) && !x.is_a?(Numeric)
      @x,@y,@z = x.to_f,y.to_f,z.to_f
    end
    def to_a; [x,y,z]; end
    def transform(t); Point3d.new(*t.apply_pt(to_a)); end
    def -(o); Vector3d.new(x-o.x,y-o.y,z-o.z); end
  end
  class Transformation
    attr_reader :m # 3x3 columns + translation
    def initialize(m=nil); @m = m || [[1,0,0],[0,1,0],[0,0,1],[0,0,0]]; end
    def self.axes(o,x,y,z); new([x.to_a,y.to_a,z.to_a,o.to_a]); end
    def self.translation(v); new([[1,0,0],[0,1,0],[0,0,1],v.to_a]); end
    def apply_vec(v); (0..2).map{|i| m[0][i]*v[0]+m[1][i]*v[1]+m[2][i]*v[2]}; end
    def apply_pt(v); a=apply_vec(v); (0..2).map{|i| a[i]+m[3][i]}; end
    def *(o)
      cols = [[1,0,0],[0,1,0],[0,0,1]].map{|e| apply_vec(o.apply_vec(e))}
      Transformation.new(cols + [apply_pt(o.m[3])])
    end
    def inverse
      r=m[0..2]; # orthonormal assumed with scale 1
      inv=[[r[0][0],r[1][0],r[2][0]],[r[0][1],r[1][1],r[2][1]],[r[0][2],r[1][2],r[2][2]]]
      t=Transformation.new(inv+[[0,0,0]]); tr=t.apply_vec(m[3]); Transformation.new(inv+[tr.map{|n|-n}])
    end
    def xscale; Vector3d.new(*m[0]).length; end
    def yscale; Vector3d.new(*m[1]).length; end
    def zscale; Vector3d.new(*m[2]).length; end
    def origin; Point3d.new(*m[3]); end
  end
  def self.tesselate(*); []; end
end
X_AXIS=Geom::Vector3d.new(1,0,0); Y_AXIS=Geom::Vector3d.new(0,1,0); Z_AXIS=Geom::Vector3d.new(0,0,1)
module Sketchup
  class Entity
    attr_accessor :layer, :material
    attr_writer :name
    # Giống SketchUp thật: gọi hàm trên entity đã xóa thì báo "reference to deleted ...".
    def __deleted!; raise TypeError, "reference to deleted #{self.class.name.to_s.split('::').last}" if @erased; end
    def name; __deleted!; @name; end
    def attribute_dictionaries; __deleted!; @dicts && !@dicts.empty? ? @dicts.map{|n,h| Dict.new(n,h)} : nil; end
    def set_attribute(d,k,v); __deleted!; (@dicts||={})[d]||={}; @dicts[d][k]=v; end
    def get_attribute(d,k,default=nil); __deleted!; (@dicts && @dicts[d] && @dicts[d].key?(k)) ? @dicts[d][k] : default; end
    def erased?; !!@erased; end
    def delete_attribute(d,k=nil); __deleted!; if k.nil? then (@dicts||={}).delete(d) else (@dicts && @dicts[d]) && @dicts[d].delete(k) end; end
    def visible?; __deleted!; @visible.nil? ? true : @visible; end
    def visible=(v); __deleted!; @visible=v; end
  end
  class Dict
    attr_reader :name
    def initialize(n,h); @name=n; @h=h; end
    def each_pair(&b); @h.each_pair(&b); end
  end
  class Vertex; attr_reader :position; def initialize(p); @position=p; end; end
  class Face < Entity
    attr_reader :pts, :ext
    def initialize(pts); @pts=pts; @flip=false; @ext=0; end
    def normal
      a=pts[0]; b=pts[1]; c=pts[2]
      n=(b-a).cross(c-b).normalize; @flip ? n.reverse : n
    end
    def reverse!; @flip=!@flip; self; end
    def area; 1.0; end
    def vertices; pts.map{|p| Vertex.new(p)}; end
    class Loop
      def initialize(pts, outer); @pts=pts; @outer=outer; end
      def vertices; @pts.map{|p| Vertex.new(p)}; end
      def outer?; @outer; end
    end
    def outer_loop; @outer_loop ||= Loop.new(pts, true); end
    def loops; [outer_loop] + (@holes||[]).map{|h| Loop.new(h, false)}; end
    def holes=(h); @holes=h; end
    def parent_entities=(e); @pe=e; end
    def parent; @pe.owner; end
    def erase!; @erased=true; end
    def pushpull(d); @ext=d; @pushed = true; end
    def pushed?; !!@pushed; end
  end
  class Bounds
    def initialize(pts); @pts=pts; end
    def min; Geom::Point3d.new(*(0..2).map{|i| @pts.map{|p|p.to_a[i]}.min}); end
    def max; Geom::Point3d.new(*(0..2).map{|i| @pts.map{|p|p.to_a[i]}.max}); end
    def corner(i)
      mn,mx=min,max; Geom::Point3d.new(i&1==0 ? mn.x : mx.x, i&2==0 ? mn.y : mx.y, i&4==0 ? mn.z : mx.z)
    end
  end
  class Entities
    include Enumerable
    attr_reader :owner
    def initialize(owner); @owner=owner; @list=[]; end
    def each(&b); @list.reject(&:erased?).each(&b); end
    def to_a; @list.reject(&:erased?); end
    def length; to_a.length; end
    def add_group; g=Group.new(self); @list<<g; g; end
    def add_face(*pts); pts=pts[0] if pts.length==1 && pts[0].is_a?(Array); pts=pts.map{|p| p.is_a?(Geom::Point3d) ? p : Geom::Point3d.new(*p)}; f=Face.new(pts); f.parent_entities=self; @list<<f; f; end
    def add_instance(defn,tr); i=ComponentInstance.new(self,defn,tr); @list<<i; i; end
    def transform_entities(*); end
    def push(e); @list<<e; end
  end
  class Definition
    attr_accessor :name
    attr_reader :entities
    def initialize(owner_entity=nil); @entities=Entities.new(self); end
    def bounds
      pts=[]
      collect(@entities,Geom::Transformation.new,pts)
      pts=[Geom::Point3d.new] if pts.empty?
      Bounds.new(pts)
    end
    def collect(ents,tr,pts)
      ents.each do |e|
        case e
        when Face
          e.pts.each{|p| pts<<p.transform(tr)}
          if e.pushed?
            nrm=e.normal; v=Geom::Vector3d.new(nrm.x*e.ext,nrm.y*e.ext,nrm.z*e.ext)
            e.pts.each{|p| pts<<Geom::Point3d.new(p.x+v.x,p.y+v.y,p.z+v.z).transform(tr)}
          end
        when Group, ComponentInstance
          collect(e.definition.entities, tr*e.transformation, pts)
        end
      end
    end
  end
  class Group < Entity
    attr_accessor :transformation
    attr_reader :parent_entities, :definition
    def initialize(parent_entities); @parent_entities=parent_entities; @definition=Definition.new; @transformation=Geom::Transformation.new; end
    def entities; @definition.entities; end
    def transform!(t); @transformation = t * @transformation; self; end
    def parent; @parent_entities.owner; end
    def erase!; @erased=true; end
    def to_component
      i=ComponentInstance.new(@parent_entities,@definition,@transformation)
      i.name=name; i.layer=layer; i.material=material
      # Giả định xấu nhất: thuộc tính không được giữ lại khi chuyển thành component.
      @erased=true; @parent_entities.push(i); i
    end
  end
  class ComponentInstance < Entity
    attr_accessor :transformation
    attr_reader :definition
    def initialize(pe,defn,tr); @pe=pe; @definition=defn; @transformation=tr; end
    def parent; @pe.owner; end
    def erase!; @erased=true; end
  end
  class Layer; attr_reader :name; def initialize(n);@name=n;end; end
  class Layers; def initialize; @h={}; end; def [](n); @h[n]; end; def add(n); @h[n]=Layer.new(n); end; end
  class Model
    attr_reader :layers, :entities, :selection, :tool, :ops
    attr_accessor :active_path # SketchUp: nil khi đang ở gốc model, hoặc mảng group đang mở
    def initialize; @layers=Layers.new; @entities=Definition.new.entities; @selection=[]; @ops=[]; @active_path=nil; end
    def start_operation(*a); @ops<<[:start]; true; end
    def commit_operation; @ops<<[:commit]; end
    def abort_operation; @ops<<[:abort]; end
    def active_view; @view ||= View.new; end
    def select_tool(t); @tool.deactivate(active_view) if @tool; @tool=t; t.activate if t; end
  end
  class View
    attr_reader :invalidated
    def invalidate; @invalidated=true; end
    def vpwidth; 1000; end
    def vpheight; 800; end
  end
  @model=Model.new
  def self.active_model; @model; end
  def self.reset_model!; @model=Model.new; end
  def self.status_text=(s); @status=s; end
  def self.status_text; @status; end
  def self.set_status_text(*); end
end
module UI
  def self.messagebox(m, *_); (@msgs||=[]) << m; @next_answer; end
  def self.next_answer=(v); @next_answer = v; end
  def self.msgs; @msgs||=[]; end
  def self.start_timer(*, &b); b.call if b; end
  def self.inputbox(*a); @inputbox_calls = (@inputbox_calls || []) << a; @next_input; end
  def self.next_input=(v); @next_input = v; end
  def self.inputbox_calls; @inputbox_calls || []; end
  class Command; def set_validation_proc(&b); @vp=b; end; def validation; @vp ? @vp.call : 0; end; attr_accessor :tooltip,:status_bar_text,:menu_text,:small_icon,:large_icon; attr_reader :title; def initialize(n,&b);@title=n;@b=b;end; def run; @b.call; end; end
  class Menu; attr_reader :items, :subs; def initialize;@items=[];@subs={};end; def add_item(x,&b); @items<<x; end; def add_submenu(n); @items<<n; @subs[n]||=Menu.new; end; def add_separator; end; def set_validation_proc(*); end; end
  def self.add_context_menu_handler(&b); (@ctx_handlers ||= []) << b; end
  def self.context_handlers; @ctx_handlers ||= []; end
  def self.menu(n); (@menus||={})[n]||=Menu.new; end
  def self.menus; @menus||={}; end
  class Toolbar; attr_reader :commands; def initialize(n);@commands=[];end; def add_item(c);@commands<<c;end; def restore;end; def get_last_state; 0;end; def show;end; end
  class HtmlDialog
    STYLE_DIALOG=1
    attr_reader :scripts, :callbacks
    def initialize(*); @scripts=[]; @callbacks={}; @visible=false; end
    def set_file(*);end
    def add_action_callback(n,&b); @callbacks[n]=b; end
    def set_on_closed(&b); @closed=b; end
    def show; @visible=true; end
    def visible?; @visible; end
    def close; @visible=false; @closed&.call; end
    def execute_script(s); @scripts<<s; end
    def call(n,payload=''); @callbacks.fetch(n).call(nil,payload); end
  end
end
TB_HIDDEN=0
CONSTRAIN_MODIFIER_MASK=8; COPY_MODIFIER_MASK=4; ALT_MODIFIER_MASK=32
class SketchupExtension; def initialize(*);end; attr_accessor :version,:description,:creator,:copyright; end
module Sketchup
  def self.register_extension(*);end
end
# ---- phần bổ sung cho công cụ tương tác ----
GL_POLYGON=9; GL_QUADS=7; GL_LINES=1; GL_LINE_LOOP=2; GL_TRIANGLES=4
module Sketchup
  class Entity
    @@pid = 0
    def persistent_id; @pid ||= (@@pid += 1); end
    def valid?; !@erased; end
  end
  class Color; attr_reader :a; def initialize(*a); @a=a; end; end
  class Selection
    include Enumerable
    def initialize; @l=[]; end
    def each(&b); @l.each(&b); end
    def clear; @l.clear; end
    def add(e); @l<<e; end
    def remove(e); @l.delete(e); end
    def length; @l.length; end
    def to_a; @l.dup; end
  end
  class Model
    def selection; @sel ||= Selection.new; end
    def active_entities; (active_path.nil? || active_path.empty?) ? entities : active_path.last.entities; end
    def edit_transform; Geom::Transformation.new; end
  end
  class Bounds; def center; mn,mx=min,max; Geom::Point3d.new((mn.x+mx.x)/2,(mn.y+mx.y)/2,(mn.z+mx.z)/2); end; end
  class PickHelper
    attr_accessor :path
    def do_pick(x,y); end
    def path_at(i); path; end
    def best_picked; nil; end
    def count; 0; end
  end
  class InputPoint
    attr_accessor :fake
    def initialize; end
    def pick(v,x,y); @fake = v.fake_point; end
    def valid?; !!@fake; end
    def position; @fake; end
    def draw(v); end
  end
  class View
    attr_accessor :fake_point, :fake_path, :drawn
    def model; Sketchup.active_model; end
    def pick_helper; h=PickHelper.new; h.path=@fake_path; h; end
    def drawing_color=(c); end
    def draw2d(*a); (@drawn||=[]) << [:draw2d,a]; end
    def draw(*a); (@drawn||=[]) << [:draw,a]; end
    def draw_text(*a); (@drawn||=[]) << [:text,a]; end
    def draw_lines(*a); end
    def line_width=(w); end
  end
end
module Sketchup; class Model; def active_view; @view ||= View.new; end; end; end
module Geom; class Point3d; def distance(o); (self-o).length; end; end; end
module Sketchup
  class Camera; def eye; Geom::Point3d.new(-5000,-5000,5000); end; def direction; Geom::Vector3d.new(1,1,-1).normalize; end; end
  class View
    def camera; Camera.new; end
    def screen_coords(p); Geom::Point3d.new(p.x*0.1+400, p.y*0.1+300, 0); end
    def line_stipple=(s); end
  end
end

$erased_new = 0
module Sketchup
  class Model
    alias_method :_start, :start_operation
    def start_operation(*a); @in_op = true; _start(*a); end
    alias_method :_commit, :commit_operation
    def commit_operation; @in_op = false; raise TypeError, 'reference to deleted Group' if $observer_fails; _commit; end
    alias_method :_abort, :abort_operation
    def abort_operation; @in_op = false; _abort; end
    def in_op?; !!@in_op; end
  end
  class Entities
    alias_method :_add_group, :add_group
    def add_group; g = _add_group; g.instance_variable_set(:@born_in_op, Sketchup.active_model.in_op?); g; end
  end
  class Group
    alias_method :_erase, :erase!
    def erase!; $erased_new += 1 if @born_in_op && Sketchup.active_model.in_op?; _erase; end
  end
end
class Numeric; def degrees; self * Math::PI / 180.0; end; end
module Geom
  class Transformation
    def zaxis; Vector3d.new(*m[2]).normalize; end
    def xaxis; Vector3d.new(*m[0]).normalize; end
    def yaxis; Vector3d.new(*m[1]).normalize; end
    def self.rotation(pt, axis, ang)
      a = axis.normalize; c = Math.cos(ang); s = Math.sin(ang); t = 1 - c
      x, y, z = a.x, a.y, a.z
      r = [[t*x*x+c, t*x*y+s*z, t*x*z-s*y], [t*x*y-s*z, t*y*y+c, t*y*z+s*x], [t*x*z+s*y, t*y*z-s*x, t*z*z+c]]
      base = new(r + [[0,0,0]])
      moved = base.apply_pt(pt.to_a)
      new(r + [[pt.x - moved[0], pt.y - moved[1], pt.z - moved[2]]])
    end
  end
end
module Sketchup
  class Materials
    def initialize; @h = {}; end
    def [](n); @h[n]; end
    def add(n); @h[n] = Material.new; end
  end
  class Material; attr_accessor :color, :alpha; end
  class Model; def materials; @materials ||= Materials.new; end; end
end
module Sketchup; class Bounds; def width; max.x - min.x; end; def height; max.z - min.z; end; def depth; max.y - min.y; end; end; end
module Sketchup
  class Sketchup::Edge < Entity
    attr_reader :a, :b
    def initialize(a, b); @a = a; @b = b; end
    def bounds; Bounds.new([a, b]); end
  end
  class Entities
    def add_line(p, q)
      pt = ->(v) { v.is_a?(Geom::Point3d) ? v : Geom::Point3d.new(*v) }
      e = Edge.new(pt.(p), pt.(q)); @list << e; e
    end
  end
  class Face; def bounds; Definition.new.tap { |d| }.then { Bounds.new(pts + (pushed? ? pts.map { |p| n = normal; Geom::Point3d.new(p.x + n.x * ext, p.y + n.y * ext, p.z + n.z * ext) } : [])) }; end; end
  class Group; def bounds; definition.bounds; end; end
  class ComponentInstance; def bounds; definition.bounds; end; end
  def self.vcb_label=(v); @vcb_label = v; end
  def self.vcb_value=(v); @vcb_value = v; end
  def self.vcb_value; @vcb_value; end
end

# ---- bổ sung beta.23 ----
GL_LINE_STRIP = 3 unless defined?(GL_LINE_STRIP)
COPY_MODIFIER_KEY = 17 unless defined?(COPY_MODIFIER_KEY)
module Geom
  class Point3d
    def offset(v, len = nil)
      if len then Point3d.new(x + v.x * len, y + v.y * len, z + v.z * len) else Point3d.new(x + v.x, y + v.y, z + v.z) end
    end
  end
  def self.intersect_line_plane(line, plane)
    p0, v = line
    q, n = plane
    den = n.dot(v)
    return nil if den.abs < 1e-12
    t = n.dot(q - p0) / den
    Point3d.new(p0.x + v.x * t, p0.y + v.y * t, p0.z + v.z * t)
  end
end
module Sketchup
  class ToolsObserver; end
  class SelectionObserver; end
  class Tools
    attr_reader :observers
    def initialize; @observers = []; end
    def add_observer(o); @observers << o; end
    def remove_observer(o); @observers.delete(o); end
  end
  class Model
    def tools; @tools ||= Tools.new; end
  end
  class View
    attr_accessor :fake_ray
    # Mặc định: tia nhìn thẳng dọc +Y qua điểm giả (nhìn trực diện mặt trước).
    def pickray(_x, _y)
      return @fake_ray if @fake_ray
      p = @fake_point || Geom::Point3d.new(0, 0, 0)
      [Geom::Point3d.new(p.x, p.y - 10000, p.z), Geom::Vector3d.new(0, 1, 0)]
    end
    def pixels_to_model(px, _pt); px * 2.0; end
  end
end

# ---- Hỗ trợ co giãn tại chỗ (test_stretch.rb): biến đổi hình học, sao chép, texture, observer, mặc định ----
module Geom
  class Transformation
    def self.scaling(x, y, z)
      new([[x.to_f, 0.0, 0.0], [0.0, y.to_f, 0.0], [0.0, 0.0, z.to_f], [0.0, 0.0, 0.0]])
    end
  end
end
module Sketchup
  class ModelObserver; end
  class AppObserver; end
  @defaults = {}
  class << self
    def add_observer(o); (@app_observers ||= []) << o; end
    def read_default(section, key, default = nil); @defaults.fetch([section, key], default); end
    def write_default(section, key, value); @defaults[[section, key]] = value; end
  end
  class Entity
    def dup_dicts; @dicts && @dicts.transform_values(&:dup); end
    def placed_bounds(box, t); Bounds.new([box.min, box.max].map { |p| p.transform(t) }); end
  end
  class Face
    attr_accessor :back_material
    def apply_transform!(t)
      n = normal
      @ext = @ext * Math.sqrt(t.apply_vec(n.to_a).sum { |c| c * c }) if pushed?
      @pts = @pts.map { |p| p.transform(t) }
      self
    end
    def position_material(material, points, front)
      (@positioned ||= []) << [material, points, front]
      true
    end
    def positioned; @positioned || []; end
    def copy_into(entities)
      f = Face.new(@pts.map { |p| Geom::Point3d.new(p.x, p.y, p.z) })
      f.instance_variable_set(:@flip, @flip)
      f.instance_variable_set(:@ext, @ext)
      f.instance_variable_set(:@pushed, @pushed)
      f.material = material
      f.back_material = back_material
      f.parent_entities = entities
      f.instance_variable_set(:@dicts, dup_dicts)
      f
    end
  end
  class Entities
    def transform_entities(t, ents = nil)
      (ents.nil? ? to_a : Array(ents)).each do |e|
        if e.is_a?(Face) then e.apply_transform!(t)
        elsif e.is_a?(Group) || e.is_a?(ComponentInstance) then e.transformation = t * e.transformation
        end
      end
      true
    end
  end
  class Definition
    def deep_copy
      copy = Definition.new
      copy.name = name
      entities.to_a.each { |e| copy.entities.push(e.copy_into(copy.entities)) }
      copy
    end
  end
  class Group
    def bounds; placed_bounds(definition.bounds, transformation); end
    def make_unique; self; end
    def copy_into(entities)
      g = Group.new(entities)
      g.transformation = transformation
      g.name = name
      g.layer = layer
      g.material = material
      g.instance_variable_set(:@definition, definition.deep_copy)
      g.instance_variable_set(:@dicts, dup_dicts)
      g
    end
  end
  class ComponentInstance
    def bounds; placed_bounds(definition.bounds, transformation); end
    def make_unique; @definition = @definition.deep_copy; self; end
    def copy_into(entities)
      i = ComponentInstance.new(entities, definition, transformation)
      i.name = name
      i.layer = layer
      i.material = material
      i.instance_variable_set(:@dicts, dup_dicts)
      i
    end
  end
  class Model
    def add_observer(o); (@model_observers ||= []) << o; end
    def remove_observer(o); (@model_observers ||= []).delete(o); end
  end
end
