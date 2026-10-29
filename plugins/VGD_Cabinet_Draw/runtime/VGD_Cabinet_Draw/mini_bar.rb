module VGD_Cabinet_Draw
  # Minitoolbar tròn nổi tại con trỏ (beta.20): các nút tròn xếp thành vòng quanh vị trí chuột phải, kiểu menu vòng.
  #   - MiniBar::Bar: bố cục + vẽ + bắt click (bố cục là Ruby thuần, test được không cần SketchUp).
  #   - Tools::PickTool ("VGD Chọn"): công cụ riêng — bật lên rồi chuột phải lên tủ / cánh / mặt hộc thì hiện thanh nút.
  #   - MiniBar::ToolMenu: gắn vào các công cụ VGD để chuột phải trong công cụ (ví dụ Cánh) cũng hiện thanh nút
  #     thay cho menu thường (getMenu trả false = không hiện menu thường).
  # Các nút lấy từ ContextMenu (cùng danh sách lệnh với menu chuột phải thường).
  module MiniBar
    extend self

    RADIUS = 27        # bán kính nút (px)
    BASE = 82          # bán kính vòng trong
    GAP = 62           # khoảng cách giữa các vòng
    SHORT = {
      'Sửa tủ…' => 'Sửa', 'Chia cánh…' => 'Cánh', 'Thêm đợt / vách…' => 'Đợt', 'Thêm ngăn kéo…' => 'Kéo',
      'Cánh tự động theo hồi' => 'Tự chia', 'Mở tất cả cánh…' => 'Mở', 'Đóng tất cả cánh' => 'Đóng', 'Đặt tay nắm tự động' => 'Nắm', 'Tìm tấm bị trùng' => 'Trùng',
      'Chuẩn hóa tên ván' => 'Tên', 'Đổi loại tủ' => 'Loại', 'Nóc' => 'Nóc', 'Chân cao' => 'Chân', 'Chia nhanh' => 'Chia',
      'Tủ chậu rửa (bỏ hậu)' => 'Chậu', 'Xà treo' => 'Xà', 'Hông chạm đất' => 'Đất', 'Hông đụng trần' => 'Trần',
      'Thêm khoang ngăn kéo…' => 'Khoang', 'Mở cánh…' => 'Mở', 'Đóng cánh' => 'Đóng', 'Bản lề' => 'Lề', 'Đặt tay nắm' => 'Nắm',
      'Xóa tay nắm' => 'Bỏ nắm', 'Loại mở của vùng' => 'Loại mở', 'Chọn tất cả vùng' => 'Tất cả', 'Bỏ chọn vùng' => 'Bỏ chọn',
      'Mở bảng Setting' => 'Setting', 'Mở ngăn kéo…' => 'Kéo ra', 'Đóng ngăn kéo' => 'Kéo vào', 'Hiện khối tham chiếu' => 'Khối',
      'Đóng tất cả cánh của tủ đang chọn' => 'Đóng'
    }.freeze


    # Bỏ vạch ngăn, giữ thứ tự (cả trong menu con).
    def flatten(list)
      list.reject { |entry| entry[:separator] }.map { |entry| entry[:items] ? entry.merge(items: flatten(entry[:items])) : entry }
    end

    def short_label(label)
      return SHORT[label] if SHORT[label]
      word = label.to_s.sub(/…\z/, '').split(/\s+/).first.to_s
      word.length > 6 ? word[0, 6] : word
    end

    class Bar
      attr_reader :items, :cx, :cy, :buttons, :expanded, :hover_index, :title

      def initialize(items, cx, cy, title = '')
        @items = MiniBar.flatten(items)
        @cx = cx.to_f
        @cy = cy.to_f
        @title = title
        @expanded = nil
        @hover_index = nil
        @vw = 1200.0
        @vh = 800.0
        layout!
      end

      def fit_to(width, height)
        return if @vw == width.to_f && @vh == height.to_f
        @vw = width.to_f
        @vh = height.to_f
        layout!
      end

      # Số vòng cần cho n nút ở bán kính r.
      def capacity(radius)
        [(2 * Math::PI * radius / (2 * RADIUS + 8)).floor, 1].max
      end

      def layout!
        rings = []
        rest = @items.each_with_index.to_a
        level = 0
        until rest.empty?
          radius = BASE + level * GAP
          rings << [radius, rest.shift(capacity(radius))]
          level += 1
        end
        outer = rings.empty? ? BASE : rings.last[0]
        extra = @expanded ? GAP : 0
        margin = outer + extra + RADIUS + 4
        @cx = clamp(@cx, margin, @vw - margin)
        @cy = clamp(@cy, margin, @vh - margin)
        @buttons = []
        rings.each_with_index do |(radius, entries), ring_index|
          step = 2 * Math::PI / entries.length
          start = -Math::PI / 2 + (ring_index.odd? ? step / 2 : 0)
          entries.each_with_index do |(item, index), i|
            angle = start + i * step
            @buttons << { item: item, index: index, x: @cx + radius * Math.cos(angle), y: @cy + radius * Math.sin(angle), r: RADIUS, angle: angle, level: 0, parent: nil }
          end
        end
        place_children(outer + GAP) if @expanded
      end

      def place_children(radius)
        parent = @buttons.find { |b| b[:level] == 0 && b[:index] == @expanded }
        return unless parent && parent[:item][:items]
        children = parent[:item][:items]
        step = 2 * Math.asin([(RADIUS + 5) / radius.to_f, 1.0].min)
        children.each_with_index do |item, i|
          angle = parent[:angle] + (i - (children.length - 1) / 2.0) * step
          x = clamp(@cx + radius * Math.cos(angle), RADIUS + 2, @vw - RADIUS - 2)
          y = clamp(@cy + radius * Math.sin(angle), RADIUS + 2, @vh - RADIUS - 2)
          @buttons << { item: item, index: i, x: x, y: y, r: RADIUS, angle: angle, level: 1, parent: @expanded }
        end
      end

      def clamp(value, low, high)
        return (low + high) / 2.0 if high < low
        [[value, low].max, high].min
      end

      # Nút nằm dưới điểm (x, y) — ưu tiên vòng ngoài (nút con).
      def button_at(x, y)
        @buttons.reverse.find { |b| (b[:x] - x)**2 + (b[:y] - y)**2 <= b[:r]**2 }
      end

      def hub_at?(x, y)
        (x - @cx)**2 + (y - @cy)**2 <= 22**2
      end

      def hover(x, y)
        found = button_at(x, y)
        @hover_button = found
        found
      end

      def hover_label
        @hover_button ? @hover_button[:item][:label] : @title
      end

      # Click tại (x, y). Trả về :run (đã chạy lệnh), :expand (mở/đóng nhóm), :close (bấm ra ngoài hoặc tâm), :ignore.
      def click(x, y)
        button = button_at(x, y)
        return :close unless button
        item = button[:item]
        return :ignore if item[:enabled] == false
        if item[:items]
          @expanded = @expanded == button[:index] && button[:level] == 0 ? nil : button[:index]
          layout!
          return :expand
        end
        return :ignore unless item[:run]
        ContextMenu.safely(item[:label], &item[:run])
        :run
      end

      # ----- Vẽ -----
      def draw(view)
        fit_to(view.vpwidth, view.vpheight) if view.respond_to?(:vpwidth)
        circle(view, @cx, @cy, 22, Sketchup::Color.new(33, 77, 90, 235), Sketchup::Color.new(255, 255, 255, 255))
        text(view, @cx, @cy, MiniBar.short_label(hover_label.to_s), 9, Sketchup::Color.new(255, 255, 255))
        @buttons.each do |b|
          item = b[:item]
          hovered = @hover_button && @hover_button.equal?(b)
          open = b[:level] == 0 && @expanded == b[:index]
          fill = if item[:enabled] == false then Sketchup::Color.new(210, 214, 216, 220)
                 elsif hovered then Sketchup::Color.new(33, 77, 90, 245)
                 elsif item[:checked] then Sketchup::Color.new(206, 232, 240, 245)
                 else Sketchup::Color.new(244, 248, 250, 240) end
          edge = open ? Sketchup::Color.new(232, 131, 36) : (item[:items] ? Sketchup::Color.new(46, 120, 150) : Sketchup::Color.new(120, 150, 160))
          circle(view, b[:x], b[:y], b[:r], fill, edge)
          label = MiniBar.short_label(item[:label])
          text(view, b[:x], b[:y], (item[:checked] ? '✓' : '') + label + (item[:items] ? '▸' : ''), 9, hovered ? Sketchup::Color.new(255, 255, 255) : Sketchup::Color.new(33, 77, 90))
        end
        text(view, @cx, @cy - BASE - RADIUS - 14, hover_label.to_s, 11, Sketchup::Color.new(33, 77, 90)) if @hover_button
      end

      def circle(view, x, y, r, fill, edge)
        pts = (0...28).map { |i| a = 2 * Math::PI * i / 28; [x + r * Math.cos(a), y + r * Math.sin(a), 0] }
        view.drawing_color = fill
        view.draw2d(GL_POLYGON, pts)
        view.drawing_color = edge
        view.line_width = 2 if view.respond_to?(:line_width=)
        view.draw2d(GL_LINE_LOOP, pts)
      end

      def text(view, x, y, string, size, color)
        width = begin
          view.respond_to?(:text_bounds) ? view.text_bounds([x, y, 0], string, size: size).width : string.length * size * 0.62
        rescue StandardError
          string.length * size * 0.62
        end
        view.draw_text([x - width / 2.0, y - size * 0.7, 0], string, color: color, size: size)
      end
    end

    # Gắn vào các công cụ VGD (prepend SAU PresetHud để thanh nút nhận click trước HUD): chuột phải trong công cụ → thanh nút.
    module ToolMenu
      def onMouseMove(flags, x, y, view)
        @mb_xy = [x, y]
        if @mb_bar
          @mb_bar.fit_to(view.vpwidth, view.vpheight)
          @mb_bar.hover(x, y)
          view.invalidate
          return
        end
        super if defined?(super)
      end

      def onLButtonDown(flags, x, y, view)
        if @mb_bar
          result = @mb_bar.click(x, y)
          @mb_bar = nil if %i[run close].include?(result)
          view.invalidate
          return
        end
        super if defined?(super)
      end

      def onCancel(reason, view)
        if @mb_bar
          @mb_bar = nil
          view.invalidate if view
          return
        end
        super if defined?(super)
      end

      def draw(view)
        super if defined?(super)
        @mb_bar.draw(view) if @mb_bar
      end

      def deactivate(view)
        @mb_bar = nil
        super if defined?(super)
      end

      # Chuột phải trong công cụ: mở thanh nút; trả false để SketchUp không hiện menu thường.
      # Đúng 5 tham số: SketchUp chỉ gọi kiểu mới (có tọa độ, và hiểu false = đừng hiện menu thường) khi hàm khai báo đủ 5 tham số.
      def getMenu(menu, flags, x, y, view)
        x, y = @mb_xy if x.nil? && @mb_xy
        view ||= Sketchup.active_model.active_view
        items = VGD_Cabinet_Draw::ContextMenu.tool_items(self)
        return true if items.empty? || x.nil?
        @mb_bar = Bar.new(items, x, y, VGD_Cabinet_Draw::Tools.label(@tool_name))
        @mb_bar.fit_to(view.vpwidth, view.vpheight)
        view.invalidate
        false
      end
    end

    def attach_to_tools
      Tools.constants.each do |name|
        klass = Tools.const_get(name)
        klass.send(:prepend, ToolMenu) if klass.is_a?(Class) && klass < Tools::Base && !klass.ancestors.include?(ToolMenu)
      end
    end
  end

  module Tools
    # Công cụ "VGD Chọn": chuột phải lên tủ / cánh / mặt hộc → thanh nút tròn tại con trỏ. Không dựng gì, chỉ chọn và chạy lệnh.
    class PickTool
      attr_reader :bar

      def initialize(_settings = {})
        @active = false
        @bar = nil
        @xy = [0, 0]
      end

      def active?; @active; end
      def enableVCB?; false; end

      def activate
        @active = true
        Sketchup.status_text = 'VGD Chọn: nhấp đúp (hoặc chuột phải) lên tủ / cánh để hiện thanh nút · Click chọn · Shift thêm/bớt · Kéo khung chọn nhiều'
        Sketchup.active_model.active_view.invalidate
      end

      def deactivate(view)
        @active = false
        @bar = nil
        @down = nil
        @drag = false
        view.invalidate if view
      end

      def resume(view); view.invalidate if view; end
      def suspend(view); end

      def onCancel(_reason, view)
        if @bar
          @bar = nil
          view.invalidate
        else
          view.model.select_tool(nil)
        end
      end

      def onMouseMove(_flags, x, y, view)
        @xy = [x, y]
        if @down && !@bar
          @drag = true if (x - @down[0]).abs + (y - @down[1]).abs >= DRAG_PIXELS
          view.invalidate if @drag
          return
        end
        return unless @bar
        @bar.fit_to(view.vpwidth, view.vpheight)
        @bar.hover(x, y)
        view.invalidate
      end

      DRAG_PIXELS = 5

      def onLButtonDown(flags, x, y, view)
        if @bar
          result = @bar.click(x, y)
          @bar = nil if %i[run close].include?(result)
          view.invalidate
          return
        end
        @down = [x, y]
        @drag = false
      end

      # Chỉ tủ / cánh VGD do công cụ này xử lý. Vật khác: chọn như SketchUp rồi TRẢ công cụ về Chọn của SketchUp,
      # mọi thao tác tiếp theo (nhấp đúp vào group, nhấp ba, chọn mặt...) để SketchUp làm. Khi chọn lại tủ VGD,
      # VGD Chọn tự quay về (xem VGD_Cabinet_Draw.pick_selection_changed).
      def onLButtonUp(flags, x, y, view)
        down = @down
        @down = nil
        return unless down
        if @drag
          @drag = false
          window_select(down, [x, y], flags, view)
          view.invalidate
          return
        end
        vgd = !pick(view, x, y).nil?
        click_select(flags, x, y, view)
        hand_over_to_select(view) unless vgd
        view.invalidate
      end

      # Trả công cụ cho Chọn của SketchUp (không để chế độ VGD Chọn bật lại ngay).
      def hand_over_to_select(view)
        VGD_Cabinet_Draw.pass_to_su_select if VGD_Cabinet_Draw.respond_to?(:pass_to_su_select)
        view.model.select_tool(nil)
      end

      def click_select(flags, x, y, view)
        raw, entity = pick_context(view, x, y)
        selection = Sketchup.active_model.selection
        additive = Keys.shift?(flags) || Keys.ctrl?(flags)
        if entity.nil?
          return unless raw.empty? # chỉ trỏ vào chính group đang mở: không làm gì
          selection.clear unless additive
          exit_group(view) unless additive # click vùng trống khi đang trong group → thoát một cấp (như beta.27)
        elsif additive
          selection.include?(entity) ? selection.remove(entity) : selection.add(entity)
        else
          select_only(entity)
        end
      end

      # Click vùng trống khi đang mở group (do nhấp đúp vào): thoát ra một cấp.
      def exit_group(view)
        model = view.model
        current = model.active_path
        return if current.nil? || current.empty?
        parent = current[0...-1]
        model.active_path = parent.empty? ? nil : parent
      end

      # Đường đi dưới con trỏ [đầy đủ, đối tượng ở cấp đang mở]. Cấp đang mở = các group đã nhấp đúp vào để vào trong.
      def pick_context(view, x, y)
        helper = view.pick_helper
        helper.do_pick(x, y)
        raw = helper.path_at(0) || []
        return [raw, helper.best_picked] if raw.empty?
        current = Sketchup.active_model.active_path || []
        rest = !current.empty? && raw.first(current.length) == current ? raw.drop(current.length) : raw
        [raw, rest.first]
      end

      # Chọn bằng khung: kéo trái→phải chọn vật nằm trọn trong khung, phải→trái chọn vật chạm khung (như SketchUp).
      def window_select(p1, p2, flags, view)
        selection = Sketchup.active_model.selection
        selection.clear unless Keys.shift?(flags) || Keys.ctrl?(flags)
        helper = view.pick_helper
        return unless helper.respond_to?(:window_pick)
        mode = p2[0] >= p1[0] ? (defined?(Sketchup::PickHelper::PICK_INSIDE) ? Sketchup::PickHelper::PICK_INSIDE : 0) : (defined?(Sketchup::PickHelper::PICK_CROSSING) ? Sketchup::PickHelper::PICK_CROSSING : 1)
        helper.window_pick([p1[0], p1[1], 0], [p2[0], p2[1], 0], mode)
        helper.count.times do |i|
          path = helper.path_at(i)
          entity = path && path.first
          selection.add(entity) if entity && !selection.include?(entity)
        end
      rescue StandardError => e
        Dialog.set_status("Chọn bằng khung không chạy được: #{e.message}")
      end

      # Nhấp đúp: chỉ xử lý tủ / cánh VGD (mở thanh nút). Vật khác đã được SketchUp xử lý.
      def onLButtonDoubleClick(_flags, x, y, view)
        return if @bar
        target = pick(view, x, y)
        return unless target
        select_only(target)
        open_bar(x, y, view)
      end

      # Chuột phải: chọn đối tượng dưới con trỏ và mở thanh nút. Trả false = không hiện menu thường của SketchUp.
      def getMenu(menu, _flags, x, y, view)
        x, y = @xy if x.nil?
        view ||= Sketchup.active_model.active_view
        target = pick(view, x, y)
        unless target
          @bar = nil
          view.invalidate
          return true # không trúng tủ/cánh: để menu thường của SketchUp hiện
        end
        select_only(target)
        open_bar(x, y, view)
        false
      end

      def open_bar(x, y, view)
        items = ContextMenu.items_for(Sketchup.active_model.selection)
        if items.empty?
          @bar = nil
          return nil
        end
        roots, doors = ContextMenu.classify(Sketchup.active_model.selection)
        title = roots.empty? ? (doors.length > 1 ? "#{doors.length} cánh" : 'Cánh') : (roots.length > 1 ? "#{roots.length} tủ" : ContextMenu::TYPE_LABELS[ContextMenu.type_of(roots.first)])
        @bar = MiniBar::Bar.new(items, x, y, title)
        @bar.fit_to(view.vpwidth, view.vpheight)
        view.invalidate
        @bar
      end

      def draw(view)
        @bar.draw(view) if @bar
        draw_window(view) if @drag && @down && !@bar
      end

      def draw_window(view)
        x0, y0 = @down
        x1, y1 = @xy
        pts = [[x0, y0, 0], [x1, y0, 0], [x1, y1, 0], [x0, y1, 0]]
        view.drawing_color = Sketchup::Color.new(33, 77, 90)
        view.line_stipple = x1 >= x0 ? '' : '-' if view.respond_to?(:line_stipple=)
        view.draw2d(GL_LINE_LOOP, pts)
      end

      # Cánh / mặt hộc dưới con trỏ nếu có, không thì tủ.
      def pick(view, x, y)
        helper = view.pick_helper
        helper.do_pick(x, y)
        path = (helper.path_at(0) || []).select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
        door = path.reverse.find { |e| Operations.door?(e) || e.get_attribute(Schema::DICTIONARY, 'kind') == 'drawer_front' }
        return door if door
        path.reverse.find { |e| ModelData.cabinet?(e) }
      end

      def select_only(entity)
        selection = Sketchup.active_model.selection
        return if selection.length == 1 && selection.first == entity
        selection.clear
        selection.add(entity)
      end
    end
  end
end
