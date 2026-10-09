# encoding: UTF-8
require 'sketchup.rb'
require 'json'
require 'digest'
require 'fileutils'
require 'tmpdir'
require 'securerandom'

module VGD
  module Center
    VERSION = '1.0.1'.freeze
    CATALOG_URL = 'https://raw.githubusercontent.com/vuongpentax/VGD_Plugins/main/shared/vgd-center/catalog.json'.freeze
    ALLOWED_IDS = %w[dim cabinet library image_importer scenes bim_lite].freeze
    PLUGIN_LAYOUTS = {
      'dim' => ['VGD Dim', ['vgd_dim.rb', 'VGD_Dim/']],
      'cabinet' => ['VGD Cabinet', ['vgd_cabinet.rb', 'VGD_Cabinet/']],
      'library' => ['VGD Library', ['vgd_library.rb', 'vgd_library/']],
      'image_importer' => ['VGD Image Importer', ['vgd_image_importer.rb', 'vgd_image_importer/']],
      'scenes' => ['VGD Scenes', ['vgd_scenes.rb', 'vgd_scenes/']],
      'bim_lite' => ['VGD BIM Lite', ['vgd_bim_lite.rb', 'vgd_bim_lite/']]
    }.freeze
    MAX_PACKAGE_BYTES = 100 * 1024 * 1024
    MAX_ARCHIVE_FILES = 5000

    class << self
      def show_dialog
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
          return
        end

        @catalog ||= read_bundled_catalog
        @dialog = UI::HtmlDialog.new(
          dialog_title: 'VGD Center',
          preferences_key: 'com.vgd.center.dialog.v1',
          scrollable: true,
          resizable: true,
          width: 1180,
          height: 760,
          min_width: 700,
          min_height: 560,
          style: UI::HtmlDialog::STYLE_WINDOW
        )
        register_callbacks(@dialog)
        @dialog.set_file(File.join(__dir__, 'dialog.html'))
        @dialog.set_can_close do
          if @busy
            UI.messagebox('VGD Center đang cài plugin. Hãy đợi thao tác hiện tại hoàn tất rồi đóng cửa sổ.')
            false
          else
            true
          end
        end
        @dialog.set_on_closed do
          @dialog = nil
        end
        @dialog.center
        @dialog.show
        UI.start_timer(0.2, false) { refresh_catalog }
      rescue StandardError => error
        @dialog = nil
        UI.messagebox("Không thể mở VGD Center.\n#{error.message}")
      end

      def register_callbacks(dialog)
        dialog.add_action_callback('center_ready') { |_context| send_state }
        dialog.add_action_callback('refresh_catalog') { |_context| refresh_catalog }
        dialog.add_action_callback('install_plugin') do |_context, plugin_id|
          queue_plugins([plugin_id])
        end
        dialog.add_action_callback('install_updates') do |_context|
          update_ids = current_products.select { |product| product[:action] == 'update' }.map { |product| product[:id] }
          if update_ids.empty?
            notify('info', 'Đã cập nhật', 'Các plugin đã cài đều đang ở phiên bản mới nhất.')
          else
            queue_plugins(update_ids)
          end
        end
      end

      def refresh_catalog
        return if @catalog_request

        set_status('Đang lấy danh mục phiên bản mới nhất từ GitHub…')
        @catalog_request = Sketchup::Http::Request.new(CATALOG_URL)
        started = @catalog_request.start do |_request, response|
          @catalog_request = nil
          if response && response.status_code == 200
            begin
              @catalog = validate_catalog(JSON.parse(response.body))
              @catalog_error = nil
              @last_sync = Time.now
              set_status('Đã đồng bộ danh mục phiên bản mới nhất từ GitHub')
            rescue StandardError => error
              @catalog_error = "Catalog GitHub không hợp lệ: #{error.message}"
              load_fallback_catalog
            end
          else
            @catalog_error = 'Không thể kết nối danh mục GitHub; đang dùng danh mục đi kèm VGD Center.'
            load_fallback_catalog
          end
          send_state
        end
        unless started
          @catalog_request = nil
          @catalog_error = 'Không thể bắt đầu kết nối GitHub; đang dùng danh mục đi kèm.'
          load_fallback_catalog
          send_state
        end
      rescue StandardError => error
        @catalog_request = nil
        @catalog_error = "Không thể kiểm tra GitHub: #{error.message}"
        load_fallback_catalog
        send_state
      end

      def read_bundled_catalog
        path = File.join(__dir__, 'catalog.json')
        validate_catalog(JSON.parse(File.read(path, encoding: 'UTF-8')))
      rescue StandardError
        { 'schema_version' => 1, 'channel' => 'latest', 'products' => [] }
      end

      def load_fallback_catalog
        @catalog = read_bundled_catalog
        set_status(@catalog_error || 'Đang dùng danh mục mới nhất đi kèm VGD Center')
      end

      def validate_catalog(catalog)
        raise 'sai phiên bản catalog' unless catalog.is_a?(Hash) && catalog['schema_version'] == 1
        raise 'catalog không ở kênh latest' unless catalog['channel'] == 'latest'
        products = catalog['products']
        raise 'thiếu danh sách plugin' unless products.is_a?(Array)

        ids = []
        normalized = products.map do |product|
          raise 'mục plugin không hợp lệ' unless product.is_a?(Hash)
          id = product['id'].to_s
          raise "plugin không được phép: #{id}" unless ALLOWED_IDS.include?(id)
          raise "trùng plugin: #{id}" if ids.include?(id)
          ids << id
          expected_name, expected_paths = PLUGIN_LAYOUTS.fetch(id)
          raise "tên extension không hợp lệ: #{id}" unless product['extension_name'] == expected_name

          version = product['version'].to_s
          version_match = version.match(/\A(\d+)\.(\d+)\.(\d+)(?:-(alpha|beta)(?:\.(\d+))?)?\z/)
          raise "phiên bản không hợp lệ: #{id}" unless version_match
          release_channel = product['release_channel'].to_s
          expected_channel = version_match[4] || 'stable'
          raise "kênh phát hành không khớp phiên bản: #{id}" unless release_channel == expected_channel
          download = product['download']
          raise "thiếu gói tải: #{id}" unless download.is_a?(Hash)
          filename = download['filename'].to_s
          raise "tên gói không hợp lệ: #{id}" unless filename.match?(/\A[A-Za-z0-9_.-]+\.rbz\z/i)
          raise "tên gói không khớp phiên bản: #{id}" unless filename.include?(version)
          url = download['url'].to_s
          allowed_url = url.start_with?('https://raw.githubusercontent.com/vuongpentax/VGD_Plugins/') ||
                        url.start_with?('https://github.com/vuongpentax/VGD_Plugins/releases/download/')
          unless allowed_url && url.end_with?("/#{filename}")
            raise "nguồn tải không được phép: #{id}"
          end
          size = Integer(download['size'])
          raise "dung lượng gói không hợp lệ: #{id}" unless size.positive? && size <= MAX_PACKAGE_BYTES
          sha = download['sha256'].to_s.downcase
          raise "SHA-256 không hợp lệ: #{id}" unless sha.match?(/\A[0-9a-f]{64}\z/)
          paths = product['allowed_paths']
          raise "thiếu đường dẫn gói được phép: #{id}" unless paths.is_a?(Array) && !paths.empty?
          raise "cấu trúc gói không hợp lệ: #{id}" unless paths == expected_paths

          product
        end
        catalog.merge('products' => normalized)
      end

      def current_products
        catalog = @catalog || read_bundled_catalog
        sketchup_version = Sketchup.version.to_s
        catalog['products'].map do |product|
          extension = Sketchup.extensions[product['extension_name']]
          installed_version = extension && extension.version.to_s
          installed = !installed_version.to_s.empty?
          min_ok = compare_versions(sketchup_version, product['minimum_sketchup'].to_s) >= 0
          action = if !min_ok
                     nil
                   elsif !installed
                     'install'
                   elsif compare_versions(installed_version, product['version']) < 0
                     'update'
                   end
          {
            id: product['id'], name: product['name'], description: product['description'],
            version: product['version'], release_channel: product['release_channel'], icon: product['icon'], minimum_sketchup: product['minimum_sketchup'],
            installed: installed, installed_version: installed_version, action: action,
            compatible: min_ok, filename: product.dig('download', 'filename')
          }
        end
      rescue StandardError => error
        set_status("Không đọc được danh sách extension: #{error.message}")
        []
      end

      def compare_versions(left, right)
        a_match = left.to_s.match(/\A(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?\z/)
        b_match = right.to_s.match(/\A(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?\z/)
        return 0 unless a_match && b_match
        a = a_match.captures.first(3).map(&:to_i)
        b = b_match.captures.first(3).map(&:to_i)
        3.times do |index|
          result = (a[index] || 0) <=> (b[index] || 0)
          return result unless result.zero?
        end
        a_pre = a_match[4]
        b_pre = b_match[4]
        return 0 if a_pre == b_pre
        return 1 if a_pre.nil?
        return -1 if b_pre.nil?
        a_ids = a_pre.split('.')
        b_ids = b_pre.split('.')
        [a_ids.length, b_ids.length].min.times do |index|
          a_id = a_ids[index]
          b_id = b_ids[index]
          next if a_id == b_id
          a_numeric = a_id.match?(/\A\d+\z/)
          b_numeric = b_id.match?(/\A\d+\z/)
          return a_id.to_i <=> b_id.to_i if a_numeric && b_numeric
          return -1 if a_numeric
          return 1 if b_numeric
          return a_id <=> b_id
        end
        a_ids.length <=> b_ids.length
      end

      def send_state
        return unless @dialog
        payload = {
          version: VERSION,
          sketchup: Sketchup.version.to_s,
          products: current_products,
          last_sync: @last_sync ? @last_sync.strftime('%H:%M · %d/%m/%Y') : nil,
          source_status: @catalog_error ? 'Dùng danh mục đi kèm' : (@last_sync ? 'Đã đồng bộ GitHub' : 'Danh mục mới nhất'),
          message: @catalog_error
        }
        script = "window.VGD && window.VGD.receiveState(#{JSON.generate(payload).gsub('</', '<\\/')});"
        @dialog.execute_script(script)
      end

      def set_status(message)
        return unless @dialog
        @dialog.execute_script("window.VGD && window.VGD.setStatus(#{JSON.generate(message)});")
      end

      def notify(kind, title, message)
        return unless @dialog
        script = "window.VGD && window.VGD.notify(#{JSON.generate(kind)}, #{JSON.generate(title)}, #{JSON.generate(message)});"
        @dialog.execute_script(script)
      end

      def queue_plugins(ids)
        return notify('error', 'Đang có thao tác', 'Hãy đợi thao tác hiện tại hoàn tất.') if @busy
        products = Array(ids).map do |id|
          @catalog['products'].find { |product| product['id'] == id.to_s }
        end.compact
        return notify('error', 'Plugin không có trong danh mục', 'Chỉ có thể cài plugin VGD đã được duyệt trong danh mục.') if products.empty?
        incompatible = products.find do |product|
          compare_versions(Sketchup.version.to_s, product['minimum_sketchup'].to_s) < 0
        end
        if incompatible
          return notify('error', 'SketchUp chưa tương thích', "#{incompatible['name']} cần SketchUp #{incompatible['minimum_sketchup']} trở lên.")
        end

        @queue = products
        @queue_total = products.length
        @completed_count = 0
        @busy = true
        process_next
      end

      def process_next
        product = @queue.shift
        unless product
          @busy = false
          send_state
          notify('success', 'Đã hoàn tất', "Đã cài hoặc cập nhật #{@completed_count} plugin. Hãy lưu model và khởi động lại SketchUp để nạp phiên bản mới.")
          return
        end

        installed = Sketchup.extensions[product['extension_name']]
        installed_version = installed && installed.version.to_s
        if installed_version && compare_versions(installed_version, product['version']) >= 0
          process_next
          return
        end

        download_and_install(product)
      end

      def download_and_install(product)
        package = product['download']
        report_progress(product['id'], 'Đang tải gói', 0, package['size'])
        @download_request = Sketchup::Http::Request.new(package['url'])
        @download_request.set_download_progress_callback do |current, total|
          report_progress(product['id'], 'Đang tải gói', current, total)
        end
        started = @download_request.start do |_request, response|
          @download_request = nil
          begin
            raise 'GitHub không trả về gói tải hợp lệ.' unless response && response.status_code == 200
            content = response.body
            raise 'Dung lượng tải về không khớp catalog.' unless content.bytesize == package['size']
            temp_path = File.join(Dir.tmpdir, "vgd_center_#{SecureRandom.hex(10)}.rbz")
            File.binwrite(temp_path, content)
            raise 'SHA-256 của gói không khớp catalog.' unless Digest::SHA256.file(temp_path).hexdigest == package['sha256']

            report_progress(product['id'], 'Đang xác minh và cài đặt', package['size'], package['size'])
            install_verified_package(temp_path, product)
            safe_delete(temp_path)
            @completed_count += 1
            process_next
          rescue Interrupt
            safe_delete(temp_path) if defined?(temp_path) && temp_path
            stop_queue('Đã hủy', 'Bạn đã hủy thao tác cài đặt.')
          rescue StandardError => error
            safe_delete(temp_path) if defined?(temp_path) && temp_path
            stop_queue('Không thể cài plugin', error.message)
          end
        end
        unless started
          @download_request = nil
          stop_queue('Không thể tải plugin', 'SketchUp không thể bắt đầu yêu cầu tải xuống.')
        end
      rescue StandardError => error
        @download_request = nil
        stop_queue('Không thể tải plugin', error.message)
      end

      def report_progress(plugin_id, phase, current, total)
        return unless @dialog
        payload = { id: plugin_id, phase: phase, current: current.to_i, total: total.to_i }
        @dialog.execute_script("window.VGD && window.VGD.progress(#{JSON.generate(payload)});")
      end

      def stop_queue(title, message)
        if @completed_count.to_i.positive?
          title = 'Đã cài một phần'
          message = "Đã hoàn tất #{@completed_count} trong #{@queue_total} plugin trước khi gặp lỗi. Hãy lưu model, khởi động lại SketchUp rồi thử lại plugin còn lại. #{message}"
        end
        @queue = []
        @busy = false
        send_state
        notify('error', title, message)
      end

      def safe_delete(path)
        File.delete(path) if path && File.file?(path)
      rescue StandardError
        nil
      end

      def install_verified_package(archive_path, product)
        entries = read_archive_entries(archive_path)
        allowed_paths = product['allowed_paths']
        files = entries.reject { |entry| entry[:directory] }
        raise 'Gói không có file cài đặt.' if files.empty?
        unless files.any? { |entry| entry[:path] == allowed_paths.first }
          raise 'Gói không chứa loader của plugin đã khai báo.'
        end
        files.each do |entry|
          allowed = allowed_paths.any? do |path|
            path.end_with?('/') ? entry[:path].start_with?(path) : entry[:path] == path
          end
          raise "Gói chứa đường dẫn không được phép: #{entry[:path]}" unless allowed
        end

        plugin_root = File.expand_path(Sketchup.find_support_file('Plugins'))
        backup_dir = Dir.mktmpdir('vgd-center-backup-')
        previous = {}
        begin
          files.each do |entry|
            target = safe_target(plugin_root, entry[:path])
            if File.file?(target) && !File.symlink?(target)
              backup = File.join(backup_dir, *entry[:path].split('/'))
              FileUtils.mkdir_p(File.dirname(backup))
              FileUtils.cp(target, backup)
              previous[entry[:path]] = true
            elsif File.exist?(target) || File.symlink?(target)
              raise "Không thể sao lưu đường dẫn cài hiện có: #{entry[:path]}"
            else
              previous[entry[:path]] = false
            end
          end

          installed = Sketchup.install_from_archive(archive_path, false)
          raise 'SketchUp không xác nhận cài đặt thành công.' unless installed
        rescue StandardError, Interrupt => error
          restore_archive_files(plugin_root, backup_dir, previous)
          raise error
        ensure
          begin
            FileUtils.remove_entry(backup_dir) if File.directory?(backup_dir)
          rescue StandardError
            nil
          end
        end
      end

      def safe_target(root, relative)
        raise 'Đường dẫn tuyệt đối không được phép.' unless safe_relative_path?(relative)
        raise 'Thư mục plugin là liên kết tượng trưng.' if File.symlink?(root)
        target = File.expand_path(File.join(root, *relative.split('/')))
        root_prefix = root.end_with?(File::SEPARATOR) ? root : root + File::SEPARATOR
        unless target.downcase.start_with?(root_prefix.downcase)
          raise 'Đường dẫn gói thoát khỏi thư mục plugin.'
        end
        cursor = root
        relative.split('/')[0...-1].each do |segment|
          cursor = File.join(cursor, segment)
          raise 'Thư mục đích là liên kết tượng trưng.' if File.symlink?(cursor)
          raise 'Đường dẫn đích không phải thư mục.' if File.exist?(cursor) && !File.directory?(cursor)
        end
        target
      end

      def safe_relative_path?(path)
        return false unless path.is_a?(String) && !path.empty?
        return false if path.include?("\0") || path.include?('\\') || path.start_with?('/')
        return false if path.match?(/\A[A-Za-z]:/)
        parts = path.split('/')
        !parts.any? { |part| part.empty? || part == '.' || part == '..' }
      end

      def restore_archive_files(plugin_root, backup_dir, previous)
        previous.each do |relative, existed|
          target = safe_target(plugin_root, relative)
          if existed
            backup = File.join(backup_dir, *relative.split('/'))
            if File.file?(backup)
              FileUtils.mkdir_p(File.dirname(target))
              FileUtils.cp(backup, target)
            end
          elsif File.file?(target) && !File.symlink?(target)
            File.delete(target)
          end
        rescue StandardError
          # Keep attempting the remaining rollback paths.
        end
      end

      def read_archive_entries(path)
        bytes = File.binread(path)
        eocd = bytes.rindex("PK\x05\x06".b)
        raise 'Gói RBZ không phải ZIP hợp lệ.' unless eocd
        record = bytes.byteslice(eocd, 22)
        raise 'Thiếu thông tin kết thúc ZIP.' unless record && record.bytesize == 22
        signature, disk, central_disk, disk_entries, total_entries, central_size, central_offset, = record.unpack('VvvvvVVv')
        raise 'Định dạng ZIP không được hỗ trợ.' unless signature == 0x06054b50 && disk.zero? && central_disk.zero? && disk_entries == total_entries
        raise 'Gói ZIP quá lớn hoặc không hợp lệ.' if total_entries > MAX_ARCHIVE_FILES || central_offset + central_size > bytes.bytesize

        entries = []
        position = central_offset
        names = {}
        uncompressed_total = 0
        total_entries.times do
          header = bytes.byteslice(position, 46)
          raise 'Mục ZIP bị hỏng.' unless header && header.bytesize == 46
          fields = header.unpack('VvvvvvvVVVvvvvvVV')
          sig, _made_by, _needed, flags, _method, _time, _date, _crc, compressed, uncompressed, name_length, extra_length, comment_length, _disk_start, _internal_attr, external_attr, = fields
          raise 'Mục ZIP không hợp lệ.' unless sig == 0x02014b50
          raise 'Không hỗ trợ gói ZIP mã hóa hoặc ZIP64.' if (flags & 1) != 0 || compressed == 0xffffffff || uncompressed == 0xffffffff
          name_bytes = bytes.byteslice(position + 46, name_length)
          raise 'Tên file trong ZIP không hợp lệ.' unless name_bytes && name_bytes.bytesize == name_length
          name = name_bytes.dup.force_encoding(Encoding::UTF_8)
          raise 'Tên file trong ZIP không phải UTF-8.' unless name.valid_encoding?
          directory = name.end_with?('/')
          relative = directory ? name[0...-1] : name
          raise 'Đường dẫn ZIP không an toàn.' unless safe_relative_path?(relative)
          key = relative.downcase
          raise 'Tên file ZIP bị trùng.' if names[key]
          names[key] = true
          unix_mode = (external_attr >> 16) & 0xffff
          raise 'Không hỗ trợ liên kết tượng trưng trong gói.' if (unix_mode & 0o170000) == 0o120000
          uncompressed_total += uncompressed
          raise 'Dung lượng giải nén vượt giới hạn.' if uncompressed_total > MAX_PACKAGE_BYTES
          entries << { path: relative, directory: directory, size: uncompressed }
          position += 46 + name_length + extra_length + comment_length
        end
        entries
      end

      unless file_loaded?(__FILE__)
        command = UI::Command.new('VGD Center') { show_dialog }
        command.tooltip = 'VGD Center'
        command.status_bar_text = 'Mở trung tâm cài đặt và cập nhật plugin VGD'
        icon = File.join(__dir__, 'icon.svg')
        command.small_icon = icon
        command.large_icon = icon
        UI.menu('Extensions').add_item(command)
        toolbar = UI::Toolbar.new('VGD Center')
        toolbar.add_item(command)
        toolbar.restore
        file_loaded(__FILE__)
      end
    end
  end
end
