# encoding: UTF-8
require 'sketchup.rb'
require 'json'
require 'base64'
require 'tmpdir'
require 'securerandom'
require 'uri'
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

    store_dropped(entry[:name], entry[:data])
  rescue StandardError => error
    send_ui('status', { 'error' => true, 'message' => error.message })
    false
  end

  # Writes a dropped image to a temp file and adds it to the list.
  def self.store_dropped(name, data)
    base = Sketchup.respond_to?(:temp_dir) ? Sketchup.temp_dir : Dir.tmpdir
    directory = (@drop_directory ||= Dir.mktmpdir('vgd-image-importer-', base))
    safe_name = name.to_s.gsub(/[^\p{Alnum}._-]+/u, '_')
    safe_name = "image#{File.extname(name.to_s)}" if safe_name.empty?
    path = File.join(directory, "#{SecureRandom.hex(12)}-#{safe_name}")
    File.binwrite(path, data)
    @drop_paths ||= {}
    path = File.expand_path(path).tr('\\', '/')
    @drop_paths[path] = true
    @files = normalize_files(Array(@files) + [path])
    publish_files
    send_ui('status', { 'message' => "Đã thêm ảnh kéo vào. Danh sách hiện có #{@files.length} ảnh." })
    true
  end

  WEB_IMAGE_MAX_BYTES = 20 * 1024 * 1024 unless const_defined?(:WEB_IMAGE_MAX_BYTES)
  WEB_IMAGE_MAX_REDIRECTS = 3 unless const_defined?(:WEB_IMAGE_MAX_REDIRECTS)
  WEB_IMAGE_TIMEOUT = 20 unless const_defined?(:WEB_IMAGE_TIMEOUT)
  WEB_IMAGE_TYPES = {
    'image/jpeg' => '.jpg', 'image/pjpeg' => '.jpg', 'image/png' => '.png', 'image/apng' => '.apng',
    'image/gif' => '.gif', 'image/webp' => '.webp', 'image/bmp' => '.bmp', 'image/x-ms-bmp' => '.bmp',
    'image/tiff' => '.tif', 'image/avif' => '.avif', 'image/heic' => '.heic', 'image/heif' => '.heif',
    'image/svg+xml' => '.svg', 'image/x-icon' => '.ico', 'image/vnd.microsoft.icon' => '.ico'
  }.freeze unless const_defined?(:WEB_IMAGE_TYPES)

  # Identify the image format from its first bytes; the server's content type and URL are not trusted.
  def self.sniff_image_extension(data)
    head = data.byteslice(0, 16).to_s.b
    return '.png' if head.start_with?("\x89PNG\r\n\x1a\n".b)
    return '.jpg' if head.start_with?("\xFF\xD8\xFF".b)
    return '.gif' if head.start_with?('GIF87a'.b) || head.start_with?('GIF89a'.b)
    return '.webp' if head[0, 4] == 'RIFF'.b && head[8, 4] == 'WEBP'.b
    return '.bmp' if head.start_with?('BM'.b)
    return '.tif' if head.start_with?("II*\x00".b) || head.start_with?("MM\x00*".b)
    return '.ico' if head.start_with?("\x00\x00\x01\x00".b)
    if head[4, 4] == 'ftyp'.b
      brand = head[8, 4].to_s
      return '.avif' if brand.start_with?('avif'.b) || brand.start_with?('avis'.b)
      return '.heic' if %w[heic heix mif1 msf1].any? { |b| brand.start_with?(b.b) }
    end
    return '.svg' if data.byteslice(0, 1024).to_s.downcase.include?('<svg')
    nil
  end

  # Returns [extension, nil] for a supported image, or [nil, message].
  # The file content decides the format. The server's Content-Type is not trusted:
  # a page can claim to be an image, and formats without a signature are not accepted.
  def self.web_image_extension(data, _content_type, _uri)
    extension = sniff_image_extension(data)
    return [nil, 'Liên kết không trỏ đến ảnh được hỗ trợ.'] unless extension && SUPPORTED.include?(extension)
    [extension, nil]
  end

  # Downloads one image URL through SketchUp's HTTP client (not the browser, so CORS does not block it).
  # Calls done.call(data, content_type, final_uri) on success, or done.call(nil, message, nil) on failure.
  # done runs exactly once, even when the timeout and the response race.
  def self.fetch_web_image(url, redirects = 0, &done)
    uri = URI.parse(url.to_s)
    raise ArgumentError, 'Chỉ nhận liên kết http hoặc https.' unless %w[http https].include?(uri.scheme.to_s.downcase)
    finished = false
    timer = nil
    request = nil
    finish = lambda do |data, info, final_uri|
      next if finished
      finished = true
      UI.stop_timer(timer) if timer
      (@web_requests ||= {}).delete(request.object_id) if request
      done.call(data, info, final_uri)
    end
    timer = UI.start_timer(WEB_IMAGE_TIMEOUT, false) { finish.call(nil, 'Quá thời gian tải ảnh từ liên kết kéo vào.', nil) }
    request = Sketchup::Http::Request.new(uri.to_s, Sketchup::Http::GET)
    request.headers = { 'User-Agent' => "VGD-ImageImporter/#{VGD_ImageImporter::VERSION}" }
    # Keep the request referenced until it finishes; otherwise it can be collected before the response arrives.
    (@web_requests ||= {})[request.object_id] = request
    request.start do |_request, response|
      begin
        status = response.status_code.to_i
        location = response.headers['Location'] || response.headers['location']
        if [301, 302, 303, 307, 308].include?(status) && location && redirects < WEB_IMAGE_MAX_REDIRECTS
          fetch_web_image(URI.join(uri.to_s, location.to_s).to_s, redirects + 1) { |data, info, final_uri| finish.call(data, info, final_uri) }
        elsif status != 200
          finish.call(nil, "Trang web trả về lỗi HTTP #{status} khi tải ảnh.", nil)
        else
          body = response.body.to_s.b
          raise ArgumentError, 'Ảnh tải về rỗng.' if body.empty?
          raise ArgumentError, 'Ảnh web vượt quá giới hạn 20 MiB.' if body.bytesize > WEB_IMAGE_MAX_BYTES
          finish.call(body, response.headers['Content-Type'] || response.headers['content-type'], uri)
        end
      rescue StandardError => error
        finish.call(nil, error.message, nil)
      end
    end
  rescue StandardError => error
    done.call(nil, error.message, nil)
  end

  # Tries candidate URLs in order (direct image links before page links) and stores the first image that works.
  def self.try_web_candidates(queue, last_error = nil)
    if queue.empty?
      send_ui('status', { 'error' => true, 'message' => last_error || 'Không tải được ảnh từ liên kết kéo vào.' })
      return
    end
    url = queue.shift
    fetch_web_image(url) do |data, info, uri|
      if data.nil?
        try_web_candidates(queue, info)
      else
        extension, problem = web_image_extension(data, info, uri)
        if problem
          try_web_candidates(queue, problem)
        else
          base = File.basename(uri.path.to_s, '.*').gsub(/[^\p{Alnum}_-]+/u, '_')
          base = 'web-image' if base.empty?
          store_dropped("#{base}#{extension}", data)
        end
      end
    end
  end

  def self.drop_url(urls)
    candidates = Array(urls).map(&:to_s).select { |url| url.match?(%r{\Ahttps?://}i) }.uniq.first(5)
    raise ArgumentError, 'Không có liên kết ảnh hợp lệ được kéo vào.' if candidates.empty?
    try_web_candidates(candidates)
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
    @dialog.set_file(File.join(__dir__.dup.force_encoding(Encoding::UTF_8), 'dialog.html'))
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
        when 'drop_url'
          drop_url(data['urls'])
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
    command.small_icon = command.large_icon = File.join(__dir__.dup.force_encoding(Encoding::UTF_8), 'icon.svg')
    UI.menu('Plugins').add_submenu('VGD Tools').add_item(command)
    @toolbar = UI::Toolbar.new('VGD Image Importer')
    @toolbar.add_item(command)
    @toolbar.restore
    file_loaded(__FILE__)
  end
  VGD::UpdateNotice.start('vgd-image-importer', 'VGD Image Importer', VERSION)
end
