# Logic/geometry simulation; native kernel/Undo are a separate acceptance check.
def smart_fixture
  m=Sketchup::FakeModel.new; Sketchup.active_model=m
  root=m.entities.add_group
  [[0,18],[18,782],[782,800]].each do |x0,x1|
    part=root.entities.add_group
    part.entities.add_face([Geom::Point3d.new(x0.mm,0,0),Geom::Point3d.new(x1.mm,600.mm,0),Geom::Point3d.new(x1.mm,0,720.mm)])
  end
  m.selection.add(root)
  [m,root]
end
def yaw(degrees, sx=1.0, sy=1.0)
  angle=degrees*Math::PI/180
  Geom::Transformation.axes(Geom::Point3d.new(0,0,0),Geom::Vector3d.new(Math.cos(angle)*sx,Math.sin(angle)*sx,0),Geom::Vector3d.new(-Math.sin(angle)*sy,Math.cos(angle)*sy,0),Geom::Vector3d.new(0,0,1))
end
def managed_groups(model)
  model.active_entities.grep(Sketchup::Group).select { |g| g.valid? && VGD::Dim::Managed.owned?(g) }
end
def run_smartdim_tests
  smart=VGD::Dim::SmartDim; managed=VGD::Dim::Managed
  m,root=smart_fixture
  result=smart.execute({'face'=>'-y'},{'dim'=>{'arrow'=>'slash','textorient'=>'aligned','align'=>'above'}})
  group=managed_groups(m).first; dims=group.entities.grep(Sketchup::DimensionLinear)
  check(dims.size==5 && result['h']==[18.0,764.0,18.0] && result['v']==[720.0],'Segments/total wrong')
  check(group.layer.name=='000_DIM_Y_MINUS' && dims.all? { |d| d.layer==m.layers[0] && d.arrow_type==1 && d.has_aligned_text? && d.aligned_text_position==0 },'Group tag/style wrong')
  check(m.operations==1 && m.commits==1 && m.selection.to_a==[root],'Operation/selection wrong')
  check(dims.all? { |d| (d.end_point-d.start_point).cross(d.offset_vector).dot(Geom::Vector3d.new(0,-1,0))>=0 },'Unreadable normal')
  group.name='Renamed by user'
  foreign=m.entities.add_group; foreign.name='000_DIM_Y_MINUS'
  result=smart.execute({'face'=>'-y','off1'=>120},{})
  check(result['replaced']==1 && !group.valid? && managed_groups(m).size==1 && foreign.valid?,'Repeat/metadata/foreign ownership wrong')
  replacement=managed_groups(m).first
  m.selection.clear; m.selection.add(replacement)
  VGD::Dim::Core.run(['dim'],{'dim'=>{'arrow'=>'dot'}},{})
  check(replacement.entities.grep(Sketchup::DimensionLinear).all? { |d| d.layer==m.layers[0] && d.arrow_type==2 },'Style destroyed Smart tag isolation')
  check(smart.saved['opts']['off1']==120.0,'Successful Smart options not persisted')
  m.selection.clear; m.selection.add(root)
  m.entities.grep(Sketchup::Group).find { |g| managed.owned?(g) }.entities.add_line(Geom::Point3d.new(0,0,0),Geom::Point3d.new(1,0,0))
  before=m.operations
  begin; smart.run({'face'=>'-y'},{}); raise 'Manual geometry deleted'; rescue RuntimeError; check(m.operations==before && replacement.valid?,'Manual group content destroyed'); end
  prior=smart.saved
  [{'off1'=>0},{'face'=>'bad'},{'off2'=>10},{'do_h'=>false,'do_v'=>false},{'depth'=>'NaN'}].each do |o|
    begin; smart.execute(o,{}); raise 'Invalid Smart settings accepted'; rescue ArgumentError; check(smart.saved==prior && m.operations==before,'Invalid/failed Smart persisted'); end
  end
  [0,30,45,90,123].each do |angle|
    m,root=smart_fixture; root.transformation=yaw(angle)
    r=smart.run({'face'=>'-y'}, {})
    check(r['h']==[18.0,764.0,18.0] && r['v']==[720.0],"Wrong actual cabinet size at #{angle} degrees")
    dims=managed_groups(m).first.entities.grep(Sketchup::DimensionLinear)
    normal=Geom::Vector3d.new(0,-1,0).transform(yaw(angle))
    check(dims.all? { |d| (d.end_point-d.start_point).cross(d.offset_vector).dot(normal)>0 },'Rotation normal wrong')
  end
  m,root=smart_fixture
  root.transformation=Geom::Transformation.translation([1000.mm,250.mm,0])*yaw(30,2,1)
  r=smart.run({'face'=>'-y','do_v'=>false},{})
  check(r['h'].sum==1600.0 && r['v'].empty?,'Scaled local lengths wrong')
  m,root=smart_fixture; root.transformation=yaw(45,-1,1)
  check(smart.run({'face'=>'-y'}, {})['h'].sum==800.0,'Mirrored cabinet wrong')
  %w[-y +y -x +x +z -z camera axis].each do |face|
    m,root=smart_fixture
    check(smart.run({'face'=>face},{})['total']>0,"Face #{face} failed")
  end
  bad_axes=[Geom::Transformation.axes(Geom::Point3d.new(0,0,0),Geom::Vector3d.new(1,0,0),Geom::Vector3d.new(0,0,1),Geom::Vector3d.new(0,-1,0)),
            Geom::Transformation.axes(Geom::Point3d.new(0,0,0),Geom::Vector3d.new(1,0,0),Geom::Vector3d.new(0.2,1,0),Geom::Vector3d.new(0,0,1)), Geom::Transformation.scaling(0)]
  bad_axes.each do |t|
    m,root=smart_fixture; root.transformation=t
    begin; smart.run({},{}); raise 'Unsupported axes measured'; rescue RuntimeError; check(m.operations==0,'Unsupported transform mutated'); end
  end
  m,root=smart_fixture
  root.entities.grep(Sketchup::Group).last.transformation=yaw(15)
  begin; smart.run({},{}); raise 'Oblique child measured'; rescue RuntimeError; check(m.operations==0,'Oblique child mutated'); end
  m,root=smart_fixture
  section=Sketchup::SectionPlane.new([0,1,0,-300.mm]); m.entities << section; m.entities.active_section_plane=section
  r=smart.run({'face'=>'+z'}, {})
  check(r['section'] && r['group'].start_with?('000_DIM_SECTION_Y') && r['h'].sum==800.0,'Section namespace/face wrong')
  dims=managed_groups(m).first.entities.grep(Sketchup::DimensionLinear)
  check(dims.all? { |d| (d.start_point.y-300.mm).abs<1e-8 && (d.end_point.y-300.mm).abs<1e-8 },'Section Dim plane wrong')
  section.plane=[0,1,0,-250.mm]
  check(smart.run({}, {})['replaced']==1 && managed_groups(m).size==1,'Moving same section created duplicates')
  m.rendering_options['DisplaySectionCuts']=false
  check(!smart.run({}, {})['section'],'Disabled cut still measured')
  m.rendering_options['DisplaySectionCuts']=true; root.transformation=yaw(30)
  begin; smart.run({},{}); raise 'Oblique section measured'; rescue RuntimeError; check(managed_groups(m).size==2,'Oblique section changed groups'); end
  section.plane=[1,1,0,0]
  p=smart.section_plane_of(m.entities,Geom::Transformation.axes(Geom::Point3d.new(0,0,0),Geom::Vector3d.new(2,0,0),Geom::Vector3d.new(0,1,0),Geom::Vector3d.new(0,0,1)))
  check((p[:normal].x/p[:normal].y-0.5).abs<1e-8,'Nonuniform plane normal wrong')
  m,root=smart_fixture
  a=Sketchup::Page.new('A'); b=Sketchup::Page.new('B'); m.pages.concat([a,b]); m.pages.selected_page=a
  camera=a.camera_token
  r=smart.run({},{}); ga=managed_groups(m).first
  check(r['scenes']==2 && a.overrides[ga.layer] && !b.overrides[ga.layer] && a.camera_token.equal?(camera),'Scene visibility/camera wrong')
  m.pages.selected_page=b; smart.run({},{}); gb=(managed_groups(m)-[ga]).first
  check(gb && !a.overrides[gb.layer] && b.overrides[gb.layer] && managed_groups(m).size==2,'Scene set collision')
  m.pages.selected_page=a; check(smart.run({}, {})['replaced']==1 && managed_groups(m).size==2,'Repeat scene duplicated set')
  b.use_hidden_layers=false; m.pages.selected_page=b; before=m.operations
  begin; smart.run({},{}); raise 'Scene without Tags accepted'; rescue RuntimeError; check(m.operations==before,'Scene preflight mutated'); end
  # The second scene fails after the first has been written; restore page overrides.
  b.use_hidden_layers=true; m.pages.selected_page=a
  a_snapshot=a.overrides.dup; b_snapshot=b.overrides.dup
  original=b.method(:set_visibility); fail_once=true
  b.define_singleton_method(:set_visibility) do |tag,visible|
    if fail_once then fail_once=false; raise 'Page write failed' end
    original.call(tag,visible)
  end
  old=managed_groups(m).dup
  begin; smart.run({},{}); raise 'Failed Page write accepted'; rescue RuntimeError => e; check(e.message=='Page write failed' && managed_groups(m)==old && a.overrides==a_snapshot && b.overrides==b_snapshot,'Scene failure destroyed old set/visibility'); end
  m,root=smart_fixture; smart.run({},{}); old=managed_groups(m).first
  original=m.entities.method(:add_group)
  m.entities.define_singleton_method(:add_group) do
    group=original.call
    group.entities.define_singleton_method(:add_dimension_linear) { |*| raise 'Creation failed' }
    group
  end
  begin; smart.execute({},{}); raise 'Failure swallowed'; rescue RuntimeError => e; check(e.message=='Creation failed' && old.valid? && m.aborts==1 && managed_groups(m)==[old],'Replacement failure destroyed old set'); end
  puts 'PASS: Smart local-axis yaw/mirror/scale, tilt/shear guards, sections/normals, owned replacement/failure, Untagged inner dims, Scene tags and successful persistence'
end
