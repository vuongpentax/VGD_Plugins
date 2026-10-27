require 'sketchup.rb'
require 'extensions.rb'

module VGD_Cabinet_Draw
  unless file_loaded?(__FILE__)
    extension = SketchupExtension.new('VGD_Cabinet Draw', 'VGD_Cabinet_Draw/main')
    extension.description = 'Dựng tủ bán tự động bằng thao tác trực tiếp trong viewport SketchUp.'
    extension.version = '1.0.0-beta.52'
    extension.creator = 'VGD'
    extension.copyright = 'VGD 2026'
    Sketchup.register_extension(extension, true)
    file_loaded(__FILE__)
  end
end
