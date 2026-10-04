# Orchestration / geometry simulation, not the native SketchUp kernel.
require 'fileutils'
$LOADED_FEATURES << 'sketchup.rb'
$LOADED_FEATURES << 'extensions.rb'
TB_NEVER_SHOWN = 0
def file_loaded?(path); ($loaded ||= []).include?(path); end
def file_loaded(path); ($loaded ||= []) << path; end
class SketchupExtension
  attr_accessor :description, :version, :creator, :copyright
  def initialize(*); end
end
module Sketchup
  class EntityObserver; end
  class ModelObserver; end
  class << self
    attr_accessor :active_model
    def read_default(section, key, fallback); (@prefs ||= {}).fetch([section, key], fallback); end
    def write_default(section, key, value); (@prefs ||= {})[[section, key]] = value; end
    def register_extension(*); end
    def version; '22.0'; end
    def platform; :platform_win; end
    def status_text=(_); end
    def send_action(action); @action = action; true; end
    def create_texture_writer; Object.new; end
  end
end
module UI
  class Command
    attr_accessor :tooltip, :status_bar_text, :small_icon, :large_icon
    def initialize(*); end
  end
  class Toolbar
    def initialize(*); end
    def add_item(*); end
    def get_last_state; 0; end
    def show; end
  end
  class Menu
    def add_submenu(*); self; end
    def add_item(*); end
    def add_separator; end
  end
  def self.menu(*); Menu.new; end
  def self.add_context_menu_handler; end
  def self.messagebox(*); end
end
module Geom
  class Vector3d
    attr_accessor :x, :y, :z
    def initialize(x,y,z); @x,@y,@z=x.to_f,y.to_f,z.to_f; end
    def length; Math.sqrt(dot(self)); end
    def dot(other); x*other.x+y*other.y+z*other.z; end
    def cross(other); self.class.new(y*other.z-z*other.y,z*other.x-x*other.z,x*other.y-y*other.x); end
    def normalize; self.class.new(x/length,y/length,z/length); end
    def to_a; [x,y,z]; end
  end
  class Point3d < Vector3d
    def -(other); Vector3d.new(x-other.x,y-other.y,z-other.z); end
    def distance(other); (self-other).length; end
    def offset(vector, distance); vector=vector.normalize; Point3d.new(x+vector.x*distance,y+vector.y*distance,z+vector.z*distance); end
  end
end
Texture = Struct.new(:width, :height, :size)
class TestMaterial
  attr_accessor :name, :texture
  def initialize(name='Oak'); @name=name; @texture=Texture.new(10,20); @attributes={}; end
  def valid?; true; end
  def get_attribute(section,key); @attributes[[section,key]]; end
  def set_attribute(section,key,value); @attributes[[section,key]]=value; end
end
Vertex = Struct.new(:position)
Edge = Struct.new(:start, :end) do
  def length; start.position.distance(self.end.position); end
end
Loop = Struct.new(:vertices, :edges)
module Sketchup
  class Face
    attr_accessor :material, :hidden, :mapping
    attr_reader :outer_loop
    def initialize(material=nil)
      @material=material; @hidden=false
      vertices=[[0,0,0],[20,0,0],[20,10,0],[0,10,0]].map { |p| Vertex.new(Geom::Point3d.new(*p)) }
      @outer_loop=Loop.new(vertices, 4.times.map { |i| Edge.new(vertices[i],vertices[(i+1)%4]) })
    end
    def valid?; true; end
    def hidden?; hidden; end
    def normal; Geom::Vector3d.new(0,0,1); end
    def get_UVHelper(*); self; end
    def get_front_UVQ(point); Geom::Point3d.new(point.x/10,point.y/20,1); end
    def clear_texture_projection(*); end
    def clear_texture_position(*); @mapping=nil; end
    def position_material(material,mapping,_); @material=material; @mapping=mapping; self; end
  end
  class ComponentInstance
    attr_accessor :material, :definition, :locked, :hidden
    def initialize(definition, material=nil); @definition=definition; @material=material; @locked=@hidden=false; definition.instances << self; end
    def valid?; true; end
    def hidden?; hidden; end
    def locked?; locked; end
    def make_unique
      return if definition.instances.size < 2
      old=definition; copy=Marshal.load(Marshal.dump(old.entities)); @definition=Definition.new(copy, [self]); old.instances.delete(self)
    end
  end
  class Group < ComponentInstance
    def entities; definition.entities; end
  end
end
Definition=Struct.new(:entities,:instances)
class Model
  attr_accessor :selection, :materials, :active_path
  attr_reader :commits, :aborts
  def initialize(selection=[]); @selection=selection; @materials=[]; @active_path=nil; @commits=@aborts=0; end
  def start_operation(*); true; end
  def commit_operation; @commits+=1; end
  def abort_operation; @aborts+=1; end
end
require '/workspace/runtime/vgd_library.rb'
require '/workspace/runtime/vgd_library/main.rb'
def assert(condition, text); raise text unless condition; end
def near(a,b); (a-b).abs < 1e-8; end
def rejects(text)
  begin; yield; rescue StandardError => e; assert(e.message.include?(text), "Wrong error: #{e.message}"); return; end
  raise "Expected rejection: #{text}"
