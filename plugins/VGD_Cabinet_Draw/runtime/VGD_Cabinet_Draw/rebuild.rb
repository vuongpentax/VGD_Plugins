module VGD_Cabinet_Draw
  # Sửa tủ đã tạo (kiểu thông số Dynamic Component): đổi thông số/kích thước rồi DỰNG LẠI theo dữ liệu.
  #   - Mỗi lệnh tạo chi tiết bên trong (đợt/vách, ngăn kéo, xà chặn, hộc tủ áo) được ghi thành một "bước" (op) trong
  #     thuộc tính 'build_ops_json' của tủ, theo thứ tự. Dựng lại = dựng vỏ tủ mới rồi chạy lại các bước theo thứ tự.
  #   - Vị trí ô của mỗi bước lưu bằng điểm neo tương đối (tỷ lệ 0..1 trong lòng tủ), nên tủ đổi kích thước vẫn tìm đúng ô.
  #   - Chia đều (/n) thì chia lại đều; đặt theo khoảng cách thì giữ khoảng cách tới mép dưới/trái của ô.
  #   - Cánh dựng lại từ bố cục vùng (tỷ lệ), giữ tay nắm và góc mở.
  #   - Tấm đã chỉnh tay (chữ ký hình học khác lúc dựng) được liệt kê để người dùng chọn ghi đè / giữ / hủy.
  module Rebuild
    extend self

    DICT = 'VGD_Cabinet_Draw'.freeze
    DRAWER_KEYS = %w[drawer_count drawer_front_height drawer_gap drawer_fit drawer_slide drawer_depth drawer_box_thickness
                     drawer_bottom_thickness drawer_back_clearance drawer_ray_space drawer_box_bottom_lift drawer_box_top_clearance
                     drawer_mode drawer_bottom_type drawer_groove_depth drawer_groove_height board_thickness door_style frame_joint frame_width rail_width panel_recess glass_rows glass_columns
                     glass_bar_width glass_thickness door_edge_gap door_inset_gap].freeze
    BLOCKER_KEYS = %w[blocker_height blocker_profile board_thickness compartment_height].freeze
    MEMBER_ROLES = %w[shelf partition].freeze
    STEP_NAMES = { 'panel' => 'Đợt/vách', 'drawer' => 'Ngăn kéo', 'blocker' => 'Xà chặn', 'wardrobe' => 'Hộc tủ áo', 'bay' => 'Khoang ngăn kéo' }.freeze
    EXTRA_KINDS = %w[blocker wardrobe_compartment bay].freeze

    # ---------- Ghi các bước tạo ----------

    def ops(root)
      list = (JSON.parse(root.get_attribute(DICT, 'build_ops_json', '[]')) rescue [])
      list.is_a?(Array) ? list : []
    end

    def save_ops(root, list)
      root.set_attribute(DICT, 'build_ops_json', JSON.generate(list))
    end

    # Thêm một bước, trả về số thứ tự (op id).
    def record(root, op)
      list = ops(root)
      id = (list.map { |item| item['op'].to_i }.max || 0) + 1
      save_ops(root, list + [op.merge('op' => id)])
      id
    end

    # Điểm (hệ thùng tủ) -> tỷ lệ [u, w] trong lòng tủ, và ngược lại.
    def anchor_of(shell, x, z)
      inner = Interior.inner(shell)
      [(x - inner.x0) / [inner.width, 1e-9].max, (z - inner.z0) / [inner.height, 1e-9].max]
    end

    def point_of(shell, anchor)
      inner = Interior.inner(shell)
      u, w = anchor || [0.5, 0.5]
      Geom::Point3d.new(inner.x0 + u.to_f * inner.width, (inner.y0 + inner.y1) / 2, inner.z0 + w.to_f * inner.height)
    end

    # ---------- Đợt / vách ----------

    # Vị trí các tấm khi chia đều ô thành count phần (giống công cụ Đợt/vách).
    def divide_positions(cell, count, kind, t, vertical)
      low, high = vertical ? [cell.x0, cell.x1] : [cell.z0, cell.z1]
      raw = case kind
            when 'lot_long'
              (1...count).map { |i| low + (high - low) * i / count - t / 2 }
            when 'phu_bi'
              low_side, high_side = vertical ? [cell.left, cell.right] : [cell.bottom, cell.top]
              reach = ->(side) { side.kind == :inner ? side.t / 2.0 : side.t }
              lo = low - reach.call(low_side)
              hi = high + reach.call(high_side)
              (1...count).map { |i| lo + (hi - lo) * i / count - t / 2 }
            else
              gap = (high - low - t * (count - 1)) / count
              (1...count).map { |i| low + gap * i + t * (i - 1) }
            end
      raw.map { |value| [[value, low].max, high - t].min }
    end

    # Độ lùi mặt trước của đợt: lùi chuẩn + dày cánh nếu tủ dùng cánh lọt.
    def shelf_setback(root, setback_mm, door_fit_choice, board_mm)
      base = setback_mm.to_f.mm
      fit = %w[phu lot].include?(door_fit_choice.to_s) ? door_fit_choice.to_s : (Interior.door_fit(root) == 'phu' || Interior.door_fit(root).nil? ? 'phu' : 'lot')
      return base unless fit == 'lot'
      base + (Interior.door_thickness_mm(root) || board_mm).to_f.mm
    end

    # Vách lùi mặt trước đúng bằng dày cánh khi tủ dùng cánh lọt (cánh nằm giữa hai hông). Cánh phủ: không lùi.
    def partition_setback(root, door_fit_choice, board_mm)
      fit = %w[phu lot].include?(door_fit_choice.to_s) ? door_fit_choice.to_s : (Interior.door_fit(root) == 'phu' || Interior.door_fit(root).nil? ? 'phu' : 'lot')
      return 0.0 unless fit == 'lot'
      (Interior.door_thickness_mm(root) || board_mm).to_f.mm
    end

    # Hộp [x0,y0,z0,x1,y1,z1] của một đợt tại độ cao pos trong ô (đợt ngang).
    def board_box(shell, cell, pos, t, setback)
      y1 = Interior.back_limit(shell, pos, pos + t)
      [cell.x0, [cell.y0 + setback, y1 - 10.mm].min, pos, cell.x1, y1, pos + t]
    end

    # Biên dạng [y, z] của vách (tấm đứng) tại ô: đi hết chiều sâu tới mặt sau trong cùng,
    # chỉ khấu góc sau-trên đúng ở dải cao của xà treo / giằng sau. Phần dưới xà không bị cắt ngắn.
    # Vách cũng lùi mặt trước như đợt (cánh lọt nằm giữa hai hông, vách không được đâm vào mặt tủ).
    def vertical_profile(shell, cell, setback)
      yb = Interior.full_depth(shell)
      yf = [cell.y0 + setback, yb - 10.mm].min
      pts = [[yf, cell.z0], [yb, cell.z0]]
      Interior.back_notches(shell, cell.z0, cell.z1).each do |ny, za, zb|
        pts += [[yb, za], [ny, za], [ny, zb], [yb, zb]]
      end
      pts += [[yb, cell.z1], [yf, cell.z1]]
      pts.each_with_object([]) do |p, out|
        last = out.last
        out << p unless last && (last[0] - p[0]).abs < Interior::EPS && (last[1] - p[1]).abs < Interior::EPS
      end
    end

    # Các mặt (để vẽ xem trước) của biên dạng vách đã đùn theo x từ x0 tới x1.
    def profile_faces(profile, x0, x1)
      front = profile.map { |y, z| [x0, y, z] }
      back = profile.map { |y, z| [x1, y, z] }
      sides = profile.each_index.map do |i|
        y, z = profile[i]
        ny, nz = profile[(i + 1) % profile.size]
        [[x0, y, z], [x0, ny, nz], [x1, ny, nz], [x1, y, z]]
      end
      [front, back] + sides
    end

    def panel_cell(shell, op)
      return Interior.inner(shell) unless op['limit'] && op['anchor']
      p = point_of(shell, op['anchor'])
      Interior.cell_at(shell, p.x, p.z)
    end

    def panel_positions(shell, cell, op)
      vertical = op['axis'] == 'vertical'
      t = op['thickness_mm'].to_f.mm
      low, high = vertical ? [cell.x0, cell.x1] : [cell.z0, cell.z1]
      # 'omit': chỉ số các tấm đã xóa (xem Removal). Tấm còn lại giữ nguyên vị trí.
      omit = Array(op['omit']).map(&:to_i)
      if op['mode'] == 'divide'
        positions = divide_positions(cell, op['count'].to_i, op['kind'].to_s, t, vertical)
        positions.each_with_index.reject { |_, i| omit.include?(i) }.map(&:first)
      else
        (op['offsets'] || []).each_with_index.reject { |_, i| omit.include?(i) }.map { |mm, _| [[low + mm.to_f.mm, low].max, high - t].min }
      end
    end

    # Dựng các tấm của một bước đợt/vách. skip: các chỉ số (index) đang được giữ nguyên (chỉnh tay).
    def place_panels(root, shell, op, skip = [])
      vertical = op['axis'] == 'vertical'
      t = op['thickness_mm'].to_f.mm
      cell = panel_cell(shell, op)
      # span 'full' (beta.28): tấm xuyên qua các tấm khác, trải hết lòng tủ theo hai chiều còn lại; trục chia vẫn theo ô.
      span_cell = op['span'].to_s == 'full' ? Interior.inner(shell) : cell
      setback = vertical ? partition_setback(root, op['door_fit'], op['thickness_mm']) : shelf_setback(root, op['setback_mm'], op['door_fit'], op['thickness_mm'])
      positions = panel_positions(shell, cell, op).sort
      existing = Interior.members(shell)[vertical ? :partitions : :shelves].length
      boards = []
      positions.each_with_index do |pos, index|
        next if skip.include?(index)
        if vertical
          profile = vertical_profile(shell, span_cell, setback)
          points = profile.map { |y, z| [pos, y, z] }
          board = Geometry.rectangular_board(shell.definition.entities, "Vách #{existing + boards.length + 1}", points, t, X_AXIS)
          Geometry.stamp_part(board, 'partition', { 'thickness_mm' => t.to_mm, 'divide_kind' => op['kind'], 'op' => op['op'], 'index' => index })
        else
          b = board_box(shell, span_cell, pos, t, setback)
          points = [[b[0], b[1], b[2]], [b[3], b[1], b[2]], [b[3], b[4], b[2]], [b[0], b[4], b[2]]]
          board = Geometry.rectangular_board(shell.definition.entities, "Đợt #{existing + boards.length + 1}", points, t, Z_AXIS)
          Geometry.stamp_part(board, 'shelf', { 'thickness_mm' => t.to_mm, 'divide_kind' => op['kind'], 'op' => op['op'], 'index' => index,
                                                'front_setback_mm' => (b[1] - cell.y0).to_mm })
        end
        Geometry.stamp_signature(board)
        boards << board
      end
      boards
    end

    # ---------- Phát hiện tấm chỉnh tay ----------

    # Danh sách { entity, label, role } các tấm đã bị chỉnh tay trong tủ.
    def hand_edited(root)
      shell = Geometry.shell_for(root)
      return [] unless shell
      out = []
      expected = expected_carcass(root)
      Interior.containers(shell).each do |entity|
        role = Interior.role_of(entity)
        next unless role
        edited = Geometry.hand_edited?(entity)
        if edited.nil? && expected[role]
          b = Interior.box_of(entity).map(&:to_mm)
          edited = b.zip(expected[role]).any? { |a, e| (a - e).abs > 0.5 }
        end
        out << { entity: entity, label: entity.name.to_s, role: role, signed: !entity.get_attribute(DICT, 'geo_sig').nil? } if edited
      end
      # Tủ tạo bằng bản rất cũ (chưa có chữ ký): nếu MỌI tấm vỏ tủ đều lệch so với tính toán hiện tại thì đó là do
      # đổi phiên bản, không phải chỉnh tay — không hỏi.
      carcass = out.select { |item| Interior::CARCASS_ROLES.include?(item[:role]) && !item[:signed] }
      all_carcass = Interior.containers(shell).count { |e| Interior::CARCASS_ROLES.include?(Interior.role_of(e)) }
      out -= carcass if carcass.length == all_carcass && all_carcass > 1
      out
    end

    # Hộp mong đợi (mm, hệ thùng tủ) của các tấm vỏ tủ theo dữ liệu đang lưu (cho tủ cũ chưa có chữ ký).
    def expected_carcass(root)
      data = ModelData.params(root)
      settings = settings_of(root)
      result = PanelModel.compute(data['width_mm'], data['depth_mm'], data['height_mm'], settings)
      result.parts.each_with_object({}) { |part, out| out[part.role] = part.bounds }
    rescue StandardError
      {}
    end

    # ---------- Đọc thông số / kích thước của tủ ----------

    def settings_of(root)
      data = ModelData.params(root)
      s = data.reject { |key, _| %w[width_mm depth_mm height_mm panel_spec panels_input local_axes front_normal remove_source].include?(key) }
      if data['panels_input'].is_a?(Hash)
        s['panels'] = data['panels_input']
      elsif data['panel_spec'].is_a?(Hash) && data['panel_spec']['panels'].is_a?(Hash)
        # Tủ cũ: độ dày bằng dày ván/dày hậu chung thì coi là "theo dày chung" (để trống).
        board = data['panel_spec']['board_thickness'].to_f
        back = data['panel_spec']['back_thickness'].to_f
        s['panels'] = data['panel_spec']['panels'].map do |role, entry|
          entry = entry.dup
          common = role == 'back' ? back : board
          entry['thickness'] = nil if (entry['thickness'].to_f - common).abs < 1e-6
          [role, entry]
        end.to_h
      end
      merged = Schema.merge_settings(s)
      merged['panels'] = Schema.deep_merge(merged['panels'], s['panels']) if s['panels'] # giữ nil (= theo dày chung)
      merged
    end

    # Kích thước thật (mm) [rộng, sâu, cao], tính cả khi người dùng đã kéo Scale tủ.
    def dimensions_of(root)
      data = ModelData.params(root)
      dims = [data['width_mm'].to_f, data['depth_mm'].to_f, data['height_mm'].to_f]
      scale = scale_of(root)
      return dims if scale.nil?
      shell = Geometry.shell_for(root)
      axes = [shell.transformation.xaxis, shell.transformation.yaxis, shell.transformation.zaxis]
      dims.each_with_index.map do |value, i|
        a = axes[i]
        value * Math.sqrt((a.x * scale[0])**2 + (a.y * scale[1])**2 + (a.z * scale[2])**2)
      end
    end

    # Hệ số scale [sx, sy, sz] của tủ (nil nếu không bị scale).
    def scale_of(root)
      _rigid, scales = Geometry.rigid_of(root)
      scales.all? { |v| (v - 1.0).abs < 1e-6 } ? nil : scales
    end

    # ---------- Dựng lại ----------

    # Tủ cũ (trước beta.15) có đợt/vách nhưng chưa có bước tạo: đổi chúng thành bước "đặt theo khoảng cách".
    def adopt_legacy(root, shell)
      list = ops(root)
      known = list.map { |op| op['op'] }
      legacy = Interior.containers(shell).select do |entity|
        role = Interior.role_of(entity)
        name = entity.name.to_s
        member = MEMBER_ROLES.include?(role) || (role.nil? && name =~ /\A(Đợt|Vách) \d+\z/)
        member && !known.include?(ModelData.params(entity)['op'])
      end
      return list if legacy.empty?
      partitions, shelves = legacy.partition { |e| Interior.role_of(e) == 'partition' || e.name.to_s.start_with?('Vách') }
      # Vách theo thứ tự trái -> phải, đợt dưới -> trên: khoảng cách mỗi tấm đo tới tấm trước nó.
      partitions = partitions.sort_by { |e| Interior.box_of(e)[0] }
      shelves = shelves.sort_by { |e| Interior.box_of(e)[2] }
      # Bước cũ mang số âm để chạy TRƯỚC mọi bước mới (đã có trước chúng).
      first_id = [list.map { |item| item['op'].to_i }.min.to_i, 1].min - (partitions.length + shelves.length)
      added = []
      (partitions + shelves).each do |entity|
        vertical = partitions.include?(entity)
        b = Interior.box_of(entity)
        cx = (b[0] + b[3]) / 2
        cz = (b[2] + b[5]) / 2
        cell = Interior.cell_at(shell, cx, cz)
        low = vertical ? cell.x0 : cell.z0
        pos = vertical ? b[0] : b[2]
        t = vertical ? b[3] - b[0] : b[5] - b[2]
        op = { 'type' => 'panel', 'axis' => vertical ? 'vertical' : 'horizontal', 'mode' => 'free', 'offsets' => [(pos - low).to_mm],
               'kind' => 'thong_thuy', 'thickness_mm' => t.to_mm, 'limit' => true, 'anchor' => anchor_of(shell, cx, cz),
               'setback_mm' => vertical ? 0.0 : (b[1] - cell.y0).to_mm, 'door_fit' => 'phu' }
        id = first_id + added.length
        added << op.merge('op' => id)
        params = ModelData.params(entity)
        Geometry.stamp_part(entity, vertical ? 'partition' : 'shelf', params.merge('op' => id, 'index' => 0))
      end
      # Bước cũ chạy trước các bước mới (chúng có trước).
      list = added + list
      save_ops(root, list)
      list
    end

    # Đặt lại phép biến đổi khi tủ đã bị Scale: tủ về phép biến đổi cứng, gốc các nhóm con dời theo scale.
    def unscale!(root)
      scale = scale_of(root)
      return unless scale
      rigid, = Geometry.rigid_of(root)
      root.definition.entities.to_a.each do |child|
        next unless child.respond_to?(:transformation=) && (child.is_a?(Sketchup::Group) || child.is_a?(Sketchup::ComponentInstance))
        tr = child.transformation
        o = tr.origin
        child.transformation = Geom::Transformation.axes(Geom::Point3d.new(o.x * scale[0], o.y * scale[1], o.z * scale[2]), tr.xaxis, tr.yaxis, tr.zaxis)
      end
      root.transformation = rigid
    end

    # Dựng lại một tủ với thông số và kích thước mới (mm). keep: các entity chỉnh tay cần giữ nguyên.
    # Chạy trong một operation do công cụ mở. Trả về danh sách cảnh báo.
    def run(root, settings, dims, keep = [], share: true)
      warnings = []
      result = PanelModel.compute(dims[0], dims[1], dims[2], settings) # kiểm tra trước khi xóa gì
      # Tấm giữ nguyên được nhận theo vai trò / (bước, chỉ số), không theo đối tượng: make_unique (tủ là bản copy)
      # tạo đối tượng mới nên so đối tượng cũ sẽ trượt.
      kept_roles = []
      kept_members = Hash.new { |h, k| h[k] = [] }
      keep.each do |entity|
        next unless entity.valid?
        role = Interior.role_of(entity)
        params = ModelData.params(entity)
        if MEMBER_ROLES.include?(role)
          kept_members[params['op']] << params['index'].to_i
        elsif role
          kept_roles << role
        end
      end
      # Cấu kiện giữ tại chỗ (co giãn tủ): không dựng lại, không xóa, không chép lại tay nắm.
      kept_keys = keep.select(&:valid?).map { |entity| stretch_key(entity) }.compact
      kept_item = ->(entity) { kept_keys.include?(stretch_key(entity)) }
      make_unique_tree(root)
      shell = Geometry.shell_for(root)
      raise 'Không tìm thấy thùng tủ.' unless shell
      list = adopt_legacy(root, shell)
      doors = Operations.doors_of(root)
      doors_kept = !doors.empty? && doors.all? { |door| kept_keys.include?(stretch_key(door)) }
      drawer_handles = capture_drawer_handles(root, kept_keys)
      warnings << 'Ngăn kéo đang mở được đóng lại khi dựng lại tủ.' if DrawerSlide.any_open?(root)
      unscale!(root)
      # Vật liệu và vân của các ván vỏ tủ sẽ dựng lại được nhớ lại trước khi xóa, rồi gán lại cho ván mới.
      looks = carcass_looks(shell, kept_roles)
      keep = Interior.containers(shell).select do |entity|
        role = Interior.role_of(entity)
        params = ModelData.params(entity)
        MEMBER_ROLES.include?(role) ? kept_members.key?(params['op']) && kept_members[params['op']].include?(params['index'].to_i) : kept_roles.include?(role)
      end
      known = list.map { |op| op['op'] }
      old_note = lambda do |what|
        text = "#{what} tạo bằng bản cũ (chưa có dữ liệu dựng lại) được giữ nguyên vị trí cũ — hãy kiểm tra hoặc tạo lại."
        warnings << text unless warnings.include?(text)
      end
      # Xóa phần sẽ dựng lại (giữ tấm chỉnh tay được chọn giữ). Chi tiết chưa có bước tạo (bản cũ) thì giữ + báo.
      Interior.containers(shell).each do |entity|
        next if keep.include?(entity) || kept_item.call(entity)
        role = Interior.role_of(entity)
        kind = entity.get_attribute(DICT, 'kind')
        if Interior::CARCASS_ROLES.include?(role) || MEMBER_ROLES.include?(role)
          entity.erase!
        elsif EXTRA_KINDS.include?(kind)
          known.include?(ModelData.params(entity)['op']) ? entity.erase! : old_note.call({ 'blocker' => 'Xà chặn', 'bay' => 'Khoang ngăn kéo' }.fetch(kind, 'Hộc tủ áo'))
        elsif kind == 'drawer_front' || kind == 'drawer_box'
          old_note.call('Ngăn kéo')
        end
      end
      root.definition.entities.to_a.each do |entity|
        next unless entity.respond_to?(:name) && entity.valid?
        name = entity.name # đọc tên TRƯỚC khi xóa: đọc entity đã xóa là lỗi "reference to deleted Group"
        if ['Chân & phào', 'Tủ lạnh (tham chiếu)'].include?(name)
          entity.erase!
          next
        end
        next unless name == Operations::DRAWER_CONTAINER
        entity.definition.entities.to_a.each do |child|
          next unless child.valid?
          next if kept_item.call(child)
          known.include?(child.get_attribute(DICT, 'op')) ? child.erase! : old_note.call('Ngăn kéo')
        end
      end
      Geometry.build_carcass(root, shell, result, settings, dims[0], dims[1], dims[2], {}, kept_roles)
      apply_carcass_looks(shell, looks)
      failures = []
      list.sort_by { |op| op['op'].to_i }.each do |op|
        next if op['type'] != 'panel' && kept_keys.any? { |key| key.length > 1 && key[1] == op['op'] }
        begin
          replay(root, shell, op, kept_members[op['op']])
        rescue StandardError => e
          failures << "#{STEP_NAMES.fetch(op['type'], op['type'])}: #{e.message.sub(/\.\z/, '')}"
        end
      end
      begin
        rebuild_doors(root) unless doors_kept
      rescue StandardError => e
        failures << "Cánh: #{e.message.sub(/\.\z/, '')}"
      end
      # Có bước không dựng lại được thì HỦY TOÀN BỘ (operation sẽ hoàn tác), để không mất chi tiết của người dùng.
      raise "Không sửa được tủ vì: #{failures.join('; ')}. Tủ giữ nguyên như cũ — hãy chỉnh lại thông số." unless failures.empty?
      restore_drawer_handles(root, drawer_handles)
      Geometry.share_components(root) if share
      warnings
    end

    # ---------- Co giãn tại chỗ (tự cập nhật khi kéo Scale) ----------
    # Hai cách, tùy loại cấu kiện (xem Links cho quan hệ giữa các cấu kiện):
    #   - Vỏ tủ, đợt/vách: CO GIÃN tại chỗ theo hộp cũ → hộp mới. Độ dày giữ nguyên, đối tượng giữ nguyên.
    #   - Cánh, mặt và thùng ngăn kéo, khoang, xà chặn, hộc tủ áo: THAY NỘI DUNG bằng bản dựng lại ở kích thước mới,
    #     nên khung, gờ, khe, đế giữ đúng mm (không co theo tỷ lệ). Đối tượng ngoài giữ nguyên, vật liệu đặt lại theo tên.
    # Nội dung mới lấy từ BẢN THỬ (bản sao của tủ dựng ở kích thước mới), xóa bản thử khi xong.
    # Tủ không khớp công thức thì dựng lại như cũ (rebuild_as_before).
    REGENERATED_KINDS = %w[door front box bay blocker wardrobe_compartment].freeze

    def regenerated?(key)
      REGENERATED_KINDS.include?(key.first)
    end

    # Khóa nhận diện một cấu kiện co giãn được. nil nếu không nhận ra (tủ cũ hoặc chi tiết thiếu bước tạo).
    def stretch_key(entity)
      return nil unless entity.valid?
      role = Interior.role_of(entity)
      return [role] if Interior::CARCASS_ROLES.include?(role)
      if MEMBER_ROLES.include?(role)
        op = ModelData.params(entity)['op']
        return op && [role, op, ModelData.params(entity)['index'].to_i]
      end
      return door_key(entity) if Operations.door?(entity)
      kind = entity.get_attribute(DICT, 'kind')
      case kind
      when 'drawer_front', 'drawer_box'
        op = entity.get_attribute(DICT, 'op')
        op && [kind == 'drawer_front' ? 'front' : 'box', op, entity.get_attribute(DICT, 'op_index').to_i]
      when *EXTRA_KINDS
        op = ModelData.params(entity)['op']
        op && [kind, op]
      end
    end

    def door_key(door)
      region = door.get_attribute(DICT, 'region_id')
      region && ['door', region.to_s]
    end

    def legacy_member?(entity)
      Interior.role_of(entity).nil? && entity.name.to_s =~ /\A(Đợt|Vách) \d+\z/
    end

    # Các cấu kiện co giãn được của tủ: { khóa => entity }. nil nếu có chi tiết không nhận ra (tủ cũ hoặc thiếu bước).
    def stretch_items(root, shell)
      containers = Interior.containers(shell)
      return nil if containers.any? { |e| legacy_member?(e) }
      candidates = containers.select do |e|
        role = Interior.role_of(e)
        Interior::CARCASS_ROLES.include?(role) || MEMBER_ROLES.include?(role) || EXTRA_KINDS.include?(e.get_attribute(DICT, 'kind'))
      end
      container = root.definition.entities.to_a.find { |e| e.is_a?(Sketchup::Group) && e.valid? && e.name == Operations::DRAWER_CONTAINER }
      candidates += container.definition.entities.to_a.select { |e| e.valid? && (DrawerSlide.front?(e) || DrawerSlide.box?(e)) } if container
      candidates += Operations.doors_of(root)
      items = {}
      candidates.each do |entity|
        key = stretch_key(entity)
        return nil if key.nil? || items.key?(key)
        items[key] = entity
      end
      items
    end

    # Hộp và thông số của từng cấu kiện: { khóa => { box:, params: } }. Cánh đo hộp trong hệ của cánh, phần còn lại
    # đo trong hệ của nhóm chứa (hai hệ này trùng với hệ thùng tủ).
    def recipe_of(items)
      items.transform_values do |entity|
        box = Operations.door?(entity) ? Operations.door_bounds(entity) : Interior.box_of(entity)
        { box: box, params: entity.get_attribute(DICT, 'params_json') }
      end
    end

    # Dựng thử tủ ở kích thước dims rồi giao bản thử và các cấu kiện của nó cho khối lệnh. Bản thử bị xóa khi xong.
    def with_probe(root, settings, dims)
      probe = probe_copy(root)
      run(probe, settings, dims, [], share: false)
      yield probe, stretch_items(probe, Geometry.shell_for(probe))
    ensure
      discard_probe(probe) if probe&.valid?
    end

    def same_keys?(recipe, items)
      recipe.keys.map(&:inspect).sort == items.keys.map(&:inspect).sort
    end

    # Co giãn tủ đang bị kéo Scale về kích thước thật. Chạy trong một operation do người gọi mở. Trả về danh sách cảnh báo.
    def stretch(root)
      # Tách các nhóm dùng chung định nghĩa (tủ copy) trước khi đọc hay sửa, để không đổi lây sang bản copy khác.
      make_unique_tree(root)
      dims = dimensions_of(root)
      settings = settings_of(root)
      old_dims = ModelData.params(root).values_at('width_mm', 'depth_mm', 'height_mm').map(&:to_f)
      shell = Geometry.shell_for(root)
      raise 'Không tìm thấy thùng tủ.' unless shell
      parts = stretch_items(root, shell)
      return rebuild_as_before(root, settings, dims) unless parts
      with_probe(root, settings, old_dims) do |_old_probe, old_items|
        with_probe(root, settings, dims) do |new_probe, new_items|
          return rebuild_as_before(root, settings, dims) unless old_items && new_items
          from = recipe_of(old_items)
          to = recipe_of(new_items)
          unless same_keys?(from, parts) && same_keys?(to, parts) && from.values.all? { |item| item[:box] } && to.values.all? { |item| item[:box] }
            return rebuild_as_before(root, settings, dims)
          end
          # Bản lề phải còn bắt được vào tấm vỏ tủ ở kích thước mới; nếu không thì ném lỗi, operation hoàn tác.
          Links.check!(Geometry.shell_for(new_probe), Operations.doors_of(new_probe))
          stretch_all!(root, settings, dims, parts, from, to, new_items)
        end
      end
    end

    def stretch_all!(root, settings, dims, parts, from, to, new_items)
      unscale!(root)
      # Cánh đang mở: nhớ góc, hướng mở và loại mở hiện tại, đóng về 0 để thay nội dung, rồi mở lại sau.
      door_states = Links.ordered(Operations.doors_of(root)).map do |door|
        [door, Operations.door_angle(door), door.get_attribute(DICT, 'opening_side', 'left'), Operations.opening_type_of(door)]
      end
      DrawerSlide.close_all(root)
      door_states.each { |door, angle, side, _type| Operations.set_door_angle(door, side, 0) if angle > 0.5 }
      # Tách bản riêng trước khi sửa (tránh đổi lây sang bản copy dùng chung), rồi nhớ và gỡ tay nắm (dựng lại sau).
      parts.each_value { |entity| entity.make_unique if entity.is_a?(Sketchup::ComponentInstance) }
      handles = parts.values.to_h { |entity| [entity, Operations.handle_specs(entity)] }
      parts.each_value { |entity| Operations.handle_groups(entity).each(&:erase!) }
      # Tấm đang chỉnh tay (lệch chữ ký) giữ chữ ký cũ để vẫn được nhận là chỉnh tay sau khi co giãn.
      edited_before = parts.transform_values { |entity| Geometry.hand_edited?(entity) }
      parts.each do |key, entity|
        if regenerated?(key)
          replace_contents(entity, new_items.fetch(key))
        elsif !same_box?(from[key][:box], to[key][:box])
          stretch_part!(entity, from[key][:box], to[key][:box])
        end
        Geometry.stamp_signature(entity) if !regenerated?(key) && !edited_before[key]
        entity.set_attribute(DICT, 'params_json', to[key][:params]) if to[key][:params]
      end
      handles.each { |entity, specs| specs.each { |spec| Operations.add_handle(entity, spec) } }
      door_states.each do |door, angle, side, type|
        Operations.apply_opening_metadata(door, type)
        Operations.set_door_angle(door, side, angle) if angle > 0.5
      end
      run(root, settings, dims, parts.values, share: false)
    end

    # Tủ không khớp công thức (thường là tủ tạo bằng bản cũ): dựng lại như trước, giữ tấm chỉnh tay, và báo lại.
    def rebuild_as_before(root, settings, dims)
      keep = hand_edited(root).map { |item| item[:entity] }
      warnings = run(root, settings, dims, keep)
      warnings << 'Tủ không khớp công thức (có thể tạo bằng bản cũ): đã dựng lại như trước, hãy kiểm tra ván.'
    end

    def same_box?(a, b)
      a.zip(b).all? { |x, y| (x - y).abs < Interior::EPS }
    end

    # Thay toàn bộ nội dung của một cấu kiện bằng nội dung đã dựng trong bản thử (đúng mm, không co theo tỷ lệ).
    # Giữ đối tượng cấu kiện và thuộc tính của nó; vật liệu đã sơn được đặt lại theo đường dẫn tên.
    def replace_contents(target, source)
      materials = material_paths(contents_of(target))
      Operations.handle_groups(source).each(&:erase!)
      contents_of(source).to_a.each { |e| e.erase! if e.valid? && e.respond_to?(:name) && e.name == Operations::MARKER_NAME }
      contents_of(target).to_a.each { |e| e.erase! if e.valid? }
      contents_of(target).add_instance(source.definition, Geom::Transformation.new).explode
      restore_material_paths(contents_of(target), materials)
    end

    # Vật liệu của các nhóm con, theo đường dẫn tên (tên + số thứ tự trong nhóm cha), để đặt lại sau khi thay nội dung.
    def material_paths(entities, prefix = '')
      counts = Hash.new(0)
      entities.to_a.each_with_object({}) do |e, out|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        counts[e.name] += 1
        path = "#{prefix}#{e.name}##{counts[e.name]}/"
        out[path] = e.material if e.material
        out.merge!(material_paths(contents_of(e), path))
      end
    end

    def restore_material_paths(entities, paths, prefix = '')
      counts = Hash.new(0)
      entities.to_a.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        counts[e.name] += 1
        path = "#{prefix}#{e.name}##{counts[e.name]}/"
        e.material = paths[path] if paths[path]
        restore_material_paths(contents_of(e), paths, path)
      end
    end

    # Vật liệu của từng ván vỏ tủ: vật liệu nhóm + vật liệu từng mặt (khớp theo hướng pháp tuyến của mặt).
    def carcass_looks(shell, kept_roles)
      Interior.containers(shell).each_with_object({}) do |entity, out|
        role = Interior.role_of(entity)
        next unless Interior::CARCASS_ROLES.include?(role) && !kept_roles.include?(role)
        faces = contents_of(entity).grep(Sketchup::Face).map { |face| [normal_key(face), face.material, face.back_material] }
        out[role] = { material: entity.material, faces: faces }
      end
    end

    def apply_carcass_looks(shell, looks)
      Interior.containers(shell).each do |entity|
        look = looks[Interior.role_of(entity)]
        next unless look
        entity.material = look[:material] if look[:material]
        pending = look[:faces].group_by(&:first)
        contents_of(entity).grep(Sketchup::Face).each do |face|
          match = pending[normal_key(face)]&.shift
          next unless match
          face.material = match[1] if match[1]
          face.back_material = match[2] if match[2]
        end
        reset_textures(entity)
      end
    end

    def normal_key(face)
      face.normal.to_a.map { |v| v.round(4) }
    end

    # Co giãn một tấm vỏ tủ / đợt / vách tại chỗ: đưa hộp cũ về hộp mới, giữ nguyên các chi tiết bên trong.
    def stretch_part!(entity, old_box, new_box)
      placement = entity.transformation
      transform = placement.inverse * stretch_transform(old_box, new_box) * placement
      contents = contents_of(entity)
      contents.transform_entities(transform, contents.to_a)
      reset_textures(entity)
    end

    # Phép biến đổi đưa hộp cũ về hộp mới: co theo từng trục (trục có kích thước 0 giữ nguyên), rồi dời tới vị trí mới.
    def stretch_transform(old_box, new_box)
      factors = (0..2).map do |i|
        old_size = old_box[i + 3] - old_box[i]
        old_size > Interior::EPS ? (new_box[i + 3] - new_box[i]) / old_size : 1.0
      end
      Geom::Transformation.translation(new_box[0, 3]) * Geom::Transformation.scaling(*factors) *
        Geom::Transformation.translation(old_box[0, 3].map(&:-@))
    end

    def contents_of(entity)
      entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
    end

    # Sau khi co giãn, đặt lại vân để mỗi viên vân giữ đúng kích thước thật (không bị kéo theo tấm).
    def reset_textures(entity)
      contents_of(entity).grep(Sketchup::Face).each do |face|
        front = face.material || entity.material
        reset_face_texture(face, front, true) if front && front.texture
        back = face.back_material
        reset_face_texture(face, back, false) if back && back.texture
      end
    end

    # position_material nhận các CẶP (điểm trên mặt, điểm tương ứng trên ảnh). Ảnh đặt theo kích thước thật
    # (texture.width/height, inch). Tọa độ ảnh dùng ảnh ĐÃ CHUẨN HÓA: (1, 0) là cạnh rộng của cả ảnh, (0, 1) là cạnh
    # cao. Dùng pixel ở đây làm vân lặp dày gấp hàng trăm lần (vân nhỏ li ti trên mặt).
    def reset_face_texture(face, material, front)
      texture = material.texture
      return if texture.width <= 0 || texture.height <= 0
      origin = face.vertices[0].position
      u = (face.vertices[1].position - origin).normalize
      v = face.normal.cross(u).normalize
      face.position_material(material, [
        origin, Geom::Point3d.new(0, 0, 0),
        origin.offset(u, texture.width), Geom::Point3d.new(1, 0, 0),
        origin.offset(v, texture.height), Geom::Point3d.new(0, 1, 0)
      ], front)
    end

    # Xóa bản thử và cả định nghĩa riêng của nó (không thì còn một component mồ côi trong danh sách Components).
    # Chỉ gọi xóa định nghĩa khi API DefinitionList#remove có sẵn và định nghĩa không còn bản thể nào.
    def discard_probe(probe)
      definition = probe.definition
      probe.erase!
      definitions = Sketchup.active_model.respond_to?(:definitions) ? Sketchup.active_model.definitions : nil
      definitions.remove(definition) if definitions && definitions.respond_to?(:remove) && definition.count_instances.zero?
    end

    # Bản sao thử của tủ (cùng vị trí, cùng thuộc tính, định nghĩa riêng) để dựng công thức mà không đụng tủ thật.
    def probe_copy(root)
      host = root.parent
      raise 'Không tạo được bản thử của tủ.' unless host.respond_to?(:entities)
      probe = host.entities.add_instance(root.definition, root.transformation)
      probe.make_unique
      ModelData.restore(probe, ModelData.snapshot(root))
      probe.name = root.name
      probe
    end

    # Tủ copy bằng Ctrl+Move dùng chung định nghĩa với bản gốc: tách riêng tủ và các nhóm con trực tiếp
    # (thùng tủ, Cánh, Ngăn kéo, Chân & phào) trước khi sửa, để không sửa lây sang các bản copy khác.
    def make_unique_tree(root)
      root.make_unique if root.respond_to?(:make_unique)
      root.definition.entities.to_a.each do |child|
        next unless child.is_a?(Sketchup::Group) && child.valid?
        child.make_unique if child.respond_to?(:make_unique)
      end
    end

    def replay(root, shell, op, skip)
      case op['type']
      when 'panel' then place_panels(root, shell, op, skip)
      when 'drawer'
        settings = Schema.merge_settings(op['settings'] || {})
        local = op['anchor'] ? point_of(shell, op['anchor']) : nil
        Operations.build_drawers(root, settings, local, op['op'])
      when 'bay'
        settings = Schema.merge_settings(op['settings'] || {})
        local = op['anchor'] ? point_of(shell, op['anchor']) : nil
        DrawerBay.place(root, shell, settings, local, op['op'])
      when 'blocker', 'wardrobe'
        settings = Schema.merge_settings(op['settings'] || {})
        locals = (op['points'] || []).map { |anchor| point_of(shell, anchor) }
        if op['type'] == 'blocker'
          Operations.place_blocker(root, shell, settings, locals.first, op['op'])
        else
          Operations.place_wardrobe(root, shell, settings, locals, op['op'])
        end
      end
    end

    # Cánh: dựng lại từ bố cục đã lưu (tỷ lệ vùng), giữ tay nắm + góc mở (DoorTool tự lo).
    def rebuild_doors(root)
      return if root.get_attribute(DICT, 'door_layout_json').to_s.empty?
      return if Operations.doors_of(root).empty?
      tool = Tools::DoorTool.new({})
      tool.load_cabinet(root)
      tool.build_doors
    end

    def capture_drawer_handles(root, kept_keys = [])
      box = root.definition.entities.to_a.find { |e| e.is_a?(Sketchup::Group) && e.name == Operations::DRAWER_CONTAINER }
      return {} unless box
      box.definition.entities.to_a.each_with_object({}) do |front, out|
        next unless front.respond_to?(:name) && front.name == 'Mặt Ngăn Kéo'
        next if kept_keys.include?(stretch_key(front))
        op = front.get_attribute(DICT, 'op')
        next unless op
        specs = Operations.handle_specs(front)
        out[[op, front.get_attribute(DICT, 'op_index')]] = specs unless specs.empty?
      end
    end

    def restore_drawer_handles(root, saved)
      return if saved.empty?
      box = root.definition.entities.to_a.find { |e| e.is_a?(Sketchup::Group) && e.name == Operations::DRAWER_CONTAINER }
      return unless box
      box.definition.entities.to_a.each do |front|
        next unless front.respond_to?(:name) && front.name == 'Mặt Ngăn Kéo'
        specs = saved[[front.get_attribute(DICT, 'op'), front.get_attribute(DICT, 'op_index')]]
        (specs || []).each { |spec| Operations.add_handle(front, spec) }
      end
    end
  end
end
