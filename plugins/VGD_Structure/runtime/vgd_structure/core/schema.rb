module VGD
  module Structure
    # Hợp đồng dữ liệu của plugin (đặc tả: docs/vgd_structure/SPEC.md). Chỉ là hằng số, chưa có logic.
    module Schema
      PLUGIN_ID = 'vgd_structure'.freeze
      # Dictionary giữ dữ liệu nguồn của plugin trong model (JSON) và dữ liệu riêng trên từng khối dựng ra.
      DICTIONARY = 'VGD_STRUCT'.freeze
      # Loại đối tượng ghi vào VGD_BIM_SOURCE.kind. VGD_BIM đọc khóa này để gợi ý hạng mục.
      KINDS = %w[column beam wall slab ceiling door window].freeze
      # Tag riêng cho từng loại, THEO BỘ TAG MẪU của VGD BIM (cụm trong config/tag_catalog.json, màu trong
      # docs/reference/5d_auto_tag/assets/default_tags_summary.json); chỉ tạo tag khi chưa có, tag đã có giữ màu và thư mục của người dùng.
      TAGS = {
        'column' => {name: 'S. COLUMN', color: [102, 221, 0], folder: 'S. STRUCTURAL', vi: 'Cột'},
        'beam' => {name: 'S. BEAM', color: [0, 170, 186], folder: 'S. STRUCTURAL', vi: 'Dầm'},
        'wall' => {name: 'A. WALL', color: [255, 153, 102], folder: 'A. ARCHITECTURAL', vi: 'Tường'},
        'slab' => {name: 'S. SLAB', color: [186, 51, 0], folder: 'S. STRUCTURAL', vi: 'Bản sàn'},
        'ceiling' => {name: 'A. FINISHING CEILING', color: [153, 0, 255], folder: 'A. ARCHITECTURAL', vi: 'Trần hoàn thiện'},
        'door' => {name: 'A. DOOR', color: [255, 119, 102], folder: 'A. ARCHITECTURAL', vi: 'Cửa đi'},
        'window' => {name: 'A. WINDOW', color: [204, 186, 237], folder: 'A. ARCHITECTURAL', vi: 'Cửa sổ'}
      }.freeze
      # Tag của lưới trục lấy theo bộ tag mẫu của VGD BIM (cụm "! INFORMATION", docs/reference/5d_auto_tag/assets/default_tags_summary.json):
      # tên `!grid` (Lưới trục, IfcGrid), màu tím. Kiểu nét của mẫu là liền, nhưng chủ dự án chốt (17/11/2026) ghi đè nét gạch dài - chấm
      # cho đúng thông lệ bản vẽ; chỉ ghi đè khi tag còn nét liền, không đè kiểu nét người dùng đã đặt.
      GRID_TAG = {name: '!grid', color: [186, 0, 204], folder: '! INFORMATION', vi: 'Lưới trục'}.freeze
      GRID_KIND = 'grid'.freeze
    end
  end
end
