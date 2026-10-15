# Regression fixtures for 1.5: identity-safe scene edits and preview-only camera/cuts.
prior_model = Sketchup.active_model
s = VGD::Scenes; store = s::SceneStore; preview = s::SectionPreview; transfer = s::SceneTransfer
m = Sketchup::Model.new; Sketchup.active_model = m
pages = %w[A B C D E].map { |name| m.pages.add(name, PAGE_USE_CAMERA) }
ids = pages.map { |page| page.persistent_id.to_s }
m.pages.selected_page = pages[0]
saved = pages.map(&:saved); live = s.camera_copy(m.active_view.camera)
store.reorder(m, [ids[1], ids[3]], ids[0], ids)
target = [pages[1],pages[3],pages[0],pages[2],pages[4]]
assert(store.ordered(m) == target && m.pages == pages, 'Block move changed identity or internal group order')
rejects('legacy native order guard') { store.sync_order(m, target.map { |p| p.persistent_id.to_s }) }
assert(m.pages == pages && pages.map(&:saved) == saved, 'Unsupported native reorder wrote scenes')
m.pages.define_singleton_method(:reorder) { |page, index| delete(page); insert(index, page); nil }
store.sync_order(m, target.map { |p| p.persistent_id.to_s })
assert(m.pages == target && pages.all?(&:valid?) && pages.map(&:saved)==saved, 'Native sync recreated or captured scenes')
assert(m.pages.selected_page == pages[0] && m.active_view.camera.eye == live.eye, 'Native sync changed live view')
rejects('stale native order') { store.sync_order(m, ids) }
raw = {'ids'=>[ids[0],ids[1]],'base'=>'Phòng ngủ','prefix'=>'PN','suffix'=>'FINAL','separator'=>'_','sequence'=>'number','start'=>1}
store.rename_many(m, raw)
assert(pages[1].name == 'PN_Phòng ngủ_01_FINAL' && pages[0].name == 'PN_Phòng ngủ_02_FINAL', 'Batch rename ignored table order')
store.rename_many(m,raw.merge('sequence'=>'letter','start'=>26))
assert(pages[1].name.include?('_Z_') && pages[0].name.include?('_AA_'), 'Alphabet sequence does not wrap after Z')
names = pages.map(&:name)
rejects('duplicate batch names') { store.rename_many(m, raw.merge('sequence'=>'none')) }
rejects('foreign name collision') { store.rename_many(m, raw.merge('ids'=>[ids[0]],'prefix'=>'','suffix'=>'','base'=>pages[2].name,'sequence'=>'none')) }
rejects('fractional sequence') { store.rename_many(m, raw.merge('start'=>1.5)) }
assert(pages.map(&:name)==names && pages.map(&:saved)==saved, 'Rejected rename partially changed scene state')

group = product(m); sibling = Sketchup::ComponentInstance.new(group.definition,'Bản sao');sibling.layer=m.layers[0];m.entities << sibling
m.selection.add(group)
original_definition = group.definition
before_camera = s.camera_copy(m.active_view.camera); before_render = m.rendering_options.dup; before_count = m.pages.length
preview.update(m, s.options('section_axis'=>'X','section_percent'=>25))
plane = m.entities.active_section_plane
assert(plane && group.definition == original_definition && sibling.definition == original_definition && sibling.definition.entities.empty?, 'Preview modified shared definitions')
assert(m.pages.length==before_count && m.entities.grep(Sketchup::SectionPlane)==[plane], 'Preview duplicated root section or scene')
first_point = plane.plane[0].to_a
preview_camera = s.camera_copy(m.active_view.camera)
preview.update(m, s.options('section_axis'=>'X','section_percent'=>75))
assert(m.entities.active_section_plane.equal?(plane) && plane.plane[0].to_a != first_point, 'Slider duplicates or does not move section')
assert(m.active_view.camera.eye == preview_camera.eye, 'Slider repeatedly reframed camera')
preview.clear
assert(group.entities.empty? && m.entities.grep(Sketchup::SectionPlane).empty? && group.definition == original_definition && !sibling.hidden? && m.active_view.camera.eye == before_camera.eye && m.rendering_options == before_render, 'Preview cleanup did not restore definition/view/section state')
assert(pages.map(&:saved)==saved,'Section preview persisted scene state')
preview.update(m, s.options('section_axis'=>'Z','section_percent'=>50))
s.dispatch('section',{'model'=>m.object_id.to_s,'settings'=>s.options('section_axis'=>'Z','section_percent'=>50)})
assert(group.entities.grep(Sketchup::SectionPlane).length==1 && group.entities.first.get_attribute(s::DICT,'preview')!=true, 'Generate kept temporary preview plane')
rejects('removed custom preview') { preview.update(m,s.options('section_axis'=>'CUSTOM')) }

