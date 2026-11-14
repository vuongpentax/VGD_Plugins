# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'
require_relative 'vgd_dim/version'
module VGD
  module Dim
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('VGD Dim', 'vgd_dim/main')
      extension.description = 'Smart Dim cho tủ, chỉnh Dim/Text/Label được chọn và áp mẫu Model Info.'
      extension.version = VERSION
      extension.creator = 'VGD'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
