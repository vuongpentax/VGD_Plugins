# encoding: UTF-8
module VGD
  module Dim
    module UpdateCore
      class Updater
        PREF_KEY = 'update_last_check_at'.freeze
        CHECK_INTERVAL = 24 * 60 * 60
        def initialize
          @client = Client.new
          @last_manifest = nil
          @install_pending = false
        end
        def check(&callback)
          if Sketchup.respond_to?(:platform) && Sketchup.platform != :platform_win
            callback.call(:error, 'Updater pilot hiện chỉ hỗ trợ Windows.') if callback
            return
          end
          @client.check do |status, body|
            if status == 200
              begin
                info = Manifest.parse(body)
                year = 2000 + (Sketchup.version_number.to_i / 100_000_000)
                raise 'Bản cập nhật yêu cầu SketchUp mới hơn.' if year < info['min_sketchup_year'].to_i
                if newer?(info['version'], VGD::Dim::VERSION)
                  @last_manifest = info
                  callback.call(:available, info) if callback
                else
                  callback.call(:current, info) if callback
                end
              rescue StandardError => error
                callback.call(:error, error.message) if callback
              end
            else
              callback.call(:error, body.to_s) if callback
            end
          end
        end
        def download_and_install(info = @last_manifest, &callback)
          raise 'Một bản cập nhật đã được khởi chạy.' if @install_pending
          raise 'Không có thông tin bản cập nhật.' unless info
          @install_pending = true
          @client.download(info) do |status, value|
            if status == :ok
              begin
                Installer.start(info, value)
                callback.call(:started, info) if callback
              rescue StandardError => error
                @install_pending = false
                callback.call(:error, error.message) if callback
              end
            else
              @install_pending = false
              callback.call(:error, value) if callback
            end
          end
        rescue StandardError => error
          @install_pending = false
          callback.call(:error, error.message) if callback
        end
        def self.version_key(value)
          core, suffix = value.split('-', 2)
          numbers = core.split('.').map(&:to_i)
          numbers + (suffix ? [0, suffix] : [1, ''])
        end
        def self.newer?(remote, current)
          (version_key(remote) <=> version_key(current)) > 0
        end
        def newer?(remote, current)
          self.class.newer?(remote, current)
        end
        def self.due?
          last = Sketchup.read_default('VGDDimUpdater', PREF_KEY, 0).to_i
          Time.now.to_i - last >= CHECK_INTERVAL
        end
        def self.mark_checked
          Sketchup.write_default('VGDDimUpdater', PREF_KEY, Time.now.to_i)
        end
      end
      module UIHooks
        extend self
        def start
          return if @started
          @started = true
          @updater ||= Updater.new
          unless @menu_added
            UI.menu('Extensions').add_item('Kiểm tra cập nhật VGD Dim') { check(true) }
            @menu_added = true
          end
          @timer = UI.start_timer(15.0, false) do
            if Updater.due?
              Updater.mark_checked
              check(false)
            end
          end
        end
        def shutdown
          UI.stop_timer(@timer) if @timer
          @timer = nil
          @started = false
        end
        def check(manual)
          @updater.check do |status, value|
            if status == :available
              message = "VGD Dim có phiên bản mới #{value['version']} (hiện tại #{VGD::Dim::VERSION}).\n\n#{value['changelog']}\n\nCập nhật ngay? SketchUp sẽ cần đóng để hoàn tất."
              if UI.messagebox(message, MB_YESNO) == IDYES
                @updater.download_and_install(value) do |result, detail|
                  if result == :started
                    UI.messagebox('Đã tải và xác minh gói. Helper sẽ chờ SketchUp đóng rồi mới cài; hãy lưu model và thoát SketchUp khi sẵn sàng.')
                  else
                    UI.messagebox("Không thể cập nhật VGD Dim: #{detail}")
                  end
                end
              end
            elsif status == :current && manual
              UI.messagebox("VGD Dim đã ở phiên bản mới nhất (#{VGD::Dim::VERSION}).")
            elsif status == :error && manual
              UI.messagebox("Không kiểm tra được cập nhật VGD Dim: #{value}")
            end
          end
        end
      end
    end
  end
end
