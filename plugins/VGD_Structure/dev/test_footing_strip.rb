# Test móng băng, loại móng riêng từng cột, móng giật cấp (H4: core/levels.rb footing!, core/footing_plan.rb, footing_builder.rb, preview, dựng tất cả)
# bằng SketchUp giả lập: dữ liệu tùy chọn chỉ lưu khi có, kích thước theo loại gán, bậc trên đặt trên bậc dưới (không trùng thể tích),
# móng băng dưới tường trừ phần trong đế cột (không chồng khối), dữ liệu BIM, một bước hoàn tác.
# Chạy: ruby dev/test_footing_strip.rb (phần dựng thật chưa xác minh trong SketchUp)
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
files = File.read(File.join(ROOT, 'loader.rb'))[/FILES = %w\[(.*?)\]/m, 1].split - %w[su_tools panel su_scan su_section edit_sync]
files.each { |f| require File.join(ROOT, f) }
S = VGD::Structure
D = S::Schema::DICTIONARY
L1 = 'sl_00000001'
BASE = {'l' => 1200, 'w' => 1200, 'h' => 400}.freeze
def state_with(footing, columns: true, walls: false)
  st = S::State.default
  st['levels'][0]['footing'] = footing
  st['levels'][0]['picks']['columns'] = columns ? S::Grid.intersections(st['grid']).each_with_object({}) { |i, h| h[i[:ref]] = {} } : {}
  st['levels'][0]['picks']['walls'] = S::Grid.spans(st['grid']).select { |s| s[:side] }.each_with_object({}) { |s, h| h[s[:ref]] = {} } if walls
  st
end
def norm(st); S::State.normalize!(st); end
def plan_of(st); n = norm(st); S::FootingPlan.plan(n['grid'], n['types'], n['levels'], L1, n['beam_types'], n['wall_types'], n['opening_types']); end
def footing_of(f); norm(state_with(f))['levels'][0]['footing']; end
bad = ->(f) { error_of { norm(state_with(f)) }.to_s }
# Hai khối chồng thể tích: hộp bao giao nhau có diện tích (chạm cạnh không tính) VÀ khoảng cao độ giao nhau.
def clash?(a, b)
  (a0, a1), (b0, b1) = S::ColumnPlan.box(a), S::ColumnPlan.box(b)
  a0[0] < b1[0] - 1e-6 && b0[0] < a1[0] - 1e-6 && a0[1] < b1[1] - 1e-6 && b0[1] < a1[1] - 1e-6 && a[:z0] < b[:z1] - 1e-6 && b[:z0] < a[:z1] - 1e-6
end
def clashes(items); items.combination(2).select { |a, b| clash?(a, b) }; end

# ---- Dữ liệu: khóa mới chỉ lưu khi có ----
ok('móng cũ chỉ l, w, h: không thêm khóa mới', footing_of(BASE) == {'l' => 1200.0, 'w' => 1200.0, 'h' => 400.0})
ok('types rỗng, assign rỗng: không lưu', footing_of(BASE.merge('types' => [], 'assign' => {})) == {'l' => 1200.0, 'w' => 1200.0, 'h' => 400.0})
full = footing_of(BASE.merge('step' => {'l' => 800, 'w' => 800, 'h' => 300}, 'types' => [{'name' => ' M2 ', 'l' => 1600, 'w' => 1400, 'h' => 500, 'step' => {'l' => 900, 'w' => 900, 'h' => 250}}],
                             'assign' => {'2-B' => 'M2'}, 'strip' => {'w' => 600, 'h' => 300}))
ok('móng đủ khóa: giật cấp, loại (tên bỏ khoảng trắng), gán, móng băng',
   full['step'] == {'l' => 800.0, 'w' => 800.0, 'h' => 300.0} && full['types'][0]['name'] == 'M2' && full['types'][0]['step']['h'] == 250.0 && full['assign'] == {'2-B' => 'M2'} && full['strip'] == {'w' => 600.0, 'h' => 300.0})
