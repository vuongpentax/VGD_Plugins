module VGD
  module BIM
    module UI
      # Công cụ hút / đổ tag, cách dùng giống công cụ của 5D Auto Tag: dùng con trỏ mặc định của SketchUp, tên và màu tag hiện cạnh con trỏ.
      # Chế độ đổ: bấm = đổ tag hiện tại lên đối tượng; Alt = đổi sang chế độ hút (và ngược lại); Ctrl = đổi cấp đối tượng
      # (nhóm / component trên cùng, trong cùng, mặt / cạnh); Shift + bấm = đổ cho mọi bản sao cùng component; bấm vào món đang nằm trong
      # lựa chọn = đổ cho cả lựa chọn. Chế độ hút: bấm = lấy tag đang HIỂN THỊ của đối tượng (tag trong cùng, nếu bị lồng nhiều cấp) rồi
      # tự về chế độ đổ. Chưa có tag để đổ thì bắt đầu ở chế độ hút. Công cụ ở lại cho tới khi Esc hoặc chọn công cụ khác.
      # Công cụ chỉ báo việc cần làm; đổi model do nơi gọi làm (TagManager#tm_paint_*).
      # SketchUp không có lớp gốc Sketchup::Tool; chỉ cần object có các hàm activate / deactivate / onLButtonDown / onCancel...
      class TagPaintTool
        SHIFT = defined?(CONSTRAIN_MODIFIER_MASK) ? CONSTRAIN_MODIFIER_MASK : 4
        ALT_KEY = defined?(ALT_MODIFIER_KEY) ? ALT_MODIFIER_KEY : 18
        CTRL_KEY = defined?(COPY_MODIFIER_KEY) ? COPY_MODIFIER_KEY : 17

        # Các cấp đối tượng, thứ tự đổi bằng Ctrl; chữ hiện trong nhãn đen cạnh con trỏ.
        LEVELS = [:top, :deepest, :face].freeze
        LEVEL_LABELS = {top: 'Nhóm / comp trên cùng', deepest: 'Nhóm / comp trong cùng', face: 'Mặt / cạnh'}.freeze

        # Nhãn vẽ cạnh con trỏ (điểm ảnh): lệch khỏi con trỏ, lề chữ, cỡ chữ; ước lượng bề rộng chữ khi SketchUp không đo được.
        LABEL_OFFSET = [18, 22].freeze
        LABEL_PAD = 5
        FONT_SIZE = 10
        CHAR_WIDTH = 7
        LINE_HEIGHT = 16
        SWATCH_SIZE = 14
        GL_QUADS_ID = defined?(GL_QUADS) ? GL_QUADS : 7
        GL_LINE_LOOP_ID = defined?(GL_LINE_LOOP) ? GL_LINE_LOOP : 2

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
        end

        def tag_name=(name)
          @tag_name = name.to_s
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

        def onMouseMove(_flags, x, y, view)
          @mouse = [x, y]
          update_hover(view)
        end

        # Alt đổi giữa hút và đổ; Ctrl đổi cấp đối tượng. Chỉ tính lần nhấn đầu (giữ phím không đổi liên tục).
        def onKeyDown(key, repeat, _flags, view)
          return if repeat.to_i > 1
          if key == ALT_KEY
            toggle_mode
          elsif key == CTRL_KEY
            @level = LEVELS[(LEVELS.index(@level) + 1) % LEVELS.size]
          else
            return
          end
          show_status
          update_hover(view)
        end

        def onLButtonDown(flags, x, y, view)
          return if @finished
          path = pick_path(view, x, y)
          if @sample_mode
            @on_sample.call(displayed_entity(path))
            @sample_mode = false unless @tag_name.empty? # hút xong về chế độ đổ
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

        # Nhãn cạnh con trỏ: chế độ hút = tên + màu tag đang hiển thị của đối tượng dưới con trỏ; chế độ đổ = tên + màu tag sẽ đổ
        # (ô vuông nhỏ ở góc) và nhãn đen ghi cấp đối tượng sẽ đổ.
        def draw(view)
          return unless @hover
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
          BIM.log("Vẽ nhãn hút / đổ tag lỗi: #{error.message}")
        end

        private

        def default_name?(name)
          TagManager::UNTAGGED_NAMES.include?(name.to_s)
        end

        def toggle_mode
          return if @sample_mode && @tag_name.empty? # chưa có tag để đổ thì chưa chuyển sang đổ được
          @sample_mode = !@sample_mode
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
          entity = case @level
                   when :face then path.last
                   when :deepest then path[depth..-1].reverse.find { |item| container?(item) } || path.last
                   else path[depth]
                   end
          entity.respond_to?(:layer) ? entity : nil
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
            @hover[:color] = layer_color(layer_named(view.model, @tag_name))
          end
          view.invalidate if view.respond_to?(:invalidate)
        end

        def layer_named(model, name)
          return model.layers.to_a.find { |layer| default_name?(layer.name) } if default_name?(name)
          Tags.find_layer(model, name)
        end

        def layer_color(layer)
          layer.color if layer && layer.respond_to?(:color)
        end

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
          return unless Sketchup.respond_to?(:status_text=)
          Sketchup.status_text = if @sample_mode
                                   'VGD BIM · Bấm vào đối tượng để hút tag. Alt: chuyển sang đổ tag | Esc: thoát.'
                                 else
                                   "VGD BIM · Đổ tag: #{@tag_name}. Bấm vào đối tượng để đổ tag | Alt: chế độ hút | Ctrl: đổi cấp đối tượng " \
                                     "(đang: #{LEVEL_LABELS[@level]}) | Shift + bấm: mọi bản sao | Esc: thoát."
                                 end
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
