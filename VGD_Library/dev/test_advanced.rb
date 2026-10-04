module Sketchup
  def self.platform; :platform_win; end
  class ImageRep
    attr_reader :width,:height,:bits_per_pixel,:row_padding,:data
    def set_data(w,h,bpp,pad,data); @width,@height,@bits_per_pixel,@row_padding,@data=w,h,bpp,pad,data; self; end
  end
  class Face
    attr_accessor :back_material
    def persistent_id; object_id; end
  end
end
P=VGD::Library::Pixels
A=VGD::Library::Advanced
class TestMaterial
  def display_name; name; end
end
rep=Sketchup::ImageRep.new.set_data(2,1,24,2,[30,20,10,60,50,40,0,0].pack('C*'))
pixels=P.from_rep(rep)
assert(pixels.rgba==[10,20,30,255,40,50,60,255], 'BGR/padding decode wrong')
assert(P.to_rep(pixels).data.unpack('C*')==[30,20,10,255,60,50,40,255], 'BGR output wrong')
uv_rep = Object.new
def uv_rep.width; 2; end
def uv_rep.height; 2; end
def uv_rep.color_at_uv(u, v, bilinear)
  raise 'Unexpected bilinear sampling' if bilinear
  Struct.new(:to_a).new([u < 0.5 ? 10 : 20, v < 0.5 ? 30 : 40, 0, 255])
end
assert(P.from_uv(uv_rep).rgba==[10,30,0,255,20,30,0,255,10,40,0,255,20,40,0,255], 'Trace UV axes or row orientation wrong')
assert(P.blur(Array.new(16,0.25),4,4,2).all? { |v| near(v,0.25) }, 'Constant blur drift')
image=P::Image.new(4,4,16.times.flat_map { |i| [i*15,i*12,i*10,255] })
fixed=P.seamless(image,0.5,0.1)
assert(P.seam_error(image)>1 && near(P.seam_error(fixed),0), 'Seam boundaries not joined')
assert(fixed.rgba.all? { |v| v.is_a?(Integer) && v.between?(0,255) }, 'Invalid output pixels')
flat=P::Image.new(4,4,[120,120,120,255]*16)
maps=P.auxiliary(flat)
assert(maps.size==5 && maps.values.all? { |v| v.rgba.size==64 }, 'Aux map sizes/names wrong')
assert(maps['04_Normal'].rgba.first(4)==[128,128,255,255], 'Flat normal not neutral')
assert(maps['04_Normal_DirectX'].rgba.first(4)==[128,128,255,255], 'Flat DirectX normal not neutral')
assert(maps['05_AO'].rgba.all? { |v| v==255 }, 'Flat AO should be white')
rejects('Cường độ') { P.auxiliary(flat,'wood',Float::INFINITY) }
assert(P.contours(flat,4,0.5,true).empty?, 'Uniform image background not removed')
logo=P::Image.new(5,5,25.times.flat_map { |i| x,y=i%5,i/5; (x.between?(1,3) && y.between?(1,3)) ? [0,0,0,255] : [255,255,255,255] })
loops=P.contours(logo,2,0.5,true)
assert(loops.size==1 && loops[0][:points].first==loops[0][:points].last && loops[0][:points].size==5, 'Square logo should give 4-edge closed contour')
donut=P::Image.new(5,5,25.times.flat_map { |i| x,y=i%5,i/5; (x.between?(1,3) && y.between?(1,3) && !(x==2 && y==2)) ? [0,0,0,255] : [255,255,255,255] })
loops=P.contours(donut,2,0.1,true)
areas=loops.map { |loop| loop[:points].each_cons(2).sum { |a,b| a[0]*b[1]-b[0]*a[1] } }
assert(areas.any?(&:positive?) && areas.any?(&:negative?), 'Logo hole lost')
rejects('đơn giản') { P.contours(logo,2,-1) }
shell=TestMaterial.new('Shell'); inner=TestMaterial.new('Inner')
face=Sketchup::Face.new(inner)
group=Sketchup::Group.new(Definition.new([face],[]),shell)
model=Model.new([group]); Sketchup.active_model=model
rows=A.audit(model)
assert(rows.size==1 && rows[0][:face]=='Inner' && rows[0][:shell]=='Shell', 'Nesting audit wrong')
A.fix_nesting(model,'shell'); assert(face.material==shell, 'Shell priority not applied')
face.material=nil; A.fix_nesting(model,'faces')
assert(face.material==shell && group.material.nil? && face.back_material==shell, 'Appearance changed when removing shell')
face.material=inner; face.back_material=inner
A.swap_material(model,inner,shell,'selection')
assert(face.material==shell && face.back_material==shell, 'Swap missed front or back')
# Manifest validation, stable IDs, and independent material/model routing.
source={'url'=>'https://example.test/catalog.json'}
entry={'name'=>'Cánh tủ','format'=>'SKP','url'=>'https://example.test/door.skp','sha256'=>'a'*64,'category'=>'Cánh tủ','preview'=>'https://example.test/door.png'}
items=VGD::Library::Online.manifest(JSON.generate({'items'=>[entry]}),source)
assert(items.first[:kind]=='model' && items.first[:online] && items.first[:root].start_with?('online:'), 'Online SKP routing')
rejects('SHA-256') { VGD::Library::Online.manifest(JSON.generate({'items'=>[entry.merge('sha256'=>'bad')]}),source) }
rejects('HTTPS') { VGD::Library::Online.https('file:///C:/secrets') }
assert(VGD::Library::Storage.safe_name('CON')=='CON_', 'Reserved filename not handled')
assert(VGD::Library::COMMANDS.size==18, 'Original command groups not all exposed')
# An existing synced Drive folder attaches once; a cancelled picker changes no roots.
drive = VGD::Library::Drive
drive.singleton_class.alias_method :source_before_test, :source
def drive.source; {'name'=>'03 MTL', 'local_candidates'=>['/fixture/library']}; end
assert(drive.connect && drive.connect && C.roots.count('/fixture/library')==1, 'Synced Drive source was not deduplicated')
def drive.source; {'name'=>'03 MTL', 'local_candidates'=>[]}; end
def UI.select_directory(**); nil; end
roots_before=C.roots.dup
assert(!drive.connect && C.roots==roots_before, 'Cancelled Drive connection changed sources')
drive.singleton_class.alias_method :source, :source_before_test
class FlowEdge < Edge
  attr_accessor :faces
  def initialize(a,b); super(a,b); @faces=[]; end
