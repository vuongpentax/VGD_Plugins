module VGD
  module BIM
    module UI
      # Khung đánh dấu đối tượng đang chọn, theo bộ màu VGD:
      # - tô nhẹ các mặt, viền nét đứt quanh khung bao, khung tên (nền nâu, chữ trắng) ở giữa đối tượng.
      # Đây là công cụ vẽ tạm: không thêm gì vào model. Click chuột vẫn chọn đối tượng (xử lý trong công cụ).
      # Nhấn Esc để tắt khung. Đối tượng bị xóa thì khung tự tắt.
      # SketchUp không có lớp gốc Sketchup::Tool; chỉ cần một object có các hàm draw / onLButtonDown / onCancel.
      class BoundsPreview
        LINE_COLOR = [180, 137, 99].freeze      # #B48963, màu nhấn VGD (viền)
        FILL_COLOR = [180, 137, 99, 70].freeze  # cùng màu, độ trong suốt nhẹ (tô mặt)
        BOX_COLOR = [142, 107, 76].freeze       # #8E6B4C, màu nhấn đậm VGD (nền khung tên)
        TEXT_COLOR = [255, 255, 255].freeze     # chữ trắng trên nền nâu
        LABEL_SIZE = 12
        LABEL_HEIGHT = 24
        CHAR_WIDTH = 7.5
        PADDING = 10

        # alive: hàm kiểm tra đối tượng còn tồn tại; trả về false thì khung tự tắt và gọi on_stale.
        def initialize(points, label: nil, label_point: nil, fills: [], alive: nil, on_stale: nil, &on_done)
          @points = points
          @label = label
          @label_point = label_point
          @fills = fills
          @alive = alive
          @on_stale = on_stale
          @on_done = on_done
          @finished = false
          @stale = false
        end

        # Vẽ lại ngay khi bật / tắt khung, không đợi người dùng xoay màn hình.
        def activate
          view = Sketchup.active_model.active_view
          view.invalidate if view
        rescue StandardError
          nil
        end

        # SketchUp gọi khi khung bị gỡ: do finish (pop_tool) hoặc do người dùng chọn công cụ khác.
        # Trường hợp sau phải đánh dấu đã xong, nếu không lần finish kế tiếp sẽ pop nhầm công cụ của người dùng.
        def deactivate(view)
          unless @finished
            @finished = true
            @on_done.call if @on_done
          end
          view.invalidate
        end

        def resume(view)
          view.invalidate
        end

        def draw(view)
          return if @finished || @stale
          unless alive?
            release_later(view)
            return
          end
          draw_fills(view)
          draw_outline(view)
          draw_label(view)
        end

        def alive?
          @alive.nil? || @alive.call ? true : false
        rescue StandardError
          false
        end

        # Tô nhẹ các mặt của đối tượng (danh sách tam giác theo tọa độ thế giới).
        def draw_fills(view)
          return if @fills.empty?
          view.drawing_color = Sketchup::Color.new(*FILL_COLOR)
          view.draw(GL_TRIANGLES, @fills)
        end

        def draw_outline(view)
          return if @points.empty?
          view.line_stipple = '-'
          view.line_width = 2
          view.drawing_color = Sketchup::Color.new(*LINE_COLOR)
          view.draw_lines(@points)
          view.line_stipple = ''
        end

        # Khung tên: một ô nền nâu có chữ trắng, đặt ở giữa đối tượng.
        # draw_text nhận tọa độ màn hình, nên đổi điểm 3D sang tọa độ màn hình trước khi viết chữ.
        def draw_label(view)
          return if @label.nil? || @label.empty? || @label_point.nil?
          screen = view.screen_coords(@label_point)
          half_width = (@label.length * CHAR_WIDTH + PADDING * 2) / 2.0
          half_height = LABEL_HEIGHT / 2.0
          corners = [
            Geom::Point3d.new(screen.x - half_width, screen.y - half_height, 0),
            Geom::Point3d.new(screen.x + half_width, screen.y - half_height, 0),
            Geom::Point3d.new(screen.x + half_width, screen.y + half_height, 0),
            Geom::Point3d.new(screen.x - half_width, screen.y + half_height, 0)
          ]
          view.drawing_color = Sketchup::Color.new(*BOX_COLOR)
          view.draw2d(GL_QUADS, corners)
          view.draw_text(text_origin(screen, half_width, half_height), @label, text_options)
        end

        def onLButtonDown(_flags, x, y, view)
          return if @finished
          pick_at(view, x, y)
        rescue StandardError => error
          BIM.log("Pick failed: #{error.message}")
        end

        def onCancel(_reason, view)
          finish(view)
        end

        def finish(view)
          return if @finished
          @finished = true
          @on_done.call if @on_done
          view.model.tools.pop_tool
        rescue StandardError => error
          BIM.log("Preview release failed: #{error.message}")
        end

        private

        # Căn giữa chữ trong ô nếu SketchUp hỗ trợ; bản cũ thì canh trái trong ô.
        def text_origin(screen, half_width, half_height)
          if defined?(TextAlignCenter) && defined?(TextVerticalAlignCenter)
            Geom::Point3d.new(screen.x, screen.y, 0)
          else
            Geom::Point3d.new(screen.x - half_width + PADDING, screen.y - half_height + 4, 0)
          end
        end

        def text_options
          options = {size: LABEL_SIZE, color: Sketchup::Color.new(*TEXT_COLOR)}
          if defined?(TextAlignCenter) && defined?(TextVerticalAlignCenter)
            options[:align] = TextAlignCenter
            options[:vertical_align] = TextVerticalAlignCenter
          end
          options
        end

        # Không gỡ công cụ ngay trong lúc vẽ; hẹn một nhịp rồi mới gỡ.
        def release_later(view)
          @stale = true
          release = lambda do
            finish(view)
            @on_stale.call if @on_stale
          end
          if defined?(::UI) && ::UI.respond_to?(:start_timer)
            ::UI.start_timer(0, false) { release.call }
          else
            release.call
          end
        end

        # Chỉ lấy đối tượng ở cấp đang mở (depth), không chọn sâu vào bên trong group.
        def pick_at(view, x, y)
          model = view.model
          depth = (model.active_path || []).size
          helper = view.pick_helper
          helper.do_pick(x, y)
          target = nil
          (0...helper.count).each do |i|
            path = helper.path_at(i)
            next if path.nil? || path.size <= depth
            target = path[depth]
            break
          end
          model.selection.clear
          model.selection.add(target) if target && target.valid?
        end
      end
    end
  end
end
