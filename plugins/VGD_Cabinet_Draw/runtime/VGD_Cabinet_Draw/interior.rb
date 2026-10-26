module VGD_Cabinet_Draw
  # Lòng tủ và các ô (khoang) bên trong, đo từ CÁC TẤM THẬT của tủ (hông, nóc, đáy, hậu, đợt, vách),
  # không đoán theo setting. Mọi công cụ (đợt/vách, cánh lọt, ngăn kéo, xà chặn, hộc tủ áo) dùng chung.
  # Tọa độ: hệ thùng tủ (đơn vị SketchUp), X trái→phải, Y trước→sau, Z dưới→trên.
  module Interior
    extend self

    CARCASS_ROLES = %w[side_left side_right top bottom back rail_front rail_back rail_front_2 rail_front_bottom rail_back_bottom rail_front_bottom_2 hang_rail].freeze
    # Tấm đứng sát hậu (giằng sau tủ dưới, xà treo tủ trên): ô nào trùm chiều cao của chúng thì sâu tới mặt trước tấm đó.
    DEPTH_LIMITERS = %w[rail_back rail_back_bottom hang_rail].freeze
    EPS = 0.01 / 25.4 # 0.01 mm

    # kind: :outer (tấm vỏ tủ: hông/nóc/đáy), :inner (đợt/vách bên trong), :open (không có tấm)
    Side = Struct.new(:kind, :t)

    Cell = Struct.new(:x0, :x1, :z0, :z1, :y0, :y1, :left, :right, :bottom, :top) do
      def width; x1 - x0; end
      def height; z1 - z0; end
      def depth; y1 - y0; end
    end

    def role_of(entity)
      return nil unless entity.respond_to?(:get_attribute) && entity.valid?
      return nil unless entity.get_attribute(Schema::DICTIONARY, 'kind') == 'part'
      ModelData.params(entity)['role']
    end

    def box_of(entity)
      b = entity.bounds
      [b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z]
    end

    def containers(shell)
      shell.definition.entities.to_a.select { |e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.valid? }
    end

    # Các tấm vỏ tủ: { role => [x0,y0,z0,x1,y1,z1] }.
    def carcass(shell)
      out = {}
      containers(shell).each do |entity|
        role = role_of(entity)
        out[role] ||= box_of(entity) if CARCASS_ROLES.include?(role)
      end
      out
    end

    # Đợt (ngang) và vách (đứng) đã có trong tủ. Bản cũ chưa gắn vai trò thì nhận theo tên "Đợt n" / "Vách n".
    def members(shell)
      shelves = []
      partitions = []
      containers(shell).each do |entity|
        role = role_of(entity)
        name = entity.name.to_s
        if role == 'shelf' || (role.nil? && name =~ /\AĐợt \d+\z/)
          shelves << box_of(entity)
        elsif role == 'partition' || (role.nil? && name =~ /\AVách \d+\z/)
          partitions << box_of(entity)
        end
      end
      { shelves: shelves, partitions: partitions }
    end

    # Lòng tủ toàn bộ: giữa hai hông, giữa đáy và nóc, từ mặt trước thân tủ tới mặt trước tấm hậu.
    def inner(shell)
      body = Geometry.body_bounds(shell)
      parts = carcass(shell)
      sl = parts['side_left']
      sr = parts['side_right']
      bo = parts['bottom'] || stand_in(parts, 'rail_front_bottom', 'rail_front_bottom_2') # tủ trên tủ quá khổ (xà trên): giằng trước thay đáy
      tp = parts['top'] || stand_in(parts, 'rail_front', 'rail_front_2') # tủ bếp dưới: giằng trước thay nóc
      bk = parts['back']
      left = sl ? Side.new(:outer, sl[3] - sl[0]) : Side.new(:open, 0.0)
      right = sr ? Side.new(:outer, sr[3] - sr[0]) : Side.new(:open, 0.0)
      bottom = bo ? Side.new(:outer, bo[5] - bo[2]) : Side.new(:open, 0.0)
      top = tp ? Side.new(:outer, tp[5] - tp[2]) : Side.new(:open, 0.0)
      c = Cell.new(sl ? sl[3] : body.min.x, sr ? sr[0] : body.max.x,
                   bo ? bo[5] : body.min.z, tp ? tp[2] : body.max.z,
                   body.min.y, bk ? bk[1] : body.max.y,
                   left, right, bottom, top)
      limit_depth(c, parts)
    end

    # Hộp bao của xà thay nóc/đáy (xà kép gồm hai tấm rời): hợp của các tấm có mặt. nil nếu không có tấm nào.
    def stand_in(parts, *roles)
      boxes = roles.map { |role| parts[role] }.compact
      return nil if boxes.empty?
      [boxes.map { |b| b[0] }.min, boxes.map { |b| b[1] }.min, boxes.map { |b| b[2] }.min,
       boxes.map { |b| b[3] }.max, boxes.map { |b| b[4] }.max, boxes.map { |b| b[5] }.max]
    end

    # Mặt sau dùng được cho một tấm/khối nằm trong khoảng cao z0..z1: mặt trước hậu, trừ khi giằng sau /
    # xà treo nằm cùng khoảng cao thì dừng ở mặt trước của chúng.
    def back_limit(shell, z0, z1)
      parts = carcass(shell)
      y = parts['back'] ? parts['back'][1] : Geometry.body_bounds(shell).max.y
      DEPTH_LIMITERS.each do |role|
        b = parts[role]
        y = [y, b[1]].min if b && b[5] > z0 + EPS && b[2] < z1 - EPS
      end
      y
    end

    # Mặt sau trong cùng của lòng tủ (mặt trước tấm hậu), không trừ xà.
    def full_depth(shell)
      bk = carcass(shell)['back']
      bk ? bk[1] : Geometry.body_bounds(shell).max.y
    end

    # Các dải cao xà (giằng sau / xà treo) chiếm ở mặt sau, trong khoảng z0..z1:
    # [[y mặt trước xà, z dưới của dải, z trên của dải], ...] theo thứ tự từ dưới lên.
    def back_notches(shell, z0, z1)
      parts = carcass(shell)
      DEPTH_LIMITERS.filter_map do |role|
        b = parts[role]
        next unless b && b[5] > z0 + EPS && b[2] < z1 - EPS
        [b[1], [b[2], z0].max, [b[5], z1].min]
      end.sort_by { |_y, za, _zb| za }
    end

    def limit_depth(c, parts)
      DEPTH_LIMITERS.each do |role|
        b = parts[role]
        next unless b && b[5] > c.z0 + EPS && b[2] < c.z1 - EPS
        c.y1 = [c.y1, b[1]].min
      end
      c
    end

    # Ô (khoang) chứa điểm (x, z) theo các đợt/vách đã có. Điểm nằm ngay trong một tấm thì tấm đó không tính.
    def cell_at(shell, x, z)
      c = inner(shell)
      m = members(shell)
      m[:partitions].each do |b|
        next unless b[2] <= z + EPS && b[5] >= z - EPS
        if b[3] <= x + EPS && b[3] > c.x0 + EPS
          c.x0 = b[3]
          c.left = Side.new(:inner, b[3] - b[0])
        elsif b[0] >= x - EPS && b[0] < c.x1 - EPS
          c.x1 = b[0]
          c.right = Side.new(:inner, b[3] - b[0])
        end
      end
      m[:shelves].each do |b|
        next unless b[0] <= x + EPS && b[3] >= x - EPS
        if b[5] <= z + EPS && b[5] > c.z0 + EPS
          c.z0 = b[5]
          c.bottom = Side.new(:inner, b[5] - b[2])
        elsif b[2] >= z - EPS && b[2] < c.z1 - EPS
          c.z1 = b[2]
          c.top = Side.new(:inner, b[5] - b[2])
        end
      end
      # Ô không trùm chiều cao giằng sau / xà treo thì sâu tới mặt trước hậu.
      bk = carcass(shell)['back']
      c.y1 = bk ? bk[1] : Geometry.body_bounds(shell).max.y
      limit_depth(c, carcass(shell))
    end

    # Kiểu cánh của tủ (đã lưu khi tạo cánh); chưa có cánh thì nil.
    def door_fit(root)
      data = (JSON.parse(root.get_attribute(Schema::DICTIONARY, 'door_layout_json', '{}')) rescue {})
      fit = data.is_a?(Hash) && data['settings'].is_a?(Hash) ? data['settings']['door_fit'] : nil
      %w[phu lot thong_thuy].include?(fit) ? fit : nil
    end

    # Độ dày cánh đã dùng khi tạo cánh (mm), nil nếu chưa có.
    def door_thickness_mm(root)
      data = (JSON.parse(root.get_attribute(Schema::DICTIONARY, 'door_layout_json', '{}')) rescue {})
      value = data.is_a?(Hash) && data['settings'].is_a?(Hash) ? data['settings']['board_thickness'] : nil
      value && value.to_f > 0 ? value.to_f : nil
    end

    # Phần mặt trước (cánh/mặt hộc) che một cạnh của ô, theo kiểu:
    #   phủ: cạnh vỏ tủ che hết dày tấm trừ khe mép; cạnh đợt/vách bên trong che nửa dày tấm trừ nửa khe giữa.
    #   lọt: lùi vào trong ô một khe lọt.   thông thủy: khít ô.
    # Trả về số dương = mặt trước vượt ra ngoài ô, số âm = lùi vào trong ô.
    def front_cover(side, fit, edge_gap, mid_gap, inset_gap)
      case fit
      when 'phu'
        case side.kind
        when :outer then side.t - edge_gap
        when :inner then side.t / 2.0 - mid_gap / 2.0
        else -edge_gap
        end
      when 'lot' then -inset_gap
      else 0.0
      end
    end
  end

  # Quy tắc lùi thùng tủ theo kiểu cánh, để kích thước phủ bì (cả cánh) luôn bằng box ban đầu.
  #   Mặt ngoài của cánh nằm đúng mặt trước box; cánh dày t nên phần thùng tủ nằm sau cánh phải lùi t.
  #   phủ: nóc + đáy lùi t; hông lùi t ở phía được cánh phủ (hông còn lại giữ nguyên).
  #   lọt: cánh nằm giữa hai hông (hông không lùi), cao phủ nóc + đáy nên nóc, đáy, ván chân, phào lùi t.
  module DoorFit
    extend self

    KEYS = %w[side_left side_right top bottom toe cornice].freeze

    def recess_for(fit, cover_left, cover_right, thickness_mm)
      t = thickness_mm.to_f
      out = KEYS.map { |key| [key, 0.0] }.to_h
      out['top'] = out['bottom'] = t
      if fit == 'lot'
        out['toe'] = out['cornice'] = t
      else
        out['side_left'] = t if cover_left
        out['side_right'] = t if cover_right
      end
      out
    end

    def same?(a, b)
      return false unless a.is_a?(Hash) && b.is_a?(Hash)
      KEYS.all? { |key| (a[key].to_f - b[key].to_f).abs < 1e-6 }
    end
  end
end
