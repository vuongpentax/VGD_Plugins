module VGD
  module BIM
    module UI
      # Công cụ hút / đổ tag, dùng như Paint Bucket của SketchUp: bấm = đổ tag hiện tại lên đối tượng, Alt + bấm = hút tag của đối tượng
      # (chưa có tag để đổ thì bấm cũng là hút), Shift + bấm = đổ cho mọi bản sao cùng component, bấm vào món đang nằm trong lựa chọn
      # = đổ cho cả lựa chọn. Công cụ ở lại cho tới khi Esc hoặc chọn công cụ khác. Đối tượng được bấm là đối tượng ở cấp đang mở
      # (không chọn sâu vào bên trong group). Công cụ chỉ báo việc cần làm; đổi model do nơi gọi làm (TagManager#tm_paint_*).
      # SketchUp không có lớp gốc Sketchup::Tool; chỉ cần object có các hàm activate / deactivate / onLButtonDown / onCancel.
      class TagPaintTool
        ALT = defined?(ALT_MODIFIER_MASK) ? ALT_MODIFIER_MASK : 32
        SHIFT = defined?(CONSTRAIN_MODIFIER_MASK) ? CONSTRAIN_MODIFIER_MASK : 4
        ALT_KEY = defined?(ALT_MODIFIER_KEY) ? ALT_MODIFIER_KEY : 18

        # Con trỏ riêng để phân biệt với trỏ chuột thường: ống hút khi bấm là HÚT (giữ Alt, hoặc chưa có tag để đổ), thùng sơn khi bấm là ĐỔ.
        # [tên file SVG trong assets/cursors, điểm nóng x, y]. Chỉ tạo trên Windows như VGD Reference; nền tảng khác giữ con trỏ mặc định.
        CURSORS = {sample: ['tag_sample.svg', 6, 26], paint: ['tag_paint.svg', 5, 26]}.freeze

        attr_reader :tag_name

        # on_paint: gọi với (đối tượng, cách đổ :single | :instances | :selection); on_sample: gọi với đối tượng (nil = không trúng gì);
        # on_done: gọi một lần khi công cụ bị gỡ (Esc, chọn công cụ khác, đóng model).
        def initialize(tag_name, on_paint:, on_sample:, on_done:)
          @tag_name = tag_name.to_s
          @on_paint = on_paint
          @on_sample = on_sample
          @on_done = on_done
          @finished = false
        end

        def tag_name=(name)
          @tag_name = name.to_s
          show_status
        end

        def activate
          show_status
        end

        def resume(_view)
          show_status
        end

        def deactivate(_view)
          Sketchup.status_text = '' if Sketchup.respond_to?(:status_text=)
          done
        end

        def onMouseMove(flags, _x, _y, _view)
          @alt = (flags & ALT) != 0
        end

        def onKeyDown(key, _repeat, _flags, _view)
          @alt = true if key == ALT_KEY
        end

        def onKeyUp(key, _repeat, _flags, _view)
          @alt = false if key == ALT_KEY
        end

        # Đặt con trỏ theo việc bấm sẽ làm; trả về true khi đã đặt, false để SketchUp dùng con trỏ mặc định.
        def onSetCursor
          id = cursor(sampling? ? :sample : :paint)
          id ? ::UI.set_cursor(id) : false
        rescue StandardError => error
          BIM.log("Đặt con trỏ hút / đổ tag lỗi: #{error.message}")
          false
        end

        def sampling?
          @alt == true || @tag_name.empty?
        end

        def onLButtonDown(flags, x, y, view)
          return if @finished
          entity = entity_at(view, x, y)
          if (flags & ALT) != 0 || @tag_name.empty?
            @on_sample.call(entity)
          elsif entity
            @on_paint.call(entity, paint_mode(entity, flags, view.model))
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

        private

        def cursor(kind)
          return nil unless Sketchup.platform == :platform_win
          @cursors ||= {}
          @cursors[kind] ||= begin
            file, hot_x, hot_y = CURSORS.fetch(kind)
            path = File.join(File.expand_path('../assets/cursors', __dir__), file)
            ::UI.create_cursor(path, hot_x, hot_y) if File.exist?(path)
          end
        end

        def paint_mode(entity, flags, model)
          return :instances if (flags & SHIFT) != 0 && entity.respond_to?(:definition)
          return :selection if model.selection.include?(entity)
          :single
        end

        def entity_at(view, x, y)
          depth = (view.model.active_path || []).size
          helper = view.pick_helper
          helper.do_pick(x, y)
          (0...helper.count).each do |i|
            path = helper.path_at(i)
            next if path.nil? || path.size <= depth
            entity = path[depth]
            return entity if entity.respond_to?(:layer)
          end
          nil
        end

        def show_status
          return unless Sketchup.respond_to?(:status_text=)
          Sketchup.status_text = if @tag_name.empty?
                                   'VGD BIM · Alt + bấm (hoặc bấm) vào đối tượng để hút tag. Esc để thoát.'
                                 else
                                   "VGD BIM · Đổ tag: #{@tag_name}. Bấm: đổ · Alt + bấm: hút · Shift + bấm: mọi bản sao · Bấm món đang chọn: cả lựa chọn · Esc: thoát."
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
