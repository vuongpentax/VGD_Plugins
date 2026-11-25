# Test vách kính (H7): dữ liệu tầng, kế hoạch chia tấm, dựng (khung nhôm + kính tách nhóm), dựng tất cả, xem trước.
# Chạy từ plugins/VGD_Structure: ruby dev/test_glass_wall.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def near(a, b, tol = 0.01); (a - b).abs <= tol; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
files = File.read(File.join(ROOT, 'loader.rb'))[/FILES = %w\[(.*?)\]/m, 1].split - %w[su_tools panel su_scan su_section edit_sync]
files.each { |f| require File.join(ROOT, f) }
S = VGD::Structure

def state(glass = nil)
  st = S::State.default
  st['levels'][0]['glass_walls'] = glass if glass
  st
end
def gw(span = 'x:A:1-2', extra = {}); {'gw_00000001' => {'span' => span}.merge(extra)}; end
def bad(glass)
  S::State.normalize!(state(glass))
  nil
rescue S::Levels::Error => e
  e.message
end

# ---- Dữ liệu tầng ----
n = S::State.normalize!(state(gw('x:A:1-2', 'height' => 3000, 'pane_max' => 1000)))
ok('lưu chuẩn: nhịp, cao, rộng tối đa một tấm', n['levels'][0]['glass_walls'] == {'gw_00000001' => {'span' => 'x:A:1-2', 'height' => 3000.0, 'pane_max' => 1000.0}})
ok('thiếu cao và rộng tối đa: dùng mặc định 2800 và 1200', S::State.normalize!(state(gw))['levels'][0]['glass_walls']['gw_00000001'].values_at('height', 'pane_max') == [2800.0, 1200.0])
ok('tầng không có vách kính: không có khóa (dữ liệu cũ không đổi)', !S::State.normalize!(state).fetch('levels')[0].key?('glass_walls'))
ok('nhịp không còn trên lưới: bỏ vách, không báo lỗi, tính vào số mục bị bỏ', (m = S::State.normalize!(state(gw('x:Z:8-9')))) && m['levels'][0]['glass_walls'].nil? && m['removed'] >= 1)
ok('cao ngoài khoảng bị chặn', bad(gw('x:A:1-2', 'height' => 100)).to_s.include?('cao từ'))
ok('rộng tối đa ngoài khoảng bị chặn', bad(gw('x:A:1-2', 'pane_max' => 50)).to_s.include?('bề rộng tối đa'))
ok('mã sai định dạng bị chặn', bad('abc' => {'span' => 'x:A:1-2'}).to_s.include?('mã vách kính'))
ok('khóa lạ bị chặn', bad('gw_00000001' => {'span' => 'x:A:1-2', 'x' => 1}).to_s.include?('không hợp lệ'))
ok('hai vách cùng một nhịp bị chặn', bad('gw_00000001' => {'span' => 'x:A:1-2'}, 'gw_00000002' => {'span' => 'x:A:1-2'}).to_s.include?('tối đa một vách'))
ok('quá nhiều vách bị chặn', bad((1..(S::Levels::MAX_GLASS_WALLS + 1)).to_h { |i| [format('gw_%08x', i), {'span' => "x:A:#{i}-#{i + 1}"}] }).to_s.include?('quá nhiều'))

