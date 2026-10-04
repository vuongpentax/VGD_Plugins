const fs=require('fs'),path=require('path');
const deps=path.resolve(__dirname,'../../TPlus_Cabinet_Codex_Handoff_2026-10-01/cabinet_dev/node_modules');
const {DefaultRubyVM}=require(path.join(deps,'@ruby/wasm-wasi/dist/cjs/node.js'));
(async()=>{
  const wasm=await WebAssembly.compile(fs.readFileSync(require.resolve(path.join(deps,'@ruby/3.2-wasm-wasi/dist/ruby+stdlib.wasm'))));
  const {vm}=await DefaultRubyVM(wasm),root=path.resolve(__dirname,'../runtime');
  const names=['defaults','engine','native_style','store','core','presets','autostyle','animation','smartdim','probe','dialog','main','reload'];
  const literal=value=>JSON.stringify(Buffer.from(value,'utf8').toString('base64'))+'.unpack1("m0")';
  for(const file of ['vgd_dim.rb',...names.map(n=>'VGD_Dim/'+n+'.rb')]){
    vm.eval('RubyVM::InstructionSequence.compile('+literal(fs.readFileSync(path.join(root,file),'utf8'))+')');
    console.log('Syntax OK:',file);
  }
  vm.eval('RubyVM::InstructionSequence.compile('+literal(fs.readFileSync(path.join(__dirname,'native_smoke.rb'),'utf8'))+')');
  vm.eval(fs.readFileSync(path.join(__dirname,'test_fixture.rb'),'utf8'));
  for(const name of names.filter(n=>!['main','reload'].includes(n)))vm.eval(fs.readFileSync(path.join(root,'VGD_Dim',name+'.rb'),'utf8'));
  for(const [file,run] of [['test_engine.rb','run_engine_tests'],['test_native_style.rb','run_native_style_tests'],['test_core.rb','run_core_tests; run_service_tests'],['test_smartdim.rb','run_smartdim_tests']]){
    vm.eval(fs.readFileSync(path.join(__dirname,file),'utf8'));vm.eval(run+'; $stdout.flush');
  }
  const main=fs.readFileSync(path.join(root,'VGD_Dim/main.rb'),'utf8').replace(/^require[^\n]*\n/gm,'');
  vm.eval(main);vm.eval(main);
  vm.eval(`
    check(UI.toolbars.length==1 && UI.toolbars.first.events==[:add],'Toolbar duplicated')
    VGD::Dim.show_dialog
    dialog=VGD::Dim::Dialog.instance_variable_get(:@dlg)
    expected=%w[ready scan run rebuild smart_dim save_preset delete_preset set_auto anim_set dim_info text_info native_apply]
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
    puts 'PASS: complete callback wiring, one dialog/toolbar, native font-only color preservation, malformed JSON caught, no popups'
    $stdout.flush
  `);
})().catch(error=>{console.error(error);process.exitCode=1;});
