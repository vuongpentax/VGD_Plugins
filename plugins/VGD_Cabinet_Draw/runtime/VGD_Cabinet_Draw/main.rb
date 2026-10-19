require 'sketchup.rb'
require 'json'
require 'securerandom'
require_relative 'schema'
require_relative 'model_data'
require_relative 'geometry'
require_relative 'door_geometry'
require_relative 'preview'
require_relative 'tools'
require_relative 'preset_store'
require_relative 'dialog'

module VGD_Cabinet_Draw
  VERSION = '1.0.0-beta.1' unless const_defined?(:VERSION, false)
  extend self

  def start
    return if @started
    @started = true
    command = UI::Command.new('VGD Cabinet Draw') { Dialog.show }
    command.tooltip = 'VGD Cabinet Draw — Dựng tủ bán tự động'
    command.status_bar_text = 'Chuyển box thành thùng tủ và dựng chi tiết trực tiếp trong model.'
    command.menu_text = 'VGD Cabinet Draw'
    icon_path = File.expand_path('../../icon.svg', __dir__.dup.force_encoding(Encoding::UTF_8))
    command.small_icon = icon_path if File.file?(icon_path)
    command.large_icon = icon_path if File.file?(icon_path)
    UI.menu('Extensions').add_item(command)
    toolbar = UI::Toolbar.new('VGD Cabinet Draw')
    toolbar.add_item(command)
    toolbar.restore if toolbar.get_last_state == TB_HIDDEN
    toolbar.show
    @toolbar = toolbar
  end

  def launch_tool(name, settings = {})
    tool = Tools.build(name, settings)
    @active_tool=tool
    Sketchup.active_model.select_tool(tool)
    Dialog.set_status("Đang dùng: #{Tools.label(name)}. Enter áp dụng · Esc hủy.")
  rescue StandardError => e
    UI.messagebox("Không thể mở công cụ: #{e.message}")
  end

  def update_active_settings(settings)
    @active_tool.update_settings(settings) if @active_tool && @active_tool.respond_to?(:update_settings)
  end

  unless file_loaded?(__FILE__)
    start
    file_loaded(__FILE__)
  end
end
