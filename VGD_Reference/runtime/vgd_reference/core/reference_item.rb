module VGD
  module Reference
    class ReferenceItem
      ATTRIBUTES = %i[
        id source_type source_path image_width image_height x y width height
        crop_u0 crop_v0 crop_u1 crop_v1 view_u0 view_v0 view_u1 view_v1
        opacity visible locked z_index
      ].freeze

      attr_accessor(*ATTRIBUTES)
      attr_accessor :texture_id, :texture_dirty, :selected
      attr_accessor :opacity_preview

      def initialize(id:, source_type:, source_path:, image_width:, image_height:,
                     x:, y:, width:, height:, z_index:)
        @id = id.to_s
        @source_type = source_type.to_sym
        @source_path = source_path.to_s
        @image_width = image_width.to_i
        @image_height = image_height.to_i
        @x = x.to_f
        @y = y.to_f
        @width = width.to_f
        @height = height.to_f
        @crop_u0 = 0.0
        @crop_v0 = 0.0
        @crop_u1 = 1.0
        @crop_v1 = 1.0
        @view_u0 = 0.0
        @view_v0 = 0.0
        @view_u1 = 1.0
        @view_v1 = 1.0
        @opacity = 100
        @visible = true
        @locked = true
        @z_index = z_index.to_i
        @texture_id = nil
        @texture_dirty = true
        @selected = false
        @opacity_preview = false
      end

      def crop_width
        @crop_u1 - @crop_u0
      end

      def crop_height
        @crop_v1 - @crop_v0
      end

      def view_width
        @view_u1 - @view_u0
      end

      def view_height
        @view_v1 - @view_v0
      end

      def display_aspect
        return 1.0 if @image_height <= 0
        (@image_width * view_width) / (@image_height * view_height)
      end

      def reset_zoom
        @view_u0 = @crop_u0
        @view_v0 = @crop_v0
        @view_u1 = @crop_u1
        @view_v1 = @crop_v1
      end

      def zoom_at(screen_x, screen_y, factor)
        return false unless @width.positive? && @height.positive?
        return false unless factor.to_f.positive?

        anchor_x = @view_u0 + ((screen_x - @x) / @width) * view_width
        anchor_y = @view_v0 + ((screen_y - @y) / @height) * view_height
        new_width = [[view_width * factor.to_f, CROP_MIN_SPAN].max, crop_width].min
        new_height = [[view_height * factor.to_f, CROP_MIN_SPAN].max, crop_height].min
        next_u0 = anchor_x - ((screen_x - @x) / @width) * new_width
        next_v0 = anchor_y - ((screen_y - @y) / @height) * new_height
        @view_u0, @view_u1 = clamp_window(next_u0, new_width, @crop_u0, @crop_u1)
        @view_v0, @view_v1 = clamp_window(next_v0, new_height, @crop_v0, @crop_v1)
        true
      end

      def pan_content(delta_x, delta_y)
        return unless @width.positive? && @height.positive?
        next_u0 = @view_u0 - delta_x.to_f / @width * view_width
        next_v0 = @view_v0 - delta_y.to_f / @height * view_height
        @view_u0, @view_u1 = clamp_window(next_u0, view_width, @crop_u0, @crop_u1)
        @view_v0, @view_v1 = clamp_window(next_v0, view_height, @crop_v0, @crop_v1)
      end

      def move_by(dx, dy)
        @x += dx.to_f
        @y += dy.to_f
      end

      def set_opacity(value)
        @opacity = [[value.to_i, OPACITY_MIN].max, 100].min
      end

      def screen_uv(screen_x, screen_y)
        return [@view_u0, @view_v0] unless @width.positive? && @height.positive?
        u = @view_u0 + ((screen_x - @x) / @width) * view_width
        v = @view_v0 + ((screen_y - @y) / @height) * view_height
        [u, v]
      end

      def to_h
        ATTRIBUTES.each_with_object({}) { |key, hash| hash[key] = public_send(key) }
      end

      private

      def clamp_window(start, length, min, max)
        length = [[length, CROP_MIN_SPAN].max, max - min].min
        start = [[start, min].max, max - length].min
        [start, start + length]
      end
    end
  end
end
