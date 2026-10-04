require 'sketchup.rb'
require 'json'
module VGD
  module BIM
    ROOT = File.dirname(__FILE__).freeze
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
  end
end
%w[core/locale core/schema core/data core/geometry core/scanner core/validator intake/mapping_rules intake/detector intake/raw_scanner intake/mapping intake/converter core/report_exporter ui/dialog ui/information_dialog ui/scan_dialog ui/mapping_dialog ui/validation_dialog].each { |file| require File.join(VGD::BIM::ROOT, file) }
unless file_loaded?(__FILE__)
  menu = ::UI.menu('Extensions').add_submenu('VGD').add_submenu('BIM Lite')
  actions = [['Thông tin đối tượng', 'information'], ['Quét mô hình', 'scan'], ['Phân loại / Chuyển đổi', 'mapping'], ['Chuyển đổi đối tượng đang chọn', 'convert_selection'], ['Kiểm tra đối tượng đang chọn', 'validate_selection'], ['Kiểm tra toàn bộ mô hình', 'validate_model'], ['Quy tắc phân loại', 'rules'], ['Xuất báo cáo', 'export']]
  actions.each { |name, mode| menu.add_item(name) { VGD::BIM.open_panel(mode) } }
  menu.add_item('Giới thiệu') { ::UI.messagebox("VGD BIM Lite #{VGD::BIM::VERSION}\nDữ liệu / Phân loại / Kiểm tra / Xuất báo cáo\nSketchUp 2022+\nVGD") }
  ::UI.add_context_menu_handler do |context|
    if Sketchup.active_model.selection.any? { |e| VGD::BIM::Data.supported?(e) }
      context.add_item('VGD BIM · Thông tin đối tượng') { VGD::BIM.open_panel('information') }
      context.add_item('VGD BIM · Chuyển đổi dữ liệu') { VGD::BIM.open_panel('convert_selection') }
    end
  end
  toolbar = ::UI::Toolbar.new('VGD BIM Lite')
  [['Thông tin đối tượng', 'information', 'information.svg'], ['Quét / Kiểm tra mô hình', 'scan', 'scan.svg']].each do |name, mode, icon|
    command = ::UI::Command.new(name) { VGD::BIM.open_panel(mode) }
    command.tooltip = name
    command.status_bar_text = "VGD BIM Lite: #{name}"
    command.small_icon = command.large_icon = File.join(VGD::BIM::ROOT, 'assets', 'icons', icon)
    toolbar.add_item(command)
  end
  toolbar.restore
  file_loaded(__FILE__)
end
