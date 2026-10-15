# frozen_string_literal: true

require 'sketchup.rb'
require 'json'
require 'fileutils'
require 'digest'
require 'time'

module VGD
  module Pack
    PLUGIN_VERSION = '0.1.3'.freeze unless const_defined?(:PLUGIN_VERSION)
    ROOT = File.dirname(__FILE__).freeze unless const_defined?(:ROOT)

    require File.join(ROOT, 'compatibility')
    require File.join(ROOT, 'asset')
    require File.join(ROOT, 'adapters', 'sketchup_texture')
    require File.join(ROOT, 'adapters', 'sketchup_pbr')
    require File.join(ROOT, 'scanner')
    require File.join(ROOT, 'research', 'enscape_inspector')
    require File.join(ROOT, 'ui', 'dialog')

    unless file_loaded?(__FILE__)
      unless Compatibility.supported?
        ::UI.messagebox('VGD_Package cần SketchUp 2022 trở lên.')
      else
        ::UI.menu('Extensions').add_submenu('VGD').add_item('VGD_Package') { UI.show }
      end
      file_loaded(__FILE__)
    end
  end
end
