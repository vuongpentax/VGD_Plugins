# Preview must leave shared definitions and saved scenes intact, including errors.
s = VGD::Scenes; preview = s::SectionPreview
previous_model = Sketchup.active_model
m = Sketchup::Model.new; Sketchup.active_model = m
group = product(m); sibling = Sketchup::ComponentInstance.new(group.definition,'Bản sao')
sibling.layer = m.layers[0]; m.entities << sibling
other = product(m,20,20,20,'Ẩn sẵn'); other.hidden = true
original_definition = group.definition
original_cut = m.entities.add_section_plane([Geom::Point3d.new,Geom::Vector3d.new(0,0,1)])
m.entities.active_section_plane = original_cut
saved_page = m.pages.add('Saved',PAGE_USE_CAMERA); m.pages.selected_page = saved_page
saved_camera = s.camera_copy(saved_page.camera)
m.selection.add(group)
opts = s.options('section_axis'=>'Y','section_percent'=>25)
# A deep traversal would touch this definition's entities; preview only clips at root.
group.definition.entities.define_singleton_method(:each) { |*| raise 'Preview traversed shared definition' }
preview.update(m,opts)
plane = m.entities.active_section_plane
assert(group.definition.equal?(original_definition) && sibling.definition.equal?(original_definition), 'Preview split shared definition')
assert(sibling.hidden? && other.hidden? && !group.hidden?, 'Preview isolation changed wrong roots')
preview.update(m,opts.merge('section_percent'=>80))
assert(m.entities.grep(Sketchup::SectionPlane)==[original_cut,plane], 'Slider adds duplicate preview planes')
preview.clear
assert(m.entities.active_section_plane.equal?(original_cut) && m.entities.grep(Sketchup::SectionPlane)==[original_cut], 'Preview lost original cut or left temporary plane')
assert(!sibling.hidden? && other.hidden? && group.definition.equal?(original_definition), 'Preview did not restore roots/shared identity')
assert(saved_page.camera.eye == saved_camera.eye && saved_page.camera.target == saved_camera.target, 'Preview saved camera')

# Error after setter writes must clean the temporary cut and restore visibility.
preview.update(m,opts)
plane = m.entities.active_section_plane
def plane.set_plane(value); @plane=value; raise 'Injected cut setter error'; end
rejects('preview setter error') { preview.update(m,opts.merge('section_percent'=>60)) }
assert(m.entities.active_section_plane.equal?(original_cut) && !sibling.hidden? && other.hidden?, 'Failed slider left cut/isolation')
assert(group.definition.equal?(original_definition),'Failed preview changed definition')

# Creation failure also restores isolation without leaving a session/plane.
entities = m.entities
entities.singleton_class.alias_method(:review_add_section_plane,:add_section_plane)
entities.define_singleton_method(:add_section_plane) { |*| nil }
rejects('preview creation error') { preview.update(m,opts) }
assert(!sibling.hidden? && other.hidden? && m.entities.grep(Sketchup::SectionPlane)==[original_cut], 'Creation failure left isolation/geometry')
entities.singleton_class.alias_method(:add_section_plane,:review_add_section_plane)

# A cleanup error remains retryable rather than forgetting its session.
preview.update(m,opts)
sibling.define_singleton_method(:hidden=) do |value|
  if !value && !@cleanup_failed; @cleanup_failed=true; raise 'Injected restore error'; end
  @hidden=value
end
rejects('retryable cleanup') { preview.clear }
preview.clear
assert(!sibling.hidden? && other.hidden? && m.entities.active_section_plane.equal?(original_cut), 'Cleanup retry failed')

# Selection/model switch cleans only the prior preview; scenes/new model remain intact.
preview.update(m,opts)
other_model = Sketchup::Model.new; Sketchup.active_model = other_model
events = other_model.events.dup
preview.clear_if_stale(other_model)
assert(other_model.events == events && other_model.entities.empty?, 'Preview cleanup touched receiving model')
assert(!sibling.hidden? && group.definition.equal?(original_definition),'Model switch left isolated/shared object')
Sketchup.active_model = previous_model
puts 'PASS: shallow root preview preserves definitions/scenes/original cuts, single slider plane, hidden roots, create/setter failure cleanup, retry and model-switch isolation'
