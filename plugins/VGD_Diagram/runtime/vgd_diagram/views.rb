# encoding: UTF-8
# Xuất ảnh PNG do chính SketchUp vẽ (theo style đang bật), phối cảnh song song, cho các góc chuẩn.
# Tạm đổi camera của khung nhìn rồi trả lại như cũ. Nhãn số không nằm trong ảnh; có bảng CSV đi kèm.
module VGD
  module Diagram
    module Views
      extend self

      # [tên file, hướng từ tâm mô hình tới camera]. SketchUp dùng trục Z hướng lên.
      STANDARD = [
        ['truoc', [0.0, -1.0, 0.0]],
        ['phai', [1.0, 0.0, 0.0]],
        ['tren', [0.0, 0.0, 1.0]],
        ['iso', [1.0, -1.0, 1.0]]
      ].freeze
      IMAGE_WIDTH = 1600
      IMAGE_HEIGHT = 1200
      MIN_DISTANCE = 1000

      # Trả về danh sách đường dẫn các ảnh đã ghi.
      def export(model, folder, base_name)
        view = model.active_view
        original = view.camera
        center = model.bounds.center
        distance = [model.bounds.diagonal, MIN_DISTANCE].max * 3
        STANDARD.map do |key, direction|
          aim = Geom::Vector3d.new(*direction).normalize
          eye = center + aim * distance
          up = aim.z.abs > 0.99 ? Geom::Vector3d.new(0, 1, 0) : Geom::Vector3d.new(0, 0, 1)
          camera = Sketchup::Camera.new(eye, center, up)
          camera.perspective = false
          view.camera = camera
          view.zoom_extents
          path = File.join(folder, "#{base_name}-#{key}.png")
          view.write_image(path, IMAGE_WIDTH, IMAGE_HEIGHT, true, 0.5)
          path
        end
      ensure
        view.camera = original if view && original
      end
    end
  end
end
