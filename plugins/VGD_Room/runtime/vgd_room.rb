require 'sketchup.rb'
require 'extensions.rb'
module VGD
  module Room
    VERSION = '0.1.0-beta.1'.freeze
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('VGD Room', 'vgd_room/main')
      extension.description = 'Dựng khối 3D của phòng từ dữ liệu phòng của VGD_BIM (VGD_BIM điều khiển, không có giao diện riêng).'
      extension.version = VERSION
      extension.creator = 'VGD'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
