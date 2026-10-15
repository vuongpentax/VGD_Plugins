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
      @window.add_action_callback('ready') { |_ctx, _| load_presets }
      @window.add_action_callback('tool') do |_ctx, payload|
        data = JSON.parse(payload)
        VGD_Cabinet_Draw.launch_tool(data['name'], data['settings'] || {})
      rescue StandardError => e
        set_status(e.message)
      end
      @window.add_action_callback('settings') do |_ctx,payload|
        VGD_Cabinet_Draw.update_active_settings(JSON.parse(payload))
      rescue StandardError => e
        set_status(e.message)
      end
      @window.add_action_callback('preset_save') do |_ctx, payload|
        data = JSON.parse(payload)
        PresetStore.new.save(data['name'], data['settings'], data['group'])
        set_status('Đã lưu preset.')
        load_presets
      rescue StandardError => e
        set_status(e.message)
      end
      @window.add_action_callback('preset_load') do |_ctx, payload|
        preset = PresetStore.new.all['presets'].find { |item| item['id'] == payload }
        @window.execute_script("VGD.loadSettings(#{JSON.generate(preset['params'])})") if preset
      rescue StandardError => e
        set_status(e.message)
      end
      @window.add_action_callback('preset_update') do |_ctx,payload|
        data=JSON.parse(payload); PresetStore.new.update(data['id'],data['settings']); set_status('Đã cập nhật preset.'); load_presets
      rescue StandardError=>e; set_status(e.message)
      end
      @window.add_action_callback('preset_rename') do |_ctx,payload|
        data=JSON.parse(payload); PresetStore.new.rename(data['id'],data['name']); set_status('Đã đổi tên preset.'); load_presets
      rescue StandardError=>e; set_status(e.message)
      end
      @window.add_action_callback('group_add') do |_ctx,payload|
        data=JSON.parse(payload); PresetStore.new.add_group(data['name']); set_status('Đã tạo nhóm preset.'); load_presets
      rescue StandardError=>e; set_status(e.message)
      end
      @window.add_action_callback('preset_delete') do |_ctx, payload|
        PresetStore.new.delete(payload)
        set_status('Đã xóa preset.')
        load_presets
      rescue StandardError => e
        set_status(e.message)
      end
      @window.set_on_closed { @window = nil }
      @window.show
    end

    def set_status(message)
      return unless @window && @window.visible?
      @window.execute_script("VGD.status(#{JSON.generate(message.to_s)})")
    rescue StandardError
      nil
    end

    def load_presets
      return unless @window && @window.visible?
      data = PresetStore.new.all
      @window.execute_script("VGD.presets(#{JSON.generate(data)})")
    rescue StandardError => e
      set_status(e.message)
    end
  end
end
