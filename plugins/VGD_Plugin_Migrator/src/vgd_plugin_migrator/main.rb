# encoding: UTF-8
require 'sketchup.rb'
require 'fileutils'
require 'json'
require 'cgi'
require File.join(File.dirname(__FILE__), 'zip_writer')
require File.join(File.dirname(__FILE__), 'logger')

module VGD
  module PluginMigrator

    VERSION         = '1.0.0-beta.3'
    IMPORT_TEMPLATE = File.join(File.dirname(__FILE__), 'bundle_import.rb')

    APPDATA_SUBPATH = 'SketchUp/SketchUp %s/SketchUp/Plugins'
    REG_SHORTCUTS   = 'Software\SketchUp\SketchUp %s\Shortcuts'
    REG_TOOLBARS    = 'Software\SketchUp\SketchUp %s\Toolbars'

    # Không chuyển chính plugin này
    SELF_NAMES = ['vgd_plugin_migrator', 'vgd_plugin_migrator.rb']
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
    def self.list_plugins(version)
      dir = plugins_dir(version)
      return [] unless File.directory?(dir)
      entries = Dir.children(dir) - SKIP_NAMES - SELF_NAMES
      groups = {}
      entries.each do |e|
        key = e.sub(/\.(rb|rbe|rbs)\z/i, '')
        (groups[key] ||= []) << e
      end
      groups.map { |k, v| { name: k, items: v.sort } }.sort_by { |h| h[:name].downcase }
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

    # ---- Phím tắt và thanh công cụ (registry Windows) ----
    def self.temp_dir
      (ENV['TEMP'] || ENV['TMP']).to_s.tr('\\', '/')
    end

    def self.reg_key_exists?(key)
      system('reg', 'query', "HKCU\\#{key}", out: File::NULL, err: File::NULL) ? true : false
    end

    def self.reg_export(key, file)
      system('reg', 'export', "HKCU\\#{key}", file.tr('/', '\\'), '/y', out: File::NULL, err: File::NULL)
    end

    # Trả về nội dung file .reg dạng nhị phân (UTF-16LE có BOM)
    def self.reg_export_raw(key)
      tmp = File.join(temp_dir, "vgd_mig_#{rand(1_000_000)}.reg")
      return nil unless reg_export(key, tmp) && File.exist?(tmp)
      raw = File.binread(tmp)
      File.delete(tmp)
      raw
    end

    def self.reg_export_text(key)
      raw = reg_export_raw(key)
      return nil if raw.nil?
      raw.force_encoding('UTF-16LE').encode('UTF-8', invalid: :replace, undef: :replace)
    end

    def self.reg_import_text(text)
      tmp = File.join(temp_dir, "vgd_mig_in_#{rand(1_000_000)}.reg")
      File.binwrite(tmp, "﻿".encode('UTF-16LE') + text.sub(/\A﻿/, '').encode('UTF-16LE'))
      ok = system('reg', 'import', tmp.tr('/', '\\'), out: File::NULL, err: File::NULL)
      File.delete(tmp) if File.exist?(tmp)
      ok
    end

    def self.migrate_registry(kind, src_ver, dst_ver)
      label   = (kind == :shortcuts) ? 'phím tắt' : 'giao diện thanh công cụ'
      key_tpl = (kind == :shortcuts) ? REG_SHORTCUTS : REG_TOOLBARS
      src_key = key_tpl % src_ver
      dst_key = key_tpl % dst_ver
      return "Không tìm thấy dữ liệu #{label} của bản #{src_ver}." unless reg_key_exists?(src_key)

      if reg_key_exists?(dst_key)
        bk = File.join(ENV['USERPROFILE'].to_s.tr('\\', '/'), 'Documents',
                       "SU_#{kind}_#{dst_ver}_backup_#{Time.now.strftime('%Y%m%d_%H%M%S')}.reg")
        reg_export(dst_key, bk)
      end

      text = reg_export_text(src_key)
      return "Không đọc được dữ liệu #{label}." if text.nil?
      text = text.gsub("SketchUp #{src_ver}", "SketchUp #{dst_ver}")
      if reg_import_text(text)
        "Đã chuyển #{label} từ #{src_ver} sang #{dst_ver}."
      else
        Log.write("reg import thất bại (#{label}, #{src_ver} -> #{dst_ver})")
        "Lỗi khi ghi #{label} vào bản #{dst_ver}. #{Log.hint}"
      end
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
    def self.build_bundle(src_ver, chosen, with_shortcuts, with_toolbars, out_path)
      entries = collect_files(src_ver, chosen)
      return { error: 'Không có file nào để đóng gói.' } if entries.empty?
      plugin_files = entries.size
      now   = Time.now
      notes = []
      manifest = {
        'tool'           => 'VGD Plugin Migrator',
        'tool_version'   => VERSION,
        'source_version' => src_ver,
        'exported_at'    => now.strftime('%Y-%m-%d %H:%M:%S'),
        'plugins'        => chosen,
        'shortcuts'      => false,
        'toolbars'       => false
      }

      [[:shortcuts, with_shortcuts, REG_SHORTCUTS, 'phím tắt'],
       [:toolbars,  with_toolbars,  REG_TOOLBARS,  'thanh công cụ']].each do |kind, wanted, tpl, label|
        next unless wanted
        key = tpl % src_ver
        raw = reg_key_exists?(key) ? reg_export_raw(key) : nil
        if raw
          entries << ["vgd_bundle_import/#{kind}.reg", raw, now]
          manifest[kind.to_s] = true
        else
          notes << "Không tìm thấy dữ liệu #{label} của bản #{src_ver}, gói sẽ không kèm mục này."
        end
      end

      entries << ['vgd_bundle_import/manifest.json', JSON.pretty_generate(manifest).b, now]
      entries << ['vgd_bundle_import.rb', File.binread(IMPORT_TEMPLATE), now]

      out_path = "#{out_path}.rbz" unless out_path =~ /\.rbz\z/i
      ZipWriter.write(out_path, entries)
      { count: plugin_files, path: out_path, notes: notes }
    rescue => e
      { error: report_error('Không tạo được gói', e) }
    end

    # ---- Giao diện ----
    def self.run
      versions = installed_versions
      if versions.size < 2
        UI.messagebox("Chỉ tìm thấy #{versions.size} phiên bản SketchUp trong AppData. Cần ít nhất 2 phiên bản.")
        return
      end

      res = UI.inputbox(['Từ phiên bản:', 'Sang phiên bản:'],
                        [versions.first, versions.last],
                        [versions.join('|'), versions.join('|')],
                        'VGD Plugin Migrator - Chọn phiên bản')
      return unless res
      src_ver, dst_ver = res
      if src_ver == dst_ver
        UI.messagebox('Phiên bản nguồn và đích phải khác nhau.')
        return
      end

      plugins = list_plugins(src_ver)
      if plugins.empty?
        UI.messagebox("Không tìm thấy plugin nào trong bản #{src_ver}.")
        return
      end

      dlg = UI::HtmlDialog.new(dialog_title: "VGD Plugin Migrator #{VERSION}",
                               width: 560, height: 720,
                               style: UI::HtmlDialog::STYLE_DIALOG)
      dlg.set_html(build_dialog_html(plugins, src_ver, dst_ver))

      dlg.add_action_callback('migrate') do |_ctx, json|
        opts   = JSON.parse(json)
        chosen = opts['plugins'] || []
        msg    = []
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
        dlg.execute_script("showResult(#{msg.join("\n").to_json})")
      rescue => e
        dlg.execute_script("showResult(#{report_error('Lỗi khi chuyển', e).to_json})")
      end

      dlg.add_action_callback('export_bundle') do |_ctx, json|
        opts   = JSON.parse(json)
        chosen = opts['plugins'] || []
        if chosen.empty?
          dlg.execute_script("showResult(#{'Hãy tick ít nhất một plugin để xuất gói.'.to_json})")
          next
        end
        default_dir = File.join(ENV['USERPROFILE'].to_s.tr('\\', '/'), 'Desktop')
        path = UI.savepanel('Lưu gói .rbz tổng', default_dir, "VGD_Plugin_Bundle_#{src_ver}.rbz")
        next unless path
        r = build_bundle(src_ver, chosen, opts['shortcuts'], opts['toolbars'], path)
        if r[:error]
          dlg.execute_script("showResult(#{r[:error].to_json})")
        else
          msg = ["Đã xuất gói: #{r[:path]}", "Số file plugin trong gói: #{r[:count]}"]
          msg.concat(r[:notes])
          warns = scan_compat(src_ver, chosen)
          msg << "Cảnh báo tương thích: #{warns.join(' | ')}" if warns.any?
          msg << 'Trên máy mới: cài file .rbz bằng Extension Manager, khởi động lại SketchUp, ' \
                 'rồi vào Plugins > "VGD: Nhập phím tắt/giao diện từ gói" nếu gói có kèm phím tắt.'
          dlg.execute_script("showResult(#{msg.join("\n").to_json})")
        end
      rescue => e
        dlg.execute_script("showResult(#{report_error('Lỗi khi xuất gói', e).to_json})")
      end

      dlg.show
    end

    def self.build_dialog_html(plugins, src_ver, dst_ver)
      rows = plugins.each_with_index.map do |pl, i|
        name = CGI.escapeHTML(pl[:name])
        "<label class='row'><input type='checkbox' class='pl' value=\"#{name}\" checked> " \
        "<span>#{i + 1}. #{name}</span></label>"
      end.join("\n")
      <<-HTML
