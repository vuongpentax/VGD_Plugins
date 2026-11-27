# Test hàng đợi kéo trực tiếp (core/live_queue.rb): chỉ giữ giá trị mới nhất, chỉ hẹn giờ một lần cho nhiều giá trị.
# Không cần SketchUp. Chạy: ruby dev/test_live_queue.rb (từ plugins/VGD_Transform)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
ROOT = File.expand_path('../runtime/vgd_transform', __dir__)
require File.join(ROOT, 'core/live_queue')
Q = VGD::Transform::LiveQueue

q = Q.new
ok('hàng đợi mới: không có gì chờ', !q.pending? && q.take.nil?)
ok('giá trị đầu tiên: cần hẹn giờ xử lý', q.push({'v' => 1}) == true)
ok('giá trị tiếp theo khi đã hẹn giờ: không hẹn thêm', q.push({'v' => 2}) == false && q.push({'v' => 3}) == false)
ok('lấy ra: chỉ còn giá trị mới nhất, các giá trị giữa bị bỏ', q.pending? && q.take == {'v' => 3} && !q.pending?)
ok('sau khi lấy ra: giá trị kế tiếp lại cần hẹn giờ', q.push({'v' => 4}) == true)
q.clear
ok('xóa: không còn gì chờ và hẹn giờ lại được', !q.pending? && q.take.nil? && q.push({'v' => 5}) == true)

puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