ok('bậc trên lớn hơn bậc dưới: từ chối', bad.call(BASE.merge('step' => {'l' => 1300, 'w' => 800, 'h' => 300})).include?('nhỏ hơn hoặc bằng bậc dưới'))
ok('dày bậc trên ngoài khoảng: từ chối đúng khoảng', bad.call(BASE.merge('step' => {'l' => 800, 'w' => 800, 'h' => 50})).include?('dày bậc trên từ 100 đến 2500'))
ok('loại móng trùng tên (không phân biệt hoa thường): từ chối', bad.call(BASE.merge('types' => [{'name' => 'M1', 'l' => 1000, 'w' => 1000, 'h' => 400}, {'name' => 'm1', 'l' => 900, 'w' => 900, 'h' => 400}])).include?('bị trùng'))
ok('loại móng sai kích thước: báo kèm tên loại', bad.call(BASE.merge('types' => [{'name' => 'M1', 'l' => 100, 'w' => 1000, 'h' => 400}])).include?('loại móng “M1”: dài móng'))
ok('quá 12 loại móng: từ chối', bad.call(BASE.merge('types' => (1..13).map { |i| {'name' => "M#{i}", 'l' => 1000, 'w' => 1000, 'h' => 400} })).include?('tối đa 12'))
ok('tên loại rỗng hoặc quá dài: từ chối', bad.call(BASE.merge('types' => [{'name' => ' ', 'l' => 1000, 'w' => 1000, 'h' => 400}])).include?('tên loại móng') &&
   bad.call(BASE.merge('types' => [{'name' => 'x' * 21, 'l' => 1000, 'w' => 1000, 'h' => 400}])).include?('tên loại móng'))
ok('gán loại không có trong danh sách: từ chối', bad.call(BASE.merge('assign' => {'1-A' => 'M9'})).include?('không có trong danh sách loại móng'))
ok('móng băng ngoài khoảng: từ chối đúng khoảng', bad.call(BASE.merge('strip' => {'w' => 100, 'h' => 300})).include?('rộng móng băng từ 200 đến 3000') &&
   bad.call(BASE.merge('strip' => {'w' => 600, 'h' => 9000})).include?('dày móng băng từ 150 đến 2500') && bad.call(BASE.merge('strip' => 'x')).include?('móng băng không hợp lệ'))
ok('khoảng giá trị đặt ở Levels', S::Levels::FOOTING_STRIP_W == (200.0..3000.0) && S::Levels::FOOTING_STEP_THICKNESS == (100.0..2500.0) && S::Levels::MAX_FOOTING_TYPES == 12)

# ---- Loại móng gán cho từng cột ----
typed = plan_of(state_with(BASE.merge('types' => [{'name' => 'Biên', 'l' => 1600, 'w' => 1500, 'h' => 500}], 'assign' => {'2-B' => 'Biên', 'fc_00000009' => 'Biên'})))
b2 = typed[:items].find { |i| i[:ref] == '2-B' }
a1 = typed[:items].find { |i| i[:ref] == '1-A' }
ok('cột gán loại: đế theo kích thước loại, có tên loại', b2[:w] == 1600.0 && b2[:d] == 1500.0 && b2[:h] == 500.0 && b2[:z1] == a1[:z1] && b2[:type_name] == 'Biên')
ok('cột không gán: dùng kích thước mặc định', a1[:w] == 1200.0 && a1[:h] == 400.0 && !a1.key?(:type_name))
ok('gán cho cột không còn: bỏ qua và cảnh báo, không lỗi', typed[:issues].any? { |m| m.include?('fc_00000009') && m.include?('không còn') } && typed[:items].none? { |i| i[:ref] == 'fc_00000009' })
ok('dữ liệu gán cho cột không còn được giữ nguyên (không tự xóa)', norm(state_with(BASE.merge('types' => [{'name' => 'Biên', 'l' => 1600, 'w' => 1500, 'h' => 500}], 'assign' => {'fc_00000009' => 'Biên'})))['levels'][0]['footing']['assign'] == {'fc_00000009' => 'Biên'})

