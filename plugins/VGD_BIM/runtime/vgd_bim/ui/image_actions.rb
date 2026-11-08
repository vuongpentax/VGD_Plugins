require 'json'
require 'fileutils'
require 'rbconfig'

module VGD
  module BIM
    module UI
      # Phần của cửa sổ BIM lo cho cài đặt chung (ngôn ngữ, thư mục ảnh) và ảnh món đồ: chụp ảnh khi người dùng bấm, nhận ảnh dán /
      # kéo thả, trả ảnh về giao diện khi giao diện không nạp được bằng đường dẫn file. Trộn vào UI::Dialog (dùng @model, @dialog, @table_records... của Dialog).
      # Ảnh chỉ được chụp khi người dùng bấm nút; không có chỗ nào tự chụp.
      module ImageActions
        MAX_CAPTURE_BATCH = 200 # số đối tượng tối đa cho một lần bấm chụp
        MAX_FULL_REQUEST = 6    # số ảnh gốc giao diện được xin mỗi lần (dự phòng; ảnh gốc nặng nên ít hơn trước)

        def register_image_callbacks
          @dialog.add_action_callback('settings_save') { |_ctx, payload| safely { settings_save(JSON.parse(payload)) } }
          @dialog.add_action_callback('settings_pick_dir') { |_ctx| safely { settings_pick_dir } }
          @dialog.add_action_callback('images_open_dir') { |_ctx| safely { images_open_dir } }
          @dialog.add_action_callback('images_capture') { |_ctx, payload| safely { images_capture(JSON.parse(payload)) } }
          @dialog.add_action_callback('images_cancel') { |_ctx| safely { @capture[:cancel] = true if @capture } }
          @dialog.add_action_callback('image_set') { |_ctx, payload| safely { image_set(JSON.parse(payload)) } }
          @dialog.add_action_callback('image_delete') { |_ctx, pid| safely { image_delete(pid) } }
          @dialog.add_action_callback('image_full') { |_ctx, payload| safely { image_full(JSON.parse(payload)) } }
        end

        # ---- Cài đặt ----
        def settings_payload
          dir = Settings.image_dir
          {settings: Settings.read, dir: dir, dir_exists: File.directory?(dir)}
        end

        def settings_save(payload)
          before = Settings.read
          language = before['language']
          Settings.update(payload)
          measure_changed = %w[exclude_words exclude_tags].any? { |key| Settings.read[key] != before[key] }
          if Settings.read['language'] != language
            refresh # đổi ngôn ngữ: gửi lại cấu hình và từ điển, vẽ lại cả cửa sổ
          else
            emit('settings', settings_payload)
          end
          table_build if measure_changed && @mode == 'table' # đổi cách đo thân: tính lại số đo của bảng ngay
          emit('message', {text: 'Đã lưu cài đặt.'})
        end

        def settings_pick_dir
          raise 'Bản SketchUp này không có hộp chọn thư mục. Hãy gõ đường dẫn thư mục vào ô.' unless ::UI.respond_to?(:select_directory)
          current = Settings.image_dir
          path = ::UI.select_directory(title: 'Chọn thư mục lưu ảnh', directory: File.directory?(current) ? current : Dir.home)
          return unless path
          Settings.update('image_dir' => path)
          emit('settings', settings_payload)
          emit('message', {text: 'Đã đổi thư mục lưu ảnh.'})
        end

        def images_open_dir
          dir = Settings.image_dir
          FileUtils.mkdir_p(dir)
          open_folder(dir)
        end

        # Windows: mở bằng explorer.exe với đường dẫn Windows. Mở bằng UI.openURL("file:///...") làm cửa sổ Explorer hiện ra bị dẹp lép.
        # Nơi khác dùng UI.openURL với địa chỉ file đã mã hóa.
        def open_folder(dir)
          if windows?
            launch_process('explorer.exe', File.expand_path(dir).tr('/', '\\'))
          else
            ::UI.openURL(TableReport.file_url(dir))
          end
        end

        def windows?
          RbConfig::CONFIG['host_os'].match?(/mswin|mingw|cygwin/i)
        end

        def launch_process(*args)
          Process.detach(Process.spawn(*args))
        end

        # ---- Chụp ảnh (nút trong Bảng khối lượng) ----
        # payload: {'indexes' => [dòng cần chụp] (không có = mọi dòng đang hiện), 'only_missing' => chỉ chụp dòng chưa có ảnh,
        #          'settings' => thiết lập ảnh của preset đang dùng (cỡ, góc nhìn, kiểu, nền); được kiểm tra lại ở đây}
        def images_capture(payload)
          check_model!
          raise 'Đang chụp ảnh. Hãy đợi xong hoặc bấm Dừng.' if @capture
          settings = Preset.settings!(payload.fetch('settings', {}))
          wanted = payload['indexes'].is_a?(Array) ? table_indexes(payload) : Array(@table_records).each_index.to_a
          jobs = wanted.map { |index| [index, @table_records.fetch(index) { raise 'Bảng đã cũ. Hãy làm mới bảng.' }] }
          jobs.reject! { |index, _| @table_rows[index][:has_image] } if payload['only_missing']
          raise 'Không có đối tượng nào cần chụp.' if jobs.empty?
          raise "Mỗi lần chỉ chụp tối đa #{MAX_CAPTURE_BATCH} đối tượng. Hãy chọn ít hơn." if jobs.size > MAX_CAPTURE_BATCH
          @capture = {queue: jobs, total: jobs.size, done: 0, errors: [], updated: [], cancel: false, notes: [], settings: settings}
          release_preview # khung đánh dấu không được lọt vào ảnh
          hide_overlay
          emit('images_progress', {done: 0, total: jobs.size})
          schedule_capture_step
        end

        # Mỗi lần một đối tượng, cách nhau một nhịp, để cửa sổ kịp báo tiến độ và nút Dừng bấm được.
        def schedule_capture_step
          ::UI.start_timer(0.05, false) { capture_step }
        end

        def capture_step
          job = @capture
          return unless job
          return finish_capture if @closed || job[:cancel] || job[:queue].empty?
          if @model != Sketchup.active_model # người dùng đã chuyển sang model khác: không chụp tiếp bằng model cũ
            job[:errors] << 'Mô hình đã thay đổi. Hãy làm mới trước khi tiếp tục.'
            return finish_capture
          end
          _index, record = job[:queue].shift
          begin
            result = Capture.shoot(@model, record, job[:settings])
            job[:updated] << result
            job[:notes] << result[:note] if result[:note]
          rescue StandardError => error
            BIM.log("Capture failed: #{error.message}")
            job[:errors] << "#{capture_label(record)}: #{capture_error_text(error)}"
          end
          job[:done] += 1
          emit('images_progress', {done: job[:done], total: job[:total]})
          schedule_capture_step
        rescue StandardError => error
          BIM.log("Capture step failed: #{error.message}")
          finish_capture
        end

        def finish_capture
          job = @capture
          @capture = nil
          return unless job
          unless @closed
            emit('images_changed', {items: job[:updated].map { |item| image_change(item[:pid], true, item[:stamp]) }})
            emit('images_done', {done: job[:done], total: job[:total], ok: job[:updated].size, errors: job[:errors].first(5), notes: job[:notes].uniq.first(3), cancelled: job[:cancel]})
            show_outline if @mode == 'table'
          end
        end

        def capture_label(record)
          name = record[:entity].respond_to?(:name) ? record[:entity].name.to_s.strip : ''
          name = Geometry.definition(record[:entity]).name.to_s.strip if name.empty?
          name.empty? ? 'Chưa đặt tên' : name
        rescue StandardError
          'Đối tượng'
        end

        def capture_error_text(error)
          return 'không ghi được file ảnh, kiểm tra thư mục lưu ảnh.' if error.is_a?(SystemCallError)
          return error.message if error.message.match?(/[À-ỹ]/)
          "lỗi #{error.class}: #{error.message[0, 140]} (chi tiết trong capture.log)"
        end

        # ---- Ảnh dán / kéo thả từ giao diện ----
        # payload: {'pid', 'full' (PNG base64)}. Chỉ nhận đối tượng đang có trong bảng.
        def image_set(payload)
          check_model!
          pid = known_pid!(payload['pid'])
          Images.write(@model, pid, Images.decode_png(payload['full']))
          emit('images_changed', {items: [image_change(pid, true, Images.info(@model, pid)[:stamp])]})
          emit('message', {text: 'Đã lưu ảnh cho đối tượng.'})
        end

        # Một mục của sự kiện images_changed: url là đường dẫn file ảnh gốc (kèm mốc thời gian để làm mới), nil khi không còn ảnh.
        def image_change(pid, has, stamp)
          {pid: pid, has: has, stamp: stamp, url: has ? Images.file_url(@model, pid, stamp) : nil}
        end

        def image_delete(pid)
          check_model!
          pid = known_pid!(pid)
          Images.delete(@model, pid)
          emit('images_changed', {items: [image_change(pid, false, 0)]})
          emit('message', {text: 'Đã xóa ảnh của đối tượng.'})
        end

        # Ảnh gốc dạng data URL cho các mã giao diện xin (dự phòng của ô ảnh hiện bằng đường dẫn file).
        def image_full(pids)
          raise 'Danh sách ảnh không hợp lệ.' unless pids.is_a?(Array)
          items = {}
          pids.first(MAX_FULL_REQUEST).each do |value|
            pid = Images.id!(value)
            next unless known_pid?(pid) # mã cũ (bảng đã đổi) thì bỏ qua, không báo lỗi
            url = Images.data_url(Images.path(@model, pid))
            items[pid.to_s] = url if url
          end
          emit('image_data', {items: items})
        end

        # Mã đối tượng giao diện gửi lên phải là của một đối tượng đang có trong bảng.
        def known_pid!(value)
          pid = Images.id!(value)
          raise 'Đối tượng không còn trong bảng. Hãy làm mới bảng.' unless known_pid?(pid)
          pid
        end

        def known_pid?(pid)
          Array(@table_records).any? { |record| record[:path].all?(&:valid?) && record[:entity].persistent_id == pid }
        end
      end
    end
  end
end
