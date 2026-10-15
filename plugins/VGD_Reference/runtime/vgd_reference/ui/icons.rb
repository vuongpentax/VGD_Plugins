module VGD
  module Reference
    module Icons
      module_function

      ASSET_ROOT = File.expand_path('../assets/toolbar', __dir__).freeze

      def bind(command)
        @command = command
        apply
      end

      def apply
        return unless @command
        @command.small_icon = @command.large_icon = toolbar_path
        UI.refresh_toolbars if UI.respond_to?(:refresh_toolbars)
      end

      def toolbar_path
        # The toolbar glyph stays the same regardless of the manager light/dark theme.
        File.join(ASSET_ROOT, 'vgd_reference.svg')
      rescue StandardError
        File.join(ASSET_ROOT, 'vgd_reference.svg')
      end
    end
  end
end
