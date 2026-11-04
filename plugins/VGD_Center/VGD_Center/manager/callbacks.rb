# encoding: UTF-8
require 'sketchup.rb'
require 'json'

module VGD
  module Center
    module Manager
      # Gắn các lệnh của tab "Quản lý" vào hộp thoại của Center (tên lệnh bắt đầu bằng mgr_).
      # Giao diện nằm trong manager/manager.js; Ruby trả kết quả bằng window.VGDManager.<hàm>.
      # Mỗi lệnh nhận một chuỗi JSON, trong đó lang ('vi' hoặc 'en') quyết định ngôn ngữ của thông báo.
      def self.register_callbacks(dlg)
        js = lambda { |fn, *args| dlg.execute_script("window.VGDManager && window.VGDManager.#{fn}(#{args.map(&:to_json).join(', ')});") }
        push_toggle = lambda { |msg| js.call('renderToggle', Toggle.state.merge('version' => VGD::Center::VERSION), msg.to_s) }
        push_result = lambda { |msg| js.call('showResult', msg.to_s) }
        push_list   = lambda do |src, dst|
          names = list_plugins(src).map { |pl| pl[:name] }
          js.call('renderMigrate', { 'src' => src, 'dst' => dst, 'plugins' => names })
        end

        # Đọc JSON của lệnh và đặt ngôn ngữ. Không có JSON (nil/rỗng) thì dùng tiếng Việt; JSON hỏng thì ném lỗi.
        parse = lambda do |json|
          data = json.nil? || json.to_s.empty? ? {} : JSON.parse(json)
          data = {} unless data.is_a?(Hash)
          Manager.lang = data['lang']
          data
        end

        # Bọc callback: lỗi bất ngờ được ghi log và hiện trong giao diện thay vì im lặng.
        # ctx là khóa thông báo (xem text.rb), được dịch lúc gặp lỗi để đúng ngôn ngữ đã đặt.
        guard = lambda do |ctx, reply, &blk|
          begin
            blk.call
          rescue => e
            reply.call(report_error(t(ctx), e))
          end
        end

        # Không đổi file trong Plugins khi Center đang cài/gỡ plugin. Trả về true nếu đang bận (đã báo người dùng).
        busy = lambda do |reply|
          next false unless VGD::Center.busy?
          reply.call(t(:busy))
          true
        end

        # ---- Mở tab: gửi trạng thái ban đầu ----
        dlg.add_action_callback('mgr_ready') do |_c, json|
          guard.call(:ctx_open_tab, push_toggle) do
            parse.call(json)
            # Chuyển dữ liệu cũ (nếu còn) về Plugins/VGD_Center/data, rồi báo cả phần đã chuyển lúc khởi động
            push_toggle.call(Toggle.migration_message(take_startup_report, Toggle.migrate_old_data))
            js.call('initMigrate', installed_versions)
          end
        end

        # ---- Bật/tắt plugin ----
        dlg.add_action_callback('mgr_change') do |_c, json|
          guard.call(:ctx_toggle, push_toggle) do
            o = parse.call(json)
            next if busy.call(push_toggle)
            action = o['action'] == 'enable' ? 'enable' : 'disable'
            if Array(o['names']).empty?
              push_toggle.call(t(:pick_one))
            else
              push_toggle.call(Toggle.summary(Toggle.change(o['names'], action), action))
            end
          end
        end

        # Tắt/bật tất cả các mục JS gửi lên (đã lọc theo ô tìm kiếm); Ruby kiểm tra lại và hỏi xác nhận
        dlg.add_action_callback('mgr_bulk') do |_c, json|
          guard.call(:ctx_bulk, push_toggle) do
            o = parse.call(json)
            next if busy.call(push_toggle)
            action = o['action'] == 'enable' ? 'enable' : 'disable'
            targets = Toggle.bulk_targets(o['names'], action)
            if targets.empty?
              next push_toggle.call(t(action == 'enable' ? :bulk_none_enable : :bulk_none_disable))
            end
            next unless UI.messagebox(Toggle.bulk_confirm_text(targets, action), MB_YESNO) == IDYES
            push_toggle.call(Toggle.summary(Toggle.change(targets, action), action))
          end
        end

        dlg.add_action_callback('mgr_save_set') do |_c, json|
          guard.call(:ctx_save_set, push_toggle) do
            o = parse.call(json)
            push_toggle.call(Toggle.save_set(o['name'], o['names']))
          end
        end

        dlg.add_action_callback('mgr_apply_set') do |_c, json|
          guard.call(:ctx_apply_set, push_toggle) do
            o = parse.call(json)
            next if busy.call(push_toggle)
            action = o['action'] == 'enable' ? 'enable' : 'disable'
            names = Toggle.load_sets[o['name'].to_s]
            if names.nil?
              push_toggle.call(t(:set_not_found))
            else
              push_toggle.call(Toggle.summary(Toggle.change(names, action), action))
            end
          end
        end

        dlg.add_action_callback('mgr_delete_set') do |_c, json|
          guard.call(:ctx_delete_set, push_toggle) do
            o = parse.call(json)
            push_toggle.call(Toggle.delete_set(o['name']))
          end
        end

        dlg.add_action_callback('mgr_open_disabled') do |_c, json|
          guard.call(:ctx_open_disabled, push_toggle) do
            parse.call(json)
            FileUtils.mkdir_p(Toggle.disabled_dir)
            open_folder(Toggle.disabled_dir)
          end
        end

        dlg.add_action_callback('mgr_open_plugins') do |_c, json|
          guard.call(:ctx_open_plugins, push_toggle) do
            parse.call(json)
            dir = plugins_dir(Toggle.year)
            next push_toggle.call(t(:no_plugins_dir, dir: dir)) unless File.directory?(dir)
            open_folder(dir)
          end
        end

        dlg.add_action_callback('mgr_export_sets') do |_c, json|
          guard.call(:ctx_export_sets, push_toggle) do
            parse.call(json)
            if Toggle.load_sets.empty?
              push_toggle.call(t(:sets_none))
            else
              path = UI.savepanel(t(:save_sets_title), Toggle.desktop_dir, 'VGD_Plugin_Sets.json')
              push_toggle.call(Toggle.export_sets(path)) if path
            end
          end
        end

        dlg.add_action_callback('mgr_import_sets') do |_c, json|
          guard.call(:ctx_import_sets, push_toggle) do
            parse.call(json)
            path = UI.openpanel(t(:open_sets_title), Toggle.desktop_dir, 'JSON|*.json||')
            next unless path
            incoming, err = Toggle.read_sets_file(path)
            if err
              push_toggle.call(err)
              next
            end
            clash = incoming.keys & Toggle.load_sets.keys
            overwrite = false
            if clash.any?
              ask = UI.messagebox(t(:import_clash, n: clash.size, names: clash.join(', ')), MB_YESNO)
              overwrite = (ask == IDYES)
            end
            push_toggle.call(Toggle.import_sets(incoming, overwrite))
          end
        end

        # ---- Chuyển plugin giữa các bản SketchUp ----
        dlg.add_action_callback('mgr_list') do |_c, json|
          guard.call(:ctx_list, push_result) do
            o = parse.call(json)
            err = check_versions(o['src'], o['dst'])
            err ? push_result.call(err) : push_list.call(o['src'], o['dst'])
          end
        end

        dlg.add_action_callback('mgr_migrate') do |_c, json|
          guard.call(:ctx_migrate, push_result) do
            opts = parse.call(json)
            next if busy.call(push_result)
            src_ver = opts['src'].to_s
            dst_ver = opts['dst'].to_s
            err = check_versions(src_ver, dst_ver)
            next push_result.call(err) if err
            chosen = opts['plugins'] || []
            msg = []
            if chosen.any?
              warns = scan_compat(src_ver, chosen)
              r = copy_plugins(src_ver, dst_ver, chosen, opts['overwrite'])
              msg << t(:mig_copied, n: r[:done].size)
              msg << t(:mig_skipped, n: r[:skipped].size) if r[:skipped].any?
              msg << t(:sum_errors, errors: r[:failed].join('; ')) if r[:failed].any?
              msg << t(:mig_backup, path: r[:backup]) if r[:backup]
              msg << t(:compat_warn, warnings: warns.join(' | ')) if warns.any?
            end
            msg << t(:mig_restart, ver: dst_ver)
            push_result.call(msg.join("\n"))
          end
        end

        dlg.add_action_callback('mgr_export_bundle') do |_c, json|
          guard.call(:ctx_bundle, push_result) do
            opts = parse.call(json)
            src_ver = opts['src'].to_s
            err = check_versions(src_ver, opts['dst'])
            next push_result.call(err) if err
            chosen = opts['plugins'] || []
            next push_result.call(t(:bundle_pick)) if chosen.empty?
            path = UI.savepanel(t(:save_bundle_title), Toggle.desktop_dir, "VGD_Plugin_Bundle_#{src_ver}.rbz")
            next unless path
            r = build_bundle(src_ver, chosen, path)
            if r[:error]
              push_result.call(r[:error])
            else
              msg = [t(:bundle_done, path: r[:path]), t(:bundle_count, n: r[:count])]
              msg.concat(r[:notes])
              warns = scan_compat(src_ver, chosen)
              msg << t(:compat_warn, warnings: warns.join(' | ')) if warns.any?
              msg << t(:bundle_next)
              push_result.call(msg.join("\n"))
            end
          end
        end
      end
    end
  end
end
