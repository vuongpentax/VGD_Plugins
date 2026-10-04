require 'sketchup.rb'
require 'json'
require_relative 'store'
require_relative 'core'
require_relative 'presets'
require_relative 'autostyle'
require_relative 'animation'
require_relative 'smartdim'
require_relative 'probe'
require_relative 'dialog'

module VGD
  module Dim
    unless file_loaded?(__FILE__)
      menu = UI.menu('Extensions').add_submenu('VGD Dim')
      menu.add_item('Open VGD Dim')            { Dialog.show }
      menu.add_item('Smart Dim (tủ đang chọn)') do
        begin
          st = AutoStyle.load['settings'] || Presets::BUILTIN['VGD Standard']
          r = SmartDim.run(Store.read('smartdim', {}), st)
          puts "VGD Smart Dim: #{r['total']} dim, mặt #{r['face']}"
        rescue StandardError => e
          UI.messagebox(e.message)
        end
      end
      menu.add_item('Probe API')                { Probe.run }
      AutoStyle.start
      file_loaded(__FILE__)
    end
  end
end
