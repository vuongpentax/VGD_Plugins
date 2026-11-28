# encoding: UTF-8
require 'base64'
require_relative 'ffmpeg'
require_relative 'version'
module VGD
  module Diagram
    module Dialog
      extend self

      def visible?
        @dlg && @dlg.visible?
      end

      def busy?
        @busy || encoding? ? true : false
      end

      # Đang ghép MP4 ở nền (ffmpeg chạy, bộ hẹn giờ hỏi tiến trình).
      def encoding?
        !@encode.nil?
      end

      def close
        @dlg.close if @dlg
        @dlg = nil
      end

      def show
        if visible?
          @dlg.bring_to_front
          return
        end
        @dlg = UI::HtmlDialog.new(dialog_title: 'VGD Diagram', preferences_key: 'VGDDiagram',
                                  width: 980, height: 680, min_width: 720, min_height: 560,
                                  resizable: true, style: UI::HtmlDialog::STYLE_DIALOG)
        @dlg.set_file(File.join(__dir__.dup.force_encoding(Encoding::UTF_8), 'dialog.html'))
        callback('ready') do
          refresh_scope
          push_tree
          push_settings
          send_js('onVersion', 'version' => VERSION)
        end
        callback('refresh') { refresh_scope && push_tree }
        callback('select') { |json| select_group(JSON.parse(json).fetch('key')) }
        callback('save_orders') { |json| save_orders(JSON.parse(json).fetch('changes')) }
        callback('suggest_orders') { suggest_orders }
        callback('export') { export_svg }
        callback('export_views') { |json| start_export(JSON.parse(json || '{}')) }
        callback('save_image') { |json| save_image(JSON.parse(json)) }
        callback('export_done') { finish_export }
        callback('export_video') { |json| start_video(JSON.parse(json || '{}')) }
        callback('save_video') { |json| save_video(JSON.parse(json)) }
        callback('save_frame') { |json| save_frame(JSON.parse(json)) }
        callback('save_ffmpeg') { |json| save_ffmpeg(JSON.parse(json)) }
        callback('pick_ffmpeg') { pick_ffmpeg }
        callback('video_done') { |json| finish_frames(JSON.parse(json)) }
        callback('cancel_encode') { cancel_encode }
        @dlg.show
      end

      def callback(name, &block)
        @dlg.add_action_callback(name) do |_context, payload|
          begin
            block.call(payload)
          rescue StandardError => error
            send_js('onError', 'message' => error.message)
          end
        end
      end

      def send_js(fn, data)
        @dlg.execute_script("VGD.#{fn}(#{JSON.generate(data)})") if @dlg
      end

      # Phạm vi = các đối tượng đang chọn trong model lúc bấm Làm mới.
      # Đổi lựa chọn trong model thì phải bấm Làm mới để cập nhật.
      def refresh_scope
        @scope_model = Sketchup.active_model
        @scope_ids = @scope_model.selection.to_a.map(&:entityID)
        true
      end

      # entityID chỉ có nghĩa trong đúng model lúc bấm Làm mới. Đã đổi sang file SketchUp khác thì phạm vi cũ bị bỏ
      # (không tìm theo số trong model mới, vì có thể trùng số với đối tượng khác).
      def scope_entities(model)
        return [] unless @scope_model.equal?(model)
        (@scope_ids || []).map { |id| model.find_entity_by_id(id) }.compact
      end

      def scope_tree(model)
        ModelIO.read_entities(scope_entities(model))
      end

      def push_tree
        model = Sketchup.active_model
        entities = scope_entities(model)
        scene = Scene.build_from(entities)
        tree = numbered_tree(model, entities, scene)
        send_js('onTree', 'nodes' => tree, 'message' => scope_message(entities, tree))
        send_js('onScene', scene)
      end

      def scope_message(entities, tree)
        return 'Hãy chọn đối tượng trong model rồi bấm Làm mới.' if entities.empty?
        return 'Vùng chọn không có nhóm hoặc component nào.' if tree.empty?
        nil
      end

      # Cây có số nhãn cho các nhóm có hình học; khớp với số hiện trên mô hình 3D.
      def numbered_tree(model, entities = scope_entities(model), scene = Scene.build_from(entities))
        ids = scene['parts'].map { |part| part['id'] }.compact
        Tree.number(ModelIO.read_entities(entities), ids)
      end

      def suggest_orders
        model = Sketchup.active_model
        tree = scope_tree(model)
        suggested = Tree.suggest(tree, ModelIO.node_positions(model, tree))
        send_js('onSuggested', 'changes' => suggested.map { |key, order| { 'key' => key, 'order' => order } })
      end

      def base_name(model)
        model.path.to_s.empty? ? 'so-do' : File.basename(model.path, '.skp')
      end

      def select_group(key)
        model = Sketchup.active_model
        node = Tree.find(scope_tree(model), key)
        raise ArgumentError, 'Không tìm thấy cấu kiện, hãy làm mới sơ đồ.' unless node
        count = ModelIO.select(model, node['ids'])
        send_js('onToast', 'message' => "Đã chọn #{count} bản \"#{node['name']}\" trong model.")
      end

      def save_orders(items)
        model = Sketchup.active_model
        changes = items.to_h { |item| [item.fetch('key'), item.fetch('order')] }
        tree = scope_tree(model)
        normalized = Tree.plan(tree, changes)
        result = busy { ModelIO.apply_orders(model, tree, normalized) }
        push_tree
        send_js('onToast', 'message' => save_message(result))
      end

      def save_message(result)
        return 'Đã lưu thứ tự lắp. Dùng Ctrl+Z để hoàn tác.' if result[:skipped].zero?
        "Đã lưu thứ tự lắp. Bỏ qua #{result[:skipped]} đối tượng bị khóa (mở khóa rồi lưu lại). Dùng Ctrl+Z để hoàn tác."
      end

      def export_svg
        path = UI.savepanel('Xuất sơ đồ lắp ráp', '', 'so-do-lap-rap.svg')
        return unless path
        path += '.svg' unless path.downcase.end_with?('.svg')
        busy { File.write(path, Tree.svg(scope_tree(Sketchup.active_model)), mode: 'wb') }
        send_js('onToast', 'message' => "Đã xuất sơ đồ: #{path}")
      end

      # Xuất ảnh các góc: giao diện vẽ bằng three.js (style mặc định SketchUp giả lập), rồi gửi từng ảnh về đây ghi ra file.
      IMAGE_FORMATS = %w[png jpg].freeze
      VIDEO_FORMATS = %w[webm png].freeze

      # Đuôi file người dùng gõ trong hộp lưu quyết định định dạng; không gõ thì dùng định dạng đã chọn.
      # Trả về [đường dẫn đã chuẩn hóa, định dạng].
      def resolve_format(path, allowed, fallback)
        ext = File.extname(path).delete('.').downcase
        return ["#{path}.#{fallback}", fallback] if ext.empty?
        raise ArgumentError, "Định dạng .#{ext} không được hỗ trợ. Chọn: #{allowed.join(', ')}." unless allowed.include?(ext)
        [path, ext]
      end

      ENCODING_MESSAGE = 'Đang ghép MP4. Hãy chờ xong hoặc bấm Hủy.'.freeze

      def ensure_not_encoding!
        raise ENCODING_MESSAGE if encoding?
      end

      def start_export(payload)
        ensure_not_encoding!
        model = Sketchup.active_model
        fallback = IMAGE_FORMATS.include?(payload['format']) ? payload['format'] : 'png'
        chosen = UI.savepanel('Lưu ảnh các góc, cụm và bước', '', "#{base_name(model)}.#{fallback}")
        return unless chosen
        path, format = resolve_format(chosen, IMAGE_FORMATS, fallback)
        @export = {
          'folder' => File.dirname(path),
          'base' => File.basename(path, File.extname(path)),
          'format' => format,
          'files' => []
        }
        send_js('onExport', 'format' => format)
      end

      ENCODE_INTERVAL = 0.3 # giây giữa hai lần hỏi tiến trình ghép MP4

      # Video lắp ráp: chọn thư mục, giao diện quay rồi gửi file về đây.
      VIDEO_EXT = %w[webm].freeze

      def start_video(payload)
        ensure_not_encoding!
        model = Sketchup.active_model
        fallback = VIDEO_FORMATS.include?(payload['format']) ? payload['format'] : 'webm'
        chosen = UI.savepanel('Lưu video lắp ráp', '', "#{base_name(model)}-lap-rap.#{fallback}")
        return unless chosen
        path, format = resolve_format(chosen, VIDEO_FORMATS, fallback)
        if format == 'png'
          # Chuỗi khung hình: mỗi khung là một file PNG đánh số, ghi trong thư mục đã chọn.
          @video = { 'frames' => true, 'folder' => File.dirname(path), 'base' => File.basename(path, File.extname(path)), 'count' => 0, 'files' => [] }
          send_js('onVideo', 'format' => 'png')
          return
        end
        @video = { 'path' => path, 'format' => format }
        send_js('onVideo', 'format' => format)
      end

      def save_frame(payload)
        raise 'Chưa chọn nơi lưu khung hình.' unless @video && @video['frames']
        index = Integer(payload.fetch('index'))
        path = File.join(@video['folder'], "%s-khung-%05d.png" % [@video['base'], index])
        data = payload.fetch('data').sub(%r{\Adata:image/png;base64,}, '')
        busy { File.binwrite(path, Base64.decode64(data)) }
        @video['count'] += 1
        @video['files'] << path
      end

      # Video WebM quay trong giao diện: ghi file vào đường dẫn người dùng đã chọn khi bắt đầu xuất.
      def save_video(payload)
        raise 'Chưa chọn nơi lưu video.' unless @video && @video['path']
        ext = payload.fetch('ext')
        raise ArgumentError, "Định dạng video không khớp: #{ext}" unless VIDEO_EXT.include?(ext) && ext == @video['format']
        path = @video['path']
        data = payload.fetch('data').sub(%r{\Adata:video/[a-z0-9.+-]+;base64,}, '')
        busy { File.binwrite(path, Base64.decode64(data)) }
        @video = nil
        send_js('onToast', 'message' => "Đã lưu video: #{path}")
      end

      # Cài đặt ffmpeg: đường dẫn nhập tay hoặc chọn bằng hộp thoại, được nhớ cho lần sau.
      def push_settings
        send_js('onSettings', 'ffmpegPath' => Ffmpeg.saved_path.to_s)
      end

      def save_ffmpeg(payload)
        saved = Ffmpeg.save_path(payload.fetch('path'))
        push_settings
        send_js('onToast', 'message' => saved ? "Đã lưu ffmpeg: #{saved}" : 'Đã xóa đường dẫn ffmpeg đã lưu.')
      end

      def pick_ffmpeg
        chosen = Ffmpeg.choose
        push_settings
        send_js('onToast', 'message' => "Đã lưu ffmpeg: #{chosen}") if chosen
      end

      # Sau khi xuất xong chuỗi khung hình: nếu có ffmpeg thì hỏi ghép MP4, rồi hỏi xóa ảnh.
      # Ảnh chỉ bị xóa khi người dùng đồng ý và ghép MP4 đã thành công.
      def finish_frames(payload)
        video = @video
        @video = nil
        return unless video && video['frames']
        fps = payload.fetch('fps')
        frames = video['files']
        pattern = Ffmpeg.frame_pattern(video['folder'], video['base'])
        output = File.join(video['folder'], "#{video['base']}.mp4")
        exe = Ffmpeg.executable || offer_ffmpeg
        unless exe
          send_js('onToast', 'message' => "Đã xuất #{frames.size} khung hình vào #{video['folder']}. " \
            "Chưa có ffmpeg nên chưa ghép MP4. Xem hướng dẫn trong README.")
          return
        end
        if File.exist?(output) && UI.messagebox("File #{File.basename(output)} đã có. Ghi đè?", MB_YESNO) != IDYES
          send_js('onToast', 'message' => "Giữ nguyên #{File.basename(output)}. Ảnh khung hình vẫn ở #{video['folder']}.")
          return
        end
        begin
          job = Ffmpeg.start_encode(exe, pattern, fps, output, frames.size)
        rescue ArgumentError, SystemCallError => error
          send_js('onError', 'message' => "Ghép MP4 thất bại, ảnh khung hình được giữ lại. #{error.message}")
          return
        end
        @encode = { 'job' => job, 'output' => output, 'frames' => frames }
        send_js('onEncode', 'state' => 'running', 'percent' => 0, 'name' => File.basename(output))
        @encode_timer = UI.start_timer(ENCODE_INTERVAL, true) { poll_encode }
      end

      # Bộ hẹn giờ gọi hàm này mỗi ENCODE_INTERVAL giây khi đang ghép: báo phần trăm, hoặc xử lý kết quả khi ffmpeg xong.
      # Đóng hộp thoại giữa chừng thì dừng ghép (không để ffmpeg chạy mồ côi). Lỗi bất ngờ cũng dừng, để bộ hẹn giờ
      # không báo lỗi lặp lại mỗi lần.
      def poll_encode
        encode = @encode
        return unless encode
        unless visible?
          cancel_encode('Đã đóng hộp thoại nên dừng ghép MP4. Ảnh khung hình được giữ lại.')
          return
        end
        result = Ffmpeg.poll(encode['job'])
        if result[:state] == :running
          total = encode['job'].total
          percent = total.positive? ? [result[:frame] * 100 / total, 99].min : 0
          send_js('onEncode', 'state' => 'running', 'percent' => percent, 'name' => File.basename(encode['output']))
        else
          finish_encode(encode, result)
        end
      rescue StandardError => error
        cancel_encode("Ghép MP4 gặp lỗi: #{error.message}. Ảnh khung hình được giữ lại.", error: true)
      end

      def finish_encode(encode, result)
        clear_encode
        unless result[:ok]
          send_js('onEncode', 'state' => 'error', 'percent' => 0)
          send_js('onError', 'message' => "Ghép MP4 thất bại, ảnh khung hình được giữ lại. #{result[:error]}")
          return
        end
        send_js('onEncode', 'state' => 'done', 'percent' => 100, 'name' => File.basename(encode['output']))
        name = File.basename(encode['output'])
        frames = encode['frames']
        if UI.messagebox("Đã tạo #{name}.\nXóa #{frames.size} ảnh khung hình đã xuất?", MB_YESNO) == IDYES
          removed = busy { Ffmpeg.delete_frames(frames) }
          send_js('onToast', 'message' => "Đã tạo #{name} và xóa #{removed} ảnh khung hình.")
        else
          send_js('onToast', 'message' => "Đã tạo #{name}. Giữ lại #{frames.size} ảnh khung hình.")
        end
      end

      # Hủy ghép (nút Hủy, hoặc đóng hộp thoại): dừng ffmpeg, xóa MP4 dở, giữ ảnh khung hình.
      def cancel_encode(message = nil, error: false)
        encode = @encode
        return unless encode
        clear_encode
        Ffmpeg.cancel(encode['job'])
        send_js('onEncode', 'state' => 'cancelled', 'percent' => 0)
        send_js(error ? 'onError' : 'onToast', 'message' => message || 'Đã hủy ghép MP4. Ảnh khung hình được giữ lại.')
      end

      def clear_encode
        UI.stop_timer(@encode_timer) if @encode_timer
        @encode_timer = nil
        @encode = nil
      end

      # Chưa có ffmpeg: hỏi người dùng chọn file. Trả về đường dẫn hoặc nil.
      def offer_ffmpeg
        return nil unless UI.messagebox('Chưa tìm thấy ffmpeg. Chọn file ffmpeg để tự ghép MP4?', MB_YESNO) == IDYES
        Ffmpeg.choose
      end

      # Tên ảnh chỉ gồm chữ thường, số và dấu gạch ngang (ví dụ truoc, cum-01, buoc-02).
      IMAGE_KEY = /\A[a-z]+(-\d+)?\z/

      def save_image(payload)
        raise 'Chưa chọn nơi lưu ảnh.' unless @export
        key = payload.fetch('key')
        raise ArgumentError, "Tên ảnh không hợp lệ: #{key}" unless IMAGE_KEY.match?(key)
        ext = @export['format']
        path = File.join(@export['folder'], "#{@export['base']}-#{key}.#{ext}")
        data = payload.fetch('data').sub(%r{\Adata:image/[a-z]+;base64,}, '')
        busy { File.binwrite(path, Base64.decode64(data)) }
        @export['files'] << path
      end

      def finish_export
        export = @export
        @export = nil
        return unless export
        csv_path = File.join(export['folder'], "#{export['base']}-danh-sach.csv")
        busy { File.write(csv_path, Tree.csv(numbered_tree(Sketchup.active_model)), mode: 'wb') }
        send_js('onToast', 'message' => "Đã xuất #{export['files'].size} ảnh và danh sách vào #{export['folder']}.")
      end

      # Đánh dấu đang ghi model hoặc file để việc tải lại code không chạy giữa chừng.
      def busy
        @busy = true
        yield
      ensure
        @busy = false
      end
    end
  end
end
