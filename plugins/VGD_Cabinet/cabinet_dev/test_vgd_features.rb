p=VGD_Cabinet.default_params
assert(p['shadow_gap_h']==20,'Ceiling strip must be 20')
%w[door_gap door_top_gap door_gap_outer door_gap_left door_gap_right door_gap_top door_gap_bottom door_gap_between drawer_gap_outer drawer_gap_left drawer_gap_right drawer_gap_top drawer_gap_bottom].each { |k| assert(p[k]==0,"Default #{k} must be zero") }
assert(p['drawer_gap']==25 && p['drawer_gap_between']==25 && p['mid_door_gap']==25,'Tier gaps must remain 25')
assert(p['door_stop_rail_joinery']=='Hồi giữa' && p['drawer_backing_rail_joinery']=='Hồi giữa','Rails should default to stopping between the sides')
_,parts=build(p.merge('opt_drawer'=>'Lộ','drawer_count'=>2,'front_bevel'=>true,'drawer_bevel'=>false))
fronts=parts.select { |v| v[:name].start_with?('Mặt Ngăn Kéo') }
assert(fronts.all? { |v| v[:group].entities.grep(Sketchup::Face).first.points.size==8 },'Door handle changed drawers')
_,parts=build(p.merge('opt_drawer'=>'Lộ','drawer_count'=>2,'front_bevel'=>false,'drawer_bevel'=>true))
assert(parts.select { |v| v[:name].start_with?('Mặt Ngăn Kéo') }.all? { |v| v[:group].entities.grep(Sketchup::Face).first.points.size==10 },'Drawer handle not beveled')
assert(parts.select { |v| v[:name].start_with?('Cánh') }.all? { |v| v[:group].entities.grep(Sketchup::Face).first.points.size==8 },'Drawer handle changed doors')
old=VGD_Cabinet::ModelingRules.normalize({'front_bevel'=>true,'bevel_lip'=>3},p)
assert(old['drawer_bevel'] && old['drawer_bevel_lip']==3 && old['handle_split_v1'],'Legacy shared handle migration failed')
_,items=build(p.merge('opt_drawer'=>'Lộ','drawer_count'=>2,'door_stop_rail'=>true,'drawer_backing_rail'=>false))
assert(items.any? { |v| v[:name].start_with?('Xà Chặn Cánh') } && items.none? { |v| v[:name].start_with?('Xà Che Khe Ngăn Kéo') },'Door stop rail changed drawer rail')
_,items=build(p.merge('opt_drawer'=>'Lộ','drawer_count'=>2,'door_stop_rail'=>false,'drawer_backing_rail'=>true))
assert(items.none? { |v| v[:name].start_with?('Xà Chặn Cánh') } && items.any? { |v| v[:name].start_with?('Xà Che Khe Ngăn Kéo') },'Drawer rail changed door rail')
_,middle_only=build(p.merge('door_stop_rail'=>true,'drawer_backing_rail'=>true,'opt_drawer'=>'Lộ','door_stop_rail_joinery'=>'Hồi giữa','drawer_backing_rail_joinery'=>'Hồi giữa'))
_,rebated=build(p.merge('door_stop_rail'=>true,'drawer_backing_rail'=>true,'opt_drawer'=>'Lộ','door_stop_rail_joinery'=>'Khấu hông','drawer_backing_rail_joinery'=>'Khấu hông'))
assert(middle_only.select { |v| v[:name].start_with?('Xà Chặn Cánh') }.all? { |v| close(v[:size][0],765) },'Middle-only door rail must stop between the sides')
assert(rebated.select { |v| v[:name].start_with?('Xà Chặn Cánh') }.all? { |v| close(v[:size][0],800) },'Door stop rebate must extend to the sides')
assert(rebated.any? { |v| ['Hông Trái','Hông Phải'].include?(v[:name]) && v[:group].get_attribute('VGD_CabinetPart','rail_rebates',nil) },'Door stop rebate did not cut the side panel')
_,drawer_middle=build(p.merge('opt_drawer'=>'Lộ','drawer_count'=>2,'drawer_backing_rail'=>true,'drawer_backing_rail_joinery'=>'Hồi giữa'))
_,drawer_rebated=build(p.merge('opt_drawer'=>'Lộ','drawer_count'=>2,'drawer_backing_rail'=>true,'drawer_backing_rail_joinery'=>'Khấu hông'))
assert(drawer_middle.select { |v| v[:name].start_with?('Xà Che Khe Ngăn Kéo') }.all? { |v| close(v[:size][0],765) },'Middle-only drawer rail must stop between the sides')
assert(drawer_rebated.select { |v| v[:name].start_with?('Xà Che Khe Ngăn Kéo') }.all? { |v| close(v[:size][0],800) },'Drawer rail rebate must extend to the sides')
assert(drawer_rebated.any? { |v| ['Hông Trái','Hông Phải'].include?(v[:name]) && v[:group].get_attribute('VGD_CabinetPart','rail_rebates',nil) },'Drawer rail rebate did not cut the side panel')
rejected('door_stop_rail_joinery'=>'other')

