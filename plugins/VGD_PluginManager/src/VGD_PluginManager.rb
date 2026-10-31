# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module VGD
  module PluginManager
    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new('VGD Plugin Manager', 'VGD_PluginManager/main')
      ex.description = 'Bật/tắt plugin theo bộ, chuyển plugin giữa các phiên bản SketchUp, xuất gói .rbz tổng.'
      ex.version     = '1.0.0-beta.17'
      ex.creator     = 'VGD'
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end
  end
end
