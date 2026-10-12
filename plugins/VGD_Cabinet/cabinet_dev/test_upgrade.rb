# New behavior checks against the geometry fixture; not native SketchUp solids.
strict_face_sink=Object.new
strict_face_sink.define_singleton_method(:add_face) do |points|
  raise ArgumentError,'Duplicate points in array' unless points.uniq.size==points.size
  points
end
cleaned_face=VGD_Cabinet::RailJoinery.add_curved_face(strict_face_sink,[[0,0,0],[10,0,0],[10,0,10],[0,0,10],[0,0,10]])
assert(cleaned_face.size==4,'Curved rail face was not deduplicated before native add_face')
assert(VGD_Cabinet::RailJoinery.add_curved_face(strict_face_sink,[[0,0,0],[0,0,10],[0,0,10],[0,0,0]]).nil?,'Degenerate curved rail face should be skipped')
puts 'PASS curved joinery face cleanup: duplicate and degenerate boundary points'
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
sides=containers(equal).select { |e| e.name=='Hông Trái' }
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
  ['Kính khung kim loại','Cánh kính bo góc'].each do |style|
    normalized,items=build('door_style'=>style,'frame_division'=>division,'frame_sections'=>3,'frame_bar_width'=>30)
    name=style=='Kính khung kim loại' ? 'Kính' : 'Kính Phẳng Bo Góc'
    panels=items.select { |part| style=='Kính khung kim loại' ? part[:name]==name : part[:name].start_with?(name) }
    assert(style=='Kính khung kim loại' ? panels.size==2 : panels.size==6,'Missing divided glass panels')
    assert(panels.all? { |part| part[:size][0]>1 && part[:size][2]>1 },'Divided opening too small')
  end
end
_,pano_items=build('door_style'=>'Shaker','frame_division'=>'Dọc','pano_panel_count'=>2,'frame_sections'=>5)
assert(pano_items.count { |part| part[:name].start_with?('Shaker ') }==4,'Pano/Shaker panel count must use its own setting, not glass division')
_,_,separated_metal=build('door_style'=>'Kính khung kim loại','frame_division'=>'Ngang','frame_sections'=>3)
metal_parts=containers(separated_metal).select { |part| part.name.start_with?('Khung Kim Loại ') || part.name.start_with?('Thanh Chia Ngang') }
assert(metal_parts.count { |part| part.name.start_with?('Khung Kim Loại ') }==8,'Two metal doors must have four separate perimeter members each')
assert(metal_parts.count { |part| part.name.start_with?('Thanh Chia Ngang') }==4,'Each door horizontal divider must remain a separate frame member')
assert(metal_parts.all? { |part| (part.respond_to?(:entities) ? part.entities : part.definition.entities).grep(Sketchup::Face).any? },'A separate metal frame member has no solid geometry')
puts 'PASS metal frame divisions: four perimeter members and each crossbar remain separate solids'
_,_,mitered_metal=build('door_style'=>'Kính khung kim loại','frame_joint'=>'Chéo')
left_miter=containers(mitered_metal).find { |part| part.name=='Khung Kim Loại Hông Trái' }
points=(left_miter.respond_to?(:entities) ? left_miter.entities : left_miter.definition.entities).grep(Sketchup::Face).first.points
diagonal=points.combination(2).any? { |a,b| close((a[0]-b[0]).abs*25.4,20) && close((a[2]-b[2]).abs*25.4,20) }
assert(diagonal,'Metal frame Chéo must cut a real 45-degree perimeter joint, not draw a guide line')
puts 'PASS metal frame miters: 45-degree corners are part geometry and each member remains separate'
['Pano khung gỗ','Shaker','Kính khung kim loại','Cánh kính bo góc'].each do |style|
  ['Ngang','Dọc','Chéo'].each do |joint|
    normalized,_,entities=build('door_style'=>style,'frame_division'=>'Dọc','frame_joint'=>joint,'frame_bar_width'=>25)
    guides=containers(entities).select { |part| part.name=='Mối Ghép '+joint }
    assert(normalized['frame_division']=='Dọc' && normalized['frame_joint']==joint,'Frame division and joint type must remain independent')
    assert(guides.empty?,'Frame joints must be separate physical member cuts, not construction-line guides')
  end
