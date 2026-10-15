module VGD
  module Reference
    class ReferenceOverlay < Sketchup::Overlay
      def initialize
        super(OVERLAY_ID, OVERLAY_NAME)
      end

      def getExtents
        Sketchup.active_model.bounds
      end

      def draw(view)
        return unless Session.store && enabled?
        Session.store.visible_items.each do |item|
          texture_id = TextureCache.texture_for(item, view)
          next unless texture_id
          draw_item(view, item, texture_id)
          draw_edit_controls(view, item) if item.selected && !item.locked
          draw_crop_controls(view, item) if Session.crop_item_id == item.id
        end
      rescue StandardError => error
        ImageLoader.log_error('Overlay draw failed', error)
      end

      def start
        Session.overlay_enabled(Sketchup.active_model&.active_view)
      end

      def stop(view = nil)
        Session.overlay_disabled(view)
        view.invalidate if view
      rescue StandardError => error
        ImageLoader.log_error('Overlay stop failed', error)
      end

      def onMouseMove(flags, x, y, view)
        QuickMovePrototype.on_mouse_move(flags, x, y, view)
      end

      private

      def draw_item(view, item, texture_id)
        points = screen_quad(item, view)
        crop_mode = Session.crop_item_id == item.id
        u0 = crop_mode ? 0.0 : item.view_u0
        v0 = crop_mode ? 0.0 : item.view_v0
        u1 = crop_mode ? 1.0 : item.view_u1
        v1 = crop_mode ? 1.0 : item.view_v1
        # SU 2024.0's new graphics engine renders Vector3d UVs as a flat
        # sampled color. Numeric arrays work in the same draw2d call, verified
        # with a four-color texture in the user's live SketchUp 2024 viewport.
        uvs = [
          [u0, 1.0 - v0, 0.0], [u1, 1.0 - v0, 0.0],
          [u1, 1.0 - v1, 0.0], [u0, 1.0 - v1, 0.0]
        ]
        # Preview applies alpha through the drawing color. A committed opacity
        # is already baked into the cached ImageRep, so the texture is drawn
        # without a second alpha multiplier.
        alpha = item.opacity_preview ? item.opacity : 100
        alpha = [[alpha.to_i, 0].max, 100].min * 255 / 100
        view.drawing_color = Sketchup::Color.new(255, 255, 255, alpha)
        view.draw2d(GL_QUADS, points, texture: texture_id, uvs: uvs)
      ensure
        view.drawing_color = Sketchup::Color.new(255, 255, 255, 255) if view
      end

      def draw_edit_controls(view, item)
        points = screen_quad(item, view)
        view.line_width = 1
        view.line_stipple = ''
        view.drawing_color = Sketchup::Color.new(198, 135, 85, 230)
        view.draw2d(GL_LINE_LOOP, points)
        half = HANDLE_SIZE / 2.0
        [
          [item.x, item.y], [item.x + item.width, item.y],
          [item.x + item.width, item.y + item.height], [item.x, item.y + item.height]
        ].each do |x, y|
          handle = [
            point3d(view, item, x - half, y - half), point3d(view, item, x + half, y - half),
            point3d(view, item, x + half, y + half), point3d(view, item, x - half, y + half)
          ]
          view.drawing_color = Sketchup::Color.new(245, 241, 235, 240)
          view.draw2d(GL_QUADS, handle)
          view.drawing_color = Sketchup::Color.new(105, 66, 44, 245)
          view.draw2d(GL_LINE_LOOP, handle)
        end
        draw_rotation_handle(view, item)
        view.drawing_color = Sketchup::Color.new(255, 255, 255, 255)
      end

      def draw_rotation_handle(view, item)
        center_x = item.x + item.width / 2.0
        top_y = item.y
        handle_x = center_x
        handle_y = top_y - 28.0
        x0, y0 = draw_point(view, item, center_x, top_y)
        x1, y1 = draw_point(view, item, handle_x, handle_y)
        view.line_width = 1
        view.drawing_color = Sketchup::Color.new(105, 66, 44, 245)
        view.draw2d(GL_LINES, [Geom::Point3d.new(x0, y0, 0), Geom::Point3d.new(x1, y1, 0)])
        ring = 16.times.map do |index|
          radians = index * 2.0 * Math::PI / 16.0
          px, py = draw_point(view, item, handle_x + Math.cos(radians) * 5.0, handle_y + Math.sin(radians) * 5.0)
          Geom::Point3d.new(px, py, 0)
        end
        view.drawing_color = Sketchup::Color.new(245, 241, 235, 255)
        view.draw2d(GL_LINE_LOOP, ring)
      end

      def draw_crop_controls(view, item)
        x0, y0 = item.x, item.y
        x1, y1 = item.x + item.width, item.y + item.height
        left, top = item.x + item.width * item.crop_u0, item.y + item.height * item.crop_v0
        right, bottom = item.x + item.width * item.crop_u1, item.y + item.height * item.crop_v1
        view.drawing_color = Sketchup::Color.new(0, 0, 0, 105)
        [
          [[x0, y0], [x1, y0], [x1, top], [x0, top]],
          [[x0, bottom], [x1, bottom], [x1, y1], [x0, y1]],
          [[x0, top], [left, top], [left, bottom], [x0, bottom]],
          [[right, top], [x1, top], [x1, bottom], [right, bottom]]
        ].each do |coords|
          view.draw2d(GL_QUADS, coords.map { |xy| point3d(view, item, xy[0], xy[1]) })
        end
        view.line_width = 1
        view.drawing_color = Sketchup::Color.new(249, 204, 154, 245)
        crop_rect = [
          point3d(view, item, left, top), point3d(view, item, right, top),
          point3d(view, item, right, bottom), point3d(view, item, left, bottom)
        ]
        view.draw2d(GL_LINE_LOOP, crop_rect)
        view.drawing_color = Sketchup::Color.new(255, 255, 255, 255)
      end

      def screen_quad(item, view)
        [
          point3d(view, item, item.x, item.y), point3d(view, item, item.x + item.width, item.y),
          point3d(view, item, item.x + item.width, item.y + item.height), point3d(view, item, item.x, item.y + item.height)
        ]
      end

      def draw_point(view, item, x, y)
        rotated_x, rotated_y = item.transform_point(x, y)
        ScreenCoordinates.to_draw_space(rotated_x, rotated_y, view)
      end

      def point3d(view, item, x, y)
        draw_x, draw_y = draw_point(view, item, x, y)
        Geom::Point3d.new(draw_x, draw_y, 0)
      end
    end
  end
end
