# encoding: UTF-8
module VGD
  module Center
    module Manager
      # Thông báo của tab Quản lý do Ruby tạo ra, có tiếng Việt và tiếng Anh.
      # Chữ tiếng Việt giữ nguyên như trước khi có tiếng Anh. %{tên} là chỗ điền giá trị.
      # Ngôn ngữ do giao diện gửi kèm mỗi lệnh (trường lang); xem Manager.lang=.
      # Nhật ký lỗi (manager.log) luôn ghi tiếng Việt vì dành cho người hỗ trợ.
      module Text
        LANGS = %w[vi en].freeze

        MESSAGES = {
          # ---- Chung ----
          busy: {
            vi: 'VGD Center đang cài hoặc gỡ plugin. Hãy đợi thao tác hiện tại hoàn tất rồi thử lại.',
            en: 'VGD Center is installing or removing plugins. Wait for the current operation to finish, then try again.'
          },
          log_hint: {
            vi: 'Chi tiết lỗi đã ghi vào: %{path}',
            en: 'Error details were written to: %{path}'
          },
          ver_pick: {
            vi: 'Hãy chọn phiên bản nguồn và đích.',
            en: 'Choose a source and a destination version.'
          },
          ver_same: {
            vi: 'Phiên bản nguồn và đích phải khác nhau.',
            en: 'The source and destination versions must be different.'
          },

          # ---- Tên lỗi hiện trước nội dung lỗi ----
          ctx_open_tab: { vi: 'Lỗi khi mở tab Quản lý', en: 'Error opening the Manage tab' },
          ctx_toggle: { vi: 'Lỗi khi bật/tắt plugin', en: 'Error enabling/disabling plugins' },
          ctx_bulk: { vi: 'Lỗi khi tắt/bật hàng loạt', en: 'Error during bulk enable/disable' },
          ctx_save_set: { vi: 'Lỗi khi lưu bộ', en: 'Error saving the set' },
          ctx_apply_set: { vi: 'Lỗi khi áp dụng bộ', en: 'Error applying the set' },
          ctx_delete_set: { vi: 'Lỗi khi xóa bộ', en: 'Error deleting the set' },
          ctx_open_disabled: { vi: 'Không mở được thư mục plugin đã tắt', en: 'Could not open the disabled-plugins folder' },
          ctx_open_plugins: { vi: 'Không mở được thư mục Plugins', en: 'Could not open the Plugins folder' },
          ctx_export_sets: { vi: 'Lỗi khi xuất bộ', en: 'Error exporting sets' },
          ctx_import_sets: { vi: 'Lỗi khi nhập bộ', en: 'Error importing sets' },
          ctx_list: { vi: 'Lỗi khi đọc danh sách plugin', en: 'Error reading the plugin list' },
          ctx_migrate: { vi: 'Lỗi khi chuyển', en: 'Error migrating plugins' },
          ctx_bundle: { vi: 'Lỗi khi xuất gói', en: 'Error exporting the package' },
          err_legacy: { vi: 'Không chuyển được dữ liệu bật/tắt cũ', en: 'Could not move the old enable/disable data' },
          err_save_set: { vi: 'Không lưu được bộ', en: 'Could not save the set' },
          err_delete_set: { vi: 'Không xóa được bộ', en: 'Could not delete the set' },
          err_export_sets: { vi: 'Không xuất được bộ plugin', en: 'Could not export the plugin sets' },
          err_read_sets: { vi: 'Không đọc được file bộ plugin', en: 'Could not read the plugin-set file' },
          err_import_sets: { vi: 'Không nhập được bộ plugin', en: 'Could not import the plugin sets' },
          err_bundle: { vi: 'Không tạo được gói', en: 'Could not create the package' },

          # ---- Bật/tắt ----
          legacy_moved: {
            vi: 'Đã chuyển dữ liệu bật/tắt cũ vào %{dir}.',
            en: 'Moved the old enable/disable data to %{dir}.'
          },
          dest_exists: {
            vi: '%{item} đã tồn tại ở thư mục đích',
            en: '%{item} already exists in the destination folder'
          },
          clash_disabled: {
            vi: '%{name}: đã có bản cùng tên trong thư mục tắt, cần xử lý thủ công',
            en: '%{name}: a plugin with the same name is already in the disabled folder; resolve it manually'
          },
          clash_plugins: {
            vi: '%{name}: đã có bản cùng tên trong Plugins, cần xử lý thủ công',
            en: '%{name}: a plugin with the same name is already in Plugins; resolve it manually'
          },
          pick_one: { vi: 'Hãy chọn ít nhất một plugin.', en: 'Select at least one plugin.' },
          bulk_none_enable: { vi: 'Không có plugin nào đang tắt để bật.', en: 'There are no disabled plugins to enable.' },
          bulk_none_disable: { vi: 'Không có plugin nào đang bật để tắt.', en: 'There are no enabled plugins to disable.' },
          confirm_enable: {
            vi: "Bật %{n} plugin?\n\nThay đổi có hiệu lực sau khi khởi động lại SketchUp.",
            en: "Enable %{n} plugin(s)?\n\nThe change takes effect after you restart SketchUp."
          },
          confirm_disable_head: {
            vi: "Tắt %{n} plugin (gồm cả plugin VGD nếu có)?\n\n",
            en: "Disable %{n} plugin(s) (including VGD plugins, if any)?\n\n"
          },
          confirm_libs: {
            vi: "Có thể có thư viện nền mà plugin khác cần: %{shown}. Tắt chúng có thể làm plugin khác lỗi khi mở lại.\n\n",
            en: "These may be shared libraries that other plugins need: %{shown}. Disabling them may break other plugins when you reopen SketchUp.\n\n"
          },
          libs_more: { vi: ' và %{n} mục khác', en: ' and %{n} more' },
          confirm_disable_tail: {
            vi: 'Thay đổi có hiệu lực sau khi khởi động lại SketchUp. Có thể bật lại bằng nút "Bật tất cả".',
            en: 'The change takes effect after you restart SketchUp. You can turn them back on with the "Enable all" button.'
          },
          sum_disabled: { vi: 'Đã tắt: %{n} plugin.', en: 'Disabled: %{n} plugin(s).' },
          sum_enabled: { vi: 'Đã bật: %{n} plugin.', en: 'Enabled: %{n} plugin(s).' },
          sum_skipped: {
            vi: 'Bỏ qua (đã ở trạng thái đó hoặc không tìm thấy): %{n}.',
            en: 'Skipped (already in that state or not found): %{n}.'
          },
          sum_errors: { vi: 'Lỗi: %{errors}', en: 'Errors: %{errors}' },
          sum_restart: {
            vi: 'Khởi động lại SketchUp để thay đổi có hiệu lực.',
            en: 'Restart SketchUp for the change to take effect.'
          },

          # ---- Bộ plugin ----
          set_need_name: { vi: 'Hãy nhập tên cho bộ plugin.', en: 'Enter a name for the plugin set.' },
          set_need_pick: {
            vi: 'Hãy tick ít nhất một plugin để lưu thành bộ.',
            en: 'Tick at least one plugin to save as a set.'
          },
          set_saved: {
            vi: 'Đã lưu bộ "%{name}" gồm %{n} plugin.',
            en: 'Saved set "%{name}" with %{n} plugin(s).'
          },
          set_not_found: { vi: 'Không tìm thấy bộ này.', en: 'Set not found.' },
          set_deleted: {
            vi: 'Đã xóa bộ "%{name}" (các plugin không bị ảnh hưởng).',
            en: 'Deleted set "%{name}" (the plugins are not affected).'
          },
          sets_none: { vi: 'Chưa có bộ plugin nào để xuất.', en: 'There are no plugin sets to export.' },
          sets_exported: { vi: 'Đã xuất %{n} bộ plugin ra: %{path}', en: 'Exported %{n} plugin set(s) to: %{path}' },
          sets_bad_format: {
            vi: 'File không đúng định dạng bộ plugin của VGD.',
            en: 'The file is not a VGD plugin-set file.'
          },
          sets_none_valid: { vi: 'File không có bộ plugin hợp lệ nào.', en: 'The file has no valid plugin sets.' },
          sets_imported: {
            vi: 'Đã nhập: %{added} bộ mới, %{replaced} bộ ghi đè.',
            en: 'Imported: %{added} new set(s), %{replaced} overwritten.'
          },
          sets_import_skipped: {
            vi: ' Bỏ qua %{n} bộ trùng tên.',
            en: ' Skipped %{n} set(s) with the same name.'
          },
          save_sets_title: { vi: 'Lưu các bộ plugin', en: 'Save plugin sets' },
          open_sets_title: { vi: 'Chọn file bộ plugin (.json)', en: 'Choose a plugin-set file (.json)' },
          import_clash: {
            vi: "Có %{n} bộ trùng tên: %{names}.\nChọn Yes để ghi đè, No để giữ bộ hiện có (chỉ nhập bộ mới).",
            en: "%{n} set(s) have the same name: %{names}.\nChoose Yes to overwrite, No to keep the existing sets (import new sets only)."
          },

          # ---- Chuyển plugin, xuất gói ----
          no_plugins_dir: { vi: 'Không thấy thư mục Plugins: %{dir}', en: 'Plugins folder not found: %{dir}' },
          mig_copied: { vi: 'Đã chép: %{n} mục.', en: 'Copied: %{n} item(s).' },
          mig_skipped: { vi: 'Bỏ qua (đã tồn tại): %{n} mục.', en: 'Skipped (already exist): %{n} item(s).' },
          mig_backup: { vi: 'Sao lưu thư mục đích: %{path}', en: 'Backup of the destination folder: %{path}' },
          mig_restart: {
            vi: 'Hãy đóng SketchUp và mở lại bản %{ver} để áp dụng.',
            en: 'Close SketchUp and reopen version %{ver} to apply the change.'
          },
          compat_warn: { vi: 'Cảnh báo tương thích: %{warnings}', en: 'Compatibility warnings: %{warnings}' },
          risky_fixnum: {
            vi: 'dùng Fixnum/Bignum (đã bỏ trong Ruby 3.2)',
            en: 'uses Fixnum/Bignum (removed in Ruby 3.2)'
          },
          risky_file_exists: {
            vi: 'dùng File.exists? (đã bỏ, phải dùng File.exist?)',
            en: 'uses File.exists? (removed; use File.exist?)'
          },
          risky_dir_exists: {
            vi: 'dùng Dir.exists? (đã bỏ, phải dùng Dir.exist?)',
            en: 'uses Dir.exists? (removed; use Dir.exist?)'
          },
          risky_uri_escape: { vi: 'dùng URI.escape (đã bỏ)', en: 'uses URI.escape (removed)' },
          risky_taint: { vi: 'dùng taint/untaint (đã bỏ)', en: 'uses taint/untaint (removed)' },
          bundle_empty: { vi: 'Không có file nào để đóng gói.', en: 'There are no files to package.' },
          bundle_pick: {
            vi: 'Hãy tick ít nhất một plugin để xuất gói.',
            en: 'Tick at least one plugin to export a package.'
          },
          save_bundle_title: { vi: 'Lưu gói .rbz tổng', en: 'Save the bundle .rbz' },
          bundle_done: { vi: 'Đã xuất gói: %{path}', en: 'Exported package: %{path}' },
          bundle_count: { vi: 'Số file plugin trong gói: %{n}', en: 'Plugin files in the package: %{n}' },
          bundle_next: {
            vi: 'Trên máy mới: cài file .rbz bằng Extension Manager rồi khởi động lại SketchUp. ' \
                'Gói chỉ chứa plugin; muốn mang các bộ plugin sang máy khác, dùng "Xuất các bộ ra file" ở tab Bật/tắt.',
            en: 'On the new computer: install the .rbz with Extension Manager, then restart SketchUp. ' \
                'The package contains plugins only; to move your plugin sets to another computer, use "Export sets to file" on the Enable/disable tab.'
          }
        }.freeze
      end

      # Ngôn ngữ của lệnh đang xử lý ('vi' hoặc 'en'). Mỗi lệnh từ giao diện gửi kèm lang; giá trị lạ thì dùng 'vi'.
      def self.lang
        @lang || 'vi'
      end

      def self.lang=(value)
        @lang = Text::LANGS.include?(value.to_s) ? value.to_s : 'vi'
      end

      # Thông báo theo ngôn ngữ hiện tại. vars điền vào các chỗ %{tên}.
      def self.t(key, vars = {})
        entry = Text::MESSAGES.fetch(key)
        format(entry[lang.to_sym] || entry[:vi], vars)
      end
    end
  end
end
