# Chạy toàn bộ test của VGD Position: cú pháp mọi file Ruby, rồi từng test_*.rb trong một tiến trình riêng.
# Chạy từ plugins/VGD_Position: ruby dev/run_tests.rb
require 'rbconfig'
ROOT = File.expand_path('..', __dir__)
RUNTIME = File.join(ROOT, 'runtime')
DEV = __dir__
TESTS = %w[units position move reload].freeze
failed = []
syntax = Dir[File.join(RUNTIME, '**', '*.rb')].sort
syntax.each do |file|
  RubyVM::InstructionSequence.compile_file(file)
rescue ScriptError => error
  failed << "cú pháp #{file}: #{error.message.lines.first}"
end
puts "Cú pháp: #{syntax.size - failed.size}/#{syntax.size} file đạt"
TESTS.each do |name|
  output = IO.popen([RbConfig.ruby, File.join(DEV, "test_#{name}.rb")], err: %i[child out], &:read)
  ok = $?.success?
  failed << "test_#{name}.rb" unless ok
  puts "#{ok ? 'ĐẠT' : 'LỖI'}  test_#{name}.rb"
  puts output unless ok
end
puts failed.empty? ? 'TẤT CẢ ĐẠT' : "CÓ LỖI:\n  - #{failed.join("\n  - ")}"
exit(failed.empty? ? 0 : 1)
