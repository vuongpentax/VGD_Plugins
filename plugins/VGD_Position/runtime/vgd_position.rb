require 'sketchup.rb'
require 'extensions.rb'
module VGD
  module Position
    VERSION = '0.1.0-beta.2'.freeze
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('VGD Position', 'vgd_position/loader')
      extension.description = 'Dời món (group, component) tới tọa độ X, Y, Z (mm) của trục thế giới.'
      extension.version = VERSION
      extension.creator = 'VGD'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
