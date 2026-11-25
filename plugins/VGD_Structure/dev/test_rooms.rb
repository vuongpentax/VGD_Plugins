# Test phòng (H8): dữ liệu tầng, kế hoạch phòng (diện tích, nhãn), lớp hoàn thiện sàn / trần riêng của phòng, xem trước.
# Chạy từ plugins/VGD_Structure: ruby dev/test_rooms.rb
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

CELLS = S::Grid.cells(S::State.default['grid']).map { |c| c[:ref] }
TILE = [{'fn' => 'finish', 't' => 10, 'material' => 'Gạch'}].freeze
def state(rooms = nil, opts = {})
  slabs = opts.fetch(:slabs, CELLS)
  ceilings = opts.fetch(:ceilings, [])
  floor_layers = opts[:floor_layers]
  st = S::State.default
  l = st['levels'][0]
  l['picks']['slabs'] = slabs.to_h { |c| [c, {}] }
  l['picks']['ceilings'] = ceilings.to_h { |c| [c, {}] }
  l['floor_layers'] = floor_layers if floor_layers
  l['rooms'] = rooms if rooms
  st
end
def room(name, cells, extra = {}); {'name' => name, 'cells' => cells}.merge(extra); end
RA = %w[1-2/A-B 1-2/B-C].freeze
def bad(rooms)
  S::State.normalize!(state(rooms))
  nil
rescue S::Levels::Error => e
  e.message
end

# ---- Dữ liệu tầng ----
n = S::State.normalize!(state('rm_00000001' => room(' Khách ', ['1-2/B-C', '1-2/A-B'], 'floor_layers' => TILE)))
ok('lưu chuẩn: tên cắt khoảng trắng, ô theo thứ tự lưới, lớp sàn', n['levels'][0]['rooms'] == {'rm_00000001' => {'name' => 'Khách', 'cells' => RA, 'floor_layers' => [{'fn' => 'finish', 't' => 10.0, 'material' => 'Gạch'}]}})
ok('tầng không có phòng: không có khóa rooms (dữ liệu cũ không đổi)', !S::State.normalize!(state).fetch('levels')[0].key?('rooms'))
m = S::State.normalize!(state('rm_00000001' => room('A', RA + ['9-9/Z-Z'])))
ok('ô không còn trên lưới: bỏ khỏi phòng, tính vào số mục bị bỏ', m['levels'][0]['rooms']['rm_00000001']['cells'] == RA && m['removed'] >= 1)
m2 = S::State.normalize!(state('rm_00000001' => room('A', ['9-9/Z-Z'])))
ok('phòng hết ô: bỏ phòng', m2['levels'][0]['rooms'].nil?)
ok('mã sai định dạng bị chặn', bad('abc' => room('A', RA)).to_s.include?('mã phòng'))
ok('khóa lạ bị chặn', bad('rm_00000001' => room('A', RA, 'x' => 1)).to_s.include?('không hợp lệ'))
ok('tên rỗng hoặc quá dài bị chặn', bad('rm_00000001' => room('', RA)).to_s.include?('tên từ 1') && bad('rm_00000001' => room('x' * 40, RA)).to_s.include?('tên từ 1'))
ok('tên trùng (không phân biệt hoa thường) bị chặn', bad('rm_00000001' => room('Khách', RA[0, 1]), 'rm_00000002' => room('khách', RA[1, 1])).to_s.include?('trùng'))
ok('một ô thuộc hai phòng bị chặn', bad('rm_00000001' => room('A', RA), 'rm_00000002' => room('B', ['1-2/A-B', '2-3/A-B'])).to_s.include?('đã thuộc phòng khác'))
ok('ô lặp trong một phòng bị chặn', bad('rm_00000001' => room('A', ['1-2/A-B', '1-2/A-B'])).to_s.include?('lặp'))
ok('các ô không liền nhau bị chặn (cạnh chung)', bad('rm_00000001' => room('A', ['1-2/A-B', '3-4/B-C'])).to_s.include?('liền nhau'))
ok('hai ô chỉ chạm góc không tính là liền', bad('rm_00000001' => room('A', ['1-2/A-B', '2-3/B-C'])).to_s.include?('liền nhau'))
ok('ba ô nối chuỗi là liền', bad('rm_00000001' => room('A', ['1-2/A-B', '2-3/A-B', '3-4/A-B'])).nil?)
ok('lớp hoàn thiện sai chức năng bị chặn', bad('rm_00000001' => room('A', RA, 'floor_layers' => [{'fn' => 'structure', 't' => 10}])).to_s.include?('chức năng'))
ok('tổng lớp sàn ngoài khoảng bị chặn', bad('rm_00000001' => room('A', RA, 'floor_layers' => [{'fn' => 'finish', 't' => 150}, {'fn' => 'finish', 't' => 200}])).to_s.include?('tổng bề dày'))
ok('quá nhiều phòng bị chặn', bad((1..(S::Levels::MAX_ROOMS + 1)).to_h { |i| [format('rm_%08x', i), room("P#{i}", RA)] }).to_s.include?('quá nhiều'))

