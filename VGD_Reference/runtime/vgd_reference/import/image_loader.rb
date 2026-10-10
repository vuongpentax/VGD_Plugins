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
        raise ArgumentError, 'Unable to load reference image.' unless File.file?(source)
        raise ArgumentError, 'Only JPG and PNG images are supported.' unless supported_path?(source, allow_bitmap)

        image = Sketchup::ImageRep.new
        image.load_file(source)
        unless image.width.to_i.positive? && image.height.to_i.positive?
          raise ArgumentError, 'Unable to load reference image.'
        end
        [image, image.width.to_i, image.height.to_i]
      rescue ArgumentError
        raise
      rescue StandardError => error
        log_error('Image load failed', error)
        raise ArgumentError, 'Unable to load reference image.'
      end

      def log_error(message, error)
        if defined?(Sketchup) && Sketchup.respond_to?(:debug_mode?) && Sketchup.debug_mode?
          puts("[VGD Reference] #{message}: #{error.class}: #{error.message}")
        end
      end
    end
  end
end
