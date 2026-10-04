const fs = require('fs'), path = require('path');
const deps = path.resolve(__dirname, '../../TPlus_Cabinet_Codex_Handoff_2026-10-01/cabinet_dev/node_modules');
const {DefaultRubyVM} = require(path.join(deps, '@ruby/wasm-wasi/dist/cjs/node.js'));
(async () => {
  const wasm = await WebAssembly.compile(fs.readFileSync(require.resolve(path.join(deps, '@ruby/3.2-wasm-wasi/dist/ruby+stdlib.wasm'))));
  const {vm} = await DefaultRubyVM(wasm);
  const root = path.resolve(__dirname, '../runtime');
  const runtime = ['vgd_dim.rb', ...['defaults','engine','native_style','main','reload'].map(n=>'VGD_Dim/'+n+'.rb')];
  const literal = value => JSON.stringify(Buffer.from(value, 'utf8').toString('base64')) + '.unpack1("m0")';
  for (const file of runtime) {
    vm.eval('RubyVM::InstructionSequence.compile(' + literal(fs.readFileSync(path.join(root, file), 'utf8')) + ')');
    console.log('Syntax OK:', file);
  }
  vm.eval('RubyVM::InstructionSequence.compile(' + literal(fs.readFileSync(path.join(__dirname,'native_smoke.rb'),'utf8')) + ')');
  console.log('Syntax OK: opt-in native smoke script (not executed)');
  vm.eval(fs.readFileSync(path.join(__dirname, 'test_fixture.rb'), 'utf8'));
  for (const name of ['defaults','engine','native_style']) vm.eval(fs.readFileSync(path.join(root,'VGD_Dim',name+'.rb'),'utf8'));
  vm.eval(fs.readFileSync(path.join(__dirname, 'test_engine.rb'), 'utf8'));
  vm.eval('run_engine_tests; $stdout.flush');
  vm.eval(fs.readFileSync(path.join(__dirname, 'test_native_style.rb'), 'utf8'));
  vm.eval('run_native_style_tests; $stdout.flush');
  const main = fs.readFileSync(path.join(root,'VGD_Dim/main.rb'),'utf8').replace(/^require[^\n]*\n/gm,'');
  vm.eval(main); vm.eval(main);
  vm.eval(`
    raise "Toolbar duplicated/moved" unless UI.toolbars.length == 1 && UI.toolbars.first.events == [:add]
    VGD::Dim.show_dialog
    dialog = VGD::Dim.instance_variable_get(:@dialog)
    raise "Callbacks wrong" unless dialog.callbacks.keys.sort == %w[apply cancel dim_info text_info].sort
    VGD::Dim.show_dialog
    raise "Duplicate dialog" unless VGD::Dim.instance_variable_get(:@dialog).equal?(dialog) && dialog.fronts == 1
    m = Sketchup::FakeModel.new
    Sketchup.active_model = m
    dim = Sketchup::DimensionLinear.new
    text = Sketchup::Text.new
    m.entities << dim; m.entities << text
    m.selection.add(dim)
    VGD::Dim::NativeStyle.adapter = FakeStyleAdapter.new
    UI.info_result = true
    before = UI.messages.to_a.length
    dialog.callbacks['apply'].call(nil, '{}')
    UI.drain
    raise "Callback scope wrong" unless m.commits == 1 && dim.layer == '000 DIM' && text.layer.nil?
    raise "Completion popup" unless UI.messages.to_a.length == before
    selection_before = m.selection.to_a
    UI.info_pages = []
    dialog.callbacks['dim_info'].call(nil)
    dialog.callbacks['text_info'].call(nil)
    raise "Model Info route wrong" unless UI.info_pages == ['Dimensions','Text'] && m.selection.to_a == selection_before
    UI.info_result = false
    dialog.callbacks['dim_info'].call(nil)
    raise "Failed Model Info ignored" unless dialog.scripts.last.include?('Model Info')
    dialog.callbacks['apply'].call(nil, 'bad json')
    raise "Malformed input mutated" unless m.operations == 1 && dialog.scripts.last.start_with?('VGDForm.error')
    raise "Error popup" unless UI.messages.to_a.length == before
    dialog.callbacks['cancel'].call(nil)
    raise "Dialog retained" unless VGD::Dim.instance_variable_get(:@dialog).nil?
    m.selection.clear
    VGD::Dim.apply_payload('{}')
    raise "Standalone status fallback failed" unless Sketchup.status_text.include?('chọn')
    puts "PASS: one toolbar/dialog, Model Info callbacks, async busy state, silent success, inline errors/status fallback"
    $stdout.flush
  `);
})().catch(error => {console.error(error); process.exitCode = 1;});
