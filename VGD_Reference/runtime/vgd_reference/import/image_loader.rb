module VGD
  module Reference
    module ImageLoader
      module_function

      def supported_path?(path, allow_bitmap = false)
        ext = File.extname(path.to_s).downcase
        FILE_EXTENSIONS.include?(ext) || (allow_bitmap && ext == '.bmp')
      end

      def load(path, allow_bitmap: false)
        source = File.expand_path(path.to_s)
        raise ArgumentError, 'Không thể tải ảnh tham chiếu.' unless File.file?(source)
        image = Sketchup::ImageRep.new
        image.load_file(source)
        unless image.width.to_i.positive? && image.height.to_i.positive?
          raise ArgumentError, 'Không thể tải ảnh tham chiếu.'
        end
        raise ArgumentError, 'Ảnh vượt giới hạn 32 triệu pixel.' if image.width.to_i * image.height.to_i > MAX_IMAGE_PIXELS
        [image, image.width.to_i, image.height.to_i]
      rescue ArgumentError
        raise
      rescue StandardError => error
        log_error('Image load failed', error)
        raise ArgumentError, 'Không thể tải ảnh tham chiếu.'
      end

      def log_error(message, error)
        if defined?(Sketchup) && Sketchup.respond_to?(:debug_mode?) && Sketchup.debug_mode?
          puts("[VGD Reference] #{message}: #{error.class}: #{error.message}")
        end
      end
    end
  end
end
