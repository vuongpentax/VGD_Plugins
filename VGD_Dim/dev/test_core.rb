# Simulation. Does not certify native font defaults, associations or Undo.
def run_core_tests
  core=VGD::Dim::Core
  m=Sketchup::FakeModel.new; Sketchup.active_model=m
  dim=Sketchup::DimensionLinear.new; text=Sketchup::Text.new; text.leader=false
  label=Sketchup::Text.new; outside=Sketchup::DimensionLinear.new
  [dim,text,label,outside].each { |e| m.entities << e }
  m.selection.add([dim,text,label])
  settings={'dim'=>{'setcolor'=>true,'color'=>'#112233','arrow'=>'dot','textorient'=>'aligned','align'=>'above'},
            'label'=>{'setcolor'=>true,'color'=>'#445566','leader'=>'pushpin','arrow'=>'closed'}}
  report=core.run(%w[dim text label],settings,{})
  check(report['count']=={'dim'=>1,'text'=>1,'label'=>1},'Core counts wrong')
  check(dim.arrow_type==2 && dim.has_aligned_text? && dim.aligned_text_position==0,'Dim style wrong')
  check(label.leader_type==ALeaderModel && label.arrow_type==3,'Label style wrong')
  check(text.material.nil? && outside.layer.nil? && dim.layer=='000 DIM' && text.layer=='000 TEXT','Setcolor/scope/tags wrong')
  check(m.options['UnitsOptions']['LengthUnit']==0,'Unchecked Units written')
  check(core.scan(m,{})['dim'].first[:entities].equal?(m.entities),'Root entities container wrong')

  group=m.entities.add_group; nested=Sketchup::DimensionLinear.new; group.entities << nested
  child=group.entities.add_group; deep=Sketchup::Text.new; child.entities << deep
  shared=Sketchup::ComponentInstance.new(group.definition); m.entities << shared
  locked=m.entities.add_group; locked.locked=true; ld=Sketchup::DimensionLinear.new; locked.entities << ld
  hidden=m.entities.add_group; hidden.hidden=true; hd=Sketchup::DimensionLinear.new; hidden.entities << hd
  m.selection.clear; m.selection.add(group)
  check(core.summary(core.scan(m,{}))=={'dim'=>1,'text'=>0,'label'=>1,'nested'=>2},'Selected group traversal wrong')
  check(core.scan(m,{'nested'=>false})['label'].empty?,'Nested opt ignored')
  acc=core.scan(m,{'scope'=>'model'})
  check(acc['dim'].length==3 && !acc['dim'].any? { |row| [ld,hd].include?(row[:entity]) },'Definition dedup/hidden/locked wrong')
  check(core.scan(m,{'scope'=>'model','hidden'=>true,'locked'=>true})['dim'].size==5,'Explicit hidden/locked options ignored')
  m.active_path=[group]
  check(core.scan(m,{'scope'=>'context'})['dim'].map { |row| row[:entity] }==[nested],'Active context wrong')
  check(core.scan(m,{'scope'=>'context'})['dim'].first[:entities].equal?(group.entities),'Nested entities container wrong')
  m.active_path=nil
  m.selection.clear; m.selection.add(shared)
  check(core.scan(m,{'components'=>false})['dim'].empty?,'Component opt ignored')
  before=m.operations
  begin
    core.run(['dim'],{'dim'=>{'textorient'=>'screen','align'=>'above'}},{})
    raise 'Invalid style accepted'
  rescue ArgumentError
    check(m.operations==before,'Validation mutated')
  end
  core.run(['dim'],{'units'=>{'enabled'=>true,'unit'=>'2','precision'=>'3','show_unit'=>true}},{})
  check(m.options['UnitsOptions']['LengthUnit']==0,'Style unexpectedly changed Units')
  core.apply_units_model({'unit'=>'2','precision'=>'3','show_unit'=>true})
  check(m.options['UnitsOptions']=={'LengthUnit'=>2,'LengthFormat'=>0,'LengthPrecision'=>3,'SuppressUnitsDisplay'=>false},'Model Units wrong')

  m.selection.clear; m.selection.add(dim)
  dim.text='CUSTOM'; dim.material=:original; dim.layer='Original'; dim.hidden=true
  dim.text_position=1; dim.set_attribute('User','id',123)
  attachment=[Object.new,Geom::Point3d.new(4,5,6)]; dim.start_attached_to=attachment
  old_points=[dim.start_point,dim.end_point,dim.offset_vector.to_a]
  check(core.endpoint(dim,:start).equal?(dim.start_point),'Attached path used as creation coordinate')
  result=core.rebuild_dims({'hidden'=>true})
  replacement=m.selection.first
  check(result=={'rebuilt'=>1,'custom'=>1,'skipped'=>0,'failed'=>0},'Rebuild count wrong')
  check(!dim.valid? && replacement.is_a?(Sketchup::DimensionLinear),'Rebuild selection wrong')
  check(replacement.text=='CUSTOM' && replacement.material==:original && replacement.layer=='Original' && replacement.hidden?,'Rebuild changed style/text')
  check(old_points==[replacement.start_point,replacement.end_point,replacement.offset_vector.to_a] && replacement.start_attached_to==attachment,'Geometry/attachment changed')
  check(replacement.get_attribute('User','id')==123 && replacement.text_position==1,'Metadata lost')
  radial=Sketchup::DimensionRadial.new; m.entities << radial; m.selection.clear; m.selection.add(radial)
  check(core.rebuild_dims({})['skipped']==1 && radial.valid?,'Radial not skipped')
  broken=Sketchup::DimensionLinear.new; m.entities << broken; m.selection.clear; m.selection.add(broken)
  def broken.text; raise 'Cannot copy'; end
  check(core.rebuild_dims({})['failed']==1 && broken.valid? && m.selection.first==broken,'Failed rebuild removed original')
  vertex=Object.new
  vertex.define_singleton_method(:position) { Geom::Point3d.new(1,2,3) }
  direct=Sketchup::DimensionLinear.new; direct.start_ref=[vertex,vertex.position]
  check(core.endpoint(direct,:start).equal?(vertex),'Direct vertex reference passed as unsupported tuple')
  m=Sketchup::FakeModel.new; Sketchup.active_model=m
  number=Sketchup::DimensionLinear.new; number.text='2400 mm'; custom=Sketchup::DimensionLinear.new; custom.text='Cao 2400'
  m.entities << number; m.entities << custom; m.selection.clear
  result=core.apply_units_model({'unit'=>'3','precision'=>'1','show_unit'=>true,'reset_text'=>true})
  check(result['reset']==1 && number.text=='' && custom.text=='Cao 2400','Global Units numeric reset lost custom label')
  check(m.commits==1 && number.layer.nil? && custom.layer.nil?,'Units wrote styles/tags')
  before=m.operations
  begin
    core.apply_units_model({'unit'=>'12'}); raise 'Invalid global unit accepted'
  rescue ArgumentError
    check(m.operations==before,'Unit validation mutated')
  end
  provider=m.options['UnitsOptions']; snapshot=provider.dup
  def provider.[]=(key,value); super(key,key=='LengthPrecision' ? 7 : value); end
  begin
    core.apply_units_model({'unit'=>'2','precision'=>'3'}); raise 'Readback failure ignored'
  rescue RuntimeError
    check(m.aborts==1 && provider['LengthUnit']==snapshot['LengthUnit'],'Unit readback failure did not rollback')
  end
  puts 'PASS: scopes/definition dedup/filters, colors/orientation/leader/tags, explicit Units, simulated Dim rebuild preservation/failure'
