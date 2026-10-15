# frozen_string_literal: true

module VGD
  module Pack
    class Asset
      attr_reader :material_name, :channel, :current_path, :status, :source_type,
                  :filename, :filesize, :sha256, :exportable, :error

      def initialize(material_name:, channel:, texture:, source_type:)
        @material_name = material_name.to_s
        @channel = channel.to_s
        @source_type = source_type.to_s
        @texture = texture
        @current_path = safe_filename(texture)
        @filename = @current_path.to_s.empty? ? '' : File.basename(@current_path)
        @filesize = file_exists? ? File.size(@current_path) : nil
        @sha256 = file_exists? ? Digest::SHA256.file(@current_path).hexdigest : nil
        @exportable = texture.respond_to?(:write)
        @status = if file_exists?
                    'OK'
                  elsif @exportable && safe_valid_texture?
                    'EMBEDDED'
                  else
                    'MISSING'
                  end
      rescue StandardError => e
        @status = 'UNKNOWN'
        @error = e.message
      end

      def to_h
        {
          'material_name' => material_name,
          'channel' => channel,
          'current_path' => current_path,
          'status' => status,
          'source_type' => source_type,
          'filename' => filename,
          'filesize' => filesize,
          'sha256' => sha256,
          'exportable' => exportable,
          'error' => error
        }
      end

      private

      def safe_filename(texture)
        texture && texture.respond_to?(:filename) ? texture.filename.to_s : ''
      rescue StandardError
        ''
      end

      def file_exists?
        !current_path.to_s.empty? && File.file?(current_path)
      rescue StandardError
        false
      end

      def safe_valid_texture?
        !@texture.respond_to?(:valid?) || @texture.valid?
      rescue StandardError
        false
      end
    end
  end
end
