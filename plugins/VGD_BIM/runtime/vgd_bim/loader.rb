require 'sketchup.rb'
require 'json'
# Menu Extensions > VGD dùng chung: mọi plugin VGD lấy cùng một menu (SketchUp không gộp các menu trùng tên).
module VGD
  def self.menu
    @extensions_menu ||= ::UI.menu('Extensions').add_submenu('VGD')
  end unless respond_to?(:menu)
end

module VGD
  module BIM
    ROOT = File.dirname(__FILE__.dup.force_encoding(Encoding::UTF_8)).freeze unless defined?(ROOT)
    # Thứ tự nạp code. Dùng chung cho lúc mở SketchUp và lúc "Tải lại code".
    FILES = %w[core/locale core/schema core/storage core/settings core/model_settings core/images core/clipboard_image core/paste_keys core/legacy_migration core/row_order core/sheet_lock core/data core/tags core/geometry core/view_fit core/scanner core/preset core/photo_settings core/front core/front_probe core/front_align core/measure core/measure_probe core/tag_rules core/tag_catalog core/folder_rules core/tag_tree core/xlsx_reader core/tag_excel core/formula core/quantity core/material_library core/check_rules core/snapshots core/custom_columns core/vgd_id core/object_code core/bridge core/bridge_provider core/levels core/room_openings core/rooms core/opening_probe core/room_detect core/room_detect_probe core/room_volume core/structure_source core/table core/data_bridge core/rename core/rename_list core/validator
               intake/mapping_rules intake/detector intake/raw_scanner intake/mapping intake/converter core/report_exporter core/xlsx_formulas core/table_report
               ui/bounds_preview ui/capture ui/image_actions ui/front_actions ui/tag_auto ui/tag_sample ui/tag_manager ui/tag_paint_runner ui/dialog ui/rename_window].freeze
    @log_counts = Hash.new(0)
    def self.log(message)
      return if @log_counts.values.inject(0, :+) >= 100
      @log_counts[message] += 1
      puts "[VGD BIM] #{message}" if @log_counts[message] <= 3
    end
    def self.presets
      @presets ||= JSON.parse(File.read(File.join(ROOT, 'config', 'presets.json'), encoding: 'UTF-8'))
    end
    def self.open_panel(mode)
      return open_tags if mode == 'tags' # Soạn tag nằm ở cửa sổ riêng
      if @panel && !@panel.closed?
        @panel.switch_mode(mode)
      else
        @panel = UI::Dialog.new(mode)
      end
      @panel.show
    end
    # Cửa sổ Đổi tên độc lập (ui/rename_window.rb): mở từ menu hoặc từ Bảng khối lượng, vẫn dùng được khi đã đóng bảng.
    def self.open_rename
      @rename = UI::RenameWindow.new if @rename.nil? || @rename.closed?
      @rename.show
    end
    # Cửa sổ Soạn tag riêng (ui/dialog.rb với kind :tags): mở từ menu, thanh công cụ, vẫn dùng được khi đã đóng cửa sổ chính.
    def self.open_tags
      @paint_runner.stop if @paint_runner && @paint_runner.active? # công cụ bật bằng phím tắt nhường cho cửa sổ (không hai nơi cùng giữ công cụ)
      @tags = UI::Dialog.new('tags', :tags) if @tags.nil? || @tags.closed?
      @tags.show
    end
    # Cửa sổ Đổi tên / Soạn tag vừa ghi vào model: Bảng khối lượng đang mở thì đọc lại để hiện tên, tag mới.
    # Gom các lần ghi liên tiếp (đổ tag nhiều lần) thành một lần đọc lại.
    def self.model_edited
      return unless @panel && !@panel.closed?
      ::UI.stop_timer(@edit_timer) if @edit_timer
      @edit_timer = ::UI.start_timer(0.3, false) { @edit_timer = nil; @panel.reload_table if @panel && !@panel.closed? }
    end
    # Lệnh menu "Hút / đổ tag" (đặt phím tắt trong Window > Preferences > Shortcuts): bật công cụ với tag dùng gần nhất có trong model
    # (chưa có thì bắt đầu ở chế độ hút), bấm lại khi đang chạy thì thoát. Không mở cửa sổ Soạn tag; cửa sổ đang mở thì công cụ chạy qua cửa sổ.
    def self.toggle_tag_paint
      return @paint_runner.toggle('') if @paint_runner && @paint_runner.active?
      model = Sketchup.active_model
      return unless model
      name = Array(Settings.read['recent_tags']).find { |tag| Tags.find_layer(model, tag) }.to_s
      return @tags.paint_shortcut(name) if @tags && !@tags.closed?
      (@paint_runner ||= UI::TagPaintRunner.new).toggle(name)
    end
    # Nút trên thanh công cụ (quy tắc chung của repo): cửa sổ đang mở thì bấm lại để đóng, đang đóng thì mở.
    # name: :table (cửa sổ chính, mở ở Bảng khối lượng), :rename, :tags. Mục menu vẫn chỉ mở.
    def self.toggle_window(name)
      window = {table: @panel, rename: @rename, tags: @tags}.fetch(name)
      return window.close if window && !window.closed? && window.visible?
      {table: -> { open_panel('table') }, rename: -> { open_rename }, tags: -> { open_tags }}.fetch(name).call
    end
    # Nạp lại toàn bộ code của plugin mà không cần mở lại SketchUp.
    # Dùng sau khi cài đè bản mới (.rbz). Menu và thanh công cụ giữ như cũ cho tới lần mở SketchUp sau.
    # Kiểm tra cú pháp cả bộ file trước: có lỗi thì giữ nguyên bản đang chạy.
    def self.reload
      busy = [@panel, @tags].find { |window| window && !window.closed? && window.busy_reason }&.busy_reason # đang chụp ảnh / vẽ khung: không nạp lại, để người dùng chờ xong
      if busy
        ::UI.messagebox("Tải lại thất bại: VGD BIM #{busy}.\n\nHãy chờ xong rồi tải lại code.")
        return false
      end
      files = [File.join(File.dirname(ROOT), 'vgd_bim.rb'), File.join(ROOT, 'loader.rb')] +
              FILES.map { |file| File.join(ROOT, "#{file}.rb") }
      files.each { |file| RubyVM::InstructionSequence.compile_file(file) }
      loading = true # từ đây lỗi nghĩa là đã nạp dở, không còn "giữ nguyên bản đang chạy"
      reopen = @panel && !@panel.closed?
      reopen_rename = @rename && !@rename.closed?
      reopen_tags = @tags && !@tags.closed?
      [reopen && @panel, reopen_rename && @rename, reopen_tags && @tags].each do |window|
        next unless window
        begin
          window.close
        rescue StandardError
          nil
        end
      end
      @paint_runner.stop if @paint_runner # công cụ hút / đổ tag bật bằng phím tắt: thoát trước khi nạp lại
      @paint_runner = nil
      @panel = nil
      @rename = nil
      @tags = nil
      @presets = nil
      @log_counts = Hash.new(0)
      verbose = $VERBOSE
      $VERBOSE = nil # tránh cảnh báo "hằng số đã khai báo" khi nạp lại
      begin
        files.each { |file| load file }
      ensure
        $VERBOSE = verbose
      end
      open_panel('table') if reopen
      open_rename if reopen_rename
      open_tags if reopen_tags
      ::UI.messagebox("Đã tải lại VGD BIM #{VERSION}.")
      true
    rescue ScriptError, StandardError => error
      ::UI.messagebox("Tải lại thất bại:\n#{error.class}: #{error.message}\n\n#{loading ? 'Hãy mở lại SketchUp nếu giao diện báo lỗi.' : 'Bản đang chạy được giữ nguyên.'}")
      false
    end
  end