# ---- Kế hoạch ----
st = S::State.normalize!(state(gw))
plan = S::GlassWallPlan.plan(st['grid'], st['levels'], st['levels'][0]['id'])
it = plan[:items][0]
ok('nhịp 4200, cao 2800, tối đa 1200: chia 4 tấm rộng 987,5, cao 2700', it[:count] == 4 && near(it[:pane_w], 987.5) && near(it[:pane_h], 2700) && plan[:issues].empty?)
ok('đáy ở mặt sàn kết cấu, đỉnh cao 2800 hơn', near(it[:z0], -50) && near(it[:z1], 2750))
ok('tấm kính rộng không quá giới hạn và cùng kích thước', it[:panes].size == 4 && it[:panes].all? { |s0, s1, za, zb| near(s1 - s0, 987.5) && near(zb - za, 2700) })
ok('khung gồm 2 thanh ngang, 2 thanh đứng biên và 3 thanh đứng giữa', it[:frame].size == 7)
ok('khối lượng khung: chiều dài thanh và thể tích', near(it[:frame_length], 2 * 4200 + 5 * 2700) && near(it[:frame_volume], 50 * 80 * 21_900 / 1e9, 1e-5))
ok('diện tích kính', near(it[:glass_area], 4 * 0.9875 * 2.7, 0.001))
ok('khung và kính phủ kín nhịp: bề rộng kính + thanh đứng = nhịp', near(it[:panes].sum { |p| p[1] - p[0] } + 5 * 50, 4200, 0.01))
wide = S::GlassWallPlan.plan(st['grid'], S::State.normalize!(state(gw('x:A:1-2', 'pane_max' => 3000)))['levels'], st['levels'][0]['id'])
ok('rộng tối đa 3000 trên nhịp 4200: hai tấm rộng 2025', wide[:items][0][:count] == 2 && near(wide[:items][0][:pane_w], 2025))
wst = state(gw('x:A:1-2'))
wst['levels'][0]['picks']['walls'] = {'x:A:1-2' => {}}
wp = S::Checker.plan_for('glass_walls', S::State.normalize!(wst), 'sl_00000001') rescue nil
direct = S::GlassWallPlan.plan(S::State.normalize!(wst)['grid'], S::State.normalize!(wst)['levels'], S::State.normalize!(wst)['levels'][0]['id'])
ok('vách kính trùng nhịp đã chọn tường: cảnh báo', direct[:issues].any? { |m| m.include?('gw_00000001') && m.include?('tường') })
yspan = S::GlassWallPlan.plan(st['grid'], S::State.normalize!(state(gw('y:2:A-B')))['levels'], st['levels'][0]['id'])[:items][0]
ok('nhịp theo Y: hai đầu đúng và hộp bao rộng thêm theo X', yspan[:a] == [4200.0, 0.0] && yspan[:b] == [4200.0, 3600.0] && yspan[:min][0] == 4160.0 && yspan[:max][0] == 4240.0)

