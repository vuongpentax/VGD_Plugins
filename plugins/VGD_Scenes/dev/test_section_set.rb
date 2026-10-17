# Section sets: standard scale choice, validation, one-step apply, metadata and failure behaviour.
s = VGD::Scenes
plan = s::ScalePlan
base = s.options('scale_mode' => 'auto', 'paper' => 'A3_L')

# --- Standard scale choice (inches in, millimetres on paper).
front = plan.for(1000.0 / 25.4, 800.0 / 25.4, 'FRONT', base)
assert(front['denominator'] == 5 && front['fits'], '1000x800 mm should be 1:5 on A3 landscape')
assert(near(front['camera_height'], 267.0 * 5 / 25.4) && near(front['aspect'], 390.0 / 267.0), 'Camera height/aspect do not match 1:5 paper area')
assert(plan.for(1000.0 / 25.4, 800.0 / 25.4, 'FRONT', base.merge('paper' => 'A4_P'))['denominator'] == 10, 'Smaller paper should choose 1:10')
assert(plan.for(20000.0 / 25.4, 800.0 / 25.4, 'TOP', base)['denominator'] == 75, 'Large object should use 1:75')
huge = plan.for(100000.0 / 25.4, 800.0 / 25.4, 'TOP', base)
assert(huge['denominator'] == 300 && !huge['fits'], 'Object beyond 1:200 must report it does not fit')
assert(plan.for(1.0, 1.0, 'FRONT', base.merge('scale_mode' => 'fixed', 'scale_denominator' => 20.0))['denominator'] == 20.0, 'Fixed scale ignored')
assert(plan.for(1.0, 1.0, 'FRONT', base.merge('scale_mode' => 'free')).nil?, 'Free mode must not use a scale')
assert(plan.for(1.0, 1.0, 'ISO', base).nil?, 'ISO view must never use a scale')
rejects('fixed needs denominator') { s.options('scale_mode' => 'fixed', 'scale_denominator' => 0) }
rejects('unknown scale mode') { s.options('scale_mode' => 'magic') }
rejects('margin too large') { plan.drawing_area(base.merge('paper_margin' => 100.0, 'paper' => 'A4_L')) }

# --- Validation of a set.
sets = s::SectionSet
good = { 'views' => %w[FRONT], 'sections' => [{ 'name' => 'A-A', 'axis' => 'Y', 'percent' => 50 }] }
assert(sets.normalize(good)['options']['width'] == 1068 && sets.normalize(good)['options']['height'] == 720, 'Frame must follow the A4 landscape printable area by default')
rejects('empty set') { sets.normalize('views' => [], 'sections' => []) }
rejects('bad axis') { sets.normalize('sections' => [{ 'name' => 'A', 'axis' => 'Q', 'percent' => 50 }]) }
rejects('percent out of range') { sets.normalize('sections' => [{ 'name' => 'A', 'axis' => 'X', 'percent' => 120 }]) }
rejects('blank name') { sets.normalize('sections' => [{ 'name' => ' ', 'axis' => 'X', 'percent' => 10 }]) }
rejects('duplicate names') { sets.normalize('sections' => [{ 'name' => 'A', 'axis' => 'X', 'percent' => 10 }, { 'name' => 'a', 'axis' => 'Y', 'percent' => 20 }]) }
rejects('bad view') { sets.normalize('views' => ['NOPE']) }
rejects('too many sections') { sets.normalize('sections' => (1..13).map { |i| { 'name' => "S#{i}", 'axis' => 'X', 'percent' => i } }) }
assert(sets.normalize(good.merge('options' => { 'width' => 5, 'grouping' => 'individual', 'paper' => 'A3_L' }))['options']['grouping'] == 'combined', 'Set must always treat the selection as one object')

# The dialog sends plain JSON: integers for numbers, string keys, a template with angle brackets.
ui_json = '{"preset":"wardrobe","views":["FRONT","ISO"],"sections":[{"name":"A-A","axis":"Y","percent":50,"flip":false}],'           '"options":{"paper":"A3_L","scale_mode":"fixed","scale_denominator":20,"project":"CT01","template":"<OBJECT>_<VIEW>","axis_mode":"local","isolate":true}}'
from_ui = sets.normalize(JSON.parse(ui_json))
assert(from_ui['options']['scale_mode'] == 'fixed' && from_ui['options']['scale_denominator'] == 20.0 && from_ui['options']['project'] == 'CT01', 'Dialog payload options lost')
assert(from_ui['views'] == %w[FRONT ISO] && from_ui['sections'].first['percent'] == 50.0, 'Dialog payload sections/views lost')

