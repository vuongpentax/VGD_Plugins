require 'sketchup.rb'
require 'json'
# Menu Extensions > VGD dùng chung: mọi plugin VGD lấy cùng một menu (SketchUp không gộp các menu trùng tên).
module VGD
  def self.menu
    @extensions_menu ||= ::UI.menu('Extensions').add_submenu('VGD')
  end unless respond_to?(:menu)
end

module VGD
  module Transform
    ROOT = File.dirname(__FILE__.dup.force_encoding(Encoding::UTF_8)).freeze unless defined?(ROOT)
    # Thứ tự nạp code. Dùng chung cho lúc mở SketchUp và lúc "Tải lại code".
    FILES = %w[core/units core/items core/steps core/translate core/rotate_scale core/plan core/model_ops ui/panel].freeze
    @log_counts = Hash.new(0)
    def self.log(message)
      return if @log_counts.values.inject(0, :+) >= 100
      @log_counts[message] += 1
      puts "[VGD Transform] #{message}" if @log_counts[message] <= 3
    end
    TOOLS = %w[move rotate scale].freeze
    # Mở cửa sổ (hoặc đưa lên trước), chọn sẵn công cụ nếu có (nút Dời / Xoay / Scale trên thanh công cụ).
    def self.open_panel(tool = nil)
      @panel = Panel.new if @panel.nil? || @panel.closed?
      @panel.select_tool(tool) if TOOLS.include?(tool)
      @panel.show
    end
    # Nạp lại toàn bộ code của plugin mà không cần mở lại SketchUp.
    # Dùng sau khi cài đè bản mới (.rbz). Menu và thanh công cụ giữ như cũ cho tới lần mở SketchUp sau.
    # Kiểm tra cú pháp cả bộ file trước: có lỗi thì giữ nguyên bản đang chạy.
    def self.reload
      busy = @panel && !@panel.closed? && @panel.busy_reason # đang làm việc dở: không nạp lại, để người dùng chờ xong
      if busy
        ::UI.messagebox("Tải lại thất bại: VGD Transform #{busy}.\n\nHãy chờ xong rồi tải lại code.")
        return false
      end
      files = [File.join(File.dirname(ROOT), 'vgd_transform.rb'), File.join(ROOT, 'loader.rb')] +
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
      ::UI.messagebox("Đã tải lại VGD Transform #{VERSION}.")
      true
    rescue ScriptError, StandardError => error
      ::UI.messagebox("Tải lại thất bại:\n#{error.class}: #{error.message}\n\n#{loading ? 'Hãy mở lại SketchUp nếu giao diện báo lỗi.' : 'Bản đang chạy được giữ nguyên.'}")
      false
    end
  end
end

VGD::Transform::FILES.each { |file| require File.join(VGD::Transform::ROOT, file) }
unless file_loaded?(__FILE__)
  # Menu Extensions > VGD > VGD Transform.
  vgd_menu = ::VGD.menu.add_submenu('VGD Transform')
  vgd_menu.add_item('Mở bảng biến đổi') { VGD::Transform.open_panel }
  vgd_menu.add_item('Tải lại code') { VGD::Transform.reload }
  # Thanh công cụ VGD TRF: ba nút như 3ds Max (Dời, Xoay, Scale), mỗi nút mở cửa sổ ở đúng công cụ.
  toolbar = ::UI::Toolbar.new('VGD TRF')
  [['move', 'Dời', 'dời group / component đang chọn tới tọa độ hoặc theo độ dời'],
   ['rotate', 'Xoay', 'xoay group / component đang chọn quanh trục X, Y, Z'],
   ['scale', 'Scale', 'scale group / component đang chọn theo hệ số, tỉ lệ hoặc kích thước đích']].each do |tool, label, text|
    command = ::UI::Command.new("VGD_TRANSFORM_#{tool.upcase}") { VGD::Transform.open_panel(tool) }
    command.tooltip = "VGD Transform · #{label}"
    command.status_bar_text = "VGD Transform: #{text}, nhập số theo đơn vị của file."
    command.small_icon = command.large_icon = File.join(VGD::Transform::ROOT, 'assets', 'icons', "#{tool}.svg")
    toolbar.add_item(command)
  end
  toolbar.restore
  file_loaded(__FILE__)
end
