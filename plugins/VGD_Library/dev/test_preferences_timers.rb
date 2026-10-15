# Regression tests for the two native SU2022 failures reported on 05/10/2026.
module Sketchup
  class << self
    alias_method :read_default_before_regression, :read_default
    alias_method :write_default_before_regression, :write_default
    attr_accessor :regression_defaults, :legacy_reads
    def read_default(section, key, fallback = nil)
      @legacy_reads << key unless key.start_with?('json2_')
      raw = @regression_defaults[[section, key]]
      # Replicate SU2022's quoted-literal read; input is fixed test data only.
      raw.nil? ? fallback : eval(raw)
    end
    def write_default(section, key, value)
      @regression_defaults[[section, key]] = '"' + value + '"'
      true
    end
  end
end
Sketchup.regression_defaults = {}
Sketchup.legacy_reads = []
previous_localappdata = ENV['LOCALAPPDATA']
ENV['LOCALAPPDATA'] = '/tmp/legacy'
catalog = VGD::Library::Catalog
folder = 'G:/Other computers/My Computer/00 BO CAI HE THONG/02 SU/03 MTL'
legacy_sources = [{'url'=>'https://drive.google.com/drive/folders/example-folder'}]
legacy = {'folders'=>'"'+JSON.generate([folder])+'"',
          'online_sources'=>'"'+JSON.generate(legacy_sources)+'"',
          'favorites'=>'"'+JSON.generate(['favorite-id'])+'"',
          'update_manifest'=>'"https://example.test/catalog.json"'}
legacy.each { |key, value| Sketchup.regression_defaults[[catalog::SECTION, key]] = value }
File.binwrite('/tmp/legacy/SketchUp/SketchUp 2022/SketchUp/PrivatePreferences.json',
              JSON.generate({'This Computer Only'=>{catalog::SECTION=>legacy}}))
begin
  Sketchup.read_default(catalog::SECTION, 'folders', nil)
  raise 'Fixture did not reproduce the reported SyntaxError'