# ---- Giật cấp ----
stepped = plan_of(state_with(BASE.merge('step' => {'l' => 800, 'w' => 700, 'h' => 300})))
cols = S::ColumnPlan.plan(*norm(state_with(BASE)).values_at('grid', 'types', 'levels'), L1)
pad = stepped[:items].find { |i| i[:ref] == '1-A' }
up = stepped[:items].find { |i| i[:ref] == '1-A:b2' }
ok('giật cấp: mỗi cột hai khối (bậc dưới mã cột, bậc trên mã cột:b2)', stepped[:items].size == 2 * cols[:items].size && pad[:kind] == 'pad' && up[:kind] == 'step' && up[:column] == '1-A')
ok('bậc trên: đỉnh = chân cột, đáy = đỉnh bậc dưới; tổng dày = h + step.h', up[:z1] == cols[:z0] && up[:z0] == pad[:z1] && pad[:z0] == (cols[:z0] - 700).round(1) && stepped[:h] == 700.0)
ok('bậc trên kích thước riêng, cùng tâm cột', up[:w] == 800.0 && up[:d] == 700.0 && up[:center] == pad[:center])
ok('giật cấp không làm hai khối chồng thể tích', clashes(stepped[:items]).empty?)
small_step = norm(state_with(BASE.merge('step' => {'l' => 300, 'w' => 300, 'h' => 300})))
small_step['types'][0]['w'] = 400
ok('bậc trên nhỏ hơn tiết diện cột: cảnh báo', S::FootingPlan.plan(small_step['grid'], small_step['types'], small_step['levels'], L1)[:issues].any? { |m| m.include?('(bậc trên) nhỏ hơn tiết diện cột') })
mix = plan_of(state_with(BASE.merge('types' => [{'name' => 'GC', 'l' => 1500, 'w' => 1500, 'h' => 400, 'step' => {'l' => 900, 'w' => 900, 'h' => 300}}], 'assign' => {'2-B' => 'GC'})))
ok('giật cấp theo loại: chỉ cột gán loại có bậc trên', mix[:items].count { |i| i[:kind] == 'step' } == 1 && mix[:items].find { |i| i[:ref] == '2-B:b2' } && mix[:items].find { |i| i[:ref] == '2-B' }[:z1] == (cols[:z0] - 300).round(1))
rot = state_with(BASE.merge('step' => {'l' => 800, 'w' => 600, 'h' => 300}))
rot['levels'][0]['picks']['columns'] = {'fc_00000001' => {'free' => {'x' => 1000, 'y' => 1000, 'rot' => 90}}, 'fc_00000002' => {'free' => {'x' => 6000, 'y' => 5000, 'rot' => 30}}}
rp = plan_of(rot)
ok('cột xoay 90 độ: bậc trên đổi chỗ dài / rộng; xoay góc khác: bậc trên xoay theo', rp[:items].find { |i| i[:ref] == 'fc_00000001:b2' }.values_at(:w, :d) == [600.0, 800.0] &&
   rp[:items].find { |i| i[:ref] == 'fc_00000002:b2' }[:rot] == 30)

# ---- Móng băng ----
strip_f = BASE.merge('strip' => {'w' => 600, 'h' => 300})
sp = plan_of(state_with(strip_f, walls: true))
strips = sp[:items].select { |i| i[:kind] == 'strip' }
walls = S::WallPlan.plan(*norm(state_with(strip_f, walls: true)).values_at('grid', 'types', 'beam_types', 'wall_types', 'levels'), L1)
ok('móng băng: mỗi tường biên có đoạn băng, đỉnh = chân tường, dày h', !strips.empty? && strips.map { |s| s[:wall] }.uniq.sort == walls[:items].map { |w| w[:ref] }.sort &&
   strips.all? { |s| s[:z1] == walls[:z0] && s[:z0] == (walls[:z0] - 300).round(1) })
xa = strips.find { |s| s[:ref] == 'x:A:2-3:s1' }
wa = walls[:items].find { |w| w[:ref] == 'x:A:2-3' }
ok('móng băng tâm theo trục tường, rộng w', xa[:d] == 600.0 && xa[:center][1] == ((wa[:min][1] + wa[:max][1]) / 2.0).round(2) && xa[:width] == 600.0)
ok('móng băng chạy GIỮA các đế cột: không chồng đế, không chồng nhau', clashes(sp[:items]).empty? && sp[:issues].empty?)
pad2 = sp[:items].find { |i| i[:ref] == '2-A' }
pad3 = sp[:items].find { |i| i[:ref] == '3-A' }
ok('đoạn băng giữa hai cột chạm đúng mép hai đế', (xa[:center][0] - xa[:w] / 2.0 - (pad2[:center][0] + pad2[:w] / 2.0)).abs < 1e-6 && (xa[:center][0] + xa[:w] / 2.0 - (pad3[:center][0] - pad3[:w] / 2.0)).abs < 1e-6)
only = plan_of(state_with(strip_f, columns: false, walls: true))
ost = only[:items]
ok('không có cột: băng khép kín ở góc, không chồng nhau', ost.size == walls[:items].size && clashes(ost).empty? &&
   ost.map { |i| S::ColumnPlan.box(i) }.then { |bs| [bs.map { |b| b[0][0] }.min, bs.map { |b| b[0][1] }.min] } == [-200.0, -200.0])
