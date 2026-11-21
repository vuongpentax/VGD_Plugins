require 'sketchup.rb'
require 'extensions.rb'
module VGD
  module Position
    VERSION = '0.1.0-beta.3'.freeze
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('VGD Position', 'vgd_position/loader')
      extension.description = 'Dời, xoay, scale món (group, component) theo trục thế giới, nhập theo đơn vị của file.'
      extension.version = VERSION
      extension.creator = 'VGD'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
