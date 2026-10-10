module VGD
  module Reference
    module ImageFormats
      module_function

      MIME = {
        '.jpg' => 'image/jpeg', '.jpeg' => 'image/jpeg', '.jfif' => 'image/jpeg', '.jpe' => 'image/jpeg',
        '.png' => 'image/png', '.apng' => 'image/png', '.bmp' => 'image/bmp', '.dib' => 'image/bmp',
        '.webp' => 'image/webp', '.gif' => 'image/gif', '.avif' => 'image/avif',
        '.ico' => 'image/x-icon', '.cur' => 'image/x-icon', '.svg' => 'image/svg+xml',
        '.tif' => 'image/tiff', '.tiff' => 'image/tiff', '.heic' => 'image/heic', '.heif' => 'image/heif',
        '.jp2' => 'image/jp2', '.j2k' => 'image/jp2', '.jxr' => 'image/jxr', '.wdp' => 'image/jxr',
        '.hdp' => 'image/jxr', '.tga' => 'image/x-tga'
      }.freeze

      def mime(name, bytes = nil, declared = nil)
        if bytes
          return 'image/png' if bytes.start_with?("\x89PNG\r\n\x1a\n".b)
          return 'image/jpeg' if bytes.start_with?("\xFF\xD8\xFF".b)
          return 'image/gif' if bytes.start_with?('GIF87a', 'GIF89a')
          return 'image/webp' if bytes.start_with?('RIFF') && bytes.byteslice(8, 4) == 'WEBP'
          return 'image/bmp' if bytes.start_with?('BM')
          return 'image/tiff' if bytes.start_with?("II\x2A\x00".b, "MM\x00\x2A".b)
          if bytes.byteslice(4, 4) == 'ftyp'
            brands = bytes.byteslice(8, 40).to_s
            return 'image/avif' if brands.include?('avif') || brands.include?('avis')
            return 'image/heic' if brands.match?(/heic|heix|hevc|hevx/)
            return 'image/heif' if brands.include?('mif1')
          end
          return 'image/svg+xml' if bytes.byteslice(0, 2048).to_s.match?(/<svg[\s>]/i)
        end
        known = MIME[File.extname(name.to_s).downcase]
        return known if known
        value = declared.to_s.split(';').first.to_s.downcase
        value.match?(/\Aimage\/[a-z0-9.+-]+\z/) ? value : 'application/octet-stream'
      end

      def extension(mime)
        { 'image/png' => '.png', 'image/jpeg' => '.jpg', 'image/gif' => '.gif',
          'image/webp' => '.webp', 'image/avif' => '.avif', 'image/svg+xml' => '.svg',
          'image/heic' => '.heic', 'image/heif' => '.heif', 'image/tiff' => '.tif',
          'image/bmp' => '.bmp', 'image/x-icon' => '.ico', 'image/jp2' => '.jp2',
          'image/jxr' => '.jxr', 'image/x-tga' => '.tga' }.fetch(mime, '.img')
      end
    end
  end
end
