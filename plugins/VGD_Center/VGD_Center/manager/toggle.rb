# encoding: UTF-8
require 'sketchup.rb'
require 'fileutils'
require 'json'

module VGD
  module Center
    module Manager
      # Quản lý bật/tắt plugin: plugin bị tắt được chuyển sang thư mục riêng
      # (không xóa), bật lại thì chuyển về Plugins. Có hiệu lực sau khi khởi động lại SketchUp.
      module Toggle
        PM  = VGD::Center::Manager
        Log = PM::Log

        def self.year
          (2000 + Sketchup.version.to_i).to_s
        end

        # Dữ liệu (plugin đã tắt, bộ plugin) nằm trong thư mục của Center: Plugins/VGD_Center/data.
        # VGD_Center bị bỏ qua khi quét plugin (SELF_NAMES) nên các mục đã tắt không hiện lại trong danh sách.
        def self.root_dir
          File.join(PM.plugins_dir(year), 'VGD_Center', 'data')
        end

        # Các vị trí cũ, theo thứ tự chuyển: VGD Plugin Manager beta.4 trở đi (trong Plugins), rồi beta.3 (ngoài Plugins).
        def self.old_roots
          plugins = PM.plugins_dir(year)
          [File.join(plugins, 'VGD_PluginManager', 'data'), File.join(File.dirname(plugins), 'VGD_PluginManager')]
        end

        # Chuyển dữ liệu từ các vị trí cũ vào vị trí mới. Trả về báo cáo { moved:, kept:, old_pm: } hoặc nil nếu không có gì.
        # An toàn với dữ liệu: chỉ đổi chỗ từng mục (mv), không bao giờ xóa đệ quy; mục trùng tên ở chỗ mới thì giữ nguyên
        # ở chỗ cũ (kept); lỗi giữa chừng để các mục còn lại nằm yên chỗ cũ. Lỗi được ném ra cho nơi gọi xử lý.
        def self.migrate_old_data
          moved = []
          kept = []
          old_roots.each do |old|
            next unless File.directory?(old)
            m, k = merge_old_root(old)
            moved.concat(m)
            kept.concat(k.map { |name| File.join(old, name) })
            prune_empty(old)
          end
          prune_empty(File.join(PM.plugins_dir(year), 'VGD_PluginManager'))
          return nil if moved.empty? && kept.empty?
          # Plugin Manager cũ còn cài thì nó không thấy dữ liệu đã chuyển
          { moved: moved, kept: kept, old_pm: File.exist?(File.join(PM.plugins_dir(year), 'VGD_PluginManager.rb')) }
        end

        # Thông báo cho một hoặc nhiều báo cáo chuyển dữ liệu, theo ngôn ngữ hiện tại. nil nếu không có gì.
        def self.migration_message(*reports)
          reports = reports.compact
          return nil if reports.empty?
          moved = reports.flat_map { |r| r[:moved] }
          kept = reports.flat_map { |r| r[:kept] }
          lines = []
          lines << PM.t(:data_moved, n: moved.size, dir: root_dir) unless moved.empty?
          lines << PM.t(:data_kept, n: kept.size, names: kept.join(', ')) unless kept.empty?
          lines << PM.t(:old_pm_present) if !moved.empty? && reports.any? { |r| r[:old_pm] }
          lines.empty? ? nil : lines.join("\n")
        end

        # Gộp một thư mục dữ liệu cũ vào thư mục mới. Trả về [các mục đã chuyển, các mục giữ lại].
        def self.merge_old_root(old)
          moved = []
          kept = []
          FileUtils.mkdir_p(disabled_dir)
          old_disabled = File.join(old, 'disabled')
          if File.directory?(old_disabled)
            Dir.children(old_disabled).each do |entry|
              dst = File.join(disabled_dir, entry)
              if File.exist?(dst)
                kept << File.join('disabled', entry)
              else
                FileUtils.mv(File.join(old_disabled, entry), dst)
                moved << entry
              end
            end
          end
          old_sets = File.join(old, 'sets.json')
          if File.file?(old_sets)
            merge_sets_file(old_sets) ? moved << 'sets.json' : kept << 'sets.json'
          end
          [moved, kept]
        end

        # Gộp bộ plugin của file cũ vào file mới (bộ cùng tên ở chỗ mới được ưu tiên) rồi xóa file cũ.
        # File cũ hỏng hoặc sai kiểu thì giữ nguyên và trả về false.
        def self.merge_sets_file(old_sets)
          old = JSON.parse(File.read(old_sets, encoding: 'UTF-8'))
          return false unless old.is_a?(Hash)
          save_sets(old.select { |_k, v| v.is_a?(Array) }.merge(load_sets))
          File.delete(old_sets)
          true
        rescue StandardError
          false
        end

        # Xóa thư mục nếu rỗng (và thư mục disabled rỗng bên trong). Không bao giờ xóa thư mục còn nội dung.
        def self.prune_empty(dir)
          disabled = File.join(dir, 'disabled')
          Dir.rmdir(disabled) if File.directory?(disabled) && Dir.empty?(disabled)
          Dir.rmdir(dir) if File.directory?(dir) && Dir.empty?(dir)
        rescue StandardError
          nil
        end

        def self.disabled_dir
          File.join(root_dir, 'disabled')
        end

        def self.sets_file
          File.join(root_dir, 'sets.json')
        end

        # Các plugin trong một thư mục: { 'ten' => { items: [...], members: [...] } } (xem linker.rb)
        def self.group_dir(dir)
          PM::Linker.group(dir, PM::SKIP_NAMES + PM::SELF_NAMES)
        end

        # { 'ten' => ['ten.rb', 'ten'] }
        def self.list_dir(dir)
          group_dir(dir).transform_values { |g| g[:items] }
        end

        def self.load_sets
          return {} unless File.exist?(sets_file)
          data = JSON.parse(File.read(sets_file, encoding: 'UTF-8'))
          data.is_a?(Hash) ? data.select { |_k, v| v.is_a?(Array) } : {}
        rescue
          {}
        end

        def self.save_sets(sets)
          FileUtils.mkdir_p(root_dir)
          File.write(sets_file, JSON.pretty_generate(sets), encoding: 'UTF-8')
        end

        def self.state
          on_g  = group_dir(PM.plugins_dir(year))
          off_g = group_dir(disabled_dir)
          on  = on_g.transform_values { |g| g[:items] }
          off = off_g.transform_values { |g| g[:items] }
          names = (on.keys + off.keys).uniq.sort_by(&:downcase)
          plugins = names.map do |n|
            st = if on.key?(n) && off.key?(n) then 'conflict'
                 elsif on.key?(n) then 'on'
                 else 'off'
                 end
            { 'name' => n, 'status' => st, 'items' => (on[n] || off[n]).size, 'members' => (on_g[n] || off_g[n])[:members] }
          end
          sets = load_sets.map do |k, v|
            { 'name' => k, 'names' => v, 'count' => v.size,
              'missing' => v.count { |x| !names.include?(x) } }
          end
          { 'year' => year, 'plugins' => plugins,
            'sets' => sets.sort_by { |s| s['name'].downcase },
            'disabled_dir' => disabled_dir }
        end

        # Chuyển các mục từ thư mục này sang thư mục kia. Lỗi thì hoàn tác. Trả về nil nếu ổn.
        def self.move_items(from_dir, to_dir, items)
          moved = []
          FileUtils.mkdir_p(to_dir)
          items.each do |item|
            src = File.join(from_dir, item)
            dst = File.join(to_dir, item)
            raise PM.t(:dest_exists, item: item) if File.exist?(dst)
            FileUtils.mv(src, dst)
            moved << item
          end
          nil
        rescue => e
          Log.write("Lỗi chuyển plugin từ #{from_dir} sang #{to_dir}, hoàn tác #{moved.size} mục", e)
          moved.each do |i|
            begin
              FileUtils.mv(File.join(to_dir, i), File.join(from_dir, i))
            rescue
              nil
            end
          end
          e.message
        end

        # action: 'disable' hoặc 'enable'. Chỉ dùng tên có trong danh sách thật.
        def self.change(names, action)
          plugins = PM.plugins_dir(year)
          on  = list_dir(plugins)
          off = list_dir(disabled_dir)
          res = { changed: [], skipped: [], errors: [] }
          Array(names).map(&:to_s).uniq.each do |n|
            if action == 'disable'
              unless on.key?(n)
                res[:skipped] << n
                next
              end
              if off.key?(n)
                res[:errors] << PM.t(:clash_disabled, name: n)
                next
              end
              err = move_items(plugins, disabled_dir, on[n])
            else
              unless off.key?(n)
                res[:skipped] << n
                next
              end
              if on.key?(n)
                res[:errors] << PM.t(:clash_plugins, name: n)
                next
              end
              err = move_items(disabled_dir, plugins, off[n])
            end
            err ? res[:errors] << "#{n}: #{err}" : res[:changed] << n
          end
          res
        end

        # Tên có chứa "lib" thường là thư viện nền (TT_Lib2, Fredo6_!LibFredo6, 5d_library...). Chỉ để cảnh báo.
        LIBRARY_PATTERN = /lib/i

        def self.library_like(names)
          Array(names).select { |n| n =~ LIBRARY_PATTERN }
        end

        # Tên thật sự đổi được khi tắt/bật hàng loạt: đúng trạng thái nguồn, không trùng tên, có trong danh sách thật
        def self.bulk_targets(names, action)
          want = action == 'enable' ? 'off' : 'on'
          valid = state['plugins'].select { |p| p['status'] == want }.map { |p| p['name'] }
          Array(names).map(&:to_s).uniq & valid
        end

        # Nội dung hộp xác nhận cho tắt/bật hàng loạt
        def self.bulk_confirm_text(targets, action)
          if action == 'enable'
            return PM.t(:confirm_enable, n: targets.size)
          end
          text = PM.t(:confirm_disable_head, n: targets.size)
          libs = library_like(targets)
          unless libs.empty?
            shown = libs.first(6).join(', ')
            shown += PM.t(:libs_more, n: libs.size - 6) if libs.size > 6
            text += PM.t(:confirm_libs, shown: shown)
          end
          text + PM.t(:confirm_disable_tail)
        end

        def self.summary(res, action)
          msg = [PM.t(action == 'disable' ? :sum_disabled : :sum_enabled, n: res[:changed].size)]
          msg << PM.t(:sum_skipped, n: res[:skipped].size) if res[:skipped].any?
          msg << PM.t(:sum_errors, errors: res[:errors].join('; ')) if res[:errors].any?
          msg << PM.t(:sum_restart) if res[:changed].any?
          msg.join("\n")
        end

        def self.save_set(name, names)
          name = name.to_s.strip[0, 40]
          return PM.t(:set_need_name) if name.empty?
          valid = state['plugins'].map { |p| p['name'] }
          picked = Array(names).map(&:to_s).uniq & valid
          return PM.t(:set_need_pick) if picked.empty?
          sets = load_sets
          sets[name] = picked
          save_sets(sets)
          PM.t(:set_saved, name: name, n: picked.size)
        rescue => e
          PM.report_error(PM.t(:err_save_set), e)
        end

        def self.delete_set(name)
          sets = load_sets
          return PM.t(:set_not_found) unless sets.delete(name.to_s)
          save_sets(sets)
          PM.t(:set_deleted, name: name)
        rescue => e
          PM.report_error(PM.t(:err_delete_set), e)
        end

        SETS_FORMAT = 'vgd_plugin_sets'

        # Xuất tất cả bộ plugin ra file .json để mang sang máy khác
        def self.export_sets(path)
          sets = load_sets
          return PM.t(:sets_none) if sets.empty?
          path = "#{path}.json" unless path =~ /\.json\z/i
          data = { 'format' => SETS_FORMAT, 'version' => 1,
                   'tool_version' => VGD::Center::VERSION, 'sets' => sets }
          File.write(path, JSON.pretty_generate(data), encoding: 'UTF-8')
          PM.t(:sets_exported, n: sets.size, path: path)
        rescue => e
          PM.report_error(PM.t(:err_export_sets), e)
        end

        # Đọc file bộ plugin. Trả về [bộ_đã_làm_sạch, lỗi]; chỉ nhận chuỗi, bỏ mục sai kiểu.
        # File xuất từ bản beta cũ có thêm mục 'layouts' thì bỏ qua mục đó.
        def self.read_sets_file(path)
          data = JSON.parse(File.read(path, encoding: 'UTF-8'))
          raw = data.is_a?(Hash) && data['format'] == SETS_FORMAT ? data['sets'] : nil
          return [nil, PM.t(:sets_bad_format)] unless raw.is_a?(Hash)
          clean = {}
          raw.each do |k, v|
            name = k.to_s.strip[0, 40]
            next if name.empty? || !v.is_a?(Array)
            names = v.select { |x| x.is_a?(String) && !x.strip.empty? }.map(&:strip).uniq
            clean[name] = names unless names.empty?
          end
          return [nil, PM.t(:sets_none_valid)] if clean.empty?
          [clean, nil]
        rescue => e
          [nil, PM.report_error(PM.t(:err_read_sets), e)]
        end

        # Gộp bộ nhập vào bộ hiện có. Trùng tên: overwrite=true thì ghi đè, false thì bỏ qua.
        def self.import_sets(incoming, overwrite)
          sets = load_sets
          added = skipped = replaced = 0
          incoming.each do |name, names|
            if sets.key?(name)
              if overwrite
                replaced += 1
              else
                skipped += 1
                next
              end
            else
              added += 1
            end
            sets[name] = names
          end
          save_sets(sets) if added + replaced > 0
          msg = PM.t(:sets_imported, added: added, replaced: replaced)
          msg += PM.t(:sets_import_skipped, n: skipped) if skipped > 0
          msg
        rescue => e
          PM.report_error(PM.t(:err_import_sets), e)
        end

        def self.desktop_dir
          File.join(ENV['USERPROFILE'].to_s.tr('\\', '/'), 'Desktop')
        end

      end
    end
  end
end