# ---- Kế hoạch phòng ----
st = S::State.normalize!(state('rm_00000001' => room('Khách', RA), 'rm_00000002' => room('Bếp', ['2-3/A-B'])))
lv = st['levels'][0]['id']
rp = S::RoomPlan.plan(st['grid'], st['levels'], lv)
k = rp[:items].find { |i| i[:name] == 'Khách' }
ok('diện tích lưới: 4200 x 7200 = 30,24 m2', near(k[:area_grid], 30.24, 0.001) && k[:rects].size == 2)
ok('nhãn nằm trong một ô của phòng', k[:rects].any? { |mn, mx| k[:label][0] > mn[0] && k[:label][0] < mx[0] && k[:label][1] > mn[1] && k[:label][1] < mx[1] })
ok('chưa có kế hoạch sàn: floor_area rỗng', k[:floor_area].nil?)
slab = S::Checker.plan_for('slabs', st, lv)
rp2 = S::RoomPlan.plan(st['grid'], st['levels'], lv, slab[:items])
ok('có sàn: floor_area bằng tổng diện tích sàn của các ô', near(rp2[:items].find { |i| i[:name] == 'Khách' }[:floor_area], slab[:items].select { |i| RA.include?(i[:ref]) }.sum { |i| i[:area] }, 0.001))
ok('phòng thứ hai riêng biệt, không lẫn ô', rp[:items].find { |i| i[:name] == 'Bếp' }[:cells] == ['2-3/A-B'])

# ---- Lớp sàn riêng của phòng ----
sp = S::Checker.plan_for('slabs', S::State.normalize!(state('rm_00000001' => room('WC', ['1-2/A-B'], 'floor_layers' => TILE))), lv)
ok('lớp sàn riêng: chỉ ô của phòng có lớp (kết cấu + gạch)', sp[:items].find { |i| i[:ref] == '1-2/A-B' }[:layers].map { |l| l[:fn] } == %w[structure finish] && sp[:items].reject { |i| i[:ref] == '1-2/A-B' }.all? { |i| i[:layers].nil? })
lp = S::Checker.plan_for('slabs', S::State.normalize!(state({'rm_00000001' => room('WC', ['1-2/A-B'], 'floor_layers' => TILE)}, floor_layers: [{'fn' => 'finish', 't' => 20, 'material' => 'Gỗ'}])), lv)
ok('phòng thay lớp chung của tầng; ô khác giữ lớp chung', lp[:items].find { |i| i[:ref] == '1-2/A-B' }[:layers][1][:material] == 'Gạch' && lp[:items].find { |i| i[:ref] == '2-3/A-B' }[:layers][1][:material] == 'Gỗ')
ok('dựng sàn: định nghĩa riêng cho ô có lớp riêng', begin
  mo = Sketchup::Model.new
  S::PlateBuilder.build(mo, state({'rm_00000001' => room('WC', ['1-2/A-B'], 'floor_layers' => TILE)}), [lv], 'slabs')
  mo.definitions.list.count { |d| d.name.include?('lớp') } >= 1
end)
missing = S::RoomPlan.plan(st['grid'], S::State.normalize!(state({'rm_00000001' => room('WC', RA, 'floor_layers' => TILE)}, slabs: ['1-2/A-B']))['levels'], lv)
ok('lớp sàn riêng mà ô chưa chọn sàn: cảnh báo', missing[:issues].any? { |m| m.include?('WC') && m.include?('1-2/B-C') && m.include?('chưa chọn sàn') })

# ---- Lớp trần riêng của phòng ----
cs = state({'rm_00000001' => room('WC', ['1-2/A-B'], 'ceiling_layers' => [{'fn' => 'finish', 't' => 12}])}, ceilings: CELLS, floor_layers: nil)
cp = S::Checker.plan_for('ceilings', S::State.normalize!(cs), lv)
wc = cp[:items].find { |i| i[:ref] == '1-2/A-B' }
other = cp[:items].find { |i| i[:ref] == '2-3/A-B' }
ok('trần riêng: dày theo tổng lớp của phòng, mặt trên tính lại', wc[:thickness] == 12.0 && near(wc[:z_top] - wc[:z_bottom], 12) && wc[:layers].size == 1)
ok('ô khác giữ dày trần chung của tầng', other[:thickness] == 9.0 || other[:thickness] == S::State.normalize!(cs)['levels'][0]['ceiling_thickness'])

# ---- Xem trước ----
pv = S::Preview.build(state({'rm_00000001' => room('Khách', RA)}).merge('level' => lv))
ok('xem trước có phòng: tên, ô, diện tích lưới và diện tích sàn', pv[:rooms] && pv[:rooms][:items][0].values_at(:name, :cells) == ['Khách', RA] && near(pv[:rooms][:items][0][:area_grid], 30.24, 0.001) && pv[:rooms][:items][0][:floor_area].to_f > 0)
ok('tầng không có phòng: xem trước không có khóa rooms', !S::Preview.build(state.merge('level' => lv)).key?(:rooms))

# ---- Thống kê ----
sch = S::Schedule.build(st)
rs = sch[:sections].find { |x| x[:kind] == 'rooms' }
ok('thống kê có mục Phòng: mỗi phòng một dòng, tổng diện tích', rs && rs[:rows].map { |r| r[:type] }.sort == %w[Bếp Khách] && near(rs[:total]['grid_area'], 30.24 + 15.12, 0.001) && rs[:total]['floor_area'] > 0)
ok('chưa có phòng: thống kê giữ sáu mục như cũ', S::Schedule.build(S::State.normalize!(state))[:sections].map { |x| x[:kind] } == %w[columns beams walls openings slabs ceilings])

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