end
G=VGD::Library::Geometry
M=VGD::Library::Materials
C=VGD::Library::Catalog
assert(near(M.dimension(254),10), 'mm/in conversion')
rejects('Kích thước') { M.dimension(0) }
rejects('Kích thước') { M.dimension(Float::INFINITY) }
u,v=G.uv_transform(1,0,Math::PI/2,0,0,0,0,10,20)
assert(near(u,0) && near(v,0.5), 'Non-square physical UV rotation distorts scale')
u,v=G.uv_transform(0.2,0.3,0,0.4,0.1)
assert(near(u,0.6) && near(v,0.4), 'UV offsets')
material=TestMaterial.new
face=Sketchup::Face.new(material)
model=Model.new([face]); Sketchup.active_model=model
G.edit(model,'rotate',90)
assert(face.mapping.size==6, 'Three UV pairs required')
G.fit(face,material)
assert(face.mapping[2].to_a==[20.0,0.0,0.0] && face.mapping[4].to_a==[0.0,10.0,0.0], 'Fit bounds')
G.edit(model,'restore'); assert(near(face.mapping[3].x,2) && near(face.mapping[5].y,0.5), 'Restore real material dimensions')
G.edit(model,'reset_uv'); assert(face.mapping.nil?, 'Restore default UVs')
rejects('Chọn mặt') { G.edit(Model.new,'rotate') }
rejects('không có mặt') { G.edit(Model.new([Sketchup::Face.new]),'rotate') }
# Two selected/unselected instances share a definition; only selected changes.
plain=Sketchup::Face.new
definition=Definition.new([plain],[])
selected=Sketchup::ComponentInstance.new(definition,material)
outside=Sketchup::ComponentInstance.new(definition,material)
G.edit(Model.new([selected]),'rotate')
assert(selected.definition != outside.definition, 'Selected component not isolated')
assert(outside.definition.entities.first.material.nil?, 'Unselected component modified')
assert(selected.definition.entities.first.material.name=='Oak', 'Inherited material not resolved')
locked=Sketchup::Group.new(Definition.new([Sketchup::Face.new(material)],[])); locked.locked=true
rejects('không có mặt') { G.edit(Model.new([locked]),'rotate') }
# Editing inside a shared context rejects before starting an operation.
shared=Definition.new([],[]); a=Sketchup::ComponentInstance.new(shared); b=Sketchup::ComponentInstance.new(shared)
model=Model.new([face]); model.active_path=[a]; Sketchup.active_model=model
rejects('dùng chung') { VGD::Library.transaction('test') { raise 'should not run' } }
assert(model.aborts==0, 'No foreign operation aborted')
model.active_path=nil
rejects('test failure') { VGD::Library.transaction('test') { raise 'test failure' } }
assert(model.aborts==1 && model.commits==0, 'Failed operation must abort')
VGD::Library.transaction('test') { true }; assert(model.commits==1, 'Successful operation must commit')
rejects('Model đang mở') { VGD::Library.dispatch('rotate', JSON.generate({model_id:'stale-model'})) }
# Favorites and folder catalog persist without importing materials or networking.
# Windows WASI cannot enumerate directories. Use a virtual tree for catalog
# traversal only; the production scanner itself executes unmodified.
module CatalogFixtureFiles
  FILES=['/fixture/library/Gỗ sồi/A 01.PNG','/fixture/library/Gỗ sồi/A 02.skm','/fixture/library/Gỗ sồi/A 02.png','/fixture/library/Gỗ sồi/not-ruby.rb','/fixture/library/Gỗ sồi/Pack.rar'].freeze
  DIRS=['/fixture/library','/fixture/library/Gỗ sồi'].freeze
  def directory?(path); path.start_with?('/fixture/') ? DIRS.include?(path) : super; end
  def file?(path); path.start_with?('/fixture/') ? FILES.include?(path) : super; end
  def symlink?(path); path.start_with?('/fixture/') ? false : super; end
  def realpath(path); path.start_with?('/fixture/') ? path : super; end
end
File.singleton_class.prepend(CatalogFixtureFiles)
module CatalogFixtureDirs
  def children(path)
    return ['Gỗ sồi'] if path=='/fixture/library'
    return CatalogFixtureFiles::FILES.map { |file| File.basename(file) } if path=='/fixture/library/Gỗ sồi'
    super
  end
end
Dir.singleton_class.prepend(CatalogFixtureDirs)
C.add_folder('/fixture/library'); C.add_folder('/fixture/library/Gỗ sồi')
scanned=C.scan.to_a.compact
items=scanned.reject { |item| item[:warning] }
assert(items.size==3, "Catalog incorrect: #{scanned.inspect}; roots=#{C.roots.inspect}")
assert(scanned.any? { |item| item[:warning].to_s.include?('1 tệp RAR/ZIP/7Z') }, 'Unextracted archives should be reported')
assert(items.find { |item| item[:format]=='SKM' }[:preview].include?('A%2002.png'), 'SKM adjacent preview')
assert(C.file_url('C:/Maps/Gỗ #1.png').include?('G%E1%BB%97%20%231.png'), 'Unicode/hash URL escaping')
C.save('favorites',[items.first[:id]]); assert(C.favorites==[items.first[:id]], 'Favorites persisted')
C.remove_folder('/fixture/library'); assert(File.file?('/fixture/library/Gỗ sồi/A 01.PNG'), 'Remove source deleted files')
puts 'PASS: dimensions, non-square UVs, fit, inheritance, instance isolation, locks, shared edit context, operation rollback, catalog, Unicode, SKM preview, favorites.'
