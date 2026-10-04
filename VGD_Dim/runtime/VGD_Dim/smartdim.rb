# encoding: UTF-8
# Adapted from the user's files.zip; original retained in dev/claude_reference.
module VGD
  module Dim
    # Smart Dim: chon tu (Group/Component) -> tao 2 cap dim tren mat dung:
    #   cap 1 = dim noi tiep (hoi, canh, ...), cap 2 = dim tong.
    module SmartDim
      Z = Geom::Vector3d.new(0, 0, 1) unless const_defined?(:Z, false)
      SIDES = { '-y' => [0, -1, 0], '+y' => [0, 1, 0], '-x' => [-1, 0, 0], '+x' => [1, 0, 0] }.freeze unless const_defined?(:SIDES, false)
      DEFAULTS = {
        'face' => 'camera', 'do_h' => true, 'do_v' => true,
        'h_side' => 'top', 'v_side' => 'left',
        'off1' => 150, 'off2' => 300,
        'min_seg' => 5, 'min_part' => 300, 'depth' => 100
      }.freeze unless const_defined?(:DEFAULTS, false)

      def self.validate(opts)
        raise ArgumentError, 'Thông số Smart Dim không hợp lệ.' unless opts.is_a?(Hash)
        o = DEFAULTS.merge(opts.select { |key, _| DEFAULTS.key?(key) })
        raise ArgumentError, 'Mặt đứng không hợp lệ.' unless (%w[camera axis] + SIDES.keys).include?(o['face'])
        raise ArgumentError, 'Vị trí Dim không hợp lệ.' unless %w[top bottom].include?(o['h_side']) && %w[left right].include?(o['v_side'])
        %w[do_h do_v].each { |key| raise ArgumentError, 'Chọn Dim ngang/đứng không hợp lệ.' unless [true, false].include?(o[key]) }
        raise ArgumentError, 'Hãy bật Dim ngang hoặc Dim đứng.' unless o['do_h'] || o['do_v']
        %w[off1 off2 min_seg min_part depth].each do |key|
          value = Float(o[key]) rescue nil
          raise ArgumentError, "#{key}: cần số mm không âm." unless value && value.finite? && value >= 0
          o[key] = value
        end
        raise ArgumentError, 'Cấp 1 phải > 0; cấp 2 phải lớn hơn cấp 1; chiều sâu phải > 0.' unless o['off1'] > 0 && o['off2'] > o['off1'] && o['depth'] > 0
        o
      end

      def self.run(opts, style)
        model = Sketchup.active_model
        raise 'APPLY đang chạy; đợi hoàn tất trước khi tạo Dim.' if NativeStyle.running?
        o = validate(opts || {})
        config = Core.validate_settings(style || {})
        Engine.check_context(model)
        sel = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
        raise 'Chưa chọn tủ. Hãy chọn Group/Component của tủ rồi bấm Smart Dim.' if sel.empty?

        parts = []
        collect(sel, Geom::Transformation.new, parts, [])
        raise 'Không tìm thấy chi tiết trong tủ đã chọn (bỏ qua đối tượng ẩn, khóa hoặc tag tắt).' if parts.empty?

        bb = Geom::BoundingBox.new
        parts.each { |cs| cs.each { |c| bb.add(c) } }
        face = pick_face(model, bb, o['face'])
        n  = Geom::Vector3d.new(*SIDES[face])
        rv = Z.cross(n)                       # huong "phai" khi nhin vao mat dung

        rows = parts.map do |cs|
          rs = cs.map { |c| c.x * rv.x + c.y * rv.y }
          zs = cs.map(&:z)
          fs = cs.map { |c| c.x * n.x + c.y * n.y }
          { rmin: rs.min, rmax: rs.max, zmin: zs.min, zmax: zs.max, f: fs.max }
        end
        big = rows.select { |p| [p[:rmax] - p[:rmin], p[:zmax] - p[:zmin]].max >= o['min_part'].to_f.mm }
        raise 'Mọi chi tiết đều nhỏ hơn ngưỡng "bỏ chi tiết nhỏ". Hãy giảm ngưỡng này.' if big.empty?
        fmax = big.map { |p| p[:f] }.max
        use  = big.select { |p| p[:f] >= fmax - o['depth'].to_f.mm }

        rmin = use.map { |p| p[:rmin] }.min
        rmax = use.map { |p| p[:rmax] }.max
        zmin = use.map { |p| p[:zmin] }.min
        zmax = use.map { |p| p[:zmax] }.max
        minseg = o['min_seg'].to_f.mm
        hb = breaks(use.flat_map { |p| [p[:rmin], p[:rmax]] }, minseg)
        vb = breaks(use.flat_map { |p| [p[:zmin], p[:zmax]] }, minseg)

        pt = lambda { |r, z| Geom::Point3d.new(rv.x * r + n.x * fmax, rv.y * r + n.y * fmax, z) }
        off1 = o['off1'].to_f.mm
        off2 = o['off2'].to_f.mm
        ents = model.active_entities
        created = []
        count = (o['do_h'] ? hb.size - 1 + (hb.size > 2 ? 1 : 0) : 0) + (o['do_v'] ? vb.size - 1 + (vb.size > 2 ? 1 : 0) : 0)
        raise 'Không có đoạn đo khác 0 trên mặt này.' if count <= 0
        raise 'Quá nhiều đoạn đo (>2000); hãy tăng ngưỡng lọc hoặc chọn ít tủ hơn.' if count > 2000

        AutoStyle.suspend do
          model.start_operation('VGD Dim — Smart Dim', true)
          begin
            if o['do_h']
              hs = o['h_side'] == 'bottom' ? -1 : 1
              zref = hs > 0 ? zmax : zmin
              v1 = Geom::Vector3d.new(0, 0, hs * off1)
              (0...hb.size - 1).each { |i| created << make(ents, pt.call(hb[i], zref), pt.call(hb[i + 1], zref), v1, n) }
              if hb.size > 2
                v2 = Geom::Vector3d.new(0, 0, hs * off2)
                created << make(ents, pt.call(hb.first, zref), pt.call(hb.last, zref), v2, n)
              end
            end
            if o['do_v']
              vs = o['v_side'] == 'right' ? 1 : -1
              rref = vs > 0 ? rmax : rmin
              w1 = Geom::Vector3d.new(rv.x * vs * off1, rv.y * vs * off1, 0)
              (0...vb.size - 1).each { |i| created << make(ents, pt.call(rref, vb[i]), pt.call(rref, vb[i + 1]), w1, n) }
              if vb.size > 2
                w2 = Geom::Vector3d.new(rv.x * vs * off2, rv.y * vs * off2, 0)
                created << make(ents, pt.call(rref, vb.first), pt.call(rref, vb.last), w2, n)
              end
            end
            created.each { |dimension| Core.style_dim(dimension, config['dim']) }
            model.commit_operation
          rescue StandardError => e
            model.abort_operation
            raise e
          end
        end
        model.active_view.invalidate

        { 'face' => face, 'total' => created.size,
          'h' => o['do_h'] ? seg_mm(hb) : [], 'v' => o['do_v'] ? seg_mm(vb) : [], 'parts' => use.size }
      end

      # ---- hinh hoc ----
      def self.make(ents, s, e, off, n)
        s, e = e, s if (e - s).cross(off).dot(n) < 0   # de chu doc duoc tu phia nguoi nhin
        ents.add_dimension_linear(s, e, off)
      end

      def self.seg_mm(b)
        b.each_cons(2).map { |a, c| ((c - a) / 1.mm).round(1) }
      end

      # Gom moc, bo doan nho hon minseg; dau cuoi luon giu de dim tong khop.
      def self.breaks(vals, minseg)
        eps = 0.5.mm
        cl = []
        vals.sort.each { |x| cl << x if cl.empty? || x - cl.last > eps }
        return cl if cl.size < 2
        out = [cl.first]
        cl[1..-1].each { |x| out << x if x - out.last >= minseg }
        if out.last != cl.last
          out.size == 1 ? out << cl.last : out[-1] = cl.last
        end
        out
      end

      def self.pick_face(model, bb, mode)
        return mode if SIDES[mode]
        look = model.active_view.camera.direction.transform(model.edit_transform.inverse)
        keys = SIDES.keys
        if mode == 'axis'
          dist = { '-y' => bb.min.y.abs, '+y' => bb.max.y.abs, '-x' => bb.min.x.abs, '+x' => bb.max.x.abs }
          best = dist.values.min
          keys = keys.select { |k| dist[k] - best < 1.mm }
        end
        keys.max_by { |k| -look.dot(Geom::Vector3d.new(*SIDES[k])) }
      end

      # ---- thu thap chi tiet (bbox 8 goc, toa do cua context dang mo) ----
      def self.corners(bb, t)
        (0..7).map { |i| t * bb.corner(i) }
      end

      def self.collect(list, tr, parts, path)
        raise 'Tủ lồng quá sâu; hãy chọn một nhóm con.' if path.size > 64
        list.each do |e|
          next unless e.valid?
          next if e.hidden? || (e.respond_to?(:locked?) && e.locked?)
          next if e.layer && e.layer.respond_to?(:visible?) && !e.layer.visible?
          case e
          when Sketchup::Group, Sketchup::ComponentInstance
            t = tr * e.transformation
            defn = e.definition
            raise 'Component lồng vòng; không thể đo.' if path.include?(defn)
            kids = defn.entities.select { |c| c.is_a?(Sketchup::Group) || c.is_a?(Sketchup::ComponentInstance) }
            faces = defn.entities.grep(Sketchup::Face).reject do |f|
              f.hidden? || (f.layer && f.layer.respond_to?(:visible?) && !f.layer.visible?)
            end
            if !faces.empty?
              bb = Geom::BoundingBox.new
              faces.each { |f| bb.add(f.bounds) }
              parts << corners(bb, t)
            elsif kids.empty? && defn.entities.grep(Sketchup::Face).empty?
              edges=defn.entities.grep(Sketchup::Edge).reject do |edge|
                edge.hidden? || (edge.layer && edge.layer.respond_to?(:visible?) && !edge.layer.visible?)
              end
              unless edges.empty?
                bb=Geom::BoundingBox.new
                edges.each { |edge| bb.add(edge.bounds) }
                parts << corners(bb,t)
              end
            end
            collect(kids, t, parts, path + [defn])
          when Sketchup::Face
            parts << corners(e.bounds, tr)
          end
        end
      end
    end
  end
end
