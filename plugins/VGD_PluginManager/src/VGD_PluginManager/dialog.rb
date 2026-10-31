# encoding: UTF-8
require 'sketchup.rb'
require 'json'

module VGD
  module PluginManager
    # Kiểm tra cặp phiên bản nguồn/đích do giao diện gửi lên. Trả về thông báo lỗi hoặc nil.
    def self.check_versions(src, dst)
      versions = installed_versions
      return 'Hãy chọn phiên bản nguồn và đích.' unless versions.include?(src.to_s) && versions.include?(dst.to_s)
      return 'Phiên bản nguồn và đích phải khác nhau.' if src == dst
      nil
    end

    # Hộp thoại đang mở (nil nếu chưa mở hoặc đã đóng)
    def self.dialog_open?
      @dialog && @dialog.visible? ? true : false
    rescue StandardError
      false
    end

    # Một hộp thoại hai tab: Bật/tắt plugin và Chuyển plugin.
    # Chỉ mở một cửa sổ: bấm lại thì đưa cửa sổ đang mở lên trước.
    # Mở thư mục bằng Explorer (Windows) hoặc trình duyệt file của hệ điều hành
    def self.open_folder(dir)
      if Sketchup.platform == :platform_win
        Process.detach(Process.spawn('explorer.exe', dir.tr('/', '\\')))
      else
        UI.openURL("file://#{dir}")
      end
    end

    def self.run
      if dialog_open?
        @dialog.bring_to_front
        return
      end
      legacy_msg = Toggle.migrate_legacy
      dlg = UI::HtmlDialog.new(dialog_title: "VGD Plugin Manager #{VERSION}",
                               width: 640, height: 780,
                               style: UI::HtmlDialog::STYLE_DIALOG)
      dlg.set_file(File.join(UI_DIR, 'dialog.html'))
      @dialog = dlg
      dlg.set_on_closed { @dialog = nil if @dialog.equal?(dlg) }

      js = lambda { |fn, *args| dlg.execute_script("#{fn}(#{args.map(&:to_json).join(', ')})") }
      push_toggle = lambda { |msg| js.call('renderToggle', Toggle.state.merge('version' => VERSION), msg.to_s) }
      push_result = lambda { |msg| js.call('showResult', msg.to_s) }
      push_list   = lambda do |src, dst|
        names = list_plugins(src).map { |pl| pl[:name] }
        js.call('renderMigrate', { 'src' => src, 'dst' => dst, 'plugins' => names })
      end

      # Bọc callback: lỗi bất ngờ được ghi log và hiện trong hộp thoại thay vì im lặng
      guard = lambda do |ctx, reply, &blk|
        begin
          blk.call
        rescue => e
          reply.call(report_error(ctx, e))
        end
      end

      dlg.add_action_callback('ready') do |_c|
        push_toggle.call(legacy_msg)
        js.call('initMigrate', installed_versions)
      end

      # ---- Tab Bật/tắt plugin ----
      dlg.add_action_callback('pm_change') do |_c, json|
        guard.call('Lỗi khi bật/tắt plugin', push_toggle) do
          o = JSON.parse(json)
          action = o['action'] == 'enable' ? 'enable' : 'disable'
          if Array(o['names']).empty?
            push_toggle.call('Hãy chọn ít nhất một plugin.')
          else
            push_toggle.call(Toggle.summary(Toggle.change(o['names'], action), action))
          end
        end
      end

      # Tắt/bật tất cả các mục JS gửi lên (đã lọc theo ô tìm kiếm); Ruby kiểm tra lại và hỏi xác nhận
      dlg.add_action_callback('pm_bulk') do |_c, json|
        guard.call('Lỗi khi tắt/bật hàng loạt', push_toggle) do
          o = JSON.parse(json)
          action = o['action'] == 'enable' ? 'enable' : 'disable'
          targets = Toggle.bulk_targets(o['names'], action)
          if targets.empty?
            next push_toggle.call(action == 'enable' ? 'Không có plugin nào đang tắt để bật.' : 'Không có plugin nào đang bật để tắt.')
          end
          next unless UI.messagebox(Toggle.bulk_confirm_text(targets, action), MB_YESNO) == IDYES
          push_toggle.call(Toggle.summary(Toggle.change(targets, action), action))
        end
      end

      dlg.add_action_callback('pm_save_set') do |_c, json|
        guard.call('Lỗi khi lưu bộ', push_toggle) do
          o = JSON.parse(json)
          push_toggle.call(Toggle.save_set(o['name'], o['names']))
        end
      end

      dlg.add_action_callback('pm_apply_set') do |_c, json|
        guard.call('Lỗi khi áp dụng bộ', push_toggle) do
          o = JSON.parse(json)
          action = o['action'] == 'enable' ? 'enable' : 'disable'
          names = Toggle.load_sets[o['name'].to_s]
          if names.nil?
            push_toggle.call('Không tìm thấy bộ này.')
          else
            push_toggle.call(Toggle.summary(Toggle.change(names, action), action))
          end
        end
      end

      dlg.add_action_callback('pm_delete_set') do |_c, json|
        guard.call('Lỗi khi xóa bộ', push_toggle) do
          o = JSON.parse(json)
          push_toggle.call(Toggle.delete_set(o['name']))
        end
      end

      dlg.add_action_callback('pm_open_disabled') do |_c|
        guard.call('Không mở được thư mục plugin đã tắt', push_toggle) do
          FileUtils.mkdir_p(Toggle.disabled_dir)
          open_folder(Toggle.disabled_dir)
        end
      end

      dlg.add_action_callback('pm_open_plugins') do |_c|
        guard.call('Không mở được thư mục Plugins', push_toggle) do
          dir = plugins_dir(Toggle.year)
          next push_toggle.call("Không thấy thư mục Plugins: #{dir}") unless File.directory?(dir)
          open_folder(dir)
        end
      end

      dlg.add_action_callback('pm_export_sets') do |_c|
        guard.call('Lỗi khi xuất bộ', push_toggle) do
          if Toggle.load_sets.empty?
            push_toggle.call('Chưa có bộ plugin nào để xuất.')
          else
            path = UI.savepanel('Lưu các bộ plugin', Toggle.desktop_dir, 'VGD_Plugin_Sets.json')
            push_toggle.call(Toggle.export_sets(path)) if path
          end
        end
      end

      dlg.add_action_callback('pm_import_sets') do |_c|
        guard.call('Lỗi khi nhập bộ', push_toggle) do
          path = UI.openpanel('Chọn file bộ plugin (.json)', Toggle.desktop_dir, 'JSON|*.json||')
          next unless path
          incoming, err = Toggle.read_sets_file(path)
          if err
            push_toggle.call(err)
            next
          end
          clash = incoming.keys & Toggle.load_sets.keys
          overwrite = false
          if clash.any?
            ask = UI.messagebox("Có #{clash.size} bộ trùng tên: #{clash.join(', ')}.\n" \
                                'Chọn Yes để ghi đè, No để giữ bộ hiện có (chỉ nhập bộ mới).', MB_YESNO)
            overwrite = (ask == IDYES)
          end
          push_toggle.call(Toggle.import_sets(incoming, overwrite))
        end
      end

      dlg.add_action_callback('migrate') do |_c, json|
        guard.call('Lỗi khi chuyển', push_result) do
          opts = JSON.parse(json)
          src_ver = opts['src'].to_s
          dst_ver = opts['dst'].to_s
          err = check_versions(src_ver, dst_ver)
          next push_result.call(err) if err
          chosen = opts['plugins'] || []
          msg = []
          if chosen.any?
            warns = scan_compat(src_ver, chosen)
            r = copy_plugins(src_ver, dst_ver, chosen, opts['overwrite'])
            msg << "Đã chép: #{r[:done].size} mục."
            msg << "Bỏ qua (đã tồn tại): #{r[:skipped].size} mục." if r[:skipped].any?
            msg << "Lỗi: #{r[:failed].join('; ')}" if r[:failed].any?
            msg << "Sao lưu thư mục đích: #{r[:backup]}" if r[:backup]
            msg << "Cảnh báo tương thích: #{warns.join(' | ')}" if warns.any?
          end
          msg << "Hãy đóng SketchUp và mở lại bản #{dst_ver} để áp dụng."
          push_result.call(msg.join("\n"))
        end
      end

      dlg.add_action_callback('export_bundle') do |_c, json|
        guard.call('Lỗi khi xuất gói', push_result) do
          opts = JSON.parse(json)
          src_ver = opts['src'].to_s
          err = check_versions(src_ver, opts['dst'])
          next push_result.call(err) if err
          chosen = opts['plugins'] || []
          next push_result.call('Hãy tick ít nhất một plugin để xuất gói.') if chosen.empty?
          path = UI.savepanel('Lưu gói .rbz tổng', Toggle.desktop_dir, "VGD_Plugin_Bundle_#{src_ver}.rbz")
          next unless path
          r = build_bundle(src_ver, chosen, path)
          if r[:error]
            push_result.call(r[:error])
          else
            msg = ["Đã xuất gói: #{r[:path]}", "Số file plugin trong gói: #{r[:count]}"]
            msg.concat(r[:notes])
            warns = scan_compat(src_ver, chosen)
            msg << "Cảnh báo tương thích: #{warns.join(' | ')}" if warns.any?
            msg << 'Trên máy mới: cài file .rbz bằng Extension Manager rồi khởi động lại SketchUp. ' \
                   'Gói chỉ chứa plugin; muốn mang các bộ plugin sang máy khác, dùng "Xuất các bộ ra file" ở tab Bật/tắt.'
            push_result.call(msg.join("\n"))
          end
        end
      end

      dlg.show
    end
  end
end
