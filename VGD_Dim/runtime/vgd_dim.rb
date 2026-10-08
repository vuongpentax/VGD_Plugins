# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'
require_relative 'VGD_Dim/version'
require_relative 'VGD_Dim/update_core/manifest'
require_relative 'VGD_Dim/update_core/bootstrap'
unless VGD::Dim::UpdateCore::Bootstrap.recover
  raise 'VGD Dim updater recovery did not complete; extension was not loaded.'
end
module VGD
  module Dim
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('VGD Dim', 'VGD_Dim/main')
      extension.description = 'Smart Dim cho tủ, chỉnh Dim/Text/Label được chọn và áp mẫu Model Info.'
      extension.version = VERSION
      extension.creator = 'VGD'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
