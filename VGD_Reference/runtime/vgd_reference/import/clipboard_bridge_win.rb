require 'fiddle/import'

module VGD
  module Reference
    module ClipboardBridgeWin
      CF_DIB = 8
      CF_DIBV5 = 17

      if defined?(Sketchup) && Sketchup.platform == :platform_win
        module Native
          extend Fiddle::Importer
          dlload 'user32.dll', 'kernel32.dll'
          extern 'int OpenClipboard(void*)'
          extern 'int CloseClipboard()'
          extern 'unsigned int RegisterClipboardFormatW(void*)'
          extern 'void* GetClipboardData(unsigned int)'
          extern 'size_t GlobalSize(void*)'
          extern 'void* GlobalLock(void*)'
          extern 'int GlobalUnlock(void*)'
        end
      end

      module_function

      def read_image
        return nil unless Sketchup.platform == :platform_win
        raise 'Clipboard is busy.' unless Native.OpenClipboard(0) != 0
        begin
          png = read_registered_png
          return [png, '.png', 'clipboard.png'] if png
          dib = read_format(CF_DIBV5)
          dib ||= read_format(CF_DIB)
          return nil unless dib
          [dib_to_bmp(dib), '.bmp', 'clipboard.bmp']
        ensure
          Native.CloseClipboard
        end
      rescue StandardError => error
        ImageLoader.log_error('Clipboard read failed', error)
        nil
      end

      def read_registered_png
        format_name = Fiddle::Pointer["PNG\0".encode('UTF-16LE')]
        format = Native.RegisterClipboardFormatW(format_name)
        return nil if format.to_i.zero?
        read_format(format)
      end

      def read_format(format)
        handle = Native.GetClipboardData(format)
        return nil if handle.to_i.zero?
        size = Native.GlobalSize(handle).to_i
        return nil if size <= 0 || size > 512 * 1024 * 1024
        pointer = Native.GlobalLock(handle)
        return nil if pointer.to_i.zero?
        begin
          Fiddle::Pointer.new(pointer.to_i)[0, size]
        ensure
          Native.GlobalUnlock(handle)
        end
      end

      def dib_to_bmp(dib)
        raise ArgumentError, 'Invalid clipboard bitmap.' if dib.bytesize < 40
        header_size = dib.unpack1('V')
        raise ArgumentError, 'Invalid clipboard bitmap.' unless [40, 52, 56, 108, 124].include?(header_size)
        width, height, planes, bit_count, compression, image_size, = dib.byteslice(4, 28).unpack('l<l<S<S<VV V V'.delete(' '))
        raise ArgumentError, 'Invalid clipboard bitmap.' unless width.positive? && height != 0 && planes == 1
        raise ArgumentError, 'Unsupported clipboard bitmap.' unless [1, 4, 8, 16, 24, 32].include?(bit_count)
        raise ArgumentError, 'Unsupported clipboard bitmap.' unless [0, 3, 6].include?(compression)
        colors_used = dib.byteslice(32, 4).unpack1('V')
        extra_masks = header_size == 40 && compression == 3 ? 12 : 0
        extra_masks = 16 if header_size == 40 && compression == 6
        palette_entries = bit_count <= 8 ? (colors_used.positive? ? colors_used : (1 << bit_count)) : 0
        pixel_offset = 14 + header_size + extra_masks + palette_entries * 4
        file_size = 14 + dib.bytesize
        file_header = 'BM'.b + [file_size, 0, 0, pixel_offset].pack('VvvV')
        file_header + dib
      end
    end
  end
end
