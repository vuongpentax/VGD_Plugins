# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

# Keep the original namespace and extension path for in-place upgrades.
module VGD_ImageImporter
  VERSION = '1.1.0-beta.2'.freeze unless const_defined?(:VERSION)
  unless file_loaded?(__FILE__)
    extension = SketchupExtension.new('VGD Image Importer', 'vgd_image_importer/main')
    extension.description = 'Bộ VGD · Nhập ảnh 2D, ảnh nằm phẳng và vật liệu theo đúng tỉ lệ.'
    extension.version = VERSION
    extension.creator = 'VGD'
    extension.copyright = 'VGD © 2026'
    Sketchup.register_extension(extension, true)
    file_loaded(__FILE__)
  end
end
