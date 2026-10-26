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
      selection = model.selection.to_a.select(&:valid?)
      # Tủ con của group 'Tủ quá khổ' cũng được tính (group chọn = chọn cả hai tủ).
      roots = ModelData.cabinets_in(selection)
      splits = selection.select { |entity| ModelData.split_group?(entity) && Geometry.split_scaled?(entity) }
      return if roots.empty? && splits.empty?
      @scheduled = true
      UI.start_timer(0.0, false) do
        @scheduled = false
        stretch_scaled(ModelData.cabinets_in(selection), splits)
      end
    end

    # Gom mọi thông báo của lượt này vào MỘT hộp thoại. Tủ đã lỗi ở đúng trạng thái Scale đó thì không thử lại
    # (và không báo lại) cho tới khi người dùng kéo Scale tiếp.
    def stretch_scaled(roots, splits = [])
      issues = []
      push_split_scales(splits, issues) unless splits.empty?
      roots = roots.select(&:valid?)
      roots.each do |root|
        next unless root.valid? && scaled?(root) && !failed?(root)
        issues.concat(stretch_one(Sketchup.active_model, root))
      end
      UI.messagebox("Tự cập nhật tủ:\n• #{issues.uniq.join("\n• ")}") unless issues.empty?
    end

    # Group quá khổ bị Scale: đưa phép scale xuống hai tủ con trong một thao tác (Undo được).
    def push_split_scales(splits, issues)
      model = Sketchup.active_model
      @busy = true
      model.start_operation(OPERATION_NAME, true)
      splits.each { |group| Geometry.push_split_scale(group) if group.valid? && Geometry.split_scaled?(group) }
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      issues << "Không đưa được Scale xuống tủ quá khổ: #{e.message}"
    ensure
      @busy = false
    end

    def failed?(root)
      @failed ? @failed[root.persistent_id] == root.transformation.to_a : false
    end

    def remember_failure(root)
      (@failed ||= {})[root.persistent_id] = root.transformation.to_a
    end

    # Tủ bị lật gương hoặc xiên thì không co giãn được: báo người dùng để sửa theo hướng dẫn.
    def scaled?(root)
      Rebuild.scale_of(root) ? true : false
    rescue ArgumentError => e
      Dialog.set_status("Không tự cập nhật được tủ: #{e.message}")
      false
    end

    # Một thao tác: co giãn rồi commit. Lỗi khi co giãn thì hủy thao tác (tủ giữ nguyên trạng thái đã kéo).
    # Trả về danh sách thông báo (lỗi hoặc lưu ý) để người gọi hiện chung một lần.
    def stretch_one(model, root)
      @busy = true
      model.start_operation(OPERATION_NAME, true)
      warnings = begin
        Rebuild.stretch(root)
      rescue StandardError => e
        model.abort_operation
        remember_failure(root)
        return ["Không tự cập nhật được tủ, tủ giữ nguyên trạng thái đã kéo Scale: #{e.message}"]
      end
      messages = warnings.dup
      begin
        model.commit_operation
      rescue StandardError => e
        messages.unshift("Tủ đã cập nhật nhưng SketchUp báo lỗi khi ghi thao tác: #{e.message}")
      end
      @failed&.delete(root.persistent_id)
      Dialog.set_status('Đã tự cập nhật tủ theo kích thước mới.') if messages.empty?
      messages
    ensure
      @busy = false
    end
  end
end
