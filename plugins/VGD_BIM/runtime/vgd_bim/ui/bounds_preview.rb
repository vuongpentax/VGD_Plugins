module VGD
  module BIM
    module UI
      # Phần vẽ khung đánh dấu dùng chung cho công cụ (SketchUp 2022) và lớp phủ (SketchUp 2023+).
      module OutlineDrawing
        LINE_COLOR = [180, 137, 99].freeze      # #B48963, màu nhấn VGD (viền)
        FILL_COLOR = [180, 137, 99, 70].freeze  # cùng màu, độ trong suốt nhẹ (tô mặt)
        BOX_COLOR = [142, 107, 76].freeze       # #8E6B4C, màu nhấn đậm VGD (nền khung tên)
        ARROW_FILL = [255, 244, 224].freeze     # mũi tên mặt trước: nền sáng, viền nâu đậm để nổi trên mặt trên của khung
        TEXT_COLOR = [255, 255, 255].freeze     # chữ trắng trên nền nâu
        LABEL_SIZE = 12
        LABEL_HEIGHT = 24
        CHAR_WIDTH = 7.5
        PADDING = 10
        MAX_LABEL_WIDTH = 360 # chiều rộng chữ tối đa (điểm ảnh); tên dài hơn thì rút gọn bằng "…"
        ELLIPSIS = '…'.freeze
        PROBE_DISTANCE = 100.0 # inch, khoảng cách điểm thử trên trục nhìn của camera
        UNDECIDED_PX = 40.0    # cả hai cách đều lệch tâm quá mức này: không tin phép đo
        NEAR_PX = 2.0          # hai cách lệch tâm gần như nhau (ngữ cảnh trùng thế giới): coi là thế giới
        IDENTITY_MATRIX = [1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0].freeze

        def alive?
          @alive.nil? || @alive.call ? true : false
        rescue StandardError
          false
        end

        # Cách vẽ 3D cũ (View#draw), chỉ còn dùng khi không mở ngữ cảnh nào (điểm thế giới giữ nguyên) hoặc khi đang mở sửa group mà
        # chưa đo được kiểu tọa độ của screen_coords (xem screen_mode): lúc đó đổi điểm thế giới sang tọa độ cục bộ bằng edit_transform.inverse.
        # Trả về [đường viền, tô mặt, điểm khung tên, mũi tên tô, mũi tên viền].
        def drawing_shapes(view)
          context = view.model.edit_transform
          return [@points, @fills, @label_point, @arrow_fills, @arrow_lines] if context.to_a == IDENTITY_MATRIX
          key = context.to_a
          unless @shape_key == key
            space = local_drawing?(view, context)
            if space == false
              @shape_cache = [@points, @fills, @label_point, @arrow_fills, @arrow_lines]
            else # đo được là cục bộ, hoặc chưa đo được: giữ cách cũ (tọa độ cục bộ) và đo lại ở lần vẽ sau
              inverse = context.inverse
              @shape_cache = [@points.map { |point| point.transform(inverse) },
                              @fills.map { |point| point.transform(inverse) },
                              @label_point && @label_point.transform(inverse),
                              @arrow_fills.map { |point| point.transform(inverse) },
                              @arrow_lines.map { |point| point.transform(inverse) }]
            end
            @shape_key = key unless space.nil?
          end
          @shape_cache
        end

        # View#screen_coords đang hiểu điểm theo tọa độ cục bộ của ngữ cảnh đang mở (true) hay tọa độ thế giới (false)? nil nếu không đo được.
        # Đo bằng một điểm biết chắc vị trí trên màn hình, không dựa vào công thức chiếu của plugin: điểm nằm đúng trên trục nhìn của camera
        # (mắt + hướng nhìn x khoảng cách) luôn rơi vào tâm khung nhìn. Điểm thế giới đó và điểm đã đổi sang cục bộ, cách nào cho
        # screen_coords ra gần tâm hơn là cách SketchUp đang dùng. Ngữ cảnh gần như trùng thế giới (hai cách cùng gần tâm) thì dùng thế giới.
        def local_drawing?(view, context)
          camera = view.camera
          probe = camera.eye.offset(camera.direction, PROBE_DISTANCE)
          center = [view.vpwidth.to_f / 2.0, view.vpheight.to_f / 2.0]
          as_world = view.screen_coords(probe)
          as_local = view.screen_coords(probe.transform(context.inverse))
          off_world = Math.hypot(as_world.x - center[0], as_world.y - center[1])
          off_local = Math.hypot(as_local.x - center[0], as_local.y - center[1])
          BIM.log("Khung đánh dấu khi mở sửa group: screen_coords lệch tâm #{off_world.round}px nếu hiểu là thế giới, #{off_local.round}px nếu hiểu là cục bộ")
          return nil if [off_world, off_local].min > UNDECIDED_PX
          off_local < off_world - NEAR_PX
        rescue StandardError => error
          BIM.log("Không đo được kiểu tọa độ vẽ: #{error.message}")
          nil
        end

        # Đang mở sửa group và đo được kiểu tọa độ của screen_coords: {local:, inverse:}. Khi đó khung được vẽ bằng tọa độ màn hình
        # (draw2d) với điểm chiếu bằng chính View#screen_coords, nên không phụ thuộc cách View#draw hiểu tọa độ trong ngữ cảnh đang mở.
        # nil: không mở ngữ cảnh nào (vẽ 3D như cũ) hoặc chưa đo được (giữ cách cũ, đo lại ở lần vẽ sau).
        def screen_mode(view)
          context = view.model.edit_transform
          return nil if context.to_a == IDENTITY_MATRIX
          key = context.to_a
          unless @screen_key == key
            @screen_local = local_drawing?(view, context)
            @screen_key = key unless @screen_local.nil?
          end
          @screen_local.nil? ? nil : {local: @screen_local, inverse: context.inverse}
        end

        # Điểm thế giới -> điểm màn hình (z = 0) để vẽ bằng draw2d; nil nếu điểm nằm sau camera (chiếu phối cảnh sẽ lật ngược).
        def screen_point(view, point, mode)
          camera = view.camera
          if camera.perspective?
            eye = camera.eye
            direction = camera.direction
            return nil if (point.x - eye.x) * direction.x + (point.y - eye.y) * direction.y + (point.z - eye.z) * direction.z <= 0.0
          end
          screen = view.screen_coords(mode[:local] ? point.transform(mode[:inverse]) : point)
          Geom::Point3d.new(screen.x, screen.y, 0)
        end

        # Vẽ các đoạn thẳng (cặp điểm) bằng tọa độ màn hình; đoạn có điểm sau camera thì bỏ.
        def draw_screen_segments(view, points, mode)
          screen = points.map { |point| screen_point(view, point, mode) }
          lines = screen.each_slice(2).select { |pair| pair.size == 2 && pair.none?(&:nil?) }.flatten
          view.draw2d(GL_LINES, lines) unless lines.empty?
        end

        # Vẽ các tam giác (ba điểm một) bằng tọa độ màn hình; tam giác có điểm sau camera thì bỏ.
        def draw_screen_triangles(view, points, mode)
          screen = points.map { |point| screen_point(view, point, mode) }
          triangles = screen.each_slice(3).select { |tri| tri.size == 3 && tri.none?(&:nil?) }.flatten
          view.draw2d(GL_TRIANGLES, triangles) unless triangles.empty?
        end

        # Tô nhẹ các mặt của đối tượng (danh sách tam giác theo tọa độ thế giới).
        def draw_fills(view)
          return if @fills.empty?
          view.drawing_color = Sketchup::Color.new(*FILL_COLOR)
          mode = screen_mode(view)
          return draw_screen_triangles(view, @fills, mode) if mode
          view.draw(GL_TRIANGLES, drawing_shapes(view)[1])
        end

        # Mũi tên mặt trước: tô đặc và viền đậm, vẽ trên mặt trên của khung bao.
        def draw_arrows(view)
          return if @arrow_fills.nil? || @arrow_fills.empty?
          mode = screen_mode(view)
          shapes = mode ? nil : drawing_shapes(view)
          view.drawing_color = Sketchup::Color.new(*ARROW_FILL)
          mode ? draw_screen_triangles(view, @arrow_fills, mode) : view.draw(GL_TRIANGLES, shapes[3])
          view.line_stipple = ''
          view.line_width = 3
          view.drawing_color = Sketchup::Color.new(*BOX_COLOR)
          mode ? draw_screen_segments(view, @arrow_lines, mode) : view.draw_lines(shapes[4])
        end

        def draw_outline(view)
          return if @points.empty?
          view.line_stipple = '-'
          view.line_width = 2
          view.drawing_color = Sketchup::Color.new(*LINE_COLOR)
          mode = screen_mode(view)
          mode ? draw_screen_segments(view, @points, mode) : view.draw_lines(drawing_shapes(view)[0])
          view.line_stipple = ''
        end

        # Khung tên: một ô nền nâu có chữ trắng, đặt ở giữa đối tượng.
        # draw_text nhận tọa độ màn hình, nên đổi điểm 3D sang tọa độ màn hình trước khi viết chữ.
        def draw_label(view)
          return if @label.nil? || @label.empty? || @label_point.nil?
          mode = screen_mode(view)
          return if mode && screen_point(view, @label_point, mode).nil? # điểm đặt khung tên nằm sau camera
          screen = mode ? screen_point(view, @label_point, mode) : view.screen_coords(drawing_shapes(view)[2])
          metrics = label_metrics(view)
          half_width = (metrics[:width] + PADDING * 2) / 2.0
          half_height = [LABEL_HEIGHT, metrics[:height] + 8].max / 2.0
          corners = [
            Geom::Point3d.new(screen.x - half_width, screen.y - half_height, 0),
            Geom::Point3d.new(screen.x + half_width, screen.y - half_height, 0),
            Geom::Point3d.new(screen.x + half_width, screen.y + half_height, 0),
            Geom::Point3d.new(screen.x - half_width, screen.y + half_height, 0)
          ]
          view.drawing_color = Sketchup::Color.new(*BOX_COLOR)
          view.draw2d(GL_QUADS, corners)
          view.draw_text(text_origin(screen, half_width, half_height), metrics[:text], text_options)
        end

        # Chữ và kích thước hộp của khung tên: đo chữ thật bằng View#text_bounds (có từ SketchUp 2020), nếu không đo được thì
        # ước lượng theo số ký tự. Tên dài quá MAX_LABEL_WIDTH thì rút gọn để chữ luôn nằm trong hộp. Nhớ lại cho tới khi đổi tên.
        def label_metrics(view)
          return @label_metrics if @label_metrics && @label_metrics[:source] == @label
          text = @label
          width, height = measure_text(view, text)
          if width > MAX_LABEL_WIDTH
            text = shorten_text(view, text)
            width, height = measure_text(view, text)
          end
          @label_metrics = {source: @label, text: text, width: width, height: height}
        end

        def measure_text(view, text)
          if view.respond_to?(:text_bounds)
            bounds = view.text_bounds(Geom::Point3d.new(0, 0, 0), text, size: LABEL_SIZE)
            return [bounds.width.to_f, bounds.height.to_f]
          end
          [text.length * CHAR_WIDTH, LABEL_SIZE * 1.4]
        rescue StandardError
          [text.length * CHAR_WIDTH, LABEL_SIZE * 1.4]
        end

        # Phần đầu dài nhất của tên mà cộng "…" vẫn vừa MAX_LABEL_WIDTH (tìm nhị phân, đo ít lần).
        def shorten_text(view, text)
          low = 1
          high = text.length - 1
          best = 1
          while low <= high
            mid = (low + high) / 2
            if measure_text(view, text[0, mid].rstrip + ELLIPSIS)[0] <= MAX_LABEL_WIDTH
              best = mid
              low = mid + 1
            else
              high = mid - 1
            end
          end
          text[0, best].rstrip + ELLIPSIS
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
      end

      # Khung đánh dấu đối tượng đang chọn, theo bộ màu VGD:
      # - tô nhẹ các mặt, viền nét đứt quanh khung bao, khung tên (nền nâu, chữ trắng) ở giữa đối tượng.
      # Dùng cho SketchUp 2022 (không có Overlay). Đây là công cụ vẽ tạm: không thêm gì vào model.
      # Click chuột vẫn chọn đối tượng nhưng do công cụ xử lý, nên Shift/Ctrl, kéo chọn, nhấp đúp bị chặn.
      # Nhấn Esc để tắt khung. Đối tượng bị xóa thì khung tự tắt.
      # SketchUp không có lớp gốc Sketchup::Tool; chỉ cần một object có các hàm draw / onLButtonDown / onCancel.
      class BoundsPreview
        include OutlineDrawing

        # alive: hàm kiểm tra đối tượng còn tồn tại; trả về false thì khung tự tắt và gọi on_stale.
        def initialize(points, label: nil, label_point: nil, fills: [], arrows: [[], []], alive: nil, on_stale: nil, &on_done)
          @points = points
          @arrow_fills, @arrow_lines = arrows
          @label = label
          @label_point = label_point
          @fills = fills
          @alive = alive
          @on_stale = on_stale
          @on_done = on_done
          @finished = false
          @stale = false
          @shape_key = nil
          @screen_key = nil
          @label_metrics = nil
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
          draw_arrows(view)
          draw_label(view)
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

      # Khung đánh dấu bằng lớp phủ (Sketchup::Overlay, chỉ có từ SketchUp 2023): chỉ vẽ, không nhận chuột và không chiếm
      # công cụ đang dùng, nên Shift/Ctrl, kéo chọn và nhấp đúp vào group vẫn là của SketchUp.
      # SketchUp 2022 không có lớp phủ nên dùng BoundsPreview (công cụ).
      if defined?(Sketchup::Overlay)
        class BoundsOverlay < Sketchup::Overlay
          include OutlineDrawing
          OVERLAY_ID = 'vgd.bim.outline'.freeze

          def initialize
            super(OVERLAY_ID, 'VGD_BIM · Khung đánh dấu')
            @visible = false
            @points = []
            @fills = []
            @arrow_fills = []
            @arrow_lines = []
          end

          # alive / on_stale giống BoundsPreview: đối tượng bị xóa thì khung tự ẩn và gọi on_stale một lần.
          def show_shapes(points, label: nil, label_point: nil, fills: [], arrows: [[], []], alive: nil, on_stale: nil)
            @points = points
            @arrow_fills, @arrow_lines = arrows
            @label = label
            @label_point = label_point
            @fills = fills
            @alive = alive
            @on_stale = on_stale
            @shape_key = nil
            @screen_key = nil
            @label_metrics = nil
            @visible = true
          end

          def hide_shapes
            @visible = false
          end

          def draw(view)
            return unless @visible
            unless alive?
              @visible = false
              notify_stale
              return
            end
            draw_fills(view)
            draw_outline(view)
            draw_arrows(view)
            draw_label(view)
          end

          private

          # Không làm việc với model ngay trong lúc vẽ; hẹn một nhịp.
          def notify_stale
            callback = @on_stale
            @on_stale = nil
            return unless callback
            if defined?(::UI) && ::UI.respond_to?(:start_timer)
              ::UI.start_timer(0, false) { callback.call }
            else
              callback.call
            end
          end
        end
      end
    end
  end
end
