require 'json'
require 'uri'

module VGD
  module Reference
    module Manager
      module_function

      def toggle
        if visible?
          @dialog.close
          false
        else
          open
          true
        end
      end

      def open
        Session.setup_for_model
        create_dialog unless @dialog && @dialog.visible?
        bind_callbacks unless @callbacks_bound
        @dialog.show
        refresh
        @dialog
      rescue StandardError => error
        ImageLoader.log_error('Manager open failed', error)
        UI.messagebox('Không thể mở bảng quản lý ảnh tham chiếu.')
        nil
      end

      def visible?
        !!(@dialog && @dialog.visible?)
      rescue StandardError
        false
      end

      def refresh
        return unless visible? && Session.store
        data = {
          items: Session.store.to_a.map { |item| item_payload(item) },
          selected_id: Session.store.selected_id,
          hidden_all: Session.store.hidden_all,
          opacity_min: OPACITY_MIN,
          toolbar_theme: Icons.toolbar_theme
        }
        @dialog.execute_script("window.VGDReference&&window.VGDReference.render(#{JSON.generate(data)})")
      rescue StandardError => error
        ImageLoader.log_error('Manager refresh failed', error)
      end

      def show_message(message)
        return unless visible?
        @dialog.execute_script("window.VGDReference&&window.VGDReference.message(#{JSON.generate(message.to_s)})")
      rescue StandardError
        nil
      end

      def item_payload(item)
        {
          id: item.id, name: item.display_name || File.basename(item.source_path),
          thumbnail: file_uri(item.source_path), visible: item.visible,
          locked: item.locked, opacity: item.opacity,
          selected: item.id == Session.store.selected_id,
          width: item.image_width, height: item.image_height
        }
      end

      def file_uri(path)
        normalized = File.expand_path(path.to_s).tr('\\', '/')
        encoded = normalized.split('/').map { |segment| URI::DEFAULT_PARSER.escape(segment) }.join('/')
        "file:///#{encoded}"
      end

      def ready?
        visible? && !!@ready
      end

      def decode_image(data)
        raise 'Bảng quản lý chưa sẵn sàng.' unless ready?
        @dialog.execute_script("window.VGDReference&&window.VGDReference.decodeImage(#{JSON.generate(data)})")
      end

      def import_status(busy, text)
        return unless visible?
        @dialog.execute_script("window.VGDReference&&window.VGDReference.importStatus(#{JSON.generate(!!busy)},#{JSON.generate(text.to_s)})")
      end

      def acknowledge(method, token, index, result)
        return unless ready?
        @dialog.execute_script("window.VGDReference&&window.VGDReference.ack(#{JSON.generate(method)},#{JSON.generate(token.to_s)},#{JSON.generate(index)},#{JSON.generate(!!result)})")
      end

      def create_dialog
        options = {
          dialog_title: 'VGD Reference | Ảnh tham chiếu', preferences_key: 'vgd.reference.manager',
          style: UI::HtmlDialog::STYLE_UTILITY, width: 310, height: 455,
          min_width: 280, min_height: 340, resizable: true
        }
        dialog = UI::HtmlDialog.new(options)
        dialog.set_file(File.join(__dir__, 'web', 'index.html'))
        dialog.set_on_closed do
          if @dialog.equal?(dialog)
            ImageImport.cancel_all
            @dialog = nil
            @ready = false
            @callbacks_bound = false
          end
        end
        @dialog = dialog
        @ready = false
        @callbacks_bound = false
      end
      private_class_method :create_dialog

      def bind_callbacks
        dialog = @dialog
        return unless dialog
        dialog.add_action_callback('ready') { |_context| @ready = true; refresh }
        dialog.add_action_callback('addImage') { |_context| Session.add_from_picker }
        dialog.add_action_callback('pasteImage') { |_context| Session.paste_reference }
        dialog.add_action_callback('setToolbarTheme') do |_context, theme|
          begin
            Icons.set_toolbar_theme(theme)
            refresh
          rescue StandardError => error
            ImageLoader.log_error('Toolbar icon theme update failed', error)
            show_message('Không thể đổi màu icon thanh công cụ.')
          end
        end
        dialog.add_action_callback('selectReference') { |_context, id| Session.select_reference(id) }
        dialog.add_action_callback('toggleVisible') do |_context, id|
          item = Session.store && Session.store.find(id)
          Session.set_visible(id, item ? !item.visible : true)
        end
        dialog.add_action_callback('toggleLock') { |_context, id| Session.toggle_lock(id) }
        dialog.add_action_callback('deleteReference') { |_context, id| Session.delete_reference(id) }
        dialog.add_action_callback('hideAll') { |_context| Session.toggle_hide_all }
        dialog.add_action_callback('startCrop') { |_context, id| Session.start_crop(id) }
        dialog.add_action_callback('opacityPreview') { |_context, id, value| Session.set_opacity(id, value, commit: false) }
        dialog.add_action_callback('commitOpacity') { |_context, id, value| Session.set_opacity(id, value, commit: true) }
        dialog.add_action_callback('editSelected') do |_context|
          Session.enter_edit(Session.store.selected_id) if Session.store && Session.store.selected_id
        end
        dialog.add_action_callback('dropStart') { |_context, token, name, size, chunks, mime| acknowledge('dropStart', token, nil, Session.drop_start(token, name, size, chunks, mime)) }
        dialog.add_action_callback('dropChunk') { |_context, token, index, chunk| acknowledge('dropChunk', token, index, Session.drop_chunk(token, index, chunk)) }
        dialog.add_action_callback('dropFinish') { |_context, token| acknowledge('dropFinish', token, nil, Session.drop_finish(token)) }
        dialog.add_action_callback('dropCancel') { |_context, token| Session.cancel_drop(token) }
        dialog.add_action_callback('dropUrl') { |_context, urls, name| ImageImport.add_urls(urls, name) }
        dialog.add_action_callback('convertedStart') { |_context, token, size, chunks| acknowledge('convertedStart', token, nil, ImageImport.conversion_start(token, size, chunks)) }
        dialog.add_action_callback('convertedChunk') { |_context, token, index, chunk| acknowledge('convertedChunk', token, index, ImageImport.conversion_chunk(token, index, chunk)) }
        dialog.add_action_callback('convertedFinish') { |_context, token| acknowledge('convertedFinish', token, nil, ImageImport.conversion_finish(token)) }
        dialog.add_action_callback('convertedError') { |_context, token, error| ImageImport.conversion_error(token, error) }
        @callbacks_bound = true
      end
      private_class_method :bind_callbacks
    end
  end
end
