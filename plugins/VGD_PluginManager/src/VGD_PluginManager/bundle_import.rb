# encoding: UTF-8
# File này được đóng vào gói .rbz tổng (đổi tên thành vgd_bundle_import.rb).
# Khi cài gói trên máy mới, menu Plugins sẽ có mục để nhập phím tắt / thanh công cụ.
require 'sketchup.rb'
require 'json'

module VGD
  module BundleImport
    DIR = File.join(File.dirname(__FILE__), 'vgd_bundle_import')
    KEYS = {
      shortcuts: 'Software\SketchUp\SketchUp %s\Shortcuts',
      toolbars:  'Software\SketchUp\SketchUp %s\Toolbars'
    }
    LABELS = { shortcuts: 'phím tắt', toolbars: 'giao diện thanh công cụ' }

    def self.temp_dir
      (ENV['TEMP'] || ENV['TMP']).to_s.tr('\\', '/')
    end

    def self.current_year
      (2000 + Sketchup.version.to_i).to_s
    end

    def self.key_exists?(key)
      system('reg', 'query', "HKCU\\#{key}", out: File::NULL, err: File::NULL) ? true : false
    end

    def self.export_file(key, file)
      system('reg', 'export', "HKCU\\#{key}", file.tr('/', '\\'), '/y', out: File::NULL, err: File::NULL)
    end

    def self.import_one(kind, manifest)
      file = File.join(DIR, "#{kind}.reg")
      return nil unless File.exist?(file)
      src_ver = manifest['source_version'].to_s
      dst_ver = current_year
      dst_key = KEYS[kind] % dst_ver

      if key_exists?(dst_key)
        bk = File.join(ENV['USERPROFILE'].to_s.tr('\\', '/'), 'Documents',
                       "SU_#{kind}_#{dst_ver}_backup_#{Time.now.strftime('%Y%m%d_%H%M%S')}.reg")
        export_file(dst_key, bk)
      end

      text = File.binread(file).force_encoding('UTF-16LE').encode('UTF-8', invalid: :replace, undef: :replace)
      text = text.sub(/\A﻿/, '').gsub("SketchUp #{src_ver}", "SketchUp #{dst_ver}")
      tmp = File.join(temp_dir, "vgd_bundle_#{rand(1_000_000)}.reg")
      File.binwrite(tmp, "﻿".encode('UTF-16LE') + text.encode('UTF-16LE'))
      ok = system('reg', 'import', tmp.tr('/', '\\'), out: File::NULL, err: File::NULL)
      File.delete(tmp) if File.exist?(tmp)
      ok ? "Đã nhập #{LABELS[kind]} vào SketchUp #{dst_ver}." : "Lỗi khi nhập #{LABELS[kind]}."
    end

    def self.run
      manifest_path = File.join(DIR, 'manifest.json')
      unless File.exist?(manifest_path)
        UI.messagebox('Không tìm thấy dữ liệu của gói (vgd_bundle_import).')
        return
      end
      manifest = JSON.parse(File.read(manifest_path, encoding: 'UTF-8'))
      kinds = KEYS.keys.select { |k| File.exist?(File.join(DIR, "#{k}.reg")) }
      if kinds.empty?
        UI.messagebox('Gói này không kèm phím tắt hay thanh công cụ.')
        return
      end

      what = kinds.map { |k| LABELS[k] }.join(' và ')
      ask = "Gói được xuất từ SketchUp #{manifest['source_version']} lúc #{manifest['exported_at']}.\n\n" \
            "Nhập #{what} vào SketchUp #{current_year}?\n\n" \
            "Dữ liệu hiện tại sẽ được sao lưu vào thư mục Documents trước khi ghi."
      return unless UI.messagebox(ask, MB_YESNO) == IDYES

      msgs = kinds.map { |k| import_one(k, manifest) }.compact
      msgs << 'Hãy đóng SketchUp và mở lại để áp dụng.'
      UI.messagebox(msgs.join("\n"))
    end

    unless file_loaded?(__FILE__)
      UI.menu('Plugins').add_item('VGD: Nhập phím tắt/giao diện từ gói') { run }
      file_loaded(__FILE__)
    end
  end
end
