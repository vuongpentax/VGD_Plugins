require 'sketchup.rb'
require 'extensions.rb'
require_relative 'vgd_reference/core/constants'
require_relative 'vgd_reference/core/compatibility'

module VGDReference
  unless file_loaded?(__FILE__)
    extension = SketchupExtension.new(
      'VGD Reference',
      File.join(__dir__, 'vgd_reference', 'main')
    )
    extension.creator = 'VGD'
    extension.description = 'Hiển thị và chỉnh sửa ảnh tham chiếu ngay trên khung nhìn SketchUp.'
    extension.version = '1.0.0-beta.6'
    extension.copyright = '2026 VGD'
    Sketchup.register_extension(extension, VGD::Reference::Compatibility.supported?)
    file_loaded(__FILE__)
  end
end
