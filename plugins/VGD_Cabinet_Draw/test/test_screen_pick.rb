# Test chọn theo khung / theo nét quét trên màn hình (Ruby thuần, không cần SketchUp).
# Chạy: ruby test_screen_pick.rb [thư mục runtime]
$stdout.sync = true
RT = File.expand_path(ARGV[0] || '../runtime/VGD_Cabinet_Draw', __dir__)
module VGD_Cabinet_Draw; end
load File.join(RT, 'screen_pick.rb')
SP = VGD_Cabinet_Draw::ScreenPick
$pass = 0
$fail = []
def check(name, cond, extra = nil)
  if cond then $pass += 1 else $fail << name; puts "FAIL: #{name} #{extra}" end
end

puts '== 1. Bao lồi và khung =='
hull = SP.hull([[0, 0], [10, 0], [10, 10], [0, 10], [5, 5], [5, 5]])
check 'bao lồi bỏ điểm trong và điểm trùng', hull.length == 4, hull.inspect
check 'bao lồi một điểm', SP.hull([[3, 3], [3, 3]]) == [[3, 3]]
check 'khung chuẩn hóa mọi hướng kéo', SP.rect(10, 20, 2, 4) == [2, 4, 10, 20]

puts '== 2. Khung kéo từ trái sang phải: chỉ chọn tấm nằm trọn trong khung =='
plate = SP.hull([[100, 50], [112, 50], [112, 300], [100, 300]]) # tấm đứng mỏng
check 'trọn trong khung lớn', SP.inside_rect?(plate, SP.rect(90, 40, 130, 310))
check 'chỉ chạm một phần: không phải trọn', !SP.inside_rect?(plate, SP.rect(90, 40, 130, 200))

puts '== 3. Khung kéo từ phải sang trái: chọn mọi tấm chạm khung =='
check 'đường ngang mảnh cắt qua tấm đứng', SP.hull_touches_rect?(plate, SP.rect(0, 150, 400, 152))
check 'khung nằm ngoài tấm', !SP.hull_touches_rect?(plate, SP.rect(0, 0, 90, 400))
check 'khung chạm sát mép tấm', SP.hull_touches_rect?(plate, SP.rect(112, 100, 200, 110))
check 'khung hoàn toàn trong tấm (khung nhỏ trong tấm)', SP.hull_touches_rect?(plate, SP.rect(103, 100, 105, 110))
slanted = SP.hull([[0, 0], [100, 100], [110, 100], [10, 0]]) # tấm xiên: bbox rộng nhưng hình thực mảnh
check 'tấm xiên: khung ở góc bbox trống KHÔNG chạm', !SP.hull_touches_rect?(slanted, SP.rect(80, 0, 110, 10))
check 'tấm xiên: khung trên thân tấm chạm', SP.hull_touches_rect?(slanted, SP.rect(48, 48, 56, 56))
edge_on = SP.hull([[200, 10], [200, 90]]) # tấm nhìn thẳng cạnh: chỉ còn là một đoạn
check 'tấm thành đoạn thẳng: khung cắt qua chạm', SP.hull_touches_rect?(edge_on, SP.rect(190, 40, 210, 60))
check 'tấm thành đoạn thẳng: khung bên cạnh không chạm', !SP.hull_touches_rect?(edge_on, SP.rect(205, 40, 220, 60))

puts '== 4. Quét như cọ: tấm nào nét đi qua thì chọn =='
path = [[0, 120], [60, 120], [150, 120]]
check 'nét ngang đi qua tấm đứng', SP.touched_by_path?(plate, path)
check 'nét dừng trước tấm: không chọn', !SP.touched_by_path?(plate, [[0, 120], [60, 120]])
check 'nét chỉ một điểm nằm trên tấm', SP.touched_by_path?(plate, [[105, 100]])
check 'nét lướt gần tấm trong dung sai 2 px', SP.touched_by_path?(plate, [[98, 100], [98, 200]], 2.0)
check 'nét xa tấm hơn dung sai', !SP.touched_by_path?(plate, [[90, 100], [90, 200]], 2.0)
check 'nét không có điểm nào', !SP.touched_by_path?(plate, [])

puts '== 5. Chạm điểm (click chọn một tấm) =='
check 'click trên tấm', SP.hull_touches_point?(plate, [105, 200], 3.0)
check 'click lệch 2 px vẫn trúng', SP.hull_touches_point?(plate, [114, 200], 3.0)
check 'click xa tấm', !SP.hull_touches_point?(plate, [130, 200], 3.0)

puts "\nĐạt: #{$pass}   Không đạt: #{$fail.length}"
exit($fail.empty? ? 0 : 1)
