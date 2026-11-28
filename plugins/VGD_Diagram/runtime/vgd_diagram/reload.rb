# encoding: UTF-8
require 'sketchup.rb'
dir = __dir__.dup.force_encoding(Encoding::UTF_8)
files = %w[version tree model_io scene ffmpeg dialog main].map { |name| File.join(dir, name + '.rb') }
# Kiểm tra cú pháp cả bộ file trước: lỗi ở đây thì không file nào được nạp.
files.each { |path| RubyVM::InstructionSequence.compile_file(path) }
reopen = defined?(VGD::Diagram::Dialog) && VGD::Diagram::Dialog.visible?
VGD::Diagram::Dialog.close if defined?(VGD::Diagram::Dialog)
# Bỏ hằng số cũ để nạp lại đúng giá trị mới (tránh cảnh báo khi định nghĩa lại).
VGD::Diagram.send(:remove_const, :VERSION) if VGD::Diagram.const_defined?(:VERSION, false)
[VGD::Diagram::Tree, VGD::Diagram::ModelIO, VGD::Diagram::Scene, VGD::Diagram::Dialog, VGD::Diagram::Ffmpeg].each do |mod|
  mod.constants(false).each { |name| mod.send(:remove_const, name) }
end
files[0..-2].each { |path| load path }
load files.last # main: không đăng ký lại menu, toolbar (có cờ @registered)
VGD::Diagram.show_dialog if reopen