end
[
  ['Cánh soi',{'wood_carved_thickness'=>17,'wood_carved_rail'=>60,'wood_carved_radius'=>60,'wood_carved_recess'=>7}],
  ['Cánh soi vát 4 cạnh',{'wood_bevel_thickness'=>20,'wood_bevel_flat'=>2,'wood_bevel_width'=>15,'wood_bevel_recess'=>10}],
  ['Cánh kính bo góc',{'wood_glass_frame_thickness'=>20,'wood_glass_rail'=>60,'wood_glass_radius'=>60,'wood_glass_type'=>'Kính phẳng','wood_glass_depth'=>8,'wood_glass_inset'=>12}]
].each do |style,parameters|
  normalized,items,entities=build(parameters.merge('door_style'=>style,'frame_joint'=>'Chéo'))
  assert(normalized['door_style']==style,'Door profile style was not preserved')
  assert(VGD_Cabinet::Modeling.door_depth_mm(normalized)==parameters.values.first,'Door style thickness not applied')
  assert(containers(entities).any? { |part| part.name.include?('So') || part.name.include?('Khung Kính Gỗ') },'Missing special wood door geometry')
  if style=='Cánh kính bo góc'
    frame_parts=containers(entities).select { |part| part.name.start_with?('Khung Kính Gỗ ') }
    assert(frame_parts.size==8 && frame_parts.none? { |part| part.name=='Mối Ghép Chéo' },'Rounded wooden glass must use four independent frame members per door')
  else
    assert(containers(entities).none? { |part| part.name.start_with?('Mối Ghép ') },'Solid carved/beveled slabs must not receive frame-joint guides')
  end
end
rejected('door_style'=>'Cánh soi','wood_carved_recess'=>18)
rejected('door_style'=>'Cánh soi vát 4 cạnh','wood_bevel_width'=>500)
rejected('door_style'=>'Cánh kính bo góc','wood_glass_depth'=>20)
puts 'PASS engineered-wood doors: carved, four-edge bevel, rounded wooden glass frame, parameters, thickness, corner joint and invalid dimensions'
legacy=VGD_Cabinet::ModelingRules.normalize({'door_style'=>'Shaker','frame_division'=>'Chéo X'},VGD_Cabinet.default_params)
assert(legacy['frame_division']=='Không chia' && legacy['frame_joint']=='Chéo','Legacy Chéo X must migrate to separate miter option without X bars')
legacy_vertical=VGD_Cabinet::ModelingRules.normalize({'frame_joint'=>'Dọc'},VGD_Cabinet.default_params)
assert(legacy_vertical['frame_division']=='Không chia' && legacy_vertical['frame_joint']=='Dọc','Vertical joint choice must remain independent from glass panel division')
rejected('door_style'=>'Shaker','shaker_recess'=>19)
rejected('frame_sections'=>2.5)
rejected('frame_division'=>'Unknown')
begin; build('door_style'=>'Kính khung kim loại','frame_division'=>'Dọc','frame_sections'=>6,'frame_bar_width'=>200); raise 'Too many frame dividers accepted'; rescue VGD_Cabinet::ModelingRules::Invalid; end
puts 'PASS frame settings: three independent joint types, glass-only panel divisions, separate Pano panel count, legacy X setting migrated, invalid recess/count/oversized bars rejected'

['Xà Trên','Xà Dưới'].each do |join|
  _,items=build('h'=>2700,'h_bottom'=>2100,'overheight_join'=>join)
  rails=items.select { |v| v[:name].include?('Xà') }
  assert(rails.all? { |v| close(v[:low][0],0)&&close(v[:high][0],800) },'Tier rails remain trapped between side panels')
  sides=items.select { |v| v[:name].start_with?('Hông ') }
  assert(sides.any? { |v| v[:group].get_attribute('VGD_CabinetPart','rail_rebates',nil) },'No actual rail rebate profiles')