end
VGD::BIM::FILES.each { |file| require File.join(VGD::BIM::ROOT, file) }
unless file_loaded?(__FILE__)
  # Menu Extensions > VGD > VGD BIM.
  vgd_menu = ::VGD.menu.add_submenu('VGD BIM')
  vgd_menu.add_item('Mở bảng khối lượng') { VGD::BIM.open_panel('table') }
  vgd_menu.add_item('Đổi tên') { VGD::BIM.open_rename }
  vgd_menu.add_item('Soạn tag') { VGD::BIM.open_tags }
  vgd_menu.add_item('Hút / đổ tag') { VGD::BIM.toggle_tag_paint }
  vgd_menu.add_item('Tải lại code') { VGD::BIM.reload }
  ::UI.add_context_menu_handler do |context|
    if Sketchup.active_model.selection.any? { |e| VGD::BIM::Data.supported?(e) }
      context.add_item('VGD_BIM · Thông tin đối tượng') { VGD::BIM.open_panel('information') }
    end
  end
  toolbar = ::UI::Toolbar.new('VGD BIM')
  command = ::UI::Command.new('VGD_BIM') { VGD::BIM.toggle_window(:table) }
  command.tooltip = 'VGD_BIM · Bảng khối lượng'
  command.status_bar_text = 'VGD_BIM: mở bảng khối lượng của đối tượng đang chọn'
  command.small_icon = command.large_icon = File.join(VGD::BIM::ROOT, 'assets', 'icons', 'information.svg')
  toolbar.add_item(command)
  # Hai cửa sổ dùng nhiều: Đổi tên và Soạn tag (icon assets/icons/rename.svg, tag.svg theo chuẩn icon VGD).
  [['VGD_BIM_Rename', 'VGD_BIM · Đổi tên', 'VGD_BIM: đổi tên các group / component đang chọn', 'rename', -> { VGD::BIM.toggle_window(:rename) }],
   ['VGD_BIM_Tags', 'VGD_BIM · Soạn tag', 'VGD_BIM: soạn, gán và quản lý tag', 'tag', -> { VGD::BIM.toggle_window(:tags) }]].each do |name, tip, status, icon, action|
    item = ::UI::Command.new(name) { action.call }
    item.tooltip = tip
    item.status_bar_text = status
    item.small_icon = item.large_icon = File.join(VGD::BIM::ROOT, 'assets', 'icons', "#{icon}.svg")
    toolbar.add_item(item)
  end
  toolbar.restore
  file_loaded(__FILE__)
end
