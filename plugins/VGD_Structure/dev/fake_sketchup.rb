# SketchUp giả lập tối thiểu cho test VGD Structure (không thay SketchUp thật): chỉ mô phỏng phần API mà mã dùng.
# Đơn vị: Numeric#mm trả về inch như SketchUp thật; hộp bao của chữ 3D giả lập là hình chữ nhật căn giữa theo ngang, đáy ở gốc.
class Numeric; def mm; self / 25.4; end; def to_mm; self * 25.4; end; end
TextAlignCenter = 1
GL_LINES = 1
GL_QUADS = 7
MB_YESNO = 4
IDYES = 6
module Geom
  class Point3d
    attr_reader :x, :y, :z
    def initialize(x, y, z); @x = x.to_f; @y = y.to_f; @z = z.to_f; end
  end
  class Vector3d
    attr_reader :x, :y, :z
    def length; Math.sqrt(@x * @x + @y * @y + @z * @z); end
    def initialize(x, y, z); @x = x.to_f; @y = y.to_f; @z = z.to_f; end
  end
  class Transformation
    attr_reader :vector, :angle
    def self.translation(vector); new(vector); end
    # Phép xoay quanh trục đứng qua gốc (giả lập chỉ cần góc, radian); `*` ghép dời với xoay như SketchUp (xoay trước rồi dời).
    def self.rotation(_point, _axis, radians); new(Vector3d.new(0, 0, 0), radians); end
    # Transformation.new(Point3d) dời tới điểm đó (như SketchUp); translation(Vector3d) dời theo vector.
    def initialize(vector = Vector3d.new(0, 0, 0), angle = 0.0); @vector = vector; @angle = angle; end
    # Ghép như SketchUp: áp `other` trước (xoay quanh gốc rồi dời), sau đó áp phép này.
    def *(other)
      cs = Math.cos(@angle); sn = Math.sin(@angle)
      return Point3d.new(@vector.x + other.x * cs - other.y * sn, @vector.y + other.x * sn + other.y * cs, @vector.z + other.z) if other.is_a?(Point3d)
      ov = other.vector
      Transformation.new(Vector3d.new(@vector.x + ov.x * cs - ov.y * sn, @vector.y + ov.x * sn + ov.y * cs, @vector.z + ov.z), @angle + other.angle)
    end
    def origin; Point3d.new(@vector.x, @vector.y, @vector.z); end
    def xaxis; Vector3d.new(Math.cos(@angle), Math.sin(@angle), 0); end
    def yaxis; Vector3d.new(-Math.sin(@angle), Math.cos(@angle), 0); end
    def zaxis; @tilt ? Vector3d.new(Math.sin(@tilt), 0, Math.cos(@tilt)) : Vector3d.new(0, 0, 1); end
    def with_tilt(deg); @tilt = deg * Math::PI / 180.0; self; end # giả lập đối tượng bị nghiêng
    def rotation_degrees; @angle * 180.0 / Math::PI; end
  end
