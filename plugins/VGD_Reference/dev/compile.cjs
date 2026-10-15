// Compile source only; this does not execute runtime code or regression fixtures.
const fs=require('fs'),path=require('path'),vmJS=require('vm'),{WASI}=require('wasi');
const {resolve}=require('./dependencies.cjs');
const {RubyVM}=require(path.join(resolve('@ruby/wasm-wasi'),'dist/cjs/vm.js'));
(async()=>{
  const root=path.resolve(__dirname,'..'),runtime=path.join(root,'runtime'),files=[];
  function scan(folder){for(const item of fs.readdirSync(folder,{withFileTypes:true})){const file=path.join(folder,item.name);if(item.isDirectory())scan(file);else if(/\.(rb|js)$/.test(item.name))files.push(file);}}
  scan(runtime);
  const wasm=await WebAssembly.compile(fs.readFileSync(path.join(resolve('@ruby/3.2-wasm-wasi'),'dist/ruby+stdlib.wasm')));
  const wasi=new WASI({version:'preview1',returnOnExit:true,preopens:{'/workspace':root}});
  const {vm}=await RubyVM.instantiateModule({module:wasm,wasip1:wasi});
  for(const file of files){
    const source=fs.readFileSync(file,'utf8');
    if(file.endsWith('.rb'))vm.eval('RubyVM::InstructionSequence.compile('+JSON.stringify(source).replace(/#/g,'\\#')+')');
    else new vmJS.Script(source,{filename:file});
  }
  console.log(`Compiled syntax: ${files.filter(f=>f.endsWith('.rb')).length} Ruby and ${files.filter(f=>f.endsWith('.js')).length} JavaScript runtime files. No tests/runtime code executed.`);
})().then(()=>process.exit(0)).catch(error=>{console.error(error);process.exit(1);});
