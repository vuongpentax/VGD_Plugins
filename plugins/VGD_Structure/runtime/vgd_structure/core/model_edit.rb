require 'securerandom'

module VGD
  module Structure
    # Sửa TRONG SketchUp thì dữ liệu cập nhật theo (P7b): từ thay đổi của một phần tử đã dựng (dời, xoay quanh trục đứng, xóa) tính ra "bản vá" dữ liệu nguồn.
    # Logic thuần: nhận dữ liệu hiện tại (đã chuẩn hóa) và mô tả thay đổi, không đụng model. Phần tử theo lưới được "mở khóa" thành phần tử tự do tại hình mới
    # (cùng cách với lệnh Mở khóa lưới trên mặt bằng); phần tử tự do được sửa tại chỗ.
    #   thay đổi: {'kind' => 'column' | 'beam' | 'wall' | 'opening' | 'slab' | 'ceiling', 'level' =>, 'ref' =>, 'from' => [x, y], 'to' => [x, y], 'dangle' => độ}
    #   bản vá: {'level', 'set' => {'columns' => {mã => lựa chọn}}, 'remove' => {'columns' => [mã]}, 'retag' => {mã cũ => mã mới}, 'kinds' => [loại cần dựng lại]}
    module ModelEdit
      BOX = {'column' => 'columns', 'beam' => 'beams', 'wall' => 'walls', 'opening' => 'openings', 'slab' => 'slabs', 'ceiling' => 'ceilings'}.freeze
      PREFIX = {'column' => 'fc_', 'beam' => 'fb_', 'wall' => 'fw_', 'slab' => 'fs_', 'ceiling' => 'fk_'}.freeze
      MOVE_EPS = 0.05          # mm: dời nhỏ hơn mức này coi như không đổi
      ANGLE_EPS = 0.01         # độ
      OPENING_OFF_WALL = 100.0 # mm: cửa bị kéo lệch khỏi tim tường quá mức này thì bỏ qua

      Error = Class.new(ArgumentError)

      def self.id_for(kind)
        PREFIX.fetch(kind) + SecureRandom.hex(4)
      end

      # Có thay đổi thật không (dời hoặc xoay đáng kể).
      def self.moved?(change)
        d = delta(change)
        d.any? { |v| v.abs > MOVE_EPS } || change['dangle'].to_f.abs > ANGLE_EPS
      end

      def self.delta(change)
        [change['to'][0] - change['from'][0], change['to'][1] - change['from'][1]]
      end

      # Phép biến đổi điểm: xoay `dangle` độ quanh điểm `from` rồi dời theo (to - from).
      def self.transform(change)
        from = change['from']
        d = delta(change)
        r = change['dangle'].to_f * Math::PI / 180.0
        cs = Math.cos(r)
        sn = Math.sin(r)
        lambda do |p|
          x = p[0] - from[0]
          y = p[1] - from[1]
          [(from[0] + x * cs - y * sn + d[0]).round(1), (from[1] + x * sn + y * cs + d[1]).round(1)]
        end
      end

      # Mục kế hoạch của phần tử; nil nếu không còn trong kế hoạch (dữ liệu đã đổi / phần tử bị bỏ qua).
      def self.item_of(state, change)
        plural = BOX.fetch(change['kind'])
        Checker.plan_for(plural, state, change['level'])[:items].find { |i| i[:ref] == change['ref'] }
      rescue ArgumentError
        nil
      end

      def self.level_of(state, id)
        Levels.find(state['levels'], id)
      end

      # ---- Xóa ----
      def self.erase(state, change)
        level = level_of(state, change['level']) or return {skip: 'tầng không còn'}
        box = BOX.fetch(change['kind'])
        return {skip: 'phần tử không còn trong dữ liệu'} unless level['picks'][box].key?(change['ref'])
        patch = {'level' => level['id'], 'set' => {}, 'remove' => {box => [change['ref']]}, 'retag' => {}, 'kinds' => [box]}
        if change['kind'] == 'wall' # cửa trên tường bị xóa không còn chỗ đứng
          gone = level['picks']['openings'].select { |_id, e| e['wall'] == change['ref'] }.keys
          unless gone.empty?
            patch['remove']['openings'] = gone
            patch['kinds'] << 'openings'
          end
        end
        patch
      end

      # ---- Dời / xoay ----
      def self.move(state, change)
        return {skip: 'không đổi'} unless moved?(change)
        level = level_of(state, change['level']) or return {skip: 'tầng không còn'}
        box = BOX.fetch(change['kind'])
        pick = level['picks'][box][change['ref']] or return {skip: 'phần tử không còn trong dữ liệu'}
        item = item_of(state, change) or return {skip: 'phần tử không có trong kế hoạch hiện tại'}
        fn = transform(change)
        case change['kind']
        when 'column' then move_column(level, pick, item, change, fn)
        when 'beam', 'wall' then move_linear(level, pick, item, change, fn)
        when 'opening' then move_opening(level, pick, item, change)
        else move_plate(level, pick, item, change, fn)
        end
      end

      # Phần tử theo lưới thành phần tử tự do (mã mới, cùng loại và cờ nối góc); đã tự do thì giữ mã.
      def self.replace(level, change, pick, free)
        kind = change['kind']
        box = BOX.fetch(kind)
        entry = {'free' => free}
        entry['type'] = pick['type'] if pick['type']
        entry['join'] = false if pick['join'] == false
        if pick['free']
          {'level' => level['id'], 'set' => {box => {change['ref'] => entry}}, 'remove' => {}, 'retag' => {}, 'kinds' => [box]}
        else
          id = id_for(kind)
          {'level' => level['id'], 'set' => {box => {id => entry}}, 'remove' => {box => [change['ref']]}, 'retag' => {change['ref'] => id}, 'kinds' => [box]}
        end
      end

      def self.move_column(level, pick, item, change, fn)
        c = fn.call(item[:center])
        base = pick['free'] ? pick['free']['rot'].to_f : 0.0
        rot = (base + change['dangle'].to_f) % 360
        rot = rot.round(2)
        rot = rot.to_i if rot == rot.to_i
        replace(level, change, pick, {'x' => c[0], 'y' => c[1], 'rot' => rot})
      end

      # Hai đầu tim của dầm / tường theo dữ liệu (CHƯA nối góc): với phần tử theo lưới lấy từ kế hoạch rồi trừ mức đầu đã dịch do nối góc.
      def self.axis_of(item)
        a, b = case item[:dir]
               when 'x' then [[item[:start], item[:center]], [item[:finish], item[:center]]]
               when 'y' then [[item[:center], item[:start]], [item[:center], item[:finish]]]
               else [item[:a], item[:b]]
               end
        len = Math.hypot(b[0] - a[0], b[1] - a[1])
        u = [(b[0] - a[0]) / len, (b[1] - a[1]) / len]
        s = item[:join_shift].to_f
        e = item[:join_shift_end].to_f
        [[a[0] - u[0] * s, a[1] - u[1] * s], [b[0] - u[0] * e, b[1] - u[1] * e]]
      end

      def self.move_linear(level, pick, item, change, fn)
        a, b = pick['free'] ? [pick['free']['a'], pick['free']['b']] : axis_of(item)
        na = fn.call(a)
        nb = fn.call(b)
        patch = replace(level, change, pick, {'a' => na, 'b' => nb})
        return patch unless change['kind'] == 'wall'
        wall_id = patch['set']['walls'].keys.first
        openings = level['picks']['openings'].select { |_id, e| e['wall'] == change['ref'] }
        return patch if openings.empty?
        reversed = Levels.free_pick!({'a' => na, 'b' => nb}, 'tường', wall_id, level['name'])['a'] != na.map { |v| v.to_f.round(1) }
        length = Math.hypot(nb[0] - na[0], nb[1] - na[1])
        moved = openings.transform_values do |e|
          out = e.merge('wall' => wall_id)
          if reversed # hai đầu đổi chỗ khi chuẩn hóa: vị trí cửa tính lại từ đầu mới, đổi mặt cánh
            out['pos'] = (length - e['pos']).round(1)
            out['flip'] = !e['flip']
            e['mirror'] ? out.delete('mirror') : out['mirror'] = true # đầu đầu và đầu cuối đổi chỗ: bản lề cũng đổi bên
          end
          out
        end
        patch['set']['openings'] = moved
        patch['kinds'] << 'openings'
        patch
      end

      def self.move_opening(level, pick, item, change)
        raise Error, 'thiếu tường' unless item[:wall]
        u = case item[:dir]
            when 'x' then [1.0, 0.0]
            when 'y' then [0.0, 1.0]
            else r = item[:angle].to_f * Math::PI / 180.0; [Math.cos(r), Math.sin(r)]
            end
        d = delta(change)
        along = d[0] * u[0] + d[1] * u[1]
        off = (d[0] * -u[1] + d[1] * u[0]).abs
        return {skip: 'cửa bị kéo ra khỏi tường'} if off > OPENING_OFF_WALL
        return {skip: 'không dời dọc tường'} if along.abs <= MOVE_EPS
        entry = pick.merge('pos' => (pick['pos'] + along).round(1))
        {'level' => level['id'], 'set' => {'openings' => {change['ref'] => entry}}, 'remove' => {}, 'retag' => {}, 'kinds' => %w[openings walls]}
      end

      def self.move_plate(level, pick, item, change, fn)
        ring = pick['free'] ? pick['free']['poly'] : item[:polygon]
        holes = pick['free'] ? (pick['free']['holes'] || []) : []
        replace(level, change, pick, {'poly' => ring.map { |p| fn.call(p) }, 'holes' => holes.map { |h| h.map { |p| fn.call(p) } }})
      end
    end
  end
end
