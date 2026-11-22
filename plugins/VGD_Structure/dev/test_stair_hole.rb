# Test khoét lỗ sàn cho cầu thang (core/slab_plan.rb stair_holes!): cầu thang tầng dưới nằm trọn trong một tấm sàn tầng trên thì sàn có lỗ đúng hình cầu thang,
# diện tích trừ lỗ, xem trước và dựng có lỗ; cầu thang vắt qua mép tấm thì chỉ cảnh báo. Chạy: ruby dev/test_stair_hole.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
files = File.read(File.join(ROOT, 'loader.rb'))[/FILES = %w\[(.*?)\]/m, 1].split - %w[su_tools panel su_scan su_section edit_sync]
files.each { |f| require File.join(ROOT, f) }
S = VGD::Structure
BIG = [[-1000, -1000], [20_000, -1000], [20_000, 20_000], [-1000, 20_000]]
def state(slabs)
  st = S::State.default
  st['levels'][0]['picks']['stairs'] = {'st_00000001' => {'type' => S::StairTypes.default[0]['id'], 'free' => {'a' => [6000, 300], 'b' => [6000, 5800]}}}
  st['levels'][1]['picks']['slabs'] = slabs
  st
end
def slab_plan(st)
  n = S::State.normalize!(st)
  S::Checker.plan_for('slabs', n, n['levels'][1]['id'])
end

stair = S::StairPlace.plan(*S::State.normalize!(state({})).values_at('grid', 'types', 'beam_types', 'wall_types', 'stair_types', 'levels'), 'sl_00000001')[:items][0]
plan = slab_plan(state('fs_00000001' => {'free' => {'poly' => BIG}}))
item = plan[:items][0]
ok('cầu thang nằm trọn trong tấm sàn tầng trên: sàn có đúng một lỗ là hình cầu thang', item[:holes] == [stair[:polygon]] && item[:stair_holes] == ['st_00000001'])
ok('diện tích sàn trừ diện tích lỗ', (item[:area] - (S::Geometry.area(BIG) - S::Geometry.area(stair[:polygon])) / 1e6).abs < 0.002)
ok('không cảnh báo khi khoét được', plan[:issues].none? { |m| m.include?('Cầu thang') })
cells = S::Grid.cells(S::State.default['grid']).each_with_object({}) { |c, h| h[c[:ref]] = {} }
cp = slab_plan(state(cells))
ok('cầu thang vắt qua nhiều ô sàn: không khoét, cảnh báo rõ', cp[:items].none? { |i| i[:stair_holes] } && cp[:issues].any? { |m| m.include?('st_00000001') && m.include?('chưa khoét') })
none = slab_plan(state('fs_00000001' => {'free' => {'poly' => [[10_000, 10_000], [12_000, 10_000], [12_000, 12_000], [10_000, 12_000]]}}))
ok('tấm sàn không chạm cầu thang: không lỗ, không cảnh báo', none[:items][0][:holes].empty? && none[:issues].none? { |m| m.include?('Cầu thang') })
lvl1 = S::State.normalize!(state('fs_00000001' => {'free' => {'poly' => BIG}}))
ok('sàn của chính tầng có cầu thang (tầng dưới) không bị khoét', S::Checker.plan_for('slabs', lvl1, lvl1['levels'][0]['id'])[:items].none? { |i| i[:stair_holes] })
pv = S::Preview.build(state('fs_00000001' => {'free' => {'poly' => BIG}}).merge('level' => 'sl_00000002'))
ok('xem trước sàn tầng trên có lỗ cầu thang', pv[:slabs][:items][0][:holes].size == 1)
m = Sketchup::Model.new
S::PlateBuilder.build(m, state('fs_00000001' => {'free' => {'poly' => BIG}}), ['sl_00000002'], 'slabs')
g = m.entities.grep(Sketchup::Group).find { |x| x.get_attribute(S::Schema::DICTIONARY, 'kind') == 'slabs' }
inst = g.entities.grep(Sketchup::Instance)[0]
ok('dựng sàn: định nghĩa có lỗ (tên băm), vân tay gồm lỗ', inst.definition.name.match?(/[0-9a-f]{12}/) && inst.get_attribute(S::Schema::DICTIONARY, 'fp').is_a?(String))

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
