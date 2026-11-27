# Test ghi chú 2D trên mặt bằng (cột mốc P5b): nét, đa tuyến, tròn, cung, chữ, kích thước, cốt cao độ: kiểm tra dữ liệu, chuẩn hóa, lưu và nạp lại.
# Chạy: ruby dev/test_notes.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/stair_types core/stair_plan core/stair_place core/layer_list core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/room_plan core/slab_plan core/ceiling_plan core/proposal core/checker core/model_edit core/state core/preview model_sync edit_sync model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder stair_builder all_builder].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
L = S::Levels
D = S::Schema::DICTIONARY
MM = 25.4
grid = S::Grid.default
types = S::ColumnTypes.default
bt = S::BeamTypes.default
wt = S::WallTypes.default
ot = S::OpeningTypes.default
def deep(x); Marshal.load(Marshal.dump(x)); end
def state_with(cols: {}, beams: {}, walls: {}, openings: {}, slabs: {}, ceilings: {})
  st = S::State.default
  st['levels'][0]['picks'] = {'columns' => cols, 'beams' => beams, 'walls' => walls, 'openings' => openings, 'slabs' => slabs, 'ceilings' => ceilings}
  S::State.normalize!(st)
end
def lv(st); st['levels']; end
FC1 = 'fc_0000000a'; FB1 = 'fb_0000000b'; FW1 = 'fw_0000000c'; FW2 = 'fw_0000000d'

def notes_state(notes, level = 0)
  st = S::State.default
  st['levels'][level]['notes'] = notes
  S::State.normalize!(st)
end
def notes_of(st, level = 0); st['levels'][level]['notes']; end
A1 = 'an_00000001'; A2 = 'an_00000002'; A3 = 'an_00000003'

# ---- Mặc định và dữ liệu cũ ----
ok('tầng mặc định không có ghi chú (notes = {})', S::State.normalize!(S::State.default)['levels'].all? { |l| l['notes'] == {} })
old = S::State.default
old['levels'].each { |l| l.delete('notes') }
ok('dữ liệu cũ (chưa có khóa notes) vẫn đọc được, thành {}', S::State.normalize!(old)['levels'].all? { |l| l['notes'] == {} })

# ---- Từng loại hợp lệ ----
good = {
  A1 => {'t' => 'line', 'a' => [0, 0], 'b' => [1000.04, 2000.06]},
  A2 => {'t' => 'poly', 'pts' => [[0, 0], [1000, 0], [1000, 1000]], 'closed' => true},
  A3 => {'t' => 'circle', 'c' => [500, 500], 'r' => 250.123}
}
n = notes_of(notes_state(good))
ok('nét: tọa độ làm tròn 0,1 mm', n[A1] == {'t' => 'line', 'a' => [0.0, 0.0], 'b' => [1000.0, 2000.1]})
ok('đa tuyến khép kín được giữ, tròn: bán kính làm tròn 0,01', n[A2]['closed'] == true && n[A2]['pts'].size == 3 && n[A3]['r'] == 250.12)
n = notes_of(notes_state({'an_00000004' => {'t' => 'poly', 'pts' => [[0, 0], [1, 1]]}}, 1), 1)
ok('đa tuyến không khai closed: mặc định hở (false)', n['an_00000004']['closed'] == false)
n = notes_of(notes_state('an_00000005' => {'t' => 'arc', 'c' => [0, 0], 'r' => 500, 'a0' => -90, 'a1' => 450}))['an_00000005']
ok('cung: góc đưa về 0..360 (-90 -> 270, 450 -> 90), vẽ ngược chiều kim đồng hồ từ góc đầu tới góc cuối', n['a0'] == 270.0 && n['a1'] == 90.0)
n = notes_of(notes_state('an_00000006' => {'t' => 'text', 'p' => [10, 20], 'text' => "  Ghi\u0007chú\n  "}))['an_00000006']
ok('chữ: bỏ ký tự điều khiển và khoảng trắng đầu cuối, mặc định cao 250 mm, xoay 0', n['text'] == 'Ghi chú' && n['h'] == 250.0 && n['rot'] == 0.0)
n = notes_of(notes_state('an_00000007' => {'t' => 'text', 'p' => [0, 0], 'text' => 'x', 'h' => 400, 'rot' => -90}))['an_00000007']
ok('chữ: cao chữ và góc xoay tùy chỉnh (-90 -> 270)', n['h'] == 400.0 && n['rot'] == 270.0)
n = notes_of(notes_state('an_00000008' => {'t' => 'dim', 'a' => [0, 0], 'b' => [3000, 0]}))['an_00000008']
ok('kích thước: mặc định lệch 300 mm', n['off'] == 300.0 && n['a'] == [0.0, 0.0] && n['b'] == [3000.0, 0.0])
n = notes_of(notes_state('an_00000009' => {'t' => 'mark', 'p' => [100, 100], 'z' => 3600}))['an_00000009']
ok('cốt cao độ: điểm và cao độ', n == {'t' => 'mark', 'p' => [100.0, 100.0], 'z' => 3600.0})

