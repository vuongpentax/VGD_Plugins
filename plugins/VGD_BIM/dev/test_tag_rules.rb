# Test luật gắn tag tự động theo từ khóa tên (core/tag_rules.rb): kiểm tra dữ liệu, khớp từ khóa, lập kế hoạch, lưu / đặt lại, nhập xuất JSON
# (kể cả file luật của Auto Tag). Logic thuần, không cần SketchUp. Chạy: ruby dev/test_tag_rules.rb
require 'json'
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_tag_rules')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def raises?(text = nil); yield; false; rescue ArgumentError => e; text ? e.message.downcase.include?(text) : true; end
module VGD; module BIM; def self.log(_m); end; end; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
%w[storage tags measure tag_rules].each { |f| require File.join(ROOT, "core/#{f}") }
R = VGD::BIM::TagRules

# ---- Từ khóa ----
ok('từ khóa: tách theo dấu phẩy, chấm phẩy, xuống dòng; bỏ rỗng và trùng (không phân biệt hoa thường, dấu)', R.keywords("tường, Wall;TUONG\n wall ,,") == %w[tường Wall])
ok('từ khóa: quá ngắn bị từ chối', raises?('ít nhất') { R.keywords('a, tường') })
ok('từ khóa: quá dài hoặc quá nhiều bị từ chối', raises?('tối đa') { R.keywords('x' * 41) } && raises?('tối đa') { R.keywords((1..31).map { |i| "tu#{i}" }.join(',')) })

# ---- Kiểm tra bộ luật ----
ok('bộ luật mặc định hợp lệ; "Cửa sổ" đứng trước "Cửa" để khớp đúng', (tags = R.default.map { |r| r['tag'] }; R.sanitize(R.default) == R.default && tags.index('Cửa sổ') < tags.index('Cửa')))
ok('luật: bỏ khoảng trắng thừa trong tên tag và từ khóa', R.sanitize([{'tag' => '  Tường   100 ', 'keywords' => ' tường ,  wall '}]) == [{'tag' => 'Tường 100', 'keywords' => 'tường, wall'}])
ok('luật: không phải danh sách bị từ chối', raises?('danh sách') { R.sanitize('x') } && raises?('danh sách') { R.sanitize(nil) })
ok('luật: thiếu tag hoặc thiếu từ khóa bị từ chối, nêu số dòng', raises?('dòng 2') { R.sanitize([{'tag' => 'A1', 'keywords' => 'ab'}, {'tag' => '', 'keywords' => 'xy'}]) } && raises?('dòng 1') { R.sanitize([{'tag' => 'A1', 'keywords' => ''}]) })
ok('luật: tên "Untagged", tên quá dài, mục không phải bảng bị từ chối', raises?('untagged') { R.sanitize([{'tag' => 'Untagged', 'keywords' => 'ab'}]) } && raises?('quá dài') { R.sanitize([{'tag' => 'x' * 61, 'keywords' => 'ab'}]) } && raises?('luật') { R.sanitize(['abc']) })
ok('luật: quá 100 luật bị từ chối', raises?('tối đa') { R.sanitize(Array.new(101) { |i| {'tag' => "T#{i}", 'keywords' => 'ab'} }) })

# ---- Khớp ----
rules = R.compile(R.default)
match = ->(*names) { (i = R.match(rules, names)) && rules[i][:tag] }
ok('khớp không phân biệt hoa thường và dấu: "TUONG_01" và "Tường 100" đều ra Tường', match.call('TUONG_01') == 'Tường' && match.call('Tường 100') == 'Tường')
ok('luật đứng trước thắng: "Cửa sổ 1" ra Cửa sổ chứ không ra Cửa', match.call('Cửa sổ 1') == 'Cửa sổ' && match.call('Door_main') == 'Cửa' && match.call('Window A') == 'Cửa sổ')
ok('khớp tên bản sao hoặc tên định nghĩa: lấy cái nào khớp (tên thứ hai)', match.call('', 'Wall_100') == 'Tường' && match.call('Group#1', 'Beam B2') == 'Dầm')
ok('không khớp luật nào hoặc tên rỗng: nil', match.call('Ghế ăn').nil? && match.call('', nil).nil? && R.match([], ['x']).nil?)
ok('khớp theo từ khóa chứa trong tên (không cần cả từ): "Doorway" cũng khớp "door" (đây là lý do luôn xem trước)', match.call('Doorway') == 'Cửa')

# ---- Kế hoạch ----
item = ->(label, names, tag: '', locked: false) { {label: label, names: names, tag: tag, locked: locked} }
items = [item.call('T1', ['Tường 1']), item.call('T2', ['Wall 2'], tag: 'Tường'), item.call('T3', ['Tường 3'], tag: 'Khác'), item.call('C1', ['Cửa 1']),
         item.call('G1', ['Ghế']), item.call('K1', ['Tường khóa'], locked: true), item.call('G2', ['Ghế 2'], tag: 'Nội thất')]
