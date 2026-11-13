# Tủ quá khổ: tủ cao hơn ngưỡng thì tách thành tủ dưới và tủ trên, ghép bằng một trong ba kiểu liên kết.
# Chỉ tính toán, không gọi SketchUp nên kiểm thử được bằng Ruby thường.
module VGD_Cabinet_Draw
  module Split
    extend self

    GROUP_NAME = 'Tủ quá khổ'.freeze
    # Tủ tùy biến, tủ bếp dưới và thùng tủ lạnh được tách. Tủ bếp trên giữ nguyên.
    SPLIT_TYPES = %w[standard base fridge].freeze
    JOINTS = %w[dau_dinh xa_duoi xa_tren].freeze
    JOINT_NAMES = { 'dau_dinh' => 'Đấu đình', 'xa_duoi' => 'Xà dưới', 'xa_tren' => 'Xà trên' }.freeze
    MAX_CABINET_HEIGHT = 2440.0 # khổ ván: mỗi tủ không cao quá 2440 mm

    # name: 'lower' hoặc 'upper'; height: chiều cao tủ (mm); overrides: thông số ghi đè riêng cho tủ đó.
    Piece = Struct.new(:name, :height, :overrides)

    # Trả về nil nếu không tách. Ngược lại trả về [tủ dưới, tủ trên]. Ném ArgumentError nếu không tách được.
    def plan(total, settings)
      return nil unless SPLIT_TYPES.include?(settings['cabinet_type'].to_s)
      threshold = PanelModel.number(settings['split_height'], 2400.0, 'Ngưỡng tách tủ', 1000.0, 4000.0)
      # Quá khổ ván thì luôn tách, kể cả khi ngưỡng cài cao hơn.
      return nil unless total > [threshold, MAX_CABINET_HEIGHT].min
      joint = settings['split_joint'].to_s
      raise ArgumentError, "Liên kết khi tách không hợp lệ: #{joint}." unless JOINTS.include?(joint)
      lower = PanelModel.number(settings['split_lower_height'], 2100.0, 'Cao tủ dưới khi tách', 300.0, MAX_CABINET_HEIGHT)
      raise ArgumentError, format('Cao tủ dưới %.0f mm phải nhỏ hơn cao tổng %.0f mm.', lower, total) if lower >= total
      upper = total - lower
      if upper > MAX_CABINET_HEIGHT
        raise ArgumentError, format('Tủ quá khổ: cao %.0f mm, tủ trên %.0f mm vượt khổ ván %.0f mm. Hãy tăng cao tủ dưới hoặc giảm cao tổng.', total, upper, MAX_CABINET_HEIGHT)
      end
      [Piece.new('lower', lower, lower_overrides(joint)), Piece.new('upper', upper, upper_overrides(joint, settings['cabinet_type'].to_s))]
    end

    # Tủ dưới: có nóc nguyên tấm (đấu đình, xà trên) hoặc thay nóc bằng xà (xà dưới). Không có phào trần.
    def lower_overrides(joint)
      { 'top_mode' => joint == 'xa_duoi' ? 'rails' : 'full', 'ceiling_strip_height' => 0.0, 'sides_to_ceiling' => false }
    end

    # Tủ trên: có đáy nguyên tấm (đấu đình, xà dưới) hoặc thay đáy bằng xà (xà trên). Không có chân, không chạm sàn.
    # Thùng tủ lạnh: phần tủ lạnh nằm ở tủ dưới, tủ trên thành tủ tùy biến (không còn tủ lạnh).
    def upper_overrides(joint, type)
      out = { 'bottom_mode' => joint == 'xa_tren' ? 'rails' : 'full', 'leg_height' => 0.0, 'sides_to_floor' => false, 'toe_kick_enabled' => false }
      out['cabinet_type'] = 'standard' if type == 'fridge'
      out
    end
  end
end
