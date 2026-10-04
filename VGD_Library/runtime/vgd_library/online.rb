# encoding: UTF-8
module VGD
  module Library
    module Online
      MAX_CATALOG = 5_000_000
      MAX_ASSET = 250_000_000

      def self.sources
        value = Catalog.read_json('online_sources', [])
        value.is_a?(Array) ? value.select { |v| v.is_a?(Hash) && v['url'].is_a?(String) } : []
      end

      def self.https(url)
        uri = URI.parse(url.to_s)
        raise 'Nguồn online phải là URL HTTPS hợp lệ.' unless uri.is_a?(URI::HTTPS) && uri.host && !uri.userinfo
        uri.to_s
      rescue URI::InvalidURIError
        raise 'URL online không hợp lệ.'
      end

      def self.add(url)
        url = https(url)
        Catalog.save('online_sources', (sources + [{ 'url' => url }]).uniq { |source| source['url'] })
      end

      def self.import_catalog(path)
        source = { 'url' => Catalog.file_url(path), 'local' => File.expand_path(path) }
        raw = File.binread(path)
        manifest(raw, source)
        data = JSON.parse(raw)
        source['label'] = data['name'].to_s.empty? ? File.basename(path, '.*') : data['name'].to_s
        Catalog.save('online_sources', (sources + [source]).uniq { |entry| entry['url'] })
      end

      def self.root(source)
        'online:' + Digest::SHA256.hexdigest(source['url'])
      end

      def self.remove(id)
        Catalog.save('online_sources', sources.reject { |source| root(source) == id })
      end

      def self.manifest(raw, source)
        raise 'Danh mục online quá lớn.' if raw.bytesize > MAX_CATALOG
        data = JSON.parse(raw)
        raise 'Danh mục online cần mảng items.' unless data.is_a?(Hash) && data['items'].is_a?(Array)
        raise 'Danh mục online vượt 20000 mẫu.' if data['items'].size > Catalog::LIMIT
        data['items'].map do |entry|
          raise 'Mẫu online không hợp lệ.' unless entry.is_a?(Hash)
          url = https(entry['url'])
          format = entry['format'].to_s.upcase
          raise 'Định dạng online không hỗ trợ.' unless %w[SKP SKM JPG JPEG PNG BMP TIF TIFF].include?(format)
          sha = entry['sha256'].to_s.downcase
          raise 'Mỗi mẫu online cần SHA-256 (64 ký tự hex).' unless sha.match?(/\A[0-9a-f]{64}\z/)
          { id: Digest::SHA256.hexdigest(source['url'] + '|' + url + '|' + sha), name: entry['name'].to_s,
            root: root(source), category: [entry['brand'], entry['category']].compact.map(&:to_s).reject(&:empty?).join(' / '),
            format: format, kind: format == 'SKP' ? 'model' : 'material',
            preview: entry['preview'] ? https(entry['preview']) : nil, url: url, sha256: sha,
            width: entry['width_mm'], height: entry['height_mm'], online: true }
        end
      end

      def self.request(url, max_size, &callback)
        request = Sketchup::Http::Request.new(https(url), Sketchup::Http::GET)
        (@requests ||= []) << request
        request.set_download_progress_callback { |current, total| request.cancel if current > max_size || total > max_size }
        request.start do |_request, response|
          @requests.delete(request)
          if response.status_code.to_i == 200 && response.body && response.body.bytesize <= max_size
            callback.call(response.body, nil)
          else
            callback.call(nil, "Không tải được nguồn online (HTTP #{response.status_code}; giới hạn #{max_size / 1_000_000} MB).")
          end
        end
      rescue StandardError => e
        callback.call(nil, e.message)
      end

      def self.check_update
        url = Catalog.read_json('update_manifest', '')
        url = '' unless url.is_a?(String)
        if url.empty?
          remote = sources.find { |source| !source['local'] }
          input = UI.inputbox(['URL HTTPS thông tin cập nhật VGD (JSON)'], [remote ? remote['url'] : 'https://'], 'Nguồn cập nhật VGD')
          return unless input
          url = https(input[0])
          Catalog.save('update_manifest', url)
        end
        request(url, MAX_CATALOG) do |raw, error|
          Library.safely do
            raise(error) if error
            data = JSON.parse(raw)
            info = data['extension']
            raise 'Danh mục chưa có mục extension.version / extension.url cho cập nhật VGD.' unless info.is_a?(Hash) && info['version'].is_a?(String) && info['url']
            download = https(info['url'])
            current_numbers = Library::VERSION.split(/[.-]/).first(3).map(&:to_i)
            latest_numbers = info['version'].split(/[.-]/).first(3).map(&:to_i)
            comparison = latest_numbers <=> current_numbers
            newer = comparison > 0 || (comparison == 0 && Library::VERSION.include?('beta') && !info['version'].include?('beta'))
            if newer
              answer = UI.messagebox("VGD_Library hiện tại: #{Library::VERSION}\nBản mới: #{info['version']}\n\nMở đường tải RBZ?", MB_YESNO)
              UI.openURL(download) if answer == IDYES
            else
              Library.message("Nguồn cập nhật VGD báo bản #{info['version']}; đang dùng #{Library::VERSION}.")
            end
          end
        end
      end

      def self.refresh(&callback)
        list = sources
        update = nil
        index = 0
        update = lambda do
          if index >= list.size
            callback.call([], [], true)
            next
          end
          source = list[index]
          index += 1
          cache = File.join(Storage.dir('online'), Digest::SHA256.hexdigest(source['url']) + '.json')
          consume = lambda do |raw, error|
            items, warnings = [], []
            begin
              if raw
                items = manifest(raw, source)
                File.binwrite(cache, raw)
              elsif File.file?(cache)
                items = manifest(File.binread(cache), source)
                warnings << 'Dùng danh mục online đã lưu vì nguồn không truy cập được.'
              else
                warnings << error
              end
            rescue StandardError => e
              warnings << "Nguồn online: #{e.message}"
            end
            callback.call(items, warnings, false)
            update.call
          end
          if source['local']
            begin
              consume.call(File.binread(source['local']), nil)
            rescue StandardError => e
              consume.call(nil, e.message)
            end
          else
            request(source['url'], MAX_CATALOG, &consume)
          end
        end
        update.call
      end

      def self.obtain(item, &callback)
        path = File.join(Storage.dir('downloads'), item[:id] + '.' + item[:format].downcase)
        if File.file?(path) && Digest::SHA256.file(path).hexdigest == item[:sha256]
          callback.call(item.merge(path: path), nil)
          return
        end
        request(item[:url], MAX_ASSET) do |bytes, error|
          begin
            raise(error || 'Không có dữ liệu tải về.') unless bytes
            raise 'Tệp tải về không khớp SHA-256 của danh mục.' unless Digest::SHA256.hexdigest(bytes) == item[:sha256]
            temp = path + '.part'
            File.binwrite(temp, bytes)
            File.rename(temp, path)
            callback.call(item.merge(path: path), nil)
          rescue StandardError => e
            File.delete(temp) if temp && File.file?(temp)
            callback.call(nil, e.message)
          end
        end
      end
    end
  end
end