plan = R.plan(items, rules, overwrite: false)
ok('kế hoạch (không ghi đè): gắn Tường 1 và Cửa 1; Tường 2 đã đúng tag; Tường 3 đã có tag khác nên giữ; Ghế không khớp; 1 bị khóa',
   plan[:assign].map { |i, r| [i[:label], rules[r][:tag]] } == [%w[T1 Tường], %w[C1 Cửa]] && plan[:same] == 1 && plan[:kept] == 1 && plan[:unmatched] == 2 && plan[:locked] == 1 && plan[:total] == 7)
plan2 = R.plan(items, rules, overwrite: true)
ok('kế hoạch (ghi đè): Tường 3 cũng bị đổi sang Tường; Tường 2 vẫn là "đã đúng"; không còn mục giữ', plan2[:assign].map { |i, _| i[:label] } == %w[T1 T3 C1] && plan2[:same] == 1 && plan2[:kept] == 0)
ok('kế hoạch: tóm tắt theo luật (số đối tượng và vài tên mẫu), chỉ các luật có đối tượng', plan[:rules].map { |r| [r[:tag], r[:count], r[:samples]] } == [['Tường', 1, ['T1']], ['Cửa', 1, ['C1']]])
many = Array.new(10) { |i| item.call("W#{i}", ["Wall #{i}"]) }
ok('kế hoạch: tên mẫu tối đa 3', R.plan(many, rules, overwrite: false)[:rules][0][:samples] == %w[W0 W1 W2])
ok('đối tượng khóa không bao giờ bị gắn, kể cả khi bật ghi đè', R.plan([item.call('K', ['Wall'], locked: true, tag: 'Khác')], rules, overwrite: true)[:assign].empty?)

# ---- Lưu, đặt lại ----
ok('chưa lưu gì: đọc ra bộ mặc định', R.load == R.default)
saved = R.save([{'tag' => ' Nội thất ', 'keywords' => 'bàn, ghế'}])
ok('lưu luật: bỏ khoảng trắng và đọc lại đúng', saved == [{'tag' => 'Nội thất', 'keywords' => 'bàn, ghế'}] && R.load == saved)
ok('lưu luật sai: bị từ chối và giữ nguyên bộ đã lưu', raises?('tag') { R.save([{'tag' => '', 'keywords' => 'ab'}]) } && R.load == saved)
File.write(File.join(ENV['VGD_BIM_DATA_DIR'], 'tag_rules.json'), '{hỏng')
ok('file luật hỏng: dùng bộ mặc định, không lỗi', R.load == R.default)
R.save([{'tag' => 'A1', 'keywords' => 'ab'}])
ok('đặt lại: xóa bộ đã lưu và trả bộ mặc định', R.reset == R.default && R.load == R.default && !File.exist?(File.join(ENV['VGD_BIM_DATA_DIR'], 'tag_rules.json')))
ok('đặt lại khi chưa lưu gì: không lỗi', R.reset == R.default)

# ---- Nhập xuất JSON ----
list = [{'tag' => 'Tường', 'keywords' => 'tường, wall'}, {'tag' => 'Cửa', 'keywords' => 'cửa'}]
text = R.to_json(list)
ok('xuất JSON có định dạng riêng và nhập lại đúng', JSON.parse(text)['format'] == R::FORMAT && R.from_json(text) == list)
ok('nhập mảng luật trần', R.from_json(JSON.generate(list)) == list)
autotag = JSON.generate('folders' => [{'A. ARCHITECTURAL' => ['A. ']}], 'names' => [{'A. WALL' => %w[Wall Tường]}, {'A. DOOR' => ['Door']}])
ok('nhập file luật của 5D Auto Tag: lấy bảng "names" (tag ← danh sách từ khóa), bỏ bảng thư mục', R.from_json(autotag) == [{'tag' => 'A. WALL', 'keywords' => 'Wall, Tường'}, {'tag' => 'A. DOOR', 'keywords' => 'Door'}])
ok('nhập file hỏng hoặc không có luật: báo lỗi', raises?('json') { R.from_json('{hỏng') } && raises?('không có luật') { R.from_json('[]') } && raises?('không có luật') { R.from_json(JSON.generate('folders' => [])) } && raises?('luật') { R.from_json('123') })
ok('nhập file có luật sai (tên tag rỗng): báo lỗi như kiểm tra thường', raises?('tag') { R.from_json(JSON.generate([{'tag' => '', 'keywords' => 'ab'}])) })
puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
