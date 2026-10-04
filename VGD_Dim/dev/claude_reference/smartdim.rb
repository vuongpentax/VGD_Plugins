module VGD
  module Dim
    # Smart Dim: chon tu (Group/Component) -> tao 2 cap dim tren mat dung:
    #   cap 1 = dim noi tiep (hoi, canh, ...), cap 2 = dim tong.
    module SmartDim
      Z = Geom::Vector3d.new(0, 0, 1)
      SIDES = { '-y' => [0, -1, 0], '+y' => [0, 1, 0], '-x' => [-1, 0, 0], '+x' => [1, 0, 0] }.freeze
      DEFAULTS = {
        'face' => 'camera', 'do_h' => true, 'do_v' => true,
        'h_side' => 'top', 'v_side' => 'left',
        'off1' => 150, 'off2' => 300,
        'min_seg' => 5, 'min_part' => 300, 'depth' => 100
      }.freeze

      def self.run(opts, style)
        model = Sketchup.active_model
        o = DEFAULTS.merge(opts || {})
        sel = model.selection.to_a
        raise 'Chưa chọn tủ. Hãy chọn Group/Component của tủ rồi bấm Smart Dim.' if sel.empty?

        parts = []
        collect(sel, Geom::Transformation.new, parts)
        raise 'Không tìm thấy chi tiết nào trong vùng chọn (đối tượng ẩn bị bỏ qua).' if parts.empty?

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

        AutoStyle.suspend do
          model.start_operation('VGD Smart Dim', true)
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
            report = Hash.new { |h, k| h[k] = Hash.new(0) }
            created.each { |d| Core.style_dim(d, (style || {})['dim'] || {}, report) }
            model.commit_operation
          rescue StandardError => e
            model.abort_operation
            raise e
          end
        end

        { 'face' => face, 'total' => created.size,
          'h' => seg_mm(hb), 'v' => seg_mm(vb), 'parts' => use.size }
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
        out = [cl.first]
        cl[1..-1].each { |x| out << x if x - out.last >= minseg }
        if out.last != cl.last
          out.size == 1 ? out << cl.last : out[-1] = cl.last
        end
        out
      end

      def self.pick_face(model, bb, mode)
        return mode if SIDES[mode]
        look = model.active_view.camera.direction
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

      def self.collect(list, tr, parts)
        list.each do |e|
          next unless e.valid?
          next if Core.skip_hidden?(e, {})
          case e
          when Sketchup::Group, Sketchup::ComponentInstance
            t = tr * e.transformation
            defn = e.definition
            kids = defn.entities.select { |c| c.is_a?(Sketchup::Group) || c.is_a?(Sketchup::ComponentInstance) }
            faces = defn.entities.grep(Sketchup::Face).reject(&:hidden?)
            if !faces.empty?
              bb = Geom::BoundingBox.new
              faces.each { |f| bb.add(f.bounds) }
              parts << corners(bb, t)
            elsif kids.empty? && defn.bounds.valid?
              parts << corners(defn.bounds, t)
            end
            collect(kids, t, parts)
          when Sketchup::Face
            parts << corners(e.bounds, tr)
          end
        end
      end
    end
  end
end
