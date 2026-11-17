# SketchUp giả lập tối thiểu cho test VGD Structure (không thay SketchUp thật): chỉ mô phỏng phần API mà mã dùng.
# Đơn vị: Numeric#mm trả về inch như SketchUp thật; hộp bao của chữ 3D giả lập là hình chữ nhật căn giữa theo ngang, đáy ở gốc.
class Numeric; def mm; self / 25.4; end; end
TextAlignCenter = 1
MB_YESNO = 4
IDYES = 6
module Geom
  class Point3d
    attr_reader :x, :y, :z
    def initialize(x, y, z); @x = x.to_f; @y = y.to_f; @z = z.to_f; end
  end
  class Vector3d
    attr_reader :x, :y, :z
    def initialize(x, y, z); @x = x.to_f; @y = y.to_f; @z = z.to_f; end
  end
  class Transformation
    attr_reader :vector
    def self.translation(vector); new(vector); end
    # Transformation.new(Point3d) dời tới điểm đó (như SketchUp); translation(Vector3d) dời theo vector.
    def initialize(vector = Vector3d.new(0, 0, 0)); @vector = vector; end
  end
end
module Sketchup
  class Color
    attr_reader :rgb
    def initialize(*rgb); @rgb = rgb; end
  end
  class Entity
    def attrs; @attrs ||= {}; end
    def set_attribute(dict, key, value); (attrs[dict] ||= {})[key] = value; end
    def get_attribute(dict, key, default = nil); (attrs[dict] || {}).fetch(key, default); end
  end
  class Edge < Entity
    attr_accessor :layer
    attr_reader :from, :to
    def initialize(from, to); @from = from; @to = to; end
  end
  class Group < Entity
    attr_accessor :name, :layer
    attr_reader :entities, :offset
    def initialize(parent); @parent = parent; @entities = FakeEntities.new; @valid = true; @locked = false; @offset = [0.0, 0.0]; end
    def valid?; @valid; end
    def locked?; @locked; end
    def lock!; @locked = true; end
    def erase!; @valid = false; @parent.items.delete(self); end
    def transform!(t); @offset = [@offset[0] + t.vector.x, @offset[1] + t.vector.y]; self; end
    # Hộp bao của nhóm chữ: giả lập chữ rộng 0,6 x cao, đáy ở y = 0, căn giữa theo ngang, rồi cộng phần dời của nhóm.
    def bounds
      text = entities.items.find { |i| i.is_a?(Array) && i.first == :text }
      w = text ? text[1].length * text[2] * 0.6 : 0
      h = text ? text[2] : 0
      Struct.new(:center).new(Geom::Point3d.new(offset[0], offset[1] + h / 2.0, 0)).tap { |b| b.center }
    end
    def texts; entities.items.select { |i| i.is_a?(Array) && i.first == :text }; end
  end
  class Face < Entity
    attr_reader :points, :height
    def initialize(points); @points = points; @reversed = false; end
    # Chiều pháp tuyến theo diện tích có dấu (shoelace) của cả đa giác: đúng cả khi có đỉnh lõm. Ngược chiều kim đồng hồ nhìn từ trên = hướng lên.
    def normal
      z = points.each_with_index.sum { |p, i| q = points[(i + 1) % points.size]; p.x * q.y - q.x * p.y }
      Struct.new(:z).new(@reversed ? -z : z)
    end
    def reverse!; @reversed = !@reversed; end
    def pushpull(distance); @height = distance; end
  end
  class ComponentDefinition < Entity
    attr_reader :name, :entities
    def initialize(name); @name = name; @entities = FakeEntities.new; end
    def valid?; true; end
  end
  class Instance < Entity
    attr_accessor :name, :layer
    attr_reader :definition, :transformation
    def initialize(definition, transformation); @definition = definition; @transformation = transformation; end
  end
  class Definitions
    attr_reader :list
    def initialize; @list = []; end
    def [](name); @list.find { |d| d.name == name }; end
    def add(name); d = ComponentDefinition.new(name); @list << d; d; end
  end
  class FakeEntities
    attr_reader :items
    def initialize; @items = []; end
    def add_group; g = Group.new(self); @items << g; g; end
    def add_face(points); f = Face.new(points); @items << f; f; end
    def add_instance(definition, transformation); i = Instance.new(definition, transformation); @items << i; i; end
    def add_line(a, b); e = Edge.new(a, b); @items << e; e; end
    def add_circle(center, normal, radius, segments); (0...segments).map { |i| e = Edge.new(center, radius); @items << e; e }.tap { |l| (@circles ||= []) << [center, radius, segments] }
    end
    def circles; @circles ||= []; end
    def add_3d_text(text, align, font, bold, italic, height, tolerance, z, filled, extrusion)
      raise 'lỗi giả lập khi tạo chữ' if $fail_text
      @items << [:text, text, height, align, font, filled, z, extrusion]
    end
    def grep(klass); @items.select { |i| i.is_a?(klass) }; end
    def to_a; @items.dup; end
  end
  class Layer
    attr_reader :name
    attr_accessor :color, :line_style, :folder
    def initialize(name); @name = name; end
  end
  class LineStyle
    attr_reader :name
    def initialize(name); @name = name; end
  end
  class Folder
    attr_reader :name
    def initialize(name); @name = name; end
  end
  class Layers
    include Enumerable
    def initialize; @list = []; @folders = []; end
    def [](name); @list.find { |l| l.name == name }; end
    def add(name); l = Layer.new(name); @list << l; l; end
    def each(&b); @list.each(&b); end
    def folders; @folders; end
    def add_folder(name); f = Folder.new(name); @folders << f; f; end
  end
  class Model
    attr_reader :entities, :layers, :operations, :line_styles, :definitions
    def initialize(styles: ['Solid Line', 'Dotted Line', 'Short Dashes Line', 'Dash Dot Line'])
      @entities = FakeEntities.new; @definitions = Definitions.new; @layers = Layers.new; @operations = []; @attrs = {}
      @line_styles = styles.map { |n| LineStyle.new(n) }
    end
    def start_operation(name, disable); @operations << [:start, name]; end
    def commit_operation; @operations << [:commit]; end
    def abort_operation; @operations << [:abort]; end
    def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; end
    def get_attribute(dict, key, default = nil); (@attrs[dict] || {}).fetch(key, default); end
    def active_model; self; end
  end
  def self.active_model; $model; end
end
