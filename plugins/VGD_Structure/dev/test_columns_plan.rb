# Test loại cột, tầng và kế hoạch cột (core/column_types.rb, levels.rb, column_plan.rb, state.rb): dữ liệu sai bị từ chối, quy ước vị trí cột
# (giữa / biên / góc, lọt trong khung lưới), cao độ đến đáy sàn tầng trên, đổi kiểu đặt từng cột, sao chép lựa chọn giữa tầng, cảnh báo chồng / nhô ra.
# Chạy: ruby dev/test_columns_plan.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
%w[schema grid axis_symbol column_types beam_types wall_types levels column_plan beam_plan wall_plan state].each { |f| require File.join(ROOT, 'core', f) }
S = VGD::Structure
T = S::ColumnTypes
L = S::Levels
P = S::ColumnPlan
def deep(x); Marshal.load(Marshal.dump(x)); end
grid = S::Grid.default
types = T.default
all_refs = S::Grid.intersections(grid).map { |i| i[:ref] }
levels = L.default
levels[0]['picks']['columns'] = all_refs.each_with_object({}) { |r, h| h[r] = {} }
levels = L.normalize!(levels, grid, types).first

# Loại cột
ok('loại cột mặc định C30x30 hợp lệ', T.normalize!(T.default) == T.default)
bad_types = {
  'không phải mảng' => 'x', 'mảng rỗng' => [], 'quá 50 loại' => Array.new(51) { |i| {'id' => format('ct_%08x', i), 'name' => "C#{i}", 'w' => 300, 'd' => 300} },
  'phần tử không phải bảng băm' => [1], 'mã sai dạng' => [{'id' => 'abc', 'name' => 'A', 'w' => 300, 'd' => 300}],
  'tên rỗng' => [{'id' => 'ct_00000001', 'name' => ' ', 'w' => 300, 'd' => 300}], 'tên quá dài' => [{'id' => 'ct_00000001', 'name' => 'x' * 21, 'w' => 300, 'd' => 300}],
  'tên có ký tự điều khiển' => [{'id' => 'ct_00000001', 'name' => "A\u0001", 'w' => 300, 'd' => 300}],
  'rộng quá nhỏ' => [{'id' => 'ct_00000001', 'name' => 'A', 'w' => 99, 'd' => 300}], 'sâu quá lớn' => [{'id' => 'ct_00000001', 'name' => 'A', 'w' => 300, 'd' => 3001}],
  'rộng là chuỗi' => [{'id' => 'ct_00000001', 'name' => 'A', 'w' => '300', 'd' => 300}], 'rộng NaN' => [{'id' => 'ct_00000001', 'name' => 'A', 'w' => Float::NAN, 'd' => 300}],
  'tên trùng không phân biệt hoa thường' => [{'id' => 'ct_00000001', 'name' => 'A', 'w' => 300, 'd' => 300}, {'id' => 'ct_00000002', 'name' => 'a', 'w' => 300, 'd' => 300}],
  'mã trùng' => [{'id' => 'ct_00000001', 'name' => 'A', 'w' => 300, 'd' => 300}, {'id' => 'ct_00000001', 'name' => 'B', 'w' => 300, 'd' => 300}]
}
bad_types.each { |label, raw| ok("loại cột sai bị từ chối: #{label}", !error_of { T.normalize!(raw) }.nil?) }
ok('loại cột đúng: cắt khoảng trắng tên, làm tròn 0,1', T.normalize!([{'id' => 'ct_0000000a', 'name' => ' C40x60 ', 'w' => 400.04, 'd' => 600}]) == [{'id' => 'ct_0000000a', 'name' => 'C40x60', 'w' => 400.0, 'd' => 600.0}])

