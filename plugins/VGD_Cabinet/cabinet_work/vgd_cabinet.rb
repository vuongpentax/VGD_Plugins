require 'sketchup.rb'
require 'extensions.rb'

module VGD_Cabinet
  unless file_loaded?(__FILE__)
    ex = SketchupExtension.new('VGD Cabinet', 'vgd_cabinet/main43')
    ex.description = 'Dựng hình tủ gỗ công nghiệp theo logic kết cấu sản xuất cho SketchUp 2022/2024.'
    ex.version     = '4.5.4-beta.3'
    ex.copyright   = 'VGD_CABINET Team 2026'
    ex.creator     = 'VGD_CABINET'
    Sketchup.register_extension(ex, true)
    file_loaded(__FILE__)
  end
end
