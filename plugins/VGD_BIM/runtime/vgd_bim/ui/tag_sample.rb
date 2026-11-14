module VGD
  module BIM
    module UI
      # Công cụ lấy mẫu tag (kiểu ống hút): bấm vào một đối tượng trong view để lấy tag của nó, rồi tự thoát về công cụ Select.
      # Không đổi gì trong model. Đối tượng được lấy là đối tượng ở cấp đang mở (như khung đánh dấu): không chọn sâu vào bên trong group.
      # Esc hủy. SketchUp không có lớp gốc Sketchup::Tool; chỉ cần object có các hàm activate / deactivate / onLButtonDown / onCancel.
      class TagSampleTool
        STATUS = 'VGD_BIM · Bấm vào đối tượng để lấy tag của nó (Esc để hủy).'.freeze

        # on_pick: gọi với tên tag (chuỗi rỗng nếu đối tượng chưa có tag hay không bấm trúng gì) rồi công cụ tự thoát; on_done: gọi khi công cụ bị gỡ.
        def initialize(on_pick, on_done = nil)
          @on_pick = on_pick
          @on_done = on_done
          @finished = false
        end

        def activate
          Sketchup.status_text = STATUS if Sketchup.respond_to?(:status_text=)
        end

        def deactivate(view)
          Sketchup.status_text = '' if Sketchup.respond_to?(:status_text=)
          return if @finished
          @finished = true
          @on_done.call if @on_done
        end

        def onLButtonDown(_flags, x, y, view)
          return if @finished
          @on_pick.call(tag_name_at(view, x, y))
          finish(view)
        rescue StandardError => error
          BIM.log("Lấy mẫu tag lỗi: #{error.message}")
          finish(view)
        end

        def onCancel(_reason, view)
          finish(view)
        end

        private

        def tag_name_at(view, x, y)
          depth = (view.model.active_path || []).size
          helper = view.pick_helper
          helper.do_pick(x, y)
          (0...helper.count).each do |i|
            path = helper.path_at(i)
            next if path.nil? || path.size <= depth
            entity = path[depth]
            return entity.respond_to?(:layer) && entity.layer ? entity.layer.name.to_s : ''
          end
          ''
        end

        def finish(view)
          return if @finished
          @finished = true
          @on_done.call if @on_done
          view.model.select_tool(nil)
        rescue StandardError => error
          BIM.log("Thoát công cụ lấy mẫu lỗi: #{error.message}")
        end
      end
    end
  end
end
