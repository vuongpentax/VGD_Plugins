def assert(condition, message); raise message unless condition; end
def near(a,b); (a-b).abs < 0.00001; end
def reject_options(cfg)
  begin
    VGD_ImageImporter.options(cfg)
  rescue ArgumentError
    return
  end
  raise "Invalid config accepted: #{cfg}"
end
plugin = VGD_ImageImporter
cfg = plugin.options({})
reject_options('spacing'=>-1)
reject_options('itemsPerRow'=>0)
reject_options('itemsPerRow'=>1.5)
reject_options('mmPerPixel'=>'NaN')
reject_options('targetHeight'=>'abc')
reject_options('importType'=>'execute')
assert(plugin.options('spacing'=>0)['spacing']==0, 'Zero spacing lost')
assert(plugin.options('alwaysFaceCamera'=>'true')['alwaysFaceCamera']==false, 'String bool accepted')
width,height = plugin.dimensions(1000,500,cfg)
assert(near(width,2000/25.4) && near(height,1000/25.4), 'Pixel conversion wrong')
width,height = plugin.dimensions(1000,500,plugin.options('scaleMethod'=>'height','targetHeight'=>2000))
assert(near(width,4000/25.4) && near(height,2000/25.4), 'Height ratio wrong')
width,height = plugin.dimensions(1000,500,plugin.options('scaleMethod'=>'width','targetWidth'=>2000))
assert(near(width,2000/25.4) && near(height,1000/25.4), 'Width ratio wrong')
begin; plugin.dimensions(10,0,cfg); raise 'Zero pixels accepted'; rescue ArgumentError; end
FileUtils.mkdir_p('/tmp/photos/sub')
%w[image10.png image2.PNG image1.jpg corrupt.png noimage.png badtexture.png].each { |name| File.write('/tmp/photos/'+name,'fixture') }
File.write('/tmp/photos/sub/nested.tiff','fixture')
File.write('/tmp/photos/sub/readme.txt','fixture')
FileUtils.mkdir_p('/tmp/photos/fake.png')
# Node WASI on Windows does not implement fd_readdir; provide directory entries
# while keeping File.file?/directory?, normalization and traversal in the engine.
class Dir
  def self.children(path)
    {
      '/tmp/photos' => %w[image10.png image2.PNG image1.jpg corrupt.png noimage.png badtexture.png sub fake.png],
      '/tmp/photos/sub' => %w[nested.tiff readme.txt],
      '/tmp/photos/fake.png' => []
    }.fetch(path)
  end