# Copy live unsaved Orbit, paste exact frame into another model, do not save its scene.
singleton = class << transfer; self; end
singleton.alias_method(:review_original_view_path,:view_clipboard_path)
singleton.define_method(:view_clipboard_path) { '/tmp/view-memory.json' }
begin
  source = Sketchup::Model.new; Sketchup.active_model = source
  src = source.pages.add('Source', PAGE_USE_CAMERA);source.pages.selected_page=src
  s::SceneFrame.store(src, s.options('width'=>1200,'height'=>1600,'margin'=>23))
  source.active_view.camera=Sketchup::Camera.new(Geom::Point3d.new(210,150,90),Geom::Point3d.new(10,20,30),Geom::Vector3d.new(0,0,1),true)
  source.active_view.camera.aspect_ratio=0.75;source.active_view.camera.fov=67
  source_saved=s.camera_copy(src.camera)
  UI.toolbars.first.commands[3].proc.call
  copied=transfer.read(transfer.view_clipboard_path)['scenes'].first
  assert(copied['camera']['eye']==[210.0,150.0,90.0] && copied['frame']['width']==1200, 'Toolbar copy uses saved scene instead of live view/frame')
  assert(src.camera.eye==source_saved.eye && source.pages.length==1,'Copy saved or created a scene')
  dest=Sketchup::Model.new;Sketchup.active_model=dest
  page=dest.pages.add('Destination',PAGE_USE_CAMERA);dest.pages.selected_page=page
  s::SceneFrame.store(page,s.options('width'=>1920,'height'=>1080))
  old=s.camera_copy(page.camera);old_frame=page.get_attribute(s::DICT,'frame')
  UI.toolbars.first.commands[4].proc.call
  assert(dest.pages.length==1 && dest.pages.selected_page==page && page.name=='Destination' && page.camera.eye==old.eye && page.get_attribute(s::DICT,'frame')==old_frame,'Paste created/renamed/saved destination scene')
  assert(dest.active_view.camera.eye.to_a==[210.0,150.0,90.0] && near(dest.active_view.camera.aspect_ratio,0.75) && near(dest.active_view.camera.fov,67),'Paste lost live camera/frame')
  assert(s.state[:current_frame]['width']==1200 && s.state[:current_frame]['height']==1600,'Dialog does not expose pasted preview frame')
  UI.toolbars.first.commands[2].proc.call
  assert(page.camera.eye==dest.active_view.camera.eye && s::SceneFrame.read(page,s.settings(dest))['width']==1200,'Manual Update did not save pasted frame')
ensure
  singleton.alias_method(:view_clipboard_path,:review_original_view_path)
  singleton.remove_method(:review_original_view_path)
  preview.clear
  Sketchup.active_model=prior_model
  s.instance_variable_set(:@live_frame,nil)
end
puts 'PASS: block scene move, identity-safe native sync/legacy guard, bulk names and conflicts, live local cut preview/cleanup, toolbar camera memory preserves scenes until Update'
