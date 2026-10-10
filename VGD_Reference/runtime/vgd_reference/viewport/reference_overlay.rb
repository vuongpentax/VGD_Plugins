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
        x0, y0 = ScreenCoordinates.to_draw_space(item.x, item.y, view)
        x1, y1 = ScreenCoordinates.to_draw_space(item.x + item.width, item.y + item.height, view)
        points = [
          Geom::Point3d.new(x0, y0, 0), Geom::Point3d.new(x1, y0, 0),
          Geom::Point3d.new(x1, y1, 0), Geom::Point3d.new(x0, y1, 0)
        ]
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
          hx0, hy0 = ScreenCoordinates.to_draw_space(x - half, y - half, view)
          hx1, hy1 = ScreenCoordinates.to_draw_space(x + half, y + half, view)
          handle = [
            Geom::Point3d.new(hx0, hy0, 0), Geom::Point3d.new(hx1, hy0, 0),
            Geom::Point3d.new(hx1, hy1, 0), Geom::Point3d.new(hx0, hy1, 0)
          ]
          view.drawing_color = Sketchup::Color.new(245, 241, 235, 240)
          view.draw2d(GL_QUADS, handle)
          view.drawing_color = Sketchup::Color.new(105, 66, 44, 245)
          view.draw2d(GL_LINE_LOOP, handle)
        end
        view.drawing_color = Sketchup::Color.new(255, 255, 255, 255)
      end

      def draw_crop_controls(view, item)
        x0, y0 = ScreenCoordinates.to_draw_space(item.x, item.y, view)
        x1, y1 = ScreenCoordinates.to_draw_space(item.x + item.width, item.y + item.height, view)
        left, top = ScreenCoordinates.to_draw_space(item.x + item.width * item.crop_u0, item.y + item.height * item.crop_v0, view)
        right, bottom = ScreenCoordinates.to_draw_space(item.x + item.width * item.crop_u1, item.y + item.height * item.crop_v1, view)
        view.drawing_color = Sketchup::Color.new(0, 0, 0, 105)
        [
          [[x0, y0], [x1, y0], [x1, top], [x0, top]],
          [[x0, bottom], [x1, bottom], [x1, y1], [x0, y1]],
          [[x0, top], [left, top], [left, bottom], [x0, bottom]],
          [[right, top], [x1, top], [x1, bottom], [right, bottom]]
        ].each do |coords|
          view.draw2d(GL_QUADS, coords.map { |xy| Geom::Point3d.new(xy[0], xy[1], 0) })
        end
        view.line_width = 1
        view.drawing_color = Sketchup::Color.new(249, 204, 154, 245)
        crop_rect = [
          Geom::Point3d.new(left, top, 0), Geom::Point3d.new(right, top, 0),
          Geom::Point3d.new(right, bottom, 0), Geom::Point3d.new(left, bottom, 0)
        ]
        view.draw2d(GL_LINE_LOOP, crop_rect)
        view.drawing_color = Sketchup::Color.new(255, 255, 255, 255)
      end

      def screen_quad(item, view)
        x0, y0 = ScreenCoordinates.to_draw_space(item.x, item.y, view)
        x1, y1 = ScreenCoordinates.to_draw_space(item.x + item.width, item.y + item.height, view)
        [
          Geom::Point3d.new(x0, y0, 0), Geom::Point3d.new(x1, y0, 0),
          Geom::Point3d.new(x1, y1, 0), Geom::Point3d.new(x0, y1, 0)
        ]
      end
    end
  end
end
