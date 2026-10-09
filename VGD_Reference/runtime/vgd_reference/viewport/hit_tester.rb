module VGD
  module Reference
    class HitTester
      BODY = :body
      RESIZE_TOP_LEFT = :resize_top_left
      RESIZE_TOP_RIGHT = :resize_top_right
      RESIZE_BOTTOM_LEFT = :resize_bottom_left
      RESIZE_BOTTOM_RIGHT = :resize_bottom_right
      CROP_LEFT = :crop_left
      CROP_RIGHT = :crop_right
      CROP_TOP = :crop_top
      CROP_BOTTOM = :crop_bottom
      CONTROL = :control
      NONE = :none

      def self.hit(item, x, y, crop: false)
        return NONE unless item && x >= item.x && x <= item.x + item.width && y >= item.y && y <= item.y + item.height
        if crop
          edge = 8.0
          crop_left = item.x + item.width * item.crop_u0
          crop_right = item.x + item.width * item.crop_u1
          crop_top = item.y + item.height * item.crop_v0
          crop_bottom = item.y + item.height * item.crop_v1
          return CROP_LEFT if (x - crop_left).abs <= edge && y >= crop_top && y <= crop_bottom
          return CROP_RIGHT if (x - crop_right).abs <= edge && y >= crop_top && y <= crop_bottom
          return CROP_TOP if (y - crop_top).abs <= edge && x >= crop_left && x <= crop_right
          return CROP_BOTTOM if (y - crop_bottom).abs <= edge && x >= crop_left && x <= crop_right
          return BODY
        end
        radius = HANDLE_SIZE * 1.5
        handles = {
          RESIZE_TOP_LEFT => [item.x, item.y],
          RESIZE_TOP_RIGHT => [item.x + item.width, item.y],
          RESIZE_BOTTOM_LEFT => [item.x, item.y + item.height],
          RESIZE_BOTTOM_RIGHT => [item.x + item.width, item.y + item.height]
        }
        handles.each do |name, point|
          return name if (point[0] - x).abs <= radius && (point[1] - y).abs <= radius
        end
        BODY
      end
    end
  end
end
