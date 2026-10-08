# encoding: UTF-8
require 'json'
require 'base64'
module VGD
  module Dim
    module Store
      SECTION = 'VGDDim'.freeze unless const_defined?(:SECTION, false)
      PREFIX = 'vgd-dim-json2:'.freeze unless const_defined?(:PREFIX, false)

      def self.read(key, fallback=nil)
        encoded = Sketchup.read_default(SECTION, 'json2_' + key, nil)
        if encoded
          raise ArgumentError, 'Cấu hình VGD Dim không đúng định dạng.' unless encoded.is_a?(String) && encoded.start_with?(PREFIX)
          return JSON.parse(Base64.strict_decode64(encoded[PREFIX.size..-1]).force_encoding(Encoding::UTF_8))
        end
        raw = legacy_raw(key)
        if raw.nil?
          raw = Sketchup.read_default(SECTION, key, nil)
          return fallback if raw.nil?
          value = JSON.parse(raw)
        else
          value = decode_legacy(raw)
        end
        write(key, value)
        value
      rescue StandardError, SyntaxError => error
        unless (@reported ||= {})[key]
          puts "[VGD Dim] Không đọc được cấu hình #{key}: #{error.class}. Dùng giá trị mặc định."
          @reported[key] = true
        end
        fallback
      end

      # SU2022 stores strings as quoted Ruby literals. Its read_default can
      # evaluate unescaped JSON quotes and fail before JSON.parse is reached.
      # Read only this extension's legacy data, without evaluating the literal.
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
        raise TypeError, 'Cấu hình cũ phải là chuỗi JSON.' unless raw.is_a?(String)
        if raw.start_with?('"') && raw.end_with?('"')
          begin
            # Original SU2022 unescaped quoted literal.
            return JSON.parse(raw[1...-1])
          rescue JSON::ParserError
            # Also accept a correctly escaped native quoted literal.
            decoded = JSON.parse(raw)
            return JSON.parse(decoded) if decoded.is_a?(String)
          end
        end
        JSON.parse(raw)
      end

      def self.write(key,value)
        encoded = PREFIX + Base64.strict_encode64(JSON.generate(value).encode(Encoding::UTF_8))
        raise 'Không lưu được cấu hình VGD Dim.' unless Sketchup.write_default(SECTION, 'json2_' + key, encoded)
        true
      end
    end
  end
end
