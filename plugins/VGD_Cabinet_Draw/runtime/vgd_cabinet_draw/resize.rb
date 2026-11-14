module VGD_Cabinet_Draw
  # Đổi kích thước tủ theo MỘT trục, giữ yên mặt có điểm neo (dùng cho lệnh Scale VGD, xem Tools::ScaleTool).
  # Đặt phép scale lên tủ rồi co giãn tại chỗ bằng đúng cơ chế như khi kéo Scale (Rebuild.stretch): ván giữ độ dày, dải 100 mm sát
  # mép mỗi tấm giữ nguyên (mộng, dấu tiết diện), cánh và ngăn kéo đi theo hông và hồi giữa. Một bước Undo; lỗi thì hủy cả thao tác.
  module Resize
    extend self

    OPERATION_NAME = 'VGD Cabinet Draw — Scale VGD'.freeze
    MIN_MM = 50.0     # nhỏ hơn thì không còn dựng được thùng tủ và các tấm
    MAX_MM = 10_000.0 # chặn gõ nhầm thừa số 0
    AXIS_NAMES = %w[Rộng Sâu Cao].freeze

    # Chuỗi nhập (mm, có thể kèm "mm") → số. Báo ArgumentError nếu không phải số hoặc ngoài khoảng cho phép.
    def parse_size(text)
      value = Float(text.to_s.strip.sub(/\s*mm\z/i, '').tr(',', '.'))
      check_size!(value)
      value
    rescue ArgumentError, TypeError => e
      raise ArgumentError, 'Kích thước phải là số mm, ví dụ 1200.' unless e.message.include?('từ')
      raise
    end

    def check_size!(value)
      raise ArgumentError, "Kích thước phải từ #{MIN_MM.to_i} đến #{MAX_MM.to_i} mm." unless value >= MIN_MM && value <= MAX_MM
    end

    # Đổi kích thước theo trục axis (0 rộng, 1 sâu, 2 cao) thành new_mm, giữ yên mặt side (:min hoặc :max) của trục đó.
    # Trả về true nếu đã đổi. Lỗi co giãn: hủy thao tác, báo bằng hộp thoại và trả về false.
    def apply_axis(root, axis, new_mm, side)
      check_size!(new_mm)
      raise ArgumentError, 'Tủ đang bị Scale chưa cập nhật. Hãy đợi tự cập nhật hoặc Undo rồi thử lại.' if Rebuild.scale_of(root)
      dims = Rebuild.dimensions_of(root)
      return false if (dims[axis] - new_mm).abs < 0.01
      factors = [1.0, 1.0, 1.0]
      factors[axis] = new_mm / dims[axis]
      anchor = [0.0, 0.0, 0.0]
      anchor[axis] = dims[axis].mm if side == :max
      model = Sketchup.active_model
      model.start_operation(OPERATION_NAME, true)
      begin
        root.transformation = root.transformation * Geom::Transformation.translation(anchor) *
                              Geom::Transformation.scaling(*factors) * Geom::Transformation.translation(anchor.map(&:-@))
        warnings = Rebuild.stretch(root)
      rescue StandardError => e
        model.abort_operation
        UI.messagebox("Không đổi được kích thước tủ, tủ giữ nguyên: #{e.message}")
        return false
      end
      model.commit_operation
      UI.messagebox("Scale VGD:\n• #{warnings.uniq.join("\n• ")}") unless warnings.empty?
      true
    end
  end
end
