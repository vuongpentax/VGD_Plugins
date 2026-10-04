def run_smartdim_tests
  smart=VGD::Dim::SmartDim
  build=lambda do
    m=Sketchup::FakeModel.new; Sketchup.active_model=m
    root=m.entities.add_group
    [[0,18],[18,782],[782,800]].each do |x0,x1|
      part=root.entities.add_group
      part.entities.add_face([Geom::Point3d.new(x0.mm,0,0),Geom::Point3d.new(x1.mm,600.mm,0),Geom::Point3d.new(x1.mm,0,720.mm)])
    end
    m.selection.add(root)
    [m,root]
  end
  m,root=build.call
  result=smart.run({'face'=>'-y'},{'dim'=>{'arrow'=>'slash','textorient'=>'aligned','align'=>'above'}})
  dims=m.entities.grep(Sketchup::DimensionLinear)
  check(result['total']==5 && result['h']==[18.0,764.0,18.0] && result['v']==[720.0],'Smart Dim segment/total wrong')
  check(dims.all? { |d| d.layer=='000 DIM' && d.arrow_type==1 && d.has_aligned_text? && d.aligned_text_position==0 },'Created styles wrong')
  check(m.operations==1 && m.commits==1 && m.selection.to_a==[root],'Smart operation/selection wrong')
  check(dims.all? { |d| (d.end_point-d.start_point).cross(d.offset_vector).dot(Geom::Vector3d.new(0,-1,0))>=0 },'Unreadable orientation')

  m,root=build.call
  root.transformation=Geom::Transformation.translation([1000.mm,250.mm,0])*Geom::Transformation.scaling(2.0)
  result=smart.run({'face'=>'-y','do_v'=>false},{})
  check(result['h'].sum==1600.0 && result['v'].empty? && result['total']==4,'Scaled/nested geometry wrong')
  check(m.entities.grep(Sketchup::DimensionLinear).all? { |d| [d.start_point.y,d.end_point.y].all? { |y| (y-250.mm).abs<1e-8 } },'Translated front plane wrong')

  m,root=build.call
  root.transformation=Geom::Transformation.axes(Geom::Point3d.new(0,0,0),Geom::Vector3d.new(0,1,0),Geom::Vector3d.new(-1,0,0),Geom::Vector3d.new(0,0,1))
  result=smart.run({'face'=>'+x'},{})
  check(result['h'].sum==800.0 && result['v']==[720.0],'90-degree cabinet projection wrong')
  %w[-y +y -x +x camera axis].each do |face|
    m,root=build.call
    check(smart.run({'face'=>face},{})['total']>0,"Face #{face} failed")
  end
  m,root=build.call; root.hidden=true
  begin
    smart.run({},{}); raise 'Hidden root measured'
  rescue RuntimeError
    check(m.operations==0,'Hidden selection mutated')
  end
  m,root=build.call; root.locked=true
  begin
    smart.run({},{}); raise 'Locked root measured'
  rescue RuntimeError
    check(m.operations==0,'Locked selection mutated')
  end
  m,root=build.call
  [{'off1'=>0},{'off2'=>10},{'face'=>'bad'},{'do_h'=>false,'do_v'=>false},{'depth'=>'abc'}].each do |opts|
    begin
      smart.run(opts,{}); raise 'Invalid Smart settings accepted'
    rescue ArgumentError
      check(m.operations==0,'Invalid Smart config mutated')
    end
  end
  # Failed creation must abort the single operation (real rollback is native).
  entities=m.entities
  def entities.add_dimension_linear(*); raise 'Creation failed'; end
  begin
    smart.run({},{}); raise 'Creation failure swallowed'
  rescue RuntimeError => error
    check(error.message=='Creation failed' && m.aborts==1 && m.commits==0,'Smart creation did not abort')
  end
  puts 'PASS: Smart Dim chain/overall dimensions, all faces, translated/scaled/rotated geometry, orientation, style/tag, selection, validation/hidden/locked/abort'
end
