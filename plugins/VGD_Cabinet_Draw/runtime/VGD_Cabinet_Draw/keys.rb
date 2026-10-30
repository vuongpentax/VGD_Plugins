# Mã phím và cờ phím bổ trợ.
# SketchUp KHÔNG định nghĩa VK_RETURN, VK_TAB, VK_ESCAPE, VK_BACKSPACE (đã kiểm tra trong Ruby Console),
# nên tự khai báo mã phím theo hệ điều hành. Mã trên Mac chưa kiểm chứng.
module VGD_Cabinet_Draw
  module Keys
    extend self

    WINDOWS = { backspace: 8, tab: 9, enter: 13, escape: 27, space: 32 }.freeze
    MAC = { backspace: 51, tab: 48, enter: 36, escape: 53, keypad_enter: 76, space: 49 }.freeze

    attr_writer :platform

    def windows?
      plat = @platform || (defined?(Sketchup) && Sketchup.respond_to?(:platform) ? Sketchup.platform : :platform_win)
      plat != :platform_osx
    end

    def table
      windows? ? WINDOWS : MAC
    end

    def tab?(key)
      key == table[:tab]
    end

    def space?(key)
      key == table[:space]
    end

    def backspace?(key)
      key == table[:backspace]
    end

    def escape?(key)
      key == table[:escape]
    end

    def enter?(key)
      key == table[:enter] || key == table[:keypad_enter]
    end

    # Phím chữ (A-Z). Trên Windows mã phím là mã ký tự in hoa. Mac chưa kiểm chứng nên trả false:
    # mọi lệnh bằng phím chữ đều có cách gõ tương đương vào ô VCB.
    def letter?(key, char)
      windows? && key == char.to_s.upcase.ord
    end

    ARROWS_WINDOWS = { left: 37, up: 38, right: 39, down: 40 }.freeze
    ARROWS_MAC = { left: 123, up: 126, right: 124, down: 125 }.freeze # Mã trên Mac chưa kiểm chứng

    # Phím mũi tên trong onKeyDown: :left, :up, :right, :down hoặc nil. Dùng hằng VK_* của SketchUp nếu có.
    def arrow(key)
      names = { left: :VK_LEFT, up: :VK_UP, right: :VK_RIGHT, down: :VK_DOWN }
      names.each do |dir, const|
        code = Object.const_defined?(const) ? Object.const_get(const) : (windows? ? ARROWS_WINDOWS : ARROWS_MAC)[dir]
        return dir if key == code
      end
      nil
    end

    # Shift (CONSTRAIN_MODIFIER_MASK) trong cờ của onLButtonDown / onKeyDown.
    def shift?(flags)
      defined?(CONSTRAIN_MODIFIER_MASK) ? (flags.to_i & CONSTRAIN_MODIFIER_MASK) != 0 : false
    end

    # Ctrl trên Windows, Option trên Mac (COPY_MODIFIER_MASK).
    def ctrl?(flags)
      defined?(COPY_MODIFIER_MASK) ? (flags.to_i & COPY_MODIFIER_MASK) != 0 : false
    end

    # Phím Ctrl (Option trên Mac) được nhấn: mã phím trong onKeyDown/onKeyUp.
    def ctrl_key?(key)
      code = defined?(COPY_MODIFIER_KEY) ? COPY_MODIFIER_KEY : (windows? ? 17 : 58)
      key == code
    end

    # Phím Alt (Command trên Mac) được nhấn: mã phím trong onKeyDown/onKeyUp.
    def alt_key?(key)
      code = defined?(ALT_MODIFIER_KEY) ? ALT_MODIFIER_KEY : (windows? ? 18 : 55)
      key == code
    end

    # Alt trên Windows, Command trên Mac (ALT_MODIFIER_MASK).
    def alt?(flags)
      defined?(ALT_MODIFIER_MASK) ? (flags.to_i & ALT_MODIFIER_MASK) != 0 : false
    end
  end
end
