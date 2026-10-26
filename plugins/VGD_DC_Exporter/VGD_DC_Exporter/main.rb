require 'sketchup.rb'
require 'json'

module VGD_DC_Exporter
  VERSION = '1.0.1'.freeze unless const_defined?(:VERSION)

  # Nạp đủ phần xử lý (chỉ đọc file, không sửa mô hình).
  load File.join(__dir__, 'params.rb')
  load File.join(__dir__, 'walker.rb')

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
    UI.menu('Extensions').add_item('VGD DC Exporter — Xuất JSON đối tượng đang chọn') { export_selected }
    file_loaded(__FILE__)
  end
end