# --- Apply a whole set in one step.
m = Sketchup::Model.new; Sketchup.active_model = m
cabinet = product(m, 1000.0 / 25.4, 600.0 / 25.4, 800.0 / 25.4, 'Tủ quần áo')
m.selection.add(cabinet)
wardrobe = { 'preset' => 'wardrobe', 'views' => sets.presets['wardrobe']['views'], 'sections' => sets.presets['wardrobe']['sections'],
             'options' => { 'paper' => 'A3_L', 'scale_mode' => 'auto' } }
operations_before = m.operations; commits_before = m.commits
result = sets.apply(m, wardrobe)
assert(result[:success] && result[:ids].length == 7 && m.pages.length == 7, 'Wardrobe set should create 4 views and 3 sections')
assert(m.operations == operations_before + 1 && m.commits == commits_before + 1, 'A set must be one undoable operation')
roles = result[:scenes].map { |scene| scene[:role] }
assert(roles == %w[VIEW VIEW VIEW VIEW SECTION SECTION SECTION], "Unexpected scene order: #{roles}")
pages = result[:ids].map { |id| s::SceneStore.find(m, id) }
sheets = pages.map { |page| sets.sheet(page) }
assert(sheets.map { |sheet| sheet['order'] } == (1..7).to_a && sheets.all? { |sheet| sheet['set'] == 'wardrobe' }, 'Sheet metadata missing')
assert(sheets.map { |sheet| sheet['name'] } == %w[FRONT RIGHT TOP ISO A-A B-B C-C], 'Sheet names wrong')
front_page = pages[0]
front_scale = JSON.parse(front_page.get_attribute(s::DICT, 'scale'))
assert(front_scale['denominator'] == 5 && front_page.camera.height > 0 && !front_page.camera.perspective?, 'FRONT must be a parallel 1:5 view')
assert(near(front_page.camera.height, 267.0 * 5 / 25.4) && near(front_page.camera.aspect_ratio, 390.0 / 267.0), 'FRONT camera is not the exact 1:5 paper area')
assert(JSON.parse(pages[3].get_attribute(s::DICT, 'scale')).empty?, 'ISO view must have no scale')
assert(result[:scenes].find { |scene| scene[:name].include?('A-A') }[:scale] =~ /\A1:\d+\z/, 'Section scene lacks a scale label')
assert(result[:warnings].empty?, "Unexpected warnings: #{result[:warnings]}")

# --- Re-applying updates the same scenes.
again = sets.apply(m, wardrobe)
assert(m.pages.length == 7 && again[:ids].sort == result[:ids].sort, 'Applying a set twice must not duplicate scenes')

# --- A failure part-way aborts as one operation and does not leave nesting stuck.
aborts_before = m.aborts
original = s::SceneStore.method(:generate)
calls = 0
s::SceneStore.define_singleton_method(:generate) do |model, raw, section_only = false|
  calls += 1
  raise 'Simulated failure' if calls == 2
  original.call(model, raw, section_only)
end
begin
  sets.apply(m, wardrobe)
  raise 'Failure was swallowed'
rescue RuntimeError => error
  assert(error.message == 'Simulated failure' && m.aborts == aborts_before + 1, 'Failure did not abort the whole set')
end
s::SceneStore.define_singleton_method(:generate, original)
ops = m.operations
s.operation(m, 'after failure') { :ok }
assert(m.operations == ops + 1, 'Operation nesting stayed stuck after a failure')

# --- The dialog command reaches SectionSet through the main dispatcher.
dm = Sketchup::Model.new; Sketchup.active_model = dm
dm.selection.add(product(dm, 1000.0 / 25.4, 600.0 / 25.4, 800.0 / 25.4, 'Tủ'))
dispatched = s.dispatch('sectionSet', { 'model' => dm.object_id.to_s, 'settings' => JSON.parse(ui_json) })
assert(dispatched[:success] && dm.pages.length == 3, 'sectionSet action should create 2 views and 1 section')
dispatched_front = dm.pages.find { |page| page.name.include?('FRONT') }
assert(JSON.parse(dispatched_front.get_attribute(s::DICT, 'scale')).fetch('denominator') == 20.0, 'Fixed 1:20 was not applied to the FRONT scene')
pages_before = dm.pages.length
stale = s.dispatch('sectionSet', { 'model' => 'old', 'settings' => JSON.parse(ui_json) })
assert(stale[:success] == false && dm.pages.length == pages_before, 'A stale model id must be refused and create no scenes')

# --- Oversized object reports a warning instead of failing.
big = Sketchup::Model.new; Sketchup.active_model = big
tower = product(big, 100000.0 / 25.4, 600.0 / 25.4, 800.0 / 25.4, 'Dài')
big.selection.add(tower)
oversize = sets.apply(big, 'views' => %w[FRONT], 'options' => { 'paper' => 'A3_L' })
assert(oversize[:success] && oversize[:warnings].length == 1, 'Oversized view should warn, not fail')
puts 'PASS: section sets — standard scale per paper, validation, one-step apply with sheet metadata, re-apply, atomic failure, oversize warning'
