require 'base64'

module VGD
  module Reference
    module Session
      module_function

      def initialize
        return if @initialized
        @initialized = true
        @observer = AppObserver.new
        Sketchup.add_observer(@observer)
        setup_for_model(Sketchup.active_model, reset: true)
        UI.start_timer(0.1, false) { setup_for_model(Sketchup.active_model) }
      rescue StandardError => error
        ImageLoader.log_error('Session initialization failed', error)
      end

      def setup_for_model(model = Sketchup.active_model, reset: false)
        return unless model
        if @model != model || reset
          cleanup_model(@model) if @model && @model != model
          if reset && @model == model
            exit_edit if @current_tool
            clear_store
          end
          @model = model
          @store ||= ReferenceStore.new
          @store = ReferenceStore.new if reset
          @current_tool = nil
          @crop_item_id = nil
          register_overlay(model)
          Manager.refresh if defined?(Manager)
        elsif !@overlay || !@overlay.valid?
          register_overlay(model)
        end
        @model
      rescue StandardError => error
        ImageLoader.log_error('Model setup failed', error)
        nil
      end

      def model
        @model
      end

      def store
        @store
      end

      def overlay
        @overlay
      end

      def crop_item_id
        @current_tool && @current_tool.crop_mode? ? @current_tool.item_id : nil
      end

      def set_current_tool(tool)
        @current_tool = tool
      end

      def add_reference(path, source_type: :file, allow_bitmap: false, display_name: nil, image_rep: nil)
        setup_for_model
        return nil unless @model && @store
        if image_rep
          width_px, height_px = image_rep.width.to_i, image_rep.height.to_i
        else
          image_rep, width_px, height_px = ImageLoader.load(path, allow_bitmap: allow_bitmap)
        end
        view = @model.active_view
        viewport_width, viewport_height = ScreenCoordinates.viewport_size(view)
        width = viewport_width * DEFAULT_FRAME_RATIO
        height = width * height_px.to_f / width_px
        if height > viewport_height * 0.58
          scale = (viewport_height * 0.58) / height
          width *= scale
          height *= scale
        end
        x = (viewport_width - width) / 2.0
        y = (viewport_height - height) / 2.0
        item = ReferenceItem.new(
          id: @store.next_id, source_type: source_type,
          source_path: File.expand_path(path), display_name: display_name, image_width: width_px,
          image_height: height_px, x: x, y: y, width: width,
          height: height, z_index: (@store.items.map(&:z_index).max || 0) + 1
        )
        @store.add(item)
        @store.select(item.id)
        if overlay_active? && TextureCache.load(item, view, image_rep).nil?
          @store.remove(item.id)
          TextureCache.release_item(item)
          TempFiles.release(item.source_path)
          show_error('Không thể tải ảnh tham chiếu.')
          Manager.refresh if defined?(Manager)
          return nil
        end
        redraw
        Manager.refresh if defined?(Manager)
        enter_edit(item.id) if overlay_active?
        item
      rescue StandardError => error
        ImageLoader.log_error('Reference add failed', error)
        show_error('Không thể tải ảnh tham chiếu.')
        nil
      end

      def add_from_picker
        filter = 'Các định dạng ảnh|' + FILE_EXTENSIONS.map { |extension| '*' + extension }.join(';') + '|Tất cả file|*.*||'
        path = UI.openpanel('Chọn ảnh tham chiếu', '', filter)
        return nil unless path
        ImageImport.add_file(path)
      rescue StandardError => error
        ImageLoader.log_error('Image picker failed', error)
        show_error('Không thể mở hộp thoại chọn ảnh.')
        nil
      end

      def paste_reference
        payload = ClipboardBridgeWin.read_image
        unless payload
          show_error('Không tìm thấy ảnh trong bộ nhớ tạm.')
          return nil
        end
        bytes, extension, name = payload
        path = TempFiles.write_bytes(name, bytes, extension)
        item = add_reference(path, source_type: :clipboard, allow_bitmap: true)
        TempFiles.release(path) unless item
        item
      rescue StandardError => error
        ImageLoader.log_error('Clipboard paste failed', error)
        show_error('Không thể tải ảnh tham chiếu.')
        nil
      end

      def drop_start(token, name, size, chunks, mime = nil)
        raise ArgumentError, 'Mã truyền ảnh không hợp lệ.' unless token.to_s.match?(/\Adrop-[a-zA-Z0-9-]{1,90}\z/)
        total = size.to_i
        raise ArgumentError, 'Ảnh phải có dung lượng không quá 20 MiB.' unless total.between?(1, MAX_IMAGE_BYTES)
        count = chunks.to_i
        raise ArgumentError, 'Số gói dữ liệu ảnh không hợp lệ.' unless count == (total + TRANSFER_CHUNK_BYTES - 1) / TRANSFER_CHUNK_BYTES
        @drop_buffers ||= {}
        raise ArgumentError, 'Đang nhận nhiều ảnh. Hãy chờ lượt hiện tại xong.' if @drop_buffers.size >= 8 || @drop_buffers.key?(token.to_s)
        @drop_buffers[token.to_s] = { name: File.basename(name.to_s[0, 250]), size: total, chunks: count, next: 0, mime: mime.to_s, data: ''.b }
        UI.start_timer(60, false) { @drop_buffers.delete(token.to_s) if @drop_buffers }
        true
      rescue StandardError => error
        ImageLoader.log_error('Image drop failed', error)
        show_error(error.message)
        false
      end

      def drop_chunk(token, index, encoded)
        entry = @drop_buffers && @drop_buffers[token.to_s]
        return false unless entry
        raise ArgumentError, 'Gói dữ liệu ảnh sai thứ tự.' unless Integer(index) == entry[:next] && entry[:next] < entry[:chunks]
        raise ArgumentError, 'Gói dữ liệu ảnh quá lớn.' if encoded.to_s.bytesize > TRANSFER_CHUNK_BYTES * 4 / 3 + 8
        bytes = Base64.strict_decode64(encoded.to_s)
        expected = [TRANSFER_CHUNK_BYTES, entry[:size] - entry[:data].bytesize].min
        raise ArgumentError, 'Gói dữ liệu ảnh thiếu dung lượng.' unless bytes.bytesize == expected
        entry[:data] << bytes
        entry[:next] += 1
        true
      rescue StandardError => error
        @drop_buffers.delete(token.to_s) if @drop_buffers
        ImageLoader.log_error('Dropped image data failed', error)
        show_error('Không thể tải ảnh được thả vào.')
        false
      end

      def drop_finish(token)
        entry = @drop_buffers && @drop_buffers.delete(token.to_s)
        return false unless entry && entry[:data].bytesize == entry[:size] && entry[:next] == entry[:chunks]
        ImageImport.add_bytes(entry[:name], entry[:data], entry[:mime])
      rescue StandardError => error
        ImageLoader.log_error('Image drop failed', error)
        show_error('Không thể tải ảnh được thả vào.')
        false
      end

      def select_reference(id)
        setup_for_model
        item = @store && @store.find(id)
        return false unless overlay_active? && item && item.visible
        @store.bring_to_front(item)
        @store.select(item.id)
        redraw
        enter_edit(item.id)
        Manager.refresh if defined?(Manager)
        true
      end

      def cancel_drop(token)
        @drop_buffers.delete(token.to_s) if @drop_buffers
      end

      def enter_edit(id)
        setup_for_model
        item = @store && @store.find(id)
        return nil unless overlay_active? && item && item.visible
        @store.select(item.id)
        restore_locked = item.locked
        item.locked = false
        @current_tool = InteractionTool.new(item.id, restore_locked: restore_locked)
        @model.select_tool(@current_tool)
        redraw
        Manager.refresh if defined?(Manager)
        @current_tool
      rescue StandardError => error
        @current_tool.restore_passive_lock if @current_tool
        @current_tool = nil
        @store.select(nil) if @store
        ImageLoader.log_error('Could not enter edit mode', error)
        nil
      end

      def start_crop(id = nil)
        item = @store && @store.find(id || @store.selected_id)
        return false unless item
        tool = @current_tool
        tool = enter_edit(item.id) unless tool && tool.item_id == item.id
        result = tool && tool.start_crop
        Manager.refresh if defined?(Manager)
        result
      end

      def exit_edit
        return unless @current_tool
        @current_tool.restore_passive_lock
        @store.select(nil) if @store
        @current_tool = nil
        @crop_item_id = nil
        @model.select_tool(nil) if @model
        redraw
        Manager.refresh if defined?(Manager)
      rescue StandardError => error
        ImageLoader.log_error('Could not exit edit mode', error)
      end

      def tool_deactivated(tool, view = nil)
        return unless tool && @current_tool.equal?(tool)
        tool.restore_passive_lock
        @current_tool = nil
        @crop_item_id = nil
        @store.select(nil) if @store
        view.invalidate if view
        Manager.refresh if defined?(Manager)
      rescue StandardError => error
        ImageLoader.log_error('Edit state cleanup failed', error)
      end

      def crop_finished
        redraw
        Manager.refresh if defined?(Manager)
      end

      def set_visible(id, visible)
        item = @store && @store.find(id)
        return false unless item
        item.visible = !!visible
        exit_edit if !item.visible && @current_tool && @current_tool.item_id == item.id
        redraw
        Manager.refresh if defined?(Manager)
        true
      end

      def toggle_lock(id)
        item = @store && @store.find(id)
        return false unless item
        item.locked = !item.locked
        exit_edit if item.locked && @current_tool && @current_tool.item_id == item.id
        redraw
        Manager.refresh if defined?(Manager)
        item.locked
      end

      def delete_reference(id)
        item = @store && @store.remove(id)
        return false unless item
        TextureCache.release_item(item)
        TempFiles.release(item.source_path)
        exit_edit if @current_tool && @current_tool.item_id == item.id
        redraw
        Manager.refresh if defined?(Manager)
        true
      end

      def toggle_hide_all
        return false unless @store
        @store.hidden_all = !@store.hidden_all
        exit_edit if @store.hidden_all
        redraw
        Manager.refresh if defined?(Manager)
        @store.hidden_all
      end

      def set_hide_all(hidden)
        return unless @store
        @store.hidden_all = !!hidden
        exit_edit if @store.hidden_all
        redraw
        Manager.refresh if defined?(Manager)
      end

      def set_opacity(id, value, commit: false)
        item = @store && @store.find(id)
        return false unless item
        item.set_opacity(value)
        view = @model && @model.active_view
        if overlay_active? && view
          item.opacity_preview = true
          TextureCache.preview_opacity(item, view)
        else
          item.opacity_preview = false
        end
        if commit && overlay_active? && view
          texture_id = view && TextureCache.commit_opacity(item, view)
          item.opacity_preview = texture_id.nil?
        elsif commit
          item.opacity_preview = false
        end
        redraw
        Manager.refresh if commit && defined?(Manager)
        true
      end

      def overlay_enabled(view)
        return unless @store && view
        TextureCache.reload_all(@store.items, view)
        view.invalidate
      end

      def overlay_disabled(view = nil)
        @store.select(nil) if @store
        @model.select_tool(nil) if @current_tool && @model
        @current_tool = nil
        TextureCache.release_all
        view.invalidate if view
        Manager.refresh if defined?(Manager)
      rescue StandardError => error
        ImageLoader.log_error('Overlay disable cleanup failed', error)
      end

      def redraw
        view = @model && @model.active_view
        view.invalidate if view
      rescue StandardError => error
        ImageLoader.log_error('Viewport redraw failed', error)
      end

      def show_error(message)
        if defined?(Manager) && Manager.visible?
          Manager.show_message(message.to_s)
        else
          UI.messagebox(message.to_s)
        end
      rescue StandardError
        nil
      end

      def shutdown
        exit_edit if @current_tool
        clear_store
        TextureCache.release_all(clear: true)
        TempFiles.cleanup
        @drop_buffers = {}
        @observer = nil
      end

      def register_overlay(model)
        existing = model.overlays.find { |entry| entry.overlay_id == OVERLAY_ID }
        @overlay = existing || ReferenceOverlay.new
        unless existing
          model.overlays.add(@overlay)
          @overlay.enabled = true
        end
        @overlay
      end

      def overlay_active?
        !!(@overlay && @overlay.valid? && @overlay.enabled?)
      rescue StandardError
        false
      end

      def clear_store
        ImageImport.cancel_all if defined?(ImageImport)
        removed = @store ? @store.clear : []
        removed.each do |item|
          TextureCache.release_item(item)
          TempFiles.release(item.source_path)
        end
        @store = ReferenceStore.new
        @current_tool = nil
        @crop_item_id = nil
        @drop_buffers = {}
      end

      def cleanup_model(model)
        return unless model
        if model == @model
          exit_edit if @current_tool
          TextureCache.release_all(clear: true)
          clear_store
        end
        if @overlay && @overlay.valid?
          model.overlays.remove(@overlay)
          @overlay = nil
        end
      rescue StandardError => error
        ImageLoader.log_error('Model cleanup failed', error)
      end

      def switch_hide_state
        toggle_hide_all
      end
    end
  end
end
