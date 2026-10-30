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

    # Một hộp thoại hai tab: Bật/tắt plugin và Chuyển plugin
    def self.run
      legacy_msg = Toggle.migrate_legacy
      dlg = UI::HtmlDialog.new(dialog_title: "VGD Plugin Manager #{VERSION}",
                               width: 640, height: 780,
                               style: UI::HtmlDialog::STYLE_DIALOG)
      dlg.set_file(File.join(UI_DIR, 'dialog.html'))

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

      # ---- Tab Chuyển plugin ----
      dlg.add_action_callback('mg_list') do |_c, json|
        guard.call('Lỗi khi đọc danh sách plugin', push_result) do
          o = JSON.parse(json)
          err = check_versions(o['src'], o['dst'])
          err ? push_result.call(err) : push_list.call(o['src'], o['dst'])
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
          msg << migrate_registry(:shortcuts, src_ver, dst_ver) if opts['shortcuts']
          msg << migrate_registry(:toolbars,  src_ver, dst_ver) if opts['toolbars']
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
          r = build_bundle(src_ver, chosen, opts['shortcuts'], opts['toolbars'], path)
          if r[:error]
            push_result.call(r[:error])
          else
            msg = ["Đã xuất gói: #{r[:path]}", "Số file plugin trong gói: #{r[:count]}"]
            msg.concat(r[:notes])
            warns = scan_compat(src_ver, chosen)
            msg << "Cảnh báo tương thích: #{warns.join(' | ')}" if warns.any?
            msg << 'Trên máy mới: cài file .rbz bằng Extension Manager, khởi động lại SketchUp, ' \
                   'rồi vào Plugins > "VGD: Nhập phím tắt/giao diện từ gói" nếu gói có kèm phím tắt.'
            push_result.call(msg.join("\n"))
          end
        end
      end

      dlg.show
    end
  end
end