# Tầng
ok('hai tầng mặc định hợp lệ, tầng 1 chọn cả 12 giao điểm', levels.size == 2 && levels[0]['picks']['columns'].size == 12 && levels[1]['picks']['columns'].empty?)
def lv(id, name, elev, extra = {}); {'id' => id, 'name' => name, 'elevation' => elev, 'slab_thickness' => 120, 'column_type' => nil, 'picks' => {'columns' => {}}}.merge(extra); end
bad_levels = {
  'không phải mảng' => 'x', 'rỗng' => [], 'quá 40 tầng' => Array.new(41) { |i| lv(format('sl_%08x', i), "T#{i}", i * 3000) },
  'mã sai' => [lv('x', 'A', 0)], 'tên rỗng' => [lv('sl_00000001', '', 0)], 'cao độ là chuỗi' => [lv('sl_00000001', 'A', '0')],
  'cao độ quá lớn' => [lv('sl_00000001', 'A', 300_000)], 'cao độ không tăng' => [lv('sl_00000001', 'A', 0), lv('sl_00000002', 'B', 0)],
  'cách tầng dưới chưa tới 500' => [lv('sl_00000001', 'A', 0), lv('sl_00000002', 'B', 499)],
  'dày sàn quá nhỏ' => [lv('sl_00000001', 'A', 0, 'slab_thickness' => 10)], 'dày sàn quá lớn' => [lv('sl_00000001', 'A', 0, 'slab_thickness' => 1001)],
  'loại cột mặc định không tồn tại' => [lv('sl_00000001', 'A', 0, 'column_type' => 'ct_ffffffff')],
  'tên tầng trùng' => [lv('sl_00000001', 'A', 0), lv('sl_00000002', 'a', 3000)], 'mã tầng trùng' => [lv('sl_00000001', 'A', 0), lv('sl_00000001', 'B', 3000)],
  'picks không phải bảng băm' => [lv('sl_00000001', 'A', 0, 'picks' => 5)],
  'cột chọn dùng loại không có' => [lv('sl_00000001', 'A', 0, 'picks' => {'columns' => {'1-A' => {'type' => 'ct_ffffffff'}}})],
  'kiểu đặt lạ' => [lv('sl_00000001', 'A', 0, 'picks' => {'columns' => {'1-A' => {'x' => 'left'}}})],
  'cột chọn không phải bảng băm' => [lv('sl_00000001', 'A', 0, 'picks' => {'columns' => {'1-A' => 1}})]
}
bad_levels.each { |label, raw| ok("tầng sai bị từ chối: #{label}", !error_of { L.normalize!(raw, grid, types) }.nil?) }
pruned, removed = L.normalize!([lv('sl_00000001', 'A', 0, 'picks' => {'columns' => {'1-A' => {}, '9-Z' => {}}})], grid, types)
ok('lựa chọn cột ở giao điểm không còn trên lưới bị bỏ và được đếm', pruned[0]['picks']['columns'].keys == ['1-A'] && removed == 1)
ok('chỉ giữ giá trị khác mặc định (auto bị bỏ)', L.normalize!([lv('sl_00000001', 'A', 0, 'picks' => {'columns' => {'1-A' => {'x' => 'auto', 'y' => 'center'}}})], grid, types).first[0]['picks']['columns']['1-A'] == {'y' => 'center'})
ok('Tầng trên cùng được nhận diện, tầng dưới có tầng kế', L.next_of(levels, 'sl_00000002').nil? && L.next_of(levels, 'sl_00000001')['id'] == 'sl_00000002')

# Kế hoạch cột
plan = P.plan(grid, types, levels, 'sl_00000001')
ok('12 cột, cao từ 0 đến đáy sàn tầng trên (3600 - 120 = 3480)', plan[:items].size == 12 && plan[:z0] == 0.0 && plan[:z1] == 3480.0 && plan[:height] == 3480.0 && plan[:items].all? { |i| i[:height] == 3480.0 })
c = ->(ref) { plan[:items].find { |i| i[:ref] == ref } }
ok('cột góc 1-A tiếp giáp cả hai trục biên: tâm (150, 150), kiểu đặt min / min', c['1-A'][:center] == [150.0, 150.0] && c['1-A'][:modes] == {'x' => 'min', 'y' => 'min'} && c['1-A'][:placement] == 'corner')
ok('cột góc đối diện 4-C: tâm (12450, 7050) (lùi vào trong nửa kích thước)', c['4-C'][:center] == [12_450.0, 7050.0] && c['4-C'][:modes] == {'x' => 'max', 'y' => 'max'})
ok('cột biên 2-A: tâm X đúng trục (4200), Y lùi vào 150; cột biên 1-B: X lùi vào 150, Y đúng trục', c['2-A'][:center] == [4200.0, 150.0] && c['1-B'][:center] == [150.0, 3600.0] && c['2-A'][:placement] == 'edge')
ok('cột giữa 2-B: tâm đúng giao điểm (4200, 3600)', c['2-B'][:center] == [4200.0, 3600.0] && c['2-B'][:modes] == {'x' => 'center', 'y' => 'center'} && c['2-B'][:placement] == 'middle')
ok('mọi cột lọt trong khung lưới và không chồng nhau: không có cảnh báo', plan[:issues].empty?)
ok('cột có đủ trường để dựng: loại, rộng, sâu', c['2-B'].values_at(:type_name, :w, :d) == ['C30x30', 300.0, 300.0])

