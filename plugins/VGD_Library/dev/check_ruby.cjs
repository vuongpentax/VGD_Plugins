const fs = require('fs'), path = require('path'), { WASI } = require('wasi');
const { resolve } = require('./dependencies.cjs');
const { RubyVM } = require(path.join(resolve('@ruby/wasm-wasi'), 'dist/cjs/vm.js'));
(async () => {
  const root = path.resolve(__dirname, '..'), outputs = path.join(root, 'outputs'); fs.mkdirSync(outputs, { recursive: true });
  const temp = fs.mkdtempSync(path.join(outputs, 'ruby-'));
  const wasm = await WebAssembly.compile(fs.readFileSync(path.join(resolve('@ruby/3.2-wasm-wasi'), 'dist/ruby+stdlib.wasm')));
  const wasi = new WASI({ version: 'preview1', returnOnExit: true, preopens: { '/workspace': root, '/tmp': temp } });
  const { vm } = await RubyVM.instantiateModule({ module: wasm, wasip1: wasi });
  const files = ['vgd_library.rb', ...fs.readdirSync(path.join(root, 'runtime/vgd_library')).filter(f => f.endsWith('.rb')).map(f => 'vgd_library/' + f)];
  for (const file of files) { vm.eval('RubyVM::InstructionSequence.compile(' + JSON.stringify(fs.readFileSync(path.join(root, 'runtime', file), 'utf8')).replace(/#/g, '\\#') + ')'); console.log('Syntax OK:', file); }
  const fixture = fs.readFileSync(path.join(__dirname, 'test_engine.rb'), 'utf8').split("require '/workspace/runtime/vgd_library.rb'\nrequire '/workspace/runtime/vgd_library/main.rb'");
  vm.eval(fixture[0]);
  for (const file of ['vgd_library.rb', ...['catalog','materials','geometry','storage','models','pixels','advanced','tools','seamless','online','drive','shell_sync','update_notice','main'].map(name => `vgd_library/${name}.rb`)]) vm.eval(fs.readFileSync(path.join(root,'runtime',file),'utf8').replace(/^require_relative[^\n]*\n/gm,''));
  // eval has no real __FILE__; native require resolves this directory itself.
  vm.eval("VGD::Library.send(:remove_const, :ROOT); VGD::Library.const_set(:ROOT, '/workspace/runtime/vgd_library')");
  vm.eval(fixture[1]); vm.eval('$stdout.flush');
  vm.eval(fs.readFileSync(path.join(__dirname,'test_advanced.rb'),'utf8')); vm.eval('$stdout.flush');
  fs.mkdirSync(path.join(temp,'legacy/SketchUp/SketchUp 2022/SketchUp'),{recursive:true});
  try { vm.eval(fs.readFileSync(path.join(__dirname,'test_preferences_timers.rb'),'utf8')); }
  finally { vm.eval('$stdout.flush'); }
  try { vm.eval(fs.readFileSync(path.join(__dirname,'test_online_errors.rb'),'utf8')); }
  finally { vm.eval('$stdout.flush'); }
  // Actual ZIP structures verify the SKM central-directory and CRC reader.
  const JSZip=require(resolve('jszip')), thumbnailZip=new JSZip();
  const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLttAAAAABJRU5ErkJggg==','base64');
  thumbnailZip.file('Thumbnail.png',png); thumbnailZip.file('document.xml','<material/>');
  for(const compression of ['STORE','DEFLATE']) {
    const bytes=await thumbnailZip.generateAsync({type:'nodebuffer',compression});
    vm.eval(`File.binwrite('/tmp/test.skm', ['${bytes.toString('hex')}'].pack('H*')); thumb=VGD::Library::Storage.skm_thumbnail('/tmp/test.skm'); assert(thumb && thumb[0].unpack1('H*')=='${png.toString('hex')}' && thumb[1]=='.png', 'SKM ${compression} thumbnail extraction failed')`);
  }
  console.log('PASS: stored and deflated SKM ZIP thumbnail bytes and CRC.');
  if(process.env.VGD_VERIFY_LOCAL_PREFERENCES) {
    const nativePath=path.join(process.env.LOCALAPPDATA,'SketchUp/SketchUp 2022/SketchUp/PrivatePreferences.json');
    const saved=JSON.parse(fs.readFileSync(nativePath,'utf8').replace(/^\uFEFF/,''))['This Computer Only']?.VGD_Library;
    if(!saved) throw Error('Local VGD_Library preferences not found');
    let checked=0;
    for(const key of ['folders','online_sources','favorites','update_manifest']) {
      if(typeof saved[key]!=='string') continue;
      const hex=Buffer.from(saved[key],'utf8').toString('hex');
      const type=key==='update_manifest'?'String':'Array';
      vm.eval(`actual=VGD::Library::Catalog.decode_legacy(['${hex}'].pack('H*').force_encoding(Encoding::UTF_8)); assert(actual.is_a?(${type}), 'Local ${key} recovery failed')`);
      checked++;
    }
    console.log(`PASS: ${checked} actual SU2022 VGD preference fields recovered read-only; values not logged or changed.`);
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
