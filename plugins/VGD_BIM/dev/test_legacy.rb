# Test lõi của VGD BIM (schema, hình học, báo cáo, cửa sổ) chạy bằng Ruby thường, ngoài SketchUp.
# Thay cho check_ruby.cjs (Ruby WASM). Chạy từ plugins/VGD_BIM: ruby dev/test_legacy.rb
require 'json'
require 'tmpdir'
DEV = __dir__
LIB = File.expand_path('../runtime/vgd_bim_lite', DEV)
def run(path); eval(File.read(path, encoding: 'UTF-8'), TOPLEVEL_BINDING, path); end

run File.join(DEV, 'fixture.rb')
run File.join(LIB, 'core/locale.rb')
VGD::BIM::Locale.instance_variable_set(:@dictionary, JSON.parse(File.read(File.join(LIB, 'config/vi.json'), encoding: 'UTF-8')))
%w[core/schema core/data core/validator intake/mapping_rules intake/detector intake/converter].each { |f| run File.join(LIB, "#{f}.rb") }
run File.join(DEV, 'test_core.rb')

run File.join(DEV, 'geometry_fixture.rb')
%w[core/geometry core/scanner intake/raw_scanner intake/mapping].each { |f| run File.join(LIB, "#{f}.rb") }
run File.join(DEV, 'test_geometry.rb')

run File.join(LIB, 'core/report_exporter.rb')
run File.join(DEV, 'test_reports.rb')

# Cửa sổ: nạp phần khai báo của loader (không mở menu) rồi chạy test điều hướng.
ENV['VGD_BIM_DATA_DIR'] ||= Dir.mktmpdir('vgd_bim_legacy')
run File.join(DEV, 'dialog_fixture.rb')
module Sketchup; def self.status_text=(_text); end; end # API thật của SketchUp, dialog.rb dùng khi quét
%w[core/storage core/tags core/table ui/bounds_preview ui/dialog].each { |f| run File.join(LIB, "#{f}.rb") }
loader = File.read(File.join(LIB, 'loader.rb'), encoding: 'UTF-8').split("\nVGD::BIM::FILES.each").first
eval(loader.gsub(/^require(?:_relative)? .*\r?\n/, ''), TOPLEVEL_BINDING, 'loader_head')
VGD::BIM.const_set(:VERSION, '0.0.0-test') unless VGD::BIM.const_defined?(:VERSION)
VGD::BIM.instance_variable_set(:@presets, [])
run File.join(DEV, 'test_dialog.rb')
