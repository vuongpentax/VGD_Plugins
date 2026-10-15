# encoding: UTF-8
require 'base64'
require 'tmpdir'
require 'securerandom'
require 'open3'

module VGD_ImageImporter
  # Converted files live only for one batch; SketchUp embeds their pixels.
  def self.begin_import(input)
    raise 'Đang xử lý một lượt nhập khác.' if @pending_import
    cfg = options(input)
    files = Array(@files).dup
    raise ArgumentError, 'Chưa chọn ảnh để nhập.' if files.empty?
    @pending_import = {
      token: SecureRandom.hex(16), cfg: cfg, files: files,
      model: Sketchup.active_model, entities: Sketchup.active_model.active_entities,
      remaining: files.each_index.select { |index| CONVERTED.include?(File.extname(files[index]).downcase) },
      prepared: {}, errors: {}, cache_files: [], directory: Dir.mktmpdir('vgd-images-')
    }
    prepare_next
  rescue StandardError
    clear_import if @pending_import
    raise
  end

  def self.prepare_next
    job = @pending_import
    return unless job
    while (index = job[:remaining].shift)
      job[:waiting] = index
      path = job[:files][index]
      begin
        if %w[.heic .heif].include?(File.extname(path).downcase)
          output = File.join(job[:directory], "#{index}.png")
          job[:cache_files] << output
          convert_wic(path, output)
          job[:prepared][path] = output
          next
        end
        send_ui('convert', { 'token' => job[:token], 'id' => index, 'name' => File.basename(path),
          'mime' => MIME.fetch(File.extname(path).downcase), 'base64' => Base64.strict_encode64(File.binread(path)) })
        return # Continue only after the matching asynchronous browser reply.
      rescue StandardError => error
        job[:errors][path] = error.message
      end
    end
    unless Sketchup.active_model.equal?(job[:model]) && Sketchup.active_model.active_entities.equal?(job[:entities])
      raise 'Model hoặc vùng chỉnh sửa đã đổi. Hãy nhập lại trong đúng model.'
    end
    result = process_import(job[:cfg], job[:files], job[:prepared], job[:errors])
    clear_import
    send_ui('result', result)
  rescue StandardError
    clear_import
    raise
  end

  def self.accept_conversion(data)
    job = @pending_import
    return unless job && data['token'] == job[:token] && data['id'] == job[:waiting]
    path = job[:files][job[:waiting]]
    begin
      if data['error']
        job[:errors][path] = data['error'].to_s
      else
        png = Base64.strict_decode64(data.fetch('base64'))
        raise 'Dữ liệu chuyển đổi không phải PNG.' unless png.start_with?("\x89PNG\r\n\x1a\n".b)
        output = File.join(job[:directory], "#{job[:waiting]}.png")
        job[:cache_files] << output
        File.binwrite(output, png)
        job[:prepared][path] = output
      end
    rescue StandardError => error
      job[:errors][path] = error.message
    end
    job[:waiting] = nil
    prepare_next
  end

  def self.convert_wic(source, destination)
    raise 'HEIC/HEIF cần Windows và codec HEIF trên máy.' unless Sketchup.platform == :platform_win
    executable = File.join(ENV.fetch('SystemRoot', 'C:/Windows'), 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe')
    _, _, result = Open3.capture3(executable, '-NoProfile', '-NonInteractive', '-STA', '-ExecutionPolicy', 'Bypass',
      '-File', File.join(__dir__, 'convert_image.ps1'), '-Source', source, '-Destination', destination)
    raise 'Không đọc được HEIC/HEIF. Cần codec HEIF của Windows hoặc chuyển ảnh sang PNG/WebP.' unless result.success? && File.file?(destination)
    destination
  end

  def self.clear_import
    job = @pending_import
    @pending_import = nil
    return unless job
    # Delete only the PNG files we authored; never recursively delete a source folder.
    job[:cache_files].uniq.each do |path|
      File.delete(path) if File.dirname(path) == job[:directory] && File.file?(path)
    end
    Dir.rmdir(job[:directory]) if File.directory?(job[:directory]) && Dir.empty?(job[:directory])
  rescue StandardError => error
    puts "VGD Image Importer cache cleanup: #{error.message}"
  end
end
