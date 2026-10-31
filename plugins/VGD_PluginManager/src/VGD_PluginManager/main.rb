# encoding: UTF-8
require 'sketchup.rb'
require 'fileutils'
require 'json'
require 'cgi'
require File.join(File.dirname(__FILE__), 'zip_writer')
require File.join(File.dirname(__FILE__), 'logger')
require File.join(File.dirname(__FILE__), 'linker')

module VGD
  module PluginManager

    VERSION         = '1.0.0-beta.15'
    UI_DIR          = File.join(File.dirname(__FILE__), 'ui')
    ICON_DIR        = File.join(File.dirname(__FILE__), 'icons')

    APPDATA_SUBPATH = 'SketchUp/SketchUp %s/SketchUp/Plugins'

    # Không chuyển/không tắt chính plugin này (gồm tên cũ của bản beta.3 trở về trước)
    SELF_NAMES = ['VGD_PluginManager', 'VGD_PluginManager.rb', 'vgd_plugin_migrator', 'vgd_plugin_migrator.rb']
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

    # Gom plugin: file .rb ở gốc Plugins + thư mục cùng tên (nếu có)
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
        pl[:items].each do |item|
          from = File.join(src, item)
          to   = File.join(dst, item)
          if File.exist?(to) && !overwrite
            skipped << item
            next
          end
          begin
            FileUtils.rm_rf(to) if File.exist?(to)
            FileUtils.cp_r(from, to)
            done << item
          rescue => e
            Log.write("Lỗi chép #{item} từ #{src_ver} sang #{dst_ver}", e)
            failed << "#{item}: #{e.message}"
          end
        end
      end
      { done: done, skipped: skipped, failed: failed, backup: backup_path }
    end

    # Cảnh báo tương thích Ruby 2.7 -> 3.2 (chỉ mang tính tham khảo)
    RISKY_PATTERNS = {
      /\bFixnum\b|\bBignum\b/ => 'dùng Fixnum/Bignum (đã bỏ trong Ruby 3.2)',
      /\bFile\.exists\?/      => 'dùng File.exists? (đã bỏ, phải dùng File.exist?)',
      /\bDir\.exists\?/       => 'dùng Dir.exists? (đã bỏ, phải dùng Dir.exist?)',
      /\bURI\.escape\b/       => 'dùng URI.escape (đã bỏ)',
      /\.taint\b|\.untaint\b/ => 'dùng taint/untaint (đã bỏ)'
    }

    def self.scan_compat(src_ver, chosen)
      src = plugins_dir(src_ver)
      warns = []
      list_plugins(src_ver).each do |pl|
        next unless chosen.include?(pl[:name])
        pl[:items].each do |item|
          path  = File.join(src, item)
          files = File.directory?(path) ? Dir.glob(File.join(path, '**', '*.rb')) : [path]
          files.each do |f|
            next unless f =~ /\.rb\z/i
            text = begin
              File.read(f, encoding: 'UTF-8', invalid: :replace, undef: :replace)
            rescue
              next
            end
            RISKY_PATTERNS.each do |re, msg|
              warns << "#{pl[:name]}: #{msg}" if text =~ re
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
      return { error: 'Không có file nào để đóng gói.' } if entries.empty?
      plugin_files = entries.size
      now = Time.now
      manifest = {
        'tool'           => 'VGD Plugin Manager',
        'tool_version'   => VERSION,
        'source_version' => src_ver,
        'exported_at'    => now.strftime('%Y-%m-%d %H:%M:%S'),
        'plugins'        => chosen
      }

      entries << ['vgd_bundle_manifest.json', JSON.pretty_generate(manifest).b, now]

      out_path = "#{out_path}.rbz" unless out_path =~ /\.rbz\z/i
      ZipWriter.write(out_path, entries)
      { count: plugin_files, path: out_path, notes: [] }
    rescue => e
      { error: report_error('Không tạo được gói', e) }
    end

    # Lệnh duy nhất cho menu và thanh công cụ (nút trên thanh công cụ cũng có trong menu)
    def self.make_command(title, tip, icon, &action)
      cmd = UI::Command.new(title, &action)
      cmd.tooltip = title
      cmd.status_bar_text = tip
      cmd.small_icon = cmd.large_icon = File.join(ICON_DIR, icon)
      cmd
    end

    unless file_loaded?(__FILE__)
      cmd = make_command('VGD Plugin Manager', 'Bật/tắt plugin và chuyển plugin, phím tắt, thanh công cụ giữa các phiên bản SketchUp',
                         'plugin_manager.svg') { run }
      UI.menu('Plugins').add_item(cmd)
      toolbar = UI::Toolbar.new('VGD Plugin Manager')
      toolbar.add_item(cmd)
      toolbar.restore
      file_loaded(__FILE__)
    end

  end
end

# Nạp sau khi module PluginManager đã được định nghĩa
require File.join(File.dirname(__FILE__), 'toggle')
require File.join(File.dirname(__FILE__), 'layout')
require File.join(File.dirname(__FILE__), 'dialog')