ok('băng một đoạn: chiều dài = phần trong mặt bằng', ost.all? { |i| i[:length] == [i[:w], i[:d]].max })
ok('tầng móng có băng nhưng chưa có tường: cảnh báo rõ', plan_of(state_with(strip_f))[:issues].any? { |m| m.include?('chưa có tường') })
obl = state_with(strip_f, columns: false)
obl['levels'][0]['picks']['walls'] = {'fw_00000001' => {'free' => {'a' => [0, 0], 'b' => [3000, 2000]}}}
op = plan_of(obl)
ok('tường xiên: chưa hỗ trợ móng băng, cảnh báo, không lỗi', op[:items].empty? && op[:issues].any? { |m| m.include?('tường xiên fw_00000001') })
stepped_strip = plan_of(state_with(BASE.merge('step' => {'l' => 800, 'w' => 800, 'h' => 300}, 'strip' => {'w' => 600, 'h' => 300}), walls: true))
ok('băng + giật cấp: không khối nào chồng thể tích', clashes(stepped_strip[:items]).empty?)

# ---- Xem trước ----
pv = S::Preview.build(state_with(BASE.merge('step' => {'l' => 800, 'w' => 800, 'h' => 300}, 'strip' => {'w' => 600, 'h' => 300}), walls: true).merge('level' => L1))
kinds = pv[:footings][:items].map { |i| i[:kind] }.uniq.sort
ok('xem trước có đế, bậc trên, đoạn băng (có kind, center, w, d)', kinds == %w[pad step strip] && pv[:footings][:items].all? { |i| i[:center] && i[:w] && i[:d] })

# ---- Dựng tất cả ----
tg = S::AllBuilder.targets(norm(state_with(strip_f, columns: false, walls: true)), [L1])
ok('dựng tất cả: tầng có móng băng và tường nhưng không cột vẫn dựng móng', tg['footings'] == [L1])
ok('tầng có móng nhưng không cột, không băng: không dựng móng', !S::AllBuilder.targets(norm(state_with(BASE, columns: false, walls: true)), [L1]).key?('footings'))
m = Sketchup::Model.new
st = state_with(BASE.merge('step' => {'l' => 800, 'w' => 800, 'h' => 300}, 'strip' => {'w' => 600, 'h' => 300}), walls: true)
res = S::AllBuilder.build(m, st, [L1], %w[footings])
g = m.entities.grep(Sketchup::Group).find { |x| x.get_attribute(D, 'kind') == 'footings' }
inst = g.entities.grep(Sketchup::Instance)
plan = plan_of(st)
ok('dựng: mỗi mục kế hoạch một khối, một bước hoàn tác', inst.size == plan[:items].size && m.operations == [[:start, 'VGD Structure · Dựng kết cấu'], [:commit]] && res[:total] == inst.size)
by_ref = inst.each_with_object({}) { |i, h| h[i.get_attribute('VGD_BIM_SOURCE', 'ref')] = i }
upper = by_ref["#{L1}:1-A:b2"]
sb = by_ref["#{L1}:x:A:2-3:s1"]
ok('bậc trên: khối riêng, kind footing, dims w, d, height của bậc', upper && upper.get_attribute('VGD_BIM_SOURCE', 'kind') == 'footing' && JSON.parse(upper.get_attribute(D, 'dims')) == {'w' => 800.0, 'd' => 800.0, 'height' => 300.0} && upper.name.include?('bậc trên'))
ok('đoạn băng: kind footing, dims w = rộng, d = dài đoạn, height = dày', sb && sb.get_attribute('VGD_BIM_SOURCE', 'kind') == 'footing' && JSON.parse(sb.get_attribute(D, 'dims')) == {'w' => 600.0, 'd' => xa[:length], 'height' => 300.0} && sb.name.start_with?('Móng băng'))
vol = inst.sum { |i| d = JSON.parse(i.get_attribute(D, 'dims')); d['w'] * d['d'] * d['height'] }
ok('tổng thể tích theo dims = tổng thể tích các khối kế hoạch (BIM tính đúng)', (vol - plan[:items].sum { |i| i[:w] * i[:d] * i[:h] }).abs < 1e-3)
ok('đế cũ giữ mã ref theo cột (VGD ID không đổi khi thêm giật cấp)', by_ref.key?("#{L1}:1-A"))
ok('dựng móng khi tầng không có cột, không băng: báo lỗi rõ', error_of { S::FootingBuilder.build(Sketchup::Model.new, state_with(BASE, columns: false), [L1]) }.to_s.include?('chưa có cột nào'))

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
