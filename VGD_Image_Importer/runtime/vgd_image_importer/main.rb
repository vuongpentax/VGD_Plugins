# encoding: UTF-8
require 'sketchup.rb'
require 'json'
require_relative 'engine'
require_relative 'file_picker'
require_relative 'conversion'

module VGD_ImageImporter
  SETTINGS = 'VGD_ImageImporter'.freeze

  def self.saved_options
    options(JSON.parse(Sketchup.read_default(SETTINGS, 'options', '{}')))
  rescue StandardError
    DEFAULTS.dup
  end

  def self.send_ui(event, data)
    @dialog.execute_script("VGDImporter.receive(#{JSON.generate(event)}, #{JSON.generate(data)});") if @dialog
  end

  def self.publish_files
    send_ui('files', Array(@files).each_with_index.map { |path, index| { 'id' => index, 'name' => File.basename(path), 'path' => path } })
  end

  def self.choose_source(kind, recursive)
    if kind == 'folder'
      directory = UI.select_directory(title: 'VGD · Chọn thư mục ảnh', directory: @last_dir)
      return unless directory
      chosen = folder_files(directory, recursive == true)
      @last_dir = directory
      @files = chosen
    else
      chosen = FilePicker.choose(@last_dir, SUPPORTED)
      return if chosen.empty?
      @last_dir = File.dirname(chosen.first)
      @files = normalize_files(Array(@files) + chosen)
    end
    Sketchup.write_default(SETTINGS, 'last_dir', @last_dir)
    publish_files
    send_ui('status', { 'message' => "Đã chọn #{@files.length} ảnh. Kiểm tra cấu hình rồi nhập." })
  end

  def self.show_dialog
    if @dialog && @dialog.visible?
      @dialog.bring_to_front
      return
    end
    @files ||= []
    @last_dir ||= Sketchup.read_default(SETTINGS, 'last_dir', '')
    @dialog = UI::HtmlDialog.new(dialog_title: 'VGD Image Importer', preferences_key: 'com.vgd.image_importer',
      scrollable: false, resizable: true, width: 860, height: 720, min_width: 540, min_height: 500,
      style: UI::HtmlDialog::STYLE_DIALOG)
    @dialog.set_file(File.join(__dir__, 'dialog.html'))
    @dialog.add_action_callback('vgd_importer') do |_context, action, payload|
      begin
        data = JSON.parse(payload)
        if @pending_import && !%w[converted ready].include?(action)
          raise 'Đang chuẩn bị ảnh. Chờ lượt nhập hoàn tất.'
        end
        case action
        when 'ready'
          send_ui('settings', saved_options.merge('version' => VERSION))
          publish_files
        when 'choose'
          choose_source(data['kind'], data['recursive'])
        when 'remove'
          index = Integer(data['id'])
          @files.delete_at(index) if index >= 0
          publish_files
        when 'clear'
          @files.clear
          publish_files
        when 'save'
          Sketchup.write_default(SETTINGS, 'options', JSON.generate(options(data)))
        when 'import'
          cfg = options(data)
          Sketchup.write_default(SETTINGS, 'options', JSON.generate(cfg))
          begin_import(cfg)
        when 'converted'
          accept_conversion(data)
        end
      rescue StandardError => error
        send_ui('status', { 'error' => true, 'message' => error.message })
      end
    end
    @dialog.set_on_closed { clear_import; @dialog = nil }
    @dialog.show
  end

  unless file_loaded?(__FILE__)
    command = UI::Command.new('VGD Image Importer') { show_dialog }
    command.tooltip = 'VGD · Nhập ảnh'
    command.status_bar_text = 'Nhập hàng loạt component 2D, ảnh nằm phẳng hoặc vật liệu đúng tỉ lệ.'
    command.small_icon = command.large_icon = File.join(__dir__, 'icon.svg')
    UI.menu('Plugins').add_submenu('VGD Tools').add_item(command)
    @toolbar = UI::Toolbar.new('VGD Image Importer')
    @toolbar.add_item(command)
    @toolbar.restore
    file_loaded(__FILE__)
  end
end
