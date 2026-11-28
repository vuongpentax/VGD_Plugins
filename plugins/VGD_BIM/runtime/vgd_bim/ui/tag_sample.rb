module VGD
  module BIM
    module UI
      # Công cụ hút / đổ tag, cách dùng giống công cụ của 5D Auto Tag: con trỏ ống hút / thùng sơn (assets/cursors, chủ dự án chọn ở 1.1.2-beta.1
      # vì không đặt con trỏ thì SketchUp không vẽ con trỏ nào), tên và màu tag hiện cạnh con trỏ,
      # đối tượng sẽ được đổ tag được tô sáng (khung + màu nhạt) để biết đang ở cấp nào. Chữ trên con trỏ và dòng trạng thái dùng tiếng Anh
      # như 5D Auto Tag.
      # Chế độ đổ: bấm = đổ tag hiện tại lên đối tượng; Alt = đổi sang chế độ hút (và ngược lại); Ctrl = đổi cấp đối tượng
      # (group / component trên cùng, trong cùng, mặt / cạnh); Shift + bấm = đổ cho mọi bản sao cùng component; bấm vào món đang nằm trong
      # lựa chọn = đổ cho cả lựa chọn. Chế độ hút: bấm = lấy tag đang HIỂN THỊ của đối tượng (tag trong cùng, nếu bị lồng nhiều cấp) rồi
      # tự về chế độ đổ. Chưa có tag để đổ thì bắt đầu ở chế độ hút. Công cụ ở lại cho tới khi Esc hoặc chọn công cụ khác.
      # Công cụ chỉ báo việc cần làm; đổi model do nơi gọi làm (TagManager#tm_paint_*).
      # SketchUp không có lớp gốc Sketchup::Tool; chỉ cần object có các hàm activate / deactivate / onLButtonDown / onCancel...
      class TagPaintTool
        SHIFT = defined?(CONSTRAIN_MODIFIER_MASK) ? CONSTRAIN_MODIFIER_MASK : 4
        ALT_MASK = defined?(ALT_MODIFIER_MASK) ? ALT_MODIFIER_MASK : 32
        CTRL_MASK = defined?(COPY_MODIFIER_MASK) ? COPY_MODIFIER_MASK : 8
        ALT_KEY = defined?(ALT_MODIFIER_KEY) ? ALT_MODIFIER_KEY : 18
        CTRL_KEY = defined?(COPY_MODIFIER_KEY) ? COPY_MODIFIER_KEY : 17
        # Phím đổi chế độ: [phím, cờ của chuột]. Cả hai đường đều được dùng vì có máy SketchUp không gửi onKeyDown đủ lần cho phím Alt.
        RETRIGGER_SECONDS = 0.35
        MODIFIERS = {alt: [ALT_KEY, ALT_MASK], ctrl: [CTRL_KEY, CTRL_MASK]}.freeze

        # Con trỏ theo việc bấm sẽ làm: ống hút khi HÚT, thùng sơn khi ĐỔ. [tên file SVG trong assets/cursors, điểm nóng x, y] (điểm nóng là
        # vòng tròn / giọt sơn ở góc dưới trái). SVG chỉ dùng được trên Windows như VGD Reference; máy khác để SketchUp tự chọn con trỏ.
        CURSORS = {sample: ['tag_sample.svg', 6, 26], paint: ['tag_paint.svg', 5, 26]}.freeze

        # Các cấp đối tượng, thứ tự đổi bằng Ctrl; chữ hiện trong nhãn đen cạnh con trỏ (tiếng Anh như 5D Auto Tag).
        LEVELS = [:top, :deepest, :face].freeze
        LEVEL_LABELS = {top: 'Top level group/comp', deepest: 'Deepest group/comp', face: 'Face/Edge'}.freeze
        STATUS_SAMPLE = 'Click object to get sample tag'.freeze
        STATUS_PAINT = "Click object to set tag | Press 'ALT': Sample mode | Press 'CTRL': switch between object types".freeze

        # Nhãn vẽ cạnh con trỏ (điểm ảnh): lệch khỏi con trỏ, lề chữ, cỡ chữ; ước lượng bề rộng chữ khi SketchUp không đo được.
        LABEL_OFFSET = [18, 22].freeze
        LABEL_PAD = 5
        FONT_SIZE = 10
        CHAR_WIDTH = 7
        LINE_HEIGHT = 16
        SWATCH_SIZE = 14
        GL_QUADS_ID = defined?(GL_QUADS) ? GL_QUADS : 7
        GL_LINE_LOOP_ID = defined?(GL_LINE_LOOP) ? GL_LINE_LOOP : 2
        GL_LINES_ID = defined?(GL_LINES) ? GL_LINES : 1
        GL_TRIANGLES_ID = defined?(GL_TRIANGLES) ? GL_TRIANGLES : 4

        # Khung đối tượng sắp được đổ: màu nhấn VGD, nét dày, tô nhạt.
        HIGHLIGHT_LINE = [180, 137, 99].freeze
        HIGHLIGHT_FILL = [180, 137, 99, 80].freeze
        HIGHLIGHT_WIDTH = 3
        # Khung bao: cặp đỉnh của 12 cạnh và 6 mặt (đỉnh của BoundingBox#corner: bit 0 = x, bit 1 = y, bit 2 = z).
        BOX_EDGES = [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]].freeze
        BOX_FACES = [[0, 1, 3, 2], [4, 5, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5], [0, 1, 5, 4], [2, 3, 7, 6]].freeze

        attr_reader :tag_name, :level

        # on_paint: gọi với (đối tượng, cách đổ :single | :instances | :selection); on_sample: gọi với đối tượng mang tag đang hiển thị
        # (nil = không trúng gì); on_done: gọi một lần khi công cụ bị gỡ (Esc, chọn công cụ khác, đóng model).
        def initialize(tag_name, on_paint:, on_sample:, on_done:)
          @tag_name = tag_name.to_s
          @on_paint = on_paint
          @on_sample = on_sample
          @on_done = on_done
          @finished = false
          @level = :top
          @sample_mode = @tag_name.empty?
          @held = {}
          @pressed_at = {}
          @flags_ok = {}
        end

        def tag_name=(name)
          @tag_name = name.to_s
          @paint_color = nil
          @hover = nil
          show_status
        end

        def sampling?
          @sample_mode
        end

        def activate
          show_status
        end

        def resume(view)
          show_status
          view.invalidate if view.respond_to?(:invalidate)
        end

        def deactivate(view)
          Sketchup.status_text = '' if Sketchup.respond_to?(:status_text=)
          view.invalidate if view.respond_to?(:invalidate)
          done
        end

        def onMouseMove(flags, x, y, view)
          @mouse = [x, y]
          sync_modifiers(flags.to_i)
          update_hover(view)
        end

        # Alt đổi giữa hút và đổ; Ctrl đổi cấp đối tượng. Mỗi lần nhấn chỉ tính một lần (giữ phím không đổi liên tục).
        def onKeyDown(key, repeat, _flags, view)
          name = modifier_for(key)
          return unless name
          @held[name] = false if repeat.to_i <= 1 && stale?(name) # lần nhấn mới dù lần thả trước bị mất (thanh menu Windows có thể lấy phím Alt)
          return unless press(name)
          show_status
          update_hover(view)
        end

        def onKeyUp(key, _repeat, _flags, _view)
          name = modifier_for(key)
          @held[name] = false if name
        end

        def onLButtonDown(flags, x, y, view)
          return if @finished
          path = pick_path(view, x, y)
          if @sample_mode
            @on_sample.call(displayed_entity(path))
            @sample_mode = false unless @tag_name.empty? # hút xong về chế độ đổ
            @paint_color = nil
            show_status
            update_hover(view)
          elsif path
            entity = level_entity(path, depth_of(view))
            @on_paint.call(entity, paint_mode(entity, flags, view.model)) if entity
          end
        rescue StandardError => error
          BIM.log("Hút / đổ tag lỗi: #{error.message}")
        end

        def onCancel(_reason, view)
          done
          view.model.select_tool(nil)
        rescue StandardError => error
          BIM.log("Thoát công cụ hút / đổ tag lỗi: #{error.message}")
        end

        # Đặt con trỏ theo chế độ; true khi đã đặt, false để SketchUp tự chọn (máy không phải Windows hoặc thiếu file).
        def onSetCursor
          id = cursor(@sample_mode ? :sample : :paint)
          id ? ::UI.set_cursor(id) : false
        rescue StandardError => error
          log_draw_error("Đặt con trỏ hút / đổ tag lỗi: #{error.message}")
          false
        end

        # Chế độ hút: nhãn tên + màu tag đang hiển thị của đối tượng dưới con trỏ. Chế độ đổ: tô sáng đối tượng sẽ được đổ, nhãn tên tag
        # sẽ đổ (ô màu nhỏ ở góc) và nhãn đen ghi cấp đối tượng.
        def draw(view)
          return unless @hover
          draw_highlight(view) unless @sample_mode
          x = @hover[:x] + LABEL_OFFSET[0]
          y = @hover[:y] + LABEL_OFFSET[1]
          if @sample_mode
            return unless @hover[:name]
            width, = draw_label(view, x, y, @hover[:name], [255, 255, 255], [30, 30, 30])
            draw_swatch(view, x + width, y, @hover[:color])
          else
            _, height = draw_label(view, x, y, @tag_name, [255, 255, 255], [30, 30, 30])
            draw_swatch(view, x - SWATCH_SIZE / 2, y - SWATCH_SIZE / 2, @hover[:color], SWATCH_SIZE / 2 + 2)
            draw_label(view, x, y + height, LEVEL_LABELS[@level], [0, 0, 0], [255, 255, 255])
          end
        rescue StandardError => error
          log_draw_error("Vẽ nhãn hút / đổ tag lỗi: #{error.message}")
        end

        private

        def cursor(kind)
          return nil unless Sketchup.platform == :platform_win
          @cursors ||= {}
          return @cursors[kind] if @cursors.key?(kind)
          file, hot_x, hot_y = CURSORS.fetch(kind)
          path = File.join(File.expand_path('../assets/cursors', __dir__), file)
          @cursors[kind] = File.exist?(path) ? ::UI.create_cursor(path, hot_x, hot_y) : nil
        end

        def modifier_for(key)
          found = MODIFIERS.find { |_name, (code, _mask)| code == key }
          found && found[0]
        end

        def default_name?(name)
          TagManager::UNTAGGED_NAMES.include?(name.to_s)
        end

        def log_draw_error(message)
          return if @draw_error == message # lỗi lặp mỗi khung hình thì chỉ ghi một lần
          @draw_error = message
          BIM.log(message)
        end

        # Một lần nhấn phím: Alt đổi chế độ, Ctrl đổi cấp. false nếu phím đang được giữ (đã tính rồi) hoặc không có việc để làm.
        def press(name)
          return false if @held[name]
          @held[name] = true
          @pressed_at[name] = now
          case name
          when :alt
            PasteKeys.cancel_alt_menu # Alt dùng cho công cụ: không để Windows mở thanh menu của SketchUp khi thả Alt
            toggle_mode
          when :ctrl then @level = LEVELS[(LEVELS.index(@level) + 1) % LEVELS.size]
          end
          true
        end

        # Cờ phím của sự kiện chuột: nếu phím đang giữ mà onKeyDown chưa tới thì tính luôn; thả phím thì nhớ lại (chỉ khi máy này có
        # gửi cờ, để không đếm hai lần khi phím lặp).
        def sync_modifiers(flags)
          changed = false
          MODIFIERS.each do |name, (_key, mask)|
            if (flags & mask) != 0
              @flags_ok[name] = true
              changed = true if press(name)
            elsif @flags_ok[name]
              @held[name] = false
            end
          end
          show_status if changed
        end

        def now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        # Phím được coi là còn giữ từ lần nhấn trước (chưa thấy thả) đã quá lâu: lần nhấn này là lần mới. Nhấn lại trong khoảng
        # RETRIGGER_SECONDS là cùng một lần nhấn báo qua hai đường (phím và cờ của chuột).
        def stale?(name)
          @held[name] && now - @pressed_at[name].to_f > RETRIGGER_SECONDS
        end

        def toggle_mode
          return if @sample_mode && @tag_name.empty? # chưa có tag để đổ thì chưa chuyển sang đổ được
          @sample_mode = !@sample_mode
          @paint_color = nil
        end

        def depth_of(view)
          (view.model.active_path || []).size
        end

        # Đường pick đầu tiên đi vào được cấp đang mở: [phần tử ngoài cùng ... phần tử trong cùng]; nil nếu không trúng gì.
        def pick_path(view, x, y)
          depth = depth_of(view)
          helper = view.pick_helper
          helper.do_pick(x, y)
          (0...helper.count).each do |i|
            path = helper.path_at(i)
            next if path.nil? || path.size <= depth
            return path if path[depth].respond_to?(:layer)
          end
          nil
        end

        def container?(entity)
          entity.respond_to?(:layer) && entity.respond_to?(:definition) && !entity.definition.nil?
        end

        # Đối tượng được đổ theo cấp đang chọn: top = ngoài cùng ở cấp đang mở, deepest = group / component trong cùng (không có thì
        # chính phần tử trong cùng), face = phần tử trong cùng (mặt hoặc cạnh).
        def level_entity(path, depth)
          index = level_index(path, depth)
          entity = path[index]
          entity.respond_to?(:layer) ? entity : nil
        end

        def level_index(path, depth)
          case @level
          when :face then path.size - 1
          when :deepest then (depth...path.size).to_a.reverse.find { |i| container?(path[i]) } || path.size - 1
          else depth
          end
        end

        # Đối tượng mang tag đang hiển thị: từ trong ra ngoài, phần tử đầu tiên có tag khác Untagged; không có thì phần tử trong cùng.
        def displayed_entity(path)
          return nil if path.nil?
          path.reverse.find { |item| item.respond_to?(:layer) && item.layer && !default_name?(item.layer.name) } || path.last
        end

        def paint_mode(entity, flags, model)
          return :instances if (flags & SHIFT) != 0 && entity.respond_to?(:definition)
          return :selection if model.selection.include?(entity)
          :single
        end

        def update_hover(view)
          return unless @mouse
          @hover = {x: @mouse[0], y: @mouse[1]}
          if @sample_mode
            layer = (entity = displayed_entity(pick_path(view, @mouse[0], @mouse[1]))) && entity.layer
            if layer
              @hover[:name] = default_name?(layer.name) ? 'Untagged' : layer.name.to_s
              @hover[:color] = layer_color(layer)
            end
          else
            @hover[:color] = paint_color(view.model)
            @hover[:shape] = target_shape(view)
          end
          view.invalidate if view.respond_to?(:invalidate)
        end

        # Màu của tag sẽ đổ; tìm trong model một lần cho tới khi đổi tag hoặc đổi chế độ (không tìm lại mỗi lần rê chuột).
        def paint_color(model)
          @paint_color ||= [layer_color(layer_named(model, @tag_name))]
          @paint_color[0]
        end

        def layer_named(model, name)
          return model.layers.to_a.find { |layer| default_name?(layer.name) } if default_name?(name)
          Tags.find_layer(model, name)
        end

        def layer_color(layer)
          layer.color if layer && layer.respond_to?(:color)
        end

        # ---- Tô sáng đối tượng sắp được đổ ----

        # Hình của đối tượng ở cấp đang chọn, theo tọa độ thế giới: {fill: [tam giác], lines: [cặp điểm]}; nil nếu không có gì hoặc lỗi.
        # Group / component: khung bao của định nghĩa; mặt: cạnh và tam giác của mặt; cạnh: một đoạn.
        def target_shape(view)
          path = pick_path(view, @mouse[0], @mouse[1])
          return nil unless path
          index = level_index(path, depth_of(view))
          entity = path[index]
          return nil unless entity.respond_to?(:layer)
          world = path[0...index].inject(Geom::Transformation.new) { |total, item| item.respond_to?(:transformation) ? total * item.transformation : total }
          if container?(entity)
            box_shape(entity, world * entity.transformation)
          elsif entity.respond_to?(:mesh)
            face_shape(entity, world)
          elsif entity.respond_to?(:start)
            {fill: [], lines: [entity.start.position.transform(world), entity.end.position.transform(world)]}
          end
        rescue StandardError => error
          log_draw_error("Tính khung đối tượng hút / đổ tag lỗi: #{error.message}")
          nil
        end

        def box_shape(entity, transform)
          bounds = entity.definition.bounds
          return nil if bounds.empty?
          corners = (0..7).map { |i| bounds.corner(i).transform(transform) }
          fill = BOX_FACES.flat_map { |a, b, c, d| [corners[a], corners[b], corners[c], corners[a], corners[c], corners[d]] }
          {fill: fill, lines: BOX_EDGES.flat_map { |a, b| [corners[a], corners[b]] }}
        end

        def face_shape(face, transform)
          mesh = face.mesh
          points = mesh.points.map { |point| point.transform(transform) }
          fill = mesh.polygons.flat_map do |polygon|
            ids = polygon.map { |i| i.abs - 1 }
            (1...(ids.size - 1)).flat_map { |k| [points[ids[0]], points[ids[k]], points[ids[k + 1]]] }
          end
          {fill: fill, lines: face.edges.flat_map { |edge| [edge.start.position.transform(transform), edge.end.position.transform(transform)] }}
        end

        def projector
          @projector ||= Object.new.extend(OutlineDrawing)
        end

        # Cách chiếu điểm thế giới lên màn hình dùng chung với khung đánh dấu của bảng (xử lý cả lúc đang mở sửa group); nil = chưa chiếu được.
        def screen_mode_for(view)
          mode = projector.screen_mode(view)
          return mode if mode
          view.model.edit_transform.to_a == OutlineDrawing::IDENTITY_MATRIX ? {local: false} : nil
        end

        def draw_highlight(view)
          shape = @hover[:shape]
          return unless shape
          mode = screen_mode_for(view)
          return unless mode
          unless shape[:fill].empty?
            view.drawing_color = Sketchup::Color.new(*HIGHLIGHT_FILL)
            projector.draw_screen_triangles(view, shape[:fill], mode)
          end
          view.line_stipple = '' if view.respond_to?(:line_stipple=)
          view.line_width = HIGHLIGHT_WIDTH
          view.drawing_color = Sketchup::Color.new(*HIGHLIGHT_LINE)
          projector.draw_screen_segments(view, shape[:lines], mode)
        end

        # ---- Nhãn cạnh con trỏ ----

        # Kích thước chữ: SketchUp (View#text_bounds, chưa kiểm tra ở bản 2022) đo giúp, không có thì ước lượng.
        def text_size(view, text)
          if view.respond_to?(:text_bounds)
            bounds = view.text_bounds(Geom::Point3d.new(0, 0, 0), text, size: FONT_SIZE)
            return [bounds.width.ceil, bounds.height.ceil]
          end
          [text.length * CHAR_WIDTH, LINE_HEIGHT]
        rescue StandardError
          [text.length * CHAR_WIDTH, LINE_HEIGHT]
        end

        # Vẽ một nhãn (ô nền + chữ); trả về [rộng, cao] của ô.
        def draw_label(view, x, y, text, background, foreground)
          text_w, text_h = text_size(view, text)
          width = text_w + LABEL_PAD * 2
          height = text_h + LABEL_PAD
          draw_box(view, x, y, width, height, Sketchup::Color.new(*background), Sketchup::Color.new(120, 120, 120))
          view.draw_text(Geom::Point3d.new(x + LABEL_PAD, y + LABEL_PAD / 2, 0), text, size: FONT_SIZE, color: Sketchup::Color.new(*foreground))
          [width, height]
        end

        # Ô màu của tag (không vẽ khi tag không có màu).
        def draw_swatch(view, x, y, color, size = SWATCH_SIZE)
          return unless color
          draw_box(view, x, y, size, size, color, Sketchup::Color.new(60, 60, 60))
        end

        def draw_box(view, x, y, width, height, fill, border)
          corners = [[x, y], [x + width, y], [x + width, y + height], [x, y + height]].map { |px, py| Geom::Point3d.new(px, py, 0) }
          view.drawing_color = fill
          view.draw2d(GL_QUADS_ID, corners)
          view.drawing_color = border
          view.line_width = 1
          view.draw2d(GL_LINE_LOOP_ID, corners)
        end

        def show_status
          Sketchup.status_text = @sample_mode ? STATUS_SAMPLE : STATUS_PAINT if Sketchup.respond_to?(:status_text=)
        end

        def done
          return if @finished
          @finished = true
          @on_done.call
        end
      end
    end
  end
end
