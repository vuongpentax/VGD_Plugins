# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module VGD
  module Center
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('VGD Center', 'VGD_Center/main')
      extension.creator = 'VGD'
      extension.version = '1.0.7'
      extension.description = 'Cài đặt và cập nhật các plugin VGD trong SketchUp.'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