end

def run_service_tests
  presets=VGD::Dim::Presets; auto=VGD::Dim::AutoStyle; anim=VGD::Dim::Animation
  check(!presets.save('VGD Standard',{}) && !presets.save(' ',{}),'Builtin preset overwritten')
  check(presets.save('My style',{'dim'=>{'arrow'=>'slash'}}) && presets.all['My style']['dim']['arrow']=='slash','Preset not stored')
  check(presets.delete('My style') && !presets.delete('VGD Standard'),'Delete guards wrong')
  m=Sketchup::FakeModel.new; Sketchup.active_model=m
  original=m.options['UnitsOptions'].dup
  anim.write(m,{'enabled'=>false,'transition'=>'2.5','delay'=>'0.5','loop'=>true})
  check(anim.read(m)=={'enabled'=>false,'transition'=>2.5,'delay'=>0.5,'loop'=>true},'Animation wrong')
  check(m.options['UnitsOptions']==original && m.operations==0,'Animation changed other settings/Undo')
  begin
    anim.write(m,{'enabled'=>true,'transition'=>'NaN','delay'=>1,'loop'=>false}); raise 'NaN accepted'
  rescue ArgumentError
    check(anim.read(m)['enabled']==false,'Invalid Animation mutated')
  end
  auto.save(true,{'dim'=>{'arrow'=>'dot'}})
  dim=Sketchup::DimensionLinear.new; m.entities << dim
  auto.added(dim); check(dim.layer.nil?,'Observer mutated synchronously'); UI.drain
  check(dim.arrow_type==2 && dim.layer=='000 DIM' && m.operation_flags.last[3]==true,'Deferred auto style wrong')
  skipped=Sketchup::DimensionLinear.new; m.entities << skipped
  auto.suspend { auto.added(skipped) }; UI.drain
  check(skipped.layer.nil?,'Manual operation double styled')
  pending=Sketchup::Text.new; m.entities << pending; auto.added(pending); auto.clear_queue; UI.drain
  check(pending.layer.nil?,'Undo/cancel queue still mutated')
  auto.save(false,{})
  auto.added(pending); UI.drain
  check(pending.layer.nil? && !auto.load['enabled'],'Disabled auto still ran')
  auto.bind(nil)
  check(VGD::Dim::AutoStyle::AppWatch.new.expectsStartupModelNotifications,'Startup model notifications missing')
  auto.shutdown
  puts 'PASS: local presets/builtin guards, Animation validation/isolation, Auto-Style deferred/suspended/cancelled/disabled'
end
