require 'sketchup.rb'
require 'extensions.rb'
module VGD
  module Structure
    VERSION = '0.30.0-beta.5'.freeze
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('VGD Structure', 'vgd_structure/loader')
      extension.description = 'Dựng phần thô (cột, dầm, tường, sàn, trần) theo lưới trục và tầng, nối với VGD BIM để tính khối lượng.'
      extension.version = VERSION
      extension.creator = 'VGD'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
