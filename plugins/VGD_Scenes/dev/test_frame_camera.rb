# frozen_string_literal: true
# Fixture regression: saved composition and live preview are distinct.
previous_model = Sketchup.active_model
s = VGD::Scenes; frames = s::SceneFrame; controls = s::CameraControl
m = Sketchup::Model.new; Sketchup.active_model = m
m.active_view.camera = Sketchup::Camera.new(Geom::Point3d.new(8,-60,30), Geom::Point3d.new(1,2,3), Geom::Vector3d.new(0,0,1), true)
m.active_view.camera.fov = 48
first = m.pages.add('Tủ bếp_TOP', PAGE_USE_CAMERA)
second = m.pages.add('Tủ bếp_ISO', PAGE_USE_CAMERA)
frames.store(first, s.options('width'=>1200,'height'=>1600))
frames.store(second, s.options('width'=>1920,'height'=>1080))
m.pages.selected_page = first
saved = s.camera_copy(first.camera); identity = first.camera; flags = first.use_camera?
assert(controls.state(m)[:sig] == controls.state(m)[:saved_sig], 'Initial camera signature differs from saved scene')
rendering = first.saved[:rendering].dup
m.active_view.camera = Sketchup::Camera.new(Geom::Point3d.new(200,100,90), Geom::Point3d.new(12,13,14), Geom::Vector3d.new(0,0,1), true)
m.active_view.camera.fov = 62
live = s.camera_copy(m.active_view.camera)
assert(controls.state(m)[:sig] != controls.state(m)[:saved_sig], 'Live Orbit does not differ from saved camera signature')
frames.apply(m, 'ids'=>[first.persistent_id.to_s], 'frame'=>{'width'=>1440,'height'=>1920,'margin'=>22})
assert(first.camera.equal?(identity) && first.camera.eye==saved.eye && first.camera.target==saved.target && first.camera.up==saved.up && near(first.camera.fov,48), 'Auto frame captured live Orbit/FOV')
assert(near(first.camera.aspect_ratio,0.75) && first.use_camera? == flags && first.saved[:rendering]==rendering, 'Frame changed scene flags/rendering')
assert(m.active_view.camera.eye==live.eye && m.active_view.camera.target==live.target && near(m.active_view.camera.fov,62), 'Frame discarded live composition')
FileUtils.mkdir_p('/tmp/frame-preview-export')
events=[];job=s::ExportJob.new(m,[first],s.options({}),'/tmp/frame-preview-export',lambda { |event,payload| events << [event,payload] });job.start;UI.tick
m.active_view.camera=s.camera_copy(live)
UI.drain
written=m.active_view.last_written_camera
assert(events.last[1][:success] && written.eye==saved.eye && near(written.fov,48) && near(written.aspect_ratio,0.75),'Export used uncommitted composition instead of old camera/new frame')
s::SceneStore.capture(m,first.persistent_id.to_s)
assert(first.camera.eye==live.eye && first.camera.target==live.target && near(first.camera.fov,62),'Update did not persist preview')
assert(controls.state(m)[:sig] == controls.state(m)[:saved_sig], 'Camera capture did not update saved signature')
current = m.pages.selected_page; live_identity=m.active_view.camera
frames.apply(m,'ids'=>[first,second].map { |p| p.persistent_id.to_s },'frame'=>{'width'=>3000,'height'=>2000,'margin'=>15},'keep_ratio'=>true)
assert(frames.read(first,s.settings(m))['width']==2250 && frames.read(first,s.settings(m))['height']==3000,'Batch lost portrait ratio')
assert(frames.read(second,s.settings(m))['width']==3000 && frames.read(second,s.settings(m))['height']==1688,'Batch lost landscape ratio')
assert(m.pages.selected_page==current && first.camera.eye==live.eye,'Batch visited or refitted scene')
before=[first,second].map { |p| [p.camera.aspect_ratio,p.get_attribute(s::DICT,'frame')] }
second.camera.fail_aspect_once=true
rejects('partial batch write') { frames.apply(m,'ids'=>[first,second].map { |p| p.persistent_id.to_s },'frame'=>{'width'=>1000,'height'=>1000}) }
assert([first,second].map { |p| [p.camera.aspect_ratio,p.get_attribute(s::DICT,'frame')] }==before && m.events.last==[:abort],'Batch rollback left modified scene')
before_events=m.events.length
rejects('missing frame target') { frames.apply(m,'ids'=>[first.persistent_id.to_s,'missing'],'frame'=>{'width'=>1000,'height'=>1000}) }
assert(m.events.length==before_events,'Invalid batch partially wrote frames')
frames.preset(m,'name'=>'Hồ sơ Tủ','frame'=>{'width'=>1200,'height'=>1600,'margin'=>20})
assert(frames.presets(m)['Hồ sơ Tủ']['height']==1600 && first.camera.eye==live.eye,'Named preset not persisted or changed camera')
frames.preset(m,'name'=>'Hồ sơ Tủ','delete'=>true)
assert(frames.presets(m).empty?,'Preset deletion failed')
first_saved=s.camera_copy(first.camera)
controls.preview(m,'kind'=>'lens','fov'=>75)
assert(near(m.active_view.camera.fov,75) && near(first.camera.fov,first_saved.fov),'FOV preview saved scene')
rejects('invalid fov') { controls.preview(m,'kind'=>'lens','fov'=>121) }
target=m.active_view.camera.target; distance=(target-m.active_view.camera.eye).length
%w[+X -X +Y -Y +Z -Z].each_with_index do |code,index|
  controls.preview(m,'kind'=>'align','axis_mode'=>'world','direction'=>code)
  expected=[Geom::Vector3d.new(1,0,0),Geom::Vector3d.new(-1,0,0),Geom::Vector3d.new(0,1,0),Geom::Vector3d.new(0,-1,0),Geom::Vector3d.new(0,0,1),Geom::Vector3d.new(0,0,-1)][index]
  camera=m.active_view.camera
  assert((camera.target-camera.eye).normalize==expected && camera.target==target && near((camera.target-camera.eye).length,distance) && near(camera.fov,75),'Six-axis align changed target/distance/lens')
