# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'
require_relative 'vgd_diagram/version'
module VGD
  module Diagram
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('VGD Diagram', 'vgd_diagram/main')
      extension.description = 'Sơ đồ cây lắp ráp: cấu kiện, số lượng và thứ tự lắp của đối tượng.'
      extension.version = VERSION
      extension.creator = 'VGD'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
