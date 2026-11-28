# encoding: UTF-8
# Kiểm tra lấy hình học 3D (scene.rb) bằng đối tượng giả lập SketchUp. Chạy từ plugins/VGD_Diagram: ruby dev/test_scene.rb
$LOAD_PATH.unshift File.expand_path('../runtime/vgd_diagram', __dir__)

module Geom
  class Point3d
    attr_reader :values

    def initialize(*values)
      @values = values
    end

    def to_a
      @values
    end
  end

  class Transformation
    attr_reader :offset

    def initialize(offset = [0.0, 0.0, 0.0])
      @offset = offset
    end

    # Hợp hai biến đổi (chỉ tịnh tiến, đủ cho test) hoặc áp lên một điểm.
    def *(other)
      case other
      when Transformation then Transformation.new(sum(offset, other.offset))
      when Point3d then Point3d.new(*sum(offset, other.to_a))
      else raise ArgumentError, 'không hỗ trợ'
      end
    end

    private

    def sum(a, b)
      a.zip(b).map { |x, y| x + y }
    end
  end
end

module Sketchup
  class Entity
    attr_reader :entityID

    def initialize(id, name = '')
      @entityID = id
      @name = name
      @attributes = {}
    end

    attr_reader :name

    def get_attribute(dict, key)
      @attributes[[dict, key]]
    end

    def set_attribute(dict, key, value)
      @attributes[[dict, key]] = value
    end
  end

  class Group < Entity
    attr_reader :entities, :transformation

    def initialize(id, name, entities, transformation = Geom::Transformation.new)
      super(id, name)
      @entities = entities
      @transformation = transformation
    end
  end

  class ComponentDefinition
    attr_reader :name, :entities

    def initialize(name, entities)
      @name = name
      @entities = entities
    end
  end

  class ComponentInstance < Entity
    attr_reader :definition, :transformation

    def initialize(id, definition, transformation = Geom::Transformation.new)
      super(id, '')
      @definition = definition
      @transformation = transformation
    end
  end

  class MeshStub
    attr_reader :polygons

    def initialize(points, polygons)
      @points = points
      @polygons = polygons
    end

    # Chỉ số SketchUp bắt đầu từ 1.
    def point_at(index)
      @points.fetch(index - 1)
    end
  end

  class Face
    def initialize(points, polygons)
      @points = points
      @polygons = polygons
    end

    def mesh(_flags = 0)
      MeshStub.new(@points, @polygons)
    end
  end

  class FakeModel
    attr_reader :entities

    def initialize(entities)
      @entities = entities
    end
  end
end

require 'model_io'
require 'scene'

$pass = 0
$fail = []
def check(name, condition)
  condition ? $pass += 1 : $fail << name
  puts "#{condition ? 'OK  ' : 'FAIL'} #{name}"
end

S = VGD::Diagram::Scene
P = Geom::Point3d

square = [P.new(0, 0, 0), P.new(1, 0, 0), P.new(1, 1, 0), P.new(0, 1, 0)]
quad = Sketchup::Face.new(square, [[1, 2, 3, 4]])

# 1. Một đa giác bốn đỉnh thành hai tam giác, đổi sang mm
model = Sketchup::FakeModel.new([quad])
scene = S.build(model)
check 'một hình vuông cho hai tam giác (18 số)', scene['parts'].size == 1 && scene['parts'][0]['positions'].size == 18
check 'đỉnh (1,0,0) inch đổi thành 25 mm', scene['parts'][0]['positions'][3, 3] == [25, 0, 0]
check 'phần Khác không có id khi là mặt gốc', scene['parts'][0]['id'].nil? && scene['parts'][0]['name'] == 'Khác'
check 'không vượt giới hạn', scene['truncated'] == false && scene['triangles'] == 2

# 2. Biến đổi lồng nhau: cha dịch x=1, con dịch y=2 (inch)
child_face = Sketchup::Face.new([P.new(0, 0, 0), P.new(1, 0, 0), P.new(0, 1, 0)], [[1, 2, 3]])
child = Sketchup::Group.new(7, 'Đáy', [child_face], Geom::Transformation.new([0.0, 2.0, 0.0]))
parent = Sketchup::Group.new(5, 'Tủ', [child], Geom::Transformation.new([1.0, 0.0, 0.0]))
nested = S.build(Sketchup::FakeModel.new([parent]))
first_point = nested['parts'][0]['positions'][0, 3]
check 'mảnh chỉ có mặt của bản con, mang id bản con', nested['parts'].size == 1 && nested['parts'][0]['id'] == 7
check 'tọa độ đã cộng biến đổi cha và con (1,2,0) inch', first_point == [25, 51, 0]

# 3. Chỉ số âm (cạnh làm mượt) lấy trị tuyệt đối
smooth = Sketchup::Face.new(square, [[-1, 2, -3, 4]])
smooth_scene = S.build(Sketchup::FakeModel.new([smooth]))
check 'chỉ số âm vẫn cho đủ hai tam giác', smooth_scene['parts'][0]['positions'].size == 18

# 4. Thứ tự lấy từ thuộc tính của bản
ordered = Sketchup::Group.new(9, 'Chân', [quad])
ordered.set_attribute(VGD::Diagram::ModelIO::DICT, VGD::Diagram::ModelIO::KEY_ORDER, 4)
ordered_scene = S.build(Sketchup::FakeModel.new([ordered]))
check 'mảnh lấy đúng thứ tự lắp và tên', ordered_scene['parts'][0]['order'] == 4 && ordered_scene['parts'][0]['name'] == 'Chân'

# 5. Giới hạn số tam giác: dừng và báo đã cắt
S.send(:remove_const, :MAX_TRIANGLES)
S.const_set(:MAX_TRIANGLES, 3)
capped = S.build(Sketchup::FakeModel.new([quad, Sketchup::Face.new(square, [[1, 2, 3, 4]])]))
check 'vượt giới hạn: dừng ở đúng giới hạn và báo truncated', capped['truncated'] && capped['triangles'] == 3
S.send(:remove_const, :MAX_TRIANGLES)
S.const_set(:MAX_TRIANGLES, 100_000)

# 6. Mô hình rỗng
empty = S.build(Sketchup::FakeModel.new([]))
check 'mô hình rỗng: không có mảnh nào', empty['parts'].empty? && empty['triangles'] == 0

puts
puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "CÓ #{$fail.size} LỖI: #{$fail.inspect}"
exit($fail.empty? ? 0 : 1)
