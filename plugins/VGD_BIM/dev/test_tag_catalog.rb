# Test thư viện tag mẫu (core/tag_catalog.rb, dữ liệu config/tag_catalog.json): 18 cụm, 201 tag theo bộ mặc định của 5D Auto Tag.
# Chạy: ruby dev/test_tag_catalog.rb
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def raises?(text = nil); yield; false; rescue ArgumentError => e; text ? e.message.downcase.include?(text) : true; end
module VGD; module BIM; def self.log(_m); end; end; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
%w[storage tags tag_catalog].each { |f| require File.join(ROOT, "core/#{f}") }
C = VGD::BIM::TagCatalog
T = VGD::BIM::Tags

ok('18 cụm, đúng tên và thứ tự 18 nhóm của bộ tag', C.clusters.map { |c| c['group'] } == T::GROUPS)
names = C.clusters.flat_map { |c| c['tags'].map { |t| t['name'] } }
ok('201 tag, không trùng tên (không phân biệt hoa thường)', names.size == 201 && names.map { |n| T.key(n) }.uniq.size == 201)
ok('mọi tên tag hợp lệ để đưa vào bộ tag (không rỗng, không quá dài, không phải Untagged)', (T.validate(names.map { |n| {'name' => n, 'group' => T::DEFAULT_GROUP} }); true))
ok('số tag từng cụm đúng như Auto Tag: INFORMATION 9, BASIC 17, ARCHITECTURAL 15, MECHANICAL 24, EQUIPMENT 25, STRUCTURAL 11, MATERIALS 25, FIRE PROTECTION 1', {'! INFORMATION' => 9, '# BASIC' => 17, 'A. ARCHITECTURAL' => 15, 'M. MECHANICAL' => 24, 'Q. EQUIPMENT' => 25, 'S. STRUCTURAL' => 11, '# MATERIALS' => 25, 'F. FIRE PROTECTION' => 1}.all? { |g, n| C.clusters.find { |c| c['group'] == g }['tags'].size == n })
arch = C.clusters.find { |c| c['group'] == 'A. ARCHITECTURAL' }['tags'].map { |t| t['name'] }
ok('cụm A. ARCHITECTURAL có đủ 5 tag của bộ luật mặc định', %w[A.\ WALL A.\ WINDOW A.\ DOOR A.\ RAILING A.\ STAIR].all? { |n| arch.include?(n) })
ok('mô tả tiếng Việt kèm theo: A. WALL = Tường, A. DOOR = Cửa đi, cụm Kết cấu', C.clusters.find { |c| c['group'] == 'A. ARCHITECTURAL' }['tags'].find { |t| t['name'] == 'A. WALL' }['vi'] == 'Tường' && C.clusters.find { |c| c['group'] == 'S. STRUCTURAL' }['label_vi'] == 'Kết cấu')

picked = C.tags_for(['F. FIRE PROTECTION', 'A. ARCHITECTURAL'])
ok('tags_for: tag của các cụm đã chọn theo thứ tự thư viện, mỗi tag mang nhóm của cụm (dạng bộ tag của BIM)', picked.size == 16 && picked.first == {'name' => 'A. CHIMNEY', 'group' => 'A. ARCHITECTURAL'} && picked.last == {'name' => 'F. FIRE SUPPRESSION', 'group' => 'F. FIRE PROTECTION'})
ok('tags_for: cụm nhập hai lần chỉ tính một lần', C.tags_for(['A. ARCHITECTURAL', 'A. ARCHITECTURAL']).size == 15)
ok('tags_for: chưa chọn cụm nào hoặc không phải danh sách bị từ chối', raises?('cụm') { C.tags_for([]) } && raises?('cụm') { C.tags_for(nil) } && raises?('cụm') { C.tags_for('A. ARCHITECTURAL') })
ok('tags_for: cụm lạ bị từ chối, không nhận tên nhóm cũ', raises?('không hợp lệ') { C.tags_for(['Phần thô']) } && raises?('không hợp lệ') { C.tags_for(['a. architectural']) })
summary = C.summary
ok('summary cho giao diện: nhóm, nhãn tiếng Việt, số tag và danh sách tên', summary.size == 18 && summary[6] == {group: 'A. ARCHITECTURAL', label_vi: 'Kiến trúc', count: 15, tags: arch})
ok('tổng 18 cụm trong summary cộng lại 201 tag', summary.sum { |c| c[:count] } == 201)
puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
exit($fails.zero? ? 0 : 1)
