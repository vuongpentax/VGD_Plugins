# frozen_string_literal: true

require 'sketchup.rb'
require 'json'
require 'fileutils'
require 'digest'
require 'time'

# Menu Extensions > VGD dùng chung: mọi plugin VGD lấy cùng một menu (SketchUp không gộp các menu trùng tên).
module VGD
  def self.menu
    @extensions_menu ||= ::UI.menu('Extensions').add_submenu('VGD')
  end unless respond_to?(:menu)
end

module VGD
  module Pack
    PLUGIN_VERSION = '0.1.5'.freeze unless const_defined?(:PLUGIN_VERSION)
    ROOT = File.dirname(__FILE__.dup.force_encoding(Encoding::UTF_8)).freeze unless const_defined?(:ROOT)

    require File.join(ROOT, 'compatibility')
    require File.join(ROOT, 'asset')
    require File.join(ROOT, 'adapters', 'sketchup_texture')
    require File.join(ROOT, 'adapters', 'sketchup_pbr')
    require File.join(ROOT, 'scanner')
    require File.join(ROOT, 'research', 'enscape_inspector')
    require File.join(ROOT, 'ui', 'dialog')

    unless file_loaded?(__FILE__)
      unless Compatibility.supported?
        ::UI.messagebox('VGD Package cần SketchUp 2022 trở lên.')
      else
        ::VGD.menu.add_submenu('VGD Package').add_item('Mở VGD Package') { UI.show }
      end
      file_loaded(__FILE__)
    end
  end
end
