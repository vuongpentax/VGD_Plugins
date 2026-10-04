# SU2022 preference regression. eval below models the native API on fixed
# fixture strings only; production Store never evaluates legacy preference data.
def run_store_tests
  store = VGD::Dim::Store
  settings = {'dim'=>{'arrow'=>'slash'}, 'text'=>{'color'=>'#112233'}}
  legacy = {
    'auto'=>'"'+JSON.generate({'enabled'=>true,'settings'=>settings})+'"',
    'smartdim'=>'"'+JSON.generate({'mode'=>'chain','offset'=>120})+'"',
    'presets'=>'"'+JSON.generate({'Gỗ "Sồi"'=>settings, %q(#{raise 'do not execute'})=>settings})+'"'
  }
  prefs_file = '/fixture/local/SketchUp/SketchUp 2022/SketchUp/PrivatePreferences.json'
  native_file = "\uFEFF" + JSON.generate({'This Computer Only'=>{'VGDDim'=>legacy,'OtherPlugin'=>{'auto'=>'leave alone'}}})
  old_localappdata = ENV['LOCALAPPDATA']
  ENV['LOCALAPPDATA'] = '/fixture/local'
  calls = []
  literals = legacy.to_h { |key,value| [[store::SECTION,key],value] }
  fail_write = false
  sketchup_singleton = Sketchup.singleton_class
  %i[read_default write_default platform].each { |name| sketchup_singleton.alias_method("#{name}_before_store_test",name) }
  had_version = Sketchup.respond_to?(:version)
  sketchup_singleton.alias_method(:version_before_store_test,:version) if had_version
  Sketchup.define_singleton_method(:version) { '22.0.354' }
  Sketchup.define_singleton_method(:platform) { :platform_win }
  Sketchup.define_singleton_method(:read_default) do |section,key,fallback=nil|
    calls << key
    raw = literals[[section,key]]
    raw.nil? ? fallback : eval(raw)
  end
  Sketchup.define_singleton_method(:write_default) do |section,key,value|
    next false if fail_write
    literals[[section,key]] = '"'+value+'"'
    true
  end
  File.singleton_class.alias_method(:file_before_store_test,:file?)
  File.singleton_class.alias_method(:read_before_store_test,:read)
  File.define_singleton_method(:file?) { |path| path==prefs_file || file_before_store_test(path) }
  File.define_singleton_method(:read) do |path,*args,**kwargs|
    path==prefs_file ? native_file : read_before_store_test(path,*args,**kwargs)
  end
  begin
    begin
      Sketchup.read_default(store::SECTION,'auto',nil)
      raise 'Fixture did not reproduce native quoted-JSON SyntaxError'
    rescue SyntaxError
    end
    calls.clear
    check(store.read('auto',{})=={'enabled'=>true,'settings'=>settings}, 'Auto settings lost during migration')
    check(store.read('smartdim',{})=={'mode'=>'chain','offset'=>120}, 'Smart Dim options lost during migration')
    check(VGD::Dim::Presets.all['Gỗ "Sồi"']['dim']['arrow']=='slash', 'Unicode preset lost during migration')
    check(calls.all? { |key| key.start_with?('json2_') }, 'Broken legacy preference was evaluated during recovery')
    VGD::Dim::AutoStyle.start
    check(VGD::Dim::AutoStyle.load['enabled'] && VGD::Dim::AutoStyle.load['settings']['dim']['arrow']=='slash', 'Startup did not recover enabled Auto-Style')
    VGD::Dim::AutoStyle.shutdown
    values = [{'name'=>'Đá "A"','path'=>'C:\\Maps\\Gỗ', 'literal'=>%q(#{raise 'do not execute'})}, [1,'Việt'], true, false, nil, 'plain', '{"literal":"JSON-looking string"}']
    values.each_with_index do |value,index|
      key = "roundtrip_#{index}"
      store.write(key,value)
      check(store.read(key,:missing)==value, 'Safe encoded preferences lost JSON type/Unicode/quotes/backslashes')
      check(literals[[store::SECTION,'json2_'+key]].match?(/\A"vgd-dim-json2:[A-Za-z0-9+\/=]+"\z/), 'Unsafe quoted-literal characters persisted')
      quoted = '"'+JSON.generate(value)+'"'
      check(store.decode_legacy(quoted)==value, 'Legacy JSON type not preserved')
      check(store.decode_legacy(JSON.generate(JSON.generate(value)))==value, 'Escaped native literal not recovered')
    end
    check(store.read('missing',:fallback)==:fallback, 'Missing key lost fallback')
    native_file = JSON.generate({'This Computer Only'=>{'VGDDim'=>{'auto'=>'"{bad data}"'}}})
    literals[[store::SECTION,'json2_auto']] = '"vgd-dim-json2:%%%"'
    VGD::Dim::AutoStyle.start
    check(!VGD::Dim::AutoStyle.load['enabled'], 'Corrupt encoded Auto-Style should default to disabled')
    VGD::Dim::AutoStyle.shutdown
    literals.delete([store::SECTION,'json2_auto'])
    native_file = '{broken native preferences'
    VGD::Dim::AutoStyle.start
    check(!VGD::Dim::AutoStyle.load['enabled'], 'Unreadable file/native SyntaxError blocked startup')
    VGD::Dim::AutoStyle.shutdown
    fail_write = true
    before = literals.dup
    begin
      store.write('auto',{'enabled'=>true}); raise 'Failed preference write was silently accepted'
    rescue RuntimeError => error
      check(error.message=='Không lưu được cấu hình VGD Dim.' && literals==before, 'Write failure changed prior preferences')
    end
  ensure
    VGD::Dim::AutoStyle.shutdown
    %i[read_default write_default platform].each { |name| sketchup_singleton.alias_method(name,"#{name}_before_store_test") }
    had_version ? sketchup_singleton.alias_method(:version,:version_before_store_test) : sketchup_singleton.remove_method(:version)
    File.singleton_class.alias_method(:file?,:file_before_store_test)
    File.singleton_class.alias_method(:read,:read_before_store_test)
    ENV['LOCALAPPDATA'] = old_localappdata
  end
  puts 'PASS: reproduced SU2022 JSON SyntaxError; recovered Auto/Smart Dim/Unicode presets from native file without eval; Base64 typed roundtrip; corrupt preferences start with Auto off; failed write preserves prior data'
end
