# encoding: UTF-8
require 'json'
require 'digest'
require 'uri'
require 'base64'

module VGD
  module Library
    module Catalog
      SECTION = 'VGD_Library'.freeze
      EXTENSIONS = %w[.jpg .jpeg .png .bmp .tif .tiff .skm .skp].freeze
      LIMIT = 20_000
      PREF_PREFIX = 'vgd-json2:'.freeze

      def self.read_json(key, fallback)
        encoded = Sketchup.read_default(SECTION, 'json2_' + key, nil)
        if encoded
          raise 'Cấu hình VGD không đúng định dạng.' unless encoded.is_a?(String) && encoded.start_with?(PREF_PREFIX)
          return JSON.parse(Base64.strict_decode64(encoded[PREF_PREFIX.size..-1]).force_encoding(Encoding::UTF_8))
        end
        return fallback if @pref_errors && @pref_errors[key]
        # SU2022 stores quoted Ruby literals in PrivatePreferences.json. Reading
        # old JSON via read_default can eval an unescaped quote and raise
        # SyntaxError. Recover the literal as JSON data, never as Ruby code.
        raw = legacy_raw(key)
        raw = Sketchup.read_default(SECTION, key, nil) if raw.nil?
        value = raw.nil? ? fallback : decode_legacy(raw)
        save(key, value)
        value
      rescue StandardError, SyntaxError => e
        (@pref_errors ||= {})[key] = true
        puts "[VGD_Library] Không đọc được cấu hình #{key}: #{e.class}. Dùng giá trị mặc định." unless (@pref_reported ||= {})[key]
        @pref_reported[key] = true
        fallback
      end

      def self.legacy_raw(key)
        return nil unless Sketchup.platform == :platform_win && ENV['LOCALAPPDATA']
        year = Sketchup.version.to_i + 2000
        path = File.join(ENV['LOCALAPPDATA'], 'SketchUp', "SketchUp #{year}", 'SketchUp', 'PrivatePreferences.json')
        return nil unless File.file?(path)
        data = JSON.parse(File.read(path, encoding: 'UTF-8').sub(/\A\uFEFF/, ''))
        section = data.fetch('This Computer Only', {}).fetch(SECTION, {})
        section.is_a?(Hash) ? section[key] : nil
      rescue SystemCallError, JSON::ParserError, TypeError
        nil
      end

      def self.decode_legacy(raw)
        return raw unless raw.is_a?(String)
        3.times do
          begin
            value = JSON.parse(raw)
          rescue JSON::ParserError
            raise unless raw.start_with?('"') && raw.end_with?('"')
            raw = raw[1...-1]
            next
          end
          return value unless value.is_a?(String) && value.lstrip.start_with?('[', '{', '"')
          raw = value
        end
        raise JSON::ParserError, 'Cấu hình cũ không phải JSON hợp lệ.'
      end

      def self.roots
        data = read_json('folders', [])
        data.is_a?(Array) ? data.select { |v| v.is_a?(String) }.uniq : []
      end

      def self.favorites
        data = read_json('favorites', [])
        data.is_a?(Array) ? data.select { |v| v.is_a?(String) }.uniq : []
      end

      def self.save(key, value)
        encoded = PREF_PREFIX + Base64.strict_encode64(JSON.generate(value).encode(Encoding::UTF_8))
        raise 'Không lưu được cấu hình VGD.' unless Sketchup.write_default(SECTION, 'json2_' + key, encoded)
      end

      def self.add_folder(path)
        raise 'Thư mục không tồn tại.' unless File.directory?(path)
        path = File.realpath(path)
        save('folders', (roots + [path]).uniq)
      end

      def self.remove_folder(path)
        save('folders', roots.reject { |root| root == path })
      end

      def self.file_url(path)
        normalized = File.expand_path(path).tr('\\', '/')
        prefix = normalized.start_with?('//') ? 'file:' : (normalized.start_with?('/') ? 'file://' : 'file:///')
        prefix + URI::DEFAULT_PARSER.escape(normalized, /[^a-zA-Z0-9\-._~:\/]/)
      end

      def self.item(path, root)
        extension = File.extname(path).downcase
        relative = path.tr('\\', '/').sub(root.tr('\\', '/') + '/', '')
        category = File.dirname(relative)
        category = 'Chưa phân nhóm' if category == '.'
        preview = %w[.skm .skp].include?(extension) ? nil : path
        if %w[.skm .skp].include?(extension)
          stem = path[0...-4]
          preview = %w[.png .jpg .jpeg].map { |ext| stem + ext }.find { |p| File.file?(p) }
        end
        { id: Digest::SHA256.hexdigest(path), name: File.basename(path, File.extname(path)),
          path: path, root: root, category: category, format: extension.delete('.').upcase,
          kind: extension == '.skp' ? 'model' : 'material',
          preview: preview ? file_url(preview) : nil }
      end

      # Enumerator is consumed in small timer batches by the dialog.
      def self.scan
        Enumerator.new do |output|
          seen = {}
          visited = {}
          roots.each do |root|
            archives = 0
            unless File.directory?(root)
              output << { warning: "Không thấy thư mục: #{root}" }
              next
            end
            stack = [root]
            until stack.empty? || seen.size >= LIMIT
              path = stack.pop
              begin
                if File.directory?(path)
                  next if path != root && (File.symlink?(path) || File.basename(path).start_with?('.'))
                  canonical = File.realpath(path)
                  next if visited[canonical]
                  visited[canonical] = true
                  Dir.children(path).sort.reverse_each { |name| stack << File.join(path, name) }
                  output << nil
                elsif File.file?(path) && !File.symlink?(path) && EXTENSIONS.include?(File.extname(path).downcase) && !seen[path]
                  seen[path] = true
                  output << item(path, root)
                  if seen.size >= LIMIT
                    output << { warning: "Đạt giới hạn #{LIMIT} mẫu. Chọn thư mục nhỏ hơn để xem đủ." }
                  end
                elsif File.file?(path) && %w[.rar .zip .7z].include?(File.extname(path).downcase)
                  archives += 1
                  output << nil
                else
                  output << nil
                end
              rescue SystemCallError => e
                output << { warning: "Không đọc được #{path}: #{e.message}" }
              end
            end
            output << { warning: "#{File.basename(root)}: #{archives} tệp RAR/ZIP/7Z chưa giải nén, chưa đưa vào thư viện." } if archives > 0
            break if seen.size >= LIMIT
          end
        end
      end
    end
  end
end
