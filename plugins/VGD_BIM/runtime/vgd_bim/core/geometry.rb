module VGD
  module BIM
    module Geometry
      INCH_MM = 25.4
      def self.definition(entity)
        entity.is_a?(Sketchup::Group) ? entity.entities.parent : entity.definition
      end
      # Local axes dimensions after full occurrence transform; rotation preserves W/D/H.
      # Món đã có mặt trước (xem Front): Rộng là chiều ngang nhìn từ mặt trước, Sâu là chiều theo hướng mặt trước, Cao là Z.
      # Chưa có mặt trước thì Rộng = X cục bộ, Sâu = Y cục bộ như trước.
      # measure: MeasureProbe::Context (Bảng khối lượng) để đo thân, bỏ tay nắm và phần nhô; nil thì dùng khung bao của định nghĩa như cũ.
      def self.dimensions(entity, transform = nil, measure: nil)
        transform ||= entity.transformation
        definition = definition(entity)
        box = definition.bounds
        return {width: 0.0, depth: 0.0, height: 0.0} if box.empty?
        body = measure && measure.extent(definition)
        size = body ? body[:size] : [box.width.to_f, box.height.to_f, box.depth.to_f]
        scale_x, scale_y, scale_z = scales(transform)
        x_size = size[0] * scale_x * INCH_MM
        y_size = size[1] * scale_y * INCH_MM
        dir = defined?(Front) ? Front.read(definition)[:dir] : nil
        width, depth = defined?(Front) ? Front.frame_sizes(x_size, y_size, dir) : [x_size, y_size]
        {width: width, depth: depth, height: size[2] * scale_z * INCH_MM}
      end

      # Hệ số phóng to theo từng trục X, Y, Z của biến đổi (độ dài ba cột đầu của ma trận 16 số). Không dùng Transformation#xaxis.length:
      # SketchUp trả về vector đơn vị nên luôn bằng 1 và làm mất phóng to (đối tượng kéo dài 1 m thành 2 m vẫn hiện 1 m).
      def self.scales(transform)
        values = transform.to_a
        [0, 4, 8].map { |i| Math.sqrt(values[i]**2 + values[i + 1]**2 + values[i + 2]**2) }
      end
      def self.width(entity, transform = nil); dimensions(entity, transform)[:width]; end
      def self.depth(entity, transform = nil); dimensions(entity, transform)[:depth]; end
      def self.height(entity, transform = nil); dimensions(entity, transform)[:height]; end
      def self.face_area(face, transform = Geom::Transformation.new)
        face.area(transform).to_f * INCH_MM**2 / 1_000_000.0
      end
      # Diện tích hình chiếu của mặt xuống mặt phẳng ngang (m²): diện tích mặt nhân |cosin góc giữa pháp tuyến và trục Z|.
      def self.projected_area(face, transform = Geom::Transformation.new)
        normal = face.normal.transform(transform)
        length = normal.length
        length.zero? ? 0.0 : face_area(face, transform) * (normal.z / length).abs
      end
    end
  end
end
