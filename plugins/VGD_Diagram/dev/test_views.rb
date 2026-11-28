# encoding: UTF-8
# Kiểm tra xuất ảnh các góc (views.rb) bằng đối tượng giả lập SketchUp. Chạy từ plugins/VGD_Diagram: ruby dev/test_views.rb
$LOAD_PATH.unshift File.expand_path('../runtime/vgd_diagram', __dir__)

module Geom
  class Vector3d
    attr_reader :x, :y, :z

    def initialize(x, y, z)
      @x = x.to_f
      @y = y.to_f
      @z = z.to_f
    end

    def length
      Math.sqrt(x * x + y * y + z * z)
    end

    def normalize
      Vector3d.new(x / length, y / length, z / length)
    end

    def *(number)
      Vector3d.new(x * number, y * number, z * number)
    end
  end

  class Point3d
    attr_reader :x, :y, :z

    def initialize(x, y, z)
      @x = x.to_f
      @y = y.to_f
      @z = z.to_f
    end

    def +(vector)
      Point3d.new(x + vector.x, y + vector.y, z + vector.z)
    end

    def distance(other)
      Math.sqrt((x - other.x)**2 + (y - other.y)**2 + (z - other.z)**2)
    end
  end
end

module Sketchup
  class Camera
    attr_reader :eye, :target, :up
    attr_accessor :perspective

    def initialize(eye, target, up)
      @eye = eye
      @target = target
      @up = up
      @perspective = true
    end
  end

  class BoundsStub
    def center
      Geom::Point3d.new(100, 200, 300)
    end

    def diagonal
      2000.0
    end
  end

  class ViewStub
    attr_accessor :camera
    attr_reader :written, :zoomed

    def initialize(camera, fail_on_write: false)
      @camera = camera
      @written = []
      @zoomed = 0
      @fail_on_write = fail_on_write
    end

    def zoom_extents
      @zoomed += 1
    end

    def write_image(path, width, height, antialias, compression)
      raise IOError, 'không ghi được ảnh' if @fail_on_write
      @written << [path, width, height, antialias, compression, @camera.perspective]
      true
    end
  end

  class ModelStub
    attr_reader :active_view, :bounds

    def initialize(view)
      @active_view = view
      @bounds = BoundsStub.new
    end
  end
end

require 'views'

$pass = 0
$fail = []
def check(name, condition)
  condition ? $pass += 1 : $fail << name
  puts "#{condition ? 'OK  ' : 'FAIL'} #{name}"
end

V = VGD::Diagram::Views
original = Sketchup::Camera.new(Geom::Point3d.new(1, 2, 3), Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1))

# 1. Xuất đủ 4 góc, đúng tên file, trong thư mục đã chọn
view = Sketchup::ViewStub.new(original)
paths = V.export(Sketchup::ModelStub.new(view), '/tmp/xuat', 'tu-bep')
check 'xuất 4 góc chuẩn đúng tên file',
      paths == %w[truoc phai tren iso].map { |key| "/tmp/xuat/tu-bep-#{key}.png" }
check 'mỗi góc được zoom_extents một lần', view.zoomed == 4
check 'ảnh có kích thước 1600x1200 và khử răng cưa', view.written.all? { |w| w[1] == 1600 && w[2] == 1200 && w[3] == true }

# 2. Mỗi ảnh được chụp khi camera là phối cảnh song song
check 'mọi ảnh chụp ở phối cảnh song song (perspective = false)', view.written.all? { |w| w[5] == false }

# 3. Camera được trả lại như cũ sau khi xong
check 'camera được trả lại đúng đối tượng ban đầu', view.camera.equal?(original) && view.camera.perspective == true

# 4. Lỗi khi ghi ảnh: vẫn trả camera lại
broken_view = Sketchup::ViewStub.new(original, fail_on_write: true)
raised = begin
  V.export(Sketchup::ModelStub.new(broken_view), '/tmp/xuat', 'loi')
  false
rescue IOError
  true
end
check 'lỗi khi ghi ảnh được báo ra ngoài', raised
check 'lỗi khi ghi ảnh: camera vẫn được trả lại', broken_view.camera.equal?(original)

# 5. Camera đặt cách tâm đúng khoảng cách (3 lần đường chéo mô hình), nhìn về tâm
check 'khoảng cách camera: 3 lần đường chéo (6000 mm)', begin
  cam = nil
  probe = Sketchup::ViewStub.new(original)
  def probe.camera=(value)
    @seen ||= []
    @seen << value
    super
  end
  V.export(Sketchup::ModelStub.new(probe), '/tmp/xuat', 'kc')
  cam = probe.instance_variable_get(:@seen).first
  (cam.eye.distance(cam.target) - 6000).abs < 1e-6
end

# 6. Góc từ trên xuống dùng trục lên khác, không bị song song với hướng nhìn
top_camera = nil
top_probe = Sketchup::ViewStub.new(original)
def top_probe.camera=(value)
  (@seen ||= []) << value
  super
end
V.export(Sketchup::ModelStub.new(top_probe), '/tmp/xuat', 'tren')
top_camera = top_probe.instance_variable_get(:@seen).find { |c| c.eye.z > c.target.z + 1000 && c.up.y == 1.0 }
check 'góc trên: trục lên không song song hướng nhìn (dùng Y)', !top_camera.nil?

puts
puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "CÓ #{$fail.size} LỖI: #{$fail.inspect}"
exit($fail.empty? ? 0 : 1)
