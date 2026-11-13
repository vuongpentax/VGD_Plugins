# encoding: UTF-8
require 'sketchup.rb'
require 'fileutils'
require 'json'
require File.join(File.dirname(__FILE__), 'text')
require File.join(File.dirname(__FILE__), 'zip_writer')
require File.join(File.dirname(__FILE__), 'logger')
require File.join(File.dirname(__FILE__), 'linker')

module VGD
  module Center
    # Quản lý plugin trên máy: bật/tắt, chuyển plugin giữa các bản SketchUp, xuất gói .rbz tổng.
    # Mã chuyển từ VGD Plugin Manager 1.0.0-beta.17 vào VGD Center.
    module Manager
      APPDATA_SUBPATH = 'SketchUp/SketchUp %s/SketchUp/Plugins'

      # Không bao giờ tắt hay chuyển các mục này:
      # - VGD Center: tắt nhầm sẽ mất chính giao diện quản lý; thư mục vgd_center/data chứa plugin đã tắt.
      # - VGD Plugin Manager (và tên cũ vgd_plugin_migrator): plugin đã gộp vào Center, nhưng máy cũ có thể còn cài,
      #   và thư mục VGD_PluginManager/data là nơi dữ liệu cũ nằm cho tới khi được chuyển sang vgd_center/data.
      # So khớp không phân biệt hoa thường (xem Linker.group).
      SELF_NAMES = ['VGD_Center', 'VGD_Center.rb',
                    'VGD_PluginManager', 'VGD_PluginManager.rb', 'vgd_plugin_migrator', 'vgd_plugin_migrator.rb']
      # Các mục hệ thống của SketchUp, bỏ qua
      SKIP_NAMES = ['.', '..', 'su_dynamiccomponents', 'su_dynamiccomponents.rb',
                    'su_sandbox', 'su_sandbox.rb', 'su_solidtools', 'su_solidtools.rb']

      def self.appdata
        ENV['APPDATA'].to_s.tr('\\', '/')
      end

      # Ghi lỗi vào nhật ký và trả về câu thông báo cho người dùng
      def self.report_error(context, exc)
        Log.write(context, exc)
        "#{context}: #{exc.message}\n#{Log.hint}"
      end

      def self.plugins_dir(version)
        File.join(appdata, APPDATA_SUBPATH % version)
      end

      def self.installed_versions
        root = File.join(appdata, 'SketchUp')
        return [] unless File.directory?(root)
        Dir.children(root).map { |d| d[/SketchUp (\d{4})/, 1] }.compact.sort
      end

      # Plugin trong Plugins của một phiên bản: loader và thư mục đi kèm được gộp (xem linker.rb)
      def self.list_plugins(version)
        Linker.group(plugins_dir(version), SKIP_NAMES + SELF_NAMES)
              .map { |k, g| { name: k, items: g[:items], members: g[:members] } }
              .sort_by { |h| h[:name].downcase }
      end

      def self.backup(dir)
        return nil unless File.directory?(dir)
        dest = "#{dir}_backup_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
        FileUtils.cp_r(dir, dest)
        dest
      end

      def self.copy_plugins(src_ver, dst_ver, chosen, overwrite)
        src = plugins_dir(src_ver)
        dst = plugins_dir(dst_ver)
        FileUtils.mkdir_p(dst)
        backup_path = backup(dst)
        done, skipped, failed = [], [], []
        list_plugins(src_ver).each do |pl|
          next unless chosen.include?(pl[:name])
          # Một plugin gồm loader và thư mục: đã có ở đích mà không ghi đè thì bỏ qua cả plugin,
          # không chép riêng từng nửa (loader mới đi với thư mục cũ sẽ báo "không tìm thấy file").
          if !overwrite && pl[:items].any? { |item| File.exist?(File.join(dst, item)) }
            skipped.concat(pl[:items])
            next
          end
          pl[:items].each do |item|
            from = File.join(src, item)
            to   = File.join(dst, item)
            begin
              FileUtils.rm_rf(to) if File.exist?(to)
              FileUtils.cp_r(from, to)
              missing = verify_copy(from, to)
              if missing.empty?
                done << item
              else
                failed << "#{item}: #{t(:copy_incomplete, n: missing.size, sample: missing.first(3).join(', '))}"
              end
            rescue => e
              Log.write("Lỗi chép #{item} từ #{src_ver} sang #{dst_ver}", e)
              failed << "#{item}: #{e.message}"
            end
          end
        end
        { done: done, skipped: skipped, failed: failed, backup: backup_path }
      end

      # Danh sách file (đường dẫn tương đối => dung lượng) của một mục; mục là một file thì khóa rỗng.
      def self.tree_files(path)
        return { '' => File.size(path) } unless File.directory?(path)
        Dir.glob('**/*', File::FNM_DOTMATCH, base: path).each_with_object({}) do |rel, files|
          full = File.join(path, rel)
          files[rel] = File.size(full) if File.file?(full)
        end
      end

      # Sau khi chép: file nào của nguồn không có ở đích hoặc khác dung lượng (danh sách rỗng là chép đủ).
      def self.verify_copy(from, to)
        expected = tree_files(from)
        actual = File.exist?(to) ? tree_files(to) : {}
        expected.reject { |rel, size| actual[rel] == size }.keys.map { |rel| rel.empty? ? File.basename(from) : rel }
      end

      # Cảnh báo tương thích Ruby 2.7 -> 3.2 (chỉ mang tính tham khảo)
      RISKY_PATTERNS = {
        /\bFixnum\b|\bBignum\b/ => :risky_fixnum,
        /\bFile\.exists\?/      => :risky_file_exists,
        /\bDir\.exists\?/       => :risky_dir_exists,
        /\bURI\.escape\b/       => :risky_uri_escape,
        /\.taint\b|\.untaint\b/ => :risky_taint
      }

      MAX_SCAN_FILES = 5000
      BINARY_EXT = /\.(so|dll|dylib|bundle)\z/i

      # Plugin gắn với một phiên bản Ruby cụ thể: file mã hóa .rbe, RubyEncoder, thư viện nhị phân.
      def self.file_risks(item, path)
        names = [item]
        names += Dir.glob('**/*', File::FNM_DOTMATCH, base: path).first(MAX_SCAN_FILES) if File.directory?(path)
        risks = []
        risks << :risky_encrypted if names.any? { |n| n =~ /\.rbe\z/i }
        risks << :risky_rubyencoder if names.any? { |n| n =~ /rubyencoder/i }
        risks << :risky_binary if names.any? { |n| n =~ BINARY_EXT }
        risks
      end

      def self.scan_compat(src_ver, chosen)
        src = plugins_dir(src_ver)
        warns = []
        list_plugins(src_ver).each do |pl|
          next unless chosen.include?(pl[:name])
          pl[:items].each do |item|
            path  = File.join(src, item)
            file_risks(item, path).each { |key| warns << "#{pl[:name]}: #{t(key)}" }
            files = File.directory?(path) ? Dir.glob(File.join(path, '**', '*.rb')) : [path]
            files.each do |f|
              next unless f =~ /\.rb\z/i
              text = begin
                File.read(f, encoding: 'UTF-8', invalid: :replace, undef: :replace)
              rescue
                next
              end
              RISKY_PATTERNS.each do |re, key|
                warns << "#{pl[:name]}: #{t(key)}" if text =~ re
              end
            end
          end
        end
        warns.uniq
      end

      # ---- Xuất gói .rbz tổng ----
      # Gom file của các plugin đã chọn: [[đường_dẫn_tương_đối, dữ_liệu, thời_gian_sửa]]
      def self.collect_files(src_ver, chosen)
        src = plugins_dir(src_ver)
        entries = []
        list_plugins(src_ver).each do |pl|
          next unless chosen.include?(pl[:name])
          pl[:items].each do |item|
            path = File.join(src, item)
            if File.directory?(path)
              Dir.glob('**/*', File::FNM_DOTMATCH, base: path).sort.each do |rel|
                f = File.join(path, rel)
                next unless File.file?(f)
                entries << ["#{item}/#{rel}", File.binread(f), File.mtime(f)]
              end
            elsif File.file?(path)
              entries << [item, File.binread(path), File.mtime(path)]
            end
          end
        end
        entries
      end

      # Trả về { count:, path:, notes: } hoặc { error: }
      def self.build_bundle(src_ver, chosen, out_path)
        entries = collect_files(src_ver, chosen)
        return { error: t(:bundle_empty) } if entries.empty?
        out_path = "#{out_path}.rbz" unless out_path =~ /\.rbz\z/i
        ZipWriter.write(out_path, entries)
        { count: entries.size, path: out_path, notes: [] }
      rescue => e
        { error: report_error(t(:err_bundle), e) }
      end

      # Gọi một lần sau khi SketchUp khởi động: chuyển dữ liệu cũ về Plugins/vgd_center/data ngay, không đợi người dùng
      # mở tab. Nhờ vậy plugin đang tắt không bị xóa theo nếu người dùng gỡ Plugin Manager cũ trước khi mở tab.
      # Báo cáo được giữ lại để tab hiện thông báo (đúng ngôn ngữ) lần mở đầu tiên; lỗi chỉ ghi nhật ký.
      def self.migrate_on_start
        report = Toggle.migrate_old_data
        @startup_report = report if report
      rescue StandardError => e
        Log.write('Lỗi chuyển dữ liệu bật/tắt cũ lúc khởi động', e)
      end

      # Lấy (một lần) báo cáo chuyển dữ liệu lúc khởi động.
      def self.take_startup_report
        report = @startup_report
        @startup_report = nil
        report
      end

      # Kiểm tra cặp phiên bản nguồn/đích do giao diện gửi lên. Trả về thông báo lỗi hoặc nil.
      def self.check_versions(src, dst)
        versions = installed_versions
        return t(:ver_pick) unless versions.include?(src.to_s) && versions.include?(dst.to_s)
        return t(:ver_same) if src == dst
        nil
      end

      # Mở thư mục bằng Explorer (Windows) hoặc trình duyệt file của hệ điều hành
      def self.open_folder(dir)
        if Sketchup.platform == :platform_win
          Process.detach(Process.spawn('explorer.exe', dir.tr('/', '\\')))
        else
          UI.openURL("file://#{dir}")
        end
      end
    end
  end
end

# Nạp sau khi module Manager đã được định nghĩa
require File.join(File.dirname(__FILE__), 'toggle')
require File.join(File.dirname(__FILE__), 'callbacks')
