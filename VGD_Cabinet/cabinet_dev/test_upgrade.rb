# New behavior checks against the geometry fixture; not native SketchUp solids.
def containers(entities,result=[])
  entities.each do |e|
    next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    next unless e.valid?
    result << e; containers(e.definition.entities,result)
  end
  result
end
_,parts,entities=build('w'=>1600,'auto_door_count'=>false,'door_count'=>4,'auto_divider_wide'=>false)
doors=containers(entities).select { |e| e.definition.name.start_with?('Cánh') && e.get_attribute('dynamic_attributes','onclick',nil) }
left=doors.select { |e| e.definition.name.start_with?('Cánh Trái') }; right=doors.select { |e| e.definition.name.start_with?('Cánh Phải') }
assert(left.size==2 && right.size==2,'Expected two left and two right hinged doors')
assert(left.map(&:definition).uniq.size==1 && right.map(&:definition).uniq.size==1,'Equal doors not sharing definitions')
assert(left.first.definition!=right.first.definition,'Left and right hinges were conflated')
left.first.definition.entities.add_cline(Geom::Point3d.new(1,2,3),Geom::Point3d.new(4,5,6))
assert(left.last.definition.entities.any? { |e| e.is_a?(Sketchup::ConstructionLine) },'Manual edit did not propagate')
_,_,different=build('w'=>1700,'module_mode'=>'Độc lập','module_widths'=>'800;900','auto_door_count'=>false,'door_count'=>2)
left=containers(different).select { |e| e.definition.name.start_with?('Cánh Trái') && e.get_attribute('dynamic_attributes','onclick',nil) }
assert(left.map(&:definition).uniq.size==2,'Different door sizes linked')
_,_,equal=build('w'=>1600,'module_mode'=>'Độc lập','module_widths'=>'800;800')
sides=containers(equal).select { |e| e.name=='Hồi Trái' }
assert(sides.size==2 && sides.map(&:definition).uniq.size==1,'Equal carcass parts not shared across modules')
puts 'PASS shared components: 2 left + 2 right doors, independent hinges/animation, manual edit propagation, differing sizes separated, equal boards shared across modules'

%w[Lộ Âm].each do |mode|
  _,values=build('opt_door'=>'Không Cánh','opt_drawer'=>mode,'is_full_drawer'=>true,'drawer_columns'=>2,'drawer_count'=>2,'auto_divider_wide'=>false)
  faces=values.select { |e| e[:name]=='Mặt Ngăn Kéo 1' }.sort_by { |e| e[:low][0] }
  divider=values.find { |e| e[:name]=='Hồi Giữa Két' }
  assert(faces.size==2,'Missing two drawer fronts')
  assert(close(faces[0][:high][0],faces[1][:low][0]),'Central drawer divider remains exposed')
  assert(faces[0][:high][0]>divider[:low][0] && faces[1][:low][0]<divider[:high][0],'Faces did not cover half of the divider')
  assert(close(faces.first[:low][0],0) && close(faces.last[:high][0],800),'Exposed fronts must cover outer sides') if mode=='Lộ'
end
_,values=build('opt_door'=>'Không Cánh','opt_drawer'=>'Lộ','is_full_drawer'=>true,'drawer_columns'=>2,'drawer_gap_advanced'=>true,'drawer_gap_left'=>2,'drawer_gap_right'=>3,'auto_divider_wide'=>false)
faces=values.select { |e| e[:name]=='Mặt Ngăn Kéo 1' }.sort_by { |e| e[:low][0] }
assert(close(faces[1][:low][0]-faces[0][:high][0],5),'Explicit front gaps ignored')
puts 'PASS drawer front overlays: concealed/exposed two columns cover shared divider, exposed outer side overlay, explicit gaps retained; box and ray geometry unchanged'

