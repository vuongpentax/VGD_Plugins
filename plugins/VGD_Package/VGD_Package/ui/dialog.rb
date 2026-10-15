# frozen_string_literal: true

module VGD
  module Pack
    module UI
      extend self

      def show
        return unless Compatibility.supported?
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
          return
        end
        @dialog = ::UI::HtmlDialog.new(
          dialog_title: 'VGD_Package', preferences_key: 'VGD_Package_Main',
          scrollable: true, resizable: true, width: 900, height: 640,
          min_width: 720, min_height: 480, style: ::UI::HtmlDialog::STYLE_DIALOG
        )
        @dialog.set_file(File.join(ROOT, 'ui', 'dialog.html'))
        @dialog.add_action_callback('scan') { |_context| scan_project }
        @dialog.add_action_callback('inspectEnscape') { |_context| inspect_enscape }
        @dialog.add_action_callback('close') { |_context| @dialog.close }
        @dialog.show
      rescue StandardError => e
        ::UI.messagebox("VGD_Package không thể mở giao diện.\n#{e.message}")
      end

      def scan_project
        model = Sketchup.active_model
        data = Scanner.new.report(model)
        @dialog.execute_script("window.VGDPack.showScan(#{JSON.generate(data)})")
      rescue StandardError => e
        show_error(e)
      end

      def inspect_enscape
        model = Sketchup.active_model
        path = ::UI.savepanel('Xuất báo cáo kiểm tra Enscape (chỉ đọc)', model.path.to_s.empty? ? nil : File.dirname(model.path),
                              'VGD_Package_Enscape_Research.json')
        return unless path
        data = Research::EnscapeInspector.inspect(model)
        File.open(path, 'wb') { |file| file.write(JSON.pretty_generate(data).encode('UTF-8')) }
        @dialog.execute_script("window.VGDPack.showResearch(#{JSON.generate({ 'path' => path, 'entries' => data['dictionary_entries'] })})")
      rescue StandardError => e
        show_error(e)
      end

      private

      def show_error(error)
        message = error.message.to_s.gsub('\\', '\\\\').gsub("'", "\\'").gsub("\n", '\\n')
        @dialog.execute_script("window.VGDPack.showError('#{message}')") if @dialog
      rescue StandardError
        ::UI.messagebox("VGD_Package: #{error.message}")
      end
    end
  end
end
