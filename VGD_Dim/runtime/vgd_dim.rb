# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'
module VGD
  module Dim
    VERSION = '2.3.0-beta.1'.freeze unless const_defined?(:VERSION)
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('VGD Dimension & Text Manager', 'VGD_Dim/main')
      extension.description = 'Áp mẫu font/cỡ chữ từ Model Info cho Dim/Text đang chọn trên Windows (English); màu, endpoint và tag 000 DIM / 000 TEXT. Không thông báo hoàn tất.'
      extension.version = VERSION
      extension.creator = 'VGD'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