rescue SyntaxError
end
Sketchup.legacy_reads.clear
assert(catalog.roots==[folder], 'Broken quoted legacy folders were not recovered')
assert(VGD::Library::Online.sources==legacy_sources, 'Legacy online sources were lost')
assert(catalog.favorites==['favorite-id'], 'Legacy favorites were lost')
assert(catalog.read_json('update_manifest','')=='https://example.test/catalog.json', 'Legacy update URL not recovered')
assert(Sketchup.legacy_reads.empty?, 'Migration evaluated the broken legacy strings')
unicode = ['C:/Gỗ "Sồi"/#1', 'C:\\Maps\\Đá', %q(C:/#{raise 'do not execute'})]
catalog.save('folders',unicode)
10.times { assert(catalog.roots==unicode, 'Encoded preferences lost Unicode/quotes/backslashes') }
assert(Sketchup.regression_defaults[[catalog::SECTION,'json2_folders']].match?(/\A"vgd-json2:[A-Za-z0-9+\/=]+"\z/), 'Unsafe characters in persisted preferences')
assert(catalog.decode_legacy(JSON.generate(JSON.generate(unicode)))==unicode, 'Escaped nested JSON migration failed')
Sketchup.regression_defaults[[catalog::SECTION,'json2_broken']] = '"vgd-json2:%%%"'
assert(catalog.read_json('broken',[])==[], 'Corrupt encoded preference should use fallback')
ENV['LOCALAPPDATA'] = previous_localappdata
Sketchup.singleton_class.alias_method :read_default, :read_default_before_regression
Sketchup.singleton_class.alias_method :write_default, :write_default_before_regression
puts 'PASS: reproduced native quoted-JSON SyntaxError; recovered folders/online/favorites/update URL without eval; safe Unicode/quotes/backslashes roundtrip.'

module UI
  class << self
    attr_reader :regression_timers, :picker_calls
    def start_timer(seconds, repeat = false, &block)
      @regression_timers ||= {}
      id = (@regression_timers.keys.max || 0) + 1
      @regression_timers[id] = {active:true, block:block, repeat:repeat, seconds:seconds}
      id
    end
    def stop_timer(id)
      @regression_timers[id][:active] = false if @regression_timers[id]
    end
    def fire_timer(id, queued = false)
      timer = @regression_timers[id]
      return unless timer && (timer[:active] || queued)
      previous, @current_timer = @current_timer, id
      timer[:block].call
    ensure
      @current_timer = previous
    end
    def select_directory(**)
      @picker_calls = (@picker_calls || 0) + 1
      raise 'Local folder picker reopened recursively' if @picker_calls > 1
      # Deliver another native callback while the modal picker is still open,
      # even though stop_timer was called. The fired guard must reject it.
      fire_timer(@current_timer, true)
      '/fixture/library'
    end
  end
end
class RegressionDialog
  attr_reader :scripts
  def initialize; @scripts=[]; end
  def execute_script(script); @scripts << script; end
end
# WASI cannot resume native Enumerator fibers with #next. Consume the real
# production traversal with #to_a, then feed its entries to the native timer
# orchestration without a fiber. SketchUp itself supports Enumerator#next.
class RegressionScanner
  def initialize(items); @items=items; @index=0; end
  def next
    raise StopIteration if @index>=@items.size
    value=@items[@index]
    @index+=1
    value
  end
end
catalog.singleton_class.alias_method :scan_before_regression, :scan
def catalog.scan
  RegressionScanner.new(scan_before_regression.to_a)
end
library = VGD::Library
regression_materials = Sketchup.active_model.materials
def regression_materials.current; nil; end
catalog.save('folders',[])
catalog.save('online_sources',[])
dialog = RegressionDialog.new
library.instance_variable_set(:@dialog,dialog)
timer = library.defer { library.dispatch('add_folder','{}') }
UI.fire_timer(timer)
3.times { UI.fire_timer(timer,true) }
assert(UI.picker_calls==1 && !UI.regression_timers[timer][:active], 'Deferred picker callback repeated')
assert(catalog.roots==['/fixture/library'], 'Picker did not add the local source')
scan_timer = library.instance_variable_get(:@scan_timer)
UI.fire_timer(scan_timer)
assert(!UI.regression_timers[scan_timer][:active] && library.instance_variable_get(:@scan_timer).nil?, 'Completed scan did not stop its timer')

class RegressionFailedScanner
  def next; raise SyntaxError, 'reported scanner failure'; end
end
def catalog.scan
  RegressionFailedScanner.new
end
library.scan
failed_timer = library.instance_variable_get(:@scan_timer)
UI.fire_timer(failed_timer)
scripts_after_failure = dialog.scripts.size
3.times { UI.fire_timer(failed_timer,true) }
assert(library.instance_variable_get(:@scan_timer).nil? && !UI.regression_timers[failed_timer][:active], 'Failed scan kept running')
assert(dialog.scripts.size==scripts_after_failure, 'Failed scan repeated its error')
assert(dialog.scripts.any? { |script| script.include?('window.VGD.append([], true,') }, 'Scan error left UI loading forever')
catalog.singleton_class.alias_method :scan, :scan_before_regression
# Older queued scan callbacks must not modify a replacement scan.
library.scan
old_timer = library.instance_variable_get(:@scan_timer)
library.scan
new_timer = library.instance_variable_get(:@scan_timer)
before = dialog.scripts.size
UI.fire_timer(old_timer,true)
assert(dialog.scripts.size==before && UI.regression_timers[new_timer][:active], 'Stale scan callback touched the replacement scan')
library.stop_scan
library.instance_variable_set(:@dialog,nil)
puts 'PASS: modal local picker executes once despite reentrant/queued native callbacks; completed/failed/stale scans stop safely.'