# ---- Dựng ----
def ids(m); m.entities.grep(Sketchup::Group).find { |g| g.get_attribute(S::Schema::DICTIONARY, 'kind') == 'glass_walls' }; end
m = Sketchup::Model.new
res = S::GlassWallBuilder.build(m, state(gw), ['sl_00000001'])
g = ids(m)
kids = g.entities.grep(Sketchup::Group)
ok('dựng: một nhóm tầng, hai nhóm con (khung nhôm, kính)', g && kids.size == 2 && kids.map(&:name).grep(/Khung nhôm/).size == 1 && kids.map(&:name).grep(/Kính/).size == 1 && res.total == 2)
frame, glass = kids.partition { |k| k.get_attribute(S::Schema::DICTIONARY, 'part') == 'glass_frame' }.then { |a, b| [a[0], b[0]] }
ok('hai nhóm con có VGD_BIM_SOURCE kind window, mã tầng:vách:phần', frame.get_attribute('VGD_BIM_SOURCE', 'ref') == 'sl_00000001:gw_00000001:frame' && glass.get_attribute('VGD_BIM_SOURCE', 'ref') == 'sl_00000001:gw_00000001:glass' && [frame, glass].all? { |k| k.get_attribute('VGD_BIM_SOURCE', 'kind') == 'window' })
fd = JSON.parse(frame.get_attribute(S::Schema::DICTIONARY, 'dims'))
gd = JSON.parse(glass.get_attribute(S::Schema::DICTIONARY, 'dims'))
ok('khung: dims tiết diện, tổng chiều dài, thể tích', fd['w'] == 50 && fd['h'] == 80 && near(fd['length'], 21_900) && near(fd['volume'], 0.0876, 1e-4))
ok('kính: dims dày, diện tích, số tấm', gd['thickness'] == 8 && gd['count'] == 4 && near(gd['area'], 10.665, 0.001))
ok('vật liệu tách riêng: nhôm và kính trong suốt', frame.material.name.include?('Nhôm') && glass.material.name.include?('Kính') && glass.material.alpha < 1)
ok('có fingerprint và tag A. WINDOW', frame.get_attribute(S::Schema::DICTIONARY, 'fp').is_a?(String) && frame.layer.name == 'A. WINDOW')
ok('mặt khung: mặt ngoài và 4 lỗ cho kính', frame.entities.grep(Sketchup::Face).size == 5 && glass.entities.grep(Sketchup::Face).size == 4)
S::GlassWallBuilder.build(m, state(gw), ['sl_00000001'])
ok('dựng lại: thay nhóm cũ, không nhân đôi', m.entities.grep(Sketchup::Group).count { |x| x.get_attribute(S::Schema::DICTIONARY, 'kind') == 'glass_walls' } == 1)
ok('xóa vách khỏi dữ liệu rồi dựng tầng khác: nhóm mồ côi bị xóa', (S::GlassWallBuilder.remove(m) == 1) && ids(m).nil?)
g2 = Sketchup::Model.new
S::GlassWallBuilder.build(g2, state(gw), ['sl_00000001'])
ids(g2).lock!
ok('nhóm bị khóa: không dựng đè, báo rõ', begin; S::GlassWallBuilder.build(g2, state(gw), ['sl_00000001']); false; rescue S::GlassWallPlan::Error => e; e.message.include?('khóa'); end)
none = Sketchup::Model.new
ok('tầng chưa có vách kính: báo lỗi rõ', begin; S::GlassWallBuilder.build(none, state, ['sl_00000001']); false; rescue S::GlassWallPlan::Error => e; e.message.include?('chưa khai báo vách kính'); end)

# ---- Dựng tất cả ----
t = S::AllBuilder.targets(S::State.normalize!(state(gw)), %w[sl_00000001 sl_00000002])
ok('dựng tất cả: có loại glass_walls cho tầng có vách', t['glass_walls'] == ['sl_00000001'])
top = state; top['levels'][1]['glass_walls'] = gw
ok('tầng trên cùng không dựng vách kính (như cột, dầm, tường)', S::AllBuilder.targets(S::State.normalize!(top), %w[sl_00000002]).key?('glass_walls') == false)
am = Sketchup::Model.new
r = S::AllBuilder.build(am, state(gw), ['sl_00000001'], ['glass_walls'])
ok('AllBuilder.build chỉ dựng vách kính khi chọn only', r[:kinds].keys == ['glass_walls'] && ids(am))

# ---- Kiểm tra kết cấu ----
chk = S::Checker.run(S::State.normalize!(state(gw)))
ok('kiểm tra: tầng chỉ có vách kính không bị báo "chưa chọn gì"', chk[:levels][0][:warnings].none? { |m| m.include?('chưa chọn') })
chk2 = S::Checker.run(S::State.normalize!(wst))
ok('kiểm tra: vách kính trùng tường hiện trong cảnh báo của tầng', chk2[:levels][0][:warnings].any? { |m| m.start_with?('Vách kính:') && m.include?('tường') })

# ---- Xem trước ----
pv = S::Preview.build(state(gw).merge('level' => 'sl_00000001'))
ok('xem trước có vách kính: hai đầu nhịp, số tấm, kích thước', pv[:glass_walls] && pv[:glass_walls][:count] == 1 && pv[:glass_walls][:items][0].values_at(:a, :b, :count) == [[0.0, 0.0], [4200.0, 0.0], 4])
ok('tầng không có vách kính: xem trước không có khóa glass_walls', !S::Preview.build(state.merge('level' => 'sl_00000001')).key?(:glass_walls))

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