%w[Ngang Dọc].each do |division|
  ['Pano khung gỗ','Shaker','Kính khung kim loại'].each do |style|
    normalized,items=build('door_style'=>style,'frame_division'=>division,'frame_sections'=>3,'frame_bar_width'=>30)
    name=style=='Kính khung kim loại' ? 'Kính' : style=='Shaker' ? 'Shaker ' : 'Pano '
    panels=items.select { |part| style=='Kính khung kim loại' ? part[:name]==name : part[:name].start_with?(name) }
    assert(style=='Kính khung kim loại' ? panels.size==2 : panels.size==6,'Missing divided panels')
    assert(panels.all? { |part| part[:size][0]>1 && part[:size][2]>1 },'Divided opening too small')
  end
end
['Pano khung gỗ','Shaker','Kính khung kim loại'].each do |style|
  _,items=build('door_style'=>style,'frame_division'=>'Chéo X','frame_bar_width'=>25)
  assert(items.any? { |part| part[:name].start_with?('Thanh Chéo') } || style=='Kính khung kim loại','Missing X bars')
end
layout=VGD_Cabinet::FrameDivisions.layout(300.mm,700.mm,25.mm,'Chéo X',2)
area=layout.values.flatten(1).sum { |poly| VGD_Cabinet::FrameDivisions.area(poly).abs }
assert(close(area,300.mm*700.mm),'X bars/panels overlap or leave holes')
assert(layout[:panels].size==4,'X glass should have four separate panes')
rejected('door_style'=>'Shaker','shaker_recess'=>19)
rejected('frame_sections'=>2.5)
rejected('frame_division'=>'Unknown')
rejected('door_style'=>'Shaker','frame_division'=>'Dọc','frame_bar_width'=>10)
begin; build('door_style'=>'Shaker','frame_division'=>'Dọc','frame_sections'=>6,'frame_bar_width'=>200); raise 'Too many frame dividers accepted'; rescue VGD_Cabinet::ModelingRules::Invalid; end
puts 'PASS framed doors: wood/glass/Shaker horizontal + vertical 3-panel layouts, physical non-overlapping X bars and 4 glass panes, invalid recess/count/oversized bars rejected'

['Xà Trên','Xà Dưới'].each do |join|
  _,items=build('h'=>2700,'h_bottom'=>2100,'overheight_join'=>join)
  rails=items.select { |v| v[:name].include?('Xà') }
  assert(rails.all? { |v| close(v[:low][0],0)&&close(v[:high][0],800) },'Tier rails remain trapped between side panels')
  sides=items.select { |v| v[:name].start_with?('Hồi ') }
  assert(sides.any? { |v| v[:group].get_attribute('VGD_CabinetPart','rail_rebates',nil) },'No actual rail rebate profiles')
end
_,items=build('door_stop_rail'=>true,'w'=>1600,'auto_divider_wide'=>false,'div_count'=>1)
rails=items.select { |v| v[:name].start_with?('Xà Chặn Cánh') }
assert(rails.size==1 && close(rails.first[:size][0],1600),'Door stop not continuous through shared side')
_,items=build('h'=>2700,'w'=>1600,'module_mode'=>'Độc lập','module_widths'=>'800;800','overheight_join'=>'Xà Dưới')
assert(items.select { |v| v[:name].include?('Xà') }.all? { |v| close(v[:size][0],765) },'Independent modules must retain inset rails')
cuts=VGD_Cabinet::RailJoinery.cut_loops([[0,0],[100,0],[100,200],[0,200]],[[0,80,20,120],[80,50,100,90]])
assert(cuts.size==1 && close(VGD_Cabinet::FrameDivisions.area(cuts.first),18_400),'Rail notch polygon area mismatch')
puts 'PASS rail joinery: upper/lower tier rails cross outer/shared sides, real notched profiles, continuous door stop, independent modules exempt, notch area checked'
_,items=build('h'=>2700,'opt_left_side'=>'Bo Cong','opt_right_side'=>'Bo Cong','overheight_join'=>'Xà Dưới')
assert(items.select { |part| part[:name].include?('Xà') }.all? { |part| close(part[:low][0],0) && close(part[:high][0],800) },'Curved side rail ends remain inset')
curves=items.select { |part| part[:name].include?('Bo Cong') && part[:name].start_with?('Hồi') }
assert(curves.count { |part| part[:group].get_attribute('VGD_CabinetPart','rail_rebates',nil) }>=2,'Curved side rebates missing')
assert(curves.all? { |part| part[:group].entities.grep(Sketchup::Face).flat_map(&:vertices).map { |v| v.position.x.round(6) }.uniq.size>20 },'Curved side arc vertices lost')
puts 'PASS curved rail joinery: full-width rails, actual notched curved side boundaries with original arc vertices retained'

