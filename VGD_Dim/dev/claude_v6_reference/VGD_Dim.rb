# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module VGD
  module Dim
    VERSION = '3.2.0'.freeze unless const_defined?(:VERSION, false)

    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new('VGD Dim', 'VGD_Dim/main')
      ex.version     = VERSION
      ex.creator     = 'VGD'
      ex.copyright   = 'VGD'
      ex.description = 'Smart Dim, chuẩn hóa Dimension/Text/Label, font/size theo Model Info, preset và Animation.'
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end
  end
end
