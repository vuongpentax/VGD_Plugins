# Luật kiểm tra tự đặt (core/check_rules.rb): kiểm tra dữ liệu, so sánh, lưu / đọc trong model, giới hạn. Chạy: ruby dev/test_check_rules.rb
require_relative '../runtime/vgd_bim/core/measure'
require_relative '../runtime/vgd_bim/core/check_rules'
$fails = 0
def ok(name, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{name}"; $fails += 1 unless cond; end
CR = VGD::BIM::CheckRules
def rule(over = {}); {'name' => 'Cửa hẹp', 'column' => 'lenX', 'op' => 'lt', 'value' => '700', 'severity' => 'WARNING', 'message' => ''}.merge(over); end
def raises?(&block); block.call; nil; rescue ArgumentError => e; e.message; end

ok('luật đúng: có id ck_ và giữ các trường', (r = CR.sanitize!([rule], %w[lenX])).first['id'].match?(CR::ID_PATTERN) && r.first['op'] == 'lt' && r.first['value'] == '700')
ok('giữ id có sẵn', CR.sanitize!([rule('id' => 'ck_0123abcd')]).first['id'] == 'ck_0123abcd')
ok('thiếu tên: lỗi', raises? { CR.sanitize!([rule('name' => ' ')]) }.to_s.include?('tên'))
ok('cột không có trong bảng: lỗi', raises? { CR.sanitize!([rule('column' => 'zzz')], %w[lenX]) }.to_s.include?('không có trong bảng'))
ok('tên cột có ký tự lạ: lỗi', raises? { CR.sanitize!([rule('column' => 'a.b')]) }.to_s.include?('cột'))
ok('phép so sánh sai: lỗi', raises? { CR.sanitize!([rule('op' => 'like')]) }.to_s.include?('phép so sánh'))
ok('mức độ sai: lỗi', raises? { CR.sanitize!([rule('severity' => 'FATAL')]) }.to_s.include?('mức độ'))
ok('phép số mà giá trị không phải số: lỗi', raises? { CR.sanitize!([rule('value' => 'abc')]) }.to_s.include?('số'))
ok('phép cần giá trị mà bỏ trống: lỗi', raises? { CR.sanitize!([rule('op' => 'eq', 'value' => '')]) }.to_s.include?('giá trị'))
ok('phép trống không cần giá trị (giá trị bị xóa)', CR.sanitize!([rule('op' => 'empty', 'value' => 'x')]).first['value'] == '')
ok('ký tự điều khiển trong lời nhắn: lỗi', raises? { CR.sanitize!([rule('message' => "a\nb")]) }.to_s.include?('điều khiển'))
ok('quá dài: lỗi', raises? { CR.sanitize!([rule('name' => 'a' * 61)]) }.to_s.include?('tối đa'))
ok('quá nhiều luật: lỗi', raises? { CR.sanitize!(Array.new(51) { rule }) }.to_s.include?('tối đa'))
ok('không phải mảng / phần tử không phải Hash: lỗi', raises? { CR.sanitize!('x') } && raises? { CR.sanitize!([1]) })
ok('mã luật sai: lỗi', raises? { CR.sanitize!([rule('id' => 'x')]) }.to_s.include?('Mã luật'))
ok('giá trị là số JSON được chấp nhận', CR.sanitize!([rule('value' => 700)]).first['value'] == '700')

v = ->(op, value, actual) { CR.violated?({'op' => op, 'value' => value}, actual) }
ok('lt / lte / gt / gte', v.('lt', '700', 650) && !v.('lt', '700', 700) && v.('lte', '700', 700) && v.('gt', '700', 701) && !v.('gt', '700', 700) && v.('gte', '700', 700))
ok('dấu phẩy thập phân', v.('lt', '0,7', 0.5))
ok('ô trống với phép số: không vi phạm; cột chữ với phép số: không vi phạm', !v.('lt', '700', nil) && !v.('lt', '700', '') && !v.('lt', '700', 'abc'))
ok('trống / không trống', v.('empty', '', nil) && v.('empty', '', '  ') && !v.('empty', '', 'x') && v.('not_empty', '', 'x') && !v.('not_empty', '', ''))
ok('bằng / khác: không phân biệt hoa thường; số so với chữ số', v.('eq', 'tầng 1', 'Tầng 1') && !v.('eq', 'a', 'b') && v.('neq', 'a', 'b') && v.('eq', '700', 700) && !v.('neq', '700', 700.0))
ok('chứa: không phân biệt hoa thường; ô trống không vi phạm', v.('contains', 'door', 'Main DOOR 01') && !v.('contains', 'x', 'abc') && !v.('contains', 'x', nil))

rules = CR.sanitize!([rule('id' => 'ck_00000001', 'message' => 'Cửa dưới 700'), rule('id' => 'ck_00000002', 'name' => 'Thiếu tầng', 'column' => 'level', 'op' => 'empty', 'severity' => 'INFO'),
                      rule('id' => 'ck_00000003', 'column' => 'gone')])
rows = [{index: 0, lenX: 650, level: ''}, {index: 1, lenX: 900, level: 'Tầng 1'}, {index: 2, lenX: nil, level: ''}]
res = CR.evaluate(rules, rows)
ok('chạy luật: đúng dòng, mức độ, lời nhắn (rỗng lấy tên luật), bỏ luật cột không còn', res[:results].map { |r| [r[:rule], r[:index], r[:severity], r[:message]] } ==
   [['ck_00000001', 0, 'WARNING', 'Cửa dưới 700'], ['ck_00000002', 0, 'INFO', 'Thiếu tầng'], ['ck_00000002', 2, 'INFO', 'Thiếu tầng']] && !res[:truncated])
big = CR.evaluate(CR.sanitize!([rule('op' => 'gte', 'value' => '0')]), Array.new(2500) { |i| {index: i, lenX: 1} })
ok('giới hạn kết quả', big[:results].size == CR::MAX_RESULTS && big[:truncated])

class FakeModel
  attr_reader :ops
  def initialize; @attrs = {}; @ops = []; end
  def get_attribute(d, k, default = nil); @attrs.dig(d, k) || default; end
  def set_attribute(d, k, v); (@attrs[d] ||= {})[k] = v; end
  def start_operation(*args); @ops << :start; end
  def commit_operation; @ops << :commit; end
  def abort_operation; @ops << :abort; end
end
m = FakeModel.new
ok('chưa lưu: đọc ra rỗng', CR.read(m) == [])
CR.write(m, [rule])
saved = CR.read(m)
ok('lưu rồi đọc lại đúng; một thao tác', saved.size == 1 && saved.first['name'] == 'Cửa hẹp' && m.ops == [:start, :commit])
CR.write(m, saved)
ok('không đổi gì thì không mở thao tác', m.ops == [:start, :commit])
m.set_attribute('VGD_BIM_MODEL', 'check_rules', '{hỏng')
ok('dữ liệu hỏng: coi như chưa có', CR.read(m) == [])
bad = raises? { CR.write(m, [rule('op' => 'zz')]) }
ok('ghi dữ liệu sai: lỗi, không mở thao tác', bad && m.ops == [:start, :commit])
puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
