module VGD_Cabinet_Draw
  # Nút Scale VGD: nhập Rộng / Sâu / Cao (mm) của tủ rồi áp dụng bằng đúng cơ chế co giãn tại chỗ như khi kéo Scale
  # (Rebuild.stretch): đặt phép scale lên tủ rồi co giãn các tấm, cánh, ngăn kéo về kích thước thật. Một bước Undo.
  # Lỗi (ví dụ không co giãn được) thì hủy cả thao tác, tủ giữ nguyên. Scale quanh gốc của tủ: tủ nở ra phải, ra sau và lên trên.
  module Resize
    extend self

    OPERATION_NAME = 'VGD Cabinet Draw — Scale VGD'.freeze
    MIN_MM = 50.0     # nhỏ hơn thì không còn dựng được thùng tủ và các tấm
    MAX_MM = 10_000.0 # chặn gõ nhầm thừa số 0
    LABELS = ['Rộng (mm)', 'Sâu (mm)', 'Cao (mm)'].freeze

    def run
      roots = ModelData.cabinets_in(Sketchup.active_model.selection.to_a.select(&:valid?))
      return UI.messagebox('Hãy chọn một tủ VGD rồi bấm Scale VGD.') if roots.empty?
      return UI.messagebox('Hãy chọn đúng một tủ để Scale VGD.') if roots.length > 1
      root = roots.first
      answer = UI.inputbox(LABELS, Rebuild.dimensions_of(root).map { |value| value.round(1).to_s }, 'Scale VGD — kích thước tủ')
      return unless answer
      apply(root, parse(answer))
    rescue ArgumentError => e
      UI.messagebox(e.message)
    end

    # Chuỗi nhập → [rộng, sâu, cao] mm. Báo lỗi nếu không phải số hoặc ngoài khoảng cho phép.
    def parse(answer)
      values = answer.map do |text|
        Float(text.to_s.strip.tr(',', '.'))
      rescue ArgumentError, TypeError
        raise ArgumentError, 'Rộng, Sâu, Cao phải là số mm, ví dụ 800.'
      end
      raise ArgumentError, "Mỗi kích thước phải từ #{MIN_MM.to_i} đến #{MAX_MM.to_i} mm." unless values.all? { |value| value >= MIN_MM && value <= MAX_MM }
      values
    end

    # Co giãn tủ về kích thước mới (mm). Trả về true nếu đã đổi.
    def apply(root, dims)
      old = Rebuild.dimensions_of(root)
      if old.zip(dims).all? { |before, after| (before - after).abs < 0.01 }
        Dialog.set_status('Kích thước không đổi.')
        return false
      end
      model = Sketchup.active_model
      model.start_operation(OPERATION_NAME, true)
      begin
        root.transformation = root.transformation * Geom::Transformation.scaling(*dims.zip(old).map { |after, before| after / before })
        warnings = Rebuild.stretch(root)
      rescue StandardError => e
        model.abort_operation
        UI.messagebox("Không đổi được kích thước tủ, tủ giữ nguyên: #{e.message}")
        return false
      end
      model.commit_operation
      UI.messagebox("Scale VGD:\n• #{warnings.uniq.join("\n• ")}") unless warnings.empty?
      Dialog.set_status("Đã đổi tủ thành #{dims.map { |value| value.round(1) }.join(' x ')} mm.")
      true
    end
  end
end
