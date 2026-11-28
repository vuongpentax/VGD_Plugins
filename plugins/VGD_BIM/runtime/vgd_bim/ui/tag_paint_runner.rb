module VGD
  module BIM
    module UI
      # Chạy công cụ hút / đổ tag từ lệnh menu "Hút / đổ tag" (đặt phím tắt được trong Window > Preferences > Shortcuts) khi cửa sổ
      # Soạn tag đang đóng: dùng lại đúng phần hút / đổ của TagManager (đổ, hút, tạo tag, Color by Tag, một bước hoàn tác mỗi lần bấm),
      # chỉ không có cửa sổ để gửi tin. Cửa sổ Soạn tag đang mở thì lệnh menu đi qua cửa sổ (VGD::BIM.toggle_tag_paint).
      class TagPaintRunner
        include TagManager

        def initialize
          @kind = :tags # ghi xong báo VGD::BIM.model_edited để Bảng khối lượng đang mở đọc lại (như cửa sổ Soạn tag)
        end

        # Bấm lệnh: đang chạy thì thoát, chưa chạy thì bật với tag name ('' = bắt đầu ở chế độ hút).
        def toggle(name)
          @model = Sketchup.active_model
          safely { tm_paint_start('name' => name) }
        end

        def stop
          tm_paint_shutdown
        end

        def active?
          paint_active?
        end

        private

        def check_model!; end
        def emit(_event, _payload); end # không có cửa sổ
        def tag_tree_state; nil; end    # chỉ cửa sổ cần cây tag
        def model_edited; BIM.model_edited; end

        def safely
          yield
        rescue StandardError => error
          BIM.log("Hút / đổ tag (phím tắt) lỗi: #{error.message}")
        end
      end
    end
  end
end
