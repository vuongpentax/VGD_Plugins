# encoding: UTF-8
# Danh sách file mã của plugin, theo thứ tự nạp (main nạp cuối). Là MỘT nơi duy nhất: main.rb dùng lúc mở SketchUp,
# reload.rb dùng khi "Tải lại code". Thêm file mới thì thêm ở đây và ở dev/package.py.
module VGD
  module Diagram
    CODE_FILES = %w[version tree model_io scene ffmpeg dialog main].freeze unless const_defined?(:CODE_FILES, false)
  end
end
