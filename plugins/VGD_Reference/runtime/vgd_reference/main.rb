require 'sketchup.rb'
require_relative 'core/constants'
require_relative 'core/compatibility'

unless VGD::Reference::Compatibility.supported?(Sketchup.active_model)
  UI.messagebox('VGD Reference yêu cầu SketchUp 2023 trở lên với API Overlay. SketchUp 2022 chưa được hỗ trợ trong bản này.')
else
  require_relative 'core/reference_item'
  require_relative 'core/reference_store'
  require_relative 'viewport/screen_coordinates'
  require_relative 'viewport/hit_tester'
  require_relative 'viewport/cursor_manager'
  require_relative 'import/image_loader'
  require_relative 'import/temp_files'
  require_relative 'import/image_formats'
  require_relative 'import/web_images'
  require_relative 'import/image_import'
  require_relative 'import/clipboard_bridge_win'
  require_relative 'viewport/texture_cache'
  require_relative 'viewport/quick_move_prototype'
  require_relative 'tools/crop_controller'
  require_relative 'viewport/reference_overlay'
  require_relative 'tools/interaction_tool'
  require_relative 'observers/app_observer'
  require_relative 'core/session'
  require_relative 'ui/icons'
  require_relative 'ui/manager'

  module VGD
    module Reference
      module_function

      def register_ui
        return if @ui_registered
        manager = UI::Command.new('VGD Reference') { Manager.toggle }
        manager.tooltip = 'VGD Reference: Quản lý ảnh tham chiếu'
        manager.status_bar_text = 'Mở hoặc ẩn bảng quản lý ảnh tham chiếu.'
        Icons.bind(manager)

        menu = UI.menu('Extensions').add_submenu('VGD Reference')
        menu.add_item(UI::Command.new('Mở bảng quản lý') { Manager.open })
        menu.add_item(UI::Command.new('Thêm ảnh tham chiếu') { Session.add_from_picker })
        menu.add_item(UI::Command.new('Dán ảnh tham chiếu') { Session.paste_reference })
        menu.add_item(UI::Command.new('Ẩn / Hiện tất cả') { Session.toggle_hide_all })
        menu.add_item(UI::Command.new('Chỉnh sửa ảnh đã chọn') do
          Session.enter_edit(Session.store.selected_id) if Session.store && Session.store.selected_id
        end)

        @toolbar = UI::Toolbar.new('VGD Reference')
        @toolbar.add_item(manager)
        @toolbar.restore
        @ui_registered = true
      rescue StandardError => error
        ImageLoader.log_error('UI registration failed', error)
      end

      def start
        return unless Compatibility.supported?(Sketchup.active_model)
        Session.initialize
        register_ui
      end
    end
  end

  VGD::Reference.start
end

file_loaded(__FILE__)
