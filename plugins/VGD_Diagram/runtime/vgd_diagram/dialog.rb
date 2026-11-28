# encoding: UTF-8
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
        callback('ready') { push_tree }
        callback('refresh') { push_tree }
        callback('select') { |json| select_group(JSON.parse(json).fetch('key')) }
        callback('save_orders') { |json| save_orders(JSON.parse(json).fetch('changes')) }
        callback('export') { export_svg }
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

      def push_tree
        model = Sketchup.active_model
        send_js('onTree', 'nodes' => ModelIO.read_tree(model))
        send_js('onScene', Scene.build(model))
      end

      def select_group(key)
        model = Sketchup.active_model
        node = Tree.find(ModelIO.read_tree(model), key)
        raise ArgumentError, 'Không tìm thấy cấu kiện, hãy làm mới sơ đồ.' unless node
        count = ModelIO.select(model, node['ids'])
        send_js('onToast', 'message' => "Đã chọn #{count} bản \"#{node['name']}\" trong model.")
      end

      def save_orders(items)
        model = Sketchup.active_model
        changes = items.to_h { |item| [item.fetch('key'), item.fetch('order')] }
        tree = ModelIO.read_tree(model)
        normalized = Tree.plan(tree, changes)
        busy { ModelIO.apply_orders(model, tree, normalized) }
        push_tree
        send_js('onToast', 'message' => 'Đã lưu thứ tự lắp. Dùng Ctrl+Z để hoàn tác.')
      end

      def export_svg
        path = UI.savepanel('Xuất sơ đồ lắp ráp', '', 'so-do-lap-rap.svg')
        return unless path
        path += '.svg' unless path.downcase.end_with?('.svg')
        busy { File.write(path, Tree.svg(ModelIO.read_tree(Sketchup.active_model)), mode: 'wb') }
        send_js('onToast', 'message' => "Đã xuất sơ đồ: #{path}")
      end

      # Đánh dấu đang ghi model để việc tải lại code không chạy giữa chừng.
      def busy
        @busy = true
        yield
      ensure
        @busy = false
      end
    end
  end
end
