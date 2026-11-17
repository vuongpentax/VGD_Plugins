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
      # Tag của lưới trục lấy theo bộ tag mẫu của VGD BIM (cụm "! INFORMATION", docs/reference/5d_auto_tag/assets/default_tags_summary.json):
      # tên `!grid` (Lưới trục, IfcGrid), màu tím. Kiểu nét của mẫu là liền, nhưng chủ dự án chốt (17/11/2026) ghi đè nét gạch dài - chấm
      # cho đúng thông lệ bản vẽ; chỉ ghi đè khi tag còn nét liền, không đè kiểu nét người dùng đã đặt.
      GRID_TAG = {name: '!grid', color: [186, 0, 204], folder: '! INFORMATION', vi: 'Lưới trục'}.freeze
      GRID_KIND = 'grid'.freeze
    end
  end
end
