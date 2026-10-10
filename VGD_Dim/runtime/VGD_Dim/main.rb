# encoding: UTF-8
require 'sketchup.rb'
require 'json'
require 'securerandom'
require_relative 'version'
require_relative 'defaults'
require_relative 'engine'
require_relative 'native_style'
require_relative 'store'
require_relative 'managed'
require_relative 'core'
require_relative 'presets'
require_relative 'autostyle'
require_relative 'animation'
require_relative 'smartdim'
require_relative 'regions'
require_relative 'manual_dim'
require_relative 'probe'
require_relative 'dialog'
require_relative 'update_core/manifest'
require_relative 'update_core/client'
require_relative 'update_core/installer'
require_relative 'update_core/updater'
module VGD
  module Dim
    extend self
    def show_dialog; Dialog.show; end
    def show_error(message)
      Dialog.send_js('onError',{'message'=>message})
      Sketchup.status_text=message unless Dialog.visible?
    end
    def open_model_info(page)
      raise "Không mở được Model Info → #{page}." unless UI.show_model_info(page)
    rescue StandardError => error
      show_error(error.message)
    end
    def reload_extension; load File.join(__dir__,'reload.rb'); end
    def quick_smart
      saved = SmartDim.saved
      result = SmartDim.execute(saved['opts'],saved['settings'])
      Dialog.send_js('onSmart',result)
      Sketchup.status_text = "VGD Dim: #{result['total']} Dim, #{result['replaced']} bộ được thay. " + result['warnings'].join(' ')
      result
    rescue StandardError => error
      show_error(error.message)
      nil
    end
    unless @command
      @command=UI::Command.new('VGD Dim') { show_dialog }
      @command.small_icon=@command.large_icon=File.join(__dir__,'dim.svg')
      UI.menu('Extensions').add_item(@command) unless file_loaded?(__FILE__)
      @toolbar ||= UI::Toolbar.new('VGD Dim')
      @toolbar.add_item(@command)
      UI.menu('Extensions').add_item('Hiện toolbar VGD Dim') { @toolbar.show }
      UI.menu('Extensions').add_item('Nạp lại VGD Dim') { reload_extension }
      file_loaded(__FILE__)
    end
    @command.tooltip='VGD Dim'
    @command.status_bar_text='Smart Dim, Dim/Text/Label, Model Info, preset và Animation.'
    unless @smart_command
      @smart_command = UI::Command.new('Smart Dim một chạm') { quick_smart }
      @smart_command.small_icon = @smart_command.large_icon = File.join(__dir__,'smart_dim.svg')
      @smart_command.tooltip = 'Smart Dim — dùng thiết lập đã lưu'
      @smart_command.status_bar_text = 'Chọn tủ rồi đo ngay; cập nhật bộ Dim cùng tủ/mặt/Scene.'
      @toolbar.add_item(@smart_command)
      UI.menu('Extensions').add_item(@smart_command)
    end
    AutoStyle.start
    UpdateCore::UIHooks.start
  end
end