# Đổi kiểu đặt, đổi loại
t2 = types + [{'id' => 'ct_00000002', 'name' => 'C40x60', 'w' => 400.0, 'd' => 600.0}]
lv2 = deep(levels)
lv2[0]['picks']['columns']['1-A'] = {'x' => 'center', 'y' => 'center'}
lv2[0]['picks']['columns']['2-B'] = {'type' => 'ct_00000002', 'x' => 'max'}
lv2[0]['column_type'] = 'ct_00000002'
lv2 = L.normalize!(lv2, grid, t2).first
p2 = P.plan(grid, t2, lv2, 'sl_00000001')
d = ->(ref) { p2[:items].find { |i| i[:ref] == ref } }
ok('đổi "tâm trên trục" cho cột góc: tâm (0, 0), kèm cảnh báo nhô ra ngoài khung lưới', d['1-A'][:center] == [0.0, 0.0] && p2[:issues].any? { |m| m.include?('1-A') && m.include?('nhô ra') })
ok('loại cột mặc định của tầng áp cho cột không ghi riêng (C40x60)', d['3-B'][:w] == 400.0 && d['3-B'][:d] == 600.0 && d['3-B'][:type_name] == 'C40x60')
ok('cột dùng loại riêng và kiểu đặt max theo X: tâm X lùi nửa rộng (4200 - 200)', d['2-B'][:center] == [4000.0, 3600.0])
lv3 = deep(levels)
lv3[0]['picks']['columns']['2-B'] = {'type' => 'ct_00000002'}
lv3[0]['column_type'] = nil
p3 = P.plan(grid, t2, L.normalize!(lv3, grid, t2).first, 'sl_00000001')
ok('không có loại mặc định của tầng: dùng loại đầu danh sách; cột có loại riêng giữ loại đó', p3[:items].find { |i| i[:ref] == '3-B' }[:type_name] == 'C30x30' && p3[:items].find { |i| i[:ref] == '2-B' }[:type_name] == 'C40x60')

# Cảnh báo chồng nhau
wide = [{'id' => 'ct_00000001', 'name' => 'W', 'w' => 1500.0, 'd' => 300.0}]
lw = deep(levels)
pw = P.plan(grid, wide, L.normalize!(lw, grid, wide).first, 'sl_00000001')
ok('cột rộng 1500 ở các giao điểm cách 4200 không chồng nhau', pw[:issues].none? { |m| m.include?('chồng') })
huge = [{'id' => 'ct_00000001', 'name' => 'H', 'w' => 3000.0, 'd' => 3000.0}]
ph = P.plan(grid, huge, L.normalize!(deep(levels), grid, huge).first, 'sl_00000001')
ok('cột 3000 x 3000 ở nhịp 3600 và 4200: các cột sát nhau chồng nhau và được báo (1-A và 1-B, 1-A và 2-A)', ph[:issues].any? { |m| m.include?('1-A và 1-B') && m.include?('chồng') } && ph[:issues].any? { |m| m.include?('1-A và 2-A') })

