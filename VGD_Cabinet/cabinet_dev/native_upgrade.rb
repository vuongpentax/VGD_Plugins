# Run explicitly in the SketchUp Ruby Console. Creates only temporary test parts,
# aborts the model operation, and stores test files under this project's outputs.
require 'json'
require 'fileutils'
require_relative '../cabinet_work/VGD_Cabinet/main43'
module VGDCabinetNativeUpgrade
  module_function
  def assert(value,message); raise message unless value; end
  def walk(entities,result=[])
    entities.each do |entity|
      next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      result << entity; walk(entity.definition.entities,result)
    end
    result
  end
  def close(a,b); (a-b).abs<0.02; end
  def run
    model=Sketchup.active_model; saved_selection=model.selection.to_a; active_layer=model.active_layer
    original_roots=model.entities.to_a; was_busy=VGD_Cabinet.instance_variable_get(:@busy)
    root=File.expand_path('../outputs/upgrade_fixture_'+Time.now.strftime('%Y%m%d_%H%M%S'),__dir__)
    FileUtils.mkdir_p(root)
    report={'version'=>VGD_Cabinet::VERSION,'sketchup'=>Sketchup.version,'ruby'=>RUBY_VERSION,'results'=>[]}
    VGD_Cabinet.instance_variable_set(:@busy,true)
    started=false
    begin
      model.start_operation('VGD Cabinet native upgrade fixture',true); started=true
      model.active_layer=model.layers[0]
      config=VGD_Cabinet.normalize('w'=>1600,'auto_door_count'=>false,'door_count'=>4,'auto_divider_wide'=>false)
      test=model.entities.add_group; test.name='VGD_NATIVE_FIXTURE'
      VGD_Cabinet::Modeling.draw(test.entities,config)
      doors=walk(test.entities).select { |e| e.get_attribute('dynamic_attributes','onclick',nil) }
      left=doors.select { |e| e.definition.name.start_with?('Cánh Trái') }; right=doors.select { |e| e.definition.name.start_with?('Cánh Phải') }
      assert(left.size==2 && right.size==2,'Expected 2 left + 2 right hinged components')
      assert(left.map(&:definition).uniq.size==1 && right.map(&:definition).uniq.size==1,'Door definitions not shared')
      assert(left.first.definition!=right.first.definition,'Left/right hinge definitions merged')
      marker=left.first.definition.entities.add_cpoint([1,2,3]); assert(left.last.definition.entities.include?(marker),'Manual definition edit did not propagate')
      marker.erase!
      report['results'] << 'PASS native component sharing and manual edits'
      %w[Lộ Âm].each do |mode|
        group=model.entities.add_group
        p=VGD_Cabinet.normalize('opt_door'=>'Không Cánh','opt_drawer'=>mode,'is_full_drawer'=>true,'drawer_columns'=>2,'auto_divider_wide'=>false)
        VGD_Cabinet::Modeling.draw(group.entities,p)
        assemblies=group.entities.to_a.select { |e| e.respond_to?(:definition) && e.name.start_with?('Ngăn Kéo ') && e.name.end_with?('Tầng 1') }
        fronts=assemblies.flat_map do |assembly|
          assembly.definition.entities.to_a.select { |part| part.respond_to?(:definition) && part.name=='Mặt Ngăn Kéo 1' }.map do |part|
            bounds=Geom::BoundingBox.new
            8.times { |i| bounds.add(part.bounds.corner(i).transform(assembly.transformation)) }
            bounds
          end
        end
        fronts=fronts.sort_by { |bounds| bounds.min.x }
        assert(fronts.size==2 && close(fronts[0].max.x.to_mm,fronts[1].min.x.to_mm),'Drawer fronts expose central divider')
        assert(close(fronts.first.min.x.to_mm,0)&&close(fronts.last.max.x.to_mm,800),'Exposed faces do not overlay outer sides') if mode=='Lộ'
      end
      report['results'] << 'PASS native concealed/exposed 2-column drawer overlays'
      cases=[['tier upper',{'h'=>2700,'overheight_join'=>'Xà Trên'}],['tier lower',{'h'=>2700,'overheight_join'=>'Xà Dưới'}],
             ['stop rails',{'w'=>1600,'door_stop_rail'=>true,'auto_divider_wide'=>false,'div_count'=>1}],
             ['drawer rails',{'opt_drawer'=>'Âm','drawer_columns'=>2,'drawer_backing_rail'=>true}],
             ['curved sides',{'h'=>2700,'opt_left_side'=>'Bo Cong','opt_right_side'=>'Bo Cong','overheight_join'=>'Xà Dưới'}],
             ['independent',{'w'=>1600,'module_mode'=>'Độc lập','module_widths'=>'800;800','h'=>2700}]]
      ['Shaker','Pano khung gỗ','Kính khung kim loại'].each do |style|
        ['Ngang','Dọc','Chéo X'].each { |division| cases << [style+' '+division,{'door_style'=>style,'frame_division'=>division,'frame_bar_width'=>25,'frame_sections'=>3}] }
      end
      cases.each do |name,changes|
        group=model.entities.add_group; p=VGD_Cabinet.normalize(changes)
        VGD_Cabinet::Modeling.draw(group.entities,p)
        leaves=walk(group.entities).select { |part| part.definition.entities.any? { |e| e.is_a?(Sketchup::Face) } }
        bad=leaves.reject { |part| part.manifold? }
        assert(bad.empty?,name+': non-manifold parts '+bad.map(&:name).join(', '))
        report['results'] << 'PASS native solid parts: '+name
      end
      before=[model.entities.size,model.definitions.size,model.materials.size,model.layers.size]
      mesh=VGD_Cabinet::PreviewMesh.new(config)
      after=[model.entities.size,model.definitions.size,model.materials.size,model.layers.size]
      assert(before==after,'Preview mutated model')
      assert(mesh.surfaces.size>100,'Preview missing structure')
      report['results'] << 'PASS native preview mesh without model mutation'
      # Export actual manually edited geometry and reload it, rather than rebuilding params.
      manual=test.entities.add_group; manual.name='MANUAL_LIBRARY_MARKER'
      face=manual.entities.add_face([[0,0,0],[20.mm,0,0],[20.mm,20.mm,0],[0,20.mm,0]]); face.pushpull(20.mm)
      definition=test.to_component.definition
      store=VGD_Cabinet::LibraryStore.new(File.join(root,'library'))
      store.save('Native tủ mẫu',definition,config,[1,1,1],VGD_Cabinet::VERSION)
      item=store.entry('Native tủ mẫu')
      assert(store.thumbnail(item),'No native thumbnail')
      loaded=store.with_load_copy(item) { |path| model.definitions.load(path) }
      assert(loaded.entities.any? { |entity| entity.respond_to?(:name) && entity.name=='MANUAL_LIBRARY_MARKER' },'Manual geometry lost in library')
      fresh=VGD_Cabinet::LibraryStore.new(File.join(root,'library'))
      assert(fresh.entries.key?('Native tủ mẫu'),'Library did not survive new store instance')
      fresh.rename('Tên mới','Native tủ mẫu')
      assert(fresh.entry('Tên mới')['asset_id']==item['asset_id'],'Rename lost saved geometry')
      begin
        fresh.save('Tên mới',definition,config,[1,1,1],VGD_Cabinet::VERSION)
        raise 'Duplicate library name overwrote existing entry'
      rescue VGD_Cabinet::ModelingRules::Invalid
      end
      fresh.save('Tên mới',definition,config,[1,1,1],VGD_Cabinet::VERSION,true)
      fresh.delete('Tên mới'); assert(fresh.entries.empty?,'Deleted library entry resurrected')
      report['results'] << 'PASS native SKP/thumbnail/library file locking, manual geometry reload, persistence/rename/collision/update/delete'
      report['status']='PASS'
    rescue => error
      report['status']='FAIL'; report['error']="#{error.class}: #{error.message}"; report['backtrace']=error.backtrace.first(8)
    ensure
      model.abort_operation if started
      model.active_layer=active_layer
      model.selection.clear; model.selection.add(saved_selection.select(&:valid?))
      VGD_Cabinet.instance_variable_set(:@busy,was_busy)
      report['model_roots_preserved']=original_roots.all?(&:valid?) && model.entities.to_a==original_roots
      report['status']='FAIL' unless report['model_roots_preserved']
      File.write(File.join(root,'NATIVE_VALIDATION.json'),JSON.pretty_generate(report))
      puts 'VGD_NATIVE_UPGRADE '+JSON.generate(report)
      $stdout.flush
    end
    if report['status']=='PASS'
      capture=report
      tool=Object.new
      mesh=VGD_Cabinet::PreviewMesh.new(VGD_Cabinet.normalize({}))
      tool.define_singleton_method(:draw) do |view|
        begin
          mesh.draw(view,Geom::Transformation.new)
          capture['native_preview_draw_calls']=(capture['native_preview_draw_calls']||0)+1
        rescue => error
          capture['native_preview_draw_error']="#{error.class}: #{error.message}"
        end
      end
      model.select_tool(tool); model.active_view.invalidate
      UI.start_timer(1.5,false) do
        model.select_tool(nil)
        File.write(File.join(root,'NATIVE_VALIDATION.json'),JSON.pretty_generate(capture))
        puts 'VGD_NATIVE_PREVIEW '+JSON.generate(capture.slice('native_preview_draw_calls','native_preview_draw_error')); $stdout.flush
      end
    end
    report
  end
end
VGDCabinetNativeUpgrade.run
