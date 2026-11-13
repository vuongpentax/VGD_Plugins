module VGD_Cabinet_Draw
  # Khoang ngăn kéo (thay Hộc tủ áo): một hộp 4 tấm (đáy, nóc, 2 hông) đặt trong ô tủ, lùi sau cánh,
  # hai hông khoang cách hông tủ một khoảng để bản lề (cốc 35 mm) và tay bản lề không cấn khi mở cánh.
  # Một lệnh dựng luôn khoang và các ngăn kéo bên trong (mặt hộc nằm lọt trong khoang).
  module DrawerBay
    module_function

    KEYS = %w[bay_setback bay_side_gap bay_height].freeze
    CONTAINER = 'Khoang Ngăn Kéo'.freeze

    # Hình học khoang (hệ thùng tủ, đơn vị inch nội bộ). Trả hash gồm khung ngoài và "lòng khoang" (Cell) cho ngăn kéo.
    def geometry(root, shell, settings, local = nil)
      mm = ->(key, default) { (settings[key].nil? ? default : settings[key]).to_f.mm }
      cell = local ? Interior.cell_at(shell, local.x, local.z) : Interior.inner(shell)
      body = Geometry.body_bounds(shell)
      t = mm.call('board_thickness', 17.5)
      recessed = !Rebuild.settings_of(root)['door_recess'].nil?
      fit = Interior.door_fit(root) || 'phu'
      door_back = recessed ? t : (fit == 'phu' ? body.min.y : body.min.y + t)
      setback = mm.call('bay_setback', 20)
      side_gap = mm.call('bay_side_gap', 35)
      x0 = cell.x0 + side_gap
      x1 = cell.x1 - side_gap
      z0 = cell.z0
      height = mm.call('bay_height', 0)
      z0 = [[local.z, cell.z0].max, cell.z1].min if height > 0 && local
      z1 = height > 0 ? [z0 + height, cell.z1].min : cell.z1
      y0 = door_back + setback
      y1 = Interior.back_limit(shell, z0, z1)
      raise format('Khoang quá hẹp: ô rộng %.0f mm, trừ 2 khe hông %.0f mm còn %.0f mm.', cell.width.to_mm, side_gap.to_mm, (x1 - x0).to_mm) if x1 - x0 < 2 * t + 100.mm
      raise format('Khoang quá thấp (%.0f mm).', (z1 - z0).to_mm) if z1 - z0 < 2 * t + 60.mm
      raise 'Khoang không còn chỗ sâu (lùi sau cánh quá lớn).' if y1 - y0 < 200.mm
      side = Interior::Side.new(:outer, t)
      inner = Interior::Cell.new(x0 + t, x1 - t, z0 + t, z1 - t, y0, y1, side, side, side, side)
      { x0: x0, x1: x1, z0: z0, z1: z1, y0: y0, y1: y1, t: t, cell: inner, y_front: y0 + t }
    end

    def build_box(shell, geo, op)
      g = shell.definition.entities.add_group
      g.name = CONTAINER
      t = geo[:t]
      Operations.part_box(g.entities, 'Đáy Khoang', 'bay_bottom', geo[:x0], geo[:x1], geo[:y0], geo[:y1], geo[:z0], geo[:z0] + t)
      Operations.part_box(g.entities, 'Nóc Khoang', 'bay_top', geo[:x0], geo[:x1], geo[:y0], geo[:y1], geo[:z1] - t, geo[:z1])
      Operations.part_box(g.entities, 'Hông Khoang Trái', 'bay_side', geo[:x0], geo[:x0] + t, geo[:y0], geo[:y1], geo[:z0] + t, geo[:z1] - t)
      Operations.part_box(g.entities, 'Hông Khoang Phải', 'bay_side', geo[:x1] - t, geo[:x1], geo[:y0], geo[:y1], geo[:z0] + t, geo[:z1] - t)
      ModelData.stamp(g, 'bay', { 'width_mm' => (geo[:x1] - geo[:x0]).to_mm, 'height_mm' => (geo[:z1] - geo[:z0]).to_mm, 'op' => op })
      g
    end

    # Dựng khoang + ngăn kéo. op_id có sẵn khi dựng lại.
    def place(root, shell, settings, local, op_id = nil)
      geo = geometry(root, shell, settings, local)
      op_id ||= Rebuild.record(root, { 'type' => 'bay', 'anchor' => local ? Rebuild.anchor_of(shell, local.x, local.z) : nil,
                                       'settings' => settings.select { |key, _| Rebuild::DRAWER_KEYS.include?(key) || KEYS.include?(key) } })
      group = build_box(shell, geo, op_id)
      plan = Operations.build_drawers(root, settings, local, op_id, geo)
      [group, plan]
    end

    def run(targets, settings, points)
      targets.each do |root|
        root.make_unique if root.respond_to?(:make_unique)
        shell = Operations.shell_for(root)
        shell.make_unique if shell.respond_to?(:make_unique)
        locals = Operations.local_clicks(root, shell, points)
        place(root, shell, settings, locals.first)
        Geometry.share_components(root)
      end
    end
  end
end
