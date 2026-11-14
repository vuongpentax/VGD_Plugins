require 'sketchup.rb'
require 'json'

# Menu Extensions > VGD dùng chung: mọi plugin VGD lấy cùng một menu (SketchUp không gộp các menu trùng tên).
module VGD
  def self.menu
    @extensions_menu ||= ::UI.menu('Extensions').add_submenu('VGD')
  end unless respond_to?(:menu)
end

module VGD_DC_Exporter
  VERSION = '1.0.4'.freeze unless const_defined?(:VERSION)

  # Danh sách file nạp, dùng chung cho lúc khởi động và lúc "Tải lại code".
  CODE_FILES = %w[params walker].freeze unless const_defined?(:CODE_FILES)

  # Nạp đủ phần xử lý (chỉ đọc file, không sửa mô hình).
  CODE_FILES.each { |name| load File.join(__dir__, "#{name}.rb") }

  # Nạp lại mã mà không cần mở lại SketchUp. Kiểm tra cú pháp cả bộ file trước: có lỗi thì giữ nguyên bản đang chạy.
  def self.reload
    files = [File.join(__dir__, 'main.rb')] + CODE_FILES.map { |name| File.join(__dir__, "#{name}.rb") }
    files.each { |file| RubyVM::InstructionSequence.compile_file(file) }
    old_version = VERSION
    old_files = CODE_FILES
    verbose = $VERBOSE
    $VERBOSE = nil # tránh cảnh báo "hằng số đã khai báo" khi nạp lại
    begin
      remove_const(:VERSION)
      remove_const(:CODE_FILES)
      load File.join(__dir__, 'main.rb')
    rescue ScriptError, StandardError
      const_set(:VERSION, old_version) unless const_defined?(:VERSION, false)
      const_set(:CODE_FILES, old_files) unless const_defined?(:CODE_FILES, false)
      raise
    ensure
      $VERBOSE = verbose
    end
    UI.messagebox("Đã tải lại VGD DC Exporter #{VERSION}.")
    true
  rescue ScriptError, StandardError => error
    UI.messagebox("Tải lại thất bại:\n#{error.class}: #{error.message}\n\nBản đang chạy được giữ nguyên.")
    false
  end

  # Xuất các đối tượng đang chọn ra file JSON. Lệnh này không sửa mô hình và không lưu SKP.
  def self.export_selected
    model = Sketchup.active_model
    selected = model.selection.to_a.select { |entity| entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group) }
    if selected.empty?
      UI.messagebox('Hãy chọn ít nhất một component hoặc group rồi chạy lại lệnh.')
      return nil
    end
    name = selected.length == 1 ? selected.first.definition.name.to_s : 'nhieu_doi_tuong'
    name = name.gsub(/[\\\/:*?"<>|\x00-\x1f]/, '_').strip[0, 70]
    name = 'doi_tuong' if name.empty?
    filename = "VGD_DC_#{name}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    path = UI.savepanel('VGD DC Exporter — Lưu file JSON', nil, filename)
    return nil unless path
    path += '.json' unless File.extname(path).casecmp('.json').zero?
    walker = Walker.new
    snapshot = walker.build(model, selected)
    json = JSON.pretty_generate(snapshot)
    File.open(path, 'wb') { |file| file.write(json.encode('UTF-8')) }
    summary = snapshot['summary']
    note = snapshot['warnings'].empty? ? '' : "\nCó #{snapshot['warnings'].length} lưu ý, xem mục warnings trong JSON."
    UI.messagebox("Đã xuất #{summary['selected']} đối tượng, #{summary['definitions']} định nghĩa.\n\n#{path}\n\nGửi file JSON này lại trong cuộc trò chuyện.#{note}")
    path
  rescue StandardError => error
    puts "[VGD DC Exporter] #{error.class}: #{error.message}\n#{(error.backtrace || []).first(8).join("\n")}"
    UI.messagebox("Không xuất được JSON: #{error.message}\nXem Window > Ruby Console để biết chi tiết.")
    nil
  end

  unless file_loaded?(__FILE__)
    menu = ::VGD.menu.add_submenu('VGD DC Exporter')
    menu.add_item('Xuất JSON đối tượng đang chọn') { export_selected }
    menu.add_item('Tải lại code') { reload }
    file_loaded(__FILE__)
  end
end
