# encoding: UTF-8
# Test giữ hành vi cho Compatibility, Asset, Scanner (giả lập SketchUp; chạy từ plugins/VGD_Package: ruby test/test_scan.rb).
require 'tmpdir'
require 'json'
require 'digest'
require 'time'
$LOADED_FEATURES << 'sketchup.rb'
$sketchup_version = '24.0.0'
module Sketchup
  def self.version; $sketchup_version; end
  class Material
    def texture; end
    def normal_texture; end
  end
  class Texture
    def filename; end
    def write(*); end
  end
end
module VGD; module Pack; PLUGIN_VERSION = 'test'; end; end
%w[compatibility asset adapters/sketchup_texture adapters/sketchup_pbr scanner].each do |f|
  require File.expand_path("../vgd_package/#{f}", __dir__)
end
$pass = 0; $fail = []
def check(name, cond); cond ? ($pass += 1) : ($fail << name); puts "#{cond ? 'OK  ' : 'FAIL'} #{name}"; end
C = VGD::Pack::Compatibility

check 'phiên bản 24.x → năm 2024', C.year_version == 2024 && C.major_version == 2024
$sketchup_version = '2022.0.1'
check 'phiên bản 2022 được hỗ trợ', C.supported? && C.year_version == 2022
$sketchup_version = '21.1.0'
check 'SketchUp 2021 không được hỗ trợ', !C.supported?
$sketchup_version = '24.0.0'

caps = C.capabilities(nil)
check 'capabilities không model: đủ khóa', caps.keys == %w[sketchup_version sketchup_year supported native_texture native_pbr_api pbr_channels enscape]
check 'capabilities: native_texture đúng', caps['native_texture'] == true
check 'capabilities: kênh PBR theo method có sẵn', caps['pbr_channels'] == %w[normal_texture] && caps['native_pbr_api'] == true
bad_model = Object.new
def bad_model.materials; raise 'hỏng'; end
caps2 = C.capabilities(bad_model)
check 'model lỗi: native_pbr_api false, các khóa khác giữ nguyên', caps2['native_pbr_api'] == false &&
  caps2['pbr_channels'] == caps['pbr_channels'] && caps2['supported'] == true && caps2['enscape'] == 'read_only_inspection'
check 'pbr_channels(nil) rỗng', C.pbr_channels(nil) == []
check 'pbr_channels theo material', C.pbr_channels(Sketchup::Material.new) == %w[normal_texture]

Tex = Struct.new(:filename) { def write(*); end; def valid?; true; end }
Dir.mktmpdir do |dir|
  path = File.join(dir, 'a.png'); File.binwrite(path, 'abc')
  a = VGD::Pack::Asset.new(material_name: 'M', channel: 'diffuse', texture: Tex.new(path), source_type: 'sketchup')
  check 'Asset OK: kích thước và SHA-256', a.status == 'OK' && a.filesize == 3 && a.sha256 == Digest::SHA256.hexdigest('abc') && a.filename == 'a.png'
  b = VGD::Pack::Asset.new(material_name: 'M', channel: 'diffuse', texture: Tex.new(File.join(dir, 'none.png')), source_type: 'sketchup')
  check 'Asset thiếu file nhưng xuất được: EMBEDDED', b.status == 'EMBEDDED' && b.filesize.nil?
  c = VGD::Pack::Asset.new(material_name: 'M', channel: 'diffuse', texture: nil, source_type: 'sketchup')
  check 'Asset không texture: MISSING', c.status == 'MISSING' && c.filename == ''
  check 'Asset#to_h đủ khóa', a.to_h.keys == %w[material_name channel current_path status source_type filename filesize sha256 exportable error]

  mat = Struct.new(:name, :texture, :normal_texture, :roughness_texture).new('Gỗ', Tex.new(path), Tex.new(File.join(dir, 'n.png')), nil)
  model = Struct.new(:materials, :path).new([mat], 'x.skp')
  report = VGD::Pack::Scanner.new.report(model)
  check 'Scanner: định dạng và phiên bản', report['format'] == 'VGD_PACK_SCAN' && report['plugin_version'] == 'test' && report['model'] == 'x.skp'
  check 'Scanner: diffuse + normal (roughness nil bị bỏ qua)', report['assets'].map { |x| x['channel'] } == %w[diffuse normal]
  check 'Scanner: tổng hợp trạng thái', report['summary'] == { 'OK' => 1, 'EMBEDDED' => 1 }
  boom = Struct.new(:name) { def texture; raise 'lỗi API'; end }.new('Hỏng')
  r = VGD::Pack::Adapters::SketchUpTexture.scan(boom)
  check 'Adapter texture lỗi API: UNKNOWN kèm thông báo', r.size == 1 && r[0].status == 'UNKNOWN' && r[0].error == 'lỗi API'
end
puts $fail.empty? ? "TẤT CẢ ĐẠT (#{$pass})" : "LỖI: #{$fail.join('; ')}"
exit($fail.empty? ? 0 : 1)
