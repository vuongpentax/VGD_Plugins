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
    FILES = %w[core/schema core/grid core/axis_symbol core/column_types core/beam_types core/wall_types core/levels core/column_plan core/beam_plan core/wall_plan core/state core/preview model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder panel].freeze

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
unless file_loaded?(__FILE__)
  # Menu Extensions > VGD > VGD Structure và thanh công cụ VGD STR. Chỉ đăng ký một lần; tải lại code không đăng ký lại.
  menu = ::VGD.menu.add_submenu('VGD Structure')
  menu.add_item('Lưới trục') { VGD::Structure.open_panel }
  menu.add_item('Tải lại code') { VGD::Structure.reload }
  toolbar = ::UI::Toolbar.new('VGD STR')
  command = ::UI::Command.new('VGD Structure · Lưới trục') { VGD::Structure.open_panel }
  command.tooltip = 'VGD Structure · Lưới trục'
  command.status_bar_text = 'VGD Structure: khai báo và vẽ lưới trục'
  command.small_icon = command.large_icon = File.join(VGD::Structure::ROOT, 'assets', 'icons', 'grid.svg')
  toolbar.add_item(command)
  toolbar.restore
  file_loaded(__FILE__)
end
