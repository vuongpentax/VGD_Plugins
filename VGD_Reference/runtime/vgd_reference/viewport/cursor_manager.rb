module VGD
  module Reference
    module CursorManager
      FILES = {
        move: ['move.svg', 16, 16],
        resize_nw_se: ['resize_nw_se.svg', 16, 16],
        resize_ne_sw: ['resize_ne_sw.svg', 16, 16],
        crop: ['crop.svg', 6, 6]
      }.freeze

      module_function

      def cursor(name)
        definition = FILES[name.to_sym]
        return nil unless definition && Sketchup.platform == :platform_win
        cursors[name.to_sym] ||= begin
          filename, hot_x, hot_y = definition
          path = File.join(__dir__, '..', 'assets', 'cursors', filename)
          UI.create_cursor(File.expand_path(path), hot_x, hot_y)
        end
      rescue StandardError => error
        ImageLoader.log_error('Cursor creation failed', error)
        nil
      end

      def cursors
        @cursors ||= {}
      end
      private_class_method :cursors
    end
  end
end