['Cánh Lọt Hồi','Cánh Lọt Lòng','Cánh Phủ toàn bộ','Cánh Phủ Hồi Trái','Cánh Phủ Hồi Phải'].each do |style|
  normalized,items=build('door_style'=>'Pano khung gỗ','opt_door'=>style,'pano_panel_count'=>2)
  panels=items.select { |v| v[:name].start_with?('Pano ') }
  left=items.select { |v| v[:name]=='Đố Pano Trái' }
  assert(panels.size==4 && left.size==2,'Missing separate pano pieces')
  dimensions=VGD_Cabinet::Modeling.pano_sizes(items.find { |v| v[:name]=='Thanh Pano Dưới' }[:size][0]+120,left.first[:size][2],normalized)
  assert(close(panels.first[:size][0],dimensions[:panel_w]) && close(panels.first[:size][2],dimensions[:panel_h]),'Groove/capture/expansion sizing incorrect')
  assert(close(panels.first[:size][1],6),'Panel thickness wrong')
  assert(left.first[:group].entities.grep(Sketchup::Face).first.points.size==16,'Stile groove missing')
  total_depth=items.map { |v| v[:high][1] }.max-items.map { |v| v[:low][1] }.min
  assert(close(total_depth,600),'Pano changed overall cabinet depth')
end
_,items=build(p.merge('door_style'=>'Pano khung gỗ','front_bevel'=>true,'pano_panel_count'=>3,'pano_stile_width'=>70,'pano_depth'=>22,'pano_panel_thickness'=>8))
assert(items.count { |v| v[:name].start_with?('Pano ') }==6,'Custom/multiple panels failed')
assert(items.find { |v| v[:name]=='Thanh Pano Trên' }[:group].entities.grep(Sketchup::Face).first.points.size==18,'Pano top rail bevel missing')
_,items=build('door_style'=>'Pano khung gỗ','w'=>1600,'module_mode'=>'Độc lập','module_widths'=>'800;800','h'=>2700,'h_bottom'=>2100)
assert(items.count { |v| v[:name].start_with?('Pano ') }==8,'Pano missing across modules and tiers')
rejected('door_style'=>'Pano khung gỗ','pano_panel_thickness'=>20)
rejected('door_style'=>'Pano khung gỗ','pano_clearance'=>8)
rejected('door_style'=>'Pano khung gỗ','pano_panel_count'=>1.5)
begin
  build('door_style'=>'Pano khung gỗ','pano_stile_width'=>300)
  raise 'Oversized pano frame accepted'
rescue VGD_Cabinet::ModelingRules::Invalid
end
puts 'PASS VGD features: zero/default tier gaps, independent handles/legacy migration, real pano grooves/capture/clearance, 5 door modes, custom thickness, modules/tiers and invalid sizes'

cabinet=Sketchup::Group.new; cabinet.name='Tủ VGD'
mod=Sketchup::Group.new; mod.name='Module 01 — 800 mm'
side=Sketchup::Group.new; side.name='Hông Trái'
mod.entities << side; cabinet.entities << mod
VGD_Cabinet::ModelData.stamp(cabinet,'cabinet-fixture')
part_id=side.get_attribute('VGD_CabinetV2','part_id')
module_id=mod.get_attribute('VGD_CabinetV2','module_id')
assert(cabinet.get_attribute('VGD_CabinetV2','schema_version')==2,'Cabinet v2 schema stamp missing')
assert(part_id && side.get_attribute('VGD_CabinetV2','cabinet_id')=='cabinet-fixture','Part identity missing')
assert(module_id && side.get_attribute('VGD_CabinetV2','module_id')==module_id,'Module identity did not propagate')
VGD_Cabinet::ModelData.stamp(cabinet,'cabinet-fixture')
assert(side.get_attribute('VGD_CabinetV2','part_id')==part_id && mod.get_attribute('VGD_CabinetV2','module_id')==module_id,'Identity changed across regeneration')
puts 'PASS VGD model data: additive schema v2, stable cabinet/module/part IDs and legacy params remain separate'
