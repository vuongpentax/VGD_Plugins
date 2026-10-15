const fs = require('fs'), path = require('path'), { WASI } = require('wasi');
const { resolve } = require('./dependencies.cjs');
const { RubyVM } = require(path.join(resolve('@ruby/wasm-wasi'), 'dist/cjs/vm.js'));
(async () => {
  const root = path.resolve(__dirname, '..'), outputs = path.join(root, 'outputs');
  fs.mkdirSync(outputs, { recursive: true });
  const temp = fs.mkdtempSync(path.join(outputs, 'ruby-'));
  const wasm = await WebAssembly.compile(fs.readFileSync(path.join(resolve('@ruby/3.2-wasm-wasi'), 'dist/ruby+stdlib.wasm')));
  const wasi = new WASI({ version: 'preview1', returnOnExit: true, preopens: { '/workspace': root, '/tmp': temp } });
  const { vm } = await RubyVM.instantiateModule({ module: wasm, wasip1: wasi });
  const files = ['vgd_image_importer.rb', ...['engine','file_picker','conversion','update_notice','main'].map(name=>'vgd_image_importer/'+name+'.rb')];
  for (const file of files) {
    vm.eval('RubyVM::InstructionSequence.compile(' + JSON.stringify(fs.readFileSync(path.join(root, 'runtime', file), 'utf8')).replace(/#/g, '\\#') + ')');
    console.log('Syntax OK:', file);
  }
  vm.eval('RubyVM::InstructionSequence.compile(' + JSON.stringify(fs.readFileSync(path.join(__dirname,'native_smoke.rb'),'utf8')).replace(/#/g,'\\#') + ')');
  vm.eval(fs.readFileSync(path.join(__dirname, 'fixture.rb'), 'utf8'));
  for (const file of files) vm.eval(fs.readFileSync(path.join(root, 'runtime', file), 'utf8').replace(/^require(?:_relative)? [^\n]*\n/gm, ''));
  vm.eval("raise 'Prerelease numeric comparison failed' unless VGD::UpdateNotice.newer?('1.1.0-beta.10','1.1.0-beta.2'); raise 'Stable release comparison failed' unless VGD::UpdateNotice.newer?('1.1.0','1.1.0-beta.3'); raise 'Same version comparison failed' if VGD::UpdateNotice.newer?('1.1.0-beta.2','1.1.0-beta.2'); puts 'PASS: updater version ordering for beta numbers and stable releases.'");
  vm.eval(fs.readFileSync(path.join(__dirname, 'test_engine.rb'), 'utf8'));
  vm.eval('$stdout.flush');
})().catch(error => { console.error(error); process.exitCode = 1; });
