# encoding: UTF-8
require 'digest'
require 'uri'
module VGD
  module Dim
    module UpdateCore
      class Client
        TIMEOUT = 30
        def initialize
          @busy = false
          @request_id = 0
        end
        def check(&callback)
          request(Manifest::MANIFEST_URL, 0, &callback)
        end
        def download(info, &callback)
          raise 'Đang có yêu cầu cập nhật khác.' if @busy
          request(info['download_url'], 0) do |status, body|
            if status == 200 && body.bytesize == info['bytes'] && Digest::SHA256.hexdigest(body) == info['sha256']
              callback.call(:ok, body)
            elsif status != 200
              callback.call(:error, "GitHub trả về HTTP #{status}.")
            else
              callback.call(:error, 'Tải xuống không khớp kích thước hoặc SHA-256.')
            end
          end
        rescue StandardError => error
          @busy = false
          callback.call(:error, error.message)
        end
        private
        def request(url, redirects, &callback)
          raise 'Đang có yêu cầu cập nhật khác.' if @busy
          @busy = true
          @request_id += 1
          request_id = @request_id
          uri = URI.parse(url)
          req = Sketchup::Http::Request.new(uri.to_s, Sketchup::Http::GET)
          req.headers = { 'User-Agent' => "VGD-Dim-Updater/#{VGD::Dim::VERSION}" }
          timer = UI.start_timer(TIMEOUT, false) do
            next unless @request_id == request_id
            @request_id += 1
            begin
              req.cancel if req.respond_to?(:cancel)
            rescue StandardError
            end
            @busy = false
            callback.call(0, 'Hết thời gian chờ kết nối.')
          end
          req.start do |_request, response|
            next unless @request_id == request_id
            UI.stop_timer(timer) if timer
            code = response.status_code.to_i
            if [301, 302, 303, 307, 308].include?(code) && redirects < 3
              location = response.headers['Location'] || response.headers['location']
              @busy = false
              if location
                target = URI.join(uri.to_s, location)
                allowed_host = target.host == 'github.com' || target.host.to_s.end_with?('.githubusercontent.com')
                if target.scheme == 'https' && allowed_host
                  request(target.to_s, redirects + 1, &callback)
                else
                  callback.call(0, 'Địa chỉ chuyển hướng không an toàn hoặc không thuộc GitHub.')
                end
              else
                callback.call(code, 'Máy chủ không cung cấp địa chỉ chuyển hướng.')
              end
            else
              @busy = false
              callback.call(code, response.body.to_s)
            end
          end
        rescue StandardError => error
          @busy = false
          UI.stop_timer(timer) if defined?(timer) && timer
          callback.call(0, error.message)
        end
      end
    end
  end
end
