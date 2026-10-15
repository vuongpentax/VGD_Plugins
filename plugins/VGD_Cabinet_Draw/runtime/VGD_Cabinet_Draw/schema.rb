module VGD_Cabinet_Draw
  module Schema
    DICTIONARY = 'VGD_Cabinet_Draw'.freeze
    MODEL_SCHEMA = 1
    PART_ROLES = %w[side_left side_right top bottom back shelf partition door drawer_front drawer_box rail handle opening].freeze
    TOOLS = {
      'box' => 'Box → Cabinet', 'panel' => 'Đợt / vách', 'door' => 'Chia cánh',
      'opening' => 'Hướng mở', 'handle' => 'Tay nắm', 'drawer' => 'Hộc kéo',
      'wardrobe' => 'Hộc tủ áo', 'blocker' => 'Xà chặn', 'cut' => 'Cắt ván',
      'round' => 'Bo góc', 'notch' => 'Khấu ván'
    }.freeze
    DEFAULTS = {
      'board_thickness' => 17.5, 'back_thickness' => 6.0,
      'back_mode' => 'groove', 'back_groove_depth' => 8.75,
      'ceiling_strip_height' => 20.0, 'door_gap' => 0.0,
      'drawer_gap' => 0.0, 'drawer_tier_gap' => 25.0,
      'split_axis' => 'vertical', 'panel_axis' => 'horizontal',
      'shelf_edge_clearance' => 1.6, 'front_offset' => 0.0,
      'cabinet_tag' => 'VGD_CD_CABINET', 'part_tag' => 'VGD_CD_PARTS',
      'opening_tag' => 'VGD_CD_OPENING'
    }.freeze
  end
end
