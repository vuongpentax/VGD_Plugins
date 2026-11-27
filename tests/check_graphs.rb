# Kiểm tra đồ thị Graphify của từng plugin còn khớp code không (chạy từ gốc repo: ruby tests/check_graphs.rb).
# So lần commit đồ thị gần nhất (plugins/<tên>/graphify-out/graph.json) với code hiện tại bằng git:
#   - file code bị thêm, xóa hoặc đổi tên sau lần đó: đồ thị CŨ (thoát mã 1), cần chạy `graphify update .` trong plugin rồi commit lại;
#   - file code chỉ bị sửa nội dung: chỉ nhắc, không lỗi (sửa nhỏ không đổi cấu trúc thì không bắt buộc cập nhật).
# Cần lịch sử git đủ sâu để thấy commit đồ thị; không thấy thì báo "chưa rõ" (không lỗi).
require 'open3'

ROOT = File.expand_path('..', __dir__)
CODE = /\.(rb|js|cjs|mjs|py|ts)\z/
SKIP = %r{(\A|/)(graphify-out|outputs|node_modules)/}

def git(*args)
  out, status = Open3.capture2('git', '-C', ROOT, *args)
  status.success? ? out : nil
end

stale = []
Dir.glob(File.join(ROOT, 'plugins', '*', 'graphify-out', 'graph.json')).sort.each do |graph|
  plugin = File.basename(File.dirname(File.dirname(graph)))
  rel = "plugins/#{plugin}"
  built = git('log', '-1', '--format=%H', '--', "#{rel}/graphify-out/graph.json")&.strip
  if built.nil? || built.empty?
    puts "CHƯA RÕ  #{plugin}: không thấy commit của đồ thị (lịch sử git quá ngắn hoặc chưa commit)"
    next
  end
  changes = (git('diff', '--name-status', '-M', "#{built}", '--', rel) || '').lines.map { |l| l.chomp.split("\t") }
  changes = changes.select { |c| c[1..].any? { |f| f =~ CODE && f !~ SKIP } }
  # untracked chưa nằm trong diff: file code mới tạo cũng tính là thêm
  (git('ls-files', '--others', '--exclude-standard', '--', rel) || '').lines.map(&:chomp).each { |f| changes << ['A', f] if f =~ CODE && f !~ SKIP }
  structural = changes.select { |c| c[0] =~ /\A[ADR]/ }
  modified = changes - structural
  if structural.any?
    stale << plugin
    puts "CŨ       #{plugin}: #{structural.size} file code thêm / xóa / đổi tên sau lần tạo đồ thị (ví dụ #{structural.first.last}). Chạy `graphify update .` trong #{rel} rồi commit graph.json và GRAPH_REPORT.md."
  elsif modified.any?
    puts "NHẮC     #{plugin}: #{modified.size} file code sửa nội dung sau lần tạo đồ thị (cập nhật nếu có đổi tên hàm, lớp)"
  else
    puts "KHỚP     #{plugin}"
  end
end

puts stale.empty? ? 'Không có đồ thị nào cũ về cấu trúc file.' : "CÓ #{stale.size} đồ thị cũ: #{stale.join(', ')}"
exit(stale.empty? ? 0 : 1)
