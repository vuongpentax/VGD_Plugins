require 'rbconfig'

module VGD
  module BIM
    # Nút dán ảnh "bấm Ctrl+V thay người dùng": gửi phím Ctrl+V của Windows (keybd_event) tới cửa sổ đang được chọn. Cửa sổ BIM đang có
    # tiêu điểm vì người dùng vừa bấm nút trong đó, nên SketchUp / trình duyệt nhúng xử lý như người dùng nhấn Ctrl+V thật
    # (sự kiện paste, không cần quyền). Chỉ gửi khi cửa sổ đang chọn thuộc chính tiến trình SketchUp (không gửi phím vào ứng dụng khác).
    # Dùng Fiddle (có sẵn trong Ruby của SketchUp); không có hoặc lỗi thì báo lỗi để giao diện chuyển sang cách khác. Chỉ Windows.
    module PasteKeys
      VK_CONTROL = 0x11
      VK_V = 0x56
      VK_UNASSIGNED = 0xE8 # phím không gán: Windows coi Alt đã đi kèm một phím khác nên không mở thanh menu khi thả Alt
      KEYUP = 0x02

      def self.windows?
        RbConfig::CONFIG['host_os'].to_s.match?(/mswin|mingw|cygwin/i)
      end

      # sender: lambda(thứ_tự_phím) để test thay bản giả; mặc định gọi Win32.
      def self.press_ctrl_v(sender: nil)
        unless sender
          raise 'Gửi phím Ctrl+V chỉ có trên Windows.' unless windows?
          sender = method(:send_win32)
        end
        sender.call([[VK_CONTROL, 0], [VK_V, 0], [VK_V, KEYUP], [VK_CONTROL, KEYUP]])
        true
      end

      # Gọi khi người dùng đang giữ Alt cho một việc khác (công cụ hút / đổ tag): gửi thêm một phím không gán để Windows không mở thanh menu
      # của SketchUp khi thả Alt (Windows chỉ mở menu nếu Alt được nhấn rồi thả mà không có phím nào xen giữa). Không phải Windows hoặc
      # lỗi thì trả false, không ném lỗi.
      def self.cancel_alt_menu(sender: nil)
        return false unless sender || windows?
        (sender || method(:send_win32)).call([[VK_UNASSIGNED, 0], [VK_UNASSIGNED, KEYUP]])
        true
      rescue StandardError => error
        BIM.log("Không chặn được thanh menu khi nhấn Alt: #{error.message}")
        false
      end

      def self.send_win32(keys)
        require 'fiddle'
        user32 = Fiddle.dlopen('user32')
        foreground = Fiddle::Function.new(user32['GetForegroundWindow'], [], Fiddle::TYPE_UINTPTR_T)
        thread_process = Fiddle::Function.new(user32['GetWindowThreadProcessId'], [Fiddle::TYPE_UINTPTR_T, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT)
        buffer = Fiddle::Pointer.malloc(4)
        thread_process.call(foreground.call, buffer)
        owner = buffer[0, 4].unpack1('L')
        raise 'Cửa sổ đang chọn không thuộc SketchUp, không gửi phím.' unless owner == Process.pid
        keybd = Fiddle::Function.new(user32['keybd_event'], [Fiddle::TYPE_CHAR, Fiddle::TYPE_CHAR, Fiddle::TYPE_INT, Fiddle::TYPE_UINTPTR_T], Fiddle::TYPE_VOID)
        keys.each { |code, flags| keybd.call(code, 0, flags, 0) }
      rescue LoadError, StandardError => error
        raise error.message.start_with?('Cửa sổ') ? error.message : "Không gửi được phím Ctrl+V: #{error.message}"
      end
    end
  end
end
