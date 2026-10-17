# encoding: UTF-8
require 'sketchup.rb'
require 'json'
require 'base64'
require 'tmpdir'
require 'securerandom'
require_relative 'engine'
require_relative 'file_picker'
require_relative 'conversion'
require_relative 'update_notice'

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

  # Browser File objects cross the HtmlDialog bridge as bounded base64 chunks.
  def self.drop_start(token, name, size, chunks)
    token = token.to_s
    raise ArgumentError, 'Mã ảnh kéo vào không hợp lệ.' unless token.match?(/\A[a-zA-Z0-9_-]{1,100}\z/)
    ext = File.extname(name.to_s).downcase
    raise ArgumentError, 'Định dạng ảnh kéo vào chưa được hỗ trợ.' unless SUPPORTED.include?(ext)
    total = Integer(size)
    count = Integer(chunks)
    expected_chunks = (total.to_f / (192 * 1024)).ceil
    raise ArgumentError, 'Ảnh phải có dung lượng từ 1 byte đến 20 MiB.' unless total.between?(1, 20 * 1024 * 1024)
    raise ArgumentError, 'Dữ liệu ảnh kéo vào không hợp lệ.' unless count == expected_chunks

    @drop_buffers ||= {}
    @drop_buffers[token] = { name: File.basename(name.to_s), size: total, chunks: count, next_chunk: 0, data: ''.b }
    UI.start_timer(60, false) { @drop_buffers.delete(token) if @drop_buffers }
    true
  rescue StandardError => error
    send_ui('status', { 'error' => true, 'message' => error.message })
    false
  end

  def self.drop_chunk(token, index, encoded)
    entry = @drop_buffers && @drop_buffers[token.to_s]
    chunk_index = Integer(index)
    return false unless entry && chunk_index == entry[:next_chunk] && chunk_index < entry[:chunks]

    bytes = Base64.strict_decode64(encoded.to_s)
    expected_bytes = [192 * 1024, entry[:size] - entry[:data].bytesize].min
    raise ArgumentError, 'Kích thước khối ảnh kéo vào không hợp lệ.' unless bytes.bytesize == expected_bytes
    entry[:data] << bytes
    if entry[:data].bytesize > entry[:size]
      @drop_buffers.delete(token.to_s)
      raise ArgumentError, 'Dữ liệu ảnh kéo vào vượt quá dung lượng khai báo.'
    end
    entry[:next_chunk] += 1
    true
  rescue StandardError => error
    @drop_buffers.delete(token.to_s) if @drop_buffers
    send_ui('status', { 'error' => true, 'message' => error.message })
    false
  end

  def self.drop_finish(token)
    token = token.to_s
    entry = @drop_buffers && @drop_buffers.delete(token)
    unless entry && entry[:next_chunk] == entry[:chunks] && entry[:data].bytesize == entry[:size]
      raise ArgumentError, 'Không nhận đủ dữ liệu ảnh được kéo vào.'
    end

    base = Sketchup.respond_to?(:temp_dir) ? Sketchup.temp_dir : Dir.tmpdir
    directory = (@drop_directory ||= Dir.mktmpdir('vgd-image-importer-', base))
    safe_name = entry[:name].gsub(/[^\p{Alnum}._-]+/u, '_')
    safe_name = "image#{File.extname(entry[:name])}" if safe_name.empty?
    path = File.join(directory, "#{SecureRandom.hex(12)}-#{safe_name}")
    File.binwrite(path, entry[:data])
    @drop_paths ||= {}
    path = File.expand_path(path).tr('\\', '/')
    @drop_paths[path] = true
    @files = normalize_files(Array(@files) + [path])
    publish_files
    send_ui('status', { 'message' => "Đã thêm ảnh kéo vào. Danh sách hiện có #{@files.length} ảnh." })
    true
  rescue StandardError => error
    send_ui('status', { 'error' => true, 'message' => error.message })
    false
  end

  def self.release_dropped_file(path)
    return unless @drop_paths && @drop_paths.delete(path)
    File.delete(path) if File.file?(path)
  rescue StandardError
    nil
  end

  def self.cleanup_dropped_files
    paths = @drop_paths ? @drop_paths.keys : []
    paths.each { |path| release_dropped_file(path) }
    @files = Array(@files).reject { |path| paths.include?(path) }
    @drop_buffers = {}
    directory = @drop_directory
    Dir.rmdir(directory) if directory && File.directory?(directory) && Dir.empty?(directory)
    @drop_directory = nil
  rescue StandardError
    nil
  end
  def self.choose_source(kind, recursive)
    if kind == 'folder'
      directory = UI.select_directory(title: 'VGD · Chọn thư mục ảnh', directory: @last_dir)
      return unless directory
      chosen = folder_files(directory, recursive == true)
      @last_dir = directory
      Array(@files).each { |path| release_dropped_file(path) }
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
          removed = @files.delete_at(index) if index >= 0
          release_dropped_file(removed) if removed
          publish_files
        when 'clear'
          Array(@files).each { |path| release_dropped_file(path) }
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
        when 'drop_start'
          drop_start(data['token'], data['name'], data['size'], data['chunks'])
        when 'drop_chunk'
          drop_chunk(data['token'], data['index'], data['base64'])
        when 'drop_finish'
          drop_finish(data['token'])
        end
      rescue StandardError => error
        send_ui('status', { 'error' => true, 'message' => error.message })
      end
    end
    @dialog.set_on_closed do
      clear_import
      cleanup_dropped_files
      @dialog = nil
    end
    @dialog.show
  end

  unless file_loaded?(__FILE__)
    command = UI::Command.new('VGD Image Importer') { show_dialog }
    command.tooltip = 'VGD Image Importer'
    command.status_bar_text = 'Nhập ảnh 2D, sắp xếp ảnh hoặc thêm vật liệu vào model.'
    command.small_icon = command.large_icon = File.join(__dir__, 'icon.svg')
    UI.menu('Plugins').add_submenu('VGD Tools').add_item(command)
    @toolbar = UI::Toolbar.new('VGD Image Importer')
    @toolbar.add_item(command)
    @toolbar.restore
    file_loaded(__FILE__)
  end
  VGD::UpdateNotice.start('vgd-image-importer', 'VGD Image Importer', VERSION)
end
