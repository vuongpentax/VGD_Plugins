# encoding: UTF-8
require 'sketchup.rb'
# Preflight before closing the old UI. Reload only this extension.
files = %w[defaults engine native_style main].map { |name| File.join(__dir__, name + '.rb') }
files.each { |path| RubyVM::InstructionSequence.compile_file(path) }
if defined?(VGD::Dim)
  VGD::Dim::NativeStyle.cancel if defined?(VGD::Dim::NativeStyle)
  dialog = VGD::Dim.instance_variable_get(:@dialog)
  dialog.close if dialog
  VGD::Dim::ProfileService.shutdown if defined?(VGD::Dim::ProfileService)
  VGD::Dim.detach_model if VGD::Dim.respond_to?(:detach_model)
  timer = VGD::Dim.instance_variable_get(:@sync_timer)
  UI.stop_timer(timer) if timer
  watch = VGD::Dim.instance_variable_get(:@app_watch)
  Sketchup.remove_observer(watch) if watch
  VGD::Dim.instance_variable_set(:@app_watch, nil)
  VGD::Dim.instance_variable_set(:@sync_timer, nil)
  %i[DEFAULTS VERSION].each do |name|
    VGD::Dim.send(:remove_const, name) if VGD::Dim.const_defined?(name, false)
  end
  VGD::Dim.const_set(:VERSION, '2.3.0-beta.1'.freeze)
end
files.each { |path| load path }
VGD::Dim.show_dialog
