# Đổi tên hàng loạt (core/rename.rb): tính tên mới từ mẫu, không đụng model.
ROOT = ARGV[0] || File.expand_path('../runtime/vgd_bim', __dir__)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
module VGD; module BIM; module Rename; end; end; end
require File.join(ROOT, 'core/rename')
R = VGD::BIM::Rename

def item(index, name, extra = {})
  {index: index, name: name, definition: 'Họ', tag: 'Tủ', tag_group: 'Đồ rời', locked: false, position: [index * 100.0, 0.0, 0.0]}.merge(extra)
end
def opts(extra = {}); R.normalize({'template' => '{tên}'}.merge(extra)); end
def news(plan); plan[:rows].map { |r| r[:new] }; end

# Mẫu và số thứ tự
items = [item(0, 'A'), item(1, 'B'), item(2, 'C')]
ok('mẫu có {số}: đánh số từ 1, đệm 2 chữ số', news(R.plan(items, opts('template' => 'Tủ-{số}'))) == %w[Tủ-01 Tủ-02 Tủ-03])
ok('bắt đầu 10, bước 5, không đệm', news(R.plan(items, opts('template' => 'T{số}', 'start' => 10, 'step' => 5, 'pad' => 0))) == %w[T10 T15 T20])
ok('ghép tên cũ, họ, phân loại, nhóm', news(R.plan([item(0, 'A')], opts('template' => '{tên}|{họ}|{phân loại}|{nhóm}'))) == ['A|Họ|Tủ|Đồ rời'])
ok('tên cũ trống thì {tên} lấy tên họ (định nghĩa)', news(R.plan([item(0, '')], opts('template' => '[{tên}]'))) == ['[Họ]'])
ok('mẫu mặc định {tên} giữ nguyên tên: trạng thái same', R.plan(items, opts)[:rows].all? { |r| r[:status] == 'same' })

# Thứ tự đánh số
shuffled = [item(0, 'b', position: [300.0, 0, 0]), item(1, 'a', position: [100.0, 0, 0]), item(2, 'c', position: [200.0, 0, 0])]
ok('theo vị trí X: dòng X nhỏ nhất số 1', news(R.plan(shuffled, opts('template' => '{số}', 'order' => 'position', 'pad' => 0))) == %w[3 1 2])
ok('theo tên: a, b, c', news(R.plan(shuffled, opts('template' => '{số}', 'order' => 'name', 'pad' => 0))) == %w[2 1 3])
ok('theo thứ tự bảng (mặc định): 1, 2, 3', news(R.plan(shuffled, opts('template' => '{số}', 'pad' => 0))) == %w[1 2 3])
natural = [item(0, 'T10'), item(1, 'T2'), item(2, 'T1')]
ok('theo tên: số trong tên so sánh theo giá trị (T1, T2, T10)', news(R.plan(natural, opts('template' => '{số}', 'order' => 'name', 'pad' => 0))) == %w[3 2 1])
tie = [item(0, 'x', position: [0.0, 5.0, 0]), item(1, 'y', position: [0.0, 1.0, 0])]
ok('theo vị trí: X bằng nhau thì xét Y', news(R.plan(tie, opts('template' => '{số}', 'order' => 'position', 'pad' => 0))) == %w[2 1])

# Tìm và thay, hoa thường, tiền tố hậu tố
ok('tìm và thay đúng chữ, không hiểu là biểu thức chính quy', news(R.plan([item(0, 'a.b(c)')], opts('find' => '.b(', 'replace' => '_'))) == ['a_c)'])
ok('thay bằng chữ có \\1 không bị hiểu là nhóm', news(R.plan([item(0, 'abc')], opts('find' => 'b', 'replace' => '\\1'))) == ['a\\1c'])
ok('chữ hoa có dấu tiếng Việt', news(R.plan([item(0, 'tủ bếp')], opts('case' => 'upper'))) == ['TỦ BẾP'])
ok('chữ thường có dấu tiếng Việt', news(R.plan([item(0, 'TỦ BẾP')], opts('case' => 'lower'))) == ['tủ bếp'])
ok('viết hoa chữ cái đầu mỗi từ', news(R.plan([item(0, 'tủ BẾP dưới')], opts('case' => 'title'))) == ['Tủ Bếp Dưới'])
ok('tiền tố và hậu tố', news(R.plan([item(0, 'A')], opts('prefix' => 'P-', 'suffix' => '-S'))) == ['P-A-S'])

# Trạng thái từng dòng
locked = [item(0, 'A', locked: true), item(1, 'B'), item(2, 'C')]
plan = R.plan(locked, opts('template' => 'N{số}', 'pad' => 0))
ok('đối tượng bị khóa: bỏ qua, giữ tên cũ', plan[:rows][0][:status] == 'locked' && plan[:rows][0][:new] == 'A')
ok('đối tượng bị khóa không chiếm số thứ tự', news(plan)[1..2] == %w[N1 N2])
ok('đếm trạng thái', plan[:counts] == {total: 3, ok: 2, same: 0, locked: 1, empty: 0, long: 0, duplicate: 0})
ok('tên mới trống: bỏ qua', R.plan([item(0, 'A')], opts('template' => '  '))[:rows][0][:status] == 'empty')
ok('tên quá dài: bỏ qua', R.plan([item(0, 'A')], opts('template' => 'x' * 201))[:rows][0][:status] == 'long')
dup = R.plan([item(0, 'A'), item(1, 'B')], opts('template' => 'Giống'))
ok('tên mới trùng nhau trong đợt: đánh dấu trùng nhưng vẫn cho đổi', dup[:rows].all? { |r| r[:duplicate] && r[:status] == 'ok' } && dup[:counts][:duplicate] == 2)
ok('trùng với tên giữ nguyên trong đợt cũng báo', R.plan([item(0, 'A'), item(1, 'B')], opts('template' => 'A', 'find' => '', 'replace' => '')).then { |p| p[:rows].map { |r| r[:duplicate] } == [true, true] })
ok('mỗi dòng giữ chỉ số dòng của bảng', R.plan([item(7, 'A'), item(9, 'B')], opts('template' => 'N{số}'))[:rows].map { |r| r[:index] } == [7, 9])

# Kiểm tra dữ liệu người dùng
bad = ->(extra) { begin; R.normalize({'template' => '{tên}'}.merge(extra)); false; rescue ArgumentError => e; e.message.match?(/[À-ỹ]/); end }
ok('thứ tự lạ bị từ chối bằng tiếng Việt', bad.call('order' => 'ngau_nhien'))
ok('kiểu chữ lạ bị từ chối', bad.call('case' => 'abc'))
ok('số bắt đầu không phải số bị từ chối', bad.call('start' => 'x'))
ok('đệm quá lớn bị từ chối', bad.call('pad' => 20))
ok('bước 0 bị từ chối', bad.call('step' => 0))
ok('mẫu quá dài bị từ chối', bad.call('template' => 'x' * 500))
ok('thiếu mẫu thì dùng {tên}', R.normalize({})[:template] == '{tên}')
ok('số nhập dạng chuỗi được chấp nhận', R.normalize('start' => '5', 'pad' => '3', 'step' => '2').values_at(:start, :pad, :step) == [5, 3, 2])

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
