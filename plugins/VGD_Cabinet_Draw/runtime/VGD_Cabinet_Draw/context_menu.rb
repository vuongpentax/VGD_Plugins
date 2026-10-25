module VGD_Cabinet_Draw
  # Menu chuột phải "VGD Cabinet ▸" (beta.17).
  #   1. Chuột phải lên TỦ / CÁNH khi không bật công cụ: lệnh theo loại tủ (tủ thường, bếp dưới, bếp trên, thùng tủ lạnh).
  #   2. Chuột phải khi đang dùng công cụ VGD: chỉ những lệnh KHÔNG có phím tắt và KHÔNG có trên HUD
  #      (Tab, Shift, Ctrl, Alt, G, Backspace... giữ nguyên, không đưa vào menu).
  # Phần dựng danh sách (items_for / tool_items) là Ruby thuần, trả về mảng hash:
  #   { label:, run:, checked:, enabled: }  hoặc  { label:, items: [...] } (menu con)  hoặc  { separator: true }
  # nên test được bằng menu giả; phần gắn vào UI::Menu (attach) rất mỏng.
  # Các lệnh đổi nhanh dựng lại tủ như Sửa tủ (một bước Undo cho cả lệnh).
  module ContextMenu
    extend self

    MENU_TITLE = 'VGD Cabinet'.freeze
    TYPE_LABELS = { 'standard' => 'Tủ thường', 'base' => 'Tủ bếp dưới', 'wall' => 'Tủ bếp trên', 'fridge' => 'Thùng tủ lạnh' }.freeze
    BASE_LEGS = [100, 120, 150].freeze
    WALL_HEIGHTS = [700, 800, 900].freeze
    # Cỡ tủ lạnh [tên, rộng, cao, sâu] — chỉ THAM KHẢO, người dùng sửa theo model thật trong Sửa tủ.
    FRIDGE_SIZES = [['Nhỏ', 600, 1700, 650], ['Vừa', 700, 1800, 650], ['Lớn', 800, 1800, 700], ['Side-by-side', 900, 1800, 750]].freeze
    # Khe tủ lạnh [tên, hai bên, phía trên, phía sau] (mm).
    FRIDGE_GAPS = [['Chuẩn VN (20 / 80 / 50)', 20, 80, 50], ['Rộng rãi (50 / 100 / 50)', 50, 100, 50]].freeze
    DRAWER_FRONT_MM = 180.0 # cao mặt hộc của kiểu "1 kéo trên + 2 cánh dưới"
    REFERENCE_NAME = 'Tủ lạnh (tham chiếu)'.freeze

    # Đặt sẵn câu trả lời hộp thoại (dùng cho test): :overwrite / :keep / :cancel cho tấm chỉnh tay; true/false cho xác nhận.
    attr_accessor :manual_choice, :confirm_answer

    # ---------- Phân loại vùng chọn ----------

    def classify(selection)
      roots = []
      doors = []
      selection.each do |entity|
        next unless (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)) && entity.valid?
        if ModelData.cabinet?(entity)
          roots << entity
        elsif Operations.door?(entity) || entity.get_attribute(Schema::DICTIONARY, 'kind') == 'drawer_front'
          doors << entity
        end
      end
      [roots, doors]
    end

    def type_of(root)
      value = ModelData.params(root)['cabinet_type'].to_s
      TYPE_LABELS.key?(value) ? value : 'standard'
    end

    # ---------- Dựng danh sách mục ----------

    # Danh sách mục cho vùng chọn hiện tại (rỗng nếu không phải tủ/cánh của VGD).
    def items_for(selection)
      roots, doors = classify(selection)
      return cabinet_items(roots) unless roots.empty?
      return door_items(doors) unless doors.empty?
      []
    end

    def cabinet_items(roots)
      types = roots.map { |root| type_of(root) }.uniq
      list = []
      list << item('Sửa tủ…', -> { launch('box') })
      list << item('Chia cánh…', -> { launch('door') })
      list << item('Thêm đợt / vách…', -> { launch('panel') })
      list << item('Thêm ngăn kéo…', -> { launch('drawer') })
      list << { separator: true }
      list << item('Mở tất cả cánh…', -> { open_all_prompt(roots) })
      list << item('Đóng tất cả cánh', -> { close_all(roots) })
      if roots.any? { |root| !DrawerSlide.parts(root).empty? }
        list << item('Mở ngăn kéo…', -> { open_drawers_prompt(roots.flat_map { |root| DrawerSlide.parts(root) }) })
        list << item('Đóng ngăn kéo', -> { close_drawers(roots.flat_map { |root| DrawerSlide.parts(root) }) })
      end
      list << item('Đặt tay nắm tự động', -> { auto_handles(roots) })
      list << { separator: true }
      list << item('Tìm tấm bị trùng', -> { PanelTools.select_duplicates(roots) })
      list << item('Chuẩn hóa tên ván', -> { PanelTools.normalize_names_command(roots) })
      list << { separator: true }
      list << { label: 'Đổi loại tủ', items: TYPE_LABELS.map { |key, name| item(name, -> { change_type(roots, key) }, checked: types == [key]) } }
      if types.length == 1
        list << { separator: true }
        list.concat(send("#{types.first}_items", roots))
      end
      list
    end

    def standard_items(roots)
      [
        item('Hông chạm đất', -> { toggle_setting(roots, 'sides_to_floor', 'Hông chạm đất') }, checked: all_true?(roots, 'sides_to_floor')),
        item('Hông đụng trần', -> { toggle_setting(roots, 'sides_to_ceiling', 'Hông đụng trần') }, checked: all_true?(roots, 'sides_to_ceiling')),
        item('Thêm khoang ngăn kéo…', -> { launch('bay') })
      ]
    end

    def base_items(roots)
      [
        { label: 'Nóc', items: [
          item('2 thanh giằng', -> { set_values(roots, 'Nóc: 2 thanh giằng', 'top_mode' => 'auto') }, checked: all_equal?(roots, 'top_mode', 'auto')),
          item('Nóc nguyên', -> { set_values(roots, 'Nóc nguyên', 'top_mode' => 'full') }, checked: all_equal?(roots, 'top_mode', 'full'))
        ] },
        { label: 'Chân cao', items: BASE_LEGS.map { |mm| item("#{mm} mm", -> { set_values(roots, "Chân cao #{mm}", 'leg_height' => mm.to_f) }, checked: all_equal?(roots, 'leg_height', mm.to_f)) } },
        { label: 'Chia nhanh', items: [
          item('3 ngăn kéo đều', -> { quick_split(roots, '3 ngăn kéo đều') { |root| split_drawers(root, 3) } }),
          item('1 kéo trên + 2 cánh dưới', -> { quick_split(roots, '1 kéo trên + 2 cánh dưới') { |root| split_drawer_top_two_doors(root) } }),
          item('2 cánh', -> { quick_split(roots, '2 cánh') { |root| split_two_doors(root) } })
        ] },
        item('Tủ chậu rửa (bỏ hậu)', -> { toggle_sink(roots) }, checked: roots.all? { |root| back_removed?(root) })
      ]
    end

    def wall_items(roots)
      [
        item('Xà treo', -> { toggle_setting(roots, 'hang_rail', 'Xà treo') }, checked: all_true?(roots, 'hang_rail')),
        { label: 'Chiều cao (giữ nguyên đỉnh tủ)', items: WALL_HEIGHTS.map { |mm| item("#{mm} mm", -> { set_height(roots, mm) }, checked: roots.all? { |root| (height_of(root) - mm).abs < 0.5 }) } },
        { label: 'Chia nhanh', items: [
          item('2 cánh mở', -> { quick_split(roots, '2 cánh mở') { |root| split_two_doors(root) } }),
          item('Cánh lật lên', -> { quick_split(roots, 'Cánh lật lên') { |root| split_flip_up(root) } }),
          item('Đợt chia đều (không cánh)', -> { quick_split(roots, 'Đợt chia đều') { |root| split_shelves(root, 3) } })
        ] }
      ]
    end

    def fridge_items(roots)
      sizes = FRIDGE_SIZES.map do |name, w, h, d|
        item("#{name} #{w} × #{h} × #{d}", -> { set_values(roots, "Cỡ tủ lạnh #{name}", 'fridge_width' => w.to_f, 'fridge_height' => h.to_f, 'fridge_depth' => d.to_f) },
             checked: all_equal?(roots, 'fridge_width', w.to_f) && all_equal?(roots, 'fridge_height', h.to_f) && all_equal?(roots, 'fridge_depth', d.to_f))
      end
      gaps = FRIDGE_GAPS.map do |name, side, top, back|
        item(name, -> { set_values(roots, "Khe tủ lạnh #{side}/#{top}/#{back}", 'fridge_side_gap' => side.to_f, 'fridge_top_gap' => top.to_f, 'fridge_back_gap' => back.to_f) },
             checked: all_equal?(roots, 'fridge_side_gap', side.to_f) && all_equal?(roots, 'fridge_top_gap', top.to_f) && all_equal?(roots, 'fridge_back_gap', back.to_f))
      end
      [
        { label: 'Cỡ tủ lạnh (tham khảo, rộng × cao × sâu)', items: sizes },
        { label: 'Khe (hai bên / trên / sau)', items: gaps },
        item('Hiện khối tham chiếu', -> { toggle_reference(roots) }, checked: roots.all? { |root| reference_visible?(root) })
      ]
    end

    def drawer_items(fronts)
      [
        item('Mở ngăn kéo…', -> { open_drawers_prompt(drawer_group(fronts)) }),
        item('Đóng ngăn kéo', -> { close_drawers(drawer_group(fronts)) }),
        { separator: true },
        item('Đặt tay nắm', -> { put_handles(fronts) }),
        item('Xóa tay nắm', -> { remove_handles(fronts) })
      ]
    end

    # Cả mặt hộc lẫn thùng của các hộc được chọn.
    def drawer_group(fronts)
      fronts.flat_map do |front|
        root = DrawerSlide.cabinet_of(front)
        root ? DrawerSlide.partners(root, [front]) : [front]
      end.uniq
    end

    def door_items(doors)
      return drawer_items(doors) if doors.all? { |door| DrawerSlide.front?(door) }
      current = doors.map { |door| Operations.opening_type_of(door) }.uniq
      hinges = [['Bản lề trái', 'left'], ['Bản lề phải', 'right'], ['Lật lên (bản lề trên)', 'top'], ['Lật xuống (bản lề dưới)', 'bottom']]
      [
        item('Mở cánh…', -> { open_doors_prompt(doors) }),
        item('Đóng cánh', -> { close_doors(doors) }),
        { separator: true },
        { label: 'Bản lề', items: hinges.map { |name, type| item(name, -> { set_hinge(doors, type) }, checked: current == [type]) } },
        { separator: true },
        item('Đặt tay nắm', -> { put_handles(doors) }),
        item('Xóa tay nắm', -> { remove_handles(doors) })
      ]
    end

    # ---------- Menu trong công cụ: chỉ lệnh KHÔNG có phím và KHÔNG có trên HUD ----------

    def tool_items(tool)
      list = []
      case tool.class.name.to_s.split('::').last
      when 'DoorTool'
        list << { label: 'Loại mở của vùng', items: door_region_types(tool) }
        list << item('Chọn tất cả vùng', -> { tool_select_all(tool) })
        list << item('Bỏ chọn vùng', -> { tool_clear_selection(tool) })
      when 'OpeningTool'
        list << item('Đóng tất cả cánh của tủ đang chọn', -> { VGD_Cabinet_Draw.close_selected_doors })
      end
      list << { separator: true } unless list.empty?
      list << item('Mở bảng Setting', -> { Dialog.show })
      list
    end

    def door_region_types(tool)
      [['Không', 'none'], ['Bản lề trái', 'left'], ['Bản lề phải', 'right'], ['Lật lên', 'top'], ['Lật xuống', 'bottom'], ['Ngăn kéo', 'drawer']].map do |name, type|
        item(name, -> { tool_set_opening(tool, type) })
      end
    end

    def tool_select_all(tool)
      layout = tool.instance_variable_get(:@layout)
      return unless layout
      tool.instance_variable_set(:@selected, layout.ids)
      refresh_tool(tool, "Đã chọn #{layout.ids.length} vùng.")
    end

    def tool_clear_selection(tool)
      tool.instance_variable_set(:@selected, [])
      refresh_tool(tool, 'Đã bỏ chọn vùng.')
    end

    def tool_set_opening(tool, type)
      layout = tool.instance_variable_get(:@layout)
      ids = tool.send(:target_ids)
      if layout.nil? || ids.empty?
        Dialog.set_status('Trỏ chuột vào một vùng (hoặc Shift-click chọn vùng) rồi chuột phải lại.')
        return
      end
      ids.each { |id| layout.set_opening(id, type) }
      refresh_tool(tool, "Đã đặt loại mở cho #{ids.length} vùng. Bấm Enter để tạo cánh.")
    rescue ArgumentError => e
      Dialog.set_status(e.message)
    end

    def refresh_tool(tool, message)
      Dialog.set_status(message)
      tool.send(:rebuild_preview) if tool.respond_to?(:rebuild_preview, true)
      Sketchup.active_model.active_view.invalidate
    end

    # ---------- Gắn vào UI::Menu ----------

    def item(label, run, opts = {})
      { label: label, run: run, checked: opts.fetch(:checked, false), enabled: opts.fetch(:enabled, true) }
    end

    # Điền các mục vào một UI::Menu (đệ quy cho menu con).
    def attach(menu, list)
      list.each do |entry|
        if entry[:separator]
          menu.add_separator
        elsif entry[:items]
          attach(menu.add_submenu(entry[:label]), entry[:items])
        else
          run = entry[:run]
          added = menu.add_item(entry[:label]) { safely(entry[:label], &run) }
          next unless added && menu.respond_to?(:set_validation_proc)
          flags = (entry[:checked] ? mf(:CHECKED, 8) : mf(:UNCHECKED, 0)) | (entry[:enabled] ? mf(:ENABLED, 0) : mf(:GRAYED, 3))
          menu.set_validation_proc(added) { flags }
        end
      end
    end

    def mf(name, fallback)
      Object.const_defined?("MF_#{name}") ? Object.const_get("MF_#{name}") : fallback
    end

    # Menu chuột phải lên đối tượng (không có công cụ VGD đang chạy).
    def populate(menu, selection = Sketchup.active_model.selection)
      return false if VGD_Cabinet_Draw.vgd_tool_active?
      list = items_for(selection)
      return false if list.empty?
      attach(menu.add_submenu(MENU_TITLE), list)
      true
    rescue StandardError => e
      puts "[VGD Cabinet Draw] Menu chuột phải lỗi: #{e.class}: #{e.message}"
      false
    end

    # Menu chuột phải khi đang dùng công cụ VGD (gọi từ getMenu của công cụ).
    def populate_tool(menu, tool)
      list = tool_items(tool)
      return false if list.empty?
      attach(menu.add_submenu(MENU_TITLE), list)
      true
    rescue StandardError => e
      puts "[VGD Cabinet Draw] Menu công cụ lỗi: #{e.class}: #{e.message}"
      false
    end

    # Bắt lỗi của lệnh: báo cho người dùng thay vì để SketchUp im lặng.
    def safely(label)
      yield
    rescue StandardError => e
      UI.messagebox("#{label} — lỗi:\n#{e.message}")
      puts "[VGD Cabinet Draw] #{label}: #{e.class}: #{e.message}\n#{(e.backtrace || []).first(6).join("\n")}"
    end

    # ---------- Đọc thông số ----------

    def settings_value(root, key)
      Rebuild.settings_of(root)[key]
    end

    def all_equal?(roots, key, value)
      roots.all? { |root| settings_value(root, key) == value }
    end

    def all_true?(roots, key)
      roots.all? { |root| settings_value(root, key) ? true : false }
    end

    def height_of(root)
      ModelData.params(root)['height_mm'].to_f
    end

    def back_removed?(root)
      back = settings_value(root, 'panels')
      back.is_a?(Hash) && back['back'].is_a?(Hash) && back['back']['enabled'] == false
    end

    # ---------- Hành động: mở công cụ ----------

    def launch(name)
      if Schema::TOOL_GROUP.key?(name)
        VGD_Cabinet_Draw.launch_default(name)
      else
        VGD_Cabinet_Draw.launch_tool(name, Schema.merge_settings({}))
      end
    end

    # ---------- Hành động: đổi nhanh thông số (dựng lại tủ như Sửa tủ) ----------

    def change_type(roots, type)
      preset = Schema::TYPE_PRESETS.fetch(type, {})
      quick_edit(roots, "Đổi loại tủ: #{TYPE_LABELS[type]}") do |_root, settings, _dims|
        settings.merge!(preset)
        settings['cabinet_type'] = type
      end
    end

    def set_values(roots, label, values)
      quick_edit(roots, label) { |_root, settings, _dims| settings.merge!(values) }
    end

    def toggle_setting(roots, key, label)
      target = !all_true?(roots, key)
      set_values(roots, "#{label}: #{target ? 'bật' : 'tắt'}", key => target)
    end

    def toggle_sink(roots)
      remove = !roots.all? { |root| back_removed?(root) }
      quick_edit(roots, remove ? 'Tủ chậu rửa (bỏ hậu)' : 'Có hậu trở lại') do |_root, settings, _dims|
        settings['panels'] = Schema.deep_copy(settings['panels'] || PanelModel.default_panels)
        settings['panels']['back'] = (settings['panels']['back'] || {}).merge('enabled' => !remove)
      end
    end

    # Đổi chiều cao, giữ nguyên ĐỈNH tủ (tủ bếp trên treo cố định ở đỉnh).
    def set_height(roots, mm)
      quick_edit(roots, "Chiều cao #{mm}", after: lambda { |root, old_dims, new_dims| keep_top(root, old_dims[2], new_dims[2]) }) do |_root, _settings, dims|
        dims[2] = mm.to_f
      end
    end

    def keep_top(root, old_height_mm, new_height_mm)
      delta = (old_height_mm - new_height_mm).mm
      return if delta.abs < 1e-6
      root.transform!(Geom::Transformation.translation(Geom::Vector3d.new(0, 0, delta)))
    end

    # Chạy một chỉnh sửa thông số/kích thước cho nhiều tủ: kiểm tra trước, hỏi nếu có tấm chỉnh tay, một bước Undo.
    def quick_edit(roots, label, after: nil)
      roots = roots.select(&:valid?)
      return false if roots.empty?
      plans = roots.map do |root|
        settings = Rebuild.settings_of(root)
        dims = Rebuild.dimensions_of(root)
        old_dims = dims.dup
        yield(root, settings, dims)
        PanelModel.compute(dims[0], dims[1], dims[2], settings) # kiểm tra trước khi chạm vào model
        [root, settings, dims, old_dims]
      end
      edited = plans.map { |plan| [plan[0], Rebuild.hand_edited(plan[0])] }.to_h
      all = edited.values.flatten
      keep = {}
      unless all.empty?
        choice = ask_manual(all)
        return false if choice == :cancel
        plans.each { |plan| keep[plan[0]] = choice == :keep ? edited[plan[0]].map { |entry| entry[:entity] } : [] }
      end
      warnings = []
      in_operation("VGD Cabinet Draw — #{label}") do
        plans.each do |root, settings, dims, old_dims|
          warnings.concat(Rebuild.run(root, settings, dims, keep[root] || []))
          after.call(root, old_dims, dims) if after
        end
      end
      reselect(roots)
      UI.messagebox("Đã dựng lại tủ. Lưu ý:\n• #{warnings.uniq.join("\n• ")}") unless warnings.empty?
      true
    rescue StandardError => e
      UI.messagebox("Không đổi được (#{label}):\n#{e.message}")
      puts "[VGD Cabinet Draw] #{label}: #{e.class}: #{e.message}\n#{(e.backtrace || []).first(8).join("\n")}"
      false
    end

    def ask_manual(list)
      return manual_choice if manual_choice
      Tools::EditCabinetTool.new({}).ask_manual(list)
    end

    # Một operation SketchUp; lỗi thì hủy toàn bộ rồi ném lại.
    def in_operation(name)
      model = Sketchup.active_model
      model.start_operation(name, true)
      begin
        yield
      rescue StandardError
        model.abort_operation
        raise
      end
      model.commit_operation
    end

    def reselect(roots)
      model = Sketchup.active_model
      model.selection.clear
      roots.each { |root| model.selection.add(root) if root.valid? }
    end

    # ---------- Hành động: Chia nhanh (XÓA cánh + ngăn kéo hiện có, nên luôn hỏi trước) ----------

    def quick_split(roots, label)
      roots = roots.select(&:valid?)
      return false if roots.empty?
      return false unless confirm_clear?(label)
      in_operation("VGD Cabinet Draw — Chia nhanh: #{label}") do
        roots.each do |root|
          root.make_unique if root.respond_to?(:make_unique)
          clear_front(root)
          yield(root)
        end
      end
      reselect(roots)
      Dialog.set_status("Đã chia nhanh: #{label}.")
      true
    rescue StandardError => e
      UI.messagebox("Không chia nhanh được (#{label}):\n#{e.message}")
      puts "[VGD Cabinet Draw] Chia nhanh #{label}: #{e.class}: #{e.message}\n#{(e.backtrace || []).first(8).join("\n")}"
      false
    end

    def confirm_clear?(label)
      return confirm_answer unless confirm_answer.nil?
      text = "Chia nhanh \"#{label}\" sẽ XÓA cánh, ngăn kéo (và đợt/vách do lệnh chia nhanh tạo) hiện có của tủ đang chọn, rồi chia lại.\nCó thể hoàn tác bằng Undo.\n\nTiếp tục?"
      answer = UI.messagebox(text, Object.const_defined?(:MB_YESNO) ? MB_YESNO : 4)
      answer == (Object.const_defined?(:IDYES) ? IDYES : 6)
    end

    # Xóa cánh, ngăn kéo và các bước đợt/ngăn kéo do Chia nhanh tạo trước đó.
    def clear_front(root)
      Operations.door_container_clear(root)
      root.delete_attribute(Schema::DICTIONARY, 'door_layout_json')
      box = root.definition.entities.to_a.find { |e| e.is_a?(Sketchup::Group) && e.valid? && e.name == Operations::DRAWER_CONTAINER }
      box.erase! if box
      list = Rebuild.ops(root)
      quick_ids = list.select { |op| op['quick'] }.map { |op| op['op'] }
      shell = Geometry.shell_for(root)
      if shell
        Interior.containers(shell).each do |entity|
          params = ModelData.params(entity)
          entity.erase! if Rebuild::MEMBER_ROLES.include?(Interior.role_of(entity)) && quick_ids.include?(params['op'])
        end
      end
      Rebuild.save_ops(root, list.reject { |op| op['type'] == 'drawer' || op['quick'] })
    end

    # Bố cục cánh: gọi block để chia, rồi dựng cánh bằng chính công cụ Cánh.
    def build_door_layout(root)
      tool = Tools::DoorTool.new({})
      raise 'Không dựng được cánh cho tủ này.' unless tool.load_cabinet(root)
      tool.instance_variable_get(:@settings).merge!(Rebuild.settings_of(root).select { |key, _| %w[door_fit door_gap door_edge_gap door_inset_gap].include?(key) })
      layout = tool.instance_variable_get(:@layout)
      layout.reset_even('vertical', 1)
      yield layout
      # Lưu bố cục (kể cả kiểu bản lề) TRƯỚC khi dựng lại đợt/vách và cánh, giống lệnh Chia cánh.
      tool.save_layout!
      tool.apply_recess!
      tool.build_doors
    end

    def split_two_doors(root)
      build_door_layout(root) do |layout|
        left, right = layout.reset_even('vertical', 2).sort_by { |region| region['u0'] }
        layout.set_opening(left['id'], 'left')
        layout.set_opening(right['id'], 'right')
      end
    end

    def split_flip_up(root)
      build_door_layout(root) { |layout| layout.set_opening(layout.regions.first['id'], 'top') }
    end

    def split_drawers(root, count)
      settings = Rebuild.settings_of(root).merge('drawer_count' => count, 'drawer_front_height' => 0.0, 'drawer_mode' => 'full')
      Operations.build_drawers(root, settings, nil)
    end

    # Đợt chia đều: count ô (count-1 tấm), không cánh.
    def split_shelves(root, count)
      shell = Geometry.shell_for(root)
      op = shelf_op(root, shell, 'mode' => 'divide', 'count' => count)
      op['op'] = Rebuild.record(root, op)
      Rebuild.place_panels(root, shell, op)
    end

    # 1 ngăn kéo trên + 2 cánh dưới: mặt hộc là vùng "ngăn kéo" của bố cục cánh, thùng hộc (chỉ thùng) nằm sau,
    # trên một đợt ngăn cách với phần cánh bên dưới.
    def split_drawer_top_two_doors(root)
      shell = Geometry.shell_for(root)
      inner = Interior.inner(shell)
      inner_mm = inner.height.to_mm
      raise "Tủ quá thấp (lòng #{inner_mm.round} mm) để chia 1 kéo + 2 cánh." if inner_mm < DRAWER_FRONT_MM + 150.0
      build_door_layout(root) do |layout|
        span = layout.span_mm('horizontal')
        low, high = layout.split(layout.regions.first['id'], 'horizontal', 1.0 - DRAWER_FRONT_MM / span)
        layout.set_opening(high['id'], 'drawer')
        left, right = layout.split_even(low['id'], 'vertical', 2).sort_by { |region| region['u0'] }
        layout.set_opening(left['id'], 'left')
        layout.set_opening(right['id'], 'right')
      end
      thickness = Rebuild.settings_of(root)['board_thickness'].to_f
      op = shelf_op(root, shell, 'mode' => 'free', 'offsets' => [inner_mm - DRAWER_FRONT_MM - thickness])
      op['op'] = Rebuild.record(root, op)
      Rebuild.place_panels(root, shell, op)
      settings = Rebuild.settings_of(root).merge('drawer_count' => 1, 'drawer_front_height' => 0.0, 'drawer_mode' => 'box_only')
      local = Geom::Point3d.new((inner.x0 + inner.x1) / 2, (inner.y0 + inner.y1) / 2, inner.z1 - DRAWER_FRONT_MM.mm / 2)
      Operations.build_drawers(root, settings, local)
    end

    def shelf_op(root, shell, extra)
      settings = Rebuild.settings_of(root)
      inner = Interior.inner(shell)
      { 'type' => 'panel', 'axis' => 'horizontal', 'kind' => 'thong_thuy', 'thickness_mm' => settings['board_thickness'].to_f, 'limit' => false,
        'anchor' => Rebuild.anchor_of(shell, (inner.x0 + inner.x1) / 2, (inner.z0 + inner.z1) / 2),
        'setback_mm' => settings['shelf_front_setback'].to_f, 'door_fit' => settings['panel_door_fit'].to_s, 'quick' => true }.merge(extra)
    end

    # ---------- Hành động: cánh và tay nắm ----------

    def open_all_prompt(roots)
      angle = prompt_angle('Mở tất cả cánh')
      return unless angle
      doors = roots.flat_map { |root| Operations.doors_of(root) }
      open_doors(doors, angle, 'Mở tất cả cánh')
    end

    def open_doors_prompt(doors)
      angle = prompt_angle('Mở cánh')
      return unless angle
      open_doors(doors, angle, 'Mở cánh')
    end

    # Hộp thoại độ mở ngăn kéo: số + đơn vị (% tầm trượt hoặc mm). Trả về [số, đơn vị] hoặc nil.
    def prompt_slide(title)
      return @slide_answer if @slide_answer
      answer = UI.inputbox(['Mở', 'Đơn vị'], ['100', '%'], ['', '%|mm'], title)
      return nil unless answer
      [Float(answer[0].to_s.tr(',', '.')), answer[1].to_s == 'mm' ? 'mm' : '%']
    rescue ArgumentError, TypeError
      UI.messagebox('Độ mở phải là một số, ví dụ 100 (%) hoặc 250 (mm).')
      nil
    end

    # Đặt sẵn câu trả lời [số, đơn vị] (dùng cho test).
    def slide_answer=(value)
      @slide_answer = value
    end

    def open_drawers_prompt(entities)
      answer = prompt_slide('Mở ngăn kéo')
      return unless answer
      move_drawers(entities, 'Mở ngăn kéo') { |parts| DrawerSlide.set_open(parts, answer[0], answer[1]) }
    end

    def close_drawers(entities)
      move_drawers(entities, 'Đóng ngăn kéo') { |parts| DrawerSlide.close(parts) }
    end

    def move_drawers(entities, label)
      parts = entities.select(&:valid?)
      return Dialog.set_status('Không có ngăn kéo nào để di chuyển.') if parts.empty?
      count = 0
      in_operation("VGD Cabinet Draw — #{label}") { count = yield(parts) }
      Dialog.set_status("#{label}: đã di chuyển #{count} tấm.")
    end

    def prompt_angle(title)
      return @angle_answer if @angle_answer
      answer = UI.inputbox(['Góc mở (độ, 0-135)'], ['90'], title)
      return nil unless answer
      Float(answer.first.to_s.tr(',', '.'))
    rescue ArgumentError, TypeError
      UI.messagebox('Góc mở phải là một số, ví dụ 90.')
      nil
    end

    # Đặt sẵn góc trả lời (dùng cho test).
    def angle_answer=(value)
      @angle_answer = value
    end

    def open_doors(doors, angle, label)
      doors = doors.select(&:valid?)
      skipped = 0
      done = 0
      in_operation("VGD Cabinet Draw — #{label}") do
        doors.each do |door|
          side = Operations.opening_type_of(door)
          unless Operations::HINGE_SIDES.include?(side)
            skipped += 1
            next
          end
          Operations.set_door_angle(door, side, angle)
          done += 1
        end
      end
      note = skipped.zero? ? '' : " (#{skipped} cánh chưa đặt bản lề nên bỏ qua)"
      Dialog.set_status("Đã đặt góc #{angle.round(1)}° cho #{done} cánh#{note}.")
      done
    end

    def close_all(roots)
      count = 0
      in_operation('VGD Cabinet Draw — Đóng tất cả cánh') { roots.each { |root| count += Operations.close_doors(root) } }
      Dialog.set_status(count.zero? ? 'Các cánh đều đang đóng.' : "Đã đóng #{count} cánh.")
      count
    end

    def close_doors(doors)
      count = 0
      in_operation('VGD Cabinet Draw — Đóng cánh') do
        doors.each do |door|
          next unless Operations.door_angle(door) > 0.5
          side = door.get_attribute(Schema::DICTIONARY, 'opening_side', 'left')
          side = 'left' unless Operations::HINGE_SIDES.include?(side)
          Operations.set_door_angle(door, side, 0)
          count += 1
        end
      end
      count
    end

    # Đổi bản lề: cánh đang mở thì đóng trước (đóng quanh bản lề cũ) rồi mới đổi.
    def set_hinge(doors, type)
      in_operation('VGD Cabinet Draw — Đổi bản lề') do
        doors.each do |door|
          next unless door.valid?
          if Operations.door_angle(door) > 0.5
            old = door.get_attribute(Schema::DICTIONARY, 'opening_side', 'left')
            Operations.set_door_angle(door, Operations::HINGE_SIDES.include?(old) ? old : 'left', 0)
          end
          Operations.apply_opening_metadata(door, type)
          Operations.save_opening_to_layout(door, type)
        end
      end
    end

    def auto_handles(roots)
      doors = roots.flat_map { |root| Operations.doors_of(root) }
      doors += roots.flat_map { |root| drawer_fronts_of(root) }
      return Dialog.set_status('Tủ chưa có cánh hoặc mặt hộc để đặt tay nắm.') if doors.empty?
      put_handles(doors)
    end

    def drawer_fronts_of(root)
      box = root.definition.entities.to_a.find { |e| e.is_a?(Sketchup::Group) && e.valid? && e.name == Operations::DRAWER_CONTAINER }
      return [] unless box
      box.definition.entities.to_a.select { |e| e.respond_to?(:name) && e.name == 'Mặt Ngăn Kéo' }
    end

    def put_handles(doors)
      settings = Schema.merge_settings({ 'handle_position' => 'auto' })
      in_operation('VGD Cabinet Draw — Đặt tay nắm') { Operations.handles(doors.select(&:valid?), settings, []) }
      Dialog.set_status("Đã đặt tay nắm cho #{doors.length} cánh.")
    end

    def remove_handles(doors)
      in_operation('VGD Cabinet Draw — Xóa tay nắm') do
        doors.each do |door|
          next unless door.valid?
          door.make_unique if door.respond_to?(:make_unique)
          Operations.handle_groups(door).each(&:erase!)
        end
      end
    end

    # ---------- Hành động: khối tủ lạnh tham chiếu ----------

    def reference_group(root)
      root.definition.entities.to_a.find { |e| e.respond_to?(:name) && e.valid? && e.name == REFERENCE_NAME }
    end

    def reference_visible?(root)
      group = reference_group(root)
      group ? group.visible? : false
    end

    def toggle_reference(roots)
      show = !roots.all? { |root| reference_visible?(root) }
      in_operation('VGD Cabinet Draw — Khối tủ lạnh tham chiếu') do
        roots.each do |root|
          group = reference_group(root)
          group.visible = show if group
        end
      end
    end
  end
end