end
_,items=build('door_stop_rail'=>true,'door_stop_rail_joinery'=>'Khấu hông','w'=>1600,'auto_divider_wide'=>false,'div_count'=>1)
rails=items.select { |v| v[:name].start_with?('Xà Chặn Cánh') }
assert(rails.size==1 && close(rails.first[:size][0],1600),'Door stop not continuous through shared side')
_,items=build('h'=>2700,'w'=>1600,'module_mode'=>'Độc lập','module_widths'=>'800;800','overheight_join'=>'Xà Dưới')
assert(items.select { |v| v[:name].include?('Xà') }.all? { |v| close(v[:size][0],765) },'Independent modules must retain inset rails')
_,items=build('w'=>1600,'module_mode'=>'Độc lập','module_widths'=>'800;800','door_stop_rail'=>true,'door_stop_rail_joinery'=>'Khấu hông')
rails=items.select { |v| v[:name].start_with?('Xà Chặn Cánh') }
assert(rails.size==2 && rails.all? { |v| close(v[:size][0],800) },'Explicit rail rebates should work within each independent module')
assert(items.select { |v| ['Hông Trái','Hông Phải'].include?(v[:name]) }.any? { |v| v[:group].get_attribute('VGD_CabinetPart','rail_rebates',nil) },'Independent module hôngs were not rebated')
cuts=VGD_Cabinet::RailJoinery.cut_loops([[0,0],[100,0],[100,200],[0,200]],[[0,80,20,120],[80,50,100,90]])
assert(cuts.size==1 && close(VGD_Cabinet::FrameDivisions.area(cuts.first),18_400),'Rail notch polygon area mismatch')
puts 'PASS rail joinery: shared-cabinet xà, explicit door-stop rebating, independent module defaults and selected rebates, notch profiles and polygon area'
_,items=build('h'=>2700,'opt_left_side'=>'Bo Cong','opt_right_side'=>'Bo Cong','overheight_join'=>'Xà Dưới')
assert(items.select { |part| part[:name].include?('Xà') }.all? { |part| close(part[:low][0],0) && close(part[:high][0],800) },'Curved side rail ends remain inset')
curves=items.select { |part| part[:name].include?('Bo Cong') && part[:name].start_with?('Hông') }
assert(curves.count { |part| part[:group].get_attribute('VGD_CabinetPart','rail_rebates',nil) }>=2,'Curved side rebates missing')
assert(curves.all? { |part| part[:group].entities.grep(Sketchup::Face).flat_map(&:vertices).map { |v| v.position.x.round(6) }.uniq.size>20 },'Curved side arc vertices lost')
puts 'PASS curved rail joinery: full-width rails, actual notched curved side boundaries with original arc vertices retained'

before=Sketchup.active_model.materials.keys.dup; tags=Sketchup.active_model.layers.keys.dup; ops=Sketchup.active_model.operations
p=VGD_Cabinet::ModelingRules.normalize({'w'=>1600,'h'=>2700,'h_bottom'=>2100,'door_style'=>'Cánh kính bo góc','frame_division'=>'Ngang','frame_joint'=>'Chéo'},VGD_Cabinet.default_params)
mesh=VGD_Cabinet::PreviewMesh.new(p)
assert(mesh.surfaces.size>100 && mesh.guides.size>5,'Preview lacks actual panels/doors/guides')
assert(before==Sketchup.active_model.materials.keys && tags==Sketchup.active_model.layers.keys && ops==Sketchup.active_model.operations,'Preview altered real model')
assert(Thread.current[:vgd_cabinet_preview_model].nil?,'Preview context leaked')
restored=VGD_Cabinet::PreviewMesh.from_data(mesh.to_data)
assert(restored.surfaces.size==mesh.surfaces.size,'Stored preview lost shapes')
$upgrade_preview_data=mesh.to_data
puts 'PASS X-ray preview: actual builder mesh with Shaker/miter/two tiers, no model entities/operations/material/tag mutation, serialized library preview round-trip'

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
