# VGD Dim - loader
require 'sketchup.rb'
require 'extensions.rb'

module VGD
  module Dim
    PLUGIN_ID = 'VGD_Dim'.freeze
    VERSION   = '0.4.0'.freeze

    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new('VGD Dim', 'VGD_Dim/main')
      ex.version     = VERSION
      ex.creator     = 'VGD'
      ex.copyright   = 'VGD'
      ex.description = 'Scan va chuan hoa Dimension / Text / Label trong SketchUp.'
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end
  end
end
