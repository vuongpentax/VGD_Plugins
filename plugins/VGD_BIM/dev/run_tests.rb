# Chạy toàn bộ test Ruby của VGD BIM bằng Ruby thường, ngoài SketchUp (mô phỏng, không thay SketchUp).
# Từ plugins/VGD_BIM: ruby dev/run_tests.rb
# Gồm: kiểm tra cú pháp mọi file Ruby, rồi từng test_*.rb trong một tiến trình riêng với thư mục dữ liệu tạm.
require 'tmpdir'
require 'rbconfig'

DEV = __dir__
RUNTIME = File.expand_path('../runtime', DEV)
TESTS = %w[bim table build dialog_logic loader_menu load preview overlay rename tags tags_io settings images capture image_actions preset columns table_report front front_probe front_actions front_align measure tag_rules tag_auto tag_catalog folder_rules tag_folders tag_tree tag_excel row_order photo_settings quantity custom_columns vgd_id object_code levels rooms material_library check_rules].freeze
failed = []

puts "Ruby #{RUBY_VERSION}"
syntax = Dir[File.join(RUNTIME, '**', '*.rb')].sort
syntax.each do |file|
  RubyVM::InstructionSequence.compile_file(file)
rescue ScriptError => error
  failed << "cú pháp #{file}: #{error.message.lines.first}"
end
puts "Cú pháp: #{syntax.size - failed.size}/#{syntax.size} file đạt"

TESTS.each do |name|
  Dir.mktmpdir('vgd_bim_test') do |data_dir|
    output = IO.popen({ 'VGD_BIM_DATA_DIR' => data_dir }, [RbConfig.ruby, File.join(DEV, "test_#{name}.rb")], err: %i[child out], &:read)
    output.force_encoding('UTF-8')
    ok = $?.success? && output !~ /^FAIL\b/ && output !~ /Error\b/
    failed << "test_#{name}.rb" unless ok
    puts "#{ok ? 'ĐẠT' : 'LỖI'}  test_#{name}.rb"
    puts output.lines.select { |l| l =~ /^FAIL|Error/ }.join unless ok
  end
end

puts failed.empty? ? "\nTẤT CẢ ĐẠT" : "\nCÓ LỖI:\n#{failed.map { |f| "  - #{f}" }.join("\n")}"
exit(failed.empty? ? 0 : 1)
