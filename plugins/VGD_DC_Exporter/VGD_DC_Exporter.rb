require 'sketchup.rb'
require 'extensions.rb'

module VGD_DC_Exporter
  unless file_loaded?(__FILE__)
    extension = SketchupExtension.new('VGD DC Exporter', 'VGD_DC_Exporter/main')
    extension.description = 'Xuất thuộc tính, công thức DC và cấu trúc component đang chọn thành JSON. Chỉ đọc mô hình.'
    extension.version = '1.0.1'
    extension.creator = 'VGD'
    extension.copyright = 'VGD 2026'
    Sketchup.register_extension(extension, true)
    file_loaded(__FILE__)
  end
end
