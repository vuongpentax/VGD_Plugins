module VGD_Cabinet_Draw
  module Schema
    extend self

    DICTIONARY = 'VGD_Cabinet_Draw'.freeze
    # Phiên bản cấu trúc dữ liệu gắn vào đối tượng trong model. Bản 1 vẫn đọc được.
    MODEL_SCHEMA = 2
    # Phiên bản file preset. Bản 1 được nâng lên 2 khi ghi, có sao lưu.
    PRESET_SCHEMA = 2
    PART_ROLES = %w[side_left side_right top bottom back toe_kick toe_kick_back cornice board shelf partition door drawer_front drawer_box drawer_side drawer_bottom drawer_box_front drawer_box_back blocker wardrobe_bottom wardrobe_top wardrobe_side bay_bottom bay_top bay_side rail handle opening].freeze
    TOOLS = {
      'box' => 'Box → Board', 'panel' => 'Đợt / vách', 'door' => 'Chia cánh',
      'opening' => 'Hướng mở', 'handle' => 'Tay nắm', 'drawer' => 'Hộc kéo',
      'wardrobe' => 'Hộc tủ áo', 'bay' => 'Khoang ngăn kéo', 'blocker' => 'Xà chặn', 'cut' => 'Cắt ván',
      'round' => 'Bo góc', 'notch' => 'Khấu ván'
    }.freeze
    # Công cụ nào dùng kho setting nào. Hướng mở cánh dùng chung kho với Cánh.
    TOOL_GROUP = { 'box' => 'box', 'panel' => 'panel', 'door' => 'door', 'opening' => 'door', 'drawer' => 'drawer', 'bay' => 'bay' }.freeze
    DEFAULTS = {
      'board_thickness' => 17.5, 'back_thickness' => 6.0,
      'back_mode' => 'groove', 'back_groove_depth' => 8.75, 'back_lip' => 10.0,
      'panels' => PanelModel.default_panels,
      'sync_front' => true,
      'ceiling_strip_height' => 20.0, 'door_gap' => 0.0, 'door_fit' => 'phu', 'door_edge_gap' => 0.0, 'door_inset_gap' => 2.0, 'door_cover_left' => true, 'door_cover_right' => true, 'door_show_dims' => true,
      'leg_height' => 40.0, 'sides_to_floor' => false, 'sides_to_ceiling' => false,
      'board_face_thickness' => nil, 'board_face_side' => 'normal', 'toe_kick_enabled' => true, 'toe_kick_back' => true, 'toe_kick_thickness' => nil, 'toe_kick_setback' => 50.0,
      'cornice_enabled' => true, 'cornice_thickness' => nil, 'cornice_setback' => 0.0,
      'drawer_gap' => 0.0, 'drawer_tier_gap' => 25.0, 'drawer_mode' => 'full', 'drawer_show_dims' => false,
      'drawer_count' => 2, 'drawer_front_height' => 0.0, 'drawer_fit' => 'auto', 'drawer_slide' => 'side', 'drawer_depth' => 0.0,
      'drawer_box_thickness' => nil, 'drawer_bottom_thickness' => 8.0, 'drawer_back_clearance' => 10.0, 'drawer_ray_space' => 13.0,
      'drawer_box_bottom_lift' => 10.0, 'drawer_box_top_clearance' => 13.0,
      'bay_setback' => 20.0, 'bay_side_gap' => 35.0, 'bay_height' => 0.0,
      'drawer_bottom_type' => 'under', 'drawer_groove_depth' => 8.0, 'drawer_groove_height' => 10.0,
      'handle_profile' => 'bar', 'handle_position' => 'auto', 'handle_width' => 128.0, 'handle_edge_offset' => 50.0, 'handle_projection' => 30.0,
      'split_axis' => 'vertical', 'panel_axis' => 'horizontal', 'panel_kind' => 'thong_thuy',
      'shelf_edge_clearance' => 1.6, 'front_offset' => 0.0,
      'cabinet_type' => 'standard', 'top_mode' => 'auto', 'top_rail_width' => 100.0, 'hang_rail' => true, 'hang_rail_height' => 100.0,
      'bottom_mode' => 'full', 'rail_front_orient' => 'flat', 'rail_back_orient' => 'upright', 'rail_back_width' => 100.0, 'rail_front_double' => false,
      'split_height' => 2400.0, 'split_lower_height' => 2100.0, 'split_joint' => 'dau_dinh',
      'fridge_width' => 700.0, 'fridge_height' => 1800.0, 'fridge_depth' => 650.0,
      'fridge_side_gap' => 20.0, 'fridge_top_gap' => 80.0, 'fridge_back_gap' => 50.0,
      'shelf_front_setback' => 20.0, 'panel_limit' => true, 'panel_span' => 'cell', 'panel_door_fit' => 'auto',
      'cabinet_tag' => 'VGD_CD_CABINET', 'part_tag' => 'VGD_CD_PARTS',
      'opening_tag' => 'VGD_CD_OPENING'
    }.freeze

    # Thông số đi kèm từng loại tủ: áp vào khi đổi Loại tủ (người dùng vẫn sửa lại được sau đó).
    #   bếp dưới: chân nhựa + len chân cao 100, lùi 50 (thông lệ 100-150 / 50-75 mm), không phào trần.
    #   bếp trên: không chân, không phào, có xà treo.   tủ lạnh: không chân (tủ lạnh đặt trên sàn), hông chạm đất.
    TYPE_PRESETS = {
      'standard' => { 'leg_height' => 40.0, 'ceiling_strip_height' => 20.0, 'toe_kick_enabled' => true, 'toe_kick_setback' => 50.0,
                      'cornice_enabled' => true, 'sides_to_floor' => false, 'sides_to_ceiling' => false, 'top_mode' => 'auto' },
      'base' => { 'leg_height' => 100.0, 'ceiling_strip_height' => 0.0, 'toe_kick_enabled' => true, 'toe_kick_setback' => 50.0,
                  'toe_kick_back' => true, 'cornice_enabled' => false, 'sides_to_floor' => false, 'sides_to_ceiling' => false, 'top_mode' => 'auto' },
      'wall' => { 'leg_height' => 0.0, 'ceiling_strip_height' => 0.0, 'toe_kick_enabled' => false, 'cornice_enabled' => false,
                  'sides_to_floor' => false, 'sides_to_ceiling' => false, 'top_mode' => 'auto', 'hang_rail' => true },
      'fridge' => { 'leg_height' => 0.0, 'toe_kick_enabled' => false, 'sides_to_floor' => true, 'top_mode' => 'auto' }
    }.freeze

    # Gộp thông số: bộ mặc định, rồi lần lượt từng lớp ghi đè (gộp sâu cho 'panels').
    # Giá trị nil hoặc NaN nghĩa là "dùng mặc định", không ghi đè.
    def merge_settings(*layers)
      layers.compact.reduce(deep_copy(DEFAULTS)) { |memo, layer| deep_merge(memo, layer) }
    end

    def deep_merge(base, override)
      out = base.dup
      (override || {}).each do |key, value|
        key = key.to_s
        next if value.nil?
        next if value.is_a?(Float) && value.nan?
        out[key] = out[key].is_a?(Hash) && value.is_a?(Hash) ? deep_merge(out[key], value) : value
      end
      out
    end

    def deep_copy(object)
      Marshal.load(Marshal.dump(object))
    end
  end
end
