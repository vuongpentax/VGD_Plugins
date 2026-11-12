require 'sketchup.rb'
require 'json'
require_relative 'update_notice'
module VGD
  module BIM
    ROOT = File.dirname(__FILE__.dup.force_encoding(Encoding::UTF_8)).freeze unless defined?(ROOT)
    # Thứ tự nạp code. Dùng chung cho lúc mở SketchUp và lúc "Tải lại code".
    FILES = %w[core/locale core/schema core/storage core/settings core/images core/row_order core/data core/tags core/geometry core/view_fit core/scanner core/preset core/photo_settings core/front core/front_probe core/front_align core/measure core/measure_probe core/tag_rules core/tag_catalog core/folder_rules core/tag_tree core/xlsx_reader core/tag_excel core/quantity core/custom_columns core/vgd_id core/object_code core/levels core/table core/rename core/validator
               intake/mapping_rules intake/detector intake/raw_scanner intake/mapping intake/converter core/report_exporter core/table_report
               ui/bounds_preview ui/capture ui/image_actions ui/front_actions ui/tag_auto ui/tag_sample ui/tag_manager ui/dialog].freeze
    @log_counts = Hash.new(0)
    def self.log(message)
      return if @log_counts.values.inject(0, :+) >= 100
      @log_counts[message] += 1
      puts "[VGD BIM] #{message}" if @log_counts[message] <= 3
    end
    def self.presets
      @presets ||= JSON.parse(File.read(File.join(ROOT, 'config', 'presets.json'), encoding: 'UTF-8'))
    end
    def self.open_panel(mode)
      if @panel && !@panel.closed?
        @panel.switch_mode(mode)
      else
        @panel = UI::Dialog.new(mode)
      end
      @panel.show
    end
    # Nạp lại toàn bộ code của plugin mà không cần mở lại SketchUp.
    # Dùng sau khi cài đè bản mới (.rbz). Menu và thanh công cụ giữ như cũ cho tới lần mở SketchUp sau.
    def self.reload
      reopen = @panel && !@panel.closed?
      begin
        @panel.close if reopen
      rescue StandardError
        nil
      end
      @panel = nil
      @presets = nil
      @log_counts = Hash.new(0)
      verbose = $VERBOSE
      $VERBOSE = nil # tránh cảnh báo "hằng số đã khai báo" khi nạp lại
      begin
        load File.join(File.dirname(ROOT), 'vgd_bim.rb')
        load File.join(ROOT, 'loader.rb')
        FILES.each { |file| load File.join(ROOT, "#{file}.rb") }
      ensure
        $VERBOSE = verbose
      end
      open_panel('table') if reopen
      ::UI.messagebox("Đã tải lại VGD_BIM #{VERSION}.")
    rescue ScriptError, StandardError => error
      ::UI.messagebox("Tải lại thất bại:\n#{error.class}: #{error.message}\n\nHãy mở lại SketchUp.")
    end
  end
end
VGD::BIM::FILES.each { |file| require File.join(VGD::BIM::ROOT, file) }
unless file_loaded?(__FILE__)
  # Menu VGD > VGD_BIM: một cú bấm là mở luôn bảng khối lượng.
  vgd_menu = ::UI.menu('Extensions').add_submenu('VGD')
  vgd_menu.add_item('VGD_BIM') { VGD::BIM.open_panel('table') }
  vgd_menu.add_item('VGD_BIM · Tải lại code') { VGD::BIM.reload }
  VGD::UpdateNotice.start('vgd-bim', 'VGD_BIM', VGD::BIM::VERSION)
  ::UI.add_context_menu_handler do |context|
    if Sketchup.active_model.selection.any? { |e| VGD::BIM::Data.supported?(e) }
      context.add_item('VGD_BIM · Thông tin đối tượng') { VGD::BIM.open_panel('information') }
    end
  end
  toolbar = ::UI::Toolbar.new('VGD_BIM')
  command = ::UI::Command.new('VGD_BIM') { VGD::BIM.open_panel('table') }
  command.tooltip = 'VGD_BIM · Bảng khối lượng'
  command.status_bar_text = 'VGD_BIM: mở bảng khối lượng của đối tượng đang chọn'
  command.small_icon = command.large_icon = File.join(VGD::BIM::ROOT, 'assets', 'icons', 'information.svg')
  toolbar.add_item(command)
  toolbar.restore
  file_loaded(__FILE__)
end
