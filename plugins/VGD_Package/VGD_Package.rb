# frozen_string_literal: true

require 'sketchup.rb'
require 'extensions.rb'

module VGD
  module Pack
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('VGD_Package', 'VGD_Package/vgd_pack')
      extension.description = 'Inspect and scan portable SketchUp project textures.'
      extension.version = '0.1.3'
      extension.creator = 'VGD'
      extension.copyright = '2026 VGD'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
