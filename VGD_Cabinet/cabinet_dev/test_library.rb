# File persistence is real host IO; SKP export/import remains a fixture here.
class Sketchup::Definition
  def save_copy(path)
    File.binwrite(path,"SKP_FIXTURE_ONLY\n"+JSON.generate(VGD_Cabinet::PreviewMesh.from_definition(self).to_data)); true
  end
  def save_thumbnail(path)
    File.binwrite(path,Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=')); true
  end
end
_,_,entities=build('door_style'=>'Shaker')
root=Sketchup::Group.new
entities.each { |e| root.entities << e }
manual=root.entities.add_group; manual.name='Manual edit'; manual.entities.add_face([[0,0,0],[1,0,0],[1,1,0],[0,1,0]]).pushpull(1)
store=VGD_Cabinet::LibraryStore.new('/tmp/vgd-library-test')
store.save('Tủ đã sửa',root.definition,VGD_Cabinet.default_params,[1,1,1],VGD_Cabinet::VERSION)
item=store.entry('Tủ đã sửa'); bytes=File.binread(store.asset_path(item,'skp'))
assert(bytes.start_with?('SKP_FIXTURE_ONLY') && store.preview(item)['surfaces'].size>100,'Missing geometry asset/preview')
assert(store.thumbnail(item).start_with?('data:image/png;base64,'),'Missing thumbnail')
fresh=VGD_Cabinet::LibraryStore.new('/tmp/vgd-library-test')
assert(fresh.entry('Tủ đã sửa')==item,'Library lost on restart')
fresh.rename('Tủ phòng ngủ','Tủ đã sửa'); assert(fresh.entry('Tủ phòng ngủ')['asset_id']==item['asset_id'],'Rename changed asset')
begin; fresh.save('TỦ PHÒNG NGỦ',root.definition,VGD_Cabinet.default_params,[1,1,1],VGD_Cabinet::VERSION); raise 'Library duplicate overwritten'; rescue VGD_Cabinet::ModelingRules::Invalid; end
assert(File.binread(store.asset_path(item,'skp'))==bytes,'Collision overwrote geometry')
failing=Object.new; def failing.save_as(_); false; end
begin; fresh.save('Ghi thất bại',failing,VGD_Cabinet.default_params,[1,1,1],VGD_Cabinet::VERSION); raise 'False export accepted'; rescue VGD_Cabinet::ModelingRules::Invalid; end
assert(!fresh.entries.key?('Ghi thất bại'),'Failed export committed index')
fresh.save('Tủ phòng ngủ',root.definition,VGD_Cabinet.default_params,[2,1,1],VGD_Cabinet::VERSION,true)
updated=fresh.entry('Tủ phòng ngủ'); assert(updated['asset_id']!=item['asset_id'] && updated['dimensions']==[1600,600,2400],'Explicit replacement/scale failed')
load_path=nil
fresh.with_load_copy(updated) { |path| load_path=path; assert(File.file?(path) && path!=store.asset_path(updated,'skp'),'SU2022 load path must be unique') }
assert(load_path && !File.exist?(load_path),'Temporary load copies leaked')
fresh.delete('Tủ phòng ngủ'); assert(fresh.entries.empty?,'Deleted library item returned')
assert(File.file?(fresh.asset_path(updated,'skp')),'Deletion removed backup asset')
fresh.save('Mẫu mở lại',root.definition,VGD_Cabinet.default_params,[1,1,1],VGD_Cabinet::VERSION)
begin; fresh.asset_path({'asset_id'=>'../../foreign'},'skp'); raise 'Path traversal accepted'; rescue VGD_Cabinet::ModelingRules::Invalid; end
puts 'PASS library file store: geometry/thumbnail/preview fixtures, new store reopening, Unicode collision, rename, failed export, replacement, scale, safe asset paths and temporary load cleanup; native SKP export not claimed'
tool=VGD_Cabinet::CabinetDrawTool.new(VGD_Cabinet.normalize('w'=>1600,'module_mode'=>'Độc lập','module_widths'=>'800;800'))
resized=tool.params_for_size(1800,650,2800)
assert(resized['module_widths']=='900.0;900.0','3-point dimensions did not proportionally resize modules')
puts 'PASS drawing dimensions: independent module widths follow 3-point overall resize'
