# Simulation: validates selected scope and setters, not native SketchUp font rendering.
def check(value, message)
  raise message unless value
end
def run_engine_tests
  engine = VGD::Dim::Engine
  model = Sketchup::FakeModel.new
  Sketchup.active_model = model
  dim = Sketchup::DimensionLinear.new
  dim.text = 'Custom dimension'; dim.hidden = true
  dim.has_aligned_text = true; dim.aligned_text_position = 0
  text = Sketchup::Text.new; text.leader = false; text.arrow_type = 4
  label = Sketchup::Text.new; label.leader = true
  outside = Sketchup::DimensionRadial.new
  outside.layer = 'Outside'; outside.material = :untouched
  outside_text = Sketchup::Text.new; outside_text.material = :untouched
  group = model.entities.add_group
  nested = Sketchup::DimensionLinear.new; group.entities << nested
  edge = Sketchup::Edge.new([])
  [dim,text,label,outside,outside_text,edge].each { |entity| model.entities << entity }
  # Groups/geometry may be selected but their content must remain unchanged.
  [dim,text,label,group,edge].each { |entity| model.selection.add(entity) }
  selection_before = model.selection.to_a
  units_before = model.options['UnitsOptions'].dup
  geometry_before = [dim.text,dim.start_point,dim.end_point,dim.offset_vector.to_a,
                     dim.has_aligned_text?,dim.aligned_text_position,dim.hidden?,
                     text.text,text.point,text.vector,label.text,label.point,label.vector]
  config = {'dim_color'=>'#112233','text_color'=>'#AABBCC',
            'dim_endpoint'=>'slash','label_endpoint'=>'closed',
            'unit'=>'ft','precision'=>4,'show_unit'=>false}
  result = engine.apply(model,config)
  check(result == {dimensions:1,texts:2}, 'Selected counts wrong')
  check(model.operations == 1 && model.commits == 1 && model.aborts == 0, 'One operation required')
  check(dim.layer == '000 DIM' && text.layer == '000 TEXT' && label.layer == '000 TEXT', 'Tags wrong')
  check(dim.arrow_type == 1 && label.arrow_type == 3 && text.arrow_type == 4, 'Endpoint affected wrong kind')
  check(dim.material.color.blue == 51 && text.material.equal?(label.material) && text.material.color.blue == 204, 'Color wrong')
  check(outside.layer == 'Outside' && outside.material == :untouched && outside.arrow_type == 4 && outside_text.material == :untouched, 'Outside selection changed')
  check(nested.material.nil? && nested.layer.nil?, 'Selected group contents changed')
  check(model.options['UnitsOptions'] == units_before, 'Global Units changed outside selection')
  check(model.selection.to_a == selection_before, 'Selection changed')
  check(geometry_before == [dim.text,dim.start_point,dim.end_point,dim.offset_vector.to_a,
                            dim.has_aligned_text?,dim.aligned_text_position,dim.hidden?,
                            text.text,text.point,text.vector,label.text,label.point,label.vector], 'Geometry/content/orientation changed')
  dim_mat = dim.material
  engine.apply(model,config)
  check(model.materials.items.length == 2 && dim.material.equal?(dim_mat), 'Repeat Apply duplicates materials')
  old_material_color = [dim_mat.color.red,dim_mat.color.green,dim_mat.color.blue]
  outside.material = dim_mat
  engine.apply(model,config.merge('dim_color'=>'#010203','dim_endpoint'=>'keep'))
  check([outside.material.color.red,outside.material.color.green,outside.material.color.blue] == old_material_color, 'Shared material recolored unselected entity')
  check(dim.arrow_type == 1, 'Keep endpoint reset existing style')
  %w[none slash dot closed open].each_with_index do |style,value|
    engine.apply(model,config.merge('dim_endpoint'=>style,'label_endpoint'=>style))
    check(dim.arrow_type == value && label.arrow_type == value, "Wrong endpoint #{style}")
  end
  puts 'PASS: selection only, no group traversal, endpoints, tags, material isolation, preserved geometry/selection/global Units'

  empty = Sketchup::FakeModel.new
  empty.selection.add(empty.entities.add_group)
  begin
    engine.apply(empty,{})
    raise 'Group-only selection applied'
  rescue ArgumentError
    check(empty.operations == 0 && empty.materials.items.empty? && empty.layers.size == 1, 'Empty eligibility changed model')
  end
  invalids = [{'dim_color'=>'#bad'}, {'text_color'=>nil},
              {'dim_endpoint'=>'wrong'}, {'label_endpoint'=>3}]
  invalids.each do |bad|
    m = Sketchup::FakeModel.new
    begin
      engine.apply(m,bad)
      raise 'Accepted invalid configuration'
    rescue ArgumentError
      check(m.operations == 0, 'Invalid configuration mutated model')
    end
  end
  m = Sketchup::FakeModel.new
  parent = m.entities.add_group
  m.entities << Sketchup::ComponentInstance.new(parent.definition)
  selected = Sketchup::Text.new; parent.entities << selected
  m.active_path = [parent]; m.selection.add(selected)
  begin
    engine.apply(m,{})
    raise 'Shared context changed unselected copies'
  rescue ArgumentError
    check(m.operations == 0 && selected.material.nil?, 'Shared context mutated before guard')
  end
  m.entities.last.erase!
  parent.locked = true
  begin
    engine.apply(m,{})
    raise 'Locked context changed'
  rescue ArgumentError
    check(m.operations == 0 && parent.locked?, 'Locked context mutated')
  end
  m = Sketchup::FakeModel.new
  broken = Sketchup::Text.new
  def broken.layer=(_); raise 'Setter failed'; end
  m.entities << broken; m.selection.add(broken)
  begin
    engine.apply(m,{})
    raise 'Failure swallowed'
  rescue RuntimeError => error
    check(error.message == 'Setter failed' && m.aborts == 1 && m.commits == 0, 'Failed setter did not abort')
  end
  puts 'PASS: empty selection no mutation, invalid data, shared/locked context guard and transaction abort'
end
