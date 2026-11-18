module VGD
  module Structure
    # Phép biến đổi đặt phần tử vào model (đơn vị mm → inch): dời tới điểm gốc rồi xoay quanh trục đứng nếu phần tử xiên / xoay góc bất kỳ (P4b-2).
    # Phần tử xiên dùng chung định nghĩa với phần tử dọc theo +X (xem `frame_dir`), chỉ khác phép xoay.
    module Placement
      # Phương của hệ tọa độ định nghĩa dùng chung: 'y' chỉ cho phần tử dọc; ngang và xiên đều dựng dọc theo +X rồi xoay.
      def self.frame_dir(item)
        item[:dir] == 'y' ? 'y' : 'x'
      end

      # Phần tử có góc xoay riêng (độ): xiên (đoạn a -> b) hoặc cột xoay góc bất kỳ; nil nếu không xoay.
      def self.angle(item)
        return (item[:a] && item[:b] ? Geometry.angle(item[:a], item[:b]) : item[:angle]) if item[:dir] == 'o'
        item[:rot] if item[:poly] && item[:rot]
      end

      def self.transformation(item, x, y, z)
        move = Geom::Transformation.new(Geom::Point3d.new(x.mm, y.mm, z.mm))
        deg = angle(item)
        return move unless deg
        move * Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1), deg * Math::PI / 180.0)
      end
    end
  end
end