end
class FlowFace < Sketchup::Face
  def initialize(vertices,material,registry)
    @material=material; @hidden=false
    edges=vertices.each_with_index.map do |vertex,i|
      other=vertices[(i+1)%vertices.size]
      key=[vertex.object_id,other.object_id].sort
      edge=registry[key] ||= FlowEdge.new(vertex,other)
      edge.faces << self
      edge
    end
    @outer_loop=Loop.new(vertices,edges)
  end
  def normal
    a,b,c=outer_loop.vertices.first(3).map(&:position)
    (b-a).cross(c-a).normalize
  end
end
vertices=[[0,0,0],[20,0,0],[20,10,0],[0,10,0],[20,10,10],[20,0,10]].map { |p| Vertex.new(Geom::Point3d.new(*p)) }
registry={}
first=FlowFace.new(vertices.values_at(0,1,2,3),shell,registry)
second=FlowFace.new(vertices.values_at(1,2,4,5),shell,registry)
model=Model.new([first,second]); Sketchup.active_model=model
A.flow(model)
uv_for=lambda do |face,vertex|
  pair=face.mapping.each_slice(2).find { |position,_uv| position.equal?(vertex.position) }
  pair && pair[1]
end
shared_first,shared_second=uv_for.call(first,vertices[1]),uv_for.call(second,vertices[1])
assert(shared_first && shared_second && near(shared_first.x,shared_second.x) && near(shared_first.y,shared_second.y), 'Flowmap shared-edge UV disconnected')
assert(near(uv_for.call(second,vertices[4]).x,3), 'Bent face was projected instead of unfolded')
puts 'PASS: Flowmap unfolds a 90-degree bend and preserves shared-edge UVs.'
module Geom
  class Transformation
    attr_accessor :m
    def initialize; @m=[[1.0,0,0,0],[0,1.0,0,0],[0,0,1.0,0],[0,0,0,1.0]]; end
    def self.translation(values); t=new; 3.times { |i| t.m[i][3]=values[i] }; t; end
    def self.scaling(*values); values*=3 if values.size==1; t=new; 3.times { |i| t.m[i][i]=values[i] }; t; end
    def *(other); t=self.class.new; 4.times { |i| 4.times { |j| t.m[i][j]=4.times.sum { |k| m[i][k]*other.m[k][j] } } }; t; end
    def point(p); Point3d.new(*3.times.map { |i| m[i][3]+3.times.sum { |j| m[i][j]*p.to_a[j] } }); end
  end
