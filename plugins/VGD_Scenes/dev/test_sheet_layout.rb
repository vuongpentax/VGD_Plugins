# Sheet layout: shared scale, packing, pages, reserved title-block band, per-item scale, reading scene sizes.
s = VGD::Scenes
layout = s::SheetLayout

def item(id, w, h, extra = {})
  { 'id' => id.to_s, 'name' => "S#{id}", 'role' => 'VIEW', 'label' => "S#{id}", 'extent_mm' => [w.to_f, h.to_f] }.merge(extra)
end

def overlap?(a, b)
  a['x'] < b['x'] + b['w'] - 1e-6 && b['x'] < a['x'] + a['w'] - 1e-6 && a['y'] < b['y'] + b['h'] - 1e-6 && b['y'] < a['y'] + a['h'] - 1e-6
end

base = s.options('paper' => 'A3_L', 'paper_margin' => 15.0)
area_w, area_h = s::ScalePlan.drawing_area(base)

# --- A wardrobe-like set fits one sheet at one shared standard scale.
wardrobe = [item(1, 1000, 800), item(2, 600, 800), item(3, 1000, 600), item(4, 1400, 1100), item(5, 1000, 800), item(6, 600, 800), item(7, 1000, 600)]
plan = layout.plan(wardrobe, base.merge('scale_mode' => 'auto'))
assert(plan['sheets'].length == 1 && s::ScalePlan::STANDARD.include?(plan['denominator'].to_i), "Wardrobe should fit one sheet at a standard scale: #{plan['denominator']}")
placed = plan['sheets'].first
assert(placed.length == 7 && placed.map { |entry| entry['scale'] }.uniq == [plan['denominator']], 'All views must share the scale')
placed.each do |entry|
  assert(entry['x'] >= 15 - 1e-6 && entry['y'] >= 15 - 1e-6 && entry['x'] + entry['w'] <= 15 + area_w + 1e-6 && entry['y'] + entry['h'] <= 15 + area_h + 1e-6, "#{entry['name']} sticks out of the printable area")
end
placed.combination(2).each { |a, b| assert(!overlap?(a, b), "#{a['name']} overlaps #{b['name']}") }
# The chosen scale is the smallest standard scale that gives one page.
smaller = s::ScalePlan::STANDARD.select { |d| d < plan['denominator'] }.last
if smaller
  tighter = layout.plan(wardrobe, base.merge('scale_mode' => 'fixed', 'scale_denominator' => smaller.to_f))
  assert(tighter['sheets'].length > 1 || tighter['warnings'].any?, "A larger scale (1:#{smaller}) would also have fit one sheet")
end

# --- Size on paper = (extent + 2 * dimension room) / scale.
single = layout.plan([item(1, 1000, 800)], base.merge('scale_mode' => 'fixed', 'scale_denominator' => 10.0))
entry = single['sheets'].first.first
assert(near(entry['w'], (1000 + 900) / 10.0) && near(entry['h'], (800 + 900) / 10.0), "Viewport size wrong: #{entry['w']} x #{entry['h']}")

# --- Too many for one page at a fixed scale: more pages, same scale, nothing lost.
many = (1..14).map { |i| item(i, 1000, 800) }
multi = layout.plan(many, base.merge('scale_mode' => 'fixed', 'scale_denominator' => 10.0))
assert(multi['sheets'].length > 1 && multi['sheets'].flatten.length == 14, 'Overflow must go to extra pages without dropping scenes')
assert(multi['warnings'].any? { |warning| warning.include?('trang') }, 'Extra pages must be reported')
assert(multi['sheets'].each_with_index.all? { |sheet, index| sheet.all? { |entry| entry['sheet'] == index + 1 } }, 'Sheet numbers wrong')
multi['sheets'].each { |sheet| sheet.combination(2).each { |a, b| assert(!overlap?(a, b), 'Overlap on a multi-page layout') } }

# --- A title-block band is kept free.
reserved = layout.plan(wardrobe, base.merge('scale_mode' => 'auto', 'reserve_bottom_mm' => 60.0))
reserved['sheets'].flatten.each { |entry| assert(entry['y'] + entry['h'] <= 15 + area_h - 60 + 1e-6, "#{entry['name']} enters the title block band") }
rejects('band too tall') { layout.plan(wardrobe, base.merge('reserve_bottom_mm' => 400.0)) }

# --- A per-item scale is kept; the others share the computed one.
mixed = layout.plan([item(1, 1000, 800, 'scale' => 5.0), item(2, 600, 800)], base.merge('scale_mode' => 'auto'))
by_name = mixed['sheets'].flatten.each_with_object({}) { |entry, hash| hash[entry['name']] = entry }
assert(by_name['S1']['scale'] == 5.0 && near(by_name['S1']['w'], 1900 / 5.0), 'Per-scene scale ignored')
assert(by_name['S2']['scale'] == mixed['denominator'], 'Other scenes must use the shared scale')

