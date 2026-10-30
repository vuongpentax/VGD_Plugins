require 'sketchup.rb'
require 'json'
require 'securerandom'

module VGD_Cabinet_Draw
  # Nạp lại (reload!) phải lấy danh sách file và phiên bản MỚI, nên xóa hằng cũ trước khi khai báo.
  %i[VERSION RUNTIME_FILES RUNTIME_CONSTANTS].each { |name| remove_const(name) if const_defined?(name, false) }
  VERSION = '1.0.0-beta.66'
  # Thứ tự nạp quan trọng: panel_model trước schema (schema dùng bộ tấm mặc định).
  RUNTIME_FILES = %w[keys theme panel_model split door_layout schema model_data geometry interior door_geometry preview drawer_parts drawer_slide tools rebuild auto_stretch resize scale_tool links removal drawer_bay panel_tools context_menu preset_hud mini_bar preset_store tool_settings dialog].freeze
  RUNTIME_CONSTANTS = %i[Keys Theme PanelModel Split DoorLayout Schema ModelData Geometry Interior DoorFit DoorGeometry Preview DrawerParts DrawerSlide Tools Operations Rebuild AutoStretch Resize Links Removal DrawerBay PanelTools ContextMenu PresetHud MiniBar PresetStore ToolSettings Dialog].freeze
  extend self

  # Nạp (hoặc nạp lại) toàn bộ file runtime từ đĩa bằng load, không dùng require,
  # để lần nào cũng đọc bản mới nhất.
  def load_runtime
    clear_runtime
    RUNTIME_FILES.each { |name| load File.join(__dir__, "#{name}.rb") }
    MiniBar.attach_to_tools # SAU PresetHud: thanh nút nhận click trước HUD
  end

  def clear_runtime
    RUNTIME_CONSTANTS.each do |name|
      remove_const(name) if const_defined?(name, false)
    end
  end

  # Nút trên thanh công cụ: [khóa, tên, gợi ý, mô tả thanh trạng thái]. 'settings' mở bảng điều khiển.
  TOOLBAR_BUTTONS = [
    ['box', 'Box → Board', 'Chuyển box thành thùng tủ, hoặc face thành ván', 'Chọn box rồi click mặt trước, hoặc chọn face để tạo ván. Dùng setting mặc định của công cụ Box → Board.'],
    ['panel', 'Chia đợt / vách', 'Chia đợt (nóc/đáy) hoặc vách (hông)', 'Rê chuột xem trước, click đặt. Dùng setting mặc định của công cụ Đợt / vách.'],
    ['door', 'Cánh tủ', 'Chia cánh trên mặt tủ', 'Chia vùng trên mặt tủ. Dùng setting mặc định của công cụ Cánh tủ.'],
    ['drawer', 'Ngăn kéo', 'Tạo ngăn kéo', 'Tạo mặt và thùng kéo. Dùng setting mặc định của công cụ Ngăn kéo.'],
    ['resize', 'Scale VGD', 'Co giãn tủ theo điểm neo (kéo hoặc gõ số mm)', 'Chọn một tủ, bấm điểm neo (mặt đứng yên), kéo hoặc gõ kích thước mới rồi Enter; mộng và dấu tiết diện giữ nguyên, cánh và ngăn kéo đi theo hông và hồi giữa.'],
    ['pick', 'VGD Chọn', 'Chuột phải lên tủ / cánh để hiện thanh nút', 'Bật công cụ rồi chuột phải lên tủ, cánh hoặc mặt hộc: thanh nút tròn hiện ngay tại con trỏ.'],
    ['settings', 'Setting', 'Mở bảng setting', 'Mở bảng điều khiển để chỉnh và lưu setting.']
  ].freeze unless const_defined?(:TOOLBAR_BUTTONS, false)

  def icon_file(key, size)
    base = File.join(__dir__, 'icons')
    png = File.join(base, "#{key}_#{size}.png")
    svg = File.join(base, "#{key}.svg")
    return png if File.file?(png)
    File.file?(svg) ? svg : nil
  end

  def build_command(key, title, tip, status)
    command = UI::Command.new(title) { key == 'settings' ? Dialog.show : (key == 'resize' ? VGD_Cabinet_Draw.launch_scale : (key == 'pick' ? VGD_Cabinet_Draw.toggle_pick : VGD_Cabinet_Draw.launch_default(key))) }
    command.tooltip = tip
    # Nút VGD Chọn là nút bật/tắt: sáng khi đang chạy, bấm lần nữa để tắt.
    command.set_validation_proc { VGD_Cabinet_Draw.pick_active? ? (defined?(MF_CHECKED) ? MF_CHECKED : 8) : (defined?(MF_UNCHECKED) ? MF_UNCHECKED : 0) } if key == 'pick' && command.respond_to?(:set_validation_proc)
    command.status_bar_text = status
    command.menu_text = title
    small = icon_file(key, 16) # PNG 16 và 24 px: cặp kích thước đã chạy ổn trên SketchUp 2024 (bản 24/32 làm mất icon)
    large = icon_file(key, 24)
    command.small_icon = small if small
    command.large_icon = large if large
    command
  end

  def start
    return if @started
    @started = true
    toolbar = UI::Toolbar.new('VGD Cabinet Draw')
    submenu = UI.menu('Extensions').add_submenu('VGD Cabinet Draw')
    TOOLBAR_BUTTONS.each do |key, title, tip, status|
      command = build_command(key, title, tip, status)
      submenu.add_item(command)
      toolbar.add_item(command)
    end
    submenu.add_item('Đóng tất cả cánh của tủ đang chọn') { VGD_Cabinet_Draw.close_selected_doors }
    submenu.add_item('Tìm tấm bị trùng') { VGD_Cabinet_Draw.run_panel_tool(:find_duplicates) }
    submenu.add_item('Chuẩn hóa tên ván (vai trò + số)') { VGD_Cabinet_Draw.run_panel_tool(:normalize_names) }
    submenu.add_item('Tải lại VGD Cabinet Draw (nạp code mới)') { VGD_Cabinet_Draw.reload! }
    toolbar.restore if toolbar.get_last_state == TB_HIDDEN
    toolbar.show
    @toolbar = toolbar
    register_context_menu
    AutoStretch.attach
  end

  # Menu chuột phải "VGD Cabinet ▸". Đăng ký MỘT lần (cờ @ctx_registered nằm ở module chính nên không mất khi nạp lại code);
  # handler tra ContextMenu lúc chạy nên luôn dùng bản mới nhất sau "Tải lại".
  def register_context_menu
    return if @ctx_registered
    @ctx_registered = true
    UI.add_context_menu_handler do |menu|
      VGD_Cabinet_Draw::ContextMenu.populate(menu) if VGD_Cabinet_Draw.const_defined?(:ContextMenu, false)
    end
  end

  # Đang có công cụ VGD chạy: menu của công cụ (getMenu) đã đủ, không thêm menu theo đối tượng nữa.
  def vgd_tool_active?
    tool = @active_tool
    tool && tool.respond_to?(:active?) && tool.active? ? true : false
  end

  # Chạy công cụ từ thanh công cụ, không cần mở bảng: dùng thông số gốc và setting mặc định (★) của công cụ.
  # Nếu bảng đang mở, setting trong các ô của bảng KHÔNG được dùng ở đây.
  def launch_default(name)
    group = Schema::TOOL_GROUP[name.to_s]
    raise "Công cụ '#{name}' chưa có kho setting." unless group
    store = ToolSettings.new
    default_id = store.all['tools'][group]['default_id']
    launch_tool(name, store.effective(group), default_id)
  rescue StandardError => e
    UI.messagebox("Không thể mở công cụ: #{e.message}")
  end

  # Đóng mọi cánh đang mở của các tủ đang chọn (một bước Undo). Dùng sau khi dựng phối cảnh mở cánh.
  def close_selected_doors
    model = Sketchup.active_model
    roots = ModelData.cabinets_in(model.selection)
    if roots.empty?
      UI.messagebox('Hãy chọn ít nhất một tủ rồi chạy lại lệnh này.')
      return 0
    end
    count = 0
    model.start_operation('VGD Cabinet Draw — Đóng tất cả cánh', true)
    begin
      roots.each { |root| count += Operations.close_doors(root) }
    rescue StandardError => e
      model.abort_operation
      UI.messagebox("Không đóng được cánh: #{e.message}")
      return 0
    end
    model.commit_operation
    UI.messagebox(count.zero? ? 'Các cánh của tủ đang chọn đều đang đóng.' : "Đã đóng #{count} cánh.")
    count
  end

  # Công cụ nhỏ: tìm tấm trùng / chuẩn hóa tên ván, cho các tủ đang chọn (không chọn gì thì quét mọi tủ trong model).
  def run_panel_tool(kind)
    model = Sketchup.active_model
    roots = ModelData.cabinets_in(model.selection)
    roots = model.entities.select { |entity| ModelData.cabinet?(entity) } if roots.empty?
    if roots.empty?
      UI.messagebox('Không thấy tủ nào để xử lý.')
      return
    end
    kind == :find_duplicates ? PanelTools.select_duplicates(roots) : PanelTools.normalize_names_command(roots)
  rescue StandardError => e
    UI.messagebox("Không chạy được: #{e.message}")
  end

  # Nạp lại code mà không cần tắt SketchUp. Không đăng ký lại menu hay thanh công cụ.
  def reload!
    Dialog.close if const_defined?(:Dialog, false)
    Sketchup.active_model.select_tool(nil)
    @active_tool = nil
    load __FILE__
    UI.messagebox("VGD Cabinet Draw #{VERSION} đã nạp lại code mới.")
  rescue StandardError, ScriptError => e
    UI.messagebox("Nạp lại thất bại: #{e.class}: #{e.message}")
  end

  # Nút VGD Chọn sáng khi CHẾ ĐỘ chọn đang bật (không phụ thuộc công cụ đang chạy): chỉ tắt khi bấm lại nút.
  def pick_active?
    @pick_mode ? true : false
  end

  def pick_tool_running?
    tool = @active_tool
    tool.is_a?(Tools::PickTool) && tool.active? ? true : false
  end

  # Quan sát đổi công cụ: khi chế độ chọn đang bật mà SketchUp chuyển sang công cụ Chọn (ví dụ bấm Space) thì quay về VGD Chọn.
  class PickModeObserver < Sketchup::ToolsObserver
    SELECT_TOOL_ID = 21022
    def onActiveToolChanged(_tools, tool_name, tool_id)
      return unless VGD_Cabinet_Draw.pick_active?
      return unless tool_id == SELECT_TOOL_ID || tool_name.to_s == 'SelectionTool'
      VGD_Cabinet_Draw.schedule_pick_resume
    end
  end

  # Chọn tủ VGD bằng công cụ Chọn của SketchUp (đã trả quyền): bật lại VGD Chọn để nhấp đúp mở thanh nút.
  class PickSelectionObserver < Sketchup::SelectionObserver
    def onSelectionBulkChange(selection)
      VGD_Cabinet_Draw.pick_selection_changed(selection)
    end

    def onSelectionAdded(selection, _entity)
      VGD_Cabinet_Draw.pick_selection_changed(selection)
    end
  end

  # Công cụ VGD Chọn trả quyền cho Chọn của SketchUp khi bấm vật không phải VGD.
  def pass_to_su_select
    @pick_native = true
  end

  def pick_native?
    @pick_native ? true : false
  end

  def pick_selection_changed(selection)
    return unless pick_active? && pick_native?
    items = selection.to_a
    return unless items.length == 1
    item = items.first
    return unless ModelData.cabinet?(item) || (defined?(Operations) && Operations.door?(item))
    @pick_native = false
    schedule_pick_resume
  end

  def attach_pick_observer(model = Sketchup.active_model)
    return unless model && defined?(Sketchup::ToolsObserver)
    @pick_observer ||= PickModeObserver.new
    model.tools.remove_observer(@pick_observer) if model.tools.respond_to?(:remove_observer)
    model.tools.add_observer(@pick_observer)
    if defined?(Sketchup::SelectionObserver) && model.selection.respond_to?(:add_observer)
      @pick_sel_observer ||= PickSelectionObserver.new
      model.selection.remove_observer(@pick_sel_observer) if model.selection.respond_to?(:remove_observer)
      model.selection.add_observer(@pick_sel_observer)
    end
  rescue StandardError => e
    puts "[VGD Cabinet Draw] Không gắn được bộ quan sát công cụ: #{e.message}"
  end

  def schedule_pick_resume
    return if @pick_resume_scheduled || @pick_native
    @pick_resume_scheduled = true
    UI.start_timer(0.0, false) do
      @pick_resume_scheduled = false
      launch_pick if pick_active? && !pick_tool_running?
    end
  end

  # Phím Space trong lệnh: thoát về Chọn của SketchUp và TẮT chế độ VGD Chọn (không thì observer bật lại ngay).
  def stop_pick_mode
    @pick_mode = false
  end

  # Bấm nút VGD Chọn: chế độ đang bật thì tắt hẳn (về công cụ Chọn thường), chưa bật thì bật.
  def toggle_pick
    if @pick_mode
      @pick_mode = false
      @pick_native = false
      Sketchup.active_model.select_tool(nil)
    else
      @pick_mode = true
      attach_pick_observer
      launch_pick
    end
  end

  # Công cụ VGD Chọn (thanh nút tròn khi chuột phải hoặc nhấp đúp).
  def launch_pick
    tool = Tools::PickTool.new
    @active_tool = tool
    Sketchup.active_model.select_tool(tool)
  rescue StandardError => e
    UI.messagebox("Không thể mở VGD Chọn: #{e.message}")
  end

  # Lệnh Scale VGD (điểm neo): không có setting nên không đi qua kho setting.
  def launch_scale
    tool = Tools::ScaleTool.new
    @active_tool = tool
    Sketchup.active_model.select_tool(tool)
  rescue StandardError => e
    UI.messagebox("Không thể mở Scale VGD: #{e.message}")
  end

  def launch_tool(name, settings = {}, preset_id = nil)
    tool = Tools.build(name, settings)
    tool.active_preset_id = preset_id if preset_id && tool.respond_to?(:active_preset_id=)
    @active_tool = tool
    Sketchup.active_model.select_tool(tool)
    Dialog.set_status("Đang dùng: #{Tools.label(name)}. Click vùng trống hoặc Enter áp dụng · Space thoát · Esc hủy.")
  rescue StandardError => e
    UI.messagebox("Không thể mở công cụ: #{e.message}")
  end

  # Nút Áp dụng trong bảng: chỉ chạy khi có công cụ đang hoạt động, tránh áp dụng hai lần.
  def apply_active_tool
    tool = @active_tool
    raise 'Chưa có công cụ nào đang chạy.' unless tool && tool.respond_to?(:active?) && tool.active?
    tool.commit(Sketchup.active_model.active_view)
  end

  def cancel_active_tool
    tool = @active_tool
    return unless tool && tool.respond_to?(:active?) && tool.active?
    tool.cancel_tool(Sketchup.active_model.active_view)
  end

  # Danh sách setting vừa đổi trong bảng: cập nhật thanh chọn trên viewport của công cụ đang chạy.
  def refresh_active_presets
    @active_tool.reload_presets if @active_tool && @active_tool.respond_to?(:active?) && @active_tool.active? && @active_tool.respond_to?(:reload_presets)
  end

  def update_active_settings(settings)
    @active_tool.update_settings(settings) if @active_tool && @active_tool.respond_to?(:update_settings)
  end
end

VGD_Cabinet_Draw.load_runtime
VGD_Cabinet_Draw.start
# Đăng ký menu chuột phải NGOÀI start: nếu SketchUp đang chạy bản cũ (start đã chạy rồi) mà nạp bản mới bằng "Tải lại", menu vẫn được đăng ký.
VGD_Cabinet_Draw.register_context_menu
