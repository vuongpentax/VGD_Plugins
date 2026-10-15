# Run explicitly in the SketchUp Ruby Console. Creates only temporary test parts,
# aborts the model operation, and stores test files under this project's outputs.
require 'json'
require 'fileutils'
require_relative '../cabinet_work/VGD_Cabinet/main43'
# The native fixture can be rerun from the Ruby Console without restarting SketchUp.
# `require_relative` caches an already-loaded feature, so refresh the source under test.
%w[modeling_rules.rb frame_divisions.rb pano.rb rail_joinery.rb modeling.rb defaults.rb preview_mesh.rb model_data.rb box_conversion.rb main43.rb].each do |file|
  load File.expand_path('../cabinet_work/VGD_Cabinet/'+file,__dir__)
end
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
  def topology(entity)
    edges=entity.definition.entities.grep(Sketchup::Edge)
    open=edges.select { |edge| edge.faces.size==1 }
    overused=edges.select { |edge| edge.faces.size>2 }
    {
      'name'=>entity.name,
      'faces'=>entity.definition.entities.grep(Sketchup::Face).size,
      'edges'=>edges.size,
      'open_edges'=>open.size,
      'overused_edges'=>overused.size,
      'open_edge_samples'=>open.first(24).map { |edge| edge.vertices.map { |vertex| vertex.position.to_a.map { |n| n.to_mm.round(4) } } },
      'overused_edge_samples'=>overused.first(24).map { |edge| [edge.faces.size,edge.vertices.map { |vertex| vertex.position.to_a.map { |n| n.to_mm.round(4) } }] }
    }
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
      batch_source=VGD_Cabinet.normalize('w'=>1200,'d'=>500,'h'=>2100,'module_mode'=>'Độc lập','module_widths'=>'700;500')
      batch_result=VGD_Cabinet.batch_params_for(batch_source,{'door_style'=>'Shaker','w'=>9999,'module_widths'=>'9999;0'},[1,1,1])
      assert(batch_result['door_style']=='Shaker','Batch did not copy the requested front settings')
      assert(close(batch_result['w'],1200)&&close(batch_result['d'],500)&&close(batch_result['h'],2100),'Batch changed cabinet dimensions')
      batch_widths=VGD_Cabinet::ModelingRules.widths(batch_result)
      assert(batch_widths.size==2 && batch_widths.zip([700,500]).all? { |actual,expected| close(actual,expected) },'Batch changed per-cabinet module layout')
      assert(!VGD_Cabinet::FRONT_SETTING_KEYS.include?('div_count')&&!VGD_Cabinet::FRONT_SETTING_KEYS.include?('w'),'Batch whitelist includes construction layout or dimensions')
      report['results'] << 'PASS batch settings whitelist preserves cabinet size/module layout'
      test=model.entities.add_group; test.name='VGD_NATIVE_FIXTURE'
      VGD_Cabinet::Modeling.draw(test.entities,config)
      VGD_Cabinet::ModelData.assign_parts(test.entities,'native-fixture')
      doors=walk(test.entities).select { |e| e.get_attribute('dynamic_attributes','onclick',nil) }
      left=doors.select { |e| e.definition.name.start_with?('Cánh Trái') }; right=doors.select { |e| e.definition.name.start_with?('Cánh Phải') }
      assert(left.size==2 && right.size==2,'Expected 2 left + 2 right hinged components')
      assert(left.map(&:definition).uniq.size==1 && right.map(&:definition).uniq.size==1,'Door definitions not shared')
      assert(left.first.definition!=right.first.definition,'Left/right hinge definitions merged')
      assert(left.all? { |door| door.get_attribute(VGD_Cabinet::ModelData::DICTIONARY,'opening_kind',nil)=='hinged' && door.get_attribute(VGD_Cabinet::ModelData::DICTIONARY,'opening_side',nil)=='left' },'Left opening metadata missing')
      assert(right.all? { |door| door.get_attribute(VGD_Cabinet::ModelData::DICTIONARY,'opening_kind',nil)=='hinged' && door.get_attribute(VGD_Cabinet::ModelData::DICTIONARY,'opening_side',nil)=='right' },'Right opening metadata missing')
      marker=left.first.definition.entities.add_cpoint([1,2,3]); assert(left.last.definition.entities.include?(marker),'Manual definition edit did not propagate')
      marker.erase!
      report['results'] << 'PASS native component sharing and manual edits'
      box=model.entities.add_group; box.name='VGD_NATIVE_BOX_FIXTURE'
      box.entities.add_face([[0,0,0],[800.mm,0,0],[800.mm,600.mm,0],[0,600.mm,0]]).pushpull(2400.mm)
      box.transformation=Geom::Transformation.rotation(ORIGIN,Z_AXIS,30.degrees)
      converter=VGD_Cabinet::BoxToCabinetTool.new(config,[box])
      front_y=converter.send(:cabinet_frame,box,Geom::Vector3d.new(0,-1,0))
      front_x=converter.send(:cabinet_frame,box,Geom::Vector3d.new(1,0,0))
      assert(front_y && close(front_y[:width],800) && close(front_y[:depth],600) && close(front_y[:height],2400),'Rotated box local Y front dimensions/orientation failed')
      assert(front_x && close(front_x[:width],600) && close(front_x[:depth],800) && close(front_x[:height],2400),'Rotated box local X front dimensions/orientation failed')
      assert((front_y[:transform].xaxis.dot(front_y[:transform].yaxis)).abs<1e-6,'Box preview axes are not orthogonal')
      report['results'] << 'PASS native Box → Cabinet local front faces, rotated axes and dimensions'
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
      ['Shaker','Pano khung gỗ','Kính khung kim loại','Cánh kính bo góc'].each do |style|
        ['Ngang','Dọc','Chéo'].each { |joint| cases << [style+' joint '+joint,{'door_style'=>style,'frame_joint'=>joint}] }
      end
      ['Kính khung kim loại','Cánh kính bo góc'].each do |style|
        ['Ngang','Dọc'].each { |division| cases << [style+' glass panels '+division,{'door_style'=>style,'frame_division'=>division,'frame_bar_width'=>25,'frame_sections'=>3}] }
      end
      ['Cánh soi','Cánh soi vát 4 cạnh'].each do |style|
        cases << [style,{'door_style'=>style}]
      end
      cases.each do |name,changes|
        group=model.entities.add_group; p=VGD_Cabinet.normalize(changes)
        VGD_Cabinet::Modeling.draw(group.entities,p)
        leaves=walk(group.entities).select { |part| part.definition.entities.any? { |e| e.is_a?(Sketchup::Face) } }
        bad=leaves.reject { |part| part.manifold? }
        details=bad.map { |part| topology(part) }
        assert(bad.empty?,name+': non-manifold parts '+JSON.generate(details))
        report['results'] << 'PASS native solid parts: '+name
      end
      before=[model.entities.size,model.definitions.size,model.materials.size,model.layers.size]
      preview_config=VGD_Cabinet.normalize('w'=>1600,'h'=>2700,'h_bottom'=>2100,'door_style'=>'Cánh kính bo góc','frame_division'=>'Ngang','frame_joint'=>'Chéo','frame_sections'=>3)
      mesh=VGD_Cabinet::PreviewMesh.new(preview_config)
      after=[model.entities.size,model.definitions.size,model.materials.size,model.layers.size]
      assert(before==after,'Preview mutated model')
      assert(mesh.surfaces.size>100,"Preview missing structure (#{mesh.surfaces.size} surfaces)")
      assert(mesh.guides.all? { |line| line.size==2 && line.all? { |point| point.is_a?(Geom::Point3d) } },'Preview contains invalid overlay guides')
      report['results'] << 'PASS native preview mesh without model mutation; overlay guides retained'
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