before=Sketchup.active_model.materials.keys.dup; tags=Sketchup.active_model.layers.keys.dup; ops=Sketchup.active_model.operations
p=VGD_Cabinet::ModelingRules.normalize({'w'=>1600,'h'=>2700,'h_bottom'=>2100,'door_style'=>'Shaker','frame_division'=>'Chéo X'},VGD_Cabinet.default_params)
mesh=VGD_Cabinet::PreviewMesh.new(p)
assert(mesh.surfaces.size>100 && mesh.guides.size>5,'Preview lacks actual panels/doors/guides')
assert(before==Sketchup.active_model.materials.keys && tags==Sketchup.active_model.layers.keys && ops==Sketchup.active_model.operations,'Preview altered real model')
assert(Thread.current[:vgd_cabinet_preview_model].nil?,'Preview context leaked')
restored=VGD_Cabinet::PreviewMesh.from_data(mesh.to_data)
assert(restored.surfaces.size==mesh.surfaces.size,'Stored preview lost shapes')
$upgrade_preview_data=mesh.to_data
puts 'PASS X-ray preview: actual builder mesh with Shaker/X/two tiers, no model entities/operations/material/tag mutation, serialized library preview round-trip'

# Validate the production draw path against the documented View contract.
# Tessellation itself remains a fixture; native rendering is not claimed.
GL_TRIANGLES=4 unless defined?(GL_TRIANGLES)
GL_LINE_LOOP=2 unless defined?(GL_LINE_LOOP)
GL_LINES=1 unless defined?(GL_LINES)
module Geom
  def self.tesselate(points)
    area=points.each_index.sum { |i| a=points[i]; b=points[(i+1)%points.size]; a.x*b.y-b.x*a.y }
    raise 'Degenerate/CW screen polygon reached tessellation' unless area>0.000001
    (1...points.size-1).flat_map { |i| [points[0],points[i],points[i+1]] }
  end
end
class PreviewViewFixture
  attr_accessor :drawing_color,:line_width,:line_stipple
  attr_reader :camera,:calls
  def initialize(eye,target)
    direction=(target-eye).normalize; @camera=Struct.new(:eye,:direction).new(eye,direction)
    @u=direction.cross(Geom::Vector3d.new(0,0,1)).normalize; @v=@u.cross(direction).normalize; @target=target; @calls=[]
  end
  def screen_coords(point); delta=point-@target; Geom::Point3d.new(320+4.5*delta.dot(@u),330-4.5*delta.dot(@v),0); end
  def draw2d(mode,points); @calls << [mode,points.map(&:to_a),drawing_color.rgb,line_stipple]; end
end
view=PreviewViewFixture.new(Geom::Point3d.new(180,-180,130),Geom::Point3d.new(31,12,53))
mesh.draw(view,Geom::Transformation.new)
assert(view.calls.any? { |mode,_,color,_| mode==GL_TRIANGLES && color==[180,137,99,52] },'VGD translucent front fill missing')
assert(view.calls.any? { |mode,_,_,stipple| mode==GL_LINES && stipple=='-' },'Hinge guides missing')
assert(view.line_stipple=='' && view.line_width==1,'View style leaked after preview')
$upgrade_draw_data=view.calls
front_view=PreviewViewFixture.new(Geom::Point3d.new(31,-180,53),Geom::Point3d.new(31,12,53))
mesh.draw(front_view,Geom::Transformation.new)
puts 'PASS preview draw contract: orbit/front projections, edge-on faces skipped, CCW triangles, VGD alpha, hinge guides and view-style cleanup; native tessellation not claimed'