# --- An object that fits no standard scale is placed anyway, with a warning.
huge = layout.plan([item(1, 200_000, 800)], base.merge('scale_mode' => 'auto'))
assert(huge['sheets'].flatten.length == 1 && huge['warnings'].any? { |warning| warning.include?('không vừa') }, 'Oversize must warn')

# --- Inputs are checked.
rejects('no scenes') { layout.plan([], base) }
rejects('fixed without denominator') { layout.plan(wardrobe, base.merge('scale_mode' => 'fixed', 'scale_denominator' => 0.0)) }

# --- A2/A1 paper exists for large workshop drawings.
a1 = s.options('paper' => 'A1_L', 'scale_mode' => 'auto')
assert(s::ScalePlan.drawing_area(a1) == [811.0, 564.0], 'A1 landscape printable area wrong')

# --- Reading sizes from real scenes created by a set.
m = Sketchup::Model.new; Sketchup.active_model = m
m.selection.add(product(m, 1000.0 / 25.4, 600.0 / 25.4, 800.0 / 25.4, 'Tủ'))
result = s::SectionSet.apply(m, 'views' => %w[FRONT TOP ISO], 'sections' => [{ 'name' => 'A-A', 'axis' => 'Y', 'percent' => 50 }], 'options' => { 'paper' => 'A3_L' })
items = layout.items(m, result[:ids])
assert(items.length == 4 && items.map { |entry| entry['label'] } == %w[FRONT TOP ISO A-A], "Scene items wrong: #{items.map { |e| e['label'] }}")
assert(items.map { |entry| entry['role'] } == %w[VIEW VIEW VIEW SECTION], 'Scene roles wrong')
assert((items[0]['extent_mm'][0] - 1000).abs < 0.2 && (items[1]['extent_mm'][1] - 600).abs < 0.2, 'Scene sizes must be the object size in the view plane')
real = layout.plan(items, s.options('paper' => 'A3_L', 'scale_mode' => 'auto'))
assert(real['sheets'].flatten.length == 4, 'Real scenes must all be placed')
foreign = m.pages.add('Foreign scene')
rejects('scene without a recorded size') { layout.items(m, [foreign.persistent_id.to_s]) }
rejects('no ids') { layout.items(m, []) }
# --- A plan edited in the dialog is checked and rebuilt from the model.
module VGD::Scenes; module SheetBuilder; end; end unless defined?(VGD::Scenes::SheetBuilder)
unless VGD::Scenes::SheetBuilder.const_defined?(:PAPER_MM)
  VGD::Scenes::SheetBuilder.const_set(:PAPER_MM, { 'A3_L' => [420.0, 297.0] })
end
good = real.merge('sheets' => real['sheets'].map { |sheet| sheet.map { |entry| entry.merge('name' => 'forged') } })
clean = layout.sanitize(m, good)
assert(clean['sheets'].flatten.map { |entry| entry['name'] } == items.map { |entry| entry['name'] }, 'Names must come from the model, not the dialog')
assert(clean['sheets'].flatten.all? { |entry| entry['x'].is_a?(Float) && entry['scale'] > 0 }, 'Numbers must be rebuilt as floats')
moved = good.merge('sheets' => [good['sheets'][0].each_with_index.map { |entry, i| i.zero? ? entry.merge('x' => 400.0) : entry }])
rejects('box outside the paper') { layout.sanitize(m, moved) }
rejects('missing scene') { layout.sanitize(m, good.merge('sheets' => [[good['sheets'][0][0].merge('id' => '999999')]])) }
rejects('bad scale') { layout.sanitize(m, good.merge('sheets' => [[good['sheets'][0][0].merge('scale' => 0)]])) }
rejects('nan position') { layout.sanitize(m, good.merge('sheets' => [[good['sheets'][0][0].merge('x' => 'abc')]])) }
rejects('duplicate scene') { layout.sanitize(m, good.merge('sheets' => [[good['sheets'][0][0], good['sheets'][0][0]]])) }
rejects('unknown paper') { layout.sanitize(m, good.merge('paper' => 'A0')) }
rejects('no sheets') { layout.sanitize(m, good.merge('sheets' => [])) }
rejects('not a plan') { layout.sanitize(m, 'x') }
puts 'PASS: sheet layout — shared standard scale, packing, extra pages, title-block band, per-scene scale, oversize warning, real scene sizes'
