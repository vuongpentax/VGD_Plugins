module VGD
  module Structure
    # Hợp đồng dữ liệu của plugin (đặc tả: docs/vgd_structure/SPEC.md). Chỉ là hằng số, chưa có logic.
    module Schema
      PLUGIN_ID = 'vgd_structure'.freeze
      # Dictionary giữ dữ liệu nguồn của plugin trong model (JSON) và dữ liệu riêng trên từng khối dựng ra.
      DICTIONARY = 'VGD_STRUCT'.freeze
      # Loại đối tượng ghi vào VGD_BIM_SOURCE.kind. VGD_BIM đọc khóa này để gợi ý hạng mục.
      KINDS = %w[column beam wall slab ceiling].freeze
      # Tag riêng cho từng loại (tên hiển thị trong SketchUp).
      TAGS = {'column' => 'Cột', 'beam' => 'Dầm', 'wall' => 'Tường', 'slab' => 'Sàn', 'ceiling' => 'Trần'}.freeze
    end
  end
end
