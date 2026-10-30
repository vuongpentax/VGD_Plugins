# encoding: UTF-8
# Giả lập SketchUp tối thiểu để chạy thử build_bundle trên Linux.
require 'tmpdir'
require 'fileutils'

stub_dir = File.join(__dir__, 'stub')
$LOAD_PATH.unshift(stub_dir)

build = File.expand_path(ARGV[0])
fake = Dir.mktmpdir('fake_appdata')
ENV['APPDATA'] = fake
ENV['TEMP'] = Dir.tmpdir

plug = File.join(fake, 'SketchUp/SketchUp 2022/SketchUp/Plugins')
FileUtils.mkdir_p(File.join(plug, 'cool_tool/lib/sub'))
File.write(File.join(plug, 'cool_tool.rb'), "puts 'tool'\n# tiếng Việt\n" * 200)
File.write(File.join(plug, 'cool_tool/lib/sub/x.rb'), "x=1\n" * 50)
File.binwrite(File.join(plug, 'cool_tool/data.bin'), (0..255).to_a.pack('C*') * 40)
File.write(File.join(plug, 'single.rb'), "puts 1\n")
File.write(File.join(plug, 'su_sandbox.rb'), "skip\n")
FileUtils.mkdir_p(File.join(fake, 'SketchUp/SketchUp 2024/SketchUp/Plugins'))

require File.join(build, 'vgd_plugin_migrator/main')

M = VGD::PluginMigrator
puts "versions: #{M.installed_versions.inspect}"
puts "plugins: #{M.list_plugins('2022').map { |p| p[:name] }.inspect}"

out = File.join(Dir.tmpdir, 'test_bundle.rbz')
FileUtils.rm_f(out)
r = M.build_bundle('2022', %w[cool_tool single], true, true, out)
puts "result: #{r.inspect}"
puts "html ok: #{M.build_dialog_html(M.list_plugins('2022'), '2022', '2024').include?('exportBundle')}"
puts "OUT=#{out}"
puts "FAKE=#{fake}"
