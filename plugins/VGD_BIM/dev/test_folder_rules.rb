# Test luật xếp tag vào thư mục tag (core/folder_rules.rb): kiểm tra dữ liệu, bộ luật mặc định (thử trên cả 201 tag mẫu), khớp, lưu / đặt lại,
# nhập xuất JSON (kể cả file luật của 5D Auto Tag). Logic thuần, không cần SketchUp. Chạy: ruby dev/test_folder_rules.rb
require 'json'
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_folder_rules')
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def raises?(text = nil); yield; false; rescue ArgumentError => e; text ? e.message.downcase.include?(text) : true; end
module VGD; module BIM; def self.log(_m); end; end; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
%w[storage tags measure tag_rules tag_catalog folder_rules].each { |f| require File.join(ROOT, "core/#{f}") }
R = VGD::BIM::FolderRules
T = VGD::BIM::Tags

# ---- Bộ luật mặc định ----
ok('mặc định: 18 luật, mỗi luật một thư mục trong 18 nhóm của bộ tag (không thiếu, không thừa)', R.default.map { |r| r['folder'] }.sort == T::GROUPS.sort)
ok('mặc định hợp lệ qua kiểm tra dữ liệu', R.sanitize(R.default) == R.default)
ok('mặc định: # MATERIALS đứng trước # BASIC (tag vật liệu như m_brick#1 có chứa "#")', (names = R.default.map { |r| r['folder'] }; names.index('# MATERIALS') < names.index('# BASIC')))
compiled = R.compile(R.default)
placed = VGD::BIM::TagCatalog.clusters.flat_map { |cluster| cluster['tags'].map { |tag| [tag['name'], cluster['group'], (i = R.match(compiled, [tag['name']])) && compiled[i][:tag]] } }
wrong = placed.reject { |_, want, got| want == got }
ok("bộ luật mặc định xếp đúng cả 201 tag mẫu vào đúng cụm của chúng#{wrong.empty? ? '' : " (sai: #{wrong.first(5).inspect})"}", placed.size == 201 && wrong.empty?)
ok('tag lạ không có tiền tố Auto Tag không khớp luật nào (giữ nguyên chỗ cũ)', R.match(compiled, ['Tường 100']).nil? && R.match(compiled, ['Nội thất']).nil?)

# ---- Kiểm tra dữ liệu ----
ok('từ khóa 1 ký tự được nhận (! # @ là tiền tố của Auto Tag), khác luật gắn tag cần từ 2 ký tự', R.sanitize([{'folder' => 'A', 'keywords' => '!'}]) == [{'folder' => 'A', 'keywords' => '!'}] && raises?('ít nhất') { VGD::BIM::TagRules.keywords('!') })
ok('bỏ khoảng trắng thừa ở tên thư mục và từ khóa', R.sanitize([{'folder' => '  A.   ARCH ', 'keywords' => ' A. ,  a1 '}]) == [{'folder' => 'A. ARCH', 'keywords' => 'A., a1'}])
ok('không phải danh sách, quá 100 luật, mục không hợp lệ bị từ chối', raises?('danh sách') { R.sanitize('x') } && raises?('tối đa') { R.sanitize(Array.new(101) { |i| {'folder' => "F#{i}", 'keywords' => 'ab'} }) } && raises?('luật') { R.sanitize([1]) })
ok('thiếu tên thư mục, thiếu từ khóa, tên quá dài bị từ chối, nêu số dòng', raises?('dòng 2') { R.sanitize([{'folder' => 'A', 'keywords' => 'ab'}, {'folder' => '', 'keywords' => 'ab'}]) } && raises?('dòng 1') { R.sanitize([{'folder' => 'A', 'keywords' => ''}]) } && raises?('quá dài') { R.sanitize([{'folder' => 'x' * 61, 'keywords' => 'ab'}]) })
ok('tên thư mục có ký tự điều khiển bị từ chối', raises?('không hợp lệ') { R.sanitize([{'folder' => "A\nB", 'keywords' => 'ab'}]) } && raises?('không hợp lệ') { R.sanitize([{'folder' => "A\u0000", 'keywords' => 'ab'}]) })

# ---- Lưu, đặt lại ----
ok('chưa lưu gì: đọc ra bộ mặc định', R.load == R.default)
saved = R.save([{'folder' => 'Thư mục riêng', 'keywords' => 'riêng, my_'}])
ok('lưu và đọc lại đúng', R.load == saved && saved == [{'folder' => 'Thư mục riêng', 'keywords' => 'riêng, my_'}])
ok('lưu sai: báo lỗi, giữ bộ đã lưu', raises?('dòng 1') { R.save([{'folder' => '', 'keywords' => 'ab'}]) } && R.load == saved)
File.write(File.join(ENV['VGD_BIM_DATA_DIR'], 'tag_folder_rules.json'), '{hỏng')
ok('file luật hỏng: dùng bộ mặc định, không lỗi', R.load == R.default)
R.save([{'folder' => 'X', 'keywords' => 'ab'}])
ok('đặt lại xóa bộ đã lưu', R.reset == R.default && !File.exist?(File.join(ENV['VGD_BIM_DATA_DIR'], 'tag_folder_rules.json')) && R.load == R.default && R.reset == R.default)

# ---- Nhập xuất ----
list = [{'folder' => 'A. ARCHITECTURAL', 'keywords' => 'A.'}, {'folder' => 'S. STRUCTURAL', 'keywords' => 'S., beam'}]
text = R.to_json(list)
ok('xuất JSON có định dạng riêng và nhập lại đúng', JSON.parse(text)['format'] == R::FORMAT && R.from_json(text) == list && R.from_json(JSON.generate(list)) == list)
autotag = JSON.generate('folders' => [{'A. ARCHITECTURAL' => ['A. ']}, {'# BASIC' => ['#', 'edge', 'face']}], 'names' => [{'A. WALL' => ['Wall']}])
ok('nhập file luật của 5D Auto Tag: lấy bảng "folders" (thư mục <- từ khóa), bỏ bảng tên', R.from_json(autotag) == [{'folder' => 'A. ARCHITECTURAL', 'keywords' => 'A.'}, {'folder' => '# BASIC', 'keywords' => '#, edge, face'}])
ok('nhập file hỏng hoặc không có luật: báo lỗi', raises?('json') { R.from_json('{hỏng') } && raises?('không có luật') { R.from_json('[]') } && raises?('không có luật') { R.from_json(JSON.generate('names' => [{'A. WALL' => ['Wall']}])) } && raises?('luật') { R.from_json('123') })
puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
