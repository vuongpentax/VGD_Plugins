require 'sketchup.rb'
# Menu Extensions > VGD dùng chung: mọi plugin VGD lấy cùng một menu (SketchUp không gộp các menu trùng tên).
module VGD
  def self.menu
    @extensions_menu ||= ::UI.menu('Extensions').add_submenu('VGD')
  end unless respond_to?(:menu)
end

module VGD
  module Structure
    ROOT = File.dirname(__FILE__.dup.force_encoding(Encoding::UTF_8)).freeze unless defined?(ROOT)
    # Thứ tự nạp code. Dùng chung cho lúc mở SketchUp và lúc "Tải lại code".
    FILES = %w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/layer_list core/levels core/column_plan core/footing_plan core/roof_plan core/glass_wall_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/slab_plan core/ceiling_plan core/proposal core/checker core/schedule core/model_edit core/section_geometry core/elevation_geometry core/stair_types core/stair_plan core/stair_place core/sketchup_import core/state core/preview model_sync edit_sync su_scan su_section model_store tag_store grid_tag grid_builder column_builder footing_builder roof_builder glass_wall_builder beam_builder wall_builder opening_builder plate_builder stair_builder all_builder su_tools panel].freeze

    # Lý do đang bận (không cho tải lại code), hoặc nil. Chưa có thao tác vẽ / dựng nào ở cột mốc 0; cột mốc sau cập nhật khi có.
    def self.busy_reason
      nil
    end

    def self.open_panel
      if @panel && !@panel.closed?
        @panel.show
      else
        @panel = Panel.new
        @panel.show
      end
      @panel
    end

    # VGD_BIM gọi lệnh `edit` của cầu nối khi người dùng chọn một phần tử do plugin dựng: mở cửa sổ ở đúng tab, tầng và phần tử đó.
    # Trả về true nếu đã mở; lỗi (không phải phần tử của plugin) thì raise để BIM báo.
    def self.edit(entity)
      source = entity.respond_to?(:get_attribute) ? entity.get_attribute('VGD_BIM_SOURCE', 'plugin') : nil
      raise ArgumentError, 'Đối tượng không do VGD Structure dựng.' unless source == Schema::PLUGIN_ID
      kind = entity.get_attribute('VGD_BIM_SOURCE', 'kind').to_s
      raise ArgumentError, 'Loại phần tử không hợp lệ.' unless Schema::KINDS.include?(kind)
      level_id, ref = entity.get_attribute('VGD_BIM_SOURCE', 'ref').to_s.split(':', 2)
      open_panel.focus(kind, level_id.to_s, ref.to_s)
      true
    end

    # Menu "Vẽ trong SketchUp": mở cửa sổ ở tab Mặt bằng và bật công cụ vẽ ngay trong khung nhìn SketchUp.
    def self.start_draw(tool)
      open_panel.start_tool(tool)
      true
    end

    # Nạp lại toàn bộ code của plugin mà không cần mở lại SketchUp (dùng sau khi cài đè bản mới).
    # Menu giữ như cũ cho tới lần mở SketchUp sau. Kiểm tra cú pháp cả bộ file trước: có lỗi thì giữ nguyên bản đang chạy.
    def self.reload
      busy = busy_reason
      if busy
        ::UI.messagebox("Không tải lại được: #{busy}\n\nHãy chờ xong rồi tải lại code.")
        return false
      end
      files = [File.join(File.dirname(ROOT), 'vgd_structure.rb'), File.join(ROOT, 'loader.rb')] +
              FILES.map { |file| File.join(ROOT, "#{file}.rb") }
      files.each { |file| RubyVM::InstructionSequence.compile_file(file) }
      reopen = @panel && !@panel.closed?
      begin
        @panel.close if reopen
      rescue StandardError
        nil
      end
      @panel = nil
      loading = true # từ đây lỗi nghĩa là đã nạp dở, không còn "giữ nguyên bản đang chạy"
      verbose = $VERBOSE
      $VERBOSE = nil # tránh cảnh báo "hằng số đã khai báo" khi nạp lại
      begin
        files.each { |file| load file }
      ensure
        $VERBOSE = verbose
      end
      open_panel if reopen # chỉ mở lại cửa sổ nếu trước đó đang mở
      ::UI.messagebox("Đã tải lại VGD Structure #{VERSION}.")
      true
    rescue ScriptError, StandardError => error
      ::UI.messagebox("Tải lại thất bại:\n#{error.class}: #{error.message}\n\n#{loading ? 'Hãy mở lại SketchUp nếu giao diện báo lỗi.' : 'Bản đang chạy được giữ nguyên.'}")
      false
    end
  end
end
VGD::Structure::FILES.each { |file| require File.join(VGD::Structure::ROOT, file) }
# Đăng ký vào danh bạ cầu nối (bridge_version 1): loại structure_element, lệnh edit (VGD_BIM gọi). Tải lại code thì ghi đè mục cũ.
::VGD::Bridge.register('vgd_structure', {bridge_version: ::VGD::Bridge::VERSION, version: VGD::Structure::VERSION, provides: ['structure_element'],
                                         commands: {'edit' => ->(_model, entity) { VGD::Structure.edit(entity) }}})
unless file_loaded?(__FILE__)
  # Menu Extensions > VGD > VGD Structure và thanh công cụ VGD STR. Chỉ đăng ký một lần; tải lại code không đăng ký lại.
  menu = ::VGD.menu.add_submenu('VGD Structure')
  menu.add_item('Lưới trục') { VGD::Structure.open_panel }
  draw_menu = menu.add_submenu('Vẽ trong SketchUp')
  [['Cột', 'column'], ['Dầm', 'beam'], ['Tường', 'wall'], ['Cửa đi', 'door'], ['Cửa sổ', 'window'], ['Sàn', 'slab'], ['Trần', 'ceiling'], ['Cầu thang', 'stair']].each do |label, tool|
    draw_menu.add_item(label) { VGD::Structure.start_draw(tool) }
  end
  menu.add_item('Tải lại code') { VGD::Structure.reload }
  toolbar = ::UI::Toolbar.new('VGD STR')
  command = ::UI::Command.new('VGD Structure · Lưới trục') { VGD::Structure.open_panel }
  command.tooltip = 'VGD Structure · Lưới trục'
  command.status_bar_text = 'VGD Structure: khai báo và vẽ lưới trục'
  command.small_icon = command.large_icon = File.join(VGD::Structure::ROOT, 'assets', 'icons', 'grid.svg')
  toolbar.add_item(command)
  # Nút vẽ trực tiếp trong SketchUp (cùng lệnh với menu Vẽ trong SketchUp): icon SVG theo bộ icon VGD (xem shared/VGD_ICON_SYSTEM_RULES.md).
  [['column', 'Cột'], ['beam', 'Dầm'], ['wall', 'Tường'], ['door', 'Cửa đi'], ['window', 'Cửa sổ'], ['slab', 'Sàn'], ['ceiling', 'Trần'], ['stair', 'Cầu thang']].each do |tool, label|
    draw_command = ::UI::Command.new("VGD Structure · Vẽ #{label.downcase}") { VGD::Structure.start_draw(tool) }
    draw_command.tooltip = "VGD Structure · Vẽ #{label.downcase}"
    draw_command.status_bar_text = "VGD Structure: vẽ #{label.downcase} trực tiếp trong SketchUp"
    draw_command.small_icon = draw_command.large_icon = File.join(VGD::Structure::ROOT, 'assets', 'icons', "draw_#{tool}.svg")
    toolbar.add_item(draw_command)
  end
  toolbar.restore
  file_loaded(__FILE__)
end