end
class TestBounds
  attr_reader :min,:max
  def initialize(min,max); @min=Geom::Point3d.new(*min); @max=Geom::Point3d.new(*max); end
  def width; max.x-min.x; end
  def height; max.y-min.y; end
  def depth; max.z-min.z; end
end
class TestDefinition < Definition
  attr_accessor :name,:bounds
  def initialize(name, bounds); super([],[]); @name,@bounds=name,bounds; @attrs={}; end
  def get_attribute(dict,key,fallback=nil); (@attrs[dict] || {}).fetch(key,fallback); end
  def attribute_dictionary(dict); @attrs[dict]; end
  def set_attribute(dict,key,value); (@attrs[dict] ||= {})[key]=value; end
end
Sketchup::ComponentDefinition = TestDefinition
class Sketchup::ComponentInstance
  attr_accessor :parent,:transformation,:tag,:name
  def attribute_dictionary(dict); (@attrs ||= {})[dict]; end
  def get_attribute(dict,key,fallback=nil); ((@attrs ||= {})[dict] || {}).fetch(key,fallback); end
  def set_attribute(dict,key,value); ((@attrs ||= {})[dict] ||= {})[key]=value; end
  def definition=(value)
    @definition.instances.delete(self) if @definition
    @definition=value
    value.instances << self unless value.instances.include?(self)
  end
  def add_observer(observer); (@observers ||= []) << observer; end
end
class Model
  attr_accessor :definitions,:entities
  def add_observer(observer); (@observers ||= []) << observer; end
end
R=VGD::Library::Replacement
old_box=TestBounds.new([1,2,3],[11,22,8])
new_box=TestBounds.new([-1,-2,-1],[1,2,0])
fitting=R.bounds_transform(old_box,new_box)
assert(fitting.point(new_box.min).to_a==old_box.min.to_a && fitting.point(new_box.max).to_a==old_box.max.to_a, 'Replacement bounds fit drift')
fresh=TestDefinition.new('Cánh mới',new_box); old=TestDefinition.new('Cánh cũ#1',old_box); sibling=TestDefinition.new('Cánh cũ#2',old_box)
fresh.set_attribute('dynamic_attributes','name','NewDoor'); fresh.set_attribute('dynamic_attributes','finish','A')
source=Sketchup::ComponentInstance.new(fresh)
target=Sketchup::ComponentInstance.new(old); other=Sketchup::ComponentInstance.new(sibling)
target.name='Door B'; target.tag='Doors'; target.set_attribute('dynamic_attributes','finish','B'); target.set_attribute('dynamic_attributes','lenx',10)
target.transformation=Geom::Transformation.translation([100,200,300]); other.transformation=Geom::Transformation.new
model=Model.new; model.definitions=[fresh,old,sibling]; model.entities=[source,target,other]; source.parent=target.parent=other.parent=model; Sketchup.active_model=model
R.apply(model,source,target,{'replace_scope'=>'family','keep_size'=>true,'redraw_dc'=>false})
assert(target.definition==fresh && other.definition==fresh, 'Family replacement skipped definition variants')
assert(target.name=='Door B' && target.tag=='Doors', 'Replacement lost instance metadata')
assert(target.get_attribute('dynamic_attributes','finish')=='B' && target.get_attribute('dynamic_attributes','lenx')==10, 'Replacement lost compatible DC values')
assert(target.transformation.point(new_box.min).to_a==[101.0,202.0,303.0], 'Replacement moved target anchor')
rejects('hai đối tượng') { R.apply(model,source,source,{}) }
# Native paint observer pauses while VGD fixes shells, avoiding a second edit.
VGD::Library::ShellSync.watch(model,[target])
assert(target.get_attribute(C::SECTION,'follow_shell'), 'Managed shell marker not persisted')
VGD::Library::ShellSync.paused(model) do
  VGD::Library::ShellSync.queue(model,target,nil,shell)
  assert(VGD::Library::ShellSync.busy?, 'Observer pause not effective')
end
assert(!VGD::Library::ShellSync.busy?, 'Observer pause leaked')
VGD::Library::ShellSync.detach(model)
assert(VGD::Library::ShellSync.instance_variable_get(:@watched).values.none? { |pair| pair[1].model.equal?(model) }, 'Closed model observers retained')
puts 'PASS: replacement family variants, bounds/anchor, tag/name/DC values, self-replacement rejection, managed shell observer pause.'
puts 'PASS: image byte order/padding, blur, seamless, five auxiliary maps, flat normals/AO, vector contours/holes, nesting audit/fix, front/back swap, online schema/checksum URLs, 18 commands.'
