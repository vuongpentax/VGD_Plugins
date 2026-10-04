module VGD
  module Dim
    module Dialog
      def self.show
        if @dlg && @dlg.visible?
          @dlg.bring_to_front
          return
        end
        @dlg = UI::HtmlDialog.new(
          dialog_title: 'VGD Dim', preferences_key: 'VGD_Dim_Dialog',
          width: 400, height: 780, min_width: 360, min_height: 520,
          resizable: true, style: UI::HtmlDialog::STYLE_DIALOG
        )
        @dlg.set_file(File.join(__dir__, 'dialog.html'))

        @dlg.add_action_callback('ready') { |_c, _p| push_state }

        @dlg.add_action_callback('scan') do |_c, json|
          acc = Core.scan(Sketchup.active_model, JSON.parse(json)['opts'])
          send_js('onScan', Core.summary(acc))
        end

        @dlg.add_action_callback('run') do |_c, json|
          p = JSON.parse(json)
          begin
            res = Core.run(p['kinds'].map(&:to_sym), p['settings'], p['opts'])
            send_js('onResult', res)
          rescue StandardError => e
            send_js('onError', { 'message' => "#{e.class}: #{e.message}" })
          end
        end

        @dlg.add_action_callback('rebuild') do |_c, json|
          begin
            send_js('onRebuild', Core.rebuild_dims(JSON.parse(json)['opts']))
          rescue StandardError => e
            send_js('onError', { 'message' => "#{e.class}: #{e.message}" })
          end
        end

        @dlg.add_action_callback('smart_dim') do |_c, json|
          p = JSON.parse(json)
          begin
            Store.write('smartdim', p['opts'])
            send_js('onSmart', SmartDim.run(p['opts'], p['settings']))
          rescue StandardError => e
            send_js('onError', { 'message' => e.message })
          end
        end

        @dlg.add_action_callback('save_preset') do |_c, json|
          p = JSON.parse(json)
          ok = Presets.save(p['name'], p['settings'])
          send_js('onToast', { 'message' => ok ? "Đã lưu preset \"#{p['name']}\"." : 'Không lưu được: tên trống hoặc trùng preset hệ thống.' })
          push_state(p['name'])
        end

        @dlg.add_action_callback('delete_preset') do |_c, name|
          ok = Presets.delete(name)
          send_js('onToast', { 'message' => ok ? "Đã xóa preset \"#{name}\"." : 'Không xóa được preset hệ thống.' })
          push_state
        end

        @dlg.add_action_callback('set_auto') do |_c, json|
          p = JSON.parse(json)
          AutoStyle.save(p['enabled'], p['settings'])
          send_js('onToast', { 'message' => p['enabled'] ? 'Auto-Style đang bật: Dim, Text, Label mới sẽ tự áp style trong form.' : 'Auto-Style đã tắt.' })
        end

        @dlg.add_action_callback('anim_set') do |_c, json|
          begin
            send_js('onAnim', Animation.write(Sketchup.active_model, JSON.parse(json)))
            send_js('onToast', { 'message' => 'Đã cập nhật Animation (không nằm trong Undo).' })
          rescue StandardError => e
            send_js('onError', { 'message' => "Animation: #{e.message}" })
          end
        end

        @dlg.show
      end

      def self.push_state(select = nil)
        send_js('onState', { 'presets' => Presets.all, 'builtin' => Presets::BUILTIN.keys, 'select' => select,
                             'auto' => AutoStyle.load, 'smart' => Store.read('smartdim', {}), 'anim' => Animation.read(Sketchup.active_model) })
      end

      def self.send_js(fn, data)
        @dlg.execute_script("VGD.#{fn}(#{JSON.generate(data)})") if @dlg
      end
    end
  end
end
