# encoding: UTF-8
# Kiểm tra logic sơ đồ và đọc/ghi model giả lập (không cần SketchUp).
# Chạy từ plugins/VGD_Diagram: ruby dev/test_tree.rb
$LOAD_PATH.unshift File.expand_path('../runtime/vgd_diagram', __dir__)

# Giả lập tối thiểu các lớp của SketchUp mà model_io.rb dùng.
module Sketchup
  class Entity
    attr_reader :entityID, :attributes
    attr_accessor :name

    def initialize(id, name = '')
      @entityID = id
      @name = name
      @attributes = {}
    end

    def get_attribute(dict, key)
      @attributes[[dict, key]]
    end

    def set_attribute(dict, key, value)
      @attributes[[dict, key]] = value
    end

    def delete_attribute(dict, key)
      @attributes.delete([dict, key])
    end
  end

  class Group < Entity
    attr_reader :entities

    def initialize(id, name = '', entities = [])
      super(id, name)
      @entities = entities
    end
  end

  class ComponentDefinition
    attr_reader :name, :entities

    def initialize(name, entities = [])
      @name = name
      @entities = entities
    end
  end

  class ComponentInstance < Entity
    attr_reader :definition

    def initialize(id, definition, name = '')
      super(id, name)
      @definition = definition
    end
  end

  class FakeSelection
    attr_reader :items

    def initialize
      @items = []
    end

    def clear
      @items = []
    end

    def add(list)
      @items.concat(Array(list))
    end
  end

  class FakeModel
    attr_reader :entities, :selection, :log

    def initialize(entities)
      @entities = entities
      @selection = FakeSelection.new
      @log = []
    end

    def find_entity_by_id(id)
      all = []
      walk = lambda do |list|
        list.each do |entity|
          all << entity
          walk.call(entity.is_a?(Group) ? entity.entities : entity.is_a?(ComponentInstance) ? entity.definition.entities : [])
        end
      end
      walk.call(@entities)
      all.find { |entity| entity.entityID == id }
    end

    def start_operation(name, _disable_ui)
      @log << [:start, name]
    end

    def commit_operation
      @log << [:commit]
    end

    def abort_operation
      @log << [:abort]
    end
  end
end

require 'tree'
require 'model_io'

$pass = 0
$fail = []
def check(name, condition)
  condition ? $pass += 1 : $fail << name
  puts "#{condition ? 'OK  ' : 'FAIL'} #{name}"
end

def raises?(message_part)
  yield
  false
rescue ArgumentError => error
  error.message.include?(message_part)
end

T = VGD::Diagram::Tree
M = VGD::Diagram::ModelIO

def raw(id, name, order = nil, children = [])
  { 'id' => id, 'name' => name, 'order' => order, 'children' => children }
end

# 1. Gom cấu kiện giống nhau cùng cấp
legs = [raw(1, 'Chân'), raw(2, 'Chân'), raw(3, 'Chân'), raw(4, 'Chân')]
nodes = T.build(legs)
check 'bốn chân giống nhau gom thành một dòng', nodes.size == 1
check 'dòng gom có số lượng 4', nodes.first['count'] == 4
check 'dòng gom giữ đủ 4 id', nodes.first['ids'].sort == [1, 2, 3, 4]

# 2. Cùng tên nhưng khác cấu trúc con thì không gom
different = [raw(5, 'Thân', nil, [raw(6, 'Đợt')]), raw(7, 'Thân', nil, [])]
check 'cùng tên, khác con thì tách hai dòng', T.build(different).size == 2

# 3. Sắp theo thứ tự lắp: có số trước (tăng dần), chưa đặt xuống cuối
sorted = T.build([raw(10, 'C', nil), raw(11, 'B', 2), raw(12, 'A', 1)])
check 'sắp theo thứ tự lắp, chưa đặt xuống cuối', sorted.map { |n| n['name'] } == %w[A B C]

