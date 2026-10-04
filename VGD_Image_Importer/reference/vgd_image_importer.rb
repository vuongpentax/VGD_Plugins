require 'sketchup.rb'
require 'extensions.rb'

module VGD_ImageImporter
  unless file_loaded?(__FILE__)
    loader = File.join(__dir__, 'vgd_image_importer', 'main.rb')
    extension = SketchupExtension.new('VGD Image Importer', loader)
    extension.description = 'Import hàng loạt ảnh 2D/Texture vào SketchUp chuẩn tỉ lệ.'
    extension.version     = '1.0.0'
    extension.copyright   = 'VGD © 2026'
    extension.creator     = 'VGD'
    Sketchup.register_extension(extension, true)
    file_loaded(__FILE__)
  end
end