end
flat = plugin.folder_files('/tmp/photos')
assert(flat.length==6 && flat.index('/tmp/photos/image2.PNG') < flat.index('/tmp/photos/image10.png'), 'Scan order or directory filter wrong')
assert(plugin.folder_files('/tmp/photos',true).length==7,'Recursive scan failed')
paths = %w[image1.jpg corrupt.png image2.PNG image10.png].map { |name| '/tmp/photos/'+name }
model = Sketchup.active_model
result = plugin.process_import({'itemsPerRow'=>2,'spacing'=>0},paths)
assert(result['imported']==3 && result['failed']==1,'Partial import result wrong')
assert(model.operations==[:start,:commit],'One undo operation expected')
instances=model.active_entities.instances
assert(near(instances[0].transform.value[0],1000/25.4),'First image not bottom centered')
assert(near(instances[1].transform.value[0],3000/25.4) && instances[1].transform.value[1]==0,'Failed image incorrectly consumed slot')
assert(near(instances[2].transform.value[1],1000/25.4),'Row height wrong')
assert(instances[0].definition.behavior.always_face_camera==true,'Billboard behavior missing')
assert(instances[0].definition.entities.transforms.last.kind==:rotation,'Standing image not rotated')
result=plugin.process_import({'importType'=>'flat','alwaysFaceCamera'=>true},['/tmp/photos/image1.jpg'])
assert(model.active_entities.instances.last.definition.entities.transforms.length==1,'Flat image rotated')
assert(!model.active_entities.instances.last.definition.behavior.always_face_camera,'Flat image billboard enabled')
before=model.definitions.length
result=plugin.process_import({},['/tmp/photos/noimage.png'])
assert(result['imported']==0 && model.operations.last==:abort && model.definitions.length==before,'Failed definition not cleaned/aborted')
existing=model.materials.add('VGD_image1'); existing.texture='/tmp/original.png'
instances_before=model.active_entities.instances.length
result=plugin.process_import({'importType'=>'texture_only'},['/tmp/photos/image1.jpg','/tmp/photos/badtexture.png'])
assert(result['imported']==1 && result['failed']==1,'Texture failure report wrong')
assert(existing.texture.path=='/tmp/original.png' && model.materials.length==2,'Existing material overwritten or failed material leaked')
assert(model.active_entities.instances.length==instances_before,'Texture import created geometry')
assert(near(model.materials.last.texture.size[0],2000/25.4),'Texture scale wrong')
plugin.show_dialog
dialog=plugin.instance_variable_get(:@dialog)
plugin.show_dialog
assert(plugin.instance_variable_get(:@dialog).equal?(dialog),'Multiple dialog instances')
callback=dialog.callbacks['vgd_importer']
callback.call(nil,'ready','{}')
assert(dialog.scripts.any? { |script| script.include?('settings') && script.include?(plugin::VERSION) },'Ready handshake missing')
UI.directory='/tmp/photos'
callback.call(nil,'choose','{"kind":"folder","recursive":true}')
assert(plugin.instance_variable_get(:@files).length==7,'Native folder callback not wired')
# Replace only the operating-system picker, not queue handling.
picker = plugin::FilePicker
def picker.choose(directory, extensions); (@selected || []).dup; end
plugin::FilePicker.selected=['/tmp/photos/image1.jpg','/tmp/photos/image2.PNG']
callback.call(nil,'choose','{"kind":"files"}')
assert(plugin.instance_variable_get(:@files).length==7,'File picker did not deduplicate')
plugin::FilePicker.selected=[]
callback.call(nil,'choose','{"kind":"files"}')
assert(plugin.instance_variable_get(:@files).length==7,'Cancel erased queue')
callback.call(nil,'remove','{"id":-1}')
assert(plugin.instance_variable_get(:@files).length==7,'Negative index removed last image')
callback.call(nil,'save','{"theme":"dark","spacing":0}')
assert(plugin.saved_options['theme']=='dark' && plugin.saved_options['spacing']==0,'Settings not persisted')
callback.call(nil,'import','{"itemsPerRow":0}')
assert(dialog.scripts.last.include?('error'),'Invalid callback configuration not reported')
callback.call(nil,'clear','{}')
assert(plugin.instance_variable_get(:@files).empty?,'Clear callback failed')
single = "C:\\Ảnh người\\cây xanh.webp\0\0".encode('UTF-16LE')
assert(picker.parse_result(single)==["C:\\Ảnh người\\cây xanh.webp"], 'Unicode single selection parser failed')
multiple = "C:/Ảnh người\0cây 1.webp\0người 2.png\0\0".encode('UTF-16LE')
assert(picker.parse_result(multiple)==['C:/Ảnh người/cây 1.webp','C:/Ảnh người/người 2.png'], 'Unicode multiple selection parser failed')
%w[.webp .gif .avif .ico .svg .tga .jfif .heic].each { |extension| assert(plugin::SUPPORTED.include?(extension), 'Missing image format '+extension) }
# Directory cleanup uses a Windows WASI shim, for the same fd_readdir limitation.
class Dir
  def self.empty?(path); true; end
end
File.binwrite('/tmp/photos/transparent.webp','fixture webp')
plugin.instance_variable_set(:@files,['/tmp/photos/transparent.webp'])
plugin.begin_import({})
job=plugin.instance_variable_get(:@pending_import)
assert(job && dialog.scripts.last.include?('image/webp'),'WebP not sent to decoder')
plugin.accept_conversion('token'=>'wrong','id'=>0,'base64'=>'invalid')
assert(plugin.instance_variable_get(:@pending_import).equal?(job),'Unmatched decoder callback accepted')
png=Base64.strict_encode64("\x89PNG\r\n\x1a\nfixture".b)
plugin.accept_conversion('token'=>job[:token],'id'=>0,'base64'=>png)
assert(plugin.instance_variable_get(:@pending_import).nil? && dialog.scripts.last.include?('"imported":1'),'Converted WebP not imported')
assert(!File.exist?(File.join(job[:directory],'0.png')),'PNG cache leaked')
plugin.begin_import({})
job=plugin.instance_variable_get(:@pending_import)
plugin.accept_conversion('token'=>job[:token],'id'=>0,'error'=>'corrupt WebP')
assert(dialog.scripts.last.include?('"failed":1') && dialog.scripts.last.include?('corrupt WebP'),'Decoder failure not reported')
plugin.begin_import({})
job=plugin.instance_variable_get(:@pending_import)
plugin.accept_conversion('token'=>job[:token],'id'=>0,'base64'=>Base64.strict_encode64('not PNG'))
assert(dialog.scripts.last.include?('"failed":1'),'Invalid PNG accepted')
dialog.close
assert(plugin.instance_variable_get(:@dialog).nil?,'Closed dialog reference not cleared')
puts 'PASS: nil-return ImageRep regression, scale/ratio, scanning, partial failure/cleanup, texture isolation, multiselect parsing, callbacks, WebP conversion handshake/tokens/errors/cache cleanup and persisted settings.'
