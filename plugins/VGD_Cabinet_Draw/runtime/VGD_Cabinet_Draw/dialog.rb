module VGD_Cabinet_Draw
  module Dialog
    extend self

    def show
      return @window.show if @window && @window.visible?
      @window = UI::HtmlDialog.new(
        dialog_title: "VGD Cabinet Draw #{VERSION}", preferences_key: 'VGD_Cabinet_Draw.Main',
        scrollable: true, resizable: true, width: 390, height: 720, min_width: 340, min_height: 480,
        style: UI::HtmlDialog::STYLE_DIALOG
      )
      @window.set_file(File.join(__dir__, 'dialog.html'))
      @window.add_action_callback('ready') { |_ctx, _| load_state }
      # Dialog báo chế độ sáng/tối để HUD và preview trong viewport đổi theo.
      @window.add_action_callback('theme') do |_ctx, payload|
        Theme.mode = payload
        Sketchup.active_model.active_view.invalidate
      end
      @window.add_action_callback('tool') do |_ctx, payload|
        data = JSON.parse(payload)
        VGD_Cabinet_Draw.launch_tool(data['name'], data['settings'] || {}, data['preset_id'])
      rescue StandardError => e
        set_status(e.message)
      end
      @window.add_action_callback('settings') do |_ctx, payload|
        VGD_Cabinet_Draw.update_active_settings(JSON.parse(payload))
      rescue StandardError => e
        set_status(e.message)
      end
      # Nút Áp dụng / Hủy: dự phòng cho phím Enter / Esc (SketchUp 2025.0 trên Windows lỗi Enter).
      @window.add_action_callback('apply') do |_ctx, _payload|
        VGD_Cabinet_Draw.apply_active_tool
      rescue StandardError => e
        set_status(e.message)
      end
      @window.add_action_callback('cancel') do |_ctx, _payload|
        VGD_Cabinet_Draw.cancel_active_tool
      rescue StandardError => e
        set_status(e.message)
      end
      # Kho setting theo công cụ. Mỗi lệnh ghi xong thì đẩy lại danh sách và báo công cụ đang chạy.
      store_action('ts_save', 'Đã lưu setting mới.') { |d| ToolSettings.new.save(d['group'], d['name'], d['settings']) }
      store_action('ts_update', 'Đã cập nhật setting.') { |d| ToolSettings.new.update(d['group'], d['id'], d['settings']) }
      store_action('ts_rename', 'Đã đổi tên setting.') { |d| ToolSettings.new.rename(d['group'], d['id'], d['name']) }
      store_action('ts_delete', 'Đã xóa setting.') { |d| ToolSettings.new.delete(d['group'], d['id']) }
      store_action('ts_default', 'Đã đặt setting mặc định.') { |d| ToolSettings.new.set_default(d['group'], d['id']) }
      store_action('ts_base_save', 'Đã lưu thông số gốc dùng chung.') { |d| ToolSettings.new.save_base(d['settings']) }
      @window.add_action_callback('ts_load') do |_ctx, payload|
        data = JSON.parse(payload)
        preset = ToolSettings.new.presets(data['group']).find { |item| item['id'] == data['id'] }
        push_settings(preset['params'], true, data['group']) if preset
      rescue StandardError => e
        set_status(e.message)
      end
      @window.add_action_callback('ts_export') do |_ctx, _payload|
        path = UI.savepanel('Xuất setting VGD Cabinet Draw', '', 'vgd_cabinet_settings.json')
        next unless path
        File.write(path, ToolSettings.new.export_json, mode: 'w:UTF-8')
        set_status("Đã xuất setting ra #{path}")
      rescue StandardError => e
        set_status(e.message)
      end
      @window.add_action_callback('ts_import') do |_ctx, _payload|
        path = UI.openpanel('Nhập setting VGD Cabinet Draw', '', 'JSON|*.json||')
        next unless path
        count = ToolSettings.new.import_json(File.read(path, encoding: 'UTF-8'))
        set_status("Đã nhập #{count} setting (gộp vào danh sách hiện có, không ghi đè).")
        load_state
        VGD_Cabinet_Draw.refresh_active_presets
      rescue StandardError => e
        set_status(e.message)
      end
      # Công tắc chung (tab Setting chung): kéo Scale xong thì tủ tự cập nhật. Lưu theo người dùng trên máy.
      @window.add_action_callback('auto_stretch') do |_ctx, payload|
        AutoStretch.enabled = JSON.parse(payload)['enabled'] == true
        set_status(AutoStretch.enabled? ? 'Đã bật: kéo Scale xong tủ tự cập nhật.' : 'Đã tắt: kéo Scale xong, bấm Box → Board rồi Enter để cập nhật.')
      rescue StandardError => e
        set_status(e.message)
      end
      @window.set_on_closed { @window = nil }
      @window.show
    end

    def close
      @window.close if @window
    rescue StandardError
      nil
    ensure
      @window = nil
    end

    def set_status(message)
      return unless @window && @window.visible?
      @window.execute_script("VGD.status(#{JSON.generate(message.to_s)})")
    rescue StandardError
      nil
    end

    def store_action(name, done_message)
      @window.add_action_callback(name) do |_ctx, payload|
        yield JSON.parse(payload)
        set_status(done_message)
        load_state
        VGD_Cabinet_Draw.refresh_active_presets
      rescue StandardError => e
        set_status(e.message)
      end
    end

    # Đẩy bộ thông số vào các ô nhập. notify = true thì báo lại cho công cụ đang chạy.
    # group (box/panel/door/drawer) giới hạn việc nạp và đặt lại về mặc định trong phạm vi các ô của công cụ đó.
    def push_settings(settings, notify = false, group = nil)
      return unless @window && @window.visible?
      @window.execute_script("VGD.loadSettings(#{JSON.generate(settings)}, #{notify ? 'true' : 'false'}, #{JSON.generate(group)})")
    rescue StandardError
      nil
    end

    # Chọn một setting trong danh sách thả xuống của công cụ (khi chọn từ thanh trên viewport).
    def select_preset(group, id)
      return unless @window && @window.visible?
      @window.execute_script("VGD.pickPreset(#{JSON.generate(group)}, #{JSON.generate(id)})")
    rescue StandardError
      nil
    end

    def load_state
      return unless @window && @window.visible?
      @window.execute_script("VGD.setAutoStretch(#{AutoStretch.enabled? ? 'true' : 'false'})")
      @window.execute_script("VGD.state(#{JSON.generate(ToolSettings.new.all)})")
    rescue StandardError => e
      set_status(e.message)
    end
  end
end
