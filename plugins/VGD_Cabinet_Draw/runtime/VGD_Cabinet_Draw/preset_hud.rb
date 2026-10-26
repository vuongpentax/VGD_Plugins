module VGD_Cabinet_Draw
  # HUD trong viewport cho 4 công cụ chính (Box, Đợt/vách, Cánh + Mở cánh, Ngăn kéo), chia 3 phần:
  #   1. MẪU      (góc trái):  danh sách setting đã lưu, click để dùng.
  #   2. CHẾ ĐỘ   (giữa trên): nút chọn chế độ, ví dụ Cánh phủ / Cánh lọt / Thông thủy.
  #   3. THÔNG SỐ (góc phải):  bảng thông số đang dùng. Số: click rồi gõ vào ô VCB + Enter. Bật/tắt và danh sách: click.
  # Hướng dẫn ngắn nằm ở thanh trạng thái mặc định của SketchUp (góc dưới trái).
  # KHÔNG dùng phím tắt Ctrl+số (tránh đụng phím tắt riêng của người dùng).
  # Gắn vào các lớp công cụ bằng prepend nên không phải sửa từng công cụ. Công cụ có thể khai báo thêm (đều tùy chọn):
  #   hud_target_settings  hash thông số đang sửa (mặc định @settings)
  #   hud_read(key) / hud_write(key, value)   đọc/ghi giá trị đặc biệt
  #   hud_guard(key, value)  trả chuỗi lỗi nếu không cho đổi lúc này
  #   hud_after_set(key)     việc cần làm sau khi đổi
  #   status_hint            hướng dẫn ngắn cho thanh trạng thái
  module PresetHud
    MAX_ROWS = 9
    LEFT_WIDTH = 200
    RIGHT_WIDTH = 280
    VALUE_X = 150
    ROW_HEIGHT = 20
    HEAD_HEIGHT = 24
    BUTTON_HEIGHT = 26
    MARGIN = 12

    BOARD = { key: 'board_thickness', label: 'Dày ván', type: :mm, min: 3, max: 100 }.freeze

    # Mô tả từng công cụ: tiêu đề, chế độ (nút) và các thông số (hàng).
    # type: :mm (số, mm) · :int (số nguyên) · :bool (bật/tắt) · :enum (đổi vòng tròn theo options)
    SPECS = {
      'box' => {
        title: 'Box → Board',
        mode: { key: 'cabinet_type', items: [['standard', 'Tủ thường', 'Thùng tủ đủ nóc, đáy, hậu (tủ áo, tủ kệ...)'],
                                              ['base', 'Bếp dưới', 'Tủ bếp dưới: 2 thanh giằng thay nóc để đặt mặt đá, chân 100 mm, len chân lùi 50 mm'],
                                              ['wall', 'Bếp trên', 'Tủ bếp trên: có xà treo áp hậu dưới nóc để treo tường, không chân'],
                                              ['fridge', 'Tủ lạnh', 'Thùng tủ lạnh: hông chạm đất, phần tủ lạnh không đáy/không hậu, hộc trên đặt ở cao tủ lạnh + khe']] },
        params: [
          BOARD,
          { key: 'back_mode', label: 'Kiểu hậu', type: :enum, options: [['groove', 'Âm 4 cạnh'], ['groove_sides', 'Âm 2 hông'], ['lua_top', 'Lùa trên'], ['lua_bottom', 'Lùa đáy'], ['overlay', 'Phủ'], ['none', 'Không hậu']] },
          { key: 'back_thickness', label: 'Dày hậu', type: :mm, min: 1, max: 30 },
          { key: 'fridge_width', label: 'Rộng tủ lạnh', type: :mm, min: 300, max: 2000, only: { 'cabinet_type' => %w[fridge] } },
          { key: 'fridge_height', label: 'Cao tủ lạnh', type: :mm, min: 400, max: 2600, only: { 'cabinet_type' => %w[fridge] } },
          { key: 'fridge_depth', label: 'Sâu tủ lạnh', type: :mm, min: 300, max: 1200, only: { 'cabinet_type' => %w[fridge] } },
          { key: 'fridge_side_gap', label: 'Khe 2 bên tủ lạnh', type: :mm, min: 0, max: 200, only: { 'cabinet_type' => %w[fridge] } },
          { key: 'fridge_top_gap', label: 'Khe trên tủ lạnh', type: :mm, min: 0, max: 500, only: { 'cabinet_type' => %w[fridge] } },
          { key: 'fridge_back_gap', label: 'Khe sau tủ lạnh', type: :mm, min: 0, max: 300, only: { 'cabinet_type' => %w[fridge] } },
          { key: 'top_rail_width', label: 'Bản giằng nóc', type: :mm, min: 30, max: 300, only: { 'cabinet_type' => %w[base] } },
          { key: 'hang_rail', label: 'Xà treo', type: :bool, only: { 'cabinet_type' => %w[wall] } },
          { key: 'hang_rail_height', label: 'Bản xà treo', type: :mm, min: 30, max: 300, only: { 'cabinet_type' => %w[wall] } },
          { key: 'leg_height', label: 'Chân cao', type: :mm, min: 0, max: 300 },
          { key: 'ceiling_strip_height', label: 'Khe trần', type: :mm, min: 0, max: 300 },
          { key: 'sides_to_floor', label: 'Hông chạm đất', type: :bool },
          { key: 'sides_to_ceiling', label: 'Hông đụng trần', type: :bool },
          { key: 'toe_kick_enabled', label: 'Ván che chân', type: :bool },
          { key: 'cornice_enabled', label: 'Phào trần', type: :bool },
          { key: 'sync_front', label: 'Đồng bộ mặt trước', type: :bool },
          { key: 'keep_source', label: 'Giữ box gốc', type: :bool }
        ]
      },
      'face' => {
        title: 'Face → Ván',
        mode: { key: 'board_face_side', items: [['normal', 'Theo pháp tuyến', 'Dựng ván về phía pháp tuyến của face'], ['reverse', 'Ngược pháp tuyến', 'Dựng ván về phía ngược lại'], ['center', 'Chia đều hai phía', 'Face nằm giữa bề dày ván']] },
        params: [
          { key: '_thickness', label: 'Dày ván', type: :mm, min: 0.5, max: 500 }
        ]
      },
      'panel' => {
        title: 'Đợt / vách',
        mode: { key: 'panel_kind', items: [['thong_thuy', 'Thông thủy', 'Các ô trống sạch bằng nhau'], ['lot_long', 'Lọt lòng', 'Chia lòng tủ đều, tấm nằm giữa ranh giới'], ['phu_bi', 'Phủ bì', 'Chia đều theo tim tấm trên bề ngoài tủ']] },
        params: [
          { key: 'panel_axis', label: 'Hướng', type: :enum, options: [['horizontal', 'Đợt ngang'], ['vertical', 'Vách đứng']] },
          BOARD,
          { key: 'panel_limit', label: 'Giới hạn trong ô', type: :bool },
          { key: 'panel_span', label: 'Phạm vi', type: :enum, options: [['cell', 'Lọt trong ô'], ['full', 'Xuyên qua tấm']] },
          { key: 'shelf_front_setback', label: 'Đợt lùi trước', type: :mm, min: 0, max: 200 },
          { key: 'panel_door_fit', label: 'Cánh của tủ', type: :enum, options: [['auto', 'Tự đọc từ tủ'], ['phu', 'Cánh phủ'], ['lot', 'Cánh lọt (+dày cánh)']] }
        ]
      },
      'door' => {
        title: 'Cánh tủ',
        mode: { key: 'door_fit', items: [['phu', 'Cánh phủ', 'Cánh phủ nóc, đáy và hông (chọn hông trái/phải bên dưới). Bấm Tab để đổi.'], ['lot', 'Cánh lọt', 'Cánh nằm giữa hai hông, cao phủ nóc và đáy; nóc, đáy, phào, chân lùi vào bằng dày cánh. Bấm Tab để đổi.']] },
        params: [
          { key: 'split_axis', label: 'Hướng chia', type: :enum, options: [['vertical', 'Dọc (cạnh nhau)'], ['horizontal', 'Ngang (chồng lên)']] },
          { key: 'door_gap', label: 'Khe giữa cánh', type: :mm, min: 0, max: 30 },
          { key: 'door_cover_left', label: 'Phủ hông trái', type: :bool, only: { 'door_fit' => %w[phu] } },
          { key: 'door_cover_right', label: 'Phủ hông phải', type: :bool, only: { 'door_fit' => %w[phu] } },
          { key: 'door_edge_gap', label: 'Khe mép (cánh phủ)', type: :mm, min: 0, max: 30 },
          { key: 'door_inset_gap', label: 'Khe mép (cánh lọt)', type: :mm, min: 0, max: 30 },
          { key: 'door_style', label: 'Kiểu cánh', type: :enum, options: [['flat', 'Phẳng'], ['shaker', 'Shaker'], ['recessed', 'Panel âm'], ['glass', 'Khung kính']] },
          BOARD.merge(label: 'Dày cánh / ván'),
          { key: 'show_dims', label: 'Hiện kích thước', type: :bool }
        ]
      },
      'opening' => {
        title: 'Mở cánh',
        mode: { key: 'hinge_side', items: [['left', 'Bản lề trái', 'Cánh mở sang trái'], ['right', 'Bản lề phải', 'Cánh mở sang phải'], ['top', 'Lật lên', 'Bản lề phía trên, cánh lật lên'], ['bottom', 'Lật xuống', 'Bản lề phía dưới, cánh lật xuống'], ['drawer', 'Ngăn kéo', 'Chỉ lưu dữ liệu, không xoay']] },
        params: []
      },
      'drawer' => {
        title: 'Ngăn kéo',
        mode: { key: 'drawer_mode', items: [['full', 'Mặt + thùng', 'Tạo cả mặt hộc và thùng kéo'], ['front_only', 'Chỉ mặt hộc', 'Chỉ tạo mặt hộc'], ['box_only', 'Chỉ thùng kéo', 'Chỉ tạo thùng kéo bên trong']] },
        params: [
          { key: 'drawer_count', label: 'Số hộc', type: :int, min: 1, max: 20 },
          { key: 'drawer_front_height', label: 'Cao mặt hộc (0=đều)', type: :mm, min: 0, max: 1000 },
          { key: 'drawer_gap', label: 'Khe giữa mặt hộc', type: :mm, min: 0, max: 30 },
          { key: 'drawer_fit', label: 'Kiểu mặt hộc', type: :enum, options: [['auto', 'Theo cánh của tủ'], ['phu', 'Phủ'], ['lot', 'Lọt'], ['thong_thuy', 'Thông thủy']] },
          { key: 'drawer_slide', label: 'Ray', type: :enum, options: [['side', 'Ray bi (bên)'], ['under', 'Ray âm']] },
          { key: 'drawer_depth', label: 'Sâu thùng (0=tự)', type: :mm, min: 0, max: 800 },
          { key: 'drawer_bottom_type', label: 'Loại đáy', type: :enum, options: [['under', 'Đặt dưới'], ['inset', 'Lọt giữa 4 thành'], ['groove', 'Ngậm rãnh']] },
          { key: 'drawer_bottom_thickness', label: 'Dày đáy thùng', type: :mm, min: 3, max: 25 },
          { key: 'drawer_groove_depth', label: 'Độ ngậm rãnh', type: :mm, min: 2, max: 15, only: { 'drawer_bottom_type' => %w[groove] } },
          { key: 'drawer_groove_height', label: 'Cao rãnh (từ mép dưới)', type: :mm, min: 3, max: 60, only: { 'drawer_bottom_type' => %w[groove] } },
          BOARD.merge(label: 'Dày ván / mặt hộc'),
          { key: 'drawer_show_dims', label: 'Hiện kích thước', type: :bool }
        ]
      },
      'bay' => {
        title: 'Khoang ngăn kéo',
        mode: { key: 'drawer_mode', items: [['full', 'Mặt + thùng', 'Tạo cả mặt hộc và thùng kéo'], ['front_only', 'Chỉ mặt hộc', 'Chỉ tạo mặt hộc'], ['box_only', 'Chỉ thùng kéo', 'Chỉ tạo thùng kéo bên trong']] },
        params: [
          { key: 'bay_setback', label: 'Lùi sau cánh', type: :mm, min: 0, max: 200 },
          { key: 'bay_side_gap', label: 'Khe hông khoang-tủ', type: :mm, min: 0, max: 150 },
          { key: 'bay_height', label: 'Cao khoang (0=cả ô)', type: :mm, min: 0, max: 2500 },
          { key: 'drawer_count', label: 'Số hộc', type: :int, min: 1, max: 20 },
          { key: 'drawer_front_height', label: 'Cao mặt hộc (0=đều)', type: :mm, min: 0, max: 1000 },
          { key: 'drawer_gap', label: 'Khe giữa mặt hộc', type: :mm, min: 0, max: 30 },
          { key: 'drawer_slide', label: 'Ray', type: :enum, options: [['side', 'Ray bi (bên)'], ['under', 'Ray âm']] },
          { key: 'drawer_depth', label: 'Sâu thùng (0=tự)', type: :mm, min: 0, max: 800 },
          { key: 'drawer_bottom_type', label: 'Loại đáy', type: :enum, options: [['under', 'Đặt dưới'], ['inset', 'Lọt giữa 4 thành'], ['groove', 'Ngậm rãnh']] },
          { key: 'drawer_bottom_thickness', label: 'Dày đáy thùng', type: :mm, min: 3, max: 25 },
          { key: 'drawer_groove_depth', label: 'Độ ngậm rãnh', type: :mm, min: 2, max: 15, only: { 'drawer_bottom_type' => %w[groove] } },
          { key: 'drawer_groove_height', label: 'Cao rãnh (từ mép dưới)', type: :mm, min: 3, max: 60, only: { 'drawer_bottom_type' => %w[groove] } },
          BOARD.merge(label: 'Dày ván / mặt hộc'),
          { key: 'drawer_show_dims', label: 'Hiện kích thước', type: :bool }
        ]
      }
    }.freeze

    # Sửa tủ đã tạo: như Box → Board nhưng thêm Rộng/Sâu/Cao của tủ, bỏ các tùy chọn chỉ dùng khi tạo mới.
    EDIT_SPEC = SPECS['box'].merge(
      title: 'Sửa tủ',
      params: [{ key: '_width', label: 'Rộng tủ', type: :mm, min: 100, max: 10_000 },
               { key: '_depth', label: 'Sâu tủ', type: :mm, min: 100, max: 10_000 },
               { key: '_height', label: 'Cao tủ', type: :mm, min: 100, max: 10_000 }] +
              SPECS['box'][:params].reject { |param| %w[sync_front keep_source].include?(param[:key]) }
    ).freeze

    attr_accessor :active_preset_id

    def preset_group
      Schema::TOOL_GROUP[@tool_name.to_s]
    end

    def activate
      super
      reload_presets
      sync_status_hint(true)
    end

    def resume(view)
      super
      sync_status_hint(true)
    end

    def deactivate(view)
      @armed = nil
      super
    end

    def reload_presets
      group = preset_group
      @hud_presets = group ? ToolSettings.new.all['tools'][group] : nil
      @hud_default_id = @hud_presets && @hud_presets['default_id']
      @hud_presets = @hud_presets ? @hud_presets['presets'] : []
      @active_preset_id = nil unless @hud_presets.any? { |item| item['id'] == @active_preset_id }
      Sketchup.active_model.active_view.invalidate
    rescue StandardError
      @hud_presets = []
    end

    # --- Mô tả công cụ ---

    def hud_spec_key
      name = self.class.name.to_s
      return 'face' if name.end_with?('FaceBoardTool')
      return 'edit' if name.end_with?('EditCabinetTool')
      @tool_name.to_s
    end

    def hud_spec
      hud_spec_key == 'edit' ? EDIT_SPEC : SPECS[hud_spec_key]
    end

    # --- Vẽ ---

    def draw_hud(view)
      @hud_rects = []
      spec = hud_spec
      return super unless spec && preset_group
      draw_preset_list(view)
      draw_mode_bar(view, spec)
      bottom = draw_param_panel(view, spec)
      draw_info_lines(view, bottom)
      sync_status_hint
    end

    def hud_fill(view, x0, y0, x1, y1, color)
      view.drawing_color = color
      view.draw2d(GL_QUADS, [[x0, y0, 0], [x1, y0, 0], [x1, y1, 0], [x0, y1, 0]])
    end

    def hud_ink
      Sketchup::Color.new(33, 77, 90)
    end

    def hud_muted
      Sketchup::Color.new(120, 120, 120)
    end

    def hud_clip(text, limit)
      text = text.to_s
      text.length > limit ? "#{text[0, limit - 1]}…" : text
    end

    def hud_hovered?(kind, index)
      @hud_hover && @hud_hover[0] == kind && @hud_hover[1] == index
    end

    # 1. MẪU
    def draw_preset_list(view)
      list = @hud_presets || []
      shown = list.first(MAX_ROWS)
      rows = shown.empty? ? 1 : shown.length
      extra = list.length > MAX_ROWS ? 1 : 0
      left = MARGIN
      top = MARGIN
      height = HEAD_HEIGHT + (rows + extra) * ROW_HEIGHT + 6
      hud_fill(view, left, top, left + LEFT_WIDTH, top + height, Sketchup::Color.new(255, 255, 255, 215))
      view.draw_text([left + 10, top + 6], "MẪU · #{hud_clip(hud_spec[:title], 18)}", color: hud_ink, size: 10, bold: true)
      if shown.empty?
        view.draw_text([left + 10, top + HEAD_HEIGHT + 2], 'Chưa có mẫu. Lưu trong bảng.', color: hud_muted, size: 10)
        return
      end
      shown.each_with_index do |preset, index|
        y = top + HEAD_HEIGHT + index * ROW_HEIGHT
        active = preset['id'] == @active_preset_id
        hud_fill(view, left + 4, y - 1, left + LEFT_WIDTH - 4, y + ROW_HEIGHT - 3, Sketchup::Color.new(40, 160, 190, 80)) if active
        hud_fill(view, left + 4, y - 1, left + LEFT_WIDTH - 4, y + ROW_HEIGHT - 3, Sketchup::Color.new(40, 160, 190, 35)) if !active && hud_hovered?(:preset, index)
        mark = preset['id'] == @hud_default_id ? '★ ' : ''
        view.draw_text([left + 10, y + 1], hud_clip("#{mark}#{preset['name']}", 25), color: hud_ink, size: 10, bold: active)
        @hud_rects << [left, y - 1, left + LEFT_WIDTH, y + ROW_HEIGHT - 3, :preset, index]
      end
      return unless extra == 1
      y = top + HEAD_HEIGHT + shown.length * ROW_HEIGHT
      view.draw_text([left + 10, y + 1], "... còn #{list.length - MAX_ROWS} mẫu nữa (xem trong bảng)", color: hud_muted, size: 10)
    end

    # 2. CHẾ ĐỘ
    def draw_mode_bar(view, spec)
      mode = spec[:mode]
      return unless mode
      current = hud_get(mode[:key])
      widths = mode[:items].map { |item| [item[1].length * 7 + 26, 84].max }
      total = widths.sum + (widths.length - 1) * 6
      left = [(view.vpwidth - total) / 2, MARGIN + LEFT_WIDTH + 12].max
      top = MARGIN
      x = left
      mode[:items].each_with_index do |item, index|
        width = widths[index]
        active = item[0] == current
        fill = if active
                 Sketchup::Color.new(30, 140, 170, 235)
               elsif hud_hovered?(:mode, index)
                 Sketchup::Color.new(220, 240, 246, 235)
               else
                 Sketchup::Color.new(255, 255, 255, 215)
               end
        hud_fill(view, x, top, x + width, top + BUTTON_HEIGHT, fill)
        color = active ? Sketchup::Color.new(255, 255, 255) : hud_ink
        view.draw_text([x + 13, top + 6], item[1], color: color, size: 10, bold: active)
        @hud_rects << [x, top, x + width, top + BUTTON_HEIGHT, :mode, index]
        x += width + 6
      end
    end

    # 3. THÔNG SỐ. Trả về tọa độ y của đáy bảng.
    def draw_param_panel(view, spec)
      params = hud_params
      left = [view.vpwidth - RIGHT_WIDTH - MARGIN, MARGIN].max
      top = MARGIN
      return top if params.empty?
      height = HEAD_HEIGHT + params.length * ROW_HEIGHT + 6
      hud_fill(view, left, top, left + RIGHT_WIDTH, top + height, Sketchup::Color.new(255, 255, 255, 215))
      view.draw_text([left + 10, top + 6], 'THÔNG SỐ  (click để sửa)', color: hud_ink, size: 10, bold: true)
      params.each_with_index do |param, index|
        y = top + HEAD_HEIGHT + index * ROW_HEIGHT
        armed = @armed && @armed[:key] == param[:key]
        if armed
          hud_fill(view, left + 4, y - 1, left + RIGHT_WIDTH - 4, y + ROW_HEIGHT - 3, Sketchup::Color.new(255, 190, 60, 150))
        elsif hud_hovered?(:param, index)
          hud_fill(view, left + 4, y - 1, left + RIGHT_WIDTH - 4, y + ROW_HEIGHT - 3, Sketchup::Color.new(40, 160, 190, 45))
        end
        view.draw_text([left + 10, y + 1], hud_clip(param[:label], 20), color: hud_ink, size: 10)
        text = armed ? 'gõ số + Enter…' : hud_value_text(param)
        view.draw_text([left + VALUE_X, y + 1], text, color: hud_ink, size: 10, bold: true)
        @hud_rects << [left, y - 1, left + RIGHT_WIDTH, y + ROW_HEIGHT - 3, :param, index]
      end
      top + height
    end

    # Thông tin phụ của công cụ (số cánh, kích thước...), nằm dưới bảng thông số.
    def draw_info_lines(view, top)
      return unless respond_to?(:hud_lines)
      lines = hud_lines || []
      return if lines.empty?
      errors = lines.select { |text| text.start_with?('Lỗi:') }
      lines = lines.reject { |text| text.start_with?('Lỗi:') }.first(7) + errors.first(1)
      width = RIGHT_WIDTH
      left = [view.vpwidth - width - MARGIN, MARGIN].max
      top += 6
      height = 12 + lines.length * 18
      hud_fill(view, left, top, left + width, top + height, Sketchup::Color.new(255, 255, 255, 190))
      lines.each_with_index do |text, index|
        color = text.start_with?('Lỗi:') ? Sketchup::Color.new(167, 61, 54) : hud_ink
        view.draw_text([left + 10, top + 6 + index * 18], hud_clip(text, 40), color: color, size: 10)
      end
    end

    def hud_number_text(value)
      number = value.to_f
      number == number.round ? number.round.to_s : number.round(2).to_s
    end

    def hud_value_text(param)
      value = hud_get(param[:key])
      case param[:type]
      when :bool then value ? 'Bật' : 'Tắt'
      when :enum
        found = param[:options].find { |option| option[0] == value }
        found ? found[1] : value.to_s
      when :int then value.nil? ? '—' : value.to_i.to_s
      else value.nil? ? '= dày ván' : "#{hud_number_text(value)} mm"
      end
    end

    # Các hàng thông số đang hiện: hàng có only: { khóa => [giá trị] } chỉ hiện khi khóa đó đang mang giá trị phù hợp
    # (ví dụ kích thước tủ lạnh chỉ hiện khi Loại tủ = Tủ lạnh).
    def hud_params
      spec = hud_spec
      return [] unless spec
      spec[:params].select do |param|
        next true unless param[:only]
        param[:only].all? { |key, values| values.include?(hud_get(key).to_s) }
      end
    end

    # --- Đọc/ghi giá trị ---

    def hud_target
      respond_to?(:hud_target_settings, true) ? hud_target_settings : @settings
    end

    def hud_get(key)
      respond_to?(:hud_read, true) ? hud_read(key) : hud_target[key]
    end

    def hud_put(key, value)
      if respond_to?(:hud_write, true)
        hud_write(key, value)
      else
        hud_target[key] = value
      end
    end

    # Đặt một giá trị từ HUD: kiểm tra, ghi, dựng lại xem trước, đồng bộ sang bảng điều khiển.
    def hud_set_value(key, value, view = nil)
      problem = respond_to?(:hud_guard, true) ? hud_guard(key, value) : nil
      if problem
        Dialog.set_status(problem)
        flash_status(problem)
        return false
      end
      hud_put(key, value)
      hud_after_set(key) if respond_to?(:hud_after_set, true)
      rebuild_preview if respond_to?(:rebuild_preview)
      push_hud_value(key)
      sync_status_hint(true)
      view.invalidate if view
      true
    rescue StandardError => e
      Dialog.set_status(e.message)
      flash_status(e.message)
      false
    end

    # Đưa giá trị mới sang các ô trong bảng điều khiển (chỉ nhóm chứa khóa đó, để không ghi đè nhóm khác).
    def push_hud_value(key)
      return if key.to_s.start_with?('_') || key.to_s == 'hinge_side'
      group = ToolSettings::BASE_KEYS.include?(key.to_s) ? 'base' : preset_group
      Dialog.push_settings(hud_target, false, group)
    end

    # --- Chuột ---

    def hud_hit(x, y)
      (@hud_rects || []).each do |x0, y0, x1, y1, kind, index|
        return [kind, index] if x >= x0 && x <= x1 && y >= y0 && y <= y1
      end
      nil
    end

    def preset_row_at(x, y)
      hit = hud_hit(x, y)
      hit && hit[0] == :preset ? hit[1] : nil
    end

    def onMouseMove(flags, x, y, view)
      before = @hud_hover
      @hud_hover = hud_hit(x, y)
      describe_hover if @hud_hover != before
      super
    end

    def onLButtonDown(flags, x, y, view)
      hit = hud_hit(x, y)
      if hit
        hud_click(hit[0], hit[1], view)
        view.invalidate
        return
      end
      disarm_param
      super if defined?(super)
    end

    def hud_click(kind, index, view)
      case kind
      when :preset
        disarm_param
        select_preset(index, view)
      when :mode
        disarm_param
        item = hud_spec[:mode][:items][index]
        hud_set_value(hud_spec[:mode][:key], item[0], view) if item
      when :param
        param = hud_params[index]
        hud_param_click(param, view) if param
      end
    end

    def hud_param_click(param, view)
      case param[:type]
      when :bool
        disarm_param
        hud_set_value(param[:key], !hud_get(param[:key]), view)
      when :enum
        disarm_param
        options = param[:options]
        at = options.index { |option| option[0] == hud_get(param[:key]) }.to_i
        hud_set_value(param[:key], options[(at + 1) % options.length][0], view)
      else
        arm_param(param)
      end
    end

    # Hover vào nút chế độ: hiện mô tả ở thanh trạng thái.
    def describe_hover
      hit = @hud_hover
      if hit && hit[0] == :mode
        item = hud_spec[:mode][:items][hit[1]]
        flash_status("#{item[1]}: #{item[2]}") if item && item[2]
      else
        sync_status_hint(true)
      end
    end

    # --- Gõ số vào ô VCB cho thông số đang chọn ---

    def arm_param(param)
      @armed = param
      current = hud_get(param[:key])
      Sketchup.vcb_label = param[:label]
      Sketchup.vcb_value = current.nil? ? '' : hud_number_text(current)
      sync_status_hint(true)
    rescue StandardError
      nil
    end

    def disarm_param
      return unless @armed
      @armed = nil
      Sketchup.vcb_value = ''
      sync_status_hint(true)
    rescue StandardError
      nil
    end

    def parse_hud_number(text)
      Float(text.to_s.strip.downcase.sub(/\s*mm\z/, '').tr(',', '.'))
    rescue ArgumentError, TypeError
      nil
    end

    def onUserText(text, view)
      return(defined?(super) ? super : nil) unless @armed
      param = @armed
      value = parse_hud_number(text)
      unless value && value >= param[:min] && value <= param[:max]
        message = "«#{param[:label]}» cần là số từ #{param[:min]} đến #{param[:max]}."
        Dialog.set_status(message)
        flash_status(message)
        return
      end
      value = value.round if param[:type] == :int
      @armed = nil
      Sketchup.vcb_value = ''
      hud_set_value(param[:key], value, view)
    end

    # Esc: nếu đang chờ gõ số thì chỉ bỏ chờ, không thoát công cụ.
    def cancel_tool(view)
      if @armed
        disarm_param
        view.invalidate if view
        return
      end
      super
    end

    # --- Thanh trạng thái mặc định của SketchUp ---

    # Thông báo tạm ở thanh trạng thái (giữ vài giây, sau đó hướng dẫn ngắn quay lại).
    def flash_status(text)
      Sketchup.status_text = text.to_s
      @hud_flash_until = Time.now + 4.0
    rescue StandardError
      nil
    end

    def sync_status_hint(force = false)
      text = if @armed
               "Gõ số cho «#{@armed[:label]}» rồi Enter · Esc: bỏ"
             else
               respond_to?(:status_hint) ? status_hint : hint
             end
      return if !force && @hud_flash_until && Time.now < @hud_flash_until
      return if !force && text == @hud_last_status
      @hud_flash_until = nil if force
      @hud_last_status = text
      Sketchup.status_text = "VGD · #{Tools.label(@tool_name)}: #{text}"
    rescue StandardError
      nil
    end

    # --- Chọn mẫu ---

    # Dùng setting thứ index (từ 0) của công cụ đang chạy.
    def select_preset(index, view = nil)
      list = @hud_presets || []
      preset = list[index]
      return false unless preset && index < MAX_ROWS
      @active_preset_id = preset['id']
      update_settings(Schema.deep_merge(@settings, preset['params']))
      Dialog.push_settings(preset['params'], false, preset_group)
      Dialog.select_preset(preset_group, preset['id'])
      Dialog.set_status("Đang dùng setting: #{preset['name']}")
      flash_status("Đã dùng mẫu: #{preset['name']}")
      view.invalidate if view
      true
    rescue StandardError => e
      Dialog.set_status("Không dùng được setting: #{e.message}")
      false
    end
  end

  Tools.constants.each do |name|
    klass = Tools.const_get(name)
    klass.send(:prepend, PresetHud) if klass.is_a?(Class) && klass < Tools::Base
  end
end