end
object=product(m,20,30,40,'Tủ bếp');object.transformation=Geom::Transformation.rotation_z(30)*Geom::Transformation.scaling(-2,3,1)
m.selection.add(object)
controls.preview(m,'kind'=>'align','axis_mode'=>'local','direction'=>'+X')
assert((m.active_view.camera.target-m.active_view.camera.eye).normalize==object.transformation.xaxis.normalize,'Rotated/mirrored local align incorrect')
controls.preview(m,'kind'=>'align','axis_mode'=>'local','direction'=>'AUTO')
assert((m.active_view.camera.target-m.active_view.camera.eye).normalize==object.transformation.xaxis.normalize && m.active_view.camera.target==target,'Auto alignment refitted object')
m.selection.clear
first.set_attribute(s::DICT,'owner','VGD Scenes'); first.set_attribute(s::DICT,'source',{'paths'=>[[object.persistent_id]],'kind'=>'TOP'}.to_json)
controls.preview(m,'kind'=>'align','axis_mode'=>'local','direction'=>'+Y')
assert(s::SceneStore.list(m).first[:group]=='Tủ bếp','Source group name missing')
m.active_view.camera.perspective=false;m.active_view.camera.height=80
controls.preview(m,'kind'=>'lens','height_mm'=>2540,'fov'=>99)
assert(near(m.active_view.camera.height,100) && near(first.camera.fov,first_saved.fov),'Parallel preview used FOV or saved scene')
rejects('zero ortho height') { controls.preview(m,'kind'=>'lens','height_mm'=>0) }
m.active_path=[object]
rejects('frame editing') { frames.apply(m,'ids'=>[first.persistent_id.to_s],'frame'=>{}) }
rejects('camera editing') { controls.preview(m,'kind'=>'align','axis_mode'=>'world','direction'=>'AUTO') }
m.active_path=nil;m.active_view.camera.two_point=true
rejects('two point preview') { controls.preview(m,'kind'=>'lens','height_mm'=>1000) }
Sketchup.active_model=previous_model
puts 'PASS: old camera/new frame export until Update; batch ratios/preflight/rollback; model presets; FOV/parallel preview; six-axis world/rotated mirrored local/auto align without refit'
