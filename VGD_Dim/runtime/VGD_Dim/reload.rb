# encoding: UTF-8
require 'sketchup.rb'
files = %w[version defaults engine native_style store managed core presets autostyle animation smartdim regions manual_dim probe dialog update_core/manifest update_core/client update_core/installer update_core/updater main].map do |name|
  File.join(__dir__, name + '.rb')
end
files.each { |path| RubyVM::InstructionSequence.compile_file(path) }
if defined?(VGD::Dim)
  VGD::Dim::NativeStyle.cancel if defined?(VGD::Dim::NativeStyle)
  VGD::Dim::AutoStyle.shutdown if defined?(VGD::Dim::AutoStyle)
  VGD::Dim::Dialog.close if defined?(VGD::Dim::Dialog)
  VGD::Dim::UpdateCore::UIHooks.shutdown if defined?(VGD::Dim::UpdateCore::UIHooks) && VGD::Dim::UpdateCore::UIHooks.respond_to?(:shutdown)
  %i[DEFAULTS VERSION].each { |name| VGD::Dim.send(:remove_const, name) if VGD::Dim.const_defined?(name, false) }
  VGD::Dim::Presets.send(:remove_const, :BUILTIN) if defined?(VGD::Dim::Presets::BUILTIN)
  VGD::Dim::Core.send(:remove_const, :STYLE) if defined?(VGD::Dim::Core::STYLE)
  %i[DEFAULTS SIDES VERTICAL].each { |name| VGD::Dim::SmartDim.send(:remove_const, name) if VGD::Dim::SmartDim.const_defined?(name, false) }
end
files[0] && load(files[0])
files[1..-2].each { |path| load path }
load files.last
VGD::Dim.show_dialog
