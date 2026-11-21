require 'sketchup.rb'
require 'json'
# Menu Extensions > VGD dùng chung: mọi plugin VGD lấy cùng một menu (SketchUp không gộp các menu trùng tên).
module VGD
  def self.menu
    @extensions_menu ||= ::UI.menu('Extensions').add_submenu('VGD')
  end unless respond_to?(:menu)
end

module VGD
  module Position
    ROOT = File.dirname(__FILE__.dup.force_encoding(Encoding::UTF_8)).freeze unless defined?(ROOT)
    # Thứ tự nạp code. Dùng chung cho lúc mở SketchUp và lúc "Tải lại code".
    FILES = %w[core/position core/move ui/panel].freeze
    @log_counts = Hash.new(0)
    def self.log(message)
      return if @log_counts.values.inject(0, :+) >= 100
      @log_counts[message] += 1
      puts "[VGD Position] #{message}" if @log_counts[message] <= 3
    end
    def self.open_panel
      if @panel && !@panel.closed?
        @panel.show
      else
        @panel = Panel.new
        @panel.show
      end
    end
    # Nạp lại toàn bộ code của plugin mà không cần mở lại SketchUp.
    # Dùng sau khi cài đè bản mới (.rbz). Menu và thanh công cụ giữ như cũ cho tới lần mở SketchUp sau.
    # Kiểm tra cú pháp cả bộ file trước: có lỗi thì giữ nguyên bản đang chạy.
    def self.reload
      busy = @panel && !@panel.closed? && @panel.busy_reason # đang làm việc dở: không nạp lại, để người dùng chờ xong
      if busy
        ::UI.messagebox("Tải lại thất bại: VGD Position #{busy}.\n\nHãy chờ xong rồi tải lại code.")
        return false
      end
      files = [File.join(File.dirname(ROOT), 'vgd_position.rb'), File.join(ROOT, 'loader.rb')] +
              FILES.map { |file| File.join(ROOT, "#{file}.rb") }
      files.each { |file| RubyVM::InstructionSequence.compile_file(file) }
      loading = true # từ đây lỗi nghĩa là đã nạp dở, không còn "giữ nguyên bản đang chạy"
      reopen = @panel && !@panel.closed?
      begin
        @panel.close if reopen
      rescue StandardError
        nil
      end
      @panel = nil
      @log_counts = Hash.new(0)
      verbose = $VERBOSE
      $VERBOSE = nil # tránh cảnh báo "hằng số đã khai báo" khi nạp lại
      begin
        files.each { |file| load file }
      ensure
        $VERBOSE = verbose
      end
      open_panel if reopen
      ::UI.messagebox("Đã tải lại VGD Position #{VERSION}.")
      true
    rescue ScriptError, StandardError => error
      ::UI.messagebox("Tải lại thất bại:\n#{error.class}: #{error.message}\n\n#{loading ? 'Hãy mở lại SketchUp nếu giao diện báo lỗi.' : 'Bản đang chạy được giữ nguyên.'}")
      false
    end
  end
end

VGD::Position::FILES.each { |file| require File.join(VGD::Position::ROOT, file) }
unless file_loaded?(__FILE__)
  # Menu Extensions > VGD > VGD Position.
  vgd_menu = ::VGD.menu.add_submenu('VGD Position')
  vgd_menu.add_item('Mở bảng vị trí') { VGD::Position.open_panel }
  vgd_menu.add_item('Tải lại code') { VGD::Position.reload }
  toolbar = ::UI::Toolbar.new('VGD POS')
  command = ::UI::Command.new('VGD_POSITION') { VGD::Position.open_panel }
  command.tooltip = 'VGD_POSITION · Dời món theo tọa độ'
  command.status_bar_text = 'VGD_POSITION: nhập tọa độ X, Y, Z (mm) để dời món đang chọn'
  command.small_icon = command.large_icon = File.join(VGD::Position::ROOT, 'assets', 'icons', 'position.svg')
  toolbar.add_item(command)
  toolbar.restore
  file_loaded(__FILE__)
end
