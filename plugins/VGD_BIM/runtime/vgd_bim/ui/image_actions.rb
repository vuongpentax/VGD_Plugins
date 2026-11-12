require 'json'
require 'fileutils'
require 'rbconfig'
require 'base64'

module VGD
  module BIM
    module UI
      # Phần của cửa sổ BIM lo cho cài đặt chung (ngôn ngữ, thư mục ảnh) và ảnh món đồ: chụp ảnh khi người dùng bấm, nhận ảnh dán /
      # kéo thả, trả ảnh về giao diện khi giao diện không nạp được bằng đường dẫn file. Trộn vào UI::Dialog (dùng @model, @dialog, @table_records... của Dialog).
      # Ảnh chỉ được chụp khi người dùng bấm nút; không có chỗ nào tự chụp.
      module ImageActions
        MAX_CAPTURE_BATCH = 200 # số đối tượng tối đa cho một lần bấm chụp
        MAX_FULL_REQUEST = 6    # số ảnh gốc giao diện được xin mỗi lần (dự phòng; ảnh gốc nặng nên ít hơn trước)
        PREVIEW_WIDTH = 180     # chiều rộng tối đa (điểm ảnh) của ảnh nháp khi xem trước góc chụp

        def register_image_callbacks
          @dialog.add_action_callback('settings_save') { |_ctx, payload| safely { settings_save(JSON.parse(payload)) } }
          @dialog.add_action_callback('settings_pick_dir') { |_ctx| safely { settings_pick_dir } }
          @dialog.add_action_callback('images_open_dir') { |_ctx| safely { images_open_dir } }
          @dialog.add_action_callback('images_capture') { |_ctx, payload| safely { images_capture(JSON.parse(payload)) } }
          @dialog.add_action_callback('images_preview') { |_ctx, payload| safely { images_preview(JSON.parse(payload)) } }
          @dialog.add_action_callback('image_item_save') { |_ctx, payload| safely { image_item_save(JSON.parse(payload)) } }
          @dialog.add_action_callback('images_cancel') { |_ctx| safely { @capture[:cancel] = true if @capture } }
          @dialog.add_action_callback('image_set') { |_ctx, payload| safely { image_set(JSON.parse(payload)) } }
          @dialog.add_action_callback('image_delete') { |_ctx, pid| safely { image_delete(pid) } }
          @dialog.add_action_callback('image_location_delete') { |_ctx, pid| safely { image_delete(pid, :location) } }
          @dialog.add_action_callback('image_full') { |_ctx, payload| safely { image_full(JSON.parse(payload)) } }
        end

        # ---- Cài đặt ----
        def settings_payload
          dir = ModelSettings.image_dir(@model)
          {settings: ModelSettings.effective(@model), dir: dir, dir_exists: File.directory?(dir)}
        end

        def settings_save(payload)
          before = ModelSettings.effective(@model)
          language = before['language']
          Settings.update(payload) # cài đặt chung (cũng là mẫu cho file chưa có riêng)
          own = payload.select { |key, _| ModelSettings::MODEL_KEYS.include?(key) }
          ModelSettings.write(@model, own.keys.to_h { |key| [key, Settings.read[key]] }) unless own.empty? # phần riêng của file này
          measure_changed = %w[exclude_words exclude_tags].any? { |key| ModelSettings.effective(@model)[key] != before[key] }
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
          current = ModelSettings.image_dir(@model)
          path = ::UI.select_directory(title: 'Chọn thư mục lưu ảnh', directory: File.directory?(current) ? current : Dir.home)
          return unless path
          Settings.update('image_dir' => path)
          ModelSettings.write(@model, 'image_dir' => Settings.read['image_dir'])
          emit('settings', settings_payload)
          emit('message', {text: 'Đã đổi thư mục lưu ảnh của file này.'})
        end

        def images_open_dir
          dir = ModelSettings.image_dir(@model)
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
        #          'settings' => thiết lập ảnh của preset đang dùng (cỡ, góc nhìn, kiểu, nền); được kiểm tra lại ở đây,
        #          'kind' => 'full' (ảnh món, mặc định) hoặc 'location' (ảnh vị trí trong công trình),
        #          'iso_side' => bên Iso của nút ◣ ◢ (thắng bên riêng của món),
        #          'force_view' => true khi bấm nút chụp một lần (Khung nhìn hiện tại / Iso): bỏ qua góc nhìn riêng của món,
        #          'item_settings' => thông số nhập trong khung ⚙ (chưa cần lưu), dùng thay cho thông số đã lưu của món}
        # Mỗi món chụp theo thông số riêng đã lưu của nó (PhotoSettings) ghép lên thiết lập của preset; món chưa đặt thì theo preset.
        def images_capture(payload)
          kind, queue = capture_queue(payload)
          start_capture(kind, queue, false)
        end

        # Xem trước góc chụp: cùng payload, cùng hàng đợi và thông số như chụp thật, nhưng chụp ảnh nháp nhỏ gửi từng khung cho giao diện ('image_preview'),
        # không lưu ảnh nào, không đổi model (cũng cô lập rồi hủy như chụp thật). Dùng chung nút Dừng với chụp.
        def images_preview(payload)
          kind, queue = capture_queue(payload)
          start_capture(kind, queue, true)
        end

        # Kiểm tra payload và dựng hàng đợi [dòng, bản ghi, thiết lập riêng của món, bên Iso] (dùng chung cho chụp và xem trước).
        def capture_queue(payload)
          check_model!
          raise 'Đang chụp ảnh. Hãy đợi xong hoặc bấm Dừng.' if @capture
          settings = Preset.settings!(payload.fetch('settings', {}))
          kind = capture_kind!(payload['kind'])
          iso_side = payload['iso_side']
          raise 'Hãy chọn bên Iso là trái hoặc phải.' unless iso_side.nil? || Capture::ISO_SIDES.include?(iso_side)
          inline = payload.key?('item_settings') ? PhotoSettings.sanitize!(payload['item_settings'], kind) : nil
          wanted = payload['indexes'].is_a?(Array) ? table_indexes(payload) : Array(@table_records).each_index.to_a
          jobs = wanted.map { |index| [index, @table_records.fetch(index) { raise 'Bảng đã cũ. Hãy làm mới bảng.' }] }
          jobs.reject! { |index, _| @table_rows[index][kind == :location ? :has_location : :has_image] } if payload['only_missing']
          raise 'Không có đối tượng nào cần chụp.' if jobs.empty?
          raise "Mỗi lần chỉ chụp tối đa #{MAX_CAPTURE_BATCH} đối tượng. Hãy chọn ít hơn." if jobs.size > MAX_CAPTURE_BATCH
          queue = jobs.map do |index, record|
            own, side = PhotoSettings.apply(settings, inline || PhotoSettings.read(record[:entity], kind), kind, force_view: payload['force_view'] == true)
            [index, record, own, iso_side || side || 'right']
          end
          [kind, queue]
        end

        def start_capture(kind, queue, preview)
          @capture = {queue: queue, total: queue.size, done: 0, errors: [], updated: [], cancel: false, notes: [], kind: kind, preview: preview}
          release_preview # khung đánh dấu không được lọt vào ảnh
          hide_overlay
          emit(preview ? 'preview_progress' : 'images_progress', {done: 0, total: queue.size})
          schedule_capture_step
        end

        # Lưu (hoặc bỏ, khi settings rỗng) thông số ảnh riêng của một món. payload: {'index' => dòng, 'kind' => 'full' | 'location', 'settings' => {...}}.
        # Ghi vào dictionary của đối tượng trong một thao tác (một bước hoàn tác); đối tượng bị khóa hoặc dữ liệu sai thì báo lỗi và không ghi.
        def image_item_save(payload)
          check_model!
          kind = capture_kind!(payload['kind'])
          index = table_indexes('indexes' => [payload['index']]).first
          record = @table_records.fetch(index) { raise 'Bảng đã cũ. Hãy làm mới bảng.' }
          raise 'Đối tượng không còn tồn tại. Hãy làm mới bảng.' unless record[:path].all?(&:valid?)
          clean = nil
          Data.transaction(@model, 'VGD_BIM · Thông số ảnh') { clean = PhotoSettings.write(record[:entity], kind, payload.fetch('settings', {})) }
          @table_rows[index][kind == :location ? :photo_location : :photo_full] = clean
          emit('photo_settings', {pid: record[:entity].persistent_id, kind: kind.to_s, settings: clean})
          emit('message', {text: clean.empty? ? 'Đã bỏ thông số ảnh riêng của món này, món theo preset.' : 'Đã lưu thông số ảnh riêng của món này.'})
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
          index, record, settings, iso_side = job[:queue].shift
          preview = job[:preview]
          begin
            result = Capture.shoot(@model, record, settings, iso_side: iso_side, kind: job[:kind], preview: preview ? PREVIEW_WIDTH : nil)
            job[:updated] << result
            job[:notes] << result[:note] if result[:note]
            emit('image_preview', preview_frame(index, record, job[:kind], result)) if preview
          rescue StandardError => error
            BIM.log("Capture failed: #{error.message}")
            reason = capture_error_text(error)
            job[:errors] << "#{capture_label(record)}: #{reason}"
            emit('image_preview', {index: index, pid: record[:entity].persistent_id, kind: job[:kind].to_s, name: capture_label(record), error: reason}) if preview
          end
          job[:done] += 1
          emit(preview ? 'preview_progress' : 'images_progress', {done: job[:done], total: job[:total]})
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
            if job[:preview]
              emit('preview_done', {done: job[:done], total: job[:total], ok: job[:updated].size, errors: job[:errors].first(5), notes: job[:notes].uniq.first(3), cancelled: job[:cancel]})
            else
              emit('images_changed', {items: job[:updated].map { |item| image_change(item[:pid], true, item[:stamp], item[:kind] || :full) }})
              emit('images_done', {done: job[:done], total: job[:total], ok: job[:updated].size, errors: job[:errors].first(5), notes: job[:notes].uniq.first(3), cancelled: job[:cancel]})
            end
            show_outline if @mode == 'table'
          end
        end

        # Một khung xem trước gửi cho giao diện: ảnh nháp dạng data URL (không qua file), kèm tên món để người dùng nhận ra.
        def preview_frame(index, record, kind, result)
          frame = {index: index, pid: result[:pid], kind: kind.to_s, name: capture_label(record), image: "data:image/png;base64,#{Base64.strict_encode64(result[:png])}"}
          result[:note] ? frame.merge(note: result[:note]) : frame
        end

        # 'full' (mặc định, ảnh món) hoặc 'location' (ảnh vị trí); giá trị khác bị từ chối.
        def capture_kind!(value)
          return :full if value.nil? || value == 'full'
          return :location if value == 'location'
          raise 'Loại ảnh không hợp lệ.'
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
          kind = capture_kind!(payload['kind'])
          Images.write(@model, pid, Images.decode_png(payload['full']), kind)
          emit('images_changed', {items: [image_change(pid, true, Images.info(@model, pid, Images.dir(@model), kind)[:stamp], kind)]})
          emit('message', {text: 'Đã lưu ảnh cho đối tượng.'})
        end

        # Một mục của sự kiện images_changed: url là đường dẫn file ảnh gốc (kèm mốc thời gian để làm mới), nil khi không còn ảnh.
        def image_change(pid, has, stamp, kind = :full)
          {pid: pid, kind: kind.to_s, has: has, stamp: stamp, url: has ? Images.file_url(@model, pid, stamp, Images.dir(@model), kind) : nil}
        end

        def image_delete(pid, kind = :full)
          check_model!
          pid = known_pid!(pid)
          Images.delete(@model, pid, kind)
          emit('images_changed', {items: [image_change(pid, false, 0, kind)]})
          emit('message', {text: kind == :location ? 'Đã xóa ảnh vị trí của đối tượng.' : 'Đã xóa ảnh của đối tượng.'})
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
