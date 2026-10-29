module VGD_Cabinet_Draw
  # Màu và font vẽ trong viewport SketchUp, theo token trong shared/VGD_UI_DESIGN_SYSTEM.md.
  # Dialog HTML báo chế độ sáng/tối qua callback 'theme'; chưa báo thì dùng chế độ sáng.
  module Theme
    SECTION = 'VGD_Cabinet_Draw'.freeze
    KEY = 'viewport_theme'.freeze
    MODES = %i[light dark].freeze
    PREFERRED_FONT = 'Manrope'.freeze
    FALLBACK_FONT = 'Segoe UI'.freeze

    TOKENS = {
      light: {
        bg: '#F7F7F5', surface: '#FFFFFF', elevated: '#F0EEE9', border: '#E5E5E5', text: '#222222', muted: '#6F6F6F',
        accent: '#B48963', accent_strong: '#8E6B4C', tint: '#F3ECE5', danger: '#A73D36', success: '#507247', on_accent: '#FFFFFF'
      },
      dark: {
        bg: '#121212', surface: '#1E1E1E', elevated: '#2B2B2B', border: '#3A3A3A', text: '#E2E8F0', muted: '#A7B0BD',
        accent: '#B48963', accent_strong: '#C8A98A', tint: '#372C24', danger: '#E79C91', success: '#A8C69D', on_accent: '#121212'
      }
    }.freeze

    module_function

    def mode
      @mode ||= begin
        saved = Sketchup.read_default(SECTION, KEY, 'light').to_s.to_sym
        MODES.include?(saved) ? saved : :light
      end
    end

    # Nhận :light / :dark (hoặc chuỗi); giá trị khác bị bỏ qua. Lưu lại để lần mở sau dùng ngay.
    def mode=(value)
      value = value.to_s.to_sym
      return unless MODES.include?(value)
      @mode = value
      Sketchup.write_default(SECTION, KEY, value.to_s)
    end

    def reset!
      @mode = nil
      @font_supported = nil
      Sketchup.write_default(SECTION, KEY, 'light')
    end

    def color(role, alpha = 255)
      hex = TOKENS[mode].fetch(role)
      Sketchup::Color.new(hex[1, 2].to_i(16), hex[3, 2].to_i(16), hex[5, 2].to_i(16), alpha)
    end

    # Manrope nếu đã cài trên Windows (hoặc thư mục font được truyền vào), không thì Segoe UI.
    def font_name(folder = nil)
      folders = folder ? [folder] : font_folders
      folders.any? { |dir| !Dir.glob(File.join(dir, 'Manrope*')).empty? } ? PREFERRED_FONT : FALLBACK_FONT
    end

    def font_folders
      [File.join(ENV['WINDIR'].to_s, 'Fonts'), File.join(ENV['LOCALAPPDATA'].to_s, 'Microsoft', 'Windows', 'Fonts')]
    end

    # View#draw_text kèm font VGD. Nếu bản SketchUp không nhận tuỳ chọn :font thì vẽ lại không có font
    # và nhớ để không thử lần nữa.
    def draw_text(view, point, text, options = {})
      return view.draw_text(point, text, options) if @font_supported == false
      @font ||= font_name
      view.draw_text(point, text, options.merge(font: @font))
      @font_supported = true
    rescue ArgumentError, TypeError
      @font_supported = false
      view.draw_text(point, text, options)
    end
  end
end
