const fs=require('fs'),path=require('path');
const deps=process.env.VGD_NODE_MODULES||path.resolve(__dirname,'../../VGD_Scenes/dev/node_modules');
const {DefaultRubyVM}=require(path.join(deps,'@ruby/wasm-wasi/dist/cjs/node.js'));
(async()=>{
  const wasm=await WebAssembly.compile(fs.readFileSync(require.resolve(path.join(deps,'@ruby/3.2-wasm-wasi/dist/ruby+stdlib.wasm'))));
  const {vm}=await DefaultRubyVM(wasm),root=path.resolve(__dirname,'../runtime');
  const names=['version','defaults','engine','native_style','store','managed','core','presets','autostyle','animation','smartdim','probe','dialog','update_core/manifest','update_core/bootstrap','update_core/client','update_core/installer','update_core/updater','main','reload'];
  const installerSource=fs.readFileSync(path.join(root,'VGD_Dim/update_core/installer.rb'),'utf8');
  if(!installerSource.includes(':new_pgroup => true')||installerSource.includes(':pgroup => true'))throw Error('Windows updater must use :new_pgroup, not POSIX :pgroup');
  const literal=value=>JSON.stringify(Buffer.from(value,'utf8').toString('base64'))+'.unpack1("m0")';
  for(const file of ['vgd_dim.rb',...names.map(n=>'VGD_Dim/'+n+'.rb')]){
    vm.eval('RubyVM::InstructionSequence.compile('+literal(fs.readFileSync(path.join(root,file),'utf8'))+')');
    console.log('Syntax OK:',file);
  }
  vm.eval('RubyVM::InstructionSequence.compile('+literal(fs.readFileSync(path.join(__dirname,'native_smoke.rb'),'utf8'))+')');
  vm.eval(fs.readFileSync(path.join(__dirname,'test_fixture.rb'),'utf8'));
  for(const name of names.filter(n=>!['main','reload','update_core/installer'].includes(n)))vm.eval(fs.readFileSync(path.join(root,'VGD_Dim',name+'.rb'),'utf8'));

  for(const [file,run] of [['test_engine.rb','run_engine_tests'],['test_native_style.rb','run_native_style_tests'],['test_core.rb','run_core_tests; run_service_tests'],['test_smartdim.rb','run_smartdim_tests'],['test_store.rb','run_store_tests']]){
    vm.eval(fs.readFileSync(path.join(__dirname,file),'utf8'));vm.eval(run+'; $stdout.flush');
  }
  if(process.env.VGD_VERIFY_LOCAL_PREFERENCES){
    const nativePath=path.join(process.env.LOCALAPPDATA,'SketchUp/SketchUp 2022/SketchUp/PrivatePreferences.json');
    const saved=JSON.parse(fs.readFileSync(nativePath,'utf8').replace(/^\uFEFF/,''))['This Computer Only']?.VGDDim;
    if(!saved)throw Error('Local VGD Dim preferences not found');
    let count=0;
    for(const key of ['auto','smartdim','presets']){
      if(typeof saved[key]!=='string')continue;
      vm.eval('actual=VGD::Dim::Store.decode_legacy('+literal(saved[key])+'); check(actual.is_a?(Hash), "Actual VGD Dim preferences not recovered")');
      if(key==='auto')vm.eval('check(VGD::Dim::Core.validate_settings(actual.fetch("settings",{})).is_a?(Hash), "Actual Auto settings invalid")');
      count++;
    }
    console.log(`PASS: ${count} actual SU2022 VGD Dim fields decoded read-only; native preferences unchanged and values not logged.`);
  }
  vm.eval(`check(VGD::Dim::UpdateCore::Updater.newer?('3.3.0-beta.3','3.3.0-beta.1'),'Beta version comparison failed'); check(VGD::Dim::UpdateCore::Updater.newer?('3.3.1','3.3.0'),'Stable version comparison failed'); info=VGD::Dim::UpdateCore::Manifest.parse(JSON.generate({'product_id'=>'vgd_dim','version'=>'3.3.0-beta.3','channel'=>'beta','min_sketchup_year'=>'2022','filename'=>'VGD_Dim_v3.3.0-beta.3.rbz','bytes'=>10,'sha256'=>'a'*64,'download_url'=>'https://github.com/vuongpentax/VGD_Plugins/releases/download/vgd-dim-v3.3.0-beta.3/VGD_Dim_v3.3.0-beta.3.rbz','changelog'=>'pilot'})); check(info['version']=='3.3.0-beta.3','Manifest parse failed'); VGD::Dim::UpdateCore::Bootstrap.validate_expected!({'main.rb'=>'a'*64}); safe=VGD::Dim::UpdateCore::Bootstrap.sibling_path!('/tmp/VGD_Dim.backup_'+('a'*32),'/tmp',/\\AVGD_Dim\\.backup_[0-9a-f]{32}\\z/i); check(File.basename(safe).start_with?('VGD_Dim.backup_'),'Backup sibling validation failed'); unsafe=false; begin; VGD::Dim::UpdateCore::Bootstrap.sibling_path!('/tmp/../outside','/tmp',/\\AVGD_Dim\\.backup_[0-9a-f]{32}\\z/i); rescue StandardError; unsafe=true; end; check(unsafe,'Outside backup path was accepted');`);
  vm.eval(`
    module Sketchup
      module Http
        GET = :get
        class Request
          @@requests=[]
          attr_accessor :headers
          def self.requests; @@requests; end
          def initialize(url,method); @url=url; @method=method; @@requests << self; end
          def start(&block); @callback=block; end
          def complete(code,body,headers={})
            response=Struct.new(:status_code,:body,:headers).new(code,body,headers)
            @callback.call(self,response)
          end
          def cancel; @cancelled=true; true; end
          def cancelled?; @cancelled; end
        end
      end
    end
    response=[]
    payload='fixture'
    digest=Digest::SHA256.hexdigest(payload)
    info={'download_url'=>'https://github.com/vuongpentax/VGD_Plugins/releases/download/vgd-dim-v3.3.0-beta.3/VGD_Dim_v3.3.0-beta.3.rbz','bytes'=>payload.bytesize,'sha256'=>digest}
    updater_client=VGD::Dim::UpdateCore::Client.new
    updater_client.download(info){|status,value| response << [status,value]}
    check(response.empty?,'Download callback fired before response')
    Sketchup::Http::Request.requests.last.complete(200,payload)
    check(response.length==1 && response.first==[:ok,payload],'Verified download did not complete')
    timeout_result=[]
    VGD::Dim::UpdateCore::Client.new.check{|status,body| timeout_result << [status,body]}
    timeout_timer=UI.timers.keys.max
    UI.timers.delete(timeout_timer).call
    check(timeout_result.length==1 && timeout_result.first[0]==0,'Timeout did not complete exactly once')
    check(Sketchup::Http::Request.requests.last.cancelled?,'Timeout did not cancel the request')
  `);
  const main=fs.readFileSync(path.join(root,'VGD_Dim/main.rb'),'utf8').replace(/^require[^\n]*\n/gm,'');
  vm.eval(main);vm.eval(main);
  vm.eval(`
    check(UI.toolbars.length==1 && UI.toolbars.first.events==[:add,:add],'Toolbar duplicated')
    VGD::Dim.show_dialog
    dialog=VGD::Dim::Dialog.instance_variable_get(:@dlg)
    expected=%w[ready scan run rebuild smart_dim save_preset delete_preset set_auto anim_set dim_info text_info native_apply units_apply]
    check(dialog.callbacks.keys.sort==expected.sort,'Missing callback')
    VGD::Dim.show_dialog
    check(VGD::Dim::Dialog.instance_variable_get(:@dlg).equal?(dialog) && dialog.fronts==1,'Dialog duplicated')
    before=UI.messages.to_a.length
    dialog.callbacks['ready'].call(nil,nil)
    check(dialog.scripts.last.start_with?('VGD.onState'),'State missing')
    m=Sketchup::FakeModel.new; Sketchup.active_model=m
    dim=Sketchup::DimensionLinear.new; outside=Sketchup::Text.new
    m.entities << dim; m.entities << outside; m.selection.add(dim)
    payload=JSON.generate({'kinds'=>['dim'],'settings'=>{},'opts'=>{}})
    dialog.callbacks['run'].call(nil,payload)
    check(m.commits==1 && dim.layer=='000 DIM' && outside.layer.nil?,'Run scope wrong')
    dialog.callbacks['run'].call(nil,'bad json')
    check(m.commits==1 && dialog.scripts.last.start_with?('VGD.onError'),'Malformed payload not caught')
    UI.info_pages=[]; UI.info_result=true
    dialog.callbacks['dim_info'].call(nil,nil); dialog.callbacks['text_info'].call(nil,nil)
    check(UI.info_pages==['Dimensions','Text'],'Model Info routes wrong')
    VGD::Dim::NativeStyle.adapter=FakeStyleAdapter.new
    dim.material=:keep_color
    dialog.callbacks['native_apply'].call(nil,nil); UI.drain
    check(dim.material==:keep_color && m.selection.to_a==[dim],'Font-only apply overwrote color/selection')
    check(UI.messages.to_a.length==before,'Completion popup')
    dialog.close
    check(!VGD::Dim::Dialog.visible?,'Close retained dialog')
    m,root=smart_fixture
    VGD::Dim::SmartDim.execute({'face'=>'-y','off1'=>123},{'dim'=>{'arrow'=>'slash'}})
    original=managed_groups(m).first
    result=VGD::Dim.instance_variable_get(:@smart_command).invoke
    check(result['replaced']==1 && !original.valid? && managed_groups(m).size==1,'One-touch command did not replace')
    check(managed_groups(m).first.entities.grep(Sketchup::DimensionLinear).all? { |d| d.arrow_type==1 },'One-touch lost saved style')
    check(VGD::Dim::SmartDim.saved['opts']['off1']==123.0 && UI.messages.to_a.length==before,'One-touch lost saved settings or popup')
    puts 'PASS: complete callback wiring, one dialog/toolbar, native font-only color preservation, malformed JSON caught, no popups'
    $stdout.flush
  `);
})().catch(error=>{console.error(error);process.exitCode=1;});
