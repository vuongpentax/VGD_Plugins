require 'sketchup.rb'
require_relative 'core/constants'
require_relative 'core/compatibility'

# Menu Extensions > VGD dùng chung: mọi plugin VGD lấy cùng một menu (SketchUp không gộp các menu trùng tên).
module VGD
  def self.menu
    @extensions_menu ||= ::UI.menu('Extensions').add_submenu('VGD')
  end unless respond_to?(:menu)
end

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

      # Danh sách file nạp lại khi "Tải lại code" (trùng các require_relative ở trên, main nạp cuối).
      CODE_FILES = %w[core/constants core/compatibility core/reference_item core/reference_store
                      viewport/screen_coordinates viewport/hit_tester viewport/cursor_manager import/image_loader
                      import/temp_files import/image_formats import/web_images import/image_import
                      import/clipboard_bridge_win viewport/texture_cache viewport/quick_move_prototype
                      tools/crop_controller viewport/reference_overlay tools/interaction_tool observers/app_observer
                      core/session ui/icons ui/manager main].freeze unless const_defined?(:CODE_FILES, false)

      # Nạp lại mã mà không cần mở lại SketchUp. Kiểm tra cú pháp cả bộ file trước: có lỗi thì giữ nguyên bản đang chạy.
      # Dữ liệu ảnh, lớp phủ và observer nằm trong biến của module nên được giữ nguyên.
      def reload
        if Session.editing? || ImageImport.busy?
          UI.messagebox('Đang chỉnh sửa hoặc nhập ảnh tham chiếu. Hãy hoàn tất rồi tải lại code.')
          return false
        end
        files = CODE_FILES.map { |name| File.join(__dir__, "#{name}.rb") }
        files.each { |file| RubyVM::InstructionSequence.compile_file(file) }
        reopen = Manager.visible?
        Manager.toggle if reopen
        old_files = CODE_FILES
        verbose = $VERBOSE
        $VERBOSE = nil # tránh cảnh báo "hằng số đã khai báo" khi nạp lại
        begin
          Reference.send(:remove_const, :CODE_FILES)
          files.each { |file| load file }
        rescue ScriptError, StandardError
          Reference.const_set(:CODE_FILES, old_files) unless Reference.const_defined?(:CODE_FILES, false)
          raise
        ensure
          $VERBOSE = verbose
        end
        Manager.open if reopen
        Session.redraw
        UI.messagebox("Đã tải lại VGD Reference #{VERSION}.")
        true
      rescue ScriptError, StandardError => error
        UI.messagebox("Tải lại thất bại:\n#{error.class}: #{error.message}\n\nBản đang chạy được giữ nguyên.")
        false
      end

      def register_ui
        return if @ui_registered
        manager = UI::Command.new('VGD Reference') { Manager.toggle }
        manager.tooltip = 'VGD Reference: Quản lý ảnh tham chiếu'
        manager.status_bar_text = 'Mở hoặc ẩn bảng quản lý ảnh tham chiếu.'
        Icons.bind(manager)

        menu = ::VGD.menu.add_submenu('VGD Reference')
        menu.add_item(UI::Command.new('Mở bảng quản lý') { Manager.open })
        menu.add_item(UI::Command.new('Thêm ảnh tham chiếu') { Session.add_from_picker })
        menu.add_item(UI::Command.new('Dán ảnh tham chiếu') { Session.paste_reference })
        menu.add_item(UI::Command.new('Ẩn / Hiện tất cả') { Session.toggle_hide_all })
        menu.add_item(UI::Command.new('Chỉnh sửa ảnh đã chọn') do
          Session.enter_edit(Session.store.selected_id) if Session.store && Session.store.selected_id
        end)
        menu.add_item(UI::Command.new('Tải lại code') { reload })

        @toolbar = UI::Toolbar.new('VGD REF')
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
