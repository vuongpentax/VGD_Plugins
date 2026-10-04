# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'
module VGD
  module Dim
    VERSION = '3.0.0-beta.1'.freeze unless const_defined?(:VERSION)
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('VGD Dim', 'VGD_Dim/main')
      extension.description = 'Smart Dim cho tủ, chỉnh Dim/Text/Label được chọn và áp mẫu Model Info. Dim native, tag 000 DIM / 000 TEXT, không thông báo hoàn tất.'
      extension.version = VERSION
      extension.creator = 'VGD'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
