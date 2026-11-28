# encoding: UTF-8
require 'base64'
module VGD
  module Diagram
    module Dialog
      extend self

      def visible?
        @dlg && @dlg.visible?
      end

      def busy?
        @busy ? true : false
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
                                  width: 980, height: 680, min_width: 360, min_height: 480,
                                  resizable: true, style: UI::HtmlDialog::STYLE_DIALOG)
        @dlg.set_file(File.join(__dir__.dup.force_encoding(Encoding::UTF_8), 'dialog.html'))
        callback('ready') { refresh_scope && push_tree }
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
        @scope_ids = Sketchup.active_model.selection.to_a.map(&:entityID)
        true
      end

      def scope_entities(model)
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
        busy { ModelIO.apply_orders(model, tree, normalized) }
        push_tree
        send_js('onToast', 'message' => 'Đã lưu thứ tự lắp. Dùng Ctrl+Z để hoàn tác.')
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
      VIDEO_FORMATS = %w[mp4 webm].freeze

      # Đuôi file người dùng gõ trong hộp lưu quyết định định dạng; không gõ thì dùng định dạng đã chọn.
      # Trả về [đường dẫn đã chuẩn hóa, định dạng].
      def resolve_format(path, allowed, fallback)
        ext = File.extname(path).delete('.').downcase
        return ["#{path}.#{fallback}", fallback] if ext.empty?
        raise ArgumentError, "Định dạng .#{ext} không được hỗ trợ. Chọn: #{allowed.join(', ')}." unless allowed.include?(ext)
        [path, ext]
      end

      def start_export(payload)
        model = Sketchup.active_model
        fallback = IMAGE_FORMATS.include?(payload['format']) ? payload['format'] : 'png'
        chosen = UI.savepanel('Lưu ảnh các góc, cụm và bước', '', "#{base_name(model)}.#{fallback}")
        return unless chosen
        path, format = resolve_format(chosen, IMAGE_FORMATS, fallback)
        @export = {
          'folder' => File.dirname(path),
          'base' => File.basename(path, ".#{format}"),
          'format' => format,
          'files' => []
        }
        send_js('onExport', 'format' => format)
      end

      # Video lắp ráp: chọn thư mục, giao diện quay rồi gửi file về đây.
      VIDEO_EXT = %w[mp4 webm].freeze

      def start_video(payload)
        model = Sketchup.active_model
        fallback = VIDEO_FORMATS.include?(payload['format']) ? payload['format'] : 'mp4'
        chosen = UI.savepanel('Lưu video lắp ráp', '', "#{base_name(model)}-lap-rap.#{fallback}")
        return unless chosen
        path, format = resolve_format(chosen, VIDEO_FORMATS, fallback)
        @video = { 'path' => path, 'format' => format }
        send_js('onVideo', 'format' => format)
      end

      def save_video(payload)
        raise 'Chưa chọn nơi lưu video.' unless @video
        raise ArgumentError, 'Trình duyệt quay ra định dạng khác với định dạng đã chọn.' unless payload.fetch('ext') == @video['format']
        data = payload.fetch('data').sub(%r{\Adata:video/[a-z0-9.+;=-]+;base64,}, '')
        busy { File.binwrite(@video['path'], Base64.decode64(data)) }
        path = @video['path']
        @video = nil
        send_js('onToast', 'message' => "Đã xuất video: #{path}")
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
