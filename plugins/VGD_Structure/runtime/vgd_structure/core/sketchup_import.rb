require 'securerandom'

module VGD
  module Structure
    # NHẬN đối tượng SketchUp thường (do người dùng vẽ bằng công cụ của SketchUp, chưa phải do plugin dựng) về làm dữ liệu nguồn của Structure.
    # Logic thuần: nhận dữ liệu đã chuẩn hóa và danh sách mô tả đối tượng (đọc từ model bởi `SuScan`), trả về bản vá dữ liệu theo tầng (phần tử TỰ DO),
    # các loại mới cần thêm và các cảnh báo. Không đụng model.
    #   mô tả đối tượng: {'id' => entityID, 'kind' => column | beam | wall | slab | ceiling | door | window, 'center' => [x, y] (mm, thế giới),
    #                     'size' => [dọc trục X cục bộ, dọc trục Y cục bộ, cao] (mm), 'angle' => độ (trục X cục bộ so với X thế giới), 'z0' => đáy, 'z1' => đỉnh}
    #   kết quả: {patches: [{'level', 'set', 'remove', 'retag', 'kinds'}], types: {'types'|'beam_types'|'wall_types'|'opening_types' => [loại mới]}, adopted: [{'su_id', 'level', 'box', 'ref'}], skipped: [lý do]}
    module SketchupImport
      TOL_LEVEL = 600.0   # mm: đối tượng lệch cao độ chuẩn của tầng quá mức này thì không xếp được vào tầng nào
      TOL_SIZE = 1.0      # mm: kích thước trùng loại có sẵn khi sai khác không quá mức này
      TOL_HOST = 60.0     # mm: tâm cửa cách tim tường tối đa (ngoài nửa bề dày) mà vẫn coi là nằm trong tường
      MIN_LENGTH = 100.0  # mm: dầm, tường ngắn hơn bị bỏ
      BOX = {'column' => 'columns', 'beam' => 'beams', 'wall' => 'walls', 'slab' => 'slabs', 'ceiling' => 'ceilings', 'door' => 'openings', 'window' => 'openings'}.freeze
      PREFIX = {'column' => 'fc_', 'beam' => 'fb_', 'wall' => 'fw_', 'slab' => 'fs_', 'ceiling' => 'fk_', 'door' => 'op_', 'window' => 'op_'}.freeze
      TYPE_KEY = {'column' => 'types', 'beam' => 'beam_types', 'wall' => 'wall_types', 'door' => 'opening_types', 'window' => 'opening_types'}.freeze
      TYPE_PREFIX = {'types' => 'ct_', 'beam_types' => 'bt_', 'wall_types' => 'wt_', 'opening_types' => 'ot_'}.freeze
      TYPE_NAME_MAX = 20

      def self.plan(state, objects)
        st = JSON.parse(state.to_json)
        out = {patches: {}, types: Hash.new { |h, k| h[k] = [] }, adopted: [], skipped: []}
        objects = Array(objects)
        solids, openings = objects.partition { |o| !%w[door window].include?(o['kind']) }
        solids.each { |o| import_solid(st, o, out) }
        import_openings(st, openings, out) unless openings.empty?
        {patches: out[:patches].values, types: out[:types].to_h.reject { |_k, v| v.empty? }, adopted: out[:adopted], skipped: out[:skipped]}
      end

      def self.label(o)
        "#{{'column' => 'Cột', 'beam' => 'Dầm', 'wall' => 'Tường', 'slab' => 'Sàn', 'ceiling' => 'Trần', 'door' => 'Cửa đi', 'window' => 'Cửa sổ'}[o['kind']]} #{o['name'] || o['id']}"
      end

      # Tầng của đối tượng theo cao độ đặc trưng của loại (chân cột, chân tường, đỉnh dầm, đỉnh sàn, đáy trần). nil nếu lệch quá TOL_LEVEL.
      def self.level_for(st, o)
        levels = st['levels']
        best = levels.each_with_index.map do |l, i|
          ref = case o['kind']
                when 'column', 'wall' then [o['z0'], Levels.structure_top(l)]
                when 'beam' then levels[i + 1] && [o['z1'], Levels.structure_top(levels[i + 1])]
                when 'slab' then [o['z1'], Levels.structure_top(l)]
                when 'ceiling' then [o['z0'], l['elevation'] + l['ceiling_height']]
                end
          ref && [(ref[0] - ref[1]).abs, l]
        end.compact.min_by(&:first)
        best && best[0] <= TOL_LEVEL ? best[1] : nil
      end

      def self.patch_for(out, level)
        out[:patches][level['id']] ||= {'level' => level['id'], 'set' => {}, 'remove' => {}, 'retag' => {}, 'kinds' => []}
      end

      def self.add_pick(st, out, level, o, pick)
        kind = o['kind']
        box = BOX.fetch(kind)
        id = PREFIX.fetch(kind) + SecureRandom.hex(4)
        id = PREFIX.fetch(kind) + SecureRandom.hex(4) while level['picks'][box].key?(id)
        (patch_for(out, level)['set'][box] ||= {})[id] = pick
        level['picks'][box][id] = pick # để các bước sau (cửa tìm tường chủ) thấy ngay
        patch = patch_for(out, level)
        patch['kinds'] << box unless patch['kinds'].include?(box)
        out[:adopted] << {'su_id' => o['id'], 'level' => level['id'], 'box' => box, 'ref' => id}
        id
      end

      # Loại có sẵn trùng kích thước thì dùng, không thì thêm loại mới "NHẬN <kích thước>".
      def self.type_for(st, out, kind, dims)
        key = TYPE_KEY.fetch(kind)
        list = st[key] + out[:types][key]
        match = list.find { |t| dims.all? { |k, v| t[k].is_a?(Numeric) ? (t[k] - v).abs <= TOL_SIZE : t[k] == v } }
        return match['id'] if match
        name = "NHẬN #{dims.reject { |k, _| %w[kind sill layers].include?(k) }.values.map { |v| fmt(v) }.join('x')}"[0, TYPE_NAME_MAX]
        taken = list.map { |t| t['name'].downcase }
        name = name[0, TYPE_NAME_MAX - 1] + '*' while taken.include?(name.downcase)
        fresh = {'id' => TYPE_PREFIX.fetch(key) + SecureRandom.hex(4), 'name' => name}.merge(dims)
        fresh['t'] = dims['t'] if key == 'wall_types'
        out[:types][key] << fresh
        fresh['id']
      end

      def self.fmt(v)
        v == v.round ? v.round.to_s : v.round(1).to_s
      end

      def self.r1(v)
        v.to_f.round(1)
      end

      # Hai đầu trục của đối tượng dài (dầm, tường): trục dài là cạnh ngang lớn hơn, tim ở giữa.
      def self.axis(o)
        sx, sy = o['size']
        long_x = sx >= sy
        length = long_x ? sx : sy
        thick = long_x ? sy : sx
        ang = (o['angle'] + (long_x ? 0.0 : 90.0)) * Math::PI / 180.0
        ux = Math.cos(ang)
        uy = Math.sin(ang)
        c = o['center']
        [[[r1(c[0] - ux * length / 2.0), r1(c[1] - uy * length / 2.0)], [r1(c[0] + ux * length / 2.0), r1(c[1] + uy * length / 2.0)]], length, thick]
      end

      def self.rect_poly(o)
        sx, sy = o['size']
        ang = o['angle'] * Math::PI / 180.0
        cs = Math.cos(ang)
        sn = Math.sin(ang)
        pts = [[-sx / 2.0, -sy / 2.0], [sx / 2.0, -sy / 2.0], [sx / 2.0, sy / 2.0], [-sx / 2.0, sy / 2.0]].map { |x, y| [r1(o['center'][0] + x * cs - y * sn), r1(o['center'][1] + x * sn + y * cs)] }
        Geometry.area2(pts) < 0 ? pts.reverse : pts # ngược chiều kim đồng hồ
      end

      def self.import_solid(st, o, out)
        level = level_for(st, o)
        return out[:skipped] << "#{label(o)}: cao độ không khớp tầng nào (lệch quá #{TOL_LEVEL.to_i} mm so với cốt kết cấu của các tầng)." unless level
        case o['kind']
        when 'column'
          sx, sy = o['size']
          tid = type_for(st, out, 'column', {'w' => r1(sx), 'd' => r1(sy)})
          rot = (o['angle'] % 360.0).round(2)
          rot = rot.to_i if rot == rot.to_i
          add_pick(st, out, level, o, {'type' => tid, 'free' => {'x' => r1(o['center'][0]), 'y' => r1(o['center'][1]), 'rot' => rot}})
        when 'beam', 'wall'
          (a, b), length, thick = axis(o)
          return out[:skipped] << "#{label(o)}: dài chỉ #{r1(length)} mm, bỏ qua." if length < MIN_LENGTH
          tid = o['kind'] == 'beam' ? type_for(st, out, 'beam', {'w' => r1(thick), 'h' => r1(o['size'][2])}) : type_for(st, out, 'wall', {'t' => r1(thick), 'layers' => [{'fn' => 'structure', 't' => r1(thick), 'material' => ''}]})
          add_pick(st, out, level, o, {'type' => tid, 'free' => {'a' => a, 'b' => b}})
        else # slab, ceiling: đa giác là hình chữ nhật bao theo hướng của đối tượng
          add_pick(st, out, level, o, {'free' => {'poly' => rect_poly(o), 'holes' => []}})
          thick = o['kind'] == 'slab' ? level['slab_thickness'] : level['ceiling_thickness']
          out[:skipped] << "#{label(o)}: dày #{r1(o['size'][2])} mm khác dày #{o['kind'] == 'slab' ? 'sàn' : 'trần'} của tầng (#{r1(thick)} mm); khi dựng lại dùng dày của tầng, hình dạng được đơn giản thành hình chữ nhật." if (o['size'][2] - thick).abs > 5.0
        end
      end

      # Cửa đi, cửa sổ: tìm tường chủ (theo kế hoạch tường SAU khi đã thêm các tường vừa nhận), đặt theo vị trí dọc tường.
      def self.import_openings(st, openings, out)
        normalized = State.normalize!(JSON.parse(st.to_json))
        openings.each do |o|
          best = nil
          normalized['levels'].each do |level|
            next if level['picks']['walls'].empty?
            Checker.plan_for('walls', normalized, level['id'])[:items].each do |w|
              a, b = ModelEdit.axis_of(w)
              len = Math.hypot(b[0] - a[0], b[1] - a[1])
              next if len < 1
              ux = (b[0] - a[0]) / len
              uy = (b[1] - a[1]) / len
              dx = o['center'][0] - a[0]
              dy = o['center'][1] - a[1]
              along = dx * ux + dy * uy
              across = (-dx * uy + dy * ux).abs
              next unless along >= 0 && along <= len && across <= w[:t] / 2.0 + TOL_HOST && o['z0'] >= w[:z_bottom] - TOL_LEVEL && o['z1'] <= w[:z_top] + TOL_LEVEL
              best = [across, level['id'], w, along] if best.nil? || across < best[0]
            end
          end
          unless best
            out[:skipped] << "#{label(o)}: không nằm trong tường nào (hãy nhận tường chứa cửa trước hoặc cùng lúc)."
            next
          end
          level = Levels.find(st['levels'], best[1])
          w = best[2]
          width = [o['size'][0], o['size'][1]].max
          sill = [o['z0'] - w[:z_bottom] - level['screed'], 0.0].max
          tid = type_for(st, out, o['kind'], {'kind' => o['kind'], 'w' => r1(width), 'h' => r1(o['size'][2]), 'sill' => r1(sill)})
          add_pick(st, out, level, o, {'wall' => w[:ref], 'type' => tid, 'pos' => r1(best[3]), 'flip' => false})
        end
      end
    end
  end
end
