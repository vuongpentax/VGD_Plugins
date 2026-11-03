# encoding: UTF-8
require 'sketchup.rb'
require 'fileutils'
require 'json'

module VGD
  module PluginManager
    # Quản lý bật/tắt plugin: plugin bị tắt được chuyển sang thư mục riêng
    # (không xóa), bật lại thì chuyển về Plugins. Có hiệu lực sau khi khởi động lại SketchUp.
    module Toggle
      PM  = VGD::PluginManager
      Log = PM::Log

      def self.year
        (2000 + Sketchup.version.to_i).to_s
      end

      # Dữ liệu nằm ngay trong thư mục của plugin (trong Plugins). Thư mục VGD_PluginManager bị
      # bỏ qua khi quét plugin nên các mục đã tắt không hiện lại trong danh sách.
      def self.root_dir
        File.join(PM.plugins_dir(year), 'VGD_PluginManager', 'data')
      end

      # Vị trí cũ (beta.3 trở về trước): ngoài thư mục Plugins
      def self.legacy_root_dir
        File.join(File.dirname(PM.plugins_dir(year)), 'VGD_PluginManager')
      end

      # Chuyển dữ liệu từ vị trí cũ sang vị trí mới, một lần. Không ghi đè nếu vị trí mới đã có.
      # Trả về thông báo hoặc nil.
      def self.migrate_legacy
        old = legacy_root_dir
        return nil unless File.directory?(old)
        return nil if File.exist?(root_dir)
        FileUtils.mkdir_p(File.dirname(root_dir))
        FileUtils.mv(old, root_dir)
        "Đã chuyển dữ liệu bật/tắt cũ vào #{root_dir}."
      rescue => e
        PM.report_error('Không chuyển được dữ liệu bật/tắt cũ', e)
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
          raise "#{item} đã tồn tại ở thư mục đích" if File.exist?(dst)
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
              res[:errors] << "#{n}: đã có bản cùng tên trong thư mục tắt, cần xử lý thủ công"
              next
            end
            err = move_items(plugins, disabled_dir, on[n])
          else
            unless off.key?(n)
              res[:skipped] << n
              next
            end
            if on.key?(n)
              res[:errors] << "#{n}: đã có bản cùng tên trong Plugins, cần xử lý thủ công"
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
          return "Bật #{targets.size} plugin?\n\nThay đổi có hiệu lực sau khi khởi động lại SketchUp."
        end
        text = "Tắt #{targets.size} plugin (gồm cả plugin VGD nếu có)?\n\n"
        libs = library_like(targets)
        unless libs.empty?
          shown = libs.first(6).join(', ')
          shown += " và #{libs.size - 6} mục khác" if libs.size > 6
          text += "Có thể có thư viện nền mà plugin khác cần: #{shown}. Tắt chúng có thể làm plugin khác lỗi khi mở lại.\n\n"
        end
        text + "Thay đổi có hiệu lực sau khi khởi động lại SketchUp. Có thể bật lại bằng nút \"Bật tất cả\"."
      end

      def self.summary(res, action)
        verb = action == 'disable' ? 'Đã tắt' : 'Đã bật'
        msg = ["#{verb}: #{res[:changed].size} plugin."]
        msg << "Bỏ qua (đã ở trạng thái đó hoặc không tìm thấy): #{res[:skipped].size}." if res[:skipped].any?
        msg << "Lỗi: #{res[:errors].join('; ')}" if res[:errors].any?
        msg << 'Khởi động lại SketchUp để thay đổi có hiệu lực.' if res[:changed].any?
        msg.join("\n")
      end

      def self.save_set(name, names)
        name = name.to_s.strip[0, 40]
        return 'Hãy nhập tên cho bộ plugin.' if name.empty?
        valid = state['plugins'].map { |p| p['name'] }
        picked = Array(names).map(&:to_s).uniq & valid
        return 'Hãy tick ít nhất một plugin để lưu thành bộ.' if picked.empty?
        sets = load_sets
        sets[name] = picked
        save_sets(sets)
        "Đã lưu bộ \"#{name}\" gồm #{picked.size} plugin."
      rescue => e
        PM.report_error('Không lưu được bộ', e)
      end

      def self.delete_set(name)
        sets = load_sets
        return 'Không tìm thấy bộ này.' unless sets.delete(name.to_s)
        save_sets(sets)
        "Đã xóa bộ \"#{name}\" (các plugin không bị ảnh hưởng)."
      rescue => e
        PM.report_error('Không xóa được bộ', e)
      end

      SETS_FORMAT = 'vgd_plugin_sets'

      # Xuất tất cả bộ plugin ra file .json để mang sang máy khác
      def self.export_sets(path)
        sets = load_sets
        return 'Chưa có bộ plugin nào để xuất.' if sets.empty?
        path = "#{path}.json" unless path =~ /\.json\z/i
        data = { 'format' => SETS_FORMAT, 'version' => 1,
                 'tool_version' => PM::VERSION, 'sets' => sets }
        File.write(path, JSON.pretty_generate(data), encoding: 'UTF-8')
        "Đã xuất #{sets.size} bộ plugin ra: #{path}"
      rescue => e
        PM.report_error('Không xuất được bộ plugin', e)
      end

      # Đọc file bộ plugin. Trả về [bộ_đã_làm_sạch, lỗi]; chỉ nhận chuỗi, bỏ mục sai kiểu.
      # File xuất từ bản beta cũ có thêm mục 'layouts' thì bỏ qua mục đó.
      def self.read_sets_file(path)
        data = JSON.parse(File.read(path, encoding: 'UTF-8'))
        raw = data.is_a?(Hash) && data['format'] == SETS_FORMAT ? data['sets'] : nil
        return [nil, 'File không đúng định dạng bộ plugin của VGD.'] unless raw.is_a?(Hash)
        clean = {}
        raw.each do |k, v|
          name = k.to_s.strip[0, 40]
          next if name.empty? || !v.is_a?(Array)
          names = v.select { |x| x.is_a?(String) && !x.strip.empty? }.map(&:strip).uniq
          clean[name] = names unless names.empty?
        end
        return [nil, 'File không có bộ plugin hợp lệ nào.'] if clean.empty?
        [clean, nil]
      rescue => e
        [nil, PM.report_error('Không đọc được file bộ plugin', e)]
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
        msg = "Đã nhập: #{added} bộ mới, #{replaced} bộ ghi đè."
        msg += " Bỏ qua #{skipped} bộ trùng tên." if skipped > 0
        msg
      rescue => e
        PM.report_error('Không nhập được bộ plugin', e)
      end

      def self.desktop_dir
        File.join(ENV['USERPROFILE'].to_s.tr('\\', '/'), 'Desktop')
      end

    end
  end
end
