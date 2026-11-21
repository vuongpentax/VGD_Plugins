# Test đặt Mã đối tượng hàng loạt (core/object_code.rb): tham số sai bị từ chối, đánh số theo thứ tự đã chọn, món có mã giữ nguyên
# (trừ khi ghi đè), món khóa bỏ qua, không trùng mã của món khác. Chạy: ruby dev/test_object_code.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
require File.join(ROOT, 'core/object_code')
O = VGD::BIM::ObjectCode

items = [{index: 4, code: '', locked: false}, {index: 2, code: 'D05', locked: false}, {index: 7, code: '', locked: true}, {index: 1, code: '', locked: false}]
ok('tiền tố rỗng: từ chối', error_of { O.plan(items, prefix: ' ', start: 1, pad: 2) }.to_s.include?('tiền tố'))
ok('tiền tố quá dài hoặc có ký tự điều khiển: từ chối', error_of { O.plan(items, prefix: 'a' * 21, start: 1, pad: 2) }.to_s.include?('tiền tố') && error_of { O.plan(items, prefix: "D\u0001", start: 1, pad: 2) }.to_s.include?('tiền tố'))
ok('số bắt đầu sai (âm, quá lớn, không phải số): từ chối', [-1, 100_000, '1', nil, 1.5].all? { |s| error_of { O.plan(items, prefix: 'D', start: s, pad: 2) }.to_s.include?('Số bắt đầu') })
ok('số chữ số sai (0, 7, không phải số): từ chối', [0, 7, '2', nil].all? { |p| error_of { O.plan(items, prefix: 'D', start: 1, pad: p) }.to_s.include?('Số chữ số') })
ok('danh sách món rỗng: từ chối', error_of { O.plan([], prefix: 'D', start: 1, pad: 2) }.to_s.include?('chọn'))

plan = O.plan(items, prefix: 'D', start: 1, pad: 2)
ok('đánh số theo thứ tự các món gửi lên, món có mã giữ nguyên, món khóa bỏ qua', plan[:assign] == {4 => 'D01', 1 => 'D02'} && plan[:kept] == [2] && plan[:locked] == [7])
ok('ghi đè: món có mã cũng được đánh số lại theo thứ tự', O.plan(items, prefix: 'D', start: 1, pad: 2, overwrite: true)[:assign] == {4 => 'D01', 2 => 'D02', 1 => 'D03'})
ok('số chữ số và số bắt đầu: TB + 3 chữ số từ 10', O.plan(items, prefix: 'TB', start: 10, pad: 3)[:assign] == {4 => 'TB010', 1 => 'TB011'})
ok('mã dài hơn số chữ số vẫn đủ (không cắt)', O.plan([{index: 0, code: '', locked: false}], prefix: 'X', start: 12_345, pad: 2)[:assign] == {0 => 'X12345'})
ok('trùng mã của món khác (so không phân biệt hoa thường) bị từ chối, nêu mã trùng', error_of { O.plan([{index: 0, code: '', locked: false}, {index: 1, code: 'd01', locked: false}], prefix: 'D', start: 1, pad: 2) }.to_s.include?('D01'))
ok('món bị ghi đè không tính là mã "của món khác"', O.plan([{index: 0, code: 'D01', locked: false}, {index: 1, code: '', locked: false}], prefix: 'D', start: 1, pad: 2, overwrite: true)[:assign] == {0 => 'D01', 1 => 'D02'})
ok('mọi món đều có mã (không ghi đè): kế hoạch rỗng', O.plan([{index: 2, code: 'D05', locked: false}], prefix: 'D', start: 1, pad: 2)[:assign].empty?)
ok('mã tối đa 30 ký tự (code của schema dùng chuỗi, giới hạn hợp lý)', O.plan([{index: 0, code: '', locked: false}], prefix: 'a' * 20, start: 99_999, pad: 6)[:assign][0].length <= 30)

ok('không trùng mã của món ngoài danh sách đặt (others)', error_of { O.plan([{index: 0, code: '', locked: false}], prefix: 'D', start: 1, pad: 2, others: ['d01']) }.to_s.include?('D01'))

# ---- Sửa tay ô Mã đối tượng trong bảng (check_edit!): không trùng mã của món khác trong bảng, không đặt một mã cho nhiều món ----
rows = [{index: 0, code: 'TB01'}, {index: 1, code: 'tb02'}, {index: 2, code: ''}]
ok('sửa tay: mã trùng món khác (khác hoa thường) bị từ chối', error_of { O.check_edit!('TB02', [0], rows) }.to_s.include?('đã có ở món khác'))
ok('sửa tay: mã mới chưa có trong bảng được nhận', error_of { O.check_edit!('TB03', [2], rows) }.nil?)
ok('sửa tay: giữ nguyên mã của chính món đó được nhận', error_of { O.check_edit!('TB01', [0], rows) }.nil?)
ok('sửa tay: xóa mã (rỗng) luôn được nhận, kể cả khi trùng', error_of { O.check_edit!('', [0, 1], rows) }.nil?)
ok('sửa tay: một mã cho nhiều món cùng lúc bị từ chối', error_of { O.check_edit!('TB09', [0, 2], rows) }.to_s.include?('nhiều món'))

puts($fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
