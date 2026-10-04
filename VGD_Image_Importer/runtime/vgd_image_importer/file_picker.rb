# encoding: UTF-8
# Unicode Windows Explorer dialog with native Ctrl/Shift/marquee multiselect.
module VGD_ImageImporter
  module FilePicker
    extend self

    def parse_result(bytes)
      parts = bytes.force_encoding('UTF-16LE').encode('UTF-8').split("\0").take_while { |part| !part.empty? }
      return [] if parts.empty?
      return [parts.first] if parts.length == 1
      directory = parts.shift
      parts.map { |name| File.join(directory, name) }
    end

    def choose(directory, extensions)
      unless Sketchup.platform == :platform_win
        path = UI.openpanel('VGD · Chọn ảnh', directory, 'Ảnh|' + extensions.map { |ext| "*#{ext}" }.join(';') + '||')
        return path ? [path] : []
      end
      require 'fiddle'
      raise 'Hộp thoại nhiều ảnh cần SketchUp Windows 64-bit.' unless Fiddle::SIZEOF_VOIDP == 8
      common = Fiddle.dlopen('comdlg32.dll')
      user = Fiddle.dlopen('user32.dll')
      open_dialog = Fiddle::Function.new(common['GetOpenFileNameW'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT)
      extended_error = Fiddle::Function.new(common['CommDlgExtendedError'], [], Fiddle::TYPE_INT)
      foreground = Fiddle::Function.new(user['GetForegroundWindow'], [], Fiddle::TYPE_VOIDP)
      filter = "Ảnh phổ thông\0#{extensions.map { |ext| "*#{ext}" }.join(';')}\0Tất cả file\0*.*\0\0".encode('UTF-16LE')
      title = "VGD · Chọn ảnh — Ctrl / Shift để chọn nhiều ảnh\0".encode('UTF-16LE')
      initial = "#{directory}\0".encode('UTF-16LE')
      # OPENFILENAMEW, Windows x64 ABI, 152 bytes. Retain every pointed-to string
      # and allocated buffer until the synchronous native call completes.
      capacity = 262_144
      buffer = Fiddle::Pointer.malloc(capacity * 2, Fiddle::RUBY_FREE)
      buffer[0, capacity * 2] = "\0" * (capacity * 2)
      structure = Fiddle::Pointer.malloc(152, Fiddle::RUBY_FREE)
      structure[0, 152] = "\0" * 152
      structure[0, 4] = [152].pack('L<')
      structure[8, 8] = [foreground.call.to_i].pack('Q<')
      structure[24, 8] = [Fiddle::Pointer[filter].to_i].pack('Q<')
      structure[44, 4] = [1].pack('L<')
      structure[48, 8] = [buffer.to_i].pack('Q<')
      structure[56, 4] = [capacity].pack('L<')
      structure[80, 8] = [Fiddle::Pointer[initial].to_i].pack('Q<')
      structure[88, 8] = [Fiddle::Pointer[title].to_i].pack('Q<')
      # EXPLORER | ALLOWMULTISELECT | PATHMUSTEXIST | FILEMUSTEXIST |
      # NOCHANGEDIR | ENABLESIZING | DONTADDTORECENT.
      structure[96, 4] = [0x02881A08].pack('L<')
      if open_dialog.call(structure) == 0
        code = extended_error.call
        return [] if code == 0 # Cancel leaves the current queue unchanged.
        raise "Không mở được hộp thoại chọn ảnh (Windows code #{code})."
      end
      parse_result(buffer[0, capacity * 2])
    end
  end
end
