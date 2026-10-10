require 'net/http'
require 'uri'
require 'openssl'
require 'timeout'
require 'resolv'
require 'ipaddr'
require 'cgi'

module VGD
  module Reference
    # Pure network/byte work. Called from a worker; never calls SketchUp or UI.
    module WebImages
      module_function

      BLOCKED_NETWORKS = %w[0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
                            192.168.0.0/16 100.64.0.0/10 224.0.0.0/4 ::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8].map { |value| IPAddr.new(value) }.freeze

      def fetch(candidates)
        Timeout.timeout(45) do
          Array(candidates).first(8).each do |candidate|
            begin
              uri, mime, bytes = request(candidate)
              if mime.include?('html') || bytes.byteslice(0, 512).to_s.match?(/<!doctype html|<html[\s>]/i)
                image_url = page_image(bytes, uri)
                raise 'Trang này không cung cấp link ảnh công khai. Hãy kéo trực tiếp ảnh vào bảng.' unless image_url
                uri, mime, bytes = request(image_url, referer: uri.to_s)
              end
              type = ImageFormats.mime(uri.path, bytes, mime)
              raise 'Link không trả về dữ liệu ảnh.' unless type.start_with?('image/') || mime == 'application/octet-stream'
              filename = CGI.unescape(File.basename(uri.path)).encode('UTF-8', invalid: :replace, undef: :replace)
              filename = 'anh-web' if filename.empty? || filename == '/' || filename == '.'
              filename += ImageFormats.extension(type) if File.extname(filename).empty?
              return { bytes: bytes, name: filename, mime: type }
            rescue Timeout::Error
              raise
            rescue StandardError
              next
            end
          end
          raise 'Không tải được ảnh từ link này. Hãy kéo trực tiếp ảnh hoặc dùng link ảnh công khai.'
        end
      rescue Timeout::Error
        raise 'Tải ảnh quá thời gian. Hãy thử lại hoặc tải ảnh về máy rồi thả vào bảng.'
      end

      def request(address, referer: nil, redirects: 0)
        raise 'Link chuyển hướng quá nhiều lần.' if redirects > 5
        raise 'Link ảnh không hợp lệ.' if address.to_s.bytesize > 8192
        uri = URI.parse(address.to_s)
        unless %w[http https].include?(uri.scheme) && uri.host && !uri.userinfo && [80, 443].include?(uri.port)
          raise 'Chỉ nhận link ảnh HTTP hoặc HTTPS công khai.'
        end
        addresses = Resolv.getaddresses(uri.host)
        ip = addresses.find do |value|
          parsed = IPAddr.new(value)
          parsed = parsed.native if parsed.ipv4_mapped?
          BLOCKED_NETWORKS.none? { |network| network.include?(parsed) }
        end
        raise 'Link ảnh không phải địa chỉ web công khai.' unless ip
        http = Net::HTTP.new(uri.host, uri.port, nil)
        http.ipaddr = ip # Pin the validated destination; preserve hostname for TLS/Host.
        http.use_ssl = uri.scheme == 'https'
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?
        http.open_timeout = 10
        http.read_timeout = 15
        http.write_timeout = 15
        headers = { 'User-Agent' => 'Mozilla/5.0 VGDReference/1.0', 'Accept' => 'image/avif,image/webp,image/*,text/html;q=0.8,*/*;q=0.5' }
        headers['Referer'] = referer if referer
        result = nil
        redirect = nil
        http.start do |connection|
          connection.request(Net::HTTP::Get.new(uri.request_uri.empty? ? '/' : uri.request_uri, headers)) do |response|
            if response.is_a?(Net::HTTPRedirection)
              raise 'Link chuyển hướng không hợp lệ.' unless response['location']
              redirect = URI.join(uri.to_s, response['location']).to_s
            else
              raise 'Website không cho tải ảnh này.' unless response.is_a?(Net::HTTPSuccess)
              type = response['content-type'].to_s.split(';').first.to_s.downcase
              limit = type.include?('html') ? 2 * 1024 * 1024 : MAX_IMAGE_BYTES
              raise 'Ảnh web vượt dung lượng 20 MiB.' if response['content-length'].to_i > limit
              bytes = ''.b
              response.read_body do |part|
                raise 'Ảnh web vượt dung lượng 20 MiB.' if bytes.bytesize + part.bytesize > limit
                bytes << part
              end
              raise 'Link ảnh trả về dữ liệu rỗng.' if bytes.empty?
              result = [uri, type, bytes]
            end
          end
        end
        redirect ? request(redirect, referer: referer, redirects: redirects + 1) : result
      end

      def page_image(bytes, base)
        html = bytes.dup.force_encoding('UTF-8').scrub
        values = {}
        html.scan(/<meta\b[^>]*>/i).each do |tag|
          attrs = {}
          tag.scan(/([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/).each do |name, double, single, bare|
            attrs[name.downcase] = CGI.unescapeHTML(double || single || bare || '')
          end
          key = (attrs['property'] || attrs['name']).to_s.downcase
          values[key] ||= attrs['content'] if attrs['content']
        end
        value = values['og:image:secure_url'] || values['og:image'] || values['twitter:image'] || values['twitter:image:src']
        value && URI.join(base.to_s, value).to_s
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
