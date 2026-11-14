require 'json'
require 'fileutils'

module VGD
  module BIM
    # Lưu cài đặt của người dùng (bộ tag, preset cột, trạng thái bảng) thành file JSON trên máy.
    # Không dùng Sketchup.write_default cho dữ liệu JSON: chuỗi có dấu ngoặc kép và chữ có dấu
    # có thể bị hỏng khi SketchUp đọc lại, làm preset vừa lưu bị mất.
    # Thư mục: %APPDATA%\VGD\VGD_BIM (Windows) hoặc ~/VGD/VGD_BIM (máy khác).
    module Storage
      def self.dir
        override = ENV['VGD_BIM_DATA_DIR']
        return override unless override.nil? || override.empty?
        base = ENV['APPDATA']
        base = Dir.home if base.nil? || base.empty?
        File.join(base, 'VGD', 'VGD_BIM')
      end

      def self.path(name)
        File.join(dir, "#{name}.json")
      end

      # Đọc file JSON. Chưa có file thì đọc dữ liệu cũ trong SketchUp (nếu có) để không mất cài đặt cũ.
      def self.read(name, legacy_section = nil, legacy_key = nil)
        file = path(name)
        return JSON.parse(File.read(file, encoding: 'bom|utf-8')) if File.exist?(file)
        return nil unless legacy_section && defined?(Sketchup) && Sketchup.respond_to?(:read_default)
        raw = Sketchup.read_default(legacy_section, legacy_key, nil)
        raw.is_a?(String) && !raw.empty? ? JSON.parse(raw) : nil
      rescue JSON::ParserError => error
        BIM.log("Storage #{name} invalid: #{error.message}")
        nil
      end

      def self.write(name, data)
        FileUtils.mkdir_p(dir)
        file = path(name)
        temp = "#{file}.tmp"
        File.open(temp, 'wb') { |f| f.write(JSON.pretty_generate(data)) }
        File.delete(file) if File.exist?(file)
        File.rename(temp, file)
        data
      end
    end
  end
end