end
module Sketchup
  class Color
    attr_reader :rgb
    def initialize(*rgb); @rgb = rgb; end
    def alpha; @rgb[3] || 255; end
  end
  class Entity
    def entityID; @entity_id ||= (Entity.next_id += 1); end
    class << self; attr_accessor :next_id; end
    self.next_id = 1000
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
    attr_accessor :name, :layer, :material
    attr_reader :entities, :offset
    def initialize(parent); @parent = parent; @entities = FakeEntities.new; @valid = true; @locked = false; @offset = [0.0, 0.0]; end
    def valid?; @valid; end
    def locked?; @locked; end
    def lock!; @locked = true; end
    def erase!; @valid = false; @parent.items.delete(self); end
    def transformation; Geom::Transformation.new(Geom::Vector3d.new(@offset[0], @offset[1], 0)); end
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
    attr_accessor :erased
    def initialize(points); @points = points; @reversed = false; @erased = false; end
    # Pháp tuyến theo phương pháp Newell (đúng cho đa giác phẳng bất kỳ, kể cả có đỉnh lõm và mặt đứng). Ngược chiều kim đồng hồ nhìn từ phía pháp tuyến.
    def normal
      nx = ny = nz = 0.0
      points.each_with_index do |p, i|
        q = points[(i + 1) % points.size]
        nx += (p.y - q.y) * (p.z + q.z)
        ny += (p.z - q.z) * (p.x + q.x)
        nz += (p.x - q.x) * (p.y + q.y)
      end
      sign = @reversed ? -1 : 1
      Struct.new(:x, :y, :z).new(sign * nx, sign * ny, sign * nz)
    end
    def reverse!; @reversed = !@reversed; end
    def pushpull(distance); @height = distance; end
    def erase!; @erased = true; end
  end
  class FakeBounds
    attr_reader :width, :height, :depth, :center
    def initialize(w, h, d, center); @width = w; @height = h; @depth = d; @center = center; end
  end
  class ComponentDefinition < Entity
    attr_accessor :fake_bounds
    def bounds; @fake_bounds; end
    attr_reader :name, :entities
    def initialize(name); @name = name; @entities = FakeEntities.new; end
    def valid?; true; end
  end
  class Instance < Entity
    attr_accessor :name, :layer
    attr_reader :definition, :transformation
    def initialize(definition, transformation, parent = nil); @definition = definition; @transformation = transformation; @parent = parent; @valid = true; end
    def valid?; @valid; end
    def locked?; false; end
    attr_accessor :layer, :name
    def erase!; @valid = false; @parent.items.delete(self) if @parent; end
    # Giả lập người dùng dời / xoay thể hiện (Move, Rotate): dời thêm (dx, dy) mm và xoay thêm `deg` quanh gốc của nó.
    def fake_move(dx, dy, deg = 0)
      v = @transformation.vector
      @transformation = Geom::Transformation.new(Geom::Vector3d.new(v.x + dx.mm, v.y + dy.mm, v.z), @transformation.angle + deg * Math::PI / 180.0)
    end
  end
  ComponentInstance = Instance
  class SelectionObserver; end
  # Vùng chọn giả lập: danh sách entity, có thể gắn observer (gọi lại khi đổi).
  class Selection
    include Enumerable
    attr_reader :observers
    def initialize; @items = []; @observers = []; end
    def add_observer(o); @observers << o; true; end
    def remove_observer(o); @observers.delete(o); true; end
    def each(&b); @items.each(&b); end
    def clear; @items.clear; notify(:onSelectionCleared); end
    def add(e); @items << e unless @items.include?(e); notify(:onSelectionAdded, e); end
    def to_a; @items.dup; end
    def include?(e); @items.include?(e); end
    def notify(name, *args); @observers.each { |o| o.public_send(name, self, *args) if o.respond_to?(name) }; end
  end
  # Điểm nhập giả lập: kiểm tra đặt vị trí rồi gọi pick.
  class InputPoint
    attr_accessor :fake_position
    def initialize; @pos = nil; end
    def pick(view, x, y); @pos = view.fake_points ? view.fake_points[[x, y]] : nil; end
    def valid?; !@pos.nil?; end
    def position; @pos; end
    def tooltip; 'Đầu mút'; end
    def draw(view); view.drawn = true; end
  end
  class FakeView
    attr_accessor :fake_points, :tooltip, :drawn, :drawing_color, :line_width
    attr_reader :invalidated, :draw_calls
    def initialize(points = {}); @fake_points = points; @invalidated = 0; @draw_calls = []; end
    def invalidate; @invalidated += 1; end
    def draw_polyline(pts); @draw_calls << [:polyline, pts]; end
    def draw_points(pts, *rest); @draw_calls << [:points, pts]; end
    def draw(mode, pts); @draw_calls << [:draw, pts, mode, drawing_color]; end
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
    def add_instance(definition, transformation); i = Instance.new(definition, transformation, self); @items << i; i; end
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
  class Material
    attr_reader :name
    attr_accessor :color
    def initialize(name); @name = name; end
    def valid?; true; end
  end
  class Materials
    def initialize; @list = []; end
    def [](name); @list.find { |m| m.name == name }; end
    def add(name); m = Material.new(name); @list << m; m; end
    def each(&b); @list.each(&b); end
    def to_a; @list.dup; end
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
    attr_reader :entities, :layers, :materials, :operations, :line_styles, :definitions, :selection, :active_path, :tool, :observers
    def add_observer(o); (@observers ||= []) << o; true; end
    def remove_observer(o); (@observers ||= []).delete(o); true; end
    def active_view; @view ||= FakeView.new; end
    # Mô phỏng người dùng Hoàn tác / Làm lại trong SketchUp: gọi các observer của model.
    def fire_commit; (@observers || []).each { |o| o.onTransactionCommit(self) if o.respond_to?(:onTransactionCommit) }; end
    def fire_undo; (@observers || []).each { |o| o.onTransactionUndo(self) if o.respond_to?(:onTransactionUndo) }; end
    def fire_redo; (@observers || []).each { |o| o.onTransactionRedo(self) if o.respond_to?(:onTransactionRedo) }; end
    def active_path=(path); @active_path = path; end
    def select_tool(t); @tool.deactivate(FakeView.new) if @tool && @tool.respond_to?(:deactivate); @tool = t; t.activate if t && t.respond_to?(:activate); end
    def initialize(styles: ['Solid Line', 'Dotted Line', 'Short Dashes Line', 'Dash Dot Line'])
      @entities = FakeEntities.new; @selection = Selection.new; @definitions = Definitions.new; @layers = Layers.new; @materials = Materials.new; @operations = []; @attrs = {}
      @line_styles = styles.map { |n| LineStyle.new(n) }
    end
    def start_operation(name, disable, *_rest); @operations << [:start, name]; end
    def commit_operation; @operations << [:commit]; end
    def abort_operation; @operations << [:abort]; end
    def set_attribute(dict, key, value); (@attrs[dict] ||= {})[key] = value; end
    def get_attribute(dict, key, default = nil); (@attrs[dict] || {}).fetch(key, default); end
    def active_model; self; end
  end
  def self.active_model; $model; end
  def self.status_text=(t); $status_text = t; end
end