# 4. Các bản trong nhóm có thứ tự khác nhau thì đánh dấu mixed
mixed = T.build([raw(20, 'Cánh', 1), raw(21, 'Cánh', 2)])
check 'thứ tự khác nhau trong nhóm: mixed và order nil', mixed.first['mixed'] && mixed.first['order'].nil?

# 5. Chuẩn hóa số thứ tự người dùng nhập
check 'để trống thì nil', T.parse_order('  ').nil?
check 'nhập 12 (có khoảng trắng) thì 12', T.parse_order(' 12 ') == 12
check 'số nguyên dạng Integer được chấp nhận', T.parse_order(3) == 3
check 'số 0 bị từ chối', raises?('từ 1 đến') { T.parse_order('0') }
check 'vượt 9999 bị từ chối', raises?('từ 1 đến') { T.parse_order('10000') }
check 'chữ bị từ chối', raises?('phải là số nguyên') { T.parse_order('abc') }
check 'số thập phân bị từ chối', raises?('phải là số nguyên') { T.parse_order('1.5') }

# 6. Kiểm tra trùng số thứ tự trong cùng cấp
tree = T.build([raw(30, 'Đáy'), raw(31, 'Hông'), raw(32, 'Nóc')])
key_day = T.find(tree, 30)['key']
key_side = T.find(tree, 31)['key']
key_top = T.find(tree, 32)['key']
plan_ok = T.plan(tree, { key_day => '1', key_side => '2' })
check 'số thứ tự không trùng thì qua', plan_ok == { key_day => 1, key_side => 2 }
duplicate_message = begin
  T.plan(tree, { key_day => '1', key_side => '1' })
  ''
rescue ArgumentError => error
  error.message
end
check 'trùng số trong cùng cấp thì báo lỗi kèm cả hai tên',
      duplicate_message.include?('trùng') && duplicate_message.include?("'Đáy'") && duplicate_message.include?("'Hông'")
existing = T.build([raw(40, 'A', 5), raw(41, 'B')])
check 'đặt B thành 5 khi A đã có 5 cùng cấp thì báo lỗi',
      raises?('Thứ tự 5 trùng') { T.plan(existing, { T.find(existing, 41)['key'] => '5' }) }
check 'để trống một cấu kiện thì qua', T.plan(tree, { key_top => '' }) == { key_top => nil }
check 'khóa không tồn tại thì báo làm mới', raises?('làm mới') { T.plan(tree, { 999_999 => '1' }) }

# 7. Cây lồng nhau: số thứ tự ở cấp con chỉ so với anh em cùng cấp
nested = T.build([raw(50, 'Tủ', nil, [raw(51, 'Cánh', 1), raw(52, 'Hộc', 1)])])
cabinet_children = T.find(nested, 50)['children']
check 'cấp con: hai nút cùng số 1 nhưng khác cấp thì không cần nút cha đổi',
      T.plan(nested, { T.find(nested, 50)['children'].first['key'] => '2' }) == { cabinet_children.first['key'] => 2 }

# 8. Xuất SVG
svg = T.svg(T.build([raw(60, 'Thân', 1, [raw(61, 'Đáy <lớn>', nil), raw(62, 'Cánh & kính')]), raw(63, 'Chân'), raw(64, 'Chân')]))
check 'SVG bắt đầu bằng khai báo XML và thẻ svg', svg.start_with?('<?xml') && svg.include?('<svg ') && svg.rstrip.end_with?('</svg>')
check 'SVG có số thứ tự và số lượng', svg.include?('1. Thân') && svg.include?('× 2')
check 'SVG thoát ký tự đặc biệt', svg.include?('Đáy &lt;lớn&gt;') && svg.include?('Cánh &amp; kính') && !svg.include?('<lớn>')
check 'SVG cho model rỗng vẫn hợp lệ', T.svg([]).include?('Chưa có cấu kiện nào')

