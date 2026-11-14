# Chạy test Ruby của VGD_Room bằng Ruby thường (mô phỏng SketchUp, không thay SketchUp). Từ plugins/VGD_Room: ruby dev/run_tests.rb
require 'rbconfig'
DEV = __dir__
RUNTIME = File.expand_path('../runtime', DEV)
failed = []
syntax = Dir[File.join(RUNTIME, '**', '*.rb')].sort
syntax.each do |file|
  RubyVM::InstructionSequence.compile_file(file)
rescue ScriptError => error
  failed << "cú pháp #{file}: #{error.message.lines.first}"
end
puts "Cú pháp: #{syntax.size - failed.size}/#{syntax.size} file đạt"
%w[builder].each do |name|
  output = IO.popen([RbConfig.ruby, File.join(DEV, "test_#{name}.rb")], err: %i[child out], &:read).force_encoding('UTF-8')
  ok = $?.success? && output !~ /^FAIL\b/
  failed << "test_#{name}.rb" unless ok
  puts "#{ok ? 'ĐẠT' : 'LỖI'}  test_#{name}.rb"
  puts output.lines.select { |l| l =~ /^FAIL|Error/ }.join unless ok
end
puts failed.empty? ? "\nTẤT CẢ ĐẠT" : "\nCÓ LỖI:\n#{failed.map { |f| "  - #{f}" }.join("\n")}"
exit(failed.empty? ? 0 : 1)