<!DOCTYPE html><html><head><meta charset="UTF-8">
<style>
body{font-family:Segoe UI,Arial,sans-serif;font-size:13px;margin:14px;color:#222}
h3{margin:0 0 8px}
.box{border:1px solid #ccc;border-radius:6px;padding:8px;max-height:300px;overflow:auto;margin-bottom:10px}
.row{display:block;padding:3px 0}
.opts label{display:block;padding:2px 0}
button{padding:8px 14px;margin:0 6px 6px 0;border:0;border-radius:5px;background:#2a6fdb;color:#fff;cursor:pointer}
button.alt{background:#777}
button.exp{background:#2e8b57}
#out{white-space:pre-wrap;margin-top:12px;padding:8px;background:#f3f3f3;border-radius:6px;display:none}
</style></head><body>
<h3>Chuyển từ SketchUp #{src_ver} sang #{dst_ver}</h3>
<div class="box">#{rows}</div>
<button class="alt" onclick="setAll(true)">Chọn hết</button>
<button class="alt" onclick="setAll(false)">Bỏ chọn hết</button>
<div class="opts" style="margin-top:10px">
<label><input type="checkbox" id="overwrite"> Ghi đè nếu plugin đã tồn tại ở bản đích</label>
<label><input type="checkbox" id="shortcuts" checked> Phím tắt (khi chuyển hoặc kèm trong gói)</label>
<label><input type="checkbox" id="toolbars"> Giao diện thanh công cụ (khi chuyển hoặc kèm trong gói)</label>
</div>
<p>
<button onclick="go()">Chuyển sang bản #{dst_ver}</button>
<button class="exp" onclick="exportBundle()">Xuất gói .rbz tổng</button>
</p>
<div id="out"></div>
<script>
function setAll(v){document.querySelectorAll('.pl').forEach(function(c){c.checked=v})}
function collect(){
 var p=[].slice.call(document.querySelectorAll('.pl')).filter(function(c){return c.checked}).map(function(c){return c.value});
 return {plugins:p,overwrite:document.getElementById('overwrite').checked,
  shortcuts:document.getElementById('shortcuts').checked,toolbars:document.getElementById('toolbars').checked};
}
function go(){sketchup.migrate(JSON.stringify(collect()))}
function exportBundle(){sketchup.export_bundle(JSON.stringify(collect()))}
function showResult(t){var e=document.getElementById('out');e.style.display='block';e.textContent=t}
</script></body></html>
      HTML
    end

    unless file_loaded?(__FILE__)
      UI.menu('Plugins').add_item('VGD Plugin Migrator') { run }
      file_loaded(__FILE__)
    end

  end
end

# Nạp sau khi module PluginMigrator đã được định nghĩa
require File.join(File.dirname(__FILE__), 'plugin_manager')
