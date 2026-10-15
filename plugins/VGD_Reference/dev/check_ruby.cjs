const fs=require('fs'),path=require('path'),{WASI}=require('wasi');
const {resolve}=require('./dependencies.cjs');
const {RubyVM}=require(path.join(resolve('@ruby/wasm-wasi'),'dist/cjs/vm.js'));
(async()=>{
  const root=path.resolve(__dirname,'..'),runtime=path.join(root,'runtime');
  const wasm=await WebAssembly.compile(fs.readFileSync(path.join(resolve('@ruby/3.2-wasm-wasi'),'dist/ruby+stdlib.wasm')));
  const wasi=new WASI({version:'preview1',returnOnExit:true,preopens:{'/workspace':root}});
  const {vm}=await RubyVM.instantiateModule({module:wasm,wasip1:wasi});
  const files=[];
  function scan(folder){for(const entry of fs.readdirSync(folder,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))){const full=path.join(folder,entry.name);if(entry.isDirectory())scan(full);else if(entry.name.endsWith('.rb'))files.push(full);}}
  scan(runtime);
  for(const file of files){const source=fs.readFileSync(file,'utf8');vm.eval('RubyVM::InstructionSequence.compile('+JSON.stringify(source).replace(/#/g,'\\#')+')');console.log('Syntax OK:',path.relative(runtime,file));}
  for(const name of ['spike_overlay.rb','diagnose_rendering.rb','apply_render_fix.rb','su2022_tool_probe.rb']){
    const source=fs.readFileSync(path.join(__dirname,name),'utf8');
    vm.eval('RubyVM::InstructionSequence.compile('+JSON.stringify(source).replace(/#/g,'\\#')+')');
    console.log('Syntax OK: dev/'+name);
  }
  for(const file of ['vgd_reference/core/constants.rb','vgd_reference/core/reference_item.rb','vgd_reference/core/reference_store.rb','vgd_reference/viewport/hit_tester.rb','vgd_reference/tools/crop_controller.rb']){
    vm.eval(fs.readFileSync(path.join(runtime,file),'utf8'));
  }
  vm.eval(fs.readFileSync(path.join(runtime,'vgd_reference/viewport/texture_cache.rb'),'utf8'));
  vm.eval(fs.readFileSync(path.join(__dirname,'texture_cache_fixture.rb'),'utf8'));
  vm.eval(fs.readFileSync(path.join(__dirname,'core_fixture.rb'),'utf8'));
  vm.eval(fs.readFileSync(path.join(runtime,'vgd_reference/core/session.rb'),'utf8'));
  vm.eval(fs.readFileSync(path.join(__dirname,'view_api_fixture.rb'),'utf8'));
  vm.eval(fs.readFileSync(path.join(__dirname,'sketchup_draw_api_fixture.rb'),'utf8'));
  vm.eval(fs.readFileSync(path.join(runtime,'vgd_reference/core/compatibility.rb'),'utf8'));
  vm.eval(fs.readFileSync(path.join(__dirname,'compatibility_fixture.rb'),'utf8'));
  for(const file of ['vgd_reference/viewport/screen_coordinates.rb','vgd_reference/import/image_loader.rb','vgd_reference/viewport/reference_overlay.rb']){
    vm.eval(fs.readFileSync(path.join(runtime,file),'utf8'));
  }
  vm.eval(fs.readFileSync(path.join(__dirname,'render_regression_fixture.rb'),'utf8'));
  const iconSource=fs.readFileSync(path.join(runtime,'vgd_reference/ui/icons.rb'),'utf8');
  vm.eval('eval('+JSON.stringify(iconSource).replace(/#/g,'\\#')+", TOPLEVEL_BINDING, '/workspace/runtime/vgd_reference/ui/icons.rb')");
  vm.eval(fs.readFileSync(path.join(__dirname,'icon_fixture.rb'),'utf8'));
  vm.eval('$stdout.flush');
  console.log(`Compiled ${files.length} Ruby files and ran the pure-Ruby core fixture. SketchUp API calls still need in-app verification.`);
})().catch(error=>{console.error(error);process.exitCode=1;});
