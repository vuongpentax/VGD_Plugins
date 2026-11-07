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
      def self.dimensions(entity, transform = nil)
        transform ||= entity.transformation
        definition = definition(entity)
        box = definition.bounds
        return {width: 0.0, depth: 0.0, height: 0.0} if box.empty?
        x_size = box.width.to_f * transform.xaxis.length * INCH_MM
        y_size = box.height.to_f * transform.yaxis.length * INCH_MM
        dir = defined?(Front) ? Front.read(definition)[:dir] : nil
        width, depth = defined?(Front) ? Front.frame_sizes(x_size, y_size, dir) : [x_size, y_size]
        {width: width, depth: depth, height: box.depth.to_f * transform.zaxis.length * INCH_MM}
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
