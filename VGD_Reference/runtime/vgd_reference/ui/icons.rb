require 'json'

module VGD
  module Reference
    module Icons
      module_function

      ASSET_ROOT = File.expand_path('../assets/toolbar', __dir__).freeze

      def toolbar_theme
        value = Sketchup.read_default('VGD.Reference', 'ToolbarTheme', 'light')
        %w[light dark].include?(value) ? value : 'light'
      end

      def bind(command)
        @command = command
        apply
      end

      def set_toolbar_theme(value)
        raise ArgumentError, 'Invalid toolbar icon theme.' unless %w[light dark].include?(value)
        Sketchup.write_default('VGD.Reference', 'ToolbarTheme', value)
        apply
        value
      end

      def apply
        return unless @command
        @command.small_icon = @command.large_icon = toolbar_path
        UI.refresh_toolbars if UI.respond_to?(:refresh_toolbars)
      end

      def toolbar_path(theme = nil)
        # SketchUp's Command API accepts a single icon path. Use the light
        # toolbar in SU 2024 unless a host/integrator explicitly selects dark.
        theme ||= toolbar_theme
        theme = 'light' unless %w[light dark].include?(theme)
        manifest = JSON.parse(File.read(File.join(ASSET_ROOT, 'icon_manifest.json')))
        filename = manifest.fetch('icons').fetch('reference').fetch('files').fetch(theme)
        File.join(ASSET_ROOT, filename)
      rescue StandardError
        File.join(ASSET_ROOT, 'vgd_reference.svg')
      end
    end
  end
end
