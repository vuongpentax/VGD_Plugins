module VGD
  module Reference
    class CropController
      def initialize(item)
        @item = item
        @original = [item.x, item.y, item.width, item.height,
                     item.crop_u0, item.crop_v0, item.crop_u1, item.crop_v1]
      end

      def drag(edge, x, y)
        u = [[(x.to_f - @item.x) / @item.width, 0.0].max, 1.0].min
        v = [[(y.to_f - @item.y) / @item.height, 0.0].max, 1.0].min
        case edge
        when HitTester::CROP_LEFT
          @item.crop_u0 = [[u, 0.0].max, @item.crop_u1 - CROP_MIN_SPAN].min
        when HitTester::CROP_RIGHT
          @item.crop_u1 = [[u, @item.crop_u0 + CROP_MIN_SPAN].max, 1.0].min
        when HitTester::CROP_TOP
          @item.crop_v0 = [[v, 0.0].max, @item.crop_v1 - CROP_MIN_SPAN].min
        when HitTester::CROP_BOTTOM
          @item.crop_v1 = [[v, @item.crop_v0 + CROP_MIN_SPAN].max, 1.0].min
        end
      end

      def commit
        center_x = @item.x + @item.width / 2.0
        center_y = @item.y + @item.height / 2.0
        aspect = (@item.image_width * @item.crop_width) / (@item.image_height * @item.crop_height)
        @item.width = [@item.width, MIN_FRAME_SIZE, MIN_FRAME_SIZE * aspect].max
        @item.height = @item.width / aspect
        @item.x = center_x - @item.width / 2.0
        @item.y = center_y - @item.height / 2.0
        @item.reset_zoom
        @original = nil
      end

      def cancel
        return unless @original
        @item.x, @item.y, @item.width, @item.height = @original[0, 4]
        @item.crop_u0, @item.crop_v0, @item.crop_u1, @item.crop_v1 = @original[4, 4]
        @item.reset_zoom
        @original = nil
      end
    end
  end
end