# 8b. Đánh số nhóm có hình học và bảng CSV (thứ tự cây: 'Chân' trước 'Tủ' vì sắp theo tên)
numbered_src = T.build([raw(70, 'Tủ', nil, [raw(71, 'Cánh', nil), raw(72, 'Cánh, lớn', 2)]), raw(73, 'Chân')])
numbered = T.number(numbered_src, [71, 72, 73])
cabinet = numbered.find { |n| n['name'] == 'Tủ' }
check 'đánh số: nhóm cha không có hình học thì không được số', cabinet['number'].nil?
check 'đánh số: Chân (đứng đầu cây) được số 1', numbered.find { |n| n['name'] == 'Chân' }['number'] == 1
check 'đánh số: các nhóm con được số 2 và 3 theo thứ tự cây',
      cabinet['children'].map { |n| n['number'] } == [2, 3]
csv = T.csv(numbered)
check 'CSV: có BOM và dòng tiêu đề', csv.start_with?("\uFEFFSố,Tên,Số lượng,Thứ tự lắp\r\n")
check 'CSV: tên có dấu phẩy được đặt trong ngoặc kép', csv.include?('"Cánh, lớn"')
check 'CSV: chỉ liệt kê nhóm được đánh số (1 tiêu đề + 3 dòng)', csv.split("\r\n").size == 4
check 'CSV: nhóm không có hình học không xuất hiện', !csv.include?('Tủ')

# 9. Đọc cây từ model giả lập
body_def = Sketchup::ComponentDefinition.new('Thân tủ', [])
inner = Sketchup::Group.new(101, 'Đáy')
cabinet_def = Sketchup::ComponentDefinition.new('Tủ', [inner])
cab1 = Sketchup::ComponentInstance.new(100, cabinet_def, '')
cab2 = Sketchup::ComponentInstance.new(103, cabinet_def, '')
loose_face = Object.new
model = Sketchup::FakeModel.new([cab1, cab2, loose_face])
read = M.read_tree(model)
check 'đọc: component không tên lấy tên definition', read.first['name'] == 'Tủ'
check 'đọc: hai tủ giống nhau gom thành một dòng', read.size == 1 && read.first['count'] == 2
check 'đọc: đối tượng không phải Group/Component bị bỏ qua', read.first['children'].first['name'] == 'Đáy'

# 10. Ghi thứ tự: vào mọi bản, có Undo, xóa khi để trống
key = read.first['key']
M.apply_orders(model, read, { key => 3 })
check 'ghi: mọi bản đều có thứ tự 3', cab1.get_attribute(M::DICT, M::KEY_ORDER) == 3 && cab2.get_attribute(M::DICT, M::KEY_ORDER) == 3
check 'ghi: bọc trong một thao tác Undo', model.log.first == [:start, 'VGD Diagram: thứ tự lắp'] && model.log.last == [:commit]
after = M.read_tree(model)
check 'đọc lại: thứ tự được giữ', after.first['order'] == 3
M.apply_orders(model, after, { after.first['key'] => nil })
check 'ghi nil: xóa thuộc tính thứ tự', cab1.get_attribute(M::DICT, M::KEY_ORDER).nil?

# 11. Lỗi giữa chừng thì hủy thao tác
broken = Sketchup::FakeModel.new([cab1])
def broken.find_entity_by_id(_id)
  raise 'mất kết nối model'
end
failed = begin
  M.apply_orders(broken, M.read_tree(Sketchup::FakeModel.new([cab1])), { cab1.entityID => 1 })
  false
rescue RuntimeError
  broken.log.include?([:abort])
end
check 'lỗi khi ghi: hủy thao tác (abort) và báo lỗi ra ngoài', failed

# 12. Chọn: chỉ chọn các bản còn tồn tại
sel_model = Sketchup::FakeModel.new([cab1, cab2])
count = M.select(sel_model, [100, 103, 999])
check 'chọn: bỏ id đã mất, chọn đủ bản còn lại', count == 2 && sel_model.selection.items == [cab1, cab2]

puts
puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "CÓ #{$fail.size} LỖI: #{$fail.inspect}"
exit($fail.empty? ? 0 : 1)
