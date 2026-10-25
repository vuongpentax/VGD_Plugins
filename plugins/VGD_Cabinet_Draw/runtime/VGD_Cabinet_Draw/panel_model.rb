# Lõi tính toán thùng tủ. KHÔNG gọi SketchUp API, đơn vị mm.
# Hệ trục cục bộ của tủ: X = chiều rộng (trái -> phải nhìn từ mặt trước),
# Y = chiều sâu (mặt trước -> mặt sau), Z = chiều cao. Gốc (0,0,0) là góc dưới-trước-trái.
# Mỗi tấm là một đa giác phẳng cộng một hướng đẩy (axis, distance); lớp dựng hình chỉ việc đẩy khối.
module VGD_Cabinet_Draw
  module PanelModel
    extend self

    ROLES = %w[side_left side_right bottom top back].freeze
    NAMES = {
      'side_left' => 'Hông Trái', 'side_right' => 'Hông Phải',
      'bottom' => 'Đáy', 'top' => 'Nóc', 'back' => 'Hậu',
      'toe_kick' => 'Ván chân', 'toe_kick_back' => 'Ván chân sau', 'cornice' => 'Phào trần',
      'rail_front' => 'Giằng trước', 'rail_back' => 'Giằng sau', 'hang_rail' => 'Xà treo'
    }.freeze
    # Loại tủ: thường / bếp dưới (2 thanh giằng thay nóc, mặt đá đặt lên) / bếp trên (xà treo sau nóc) /
    # thùng tủ lạnh (hông chạm đất, không đáy + không hậu phần tủ lạnh, hộc trên có đáy/nóc/hậu).
    CABINET_TYPES = %w[standard base wall fridge].freeze
    TYPE_NAMES = { 'standard' => 'Tủ thường', 'base' => 'Tủ bếp dưới', 'wall' => 'Tủ bếp trên', 'fridge' => 'Thùng tủ lạnh' }.freeze
    BACK_MODES = %w[groove overlay none].freeze
    MAX_DIMENSION = 10_000.0
    MIN_OPENING = 10.0 # khoang trống tối thiểu (mm)
    MIN_WALL = 3.0     # phần ván còn lại tối thiểu sau khi khoét rãnh (mm)

    Part = Struct.new(:role, :name, :points, :axis, :distance, :thickness, :bounds, :volume, :grooved)
    # parts = thân tủ (đã nâng lên theo chân cao); trim = ván chân và phào trần (nhóm riêng).
    # reference = hộp tham chiếu tủ lạnh [x0,y0,z0,x1,y1,z1] (chỉ để nhìn, không phải tấm ván).
    Result = Struct.new(:parts, :opening, :resolved, :width, :depth, :height, :trim, :reference)

    # Bộ tấm mặc định. thickness = nil nghĩa là dùng dày ván chung (hậu dùng dày hậu chung).
    def default_panels
      {
        'side_left' => { 'enabled' => true, 'thickness' => nil, 'front_offset' => 0.0 },
        'side_right' => { 'enabled' => true, 'thickness' => nil, 'front_offset' => 0.0 },
        'bottom' => { 'enabled' => true, 'thickness' => nil, 'front_offset' => 0.0, 'cover_left' => false, 'cover_right' => false },
        'top' => { 'enabled' => true, 'thickness' => nil, 'front_offset' => 0.0, 'cover_left' => false, 'cover_right' => false },
        'back' => { 'enabled' => true, 'thickness' => nil }
      }
    end

    # Kiểm tra và chuẩn hóa toàn bộ thông số thùng tủ. Ném ArgumentError (tiếng Việt) nếu sai.
    def resolve(settings)
      s = stringify(settings || {})
      board = number(s['board_thickness'], 17.5, 'Dày ván', MIN_WALL, 100.0)
      back_t = number(s['back_thickness'], 6.0, 'Dày hậu', 1.0, 100.0)
      mode = (s['back_mode'] || 'groove').to_s
      raise ArgumentError, "Kiểu hậu không hợp lệ: #{mode}." unless BACK_MODES.include?(mode)
      groove = number(s['back_groove_depth'], 8.75, 'Độ ngậm rãnh hậu', 0.0, 100.0)
      lip = number(s['back_lip'], 10.0, 'Lớp ván che sau rãnh', 0.0, 100.0)
      given = s['panels'].is_a?(Hash) ? s['panels'] : {}
      # Phần tấm LÙI vào theo dày cánh (cánh lọt/phủ): cộng vào độ lùi mặt trước của tấm, không đổi thông số người dùng nhập.
      recess = s['door_recess'].is_a?(Hash) ? stringify(s['door_recess']) : {}
      recess_of = ->(key) { number(recess[key], 0.0, "Độ lùi theo cánh (#{key})", 0.0, 200.0) }
      panels = {}
      ROLES.each do |role|
        raw = stringify(given[role] || {})
        base = default_panels[role]
        label = NAMES[role]
        entry = {}
        entry[:enabled] = raw['enabled'].nil? ? base['enabled'] : truthy(raw['enabled'])
        default_t = role == 'back' ? back_t : board
        low = role == 'back' ? 1.0 : MIN_WALL
        entry[:t] = number(raw['thickness'], default_t, "Dày #{label}", low, 100.0)
        entry[:front] = number(raw['front_offset'], 0.0, "Lùi mặt trước của #{label}", 0.0, 1000.0) + (role == 'back' ? 0.0 : recess_of.call(role))
        entry[:cover_l] = truthy(raw['cover_left'])
        entry[:cover_r] = truthy(raw['cover_right'])
        panels[role] = entry
      end
      leg = number(s['leg_height'], 0.0, 'Chân cao', 0.0, 1000.0)
      strip = number(s['ceiling_strip_height'], 0.0, 'Khe tách trần (phào)', 0.0, 1000.0)
      toe_t = number(s['toe_kick_thickness'], board, 'Dày ván chân', MIN_WALL, 100.0)
      toe_set = number(s['toe_kick_setback'], 0.0, 'Lùi ván chân', 0.0, 1000.0) + recess_of.call('toe')
      cor_t = number(s['cornice_thickness'], board, 'Dày phào trần', MIN_WALL, 100.0)
      cor_set = number(s['cornice_setback'], 0.0, 'Lùi phào trần', 0.0, 1000.0) + recess_of.call('cornice')
      toe_on = s['toe_kick_enabled'].nil? ? true : truthy(s['toe_kick_enabled'])
      toe_back = s['toe_kick_back'].nil? ? true : truthy(s['toe_kick_back'])
      cor_on = s['cornice_enabled'].nil? ? true : truthy(s['cornice_enabled'])
      type = (s['cabinet_type'] || 'standard').to_s
      raise ArgumentError, "Loại tủ không hợp lệ: #{type}." unless CABINET_TYPES.include?(type)
      top_mode = (s['top_mode'] || 'auto').to_s
      top_mode = type == 'base' ? 'rails' : 'full' unless %w[full rails].include?(top_mode)
      fridge = nil
      if type == 'fridge'
        fridge = {
          w: number(s['fridge_width'], 700.0, 'Rộng tủ lạnh', 300.0, 2000.0),
          h: number(s['fridge_height'], 1800.0, 'Cao tủ lạnh', 400.0, 2600.0),
          d: number(s['fridge_depth'], 650.0, 'Sâu tủ lạnh', 300.0, 1200.0),
          side: number(s['fridge_side_gap'], 20.0, 'Khe hở hai bên tủ lạnh', 0.0, 200.0),
          top: number(s['fridge_top_gap'], 80.0, 'Khe hở phía trên tủ lạnh', 0.0, 500.0),
          back: number(s['fridge_back_gap'], 50.0, 'Khe hở phía sau tủ lạnh', 0.0, 300.0)
        }
      end
      { board: board, type: type, top_mode: top_mode, fridge: fridge,
        rail_w: number(s['top_rail_width'], 100.0, 'Bản giằng nóc', 30.0, 500.0),
        hang: type == 'wall' && (s['hang_rail'].nil? ? true : truthy(s['hang_rail'])),
        hang_h: number(s['hang_rail_height'], 100.0, 'Bản xà treo', 30.0, 500.0), back_t: back_t, mode: mode, groove: groove, lip: lip, panels: panels,
        floor: truthy(s['sides_to_floor']), ceil: truthy(s['sides_to_ceiling']),
        leg: leg, strip: strip, toe_on: toe_on, toe_back: toe_back, toe_t: toe_t, toe_set: toe_set,
        cor_on: cor_on, cor_t: cor_t, cor_set: cor_set }
    end

    # Tính toàn bộ tấm của thùng tủ rộng x sâu x cao (mm).
    def compute(width, depth, height, settings = {})
      w = dimension(width, 'Rộng')
      d = dimension(depth, 'Sâu')
      total_h = dimension(height, 'Cao')
      c = resolve(settings)
      fridge = c[:fridge]
      if fridge
        # Thùng tủ lạnh: tủ lạnh đặt thẳng trên sàn, không chân, không ván chân; hông xuống sàn.
        c[:leg] = 0.0
        c[:toe_on] = false
        c[:floor] = true
        c[:panels]['bottom'][:cover_l] = c[:panels]['bottom'][:cover_r] = false
      end
      leg = c[:leg]
      strip = c[:strip]
      h = total_h - leg - strip   # chiều cao thân tủ
      if h < MIN_OPENING + MIN_WALL * 2
        raise ArgumentError, 'Chiều cao box quá thấp so với chân cao và khe tách trần.'
      end
      p = c[:panels]
      sl = p['side_left']
      sr = p['side_right']
      bo = p['bottom']
      tp = p['top']
      bk = p['back']

      rails = c[:top_mode] == 'rails' && tp[:enabled]
      top_on = tp[:enabled] && !rails
      tl = sl[:enabled] ? sl[:t] : 0.0
      tr = sr[:enabled] ? sr[:t] : 0.0
      tb = bo[:enabled] ? bo[:t] : 0.0
      tt = top_on ? tp[:t] : 0.0
      # Thùng tủ lạnh: đáy hộc trên nằm ở cao tủ lạnh + khe trên; phần dưới để trống cho tủ lạnh.
      zb0 = fridge ? fridge[:h] + fridge[:top] : 0.0
      ix0 = tl
      ix1 = w - tr
      iz0 = zb0 + tb
      iz1 = h - tt
      raise ArgumentError, 'Khoang trong thùng tủ quá hẹp: chiều rộng quá nhỏ so với dày hông.' if ix1 - ix0 < MIN_OPENING
      raise ArgumentError, 'Khoang trong thùng tủ quá thấp: chiều cao quá nhỏ so với dày nóc và đáy.' if !fridge && iz1 - iz0 < MIN_OPENING
      if fridge
        need_w = fridge[:w] + 2 * fridge[:side]
        raise ArgumentError, format('Thùng tủ lạnh hẹp: lòng %.0f mm < tủ lạnh %.0f + khe 2 × %.0f = %.0f mm.', ix1 - ix0, fridge[:w], fridge[:side], need_w) if ix1 - ix0 < need_w - 1e-6
        raise ArgumentError, format('Thùng tủ lạnh nông: sâu %.0f mm < tủ lạnh %.0f + khe sau %.0f mm.', d, fridge[:d], fridge[:back]) if d < fridge[:d] + fridge[:back] - 1e-6
        if iz1 - iz0 < 100.0
          raise ArgumentError, format('Không đủ chỗ cho hộc trên tủ lạnh: thân tủ cao %.0f mm, cần ≥ tủ lạnh %.0f + khe %.0f + đáy + nóc + 100 mm lòng hộc.', h, fridge[:h], fridge[:top])
        end
      end

      back_on = c[:mode] != 'none' && bk[:enabled]
      bt = bk[:t]
      overlay = back_on && c[:mode] == 'overlay'
      groove_on = back_on && c[:mode] == 'groove'
      g = c[:groove]
      yr = overlay ? d - bt : d   # mép sau của các tấm khác
      yg1 = d - c[:lip]           # thành sau của rãnh
      yg0 = yg1 - bt              # thành trước của rãnh

      fronts = %w[side_left side_right bottom top].select { |r| p[r][:enabled] }.map { |r| p[r][:front] }
      max_front = fronts.max || 0.0
      raise ArgumentError, 'Chiều sâu thùng tủ quá nhỏ so với phần lùi mặt trước và dày hậu.' if yr - max_front < MIN_OPENING
      if groove_on && yg0 - max_front < MIN_WALL
        raise ArgumentError, 'Rãnh hậu nằm quá sát mặt trước: giảm lớp che sau rãnh hoặc tăng chiều sâu.'
      end

      grooved = { 'side_left' => false, 'side_right' => false, 'bottom' => false, 'top' => false }
      if groove_on && g > 0
        grooved['side_left'] = sl[:enabled]
        grooved['side_right'] = sr[:enabled]
        # Nóc/đáy trùm hông thì rãnh chạy suốt sẽ lộ ra đầu tấm, nên không khoét rãnh cho tấm đó.
        grooved['bottom'] = bo[:enabled] && !bo[:cover_l] && !bo[:cover_r]
        grooved['top'] = top_on && !tp[:cover_l] && !tp[:cover_r]
        grooved.each do |role, on|
          next unless on
          if g > p[role][:t] - MIN_WALL
            raise ArgumentError, "Độ ngậm rãnh phải nhỏ hơn dày #{NAMES[role]} ít nhất #{MIN_WALL} mm."
          end
        end
      end

      parts = []

      # Hông chạm đất / đụng trần: kéo dài hông xuống sàn (qua phần chân) và lên trần (qua phần phào).
      # Không áp dụng cho phía có đáy/nóc trùm hông, vì hông đã tựa lên tấm đó.
      extend = lambda do |cover_key, zl, zh|
        zl -= leg if c[:floor] && !(bo[:enabled] && bo[cover_key])
        zh += strip if c[:ceil] && !(tp[:enabled] && tp[cover_key])
        [zl, zh]
      end

      side_panels = rails ? p.merge('top' => p['top'].merge(enabled: false)) : p
      if sl[:enabled]
        zl, zh = extend.call(:cover_l, *side_z(side_panels, :cover_l, h))
        pts = side_profile_left(tl, sl[:front], yr, nil)
        parts << finish('side_left', pts.map { |x, y| [x, y, zl] }, :z, zh - zl, tl, grooved['side_left'])
      end
      if sr[:enabled]
        zl, zh = extend.call(:cover_r, *side_z(side_panels, :cover_r, h))
        pts = side_profile_right(w - tr, w, sr[:front], yr, nil)
        parts << finish('side_right', pts.map { |x, y| [x, y, zl] }, :z, zh - zl, tr, grooved['side_right'])
      end
      if bo[:enabled]
        xl, xr = horizontal_x(bo, sl, sr, tl, tr, w)
        pts = bottom_profile(zb0, zb0 + tb, bo[:front], yr, nil)
        parts << finish('bottom', pts.map { |y, z| [xl, y, z] }, :x, xr - xl, tb, grooved['bottom'])
      end
      if top_on
        xl, xr = horizontal_x(tp, sl, sr, tl, tr, w)
        pts = top_profile(h - tt, h, tp[:front], yr, nil)
        parts << finish('top', pts.map { |y, z| [xl, y, z] }, :x, xr - xl, tt, grooved['top'])
      end
      if back_on
        if overlay
          x0b = 0.0
          x1b = w
          z0b = fridge ? zb0 : 0.0
          z1b = h
          yb = d - bt
        else
          x0b = ix0 - (grooved['side_left'] ? g : 0.0)
          x1b = ix1 + (grooved['side_right'] ? g : 0.0)
          z0b = iz0 - (grooved['bottom'] ? g : 0.0)
          z1b = iz1 + (grooved['top'] ? g : 0.0)
          yb = yg0
        end
        pts = [[x0b, yb, z0b], [x1b, yb, z0b], [x1b, yb, z1b], [x0b, yb, z1b]]
        parts << finish('back', pts, :y, bt, bt, false)
      end
      # Mặt trước tấm hậu (hoặc mép sau tủ nếu không có hậu): giằng sau / xà treo áp vào đây.
      back_face = back_on ? (overlay ? d - bt : yg0) : d
      rx0 = sl[:enabled] ? tl : 0.0
      rx1 = sr[:enabled] ? w - tr : w
      if rails
        # Tủ bếp dưới: giằng trước nằm ngang sát mặt trước, giằng sau đứng áp hậu (bắt vít vào tường).
        rt = tp[:t]
        rw = c[:rail_w]
        raise ArgumentError, 'Bản giằng nóc quá lớn so với chiều sâu tủ.' if rw * 2 > back_face - tp[:front]
        pts = [[rx0, tp[:front], h - rt], [rx1, tp[:front], h - rt], [rx1, tp[:front] + rw, h - rt], [rx0, tp[:front] + rw, h - rt]]
        parts << finish('rail_front', pts, :z, rt, rt, false)
        pts = [[rx0, back_face - rt, h - rw], [rx1, back_face - rt, h - rw], [rx1, back_face - rt, h], [rx0, back_face - rt, h]]
        parts << finish('rail_back', pts, :y, rt, rt, false)
      end
      if c[:hang]
        # Tủ bếp trên: xà treo đứng dưới nóc, áp mặt trước hậu (bắt ke/vít treo tường).
        ht = c[:board]
        raise ArgumentError, 'Bản xà treo quá lớn so với chiều cao tủ.' if c[:hang_h] > iz1 - iz0 - MIN_OPENING
        pts = [[ix0, back_face - ht, iz1 - c[:hang_h]], [ix1, back_face - ht, iz1 - c[:hang_h]], [ix1, back_face - ht, iz1], [ix0, back_face - ht, iz1]]
        parts << finish('hang_rail', pts, :y, ht, ht, false)
      end

      # Nâng thân tủ lên theo chân cao (hệ trục gốc là đáy box).
      if leg > 0
        parts.each do |part|
          part.points = part.points.map { |x, y, z| [x, y, z + leg] }
          part.bounds = part.bounds.each_with_index.map { |v, i| i == 2 || i == 5 ? v + leg : v }
        end
      end
      trim = []
      if leg > 0 && c[:toe_on]
        raise ArgumentError, 'Ván chân (lùi + dày) vượt quá chiều sâu thùng tủ.' if c[:toe_set] + c[:toe_t] > d - MIN_WALL
        y = c[:toe_set]
        # Hông chạm đất thì ván chân nằm giữa hai hông; ngược lại chạy suốt bề rộng tủ.
        # Phía có đáy trùm hông thì hông không xuống sàn, nên ván chân chạy ra tới mép ngoài phía đó.
        x0 = c[:floor] && sl[:enabled] && !(bo[:enabled] && bo[:cover_l]) ? tl : 0.0
        x1 = c[:floor] && sr[:enabled] && !(bo[:enabled] && bo[:cover_r]) ? w - tr : w
        pts = [[x0, y, 0.0], [x1, y, 0.0], [x1, y, leg], [x0, y, leg]]
        trim << finish('toe_kick', pts, :y, c[:toe_t], c[:toe_t], false)
        # Ván chân sau: đỡ phía sau thân tủ (bệ chân 2 thanh trước/sau), sát mặt sau tủ.
        if c[:toe_back] && d - c[:toe_t] > y + c[:toe_t] + MIN_WALL
          yb = d - c[:toe_t]
          pts = [[x0, yb, 0.0], [x1, yb, 0.0], [x1, yb, leg], [x0, yb, leg]]
          trim << finish('toe_kick_back', pts, :y, c[:toe_t], c[:toe_t], false)
        end
      end
      if strip > 0 && c[:cor_on]
        raise ArgumentError, 'Phào trần (lùi + dày) vượt quá chiều sâu thùng tủ.' if c[:cor_set] + c[:cor_t] > d - MIN_WALL
        y = c[:cor_set]
        # Hông đụng trần thì phào nằm giữa hai hông; ngược lại chạy suốt bề rộng tủ.
        x0 = c[:ceil] && sl[:enabled] ? tl : 0.0
        x1 = c[:ceil] && sr[:enabled] ? w - tr : w
        pts = [[x0, y, total_h - strip], [x1, y, total_h - strip], [x1, y, total_h], [x0, y, total_h]]
        trim << finish('cornice', pts, :y, c[:cor_t], c[:cor_t], false)
      end
      reference = nil
      if fridge
        fx0 = (w - fridge[:w]) / 2.0
        fy1 = d - fridge[:back]
        reference = [fx0, fy1 - fridge[:d], 0.0, fx0 + fridge[:w], fy1, fridge[:h]]
      end
      Result.new(parts, { x0: ix0, x1: ix1, z0: iz0 + leg, z1: iz1 + leg }, export(c).merge('body_z0_mm' => zb0 + leg), w, d, total_h, trim, reference)
    end

    # Sáu mặt của một hộp bao [x0,y0,z0,x1,y1,z1], dùng để vẽ preview.
    def box_faces(b)
      x0, y0, z0, x1, y1, z1 = b
      [
        [[x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0]],
        [[x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1]],
        [[x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1]],
        [[x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1]],
        [[x0, y0, z0], [x0, y1, z0], [x0, y1, z1], [x0, y0, z1]],
        [[x1, y0, z0], [x1, y1, z0], [x1, y1, z1], [x1, y0, z1]]
      ]
    end

    # Mặt trước của thùng tủ (mặt y = 0), dùng để tô màu "mặt trước".
    def front_face(width, height)
      [[0.0, 0.0, 0.0], [width, 0.0, 0.0], [width, 0.0, height], [0.0, 0.0, height]]
    end

    # Thông số đã chuẩn hóa dạng chuỗi/JSON, lưu vào đối tượng để dựng lại sau này.
    def export(c)
      panels = {}
      ROLES.each do |role|
        e = c[:panels][role]
        panels[role] = {
          'enabled' => e[:enabled], 'thickness' => e[:t], 'front_offset' => e[:front],
          'cover_left' => e[:cover_l], 'cover_right' => e[:cover_r]
        }
      end
      {
        'board_thickness' => c[:board], 'back_thickness' => c[:back_t], 'back_mode' => c[:mode],
        'back_groove_depth' => c[:groove], 'back_lip' => c[:lip], 'panels' => panels,
        'leg_height' => c[:leg], 'ceiling_strip_height' => c[:strip],
        'sides_to_floor' => c[:floor], 'sides_to_ceiling' => c[:ceil],
        'toe_kick_enabled' => c[:toe_on], 'toe_kick_back' => c[:toe_back], 'toe_kick_thickness' => c[:toe_t], 'toe_kick_setback' => c[:toe_set],
        'cornice_enabled' => c[:cor_on], 'cornice_thickness' => c[:cor_t], 'cornice_setback' => c[:cor_set],
        'cabinet_type' => c[:type], 'top_mode' => c[:top_mode], 'top_rail_width' => c[:rail_w],
        'hang_rail' => c[:hang], 'hang_rail_height' => c[:hang_h],
        'fridge' => c[:fridge] && c[:fridge].map { |k, v| [k.to_s, v] }.to_h
      }
    end

    # ---- Hàm phụ ----

    def side_z(panels, cover_key, h)
      bo = panels['bottom']
      tp = panels['top']
      zl = bo[:enabled] && bo[cover_key] ? bo[:t] : 0.0
      zh = tp[:enabled] && tp[cover_key] ? h - tp[:t] : h
      [zl, zh]
    end

    def horizontal_x(e, sl, sr, tl, tr, w)
      xl = e[:cover_l] || !sl[:enabled] ? 0.0 : tl
      xr = e[:cover_r] || !sr[:enabled] ? w : w - tr
      [xl, xr]
    end

    # Đa giác (x, y) của hông trái. groove = [độ sâu, y thành trước, y thành sau] hoặc nil.
    def side_profile_left(t, yf, yr, groove)
      pts = [[0.0, yf], [t, yf]]
      if groove
        g, yg0, yg1 = groove
        pts += [[t, yg0], [t - g, yg0], [t - g, yg1], [t, yg1]]
      end
      pts += [[t, yr], [0.0, yr]]
      dedupe(pts)
    end

    def side_profile_right(x0, x1, yf, yr, groove)
      pts = [[x0, yf], [x1, yf], [x1, yr], [x0, yr]]
      if groove
        g, yg0, yg1 = groove
        pts += [[x0, yg1], [x0 + g, yg1], [x0 + g, yg0], [x0, yg0]]
      end
      dedupe(pts)
    end

    # Đa giác (y, z) của đáy: rãnh khoét xuống từ mặt trên.
    def bottom_profile(zl, zh, yf, yr, groove)
      pts = [[yf, zl], [yr, zl], [yr, zh]]
      if groove
        g, yg0, yg1 = groove
        pts += [[yg1, zh], [yg1, zh - g], [yg0, zh - g], [yg0, zh]]
      end
      pts << [yf, zh]
      dedupe(pts)
    end

    # Đa giác (y, z) của nóc: rãnh khoét lên từ mặt dưới.
    def top_profile(zl, zh, yf, yr, groove)
      pts = [[yf, zl]]
      if groove
        g, yg0, yg1 = groove
        pts += [[yg0, zl], [yg0, zl + g], [yg1, zl + g], [yg1, zl]]
      end
      pts += [[yr, zl], [yr, zh], [yf, zh]]
      dedupe(pts)
    end

    # Bỏ điểm trùng liên tiếp (xảy ra khi lớp che sau rãnh bằng 0).
    def dedupe(pts)
      out = []
      pts.each { |pt| out << pt unless out.last && same_point?(out.last, pt) }
      out.pop if out.length > 1 && same_point?(out.first, out.last)
      out
    end

    def same_point?(a, b)
      a.each_index.all? { |i| (a[i] - b[i]).abs < 1e-9 }
    end

    def finish(role, points, axis, distance, thickness, grooved)
      raise ArgumentError, "Tấm #{NAMES[role]} có kích thước không hợp lệ." unless distance > 1e-6
      idx = { x: 0, y: 1, z: 2 }[axis]
      mins = (0..2).map { |i| points.map { |pt| pt[i] }.min }
      maxs = (0..2).map { |i| points.map { |pt| pt[i] }.max }
      maxs[idx] = mins[idx] + distance
      other = [0, 1, 2] - [idx]
      area = polygon_area(points.map { |pt| [pt[other[0]], pt[other[1]]] })
      Part.new(role, NAMES[role], points, axis, distance, thickness, mins + maxs, area * distance, grooved)
    end

    def polygon_area(pts)
      sum = 0.0
      pts.each_index do |i|
        a = pts[i]
        b = pts[(i + 1) % pts.length]
        sum += a[0] * b[1] - b[0] * a[1]
      end
      sum.abs / 2.0
    end

    def dimension(value, label)
      n = begin
        Float(value.to_s)
      rescue ArgumentError, TypeError
        raise ArgumentError, "#{label} phải là một số."
      end
      unless n > 0 && n <= MAX_DIMENSION
        raise ArgumentError, "#{label} phải lớn hơn 0 và không vượt quá #{MAX_DIMENSION.to_i} mm."
      end
      n
    end

    # Số trong khoảng [low, high]; nil hoặc chuỗi rỗng nghĩa là dùng mặc định.
    def number(value, default, label, low, high)
      return default.to_f if value.nil? || value.to_s.strip.empty?
      n = begin
        Float(value.to_s)
      rescue ArgumentError, TypeError
        raise ArgumentError, "#{label} phải là một số."
      end
      raise ArgumentError, "#{label} phải nằm trong khoảng #{low} đến #{high} mm." unless n.finite? && n >= low && n <= high
      n
    end

    def truthy(value)
      value == true || %w[true 1 yes on].include?(value.to_s.strip.downcase)
    end

    def stringify(hash)
      hash.each_with_object({}) { |(k, v), out| out[k.to_s] = v }
    end
  end
end
