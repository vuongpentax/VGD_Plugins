# encoding: UTF-8
require 'sketchup.rb'
require 'json'
require_relative 'engine'
require_relative 'native_style'
require_relative 'store'
require_relative 'core'
require_relative 'presets'
require_relative 'autostyle'
require_relative 'animation'
require_relative 'smartdim'
require_relative 'dialog'
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
    unless file_loaded?(__FILE__)
      command=UI::Command.new('VGD Dim') { show_dialog }
      command.small_icon=command.large_icon=File.join(__dir__,'dim.svg')
      command.tooltip='VGD Dim'
      command.status_bar_text='Smart Dim, font/size theo Model Info, màu/mũi tên, preset và Animation.'
      UI.menu('Extensions').add_item(command)
      toolbar=UI::Toolbar.new('VGD Dim')
      toolbar.add_item(command)
      UI.menu('Extensions').add_item('Hiện toolbar VGD Dim') { toolbar.show }
      AutoStyle.start
      file_loaded(__FILE__)
    end
  end
end
