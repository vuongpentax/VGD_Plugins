# encoding: UTF-8
# Lightweight, cross-platform update notices for VGD SketchUp extensions.
require 'json'
require 'uri'

module VGD
  module UpdateNotice
    extend self
    MAX_MANIFEST = 64 * 1024 unless const_defined?(:MAX_MANIFEST, false)
    TIMEOUT = 25 unless const_defined?(:TIMEOUT, false)
    CHECK_INTERVAL = 24 * 60 * 60 unless const_defined?(:CHECK_INTERVAL, false)

    def start(product_id, product_name, current_version)
      @product_id = product_id.to_s
      @product_name = product_name.to_s
      @current_version = current_version.to_s
      section = "VGDUpdate_#{@product_id}"
      return unless ::UI.respond_to?(:start_timer) && ::Sketchup.respond_to?(:read_default) && ::Sketchup.respond_to?(:write_default)
      unless @menu_added
        ::UI.menu('Extensions').add_item("Kiểm tra cập nhật #{@product_name}…") { check(true) }
        @menu_added = true
      end
      return unless due?(section)
      ::UI.start_timer(18.0, false) do
        mark_checked(section)
        check(false)
      end
    rescue StandardError => error
      warn("[VGD Update] #{error.message}")
    end

    def check(manual)
      raise 'Thiếu cấu hình updater.' unless @product_id && @current_version
      uri = URI("https://raw.githubusercontent.com/vuongpentax/VGD_Plugins/main/updates/#{@product_id}.json")
      request = ::Sketchup::Http::Request.new(uri.to_s, ::Sketchup::Http::GET)
      request.headers = { 'User-Agent' => "VGD-UpdateNotice/#{@product_id}" }
      done = false
      timer = ::UI.start_timer(TIMEOUT, false) do
        next if done
        done = true
        begin
          request.cancel if request.respond_to?(:cancel)
        rescue StandardError
        end
        ::UI.messagebox("Hết thời gian chờ khi kiểm tra cập nhật #{@product_name}.") if manual
      end
      request.start do |_req, response|
        next if done
        done = true
        ::UI.stop_timer(timer) if timer
        begin
          raise "GitHub trả HTTP #{response.status_code}." unless response.status_code.to_i == 200
          body = response.body.to_s
          raise 'Manifest cập nhật vượt giới hạn.' if body.bytesize > MAX_MANIFEST
          info = JSON.parse(body)
          raise 'Manifest không khớp plugin.' unless info.is_a?(Hash) && info['product_id'] == @product_id
          raise 'Manifest thiếu phiên bản hoặc link RBZ.' unless info['version'].is_a?(String) && info['download_url'].is_a?(String)
          download = URI(info['download_url'])
          raise 'Link tải phải là HTTPS từ GitHub.' unless download.is_a?(URI::HTTPS) && %w[github.com objects.githubusercontent.com release-assets.githubusercontent.com].include?(download.host)
          min_year = info['min_sketchup_year'].to_i
          year = 2000 + (::Sketchup.version_number.to_i / 100_000_000)
          raise 'Bản cập nhật yêu cầu SketchUp mới hơn.' if min_year > 0 && year < min_year
          if newer?(info['version'], @current_version)
            message = "#{@product_name} có phiên bản thử nghiệm mới #{info['version']} (đang dùng #{@current_version}).\n\n#{info['changelog']}\n\nMở trang tải RBZ? Cần cài trong Extension Manager rồi khởi động lại SketchUp."
            ::UI.openURL(download.to_s) if ::UI.messagebox(message, ::MB_YESNO) == ::IDYES
          elsif manual
            ::UI.messagebox("#{@product_name} đang ở bản mới nhất (#{@current_version}).")
          end
        rescue StandardError => error
          ::UI.messagebox("Không kiểm tra được cập nhật #{@product_name}: #{error.message}") if manual
          warn("[VGD Update] #{error.message}")
        end
      end
    rescue StandardError => error
      ::UI.messagebox("Không kiểm tra được cập nhật #{@product_name}: #{error.message}") if manual
      warn("[VGD Update] #{error.message}")
    end

    def version_key(value)
      core, pre = value.to_s.split('-', 2)
      numbers = core.to_s.split('.').map { |part| Integer(part) rescue 0 }
      [numbers, pre]
    end

    def newer?(remote, current)
      remote_core, remote_pre = version_key(remote)
      current_core, current_pre = version_key(current)
      length = [remote_core.length, current_core.length].max
      (0...length).each do |index|
        comparison = (remote_core[index] || 0) <=> (current_core[index] || 0)
        return comparison > 0 unless comparison == 0
      end
      return false if current_pre.nil?
      return true if remote_pre.nil?
      remote_parts = remote_pre.split(/[.-]/)
      current_parts = current_pre.split(/[.-]/)
      [remote_parts.length, current_parts.length].max.times do |index|
        left = remote_parts[index]
        right = current_parts[index]
        return false if left.nil?
        return true if right.nil?
        comparison = if left.match?(/\A\d+\z/) && right.match?(/\A\d+\z/)
          left.to_i <=> right.to_i
        elsif left.match?(/\A\d+\z/)
          -1
        elsif right.match?(/\A\d+\z/)
          1
        else
          left <=> right
        end
        return comparison > 0 unless comparison == 0
      end
      false
    end

    private
    def due?(section)
      ::Time.now.to_i - ::Sketchup.read_default(section, 'last_check', 0).to_i >= CHECK_INTERVAL
    end

    def mark_checked(section)
      ::Sketchup.write_default(section, 'last_check', ::Time.now.to_i)
    end
  end
end
