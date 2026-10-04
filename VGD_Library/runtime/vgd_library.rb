# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module VGD
  module Library
    VERSION = '1.1.1-beta.1'.freeze
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('VGD_Library', 'vgd_library/main')
      extension.description = 'Thư viện vật liệu/model, kho Drive đồng bộ và bộ công cụ map VGD.'
      extension.version = VERSION
      extension.creator = 'VGD'
      extension.copyright = 'VGD 2026'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
