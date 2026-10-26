module VGD_Cabinet_Draw
  # Tự cập nhật tủ khi kéo Scale xong (kiểu Dynamic Component): không cần mở Box → Board.
  # SketchUp báo khi một thao tác kết thúc (onTransactionCommit). Lúc đó chỉ đặt lịch; việc co giãn chạy ở
  # lượt kế tiếp, để không sửa model ngay trong lúc SketchUp đang kết thúc thao tác Scale.
  module AutoStretch
    extend self

    SECTION = 'VGD_Cabinet_Draw'.freeze
    PREF_KEY = 'auto_stretch'.freeze
    OPERATION_NAME = 'VGD Cabinet Draw — Tự cập nhật tủ'.freeze

    class ModelWatcher < Sketchup::ModelObserver
      def onTransactionCommit(model)
        VGD_Cabinet_Draw::AutoStretch.after_commit(model)
      end
    end

    class AppWatcher < Sketchup::AppObserver
      def onNewModel(model)
        VGD_Cabinet_Draw::AutoStretch.attach(model)
      end

      def onOpenModel(model)
        VGD_Cabinet_Draw::AutoStretch.attach(model)
      end
    end

    # Mặc định BẬT. Lưu theo người dùng trên máy (không theo từng file model).
    def enabled?
      Sketchup.read_default(SECTION, PREF_KEY, true) ? true : false
    end

    def enabled=(value)
      Sketchup.write_default(SECTION, PREF_KEY, value ? true : false)
    end

    # Gắn bộ theo dõi vào model đang mở. Gắn lại nhiều lần thì không sinh thêm bộ theo dõi trùng.
    def attach(model = Sketchup.active_model)
      return unless model && model.respond_to?(:add_observer)
      @watcher ||= ModelWatcher.new
      model.remove_observer(@watcher)
      model.add_observer(@watcher)
      @app_watcher ||= AppWatcher.new
      Sketchup.add_observer(@app_watcher) unless @app_registered
      @app_registered = true
    end

    # Sau mỗi thao tác: nếu một tủ đang chọn vừa bị Scale thì đặt lịch co giãn. Lượt chạy tự kiểm tra lại.
    def after_commit(model)
      return if @busy || @scheduled || !enabled?
      roots = model.selection.to_a.select { |entity| ModelData.cabinet?(entity) && entity.valid? }
      return if roots.empty?
      @scheduled = true
      UI.start_timer(0.0, false) do
        @scheduled = false
        stretch_scaled(roots)
      end
    end

    def stretch_scaled(roots)
      roots.each do |root|
        next unless root.valid? && scaled?(root)
        stretch_one(Sketchup.active_model, root)
      end
    end

    # Tủ bị lật gương hoặc xiên thì không co giãn được: báo người dùng để sửa theo hướng dẫn.
    def scaled?(root)
      Rebuild.scale_of(root) ? true : false
    rescue ArgumentError => e
      UI.messagebox("Không tự cập nhật được tủ: #{e.message}")
      false
    end

    def stretch_one(model, root)
      warnings = []
      @busy = true
      model.start_operation(OPERATION_NAME, true)
      begin
        warnings = Rebuild.stretch(root)
        model.commit_operation
      rescue StandardError => e
        model.abort_operation
        UI.messagebox("Không tự cập nhật được tủ, tủ giữ nguyên trạng thái đã kéo Scale:\n#{e.message}")
        return
      ensure
        @busy = false
      end
      report(warnings)
    end

    def report(warnings)
      Dialog.set_status('Đã tự cập nhật tủ theo kích thước mới.')
      return if warnings.empty?
      UI.messagebox("Tự cập nhật tủ xong, lưu ý:\n• #{warnings.uniq.join("\n• ")}")
    end
  end
end