# ---- Dữ liệu sai bị từ chối ----
bad = {
  'loại lạ' => {'t' => 'blob'}, 'thiếu loại' => {'a' => [0, 0]}, 'nét hai đầu trùng' => {'t' => 'line', 'a' => [0, 0], 'b' => [0.3, 0.3]}, 'tọa độ không phải số' => {'t' => 'line', 'a' => [0, 'x'], 'b' => [1, 1]},
  'tọa độ quá lớn' => {'t' => 'line', 'a' => [0, 0], 'b' => [2_000_000, 0]}, 'điểm thiếu' => {'t' => 'line', 'a' => [0], 'b' => [5, 5]},
  'đa tuyến 1 điểm' => {'t' => 'poly', 'pts' => [[0, 0]]}, 'đa tuyến khép kín 2 điểm' => {'t' => 'poly', 'pts' => [[0, 0], [5, 5]], 'closed' => true}, 'closed không phải true/false' => {'t' => 'poly', 'pts' => [[0, 0], [5, 5]], 'closed' => 'yes'},
  'quá nhiều điểm' => {'t' => 'poly', 'pts' => (0..500).map { |i| [i, i] }}, 'tròn bán kính 0' => {'t' => 'circle', 'c' => [0, 0], 'r' => 0}, 'cung hai góc trùng' => {'t' => 'arc', 'c' => [0, 0], 'r' => 5, 'a0' => 30, 'a1' => 390},
  'chữ rỗng' => {'t' => 'text', 'p' => [0, 0], 'text' => '   '}, 'chữ quá dài' => {'t' => 'text', 'p' => [0, 0], 'text' => 'a' * 201}, 'chữ không phải chuỗi' => {'t' => 'text', 'p' => [0, 0], 'text' => 5},
  'chữ cao 10 mm' => {'t' => 'text', 'p' => [0, 0], 'text' => 'a', 'h' => 10}, 'kích thước hai điểm trùng' => {'t' => 'dim', 'a' => [1, 1], 'b' => [1, 1]}, 'cốt cao độ thiếu z' => {'t' => 'mark', 'p' => [0, 0]}
}
bad.each { |name, note| ok("ghi chú sai bị từ chối: #{name}", error_of { notes_state(A1 => note) }) }
ok('mã ghi chú sai bị từ chối', error_of { notes_state('xx_00000001' => {'t' => 'mark', 'p' => [0, 0], 'z' => 0}) } && error_of { notes_state('an_1' => {'t' => 'mark', 'p' => [0, 0], 'z' => 0}) })
ok('notes không phải đối tượng bị từ chối', error_of { notes_state([1]) })
many = (0..2000).each_with_object({}) { |i, h| h[format('an_%08x', i)] = {'t' => 'mark', 'p' => [i, i], 'z' => 0} }
ok('quá 2000 ghi chú một tầng bị từ chối', error_of { notes_state(many) })

# ---- Mỗi tầng riêng, lưu và nạp lại ----
st = S::State.default
st['levels'][0]['notes'] = good
st['levels'][1]['notes'] = {A1 => {'t' => 'text', 'p' => [1, 2], 'text' => 'Tầng 2'}}
m = Sketchup::Model.new
saved = S::ModelStore.write(m, st)
back = S::ModelStore.read(m)
ok('lưu vào model rồi đọc lại: ghi chú từng tầng còn nguyên, đã chuẩn hóa', back['levels'][0]['notes'] == saved['levels'][0]['notes'] && back['levels'][0]['notes'].size == 3 && back['levels'][1]['notes'][A1]['text'] == 'Tầng 2')
ok('cùng mã ghi chú ở hai tầng khác nhau không lẫn', back['levels'][0]['notes'][A1]['t'] == 'line' && back['levels'][1]['notes'][A1]['t'] == 'text')
ok('đọc lại dữ liệu lưu rồi lưu lần nữa cho kết quả y hệt (ổn định)', S::ModelStore.write(m, back)['levels'].map { |l| l['notes'] } == back['levels'].map { |l| l['notes'] })
big = S::State.default
big['levels'][0]['notes'] = (0...300).each_with_object({}) { |i, h| h[format('an_%08x', i)] = {'t' => 'poly', 'pts' => (0...500).map { |k| [k * 10.5, i * 10.5] }} }
big['levels'][1]['notes'] = (0...300).each_with_object({}) { |i, h| h[format('an_%08x', i)] = {'t' => 'poly', 'pts' => (0...500).map { |k| [k * 10.5, i * 10.5] }} }
ok('dữ liệu ghi chú vượt giới hạn dung lượng lưu bị từ chối khi ghi vào model', error_of { S::ModelStore.write(Sketchup::Model.new, big) })
ok('xem trước (giao diện) không bị ghi chú làm hỏng', S::Preview.build(st.merge('level' => 'sl_00000001').reject { |k, _| k == 'removed' })[:levels_ok] == true)
ck = S::Checker.run(st)
ok('kiểm tra kết cấu không đếm ghi chú (không phải phần tử kết cấu)', ck[:levels][0][:counts].keys.sort == %w[beams ceilings columns openings slabs walls])
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
