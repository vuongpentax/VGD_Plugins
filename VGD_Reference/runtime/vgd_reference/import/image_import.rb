require 'base64'
require 'json'
require 'securerandom'
require 'thread'
require 'open3'

module VGD
  module Reference
    # The timer owns SketchUp/HtmlDialog calls. Workers only fetch bytes or run WIC.
    module ImageImport
      module_function

      def add_file(path)
        source = File.expand_path(path.to_s)
        raise 'Không tìm thấy file ảnh.' unless File.file?(source)
        raise 'Ảnh phải có dung lượng không quá 20 MiB.' unless File.size(source).between?(1, MAX_IMAGE_BYTES)
        enqueue(path: source, name: File.basename(source), mime: ImageFormats.mime(source), source_type: :file)
      rescue StandardError => error
        Session.show_error(error.message)
        false
      end

      def add_bytes(name, bytes, mime = nil)
        raise 'Ảnh phải có dung lượng không quá 20 MiB.' unless bytes.bytesize.between?(1, MAX_IMAGE_BYTES)
        type = ImageFormats.mime(name, bytes, mime)
        path = TempFiles.write_bytes(name, bytes, ImageFormats.extension(type))
        result = enqueue(path: path, name: File.basename(name.to_s), mime: type, source_type: :drop, owned: [path])
        TempFiles.release(path) unless result
        result
      rescue StandardError => error
        TempFiles.release(path) if path
        Session.show_error(error.message)
        false
      end

      def add_urls(json, name = nil)
        urls = JSON.parse(json.to_s)
        raise 'Dữ liệu link ảnh không hợp lệ.' unless urls.is_a?(Array) && urls.length.between?(1, 8)
        raise 'Link ảnh quá dài.' unless urls.all? { |url| url.is_a?(String) && url.bytesize <= 8192 }
        enqueue(urls: urls, name: name.to_s[0, 200], source_type: :web)
      rescue StandardError => error
        Session.show_error(error.message)
        false
      end

      def enqueue(data)
        Session.setup_for_model
        @queue ||= []
        raise 'Đang nhận nhiều ảnh. Hãy chờ lượt hiện tại xong.' if @queue.length >= 24
        Manager.open unless Manager.visible?
        raise 'Không mở được bảng quản lý ảnh.' unless Manager.visible?
        job = data.merge(token: SecureRandom.hex(16), model: Sketchup.active_model,
                         owned: data[:owned] || [], stage: :prepare, cancelled: false)
        @queue << job
        @results ||= Queue.new
        @timer ||= UI.start_timer(0.1, true) { pump }
        pump
        true
      end

      def pump
        drain_results
        if @active && (!@active[:model].equal?(Sketchup.active_model) || !Manager.visible?)
          @active[:cancelled] = true
        end
        if @active && @active[:cancelled] && @active[:stage] != :worker
          finish
        end
        @active ||= (@queue && @queue.shift)
        job = @active
        if job
          unless job[:model].equal?(Sketchup.active_model) && Manager.visible?
            job[:cancelled] = true
            return finish unless job[:stage] == :worker
          end
          case job[:stage]
          when :prepare
            Manager.import_status(true, "Đang nhận ảnh: #{job[:name].to_s.empty? ? 'ảnh web' : job[:name]}")
            if job[:urls]
              urls = job.delete(:urls)
              start_worker(job, :web) { WebImages.fetch(urls) }
            else
              prepare_path(job)
            end
          when :browser_pending
            raise 'Ảnh phải có dung lượng không quá 20 MiB.' unless File.size(job[:path]).between?(1, MAX_IMAGE_BYTES)
            raise 'Bảng quản lý chưa sẵn sàng. Hãy mở lại bảng và thả ảnh.' if monotonic > job[:deadline]
            if Manager.ready?
              bytes = File.binread(job[:path])
              job[:mime] = ImageFormats.mime(job[:name], bytes, job[:mime])
              job[:stage] = :browser
              job[:deadline] = monotonic + 50
              Manager.decode_image(token: job[:token], name: job[:name], mime: job[:mime], base64: Base64.strict_encode64(bytes))
            end
          when :browser
            conversion_error(job[:token], 'Quá thời gian giải mã trong trình duyệt.') if monotonic > job[:deadline]
          end
        elsif !@timer.nil?
          UI.stop_timer(@timer)
          @timer = nil
          Manager.import_status(false, '')
        end
      rescue StandardError => error
        fail_job(error.message)
      end

      def prepare_path(job)
        raise 'Ảnh phải có dung lượng không quá 20 MiB.' unless File.size(job[:path]).between?(1, MAX_IMAGE_BYTES)
        begin
          image, = ImageLoader.load(job[:path])
        rescue StandardError
          job[:stage] = :browser_pending
          job[:deadline] = monotonic + 15
          return
        end
        path = job[:path]
        unless %w[.jpg .jpeg .png .bmp].include?(File.extname(path).downcase)
          # Chromium cannot thumbnail TIFF/TGA; keep a PNG for redraw and preview.
          path = TempFiles.write_bytes(job[:name], ''.b, '.png')
          job[:owned] << path
          raise 'Không chuyển được ảnh sang PNG.' unless image.save_file(path)
          raise 'Ảnh sau chuyển đổi vượt dung lượng 64 MiB.' unless File.size(path).between?(1, MAX_CONVERTED_BYTES)
        end
        import_ready(job, path, image)
      end

      def start_worker(job, kind, &work)
        token = job[:token]
        results = @results
        job[:stage] = :worker
        job[:work_kind] = kind
        Thread.new do
          begin
            results << [token, work.call, nil]
          rescue StandardError => error
            results << [token, nil, error.message]
          end
        end
      end

      def drain_results
        return unless @results
        loop do
          result = @results.pop(true)
          job = @active
          next unless job && job[:token] == result[0]
          if job[:cancelled] || !job[:model].equal?(Sketchup.active_model) || !Manager.visible?
            finish
          elsif result[2]
            fail_job(result[2])
          elsif job[:work_kind] == :web
            payload = result[1]
            job[:name] = payload[:name] if job[:name].to_s.empty?
            job[:mime] = payload[:mime]
            job[:path] = TempFiles.write_bytes(job[:name], payload[:bytes], ImageFormats.extension(payload[:mime]))
            job[:owned] << job[:path]
            job[:stage] = :prepare
          else
            path = result[1]
            image, = ImageLoader.load(path)
            import_ready(job, path, image)
          end
        end
      rescue ThreadError
        nil
      end

      def conversion_start(token, size, chunks)
        job = conversion_job(token)
        return false unless job
        size, chunks = Integer(size), Integer(chunks)
        raise 'Ảnh sau chuyển đổi vượt dung lượng 64 MiB.' unless size.between?(1, MAX_CONVERTED_BYTES)
        raise 'Số gói dữ liệu ảnh không hợp lệ.' unless chunks == (size + TRANSFER_CHUNK_BYTES - 1) / TRANSFER_CHUNK_BYTES
        raise 'Ảnh đã bắt đầu được truyền.' if job[:conversion]
        job[:conversion] = { size: size, chunks: chunks, next: 0, bytes: ''.b }
        true
      rescue StandardError => error
        fail_job(error.message)
        false
      end

      def conversion_chunk(token, index, encoded)
        job = conversion_job(token)
        buffer = job && job[:conversion]
        return false unless buffer
        raise 'Gói dữ liệu ảnh sai thứ tự.' unless Integer(index) == buffer[:next] && buffer[:next] < buffer[:chunks]
        raise 'Gói dữ liệu ảnh quá lớn.' if encoded.to_s.bytesize > (TRANSFER_CHUNK_BYTES * 4 / 3 + 8)
        bytes = Base64.strict_decode64(encoded.to_s)
        expected = [TRANSFER_CHUNK_BYTES, buffer[:size] - buffer[:bytes].bytesize].min
        raise 'Gói dữ liệu ảnh không đủ dung lượng.' unless bytes.bytesize == expected
        buffer[:bytes] << bytes
        buffer[:next] += 1
        job[:deadline] = monotonic + 30
        true
      rescue StandardError => error
        fail_job(error.message)
        false
      end

      def conversion_finish(token)
        job = conversion_job(token)
        buffer = job && job[:conversion]
        return false unless buffer
        raise 'Dữ liệu ảnh chưa đầy đủ.' unless buffer[:bytes].bytesize == buffer[:size] && buffer[:next] == buffer[:chunks]
        raise 'Dữ liệu chuyển đổi không phải PNG.' unless buffer[:bytes].start_with?("\x89PNG\r\n\x1a\n".b)
        path = TempFiles.write_bytes(job[:name], buffer[:bytes], '.png')
        job[:owned] << path
        job.delete(:conversion)
        image, = ImageLoader.load(path)
        import_ready(job, path, image)
        true
      rescue StandardError => error
        fail_job(error.message)
        false
      end

      def conversion_error(token, _error)
        job = conversion_job(token)
        return false unless job
        job.delete(:conversion)
        unless Sketchup.platform == :platform_win
          return fail_job('Không có bộ giải mã phù hợp với định dạng ảnh này.')
        end
        source = job[:path]
        destination = TempFiles.write_bytes(job[:name], ''.b, '.png')
        job[:owned] << destination
        start_worker(job, :wic) { convert_windows(source, destination) }
        true
      end

      def convert_windows(source, destination)
        executable = File.join(ENV.fetch('SystemRoot', 'C:/Windows'), 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe')
        args = [executable, '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-STA', '-ExecutionPolicy', 'Bypass',
                '-File', File.join(__dir__, 'convert_image.ps1'), '-Source', source, '-Destination', destination]
        Open3.popen3(*args) do |input, output, errors, waiter|
          input.close
          readers = [Thread.new { output.read }, Thread.new { errors.read }]
          begin
            unless waiter.join(30)
              Process.kill('KILL', waiter.pid) rescue nil
              raise 'Quá thời gian chuyển đổi ảnh bằng codec Windows.'
            end
            unless waiter.value.success? && File.file?(destination) && File.size(destination).between?(1, MAX_CONVERTED_BYTES)
              raise 'Không giải mã được định dạng này. HEIC/HEIF cần codec HEIF trên Windows; có thể đổi ảnh sang PNG/WebP.'
            end
          ensure
            readers.each { |thread| thread.kill if thread.alive? }
          end
        end
        destination
      end

      def conversion_job(token)
        job = @active
        job if job && job[:stage] == :browser && job[:token] == token.to_s && !job[:cancelled] && job[:model].equal?(Sketchup.active_model)
      end

      def import_ready(job, path, image)
        raise 'Model đã đổi. Hãy thả ảnh lại trong model hiện tại.' unless job[:model].equal?(Sketchup.active_model)
        item = Session.add_reference(path, source_type: job[:source_type], display_name: job[:name], image_rep: image)
        raise 'Không thể thêm ảnh tham chiếu.' unless item
        finish(keep: path)
      end

      def fail_job(message)
        ImageLoader.log_error('Image import failed', RuntimeError.new(message))
        Session.show_error(message)
        finish
        false
      end

      def finish(keep: nil)
        job = @active
        @active = nil
        if job
          Array(job[:owned]).each { |path| TempFiles.release(path) unless path == keep }
        end
        Manager.import_status(false, '')
      end

      def cancel_all
        Array(@queue).each { |job| Array(job[:owned]).each { |path| TempFiles.release(path) } }
        @queue = []
        if @active
          @active[:cancelled] = true
          finish unless @active[:stage] == :worker
        end
      end

      def monotonic
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