# Lỗi kế hoạch
ok('tầng trên cùng không có cột: báo rõ', error_of { P.plan(grid, types, levels, 'sl_00000002') }.to_s.include?('tầng trên cùng'))
ok('tầng không tồn tại: báo lỗi', !error_of { P.plan(grid, types, levels, 'sl_deadbeef') }.nil?)
low = L.normalize!([lv('sl_00000001', 'A', 0), lv('sl_00000002', 'B', 500, 'slab_thickness' => 250)], grid, types).first
ok('tầng kế quá sát (cao 500, sàn dày 250 -> cột cao 250 < 300): báo lỗi chiều cao', error_of { P.plan(grid, types, low, 'sl_00000001') }.to_s.include?('Chiều cao cột'))
big = S::Grid.normalize!('origin' => [0, 0], 'x_axes' => S::Grid.axes_from_spacings('4000*59', :number), 'y_axes' => S::Grid.axes_from_spacings('4000*59', :letter))
refs = S::Grid.intersections(big).map { |i| i[:ref] }
lb = L.normalize!([lv('sl_00000001', 'A', 0, 'picks' => {'columns' => refs.each_with_object({}) { |r, h| h[r] = {} }}), lv('sl_00000002', 'B', 3600)], big, types).first
ok('lưới 60 x 60 = 3600 cột vẫn trong giới hạn 5000 và nhanh', P.plan(big, types, lb, 'sl_00000001')[:items].size == 3600)

# Sao chép lựa chọn giữa các tầng
three = L.normalize!([lv('sl_00000001', 'A', 0, 'picks' => {'columns' => {'1-A' => {'x' => 'center'}, '2-B' => {'type' => 'ct_00000001'}}}), lv('sl_00000002', 'B', 3600, 'column_type' => nil, 'picks' => {'columns' => {'3-C' => {}}}), lv('sl_00000003', 'C', 7200)], grid, types).first
copied = L.copy_picks(three, 'sl_00000001', 'sl_00000002', grid, types)
ok('sao chép lựa chọn: tầng đích có đúng lựa chọn (và kiểu đặt) của tầng nguồn, thay lựa chọn cũ', copied[1]['picks']['columns'] == {'1-A' => {'x' => 'center'}, '2-B' => {'type' => 'ct_00000001'}})
ok('sao chép không đổi tầng nguồn, tầng khác, cao độ, dày sàn; không đổi dữ liệu vào', copied[0] == three[0] && copied[2] == three[2] && copied[1]['elevation'] == 3600.0 && three[1]['picks']['columns'].keys == ['3-C'])
ok('sao chép: hai tầng giống nhau hoặc không tồn tại bị từ chối', !error_of { L.copy_picks(three, 'sl_00000001', 'sl_00000001', grid, types) }.nil? && !error_of { L.copy_picks(three, 'sl_00000009', 'sl_00000001', grid, types) }.nil? && !error_of { L.copy_picks(three, 'sl_00000001', 'sl_00000009', grid, types) }.nil?)
ok('sau khi sao chép, sửa riêng tầng đích không ảnh hưởng tầng nguồn (không dùng chung đối tượng)', (copied[1]['picks']['columns']['1-A']['x'] = 'min') && copied[0]['picks']['columns']['1-A']['x'] == 'center')

# Trạng thái gộp
ok('trạng thái mặc định hợp lệ (qua normalize)', S::State.normalize!(S::State.default)['levels'].size == 2)
ok('dữ liệu cột mốc 1 (chỉ có lưới và ký hiệu) vẫn nạp được, bổ sung loại cột và tầng mặc định', (n = S::State.normalize!('grid' => grid, 'symbol' => {})) && n['types'] == T.default && n['levels'].size == 2)
ok('đổi lưới làm giao điểm biến mất: lựa chọn cột bị bỏ và đếm trong removed', (n = S::State.normalize!('grid' => S::Grid.normalize!('origin' => [0, 0], 'x_axes' => S::Grid.axes_from_spacings('4200', :number), 'y_axes' => S::Grid.axes_from_spacings('3600', :letter)), 'types' => types, 'levels' => levels)) && n['levels'][0]['picks']['columns'].size == 4 && n['removed'] == 8)
ok('tên trục chứa dấu - / : bị từ chối (dùng để ghép mã)', %w[1-2 a/b x:y].all? { |name| !error_of { S::Grid.normalize!(grid.merge('x_axes' => [{'name' => name, 'offset' => 0}, {'name' => '9', 'offset' => 4200}])) }.nil? })
ok('mã giao điểm nhất quán với tên trục (xn, yn)', S::Grid.intersections(grid).all? { |i| i[:ref] == "#{i[:xn]}-#{i[:yn]}" })

puts $fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
